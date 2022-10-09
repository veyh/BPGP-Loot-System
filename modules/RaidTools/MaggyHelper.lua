local _, BPGP = ...

local MaggyHelper = BPGP.NewModule("MaggyHelper")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
LibStub("AceComm-3.0"):Embed(MaggyHelper)

local LibDeflate = LibStub("LibDeflate")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")
local Storage = BPGP.GetLibrary("Storage")
local Encryption = BPGP.GetLibrary("Encryption")

local DataManager = BPGP.GetModule("DataManager")

local math = math
local string, strsplit, tostring, tonumber = string, strsplit, tostring, tonumber
local select, ipairs, pairs = select, ipairs, pairs
local tinsert, tconcat, wipe = tinsert, table.concat, wipe
local GetServerTime, GetInstanceInfo, UnitIsDead, SendChatMessage, PlaySoundFile = GetServerTime, GetInstanceInfo, UnitIsDead, SendChatMessage, PlaySoundFile

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      soundEnabled = false,
      showFrame = true,
      lockFrame = false,
      currentPositions = {5, 6, 7, 8, 4}, -- Target icon for each cube position
      currentAssignments = {},
      incomingAssignments = {},
      broadcastedSpecs = {},
    },
  },
  novaCounter = 0,
  lastNovaCastTime = 0,
  currentSpecId = 0,
  serializationCache = {},
  playerAssignmentsCRCs = {},
  targetSounds = {
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Star.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Circle.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Diamond.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Triangle.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Moon.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Square.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Cross.ogg",
    "Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Skull.ogg",
  },
}
Debugger.Attach("MaggyHelper", private)

----------------------------------------
-- Core module methods
----------------------------------------

function MaggyHelper:OnAddonLoad()
  -- Setup DB
  self.db = BPGP.db:RegisterNamespace("MaggyHelper", private.dbDefaults)
  BPGP.RegisterEvent("PLAYER_ENTERING_WORLD", private.HandlePlayerEnteringWorld)
  BPGP.RegisterEvent("RAID_INSTANCE_WELCOME", private.HandlePlayerEnteringWorld)
  BPGP.RegisterEvent("GROUP_ROSTER_UPDATE", private.HandleGroupRosterUpdate)
end

function MaggyHelper:OnEnable()
  -- Nova Counter data feed
--  BPGP.RegisterEvent("SPELL_CAST_SUCCESS 6304", private.HandleSpellCastStart) -- Rhahk'Zor Slam id = 6304
  BPGP.RegisterEvent("CHAT_MSG_MONSTER_YELL", private.HandleMonsterYell)
  BPGP.RegisterEvent("SPELL_CAST_START 30616", private.HandleSpellCastStart)
  BPGP.RegisterEvent("UNIT_DIED", private.HandleUnitDied)
  -- Assignments module data exchange
  self:RegisterComm("MHB_SPEC", private.HandleBroadcastedSpec)
  self:RegisterComm("MHB_CRC", private.HandleBroadcastedCRC)
  self:RegisterComm("MHB_ASSIGN", private.HandleBroadcastedAssignments)
  -- Show incoming assignments popup if it wasn't responded before /reload
  if MaggyHelper.db.profile.incomingAssignments.notResponded then
    BPGP.Fire("AssignmentsBroadcastProcessed", MaggyHelper.db.profile.incomingAssignments)
  end
end

function MaggyHelper:OnDisable()
  -- Nova Counter data feed
--  BPGP.UnregisterEvent("SPELL_CAST_SUCCESS 6304", private.HandleSpellCastStart)
  BPGP.UnregisterEvent("CHAT_MSG_MONSTER_YELL", private.HandleMonsterYell)
  BPGP.UnregisterEvent("SPELL_CAST_START 30616", private.HandleSpellCastStart)
  BPGP.UnregisterEvent("UNIT_DIED", private.HandleUnitDied)
end

