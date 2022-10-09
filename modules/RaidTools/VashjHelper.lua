local _, BPGP = ...

local VashjHelper = BPGP.NewModule("VashjHelper")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
LibStub("AceComm-3.0"):Embed(VashjHelper)

local LibDeflate = LibStub("LibDeflate")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")
local Storage = BPGP.GetLibrary("Storage")
local Encryption = BPGP.GetLibrary("Encryption")

local DataManager = BPGP.GetModule("DataManager")

local GetItemCount = GetItemCount
local string, strsplit, tostring, tonumber = string, strsplit, tostring, tonumber
local select, ipairs, pairs = select, ipairs, pairs
local tinsert, tconcat, wipe = tinsert, table.concat, wipe
local GetServerTime, GetInstanceInfo, SendChatMessage = GetServerTime, GetInstanceInfo, SendChatMessage

local private = {
  dbDefaults = {
    profile = {
      enabled = false,
    },
  },
  taintedCores = {},
  combatTimeEnd = 0,
}
Debugger.Attach("VashjHelper", private)

----------------------------------------
-- Core module methods
----------------------------------------

function VashjHelper:OnAddonLoad()
  -- Setup DB
  self.db = BPGP.db:RegisterNamespace("VashjHelper", private.dbDefaults)
  BPGP.RegisterEvent("GROUP_ROSTER_UPDATE", private.HandleGroupRosterUpdate)
  BPGP.RegisterEvent("PLAYER_ENTERING_WORLD", private.HandleGroupRosterUpdate)
end

function VashjHelper:OnEnable()
  BPGP.RegisterEvent("CHAT_MSG_MONSTER_YELL", private.HandleMonsterYell)
  self:RegisterComm("VHB_CORE", private.HandleBroadcastedTaintedCoreStatus)
end

function VashjHelper:OnDisable()
  BPGP.UnregisterEvent("CHAT_MSG_MONSTER_YELL", private.HandleMonsterYell)
  self:UnregisterComm("VHB_CORE", private.HandleBroadcastedTaintedCoreStatus)
end

function private.HandleGroupRosterUpdate()
  if DataManager.SelfInRaid() then
    VashjHelper:Enable()
  else
    VashjHelper:Disable()
  end
end

--function private.ToggleWidget()
--  local mapId = select(8, GetInstanceInfo())
--  if mapId == 544 then -- DM mapId = 36
--    VashjHelper:Enable()
--    if VashjHelper.db.profile.showFrame then 
--      VashjHelper.ShowWidgetFrame()
--    end
--  else
--    VashjHelper:Disable()
--    VashjHelper.HideWidgetFrame()
--  end
--end

function private.HandleMonsterYell(event, message)
  local yell_p2 = L["The time is now! Leave none standing!"]
  local yell_p3 = L["You may want to take cover."]
  if message == yell_p2 or message:find(yell_p2) then
    private.coreTrackerEnabled = true
    private.coreInInventory = false
    Coroutine:RunAsync(private.AsyncTrackTaintedCore)
    Debugger("Vashj Helper: Phase 2 transition detected.")
  elseif message == yell_p3 or message:find(yell_p3) then
    private.coreTrackerEnabled = false
    Debugger("Vashj Helper: Phase 3 transition detected.")
  end
end

function private.AsyncTrackTaintedCore()
  local combatTimeEnd = 0
  while private.coreTrackerEnabled do
    if private.combatTimeEnd > 0 and GetServerTime() >= private.combatTimeEnd + 180 then
      break
    end
--    local itemCount = GetItemCount(6948) -- Tainted Core ID: 31088
    local itemCount = GetItemCount(31088) -- Tainted Core ID: 31088
    if itemCount > 0 then
      if not private.coreInInventory then
        private.coreInInventory = true
        private.BroadcastTaintedCoreStatus(GetServerTime())
      end
    else
      if private.coreInInventory then
        private.coreInInventory = false
        private.BroadcastTaintedCoreStatus(0)
      end
    end
    Coroutine:Sleep(0.1)
  end
  private.taintedCores = {}
end

function private.UpdateTimeOutOfCombat(event, inCombat)
  if not inCombat then
    private.combatTimeEnd = GetServerTime()
  else
    private.combatTimeEnd = 0
  end
end
BPGP.RegisterCallback("CombatUpdate", private.UpdateTimeOutOfCombat)

----------------------------------------
-- Tainted Core Broadcasts
----------------------------------------

function private.BroadcastTaintedCoreStatus(status)
  VashjHelper:SendCommMessage("VHB_CORE", tostring(status), "RAID", nil, "ALERT")
end

function private.HandleBroadcastedTaintedCoreStatus(prefix, message, distribution, sender)
  if not DataManager.IsInRaid(sender) then return end
  local timeLooted = tonumber(message)
  if timeLooted > 0 then
    private.taintedCores[sender] = timeLooted
  else
    private.taintedCores[sender] = nil
  end
  BPGP.Fire("TaintedCoresStatusUpdate")
end

----------------------------------------
-- Public Interface
----------------------------------------

function VashjHelper.GetTaintedCoresStatus()
  return private.taintedCores
end

function private.AsyncTest()
  DataManager.UpdateSelfGetInCombat()
  private.HandleMonsterYell(nil, "The time is now! Leave none standing!")
  Coroutine:Sleep(30)
  private.HandleMonsterYell(nil, "You may want to take cover.")
  DataManager.UpdateSelfOutOfCombat()
end

function VashjHelper.Test()
  BPGP.Print("Vashj Helper: Test started!")
  Coroutine:RunAsync(private.AsyncTest)
end