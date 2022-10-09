local _, BPGP = ...

local ChecksManager = BPGP.NewModule("ChecksManager")

local tinsert, tconcat, wipe = tinsert, table.concat, wipe
local GetNumGroupMembers, GetRaidRosterInfo = GetNumGroupMembers, GetRaidRosterInfo
local UnitName, UnitGUID, CanLootUnit = UnitName, UnitGUID, CanLootUnit

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
LibStub("AceComm-3.0"):Embed(ChecksManager)

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local DataManager = BPGP.GetModule("DataManager")
local AnnounceSender = BPGP.GetModule("AnnounceSender")

local private = {
  versionCheckOngoing = false,
  versionCheckResults = {},
  lootChecksList = {},
  lootCheckUnitNames = {},
  lootCheckResults = {},
  lootCheckHistory = {},
}

function ChecksManager:OnEnable()
  self:RegisterComm("BPGPLOOTREQUEST", private.HandletLootCheckRequest)
  self:RegisterComm("BPGPLOOTRESPONSE", private.HandletLootCheckResponse)
  self:RegisterComm("BPGPVERSREQUEST", private.HandletVersionCheckRequest)
  self:RegisterComm("BPGPVERSRESPONSE", private.HandletVersionCheckResponse)
end

-- Version Check

function ChecksManager.RequestVersionCheck()
  local playerName, errorMsg = DataManager.GetSelfName(), nil
  if not DataManager.SelfInRaid() then
    errorMsg = L["Version Check: You should be in a raid group!"]
  elseif DataManager.GetRaidRank(playerName) == 0 then
    errorMsg = L["Version Check: You should be at least a group assistant!"]
  elseif private.versionCheckOngoing then
    errorMsg = L["Version Check: Previous check isn't finished!"]
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  BPGP.Print(L["Version Check: Started."])
  private.versionCheckOngoing = true
  private.versionCheckResults[playerName] = BPGP.GetVersion()
  ChecksManager:SendCommMessage("BPGPVERSREQUEST", "1", "RAID", nil, "ALERT")
  Coroutine:RunAsync(private.AsyncTrackVersionCheck)
end

function private.HandletVersionCheckRequest(prefix, message, distribution, sender)
  if not DataManager.SelfInRaid() or sender == DataManager.GetSelfName() then return end
  if DataManager.GetRaidRank(sender) == 0 then return end
  ChecksManager:SendCommMessage("BPGPVERSRESPONSE", BPGP.GetVersion(), "WHISPER", sender, "ALERT")
end

function private.HandletVersionCheckResponse(prefix, message, distribution, sender)
  if not DataManager.IsInRaid(sender) then return end
  private.versionCheckResults[sender] = message
end

function private.AsyncTrackVersionCheck(unitName, unitGUID)
  for i = 1, 25 do
    if Common:KeysCount(private.versionCheckResults) == GetNumGroupMembers() then break end
    Coroutine:Sleep(0.2)
  end
  local currentVersion, oldVersions, unknownVersions, offlineMembers = BPGP.GetVersion(), {}, {}, {}
  for i = 1, GetNumGroupMembers() do
    local playerName, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
    local version = private.versionCheckResults[playerName]
    if version then
      if version < currentVersion then
        tinsert(oldVersions, playerName.."-"..version)
      end
    else
      if online then
        tinsert(unknownVersions, playerName)
      else
        tinsert(offlineMembers, playerName)
      end
    end
  end
  wipe(private.versionCheckResults)
  private.versionCheckOngoing = false
  if #oldVersions == 0 and #unknownVersions == 0 and #offlineMembers == 0 then
    BPGP.Print(L["Version Check: Everyone reporting version %s or higher."]:format(currentVersion))
  else
    if #oldVersions > 0 then
      BPGP.Print(L["Version Check: Old: %s."]:format(tconcat(oldVersions, ", ")))
    end
    if #unknownVersions > 0 then
      BPGP.Print(L["Version Check: Unknown: %s."]:format(tconcat(unknownVersions, ", ")))
    end
    if #offlineMembers > 0 then
      BPGP.Print(L["Version Check: Offline: %s."]:format(tconcat(offlineMembers, ", ")))
    end
  end
end

-- Loot Check
    