function private.ToggleWidget()
  local mapId = select(8, GetInstanceInfo())
  if mapId == 544 then -- DM mapId = 36
    MaggyHelper:Enable()
    if MaggyHelper.db.profile.showFrame then 
      MaggyHelper.ShowWidgetFrame()
    end
  else
    MaggyHelper:Disable()
    MaggyHelper.HideWidgetFrame()
  end
end

function private.HandlePlayerEnteringWorld()
  private.UpdateCurrentSpecId()
  private.ToggleWidget()
end

function private.HandleGroupRosterUpdate()
  if DataManager.SelfInRaid() then
    private.BroadcastTalents()
  end
end

----------------------------------------
-- Player Spec sharing
----------------------------------------

function private.UpdateCurrentSpecId()
  local specDepth = 0
  for specId = 1, GetNumTalentTabs() do
    local activeTalents = 0
    for talentId = 1, GetNumTalents(specId) do
      activeTalents = activeTalents + select(5, GetTalentInfo(specId, talentId))
    end
    if activeTalents > specDepth then
      specDepth = activeTalents
      private.currentSpecId = specId
    end
  end
end

function private.BroadcastTalents()
  local message = tostring(private.currentSpecId)
  MaggyHelper:SendCommMessage("MHB_SPEC", message, "RAID", nil, "BULK")
end

----------------------------------------
-- Blast Nova counter engine
----------------------------------------

function private.HandleMonsterYell(event, message)
  local yell = L["I... am... unleashed!"] -- Rhahk'Zor yell = "VanCleef pay big for you heads!"
  local yell2 = L["I will not be taken so easily! Let the walls of this prison tremble... and fall!"] 
  if message == yell or message:find(yell) then
    private.novaCounter = 1
    private.lastNovaCastTime = GetServerTime()
    BPGP.Fire("NovaCounterUpdate")
    Coroutine:RunAsync(private.AsyncCounterReset)
    Debugger("Maggy Helper: Phase 2 transition detected.")
  elseif message == yell2 or message:find(yell2) then
    if private.lastNovaCastTime + 50 - GetServerTime() < 20 then
      private.nextNovaCastTime = GetServerTime() + 20
    end
  end
end

function MaggyHelper.GetNextNovaCastTime()
  return private.nextNovaCastTime
end  

function MaggyHelper.SetNextNovaCastTime(value)
  private.nextNovaCastTime = value
end  

function private.AsyncCounterReset()
  while GetServerTime() - private.lastNovaCastTime < 90 do
    Coroutine:Sleep(10)
  end
  private.novaCounter = 0
  private.lastNovaCastTime = 0
  BPGP.Fire("NovaCounterUpdate")
end

function private.HandleSpellCastStart(...)
  local serverTime = GetServerTime()
  if serverTime < private.lastNovaCastTime + 35 then
--    print("Counter on CD, left:", private.lastNovaCastTime+35-serverTime, "next nova is #", private.novaCounter)
  else
    if private.novaCounter == 0 then
      private.novaCounter = 1
      Coroutine:RunAsync(private.AsyncCounterReset)
      Debugger("Maggy Helper: Phase 2 transition detection failed, falled back to start from 2nd Nova .")
    end
    private.novaCounter = private.novaCounter + 1
    private.lastNovaCastTime = serverTime
    BPGP.Fire("NovaCounterUpdate")
  end
end

function private.HandleUnitDied(event, guid, name, flags, raidFlags, destGUID, destName)
  local unitType, zero, serverId, instanceId, zoneUID, npcId, spawnUID = strsplit("-", destGUID)
  if npcId == "17257" then -- Maggy npcId = 17257; Rhahk'Zor npcId = 644
    private.novaCounter = 0
    private.lastNovaCastTime = 0
    BPGP.Fire("NovaCounterUpdate")
    MaggyHelper:Disable()
    MaggyHelper.HideWidgetFrame()
  end
end

