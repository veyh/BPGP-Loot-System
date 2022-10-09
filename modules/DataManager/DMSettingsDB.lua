local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Storage = BPGP.GetLibrary("Storage")

local AnnounceSender = BPGP.GetModule("AnnounceSender")
local Logger = BPGP.GetModule("Logger")

function DataManager.NewSettings()
  return Common:NewCopy({
    sysState = 0,
    sysAdminId = 0,
    lockState = 0,
    baseGP = {},
    minBP = {},
    baseGPOld = 1,
    decayPercent = 0,
    standbyPercent = 100,
    altRanks = {},
    wideTables = false,
    namedTables = false,
    integerIndex = false, -- EPGP-like BP / GP handling
    numTables = 1,
    tableNames = {9},
    bpAward = 1,
    gpCredit = 1,
  })
end

local private = {
  decoder = {
    tableNames = {"KARA", "GRUUL", "MAG", "SC", "TK", "HYJAL", "BT", "ZA", "SP"},
    flagSet1 = {"wideTables", "namedTables", "integerIndex"}, -- 11 max
    flagSet2 = {}, -- 11 max
  },
  settings = DataManager.NewSettings(),
}
Debugger.Attach("SettingsDB", private)

----------------------------------------
-- Public interface
----------------------------------------

----------------------------------------
-- Getters
----------------------------------------

-- Plain values
function DataManager.GetSettings() return private.settings end
function DataManager.GetSystemState() return private.settings.sysState end
function DataManager.GetSysAdminId() return private.settings.sysAdminId end
function DataManager.GetLockState() return private.settings.lockState end
function DataManager.GetBaseGP(tableId)
  return private.settings.baseGP[tableId or DataManager.GetUnlockedTableId()] or private.settings.baseGPOld or 1
end
function DataManager.GetDecayPercent() return private.settings.decayPercent end
function DataManager.GetStandbyPercent() return private.settings.standbyPercent end
function DataManager.GetBPAward() return private.settings.bpAward end
function DataManager.GetGPCredit() return private.settings.gpCredit end
function DataManager.GetMinBP(tableId)
  return private.settings.minBP[tableId] or 0
end

-- Flags
function DataManager.WideTablesEnabled() return private.settings.wideTables end
function DataManager.NamedTablesEnabled() return private.settings.namedTables end
function DataManager.IntegerIndexEnabled() return private.settings.integerIndex end

-- Data tables
function DataManager.GetTableNames() return private.decoder.tableNames end
function DataManager.GetNumTables() return private.settings.numTables end
function DataManager.GetTableName(i)
  if private.settings.namedTables then
    return private.decoder.tableNames[private.settings.tableNames[i]]
  else
    if i > 0 then return L["#%d"]:format(i) else return end
  end
end

-- Other

function DataManager.IsSA(playerName)
  return DataManager.GetId(playerName) == private.settings.sysAdminId
end

function DataManager.IsAltRankIndex(rankIndex)
  return private.settings.altRanks[rankIndex]
end

function DataManager.GetSysAdminName()
 return DataManager.GetName(private.settings.sysAdminId) or L["<System>"]
end

function DataManager.GetUnlockedTableName()
  if private.settings.lockState == 0 then return end
  return DataManager.GetTableName(private.settings.lockState)
end

function DataManager.GetUnlockedTableId()
  if private.settings.lockState == 0 then return end
  return private.settings.lockState
end

----------------------------------------
-- Setters
----------------------------------------

function DataManager.ShiftLockState(lockState)
  local newSettings = Common:NewCopy(private.settings)
  assert(lockState ~= newSettings.lockState or DataManager.GetSelfId() ~= newSettings.sysAdminId)
  if lockState == 0 then
    private.oldSystemState = newSettings.sysState
    newSettings.sysState = newSettings.sysState + 1
    if newSettings.sysState > 3067 then newSettings.sysState = 1 end
  end
  newSettings.lockState = lockState
  newSettings.sysAdminId = DataManager.GetSelfId() or 0
  Logger.LogLockShift(DataManager.GetSelfName(), DataManager.GetTableName(lockState) or "LOCKED")
  DataManager.WriteSettings(newSettings)
  if lockState == 0 then
    for mainName in pairs(DataManager.GetPlayersDB("id")) do
      local decodedData = Storage:Decode(private.oldSystemState, mainName, DataManager.GetNote(mainName))
      DataManager.SetNote(mainName, Storage:Encode(newSettings.sysState, mainName, decodedData), true)
    end
  end
