local _, BPGP = ...

local DataManager = BPGP.NewModule("DataManager")

local type, tostring, wipe, next, pairs, math = type, tostring, wipe, next, pairs, math

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
 
local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      minimalLevel = 70,
    },
  },
  initialized = false,
  guildRosterUpdated = true,
  isIntegrityLocked = true,
  isWriteLocked = true,
  alerts = {},
}
Debugger.Attach("DataManager", private)

function DataManager:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("DataManager", private.dbDefaults)
  BPGP.db.RegisterCallback(self, "OnDatabaseShutdown", DataManager.Snapshot)
end

function DataManager:OnEnable()
  BPGP.RegisterEvent("PLAYER_REGEN_DISABLED", DataManager.UpdateSelfGetInCombat)
  BPGP.RegisterEvent("PLAYER_REGEN_ENABLED", DataManager.UpdateSelfOutOfCombat)
end

function DataManager:OnDisable()
  BPGP.UnregisterEvent("PLAYER_REGEN_DISABLED", DataManager.UpdateSelfGetInCombat)
  BPGP.UnregisterEvent("PLAYER_REGEN_ENABLED", DataManager.UpdateSelfOutOfCombat)
end

----------------------------------------
-- Public interface
----------------------------------------

function DataManager.ResetAlerts()
  wipe(private.alerts)
end

function DataManager.GetMinimalLevel()
  return DataManager.db.profile.minimalLevel
end

function DataManager.GetAlerts(target)
  if target then return private.alerts[target] else return private.alerts end
end

function DataManager.NewAlert(target, alert)
  if not private.alerts[target] then private.alerts[target] = {} end
  table.insert(private.alerts[target], alert)
end

function DataManager.IsInitialized()
  return private.initialized
end

function DataManager.IsWriteLocked()
  return not DataManager.SelfCanWriteNotes() or private.isWriteLocked
end

function DataManager.IsAllowedDataWrite()
  DataManager.UpdateData() -- We must ensure first that guild data read is not pending
  return not private.isIntegrityLocked and not DataManager.IsWriteLocked()
end

function DataManager.IsValidReason(reason)
  if not reason or string.len(tostring(reason)) < 1 then return false end
  return true
end

function DataManager.IsValidIncrement(x)
  if type(x) ~= "number" then return false end
  if x < -99999 or x > 99999 or x ~= math.floor(x + 0.5) then return false end
  return true
end

function DataManager.IsAllowedIncBPGPByX(reason, x)
  if not DataManager.IsAllowedDataWrite() then return false end
  if not DataManager.IsValidReason(reason) then return false end
  if not DataManager.IsValidIncrement(x) then return false end
  return true
end

function DataManager.CalculateIndex(bp, gp)
  local index = bp / math.max(1, gp)
  if DataManager.IntegerIndexEnabled() then
    return index + 0.5 - (index + 0.5) % 1
  else
    return math.floor(index * 10000 + 0.5) / 10000
  end
end

----------------------------------------
-- Unsafe public interface
----------------------------------------

function DataManager.QueueGuildRosterUpdate()
  Debugger("QueueGuildRosterUpdate")
  private.guildRosterUpdated = true
  if not private.initialized then
    DataManager.UpdateData()
    if private.initialized then
      BPGP.GetModule("Logger").TrimToOneMonth()
      BPGP.GetModule("Logger").ReadChainHashes()
    end
  end
end

function DataManager.UpdateData()
  if not private.guildRosterUpdated then return end
  private.guildRosterUpdated = false
  Debugger("Processing guild roster")
  DataManager.UpdateSelfNoteEditStatus()
  local dataUpdated = DataManager.UpdateGuildDB()
  if dataUpdated then
    if DataManager.GetSettingsHolder() then
      DataManager.ResetAlerts()
    end
    local pending = DataManager.GetUpdatedData()
    if pending.settings then
      pending.settings = false
      DataManager.UpdateSettings()
      BPGP.Fire("SettingsUpdated", DataManager.GetSettings())
      Debugger("SettingsDB updated")
      DataManager.UpdateOptions()
    end
    if next(pending.updated) or next(pending.removed) then
      DataManager.UpdatePlayersDB(pending)
      if pending.updated[DataManager.GetSelfName()] or pending.removed[DataManager.GetSelfName()] then
        DataManager.UpdateSelfDB()
        Debugger("SelfDB updated")
      end
      wipe(pending.updated)
      wipe(pending.removed)
      Debugger("PlayersDB updated")
    end
    DataManager.UpdateSelfRoleSA()
    
    private.isWriteLocked = false or not not next(DataManager.GetAlerts())
    private.isIntegrityLocked = not DataManager.SelfSA() or DataManager.GetLockState() == 0
    
    BPGP.GetModule("StandingsManager").DestroyStandings()
    private.initialized = true
    Debugger("New data processed")
    BPGP.Fire("DataManagerUpdated")
  else
    Debugger("No new data found")
  end
  Debugger("Roster processing finished")
end

function DataManager.Snapshot(t)
  wipe(BPGP.db.profile.snapshot)
  for playerName in pairs(DataManager.GetPlayersDB("id")) do
    table.insert(BPGP.db.profile.snapshot, {playerName, DataManager.GetClass(playerName), DataManager.GetRawBPGP(playerName)})
  end
  for playerName, mainName in pairs(DataManager.GetPlayersDB("main")) do
    table.insert(BPGP.db.profile.snapshot, {playerName, DataManager.GetClass(playerName), mainName})
  end
end

-- DataManager gets locked in Read-Only state after each write operaion and unlocks once roster update was processed

-- Enables Read-Only lock, should be called for every separate write operation to keep data integrity
function DataManager.WriteLock()
  private.isWriteLocked = true
end

-- Removes the Read-Only lock, should only be called when data was updated or for consequent write operations 
function DataManager.WriteUnlock()
  private.isWriteLocked = false
end