function private.TestNovaCounter()
    BPGP.Print("Maggy Helper: Blast Nova counter test started! Est. duration: 2 min.")
    DataManager.UpdateSelfGetInCombat()
    Coroutine:Sleep(5)
    private.HandleMonsterYell(nil, L["I... am... unleashed!"])
    Coroutine:Sleep(50)
    private.HandleSpellCastStart()
    Coroutine:Sleep(50)
--    private.HandleMonsterYell(nil, L["I will not be taken so easily! Let the walls of this prison tremble... and fall!"] )
--    Coroutine:Sleep(31)
    private.HandleSpellCastStart()
    Coroutine:Sleep(5)
    private.HandleUnitDied(event, guid, name, flags, raidFlags, "0-0-0-0-0-17257", destName)
    DataManager.UpdateSelfOutOfCombat()
end

----------------------------------------
-- Assignments Broadcasts
----------------------------------------

function private.HandleBroadcastedSpec(prefix, message, distribution, sender)
  if not DataManager.IsInRaid(sender) then return end
  local specId = tonumber(message)
  if specId > 0 and specId <= 4 then
    MaggyHelper.db.profile.broadcastedSpecs[sender] = tonumber(message)
  end
end

function private.HandleBroadcastedCRC(prefix, message, distribution, sender)
  if not DataManager.IsInRaid(sender) then return end
  if sender == DataManager.GetSelfName() then return end
  local crc = tonumber(message)
  private.playerAssignmentsCRCs[sender] = crc
  BPGP.Fire("BroadcastResponseProcessed", sender)
end

function private.SerializeAssignments(positions, assignments)
  if not positions or not assignments then return end
  wipe(private.serializationCache)
  for playerName, slotId in pairs(assignments) do
    if DataManager.IsInRaid(playerName) then
      private.serializationCache[slotId] = playerName
    end
  end
  local result = tconcat(positions, ":") .. ";"
  for slotId = 1, 40 do
    local playerName = private.serializationCache[slotId]
    if playerName then
      result = result .. string.format("%s:%d,", playerName, slotId)
    end
  end
  return result:sub(0, -2)
end

function private.BroadcastAssignmentsCRC()
  if not DataManager.SelfInRaid() then return end
  MaggyHelper:SendCommMessage("MHB_CRC", tostring(MaggyHelper.GetCurrentCRC()), "RAID", nil, "BULK")
end

function private.HandleBroadcastedAssignments(prefix, message, distribution, sender)
  if not ((DataManager.GetRaidRank(sender) or 0) > 0) then return end
  
  wipe(MaggyHelper.db.profile.incomingAssignments)
  
  local incomingAssignments = MaggyHelper.GetIncomingAssignments()
  incomingAssignments.positions = {}
  incomingAssignments.assignments = {}
  
  incomingAssignments.sender = sender
  
  local rawPositions, rawAssignments = strsplit(";", message)
  
  local positions = {strsplit(":", rawPositions)}
  for i = 1, 5 do
    local position = tonumber(positions[i] or "0")
    if position > 0 then
      incomingAssignments.positions[i] = position
    end
  end
  
  local assignments = {strsplit(",", rawAssignments)}
  for i = 1, #assignments do
    local playerName, slotId = strsplit(":", assignments[i] or "")
    if playerName and slotId then
      incomingAssignments.assignments[playerName] = tonumber(slotId)
    end
  end
  
  local crc = MaggyHelper.GetIncomingAssignmentsCRC()
  
  local senderName, color = incomingAssignments.sender, DataManager.GetRaidClassColor(incomingAssignments.sender)
  if color then senderName = string.format("|c%s@%s|r", color.colorStr, incomingAssignments.sender) end
  incomingAssignments.watermark = string.format("|cFF00FF00#%d|r%s", crc, senderName)
  MaggyHelper.UpdateCurrentCRC()
  
  if crc ~= MaggyHelper.GetCurrentCRC() then
    incomingAssignments.notResponded = true
  else
    incomingAssignments.notResponded = false
  end
  
  BPGP.Fire("AssignmentsBroadcastProcessed", incomingAssignments)