function ChecksManager.RequestLootCheck()
  local playerName, unitName, unitGUID, errorMsg = DataManager.GetSelfName(), UnitName("target"), UnitGUID("target"), nil
  if not DataManager.SelfInRaid() then
    errorMsg = L["Loot Check: You should be in a raid group!"]
  elseif not unitName or unitName == ""  or not unitGUID or unitGUID == "" then
    errorMsg = L["Loot Check: Please target a corpse first!"]
  elseif DataManager.GetRaidRank(playerName) == 0 then
    errorMsg = L["Loot Check for %s: You should be at least a group assistant!"]:format(unitName)
  elseif not UnitIsDead("target") then
    errorMsg = L["Loot Check for %s: Target must be dead!"]:format(unitName)
  elseif private.lootChecksList[unitGUID] then
    if private.lootCheckHistory[unitGUID] then
      errorMsg = L["Loot Check for %s: it's %s's loot."]:format(unitName, private.lootCheckHistory[unitGUID])
    elseif private.lootCheckHistory[unitGUID] == playerName then
      errorMsg = L["Loot Check for %s: Everyone reporting it's looted or out of 100 yd range."]:format(unitName, private.lootChecksList[unitGUID])
    else
      errorMsg = L["Loot Check for %s: Already checked by %s!"]:format(unitName, private.lootChecksList[unitGUID])
    end
  else
    local hasLoot, canLoot = CanLootUnit(unitGUID)
    if hasLoot then
      errorMsg = L["Loot Check for %s: Please loot the corpse yourself!"]:format(unitName)
    end
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  BPGP.Print(L["Loot Check for %s: Started."]:format(unitName))
  private.lootChecksList[unitGUID] = playerName
  private.lootCheckUnitNames[unitGUID] = unitName
  private.lootCheckResults[unitGUID] = {}
  private.lootCheckResults[unitGUID][playerName] = "0"
  ChecksManager:SendCommMessage("BPGPLOOTREQUEST", unitGUID, "RAID", nil, "ALERT")
  Coroutine:RunAsync(private.AsyncTrackLootCheck, unitName, unitGUID)
end

function private.HandletLootCheckRequest(prefix, message, distribution, sender)
  if not message or message == "" or private.lootChecksList[message] then return end
  if not DataManager.SelfInRaid() or sender == DataManager.GetSelfName() then return end
  if DataManager.GetRaidRank(sender) == 0 then return end
  private.lootChecksList[message] = sender
  local hasLoot, canLoot = CanLootUnit(message)
  local checkResult = hasLoot and "1" or "0"
  ChecksManager:SendCommMessage("BPGPLOOTRESPONSE", message..","..checkResult, "WHISPER", sender, "ALERT")
end

function private.HandletLootCheckResponse(prefix, message, distribution, sender)
  if not DataManager.IsInRaid(sender) then return end
  local unitGUID, checkResult = strsplit(",", message)
  if not (unitGUID and unitGUID ~= "" and checkResult and checkResult ~= "") then return end
  if not (private.lootCheckUnitNames[unitGUID] and private.lootCheckResults[unitGUID]) then return end
  private.lootCheckResults[unitGUID][sender] = checkResult
  if checkResult == "1" then
    AnnounceSender.AnnounceEvent("PendingCorpseLoot", sender, private.lootCheckUnitNames[unitGUID])
    BPGP.Print(L["Loot Check for %s: it's %s's loot."]:format(private.lootCheckUnitNames[unitGUID], sender))
    private.lootCheckUnitNames[unitGUID] = nil
    private.lootCheckResults[unitGUID] = nil
    private.lootCheckHistory[unitGUID] = sender
  end
end

function private.AsyncTrackLootCheck(unitName, unitGUID)
  for i = 1, 25 do
    if not private.lootCheckUnitNames[unitGUID] then return end
    if Common:KeysCount(private.lootCheckResults[unitGUID]) == GetNumGroupMembers() then break end
    Coroutine:Sleep(0.2)
  end
  local notResponded = {}
  for i = 1, GetNumGroupMembers() do
    local playerName = GetRaidRosterInfo(i)
    if not private.lootCheckResults[unitGUID][playerName] then
      tinsert(notResponded, playerName)
    end
  end
  private.lootCheckUnitNames[unitGUID] = nil
  private.lootCheckResults[unitGUID] = nil
  if #notResponded > 0 then
    BPGP.Print(L["Loot Check for %s ignored by: %s."]:format(unitName, tconcat(notResponded, ", ")))
  else
    BPGP.Print(L["Loot Check for %s: Everyone reporting it's looted or out of 100 yd range."]:format(unitName))
  end
end