end

function DataManager.ApplySettings(settings)
  if not DataManager.SelfGM() then return end
  assert(#settings.minBP >= 1 and #settings.minBP <= 6)
  for i = 1, 6 do
    assert(settings.minBP[i] >= 0 and settings.minBP[i] <= 1000)
  end
  assert(#settings.baseGP >= 1 and #settings.baseGP <= 6)
  for i = 1, 6 do
    assert(settings.baseGP[i] >= 1 and settings.baseGP[i] <= 1000)
  end
  assert(settings.baseGPOld >= 1 and settings.baseGPOld <= 1000)
  assert(settings.decayPercent >= 0 and settings.decayPercent <= 100)
  assert(settings.standbyPercent >= 0 and settings.standbyPercent <= 100)
  assert(Common:KeysCount(settings.altRanks) <= 3)
  assert(settings.numTables >= 1 and settings.numTables <= 6)
  assert(settings.bpAward > 0 and settings.bpAward <= 1000)
  assert(settings.gpCredit > 0 and settings.gpCredit <= 1000)
  assert(settings.numTables >= private.settings.numTables, "Data tables removing is not implemented yet!")
  BPGP.Print(L["Applying Enforced Settings..."])
  DataManager.WriteSettings(settings)
  if settings.wideTables ~= private.settings.wideTables or settings.numTables ~= private.settings.numTables then
    BPGP.Print(L["Converting data containers to new storage format, please wait..."])
    for mainName in pairs(DataManager.GetPlayersDB("id")) do
      DataManager.SetNote(mainName, DataManager.EncodeMainData(mainName, nil, nil, 0, settings.numTables, settings.wideTables), true)
    end
    BPGP.Print(L["Data containers conversion finished."])
  end
  BPGP.Print(L["Enforced Settings have been applied."])
end

----------------------------------------
-- Settings Reading
----------------------------------------

function DataManager.UpdateSettings()
  local handle, newSettings = DataManager.GetSettingsHolder(), nil
  if handle then
    local rawSettings = Storage:Decode(0, handle, DataManager.GetNote(handle))  
    newSettings = DataManager.DecodeSettings(rawSettings)
  end
  if newSettings then
    private.settings = newSettings
  else
    if not CanViewOfficerNote() then
      DataManager.NewAlert("BPGP", L["Failed to load BPGP data! You aren't allowed to view Officer Notes."])
    else
      DataManager.NewAlert("BPGP", L["Failed to read Enforced Settings! Please ask your Guild Master to setup BPGP properly."])
    end
    private.settings = DataManager.NewSettings()
  end
end

----------------------------------------
-- Settings Writing
----------------------------------------

function DataManager.WriteSettings(settings)
  if DataManager.SelfActive() then
    if DataManager.IsWriteLocked() and not next(DataManager.GetAlerts()) then return end
  else
    if not DataManager.SelfGM() then return end
  end
  if DataManager.GetLockState() == 0 and not (DataManager.SelfSA() or DataManager.SelfGM()) then return end
  
  local handle = DataManager.GetSettingsHolder()
  if not handle then return end
  
  local rawSettings = DataManager.EncodeSettings(settings)
  local encodedSettings = Storage:Encode(0, handle, rawSettings)
  
  DataManager.SetNote(handle, encodedSettings, true)
end

function DataManager.WriteSettingsPreset(preset)
  if not DataManager.SelfGM() then return end
  local encodedSettings = Storage:Encode(0, DataManager.GetSettingsHolder(), preset)
  DataManager.SetNote(DataManager.GetSettingsHolder(), encodedSettings, true)
end

----------------------------------------
-- Settings Decoding
----------------------------------------

function DataManager.DecodeSettings(rawSettings)
  if not rawSettings or #rawSettings < 12 then return end
  local settings = DataManager.NewSettings()
  settings.sysState = rawSettings[1] -- Used for encryption, 0-3067
  settings.sysAdminId = rawSettings[2] -- Id of player the system is unlocked for, 1-3067
  settings.lockState = rawSettings[3] -- Id of unlocked table, 0-6
--  local unused = rawSettings[4] -- MinBP is no longer global setting
  settings.baseGPOld = rawSettings[5] -- [DEPRECATED] Minimal amount of GP, points can't drop below it, 0-3067
  settings.decayPercent = rawSettings[6] -- Percent which is deducted from both BP&GP on each Decay call, 0-100
  settings.standbyPercent = rawSettings[7] -- Percent of mass BP award which goes to raiders in standby list, 0-100
  
  settings.altRanks = DataManager.DecodeAltRanks(rawSettings[8]) -- Rank ids which are considered as alts by the system, up to 3
  
  local flags1 = DataManager.DecodeFlags(rawSettings[9]) -- Flag set, declared in decoder.flagSet1, up to 11 flags
  for i, flag in ipairs(private.decoder.flagSet1) do
    settings[flag] = flags1[i]
  end
  
  settings.tableNames = DataManager.DecodeTableNames(rawSettings[11], rawSettings[12]) -- BP/GP tables metadata
  settings.numTables = #settings.tableNames
  
  settings.bpAward = rawSettings[13] -- Default BP award size, 1-3067
  settings.gpCredit = rawSettings[14] -- Default GP credit size, 1-3067
  
  -- Minimal amount of BP to be shown on the top of index-sorted list, 0-3067
  for i = 1, 6 do
    settings.minBP[i] = rawSettings[14 + i] or 0
  end
  
  -- Minimal amount of GP, points can't drop below it, 0-3067
  for i = 1, 6 do
    settings.baseGP[i] = rawSettings[20 + i] or settings.baseGPOld or 1
  end
  
  return settings
end

function DataManager.DecodeAltRanks(codeBytes1)
  local codeBytes, altRanks = tostring(codeBytes1), {}
  for i = 1, #codeBytes do
    local codeByte = tonumber(codeBytes:sub(i, i))
    if codeByte > 0 then
      altRanks[codeByte] = true
    end
  end
  return altRanks
end

function DataManager.DecodeFlags(flags)
  local decodedFlags = {}
  for i = 1, 11 do
    table.insert(decodedFlags, Common:TestFlag(flags, 2 ^ (i - 1)))
  end
  return decodedFlags
end

function DataManager.DecodeTableNames(codeBytes1, codeBytes2) -- 111 - 999
  local codeBytes, tables = tostring(codeBytes1)..tostring(codeBytes2), {}
  for i = 1, #codeBytes do
    local codeByte = tonumber(codeBytes:sub(i, i))
    if codeByte > 0 then
      table.insert(tables, codeByte)
    end
  end
  return tables
end

----------------------------------------
-- Settings Encoding
----------------------------------------

function DataManager.EncodeSettings(settings)
  local rawSettings = {
    settings.sysState,
    settings.sysAdminId,
    settings.lockState,
    0,
    settings.baseGPOld,
    settings.decayPercent,
    settings.standbyPercent,
  }
  table.insert(rawSettings, DataManager.EncodeAltRanks(settings))
  table.insert(rawSettings, DataManager.EncodeFlags(settings, private.decoder.flagSet1))
  table.insert(rawSettings, DataManager.EncodeFlags(settings, private.decoder.flagSet2))
  table.insert(rawSettings, DataManager.EncodeTables(settings, 0))
  table.insert(rawSettings, DataManager.EncodeTables(settings, 3))
  
  table.insert(rawSettings, settings.bpAward)
  table.insert(rawSettings, settings.gpCredit)
  
  for i = 1, 6 do
    table.insert(rawSettings, settings.minBP[i])
  end
  
  for i = 1, 6 do
    table.insert(rawSettings, settings.baseGP[i])
  end
  
  return rawSettings
end

function DataManager.EncodeAltRanks(settings)
  local altRanks = "0" -- For tonumber transform if no alt ranks
  for rankIndex, isAltRank in pairs(settings.altRanks) do
    if isAltRank then
      altRanks = altRanks..tostring(rankIndex)
    end
    if #altRanks > 3 then break end -- Break once we get something like "0248", 3 alt ranks max
  end
  return tonumber(altRanks)
end

function DataManager.EncodeFlags(settings, flagSet)
  local flags = 0
  for i = 1, 11 do
    if settings[flagSet[i]] then
      flags = Common:SetFlag(flags, 2 ^ (i - 1))
    end
  end
  return flags
end

function DataManager.EncodeTables(settings, offset)
  local tabs = "0" -- For tonumber transform if no tables
  for i = 1 + offset, offset + 3 do
    tabs = tabs..tostring(settings.tableNames[i] or 0)
  end
  return tonumber(tabs)
end
