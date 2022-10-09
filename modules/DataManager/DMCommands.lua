local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local AnnounceSender = BPGP.GetModule("AnnounceSender")
local Logger = BPGP.GetModule("Logger")

local private = {
}

----------------------------------------
-- Public interface
----------------------------------------

function DataManager.MassAwardBP(reason, bpInc)
  local StandbyTracker = BPGP.GetModule("StandbyTracker")
  local err = nil
  if not DataManager.SelfInRaid() then
    err = L["Mass BP Award: You should be in a raid group!"]
  end
  if err then BPGP.Print(err) return end
  assert(DataManager.IsAllowedDataWrite())
  local standbyReason = reason.." - "..L["Standby"]
  local bpIncStandby = math.floor(bpInc * (DataManager.GetStandbyPercent() / 100) + 0.5)
  
  local bpBatch = DataManager.NewBatch(reason, "RaidAwardedBP", bpInc)
  local bpStandbyBatch = DataManager.NewBatch(standbyReason, "RaidAwardedBP", bpIncStandby, StandbyTracker.GetAnnounceMedium())
  
  for playerName in pairs(DataManager.GetRaidDB("class")) do
    if DataManager.IsInGuild(playerName) then
      local mainName = DataManager.GetMain(playerName)
      if mainName then
        playerName = mainName
      end
      if not bpBatch[playerName] then
        bpBatch[playerName] = bpInc
      end
    end
  end
  
  for playerName in pairs(StandbyTracker.GetStandbyList()) do
    if DataManager.IsInGuild(playerName) then
      local mainName = DataManager.GetMain(playerName)
      if mainName then
        playerName = mainName
      end
      if not bpBatch[playerName] and not bpStandbyBatch[playerName] then
        bpStandbyBatch[playerName] = bpIncStandby
      end
    end
  end
  
  if next(bpBatch) then
    DataManager.MultiBatchIncBPGP({bpBatch, bpStandbyBatch}, nil)
  end
end

function DataManager.AssignMain(altName, mainName)
  assert(DataManager.SelfSA(), "Assign main failed: data write is forbidden")
  local err = nil
  if not DataManager.IsInGuild(mainName) then
    err = L["Main %s is below level %d or not in guild!"]:format(mainName, DataManager.GetMinimalLevel())
  elseif DataManager.GetMain(mainName) then
    err = L["Main %s is also an alt!"]:format(mainName)
  elseif DataManager.IsAltRankIndex(DataManager.GetRankIndex(mainName)) then
    err = L["Main %s has alt-marked rank <%s> in options!"]:format(mainName, DataManager.GetRank(mainName))
  elseif not DataManager.IsAltRankIndex(DataManager.GetRankIndex(altName)) then
    err = L["Rank <%s> isn't marked as alt rank in options!"]:format(altName, DataManager.GetRank(altName))
  else
    for i = 1, DataManager.GetNumTables() do
      local bp, gp = DataManager.GetBPGP(altName, i)
      if bp > 0 or gp > DataManager.GetBaseGP(i) then
        err = L["%s has more then 0 BP or more then %d GP in table %s!"]:format(altName, DataManager.GetBaseGP(i), DataManager.GetTableName(i))
        break
      end
    end
  end
  if err then
    BPGP.Print(L["Main assignment for %s was aborted: %s"]:format(altName, err))
    return
  end
  DataManager.SetNote(altName, DataManager.EncodeAltData(mainName), true)
  BPGP.Print(L["Main assignment for %s is finished: %s is now a main."]:format(altName, mainName))
end

-- Service commands

function DataManager.ResetBPGP(affectBP, affectGP)
  assert(DataManager.IsAllowedDataWrite(), "Reset BP/GP failed: data write is forbidden")
  local bpBatch, gpBatch = nil, nil
  if affectBP then bpBatch = DataManager.NewBatch(L["BP Reset"], "SysResetBP", nil) end
  if affectGP then gpBatch = DataManager.NewBatch(L["GP Reset"], "SysResetGP", nil) end
  DataManager.FillResetBatches(bpBatch, gpBatch)
  
  DataManager.BatchIncBPGP(bpBatch, gpBatch)
end

