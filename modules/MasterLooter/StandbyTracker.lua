local _, BPGP = ...

local StandbyTracker = BPGP.NewModule("StandbyTracker")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local AnnounceSender = BPGP.GetModule("AnnounceSender")
local DataManager = BPGP.GetModule("DataManager")
local MasterLooter = BPGP.GetModule("MasterLooter")

local strfind, strtrim = strfind, strtrim

local SendChatMessage = _G.SendChatMessage
if ChatThrottleLib then
  SendChatMessage = function(...) ChatThrottleLib:SendChatMessage("NORMAL", "BPGP", ...) end
end
  
local private = {
  dbDefaults = {
    profile = {
      enabled = false, -- Loading is managed by MasterLooter module
      cache = {
        requestsList = {},
        standbyList = {},
        standbyCount = 0,
      },
    },
  },
  standbyList = nil,
}
Debugger.Attach("StandbyTracker", private)

function StandbyTracker:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("StandbyTracker", private.dbDefaults)
  private.standbyList = self.db.profile.cache.standbyList
end

function StandbyTracker:OnEnable()
  Debugger("StandbyTracker:OnEnable()")
  if MasterLooter.db.profile.standbyRequests then
    BPGP.RegisterEvent("CHAT_MSG_WHISPER", self.HandleStandbyRequest)
  end
end

function StandbyTracker:OnDisable()
  Debugger("StandbyTracker:OnDisable()")
  BPGP.UnregisterEvent("CHAT_MSG_WHISPER", self.HandleStandbyRequest)
end

function StandbyTracker:Reload()
  self:Disable()
  self:Enable()
end

----------------------------------------
-- Event handlers
----------------------------------------

function StandbyTracker.HandleStandbyRequest(event_name, msg, sender)
  if not DataManager.SelfInRaid() then return end
  sender = Common:ExtractCharacterName(sender)
  msg = strtrim(msg):lower()
  -- Looking for any header ("bpgp", "/bpgp", " /bpgp" "-epgp", ".epgp" etc...)
  if not strfind(msg:sub(1, 6), "pgp") then return end
  -- Looking for "standby" / "sitout"
  local matchStart, matchend = strfind(msg:sub(1, 15), "stand")
  if not matchStart then
    matchStart, matchend = strfind(msg:sub(1, 15), "sit")
  end
  if not matchStart then return end
  -- Looking if there is character name provided
  local member, foundSeparator = nil, false -- Allow any number of spaces between command and name
  for i = matchend+1, msg:len() do
    if msg:sub(i, i) == " " then
      foundSeparator = true
    elseif foundSeparator then
      member = msg:sub(i, i):upper()..msg:sub(i+1)
      break
    end
  end
  if not member then
    member = sender
  end
  if not DataManager.IsActive(member) and not DataManager.IsInactive(member) then
    SendChatMessage(L["[BPGP] "]..L["%s is below level %d or not in guild!"]:format(member, DataManager.GetMinimalLevel()), "WHISPER", nil, sender)
  elseif DataManager.GuildMemberInRaid(sender) and member == sender then
    SendChatMessage(L["[BPGP] "]..L["Please leave the raid group before making a request!"]:format(member, DataManager.GuildMemberInRaid(member)), "WHISPER", nil, sender)
  elseif DataManager.GuildMemberInRaid(member) then
    SendChatMessage(L["[BPGP] "]..L["%s is already in the raid as %s!"]:format(member, DataManager.GuildMemberInRaid(member)), "WHISPER", nil, sender)
  elseif StandbyTracker.GuildMemberEnlisted(member) then
    if member == sender then
      SendChatMessage(L["[BPGP] "]..L["You are already added to the standby list."]:format(member, StandbyTracker.GuildMemberEnlisted(member)), "WHISPER", nil, sender)
    else
      SendChatMessage(L["[BPGP] "]..L["%s is already added to the standby list as %s!"]:format(member, StandbyTracker.GuildMemberEnlisted(member)), "WHISPER", nil, sender)
    end
  else
    StandbyTracker.RegisterRequest(sender, member)
  end
end

----------------------------------------
-- Public interface
----------------------------------------

function StandbyTracker.GetStandbyList()
  return private.standbyList
end

function StandbyTracker.RequestStandby()
  local sa = DataManager.GetSysAdminName()
  local errorMsg = nil
  if DataManager.IsInRaid(sa) then
    errorMsg = L["Standby Request: Please leave the raid group first!"]
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  SendChatMessage("bpgp standby", "WHISPER", nil, DataManager.GetSysAdminName())
end

function StandbyTracker.AnnounceStandbyList()
  local errorMsg = nil
  if not DataManager.SelfInRaid() then
    errorMsg = L["Standby Announce: You should be in a raid group!"]
  end
  if errorMsg then BPGP.Print(errorMsg) return end
  AnnounceSender.AnnounceEvent("AnnounceStandbyList", StandbyTracker.GetAnnounceMedium(), StandbyTracker.GetStandbyList())
end

function StandbyTracker.GetAnnounceMedium()
  return MasterLooter.db.profile.standbyAnnounceMedium
end