end

----------------------------------------
-- Public interface
----------------------------------------

function MaggyHelper.TestNovaCounter()
  Coroutine:RunAsync(private.TestNovaCounter)
end

function private.PlaySoundWarning()
  local positionId = MaggyHelper.GetAssignedPositionId(DataManager.GetSelfName())
  local soundFile = MaggyHelper.db.profile.currentPositions[positionId]
  PlaySoundFile("Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\AirHorn.ogg", "Master")
  Coroutine:Sleep(1)
  PlaySoundFile("Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Stack.ogg", "Master")
  Coroutine:Sleep(1)
  PlaySoundFile(private.targetSounds[soundFile], "Master")
  Coroutine:Sleep(5)
  PlaySoundFile("Interface\\AddOns\\BPGP-Loot-System\\media\\sounds\\Stack.ogg", "Master")
  Coroutine:Sleep(1)
  PlaySoundFile(private.targetSounds[soundFile], "Master")
end

function MaggyHelper.PlaySoundWarning()
  if MaggyHelper.db.profile.soundEnabled then
    Coroutine:RunAsync(private.PlaySoundWarning)
  end
end

function MaggyHelper.ToggleSound()
  MaggyHelper.db.profile.soundEnabled = not MaggyHelper.db.profile.soundEnabled
end

function MaggyHelper.GetSpecId(playerName)
  return MaggyHelper.db.profile.broadcastedSpecs[playerName]
--  return MaggyHelper.db.profile.broadcastedSpecs[playerName] or DataManager.GetDummyRole(playerName)
end

function MaggyHelper.GetNextNovaNumber()
  return private.novaCounter
end

function MaggyHelper.GetCurrentCRC()
  return private.playerAssignmentsCRCs[DataManager.GetSelfName()]
end

function MaggyHelper.GetPlayerCRC(playerName)
  return private.playerAssignmentsCRCs[playerName]
end

function MaggyHelper.GetIncomingAssignments()
  return MaggyHelper.db.profile.incomingAssignments
end

function MaggyHelper.GetAssignedSlotId(playerName)
  return MaggyHelper.db.profile.currentAssignments[playerName] or 0
end

function MaggyHelper.GetAssignedNovaId(playerName)
  local slotId = MaggyHelper.GetAssignedSlotId(playerName)
  return slotId / 4 <= 5 and slotId - (math.ceil(slotId / 4) - 1) * 4 or 0
end

function MaggyHelper.GetAssignedPositionId(playerName)
  local slotId = MaggyHelper.GetAssignedSlotId(playerName)
  return slotId / 4 <= 5 and math.ceil(slotId / 4) or 0
end

function MaggyHelper.SetAssignedSlotId(playerName, slotId)
  if not playerName then return end
  MaggyHelper.db.profile.currentAssignments[playerName] = slotId
end

function MaggyHelper.UpdateTargetIconPosition(positionId, iconId)
  MaggyHelper.db.profile.currentPositions[positionId] = iconId
  MaggyHelper.UpdateCurrentCRC()
end

function MaggyHelper.LoadLastKnownAssignments()
  MaggyHelper.ResponseAssignmentsBroadcast(1)
end

function MaggyHelper.GetIncomingAssignmentsCRC()
  local incomingAssignments = MaggyHelper.GetIncomingAssignments()
  if not incomingAssignments then return end
  local assignments = private.SerializeAssignments(incomingAssignments.positions, incomingAssignments.assignments)
  if not assignments then return end
  return Encryption:GetChecksum(assignments)
end