function DataManager.RescaleBPGP(affectBP, affectGP, rescaleFactor)
  assert(DataManager.IsAllowedDataWrite(), "Rescale BP/GP failed: data write is forbidden")
  if rescaleFactor == 1 then return end
  local reason = L["Rescale to x%s"]:format(rescaleFactor)
  
  local bpBatch, gpBatch = nil, nil
  if affectBP then bpBatch = DataManager.NewBatch(reason, "SysRescaleBP", rescaleFactor) end
  if affectGP then gpBatch = DataManager.NewBatch(reason, "SysRescaleGP", rescaleFactor) end
  DataManager.FillRescaleBatches(bpBatch, gpBatch, rescaleFactor)
  
  DataManager.BatchIncBPGP(bpBatch, gpBatch)
end

function DataManager.DecayBPGP()
  assert(DataManager.IsAllowedDataWrite(), "Decay BP/GP failed: data write is forbidden")
  local reason = L["Decay %s%%"]:format(DataManager.GetDecayPercent())
  
  local bpBatch = DataManager.NewBatch(reason, "SysDecayBP", DataManager.GetDecayPercent())
  local gpBatch = DataManager.NewBatch(reason, "SysDecayGP", DataManager.GetDecayPercent())  
  DataManager.FillRescaleBatches(bpBatch, gpBatch, 1 - DataManager.GetDecayPercent() * 0.01)
  
  DataManager.BatchIncBPGP(bpBatch, gpBatch)
end

-- Low-level global operations, use with care!

function DataManager.SoftLock()
  if not DataManager.IsInGuild(DataManager.GetSelfName()) then
    BPGP.Print(L["You should be level %d+ or have guild rank %s to unlock the system! If you were promoted during current session please open guild tab or /reload your UI."]:format(DataManager.db.profile.minimalLevel, DataManager.GetGuildRank(1)))
    return
  end
  if not DataManager.SelfActive() then
    DataManager.SetNote(DataManager.GetSelfName(), DataManager.EncodeMainData(DataManager.GetSelfName(), nil, nil, 0, DataManager.GetNumTables(), DataManager.WideTablesEnabled()), true)
    BPGP.Print(L["User activation complete! Please click red lock button again to unlock the table."])
    return
  end
  DataManager.ShiftLockState(BPGP.GetModule("StandingsManager").GetTableId())
end

function DataManager.HardLock()
  DataManager.ShiftLockState(0)
end

function DataManager.InitializeBPGP()
  if not DataManager.SelfGM() then return end
  local err = nil
  if not DataManager.GetSettingsHolder() then
    err = L["%s ranked level 1 character for settings holding not found!"]:format(DataManager.GetGuildRank(1))
  elseif DataManager.SelfActive() then
    err = L["system is already initialized!"]
  end
  if err then
    BPGP.Print(L["Initialization was aborted: %s"]:format(err))
    return
  end
  DataManager.SoftLock()
  BPGP.Print(L["Initialization finished! Please configure Enforced Settings to finish setup."])
end

function DataManager.WipeData()
  assert(DataManager.IsAllowedDataWrite(), "Data wipe aborted: data write is forbidden!")
  local pendingPlayers = {}
  for playerName in pairs(DataManager.GetPlayersDB("id")) do
    local skipped = false
    for i = 1, DataManager.GetNumTables() do
      local bp, gp = DataManager.GetBPGP(playerName, i)
      if bp > 0 or gp > DataManager.GetBaseGP(i) then
        BPGP.Print(L["Skipped data wipe for %s: more then 0 BP or more then %d GP in table %s!"]:format(playerName, DataManager.GetBaseGP(i), DataManager.GetTableName(i)))
        skipped = true
        break
      end
    end
    if not skipped then
      table.insert(pendingPlayers, playerName)
    end
  end
  if #pendingPlayers == 0 then
    BPGP.Print(L["Data wipe aborted: eligible members not found!"])
    return
  end
  for i, playerName in pairs(pendingPlayers) do
    DataManager.SetNote(playerName, "", true)
    BPGP.Print(L["Wiped data for %s"]:format(playerName))
  end
  AnnounceSender.AnnounceEvent("SysWipeBPGP")
end

function DataManager.WipeSettings()
  if next(DataManager.GetPlayersDB("id")) then
    BPGP.Print(L["Settings wipe aborted: please wipe all data containers first!"])
    return
  end
  DataManager.SetNote(DataManager.GetSettingsHolder(), "", true)
end