function StandbyTracker.RegisterRequest(sender, member)
  local senderMain, memberMain = DataManager.GetMain(sender), DataManager.GetMain(member)
  if member == sender or member == senderMain or memberMain == sender or (memberMain and memberMain == senderMain) then
    StandbyTracker.db.profile.cache.requestsList[member] = { sender = sender }
    SendChatMessage(L["[BPGP] "]..L["Your standby request for %s is awaiting approval."]:format(member), "WHISPER", nil, sender)
    BPGP.GetModule("StandingsManager").DestroyStandings()
  else
    SendChatMessage(L["[BPGP] "]..L["You can request standby only for YOUR main or alt."], "WHISPER", nil, sender)
  end
end

function StandbyTracker.AcceptRequest(member)
  local request = StandbyTracker.db.profile.cache.requestsList[member]
  if request then
    if StandbyTracker.Enlist(member, true) then
      SendChatMessage(L["[BPGP] "]..L["Your standby request for %s has been accepted."]:format(member),"WHISPER", nil, request.sender)
      StandbyTracker.db.profile.cache.requestsList[member] = nil
      BPGP.GetModule("StandingsManager").DestroyStandings()      
    end
  end
end

function StandbyTracker.DeclineRequest(member)
  local request = StandbyTracker.db.profile.cache.requestsList[member]
  if request then
    SendChatMessage(L["[BPGP] "]..L["Your standby request for %s has been declined."]:format(member),"WHISPER", nil, request.sender)
    StandbyTracker.db.profile.cache.requestsList[member] = nil
    BPGP.GetModule("StandingsManager").DestroyStandings()
  end
end

function StandbyTracker.IsEnlisted(playerName)
  return not not StandbyTracker.db.profile.cache.standbyList[playerName]
end

function StandbyTracker.GuildMemberEnlisted(playerName)
  local charactersList = DataManager.GetMemberCharacters(playerName)
  for i = 1, #charactersList do
    if StandbyTracker.db.profile.cache.standbyList[charactersList[i]] then
      return charactersList[i]
    end
  end
  return nil
end

function StandbyTracker.IsPending(playerName)
  return StandbyTracker.db.profile.cache.requestsList[playerName]
end

function StandbyTracker.GetNumStandbyMembers()
  return StandbyTracker.db.profile.cache.standbyCount
end

function StandbyTracker.Enlist(playerName, skipNotify)
  local err = nil
  if not MasterLooter.db.profile.standbySupport then
    err = L["please enable standby list in options first!"]:format(playerName)
  elseif not DataManager.SelfInRaid() then
    err = L["please join the raid group first!"]:format(playerName)
  elseif DataManager.GuildMemberInRaid(playerName) then
    err = L["%s is already in the award list as %s!"]:format(playerName, DataManager.GuildMemberInRaid(playerName))
  elseif StandbyTracker.GuildMemberEnlisted(playerName) then
    err = L["%s is already in the award list as %s!"]:format(playerName, StandbyTracker.GuildMemberEnlisted(playerName))
  end
  if err then
    BPGP.Print(L["Failed to enlist %s for standby: %s"]:format(playerName, err))
    return
  end
  StandbyTracker.db.profile.cache.standbyList[playerName] = {}
  StandbyTracker.db.profile.cache.standbyCount = StandbyTracker.db.profile.cache.standbyCount + 1
  BPGP.GetModule("StandingsManager").DestroyStandings()
  if not skipNotify and MasterLooter.db.profile.standbyNotify then
    SendChatMessage(L["[BPGP] "]..L["You have been added to standby list."], "WHISPER", nil, playerName)
  end
  return true
end

function StandbyTracker.Delist(playerName)
  if DataManager.IsInRaid(playerName) then
    return false
  end
  if not StandbyTracker.db.profile.cache.standbyList[playerName] then
    return false
  end
  StandbyTracker.db.profile.cache.standbyList[playerName] = nil
  StandbyTracker.db.profile.cache.standbyCount = StandbyTracker.db.profile.cache.standbyCount - 1
  BPGP.GetModule("StandingsManager").DestroyStandings()
  if MasterLooter.db.profile.standbyNotify then
    SendChatMessage(L["[BPGP] "]..L["You have been removed from standby list."], "WHISPER", nil, playerName)
  end
  return true
end

function StandbyTracker.UpdateData()
  if not MasterLooter.db.profile.standbySupport then return end
  if DataManager.SelfInRaid() then
    for playerName in pairs(StandbyTracker.db.profile.cache.standbyList) do
      if DataManager.GuildMemberInRaid(playerName) then
        StandbyTracker.db.profile.cache.standbyList[playerName] = nil
        StandbyTracker.db.profile.cache.standbyCount = StandbyTracker.db.profile.cache.standbyCount - 1
        Debugger(playerName.." removed from standby list")
      end
    end
    for playerName in pairs(StandbyTracker.db.profile.cache.requestsList) do
      if DataManager.GuildMemberInRaid(playerName) then
        StandbyTracker.db.profile.cache.requestsList[playerName] = nil
        Debugger(playerName.." removed from standby requests list")
      end
    end
  else
    if StandbyTracker.db.profile.cache.standbyCount == 0 then return end
    wipe(StandbyTracker.db.profile.cache.standbyList)
    wipe(StandbyTracker.db.profile.cache.requestsList)
    StandbyTracker.db.profile.cache.standbyCount = 0
    Debugger("Standby lists were wiped")
  end
end