function MaggyHelper.UpdateCurrentCRC()
  local newAssignmentsCRC = Encryption:GetChecksum(private.SerializeAssignments(MaggyHelper.db.profile.currentPositions, MaggyHelper.db.profile.currentAssignments))
  private.playerAssignmentsCRCs[DataManager.GetSelfName()] = newAssignmentsCRC
  private.BroadcastAssignmentsCRC()
  BPGP.Fire("AssignmentsCRCUpdated", newAssignmentsCRC)
end

function MaggyHelper.ResetCurrentCRC()
  private.playerAssignmentsCRCs[DataManager.GetSelfName()] = 0
  BPGP.Fire("AssignmentsCRCUpdated", 0)
end

function MaggyHelper.BroadcastAssignments()
  local playerName, errorMsg = DataManager.GetSelfName(), nil
  if not DataManager.SelfInRaid() then
    errorMsg = L["Maggy Helper: You should be in a raid group!"]
  elseif DataManager.GetRaidRank(playerName) == 0 then
    errorMsg = L["Maggy Helper: You should be at least a group assistant!"]
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  
  local message = private.SerializeAssignments(MaggyHelper.db.profile.currentPositions, MaggyHelper.db.profile.currentAssignments)
  MaggyHelper:SendCommMessage("MHB_ASSIGN", message, "RAID", nil, "ALERT")
end
  
function MaggyHelper.ResponseAssignmentsBroadcast(response)
  local incomingAssignments = MaggyHelper.GetIncomingAssignments()
  if response == 1 then
--    wipe(MaggyHelper.db.profile.currentAssignments)
    for index, position in pairs(incomingAssignments.positions) do
      MaggyHelper.db.profile.currentPositions[index] = position
    end
    for playerName, slotId in pairs(incomingAssignments.assignments) do
      if DataManager.IsInRaid(playerName) then
        MaggyHelper.SetAssignedSlotId(playerName, tonumber(slotId))
      end
    end
    MaggyHelper.UpdateCurrentCRC()
    BPGP.Fire("NewAssignmentsReceived")
  end
  incomingAssignments.notResponded = false
end
  
function MaggyHelper.AnnounceCurrentAssignments()
  local playerName, errorMsg = DataManager.GetSelfName(), nil
  if not DataManager.SelfInRaid() then
    errorMsg = L["Maggy Helper: You should be in a raid group!"]
  elseif DataManager.GetRaidRank(playerName) == 0 then
    errorMsg = L["Maggy Helper: You should be at least a group assistant!"]
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  
  local cachedAssigments = {}
  for playerName, slotId in pairs(MaggyHelper.db.profile.currentAssignments) do
    if DataManager.IsInRaid(playerName) then
      cachedAssigments[slotId] = playerName
    end
  end
  
  local announceData = {}
  for novaId = 1, 4 do
    if not announceData[novaId] then announceData[novaId] = {} end
    for groupId = 1, 5 do
      local slotId = (groupId - 1) * 4 + novaId
      local targetIcon = MaggyHelper.db.profile.currentPositions[groupId]
      local playerName = cachedAssigments[slotId]
      announceData[novaId][groupId] = string.format(L["{rt%d} %s"], targetIcon, playerName or L["N/A"])
    end
  end
  
  SendChatMessage(L["Blast Nova assignments #%d:"]:format(MaggyHelper.GetCurrentCRC()), "RAID", nil, 0)
  for novaId = 1, #announceData do
    SendChatMessage(L["%d. %s"]:format(novaId, tconcat(announceData[novaId], " || ")), "RAID", nil, 0)
  end
end

function MaggyHelper.AutoAssign()
  local playerName, errorMsg = DataManager.GetSelfName(), nil
  if not DataManager.SelfInRaid() then
    errorMsg = L["Maggy Helper: You should be in a raid group!"]
  elseif DataManager.GetRaidRank(playerName) == 0 then
    errorMsg = L["Maggy Helper: You should be at least a group assistant!"]
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  
  local classRoles = {
    ["DRUID"] = {"MOBILE_MELEE", "RANGED", "TANK", "HEALER"},
    ["HUNTER"] = {"MOBILE_RANGED", "MOBILE_RANGED", "MOBILE_RANGED", "MOBILE_RANGED"},
    ["MAGE"] = {"MOBILE_RANGED", "MOBILE_RANGED", "MOBILE_RANGED", "MOBILE_RANGED"},
    ["PALADIN"] = {"MELEE", "HEALER", "TANK", "MELEE"},
    ["PRIEST"] = {"HEALER", "HEALER", "HEALER", "MOBILE_MELEE"},
    ["ROGUE"] = {"MOBILE_MELEE", "MOBILE_MELEE", "MOBILE_MELEE", "MOBILE_MELEE"},
    ["SHAMAN"] = {"RANGED", "RANGED", "MOBILE_MELEE", "HEALER"},
    ["WARLOCK"] = {"RANGED", "RANGED", "RANGED", "RANGED"},
    ["WARRIOR"] = {"MELEE", "MELEE", "MELEE", "TANK"},
  }
  local positionsPrios = {
    {"MELEE", "MOBILE_MELEE", "TANK", "HEALER", "RANGED", "MOBILE_RANGED"}, -- NE
    {"HEALER", "RANGED", "MOBILE_RANGED", "MOBILE_MELEE", "MELEE", "TANK"}, -- SE
    {"MOBILE_RANGED", "RANGED", "MOBILE_MELEE", "MELEE", "HEALER", "TANK"}, -- S
    {"HEALER", "RANGED", "MOBILE_RANGED", "MOBILE_MELEE", "MELEE", "TANK"}, -- SW
    {"MELEE", "MOBILE_MELEE", "TANK", "HEALER", "RANGED", "MOBILE_RANGED"}, -- NW
  }
  -- Build role-based player index by known spec data, fallback to default class role if spec is unknown
  local roster = {}
  for playerName, playerClass in pairs(DataManager.GetRaidDB("class")) do
    local playerRole = classRoles[playerClass][(MaggyHelper.GetSpecId(playerName) or 0) + 1]
    if not roster[playerRole] then roster[playerRole] = {} end
    roster[playerRole][playerName] = true
  end
  
  local assignments = {}
  -- Iterate through Novas, pulling & assigning players with best suiting roles one by one
  for novaId = 1, 4 do
    local perNovaLimits = {["TANK"] = 2, ["HEALER"] = 1} -- 'cause we don't want all healers to be assigned for same Nova
    -- Iterate through cubes
    for positionId = 1, 5 do
      local chosenOne = nil
      -- Iterate through per-cubes role priorities, from best suited to worst suited
      for _, preferredRole in ipairs(positionsPrios[positionId]) do
        if roster[preferredRole] then
          -- Iterate through players with given role
          for playerName in pairs(roster[preferredRole]) do
            if perNovaLimits[preferredRole] then
              if perNovaLimits[preferredRole] == 0 then break end -- Exit given role's loop if limit reached
              perNovaLimits[preferredRole] = perNovaLimits[preferredRole] - 1
            end
            chosenOne = playerName
            roster[preferredRole][playerName] = nil -- Remove this yet-to-be-assigned poor soul from the available roster
            break
          end
        end
        if chosenOne then break end -- Exit given cube's loop if found someone
      end
      if chosenOne then
        assignments[chosenOne] = (positionId - 1) * 4 + novaId
      end
    end
  end
  -- Place non-assigned players in the end of the table
  local slotId = 40
  for playerRole, roleRoster in pairs(roster) do
    for playerName in pairs(roleRoster) do
      assignments[playerName] = slotId
      slotId = slotId - 1
    end
  end
  -- Update assignments registry
  for playerName, slotId in pairs(assignments) do
    MaggyHelper.SetAssignedSlotId(playerName, slotId)
  end
  MaggyHelper.UpdateCurrentCRC()
  -- Data is ready, firing GUI update
  BPGP.Fire("NewAssignmentsReceived")
end