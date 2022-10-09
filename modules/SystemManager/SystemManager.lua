local _, BPGP = ...

local SystemManager = BPGP.NewModule("SystemManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
LibStub("AceConsole-3.0"):Embed(SystemManager)

local Debugger = BPGP.Debugger

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      logSync = true,
      logTrim = false,
    },
  },
}

function SystemManager:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("SystemManager", private.dbDefaults)
  SystemManager:RegisterChatCommand("bpgp", SystemManager.HandleChatCommand)
end

function SystemManager:OnEnable()
  
end

function SystemManager:OnDisable()
  
end

function SystemManager.HandleChatCommand(str)
  str = str:gsub("%%t", UnitName("target") or "notarget")
  local command, nextpos = SystemManager:GetArgs(str, 1)
  if command == "debug" then
    Debugger:ToggleFrame()
  elseif command == "toggle_debug" then
    BPGP.ToggleDebug()
  elseif command == "vc" then
    BPGP.GetModule("ChecksManager"):RequestVersionCheck()
  elseif command == "lc" or command == "woof" or command == "whoseloot" then
    BPGP.GetModule("ChecksManager"):RequestLootCheck()
  elseif command == "cd" then
    BPGP.GetModule("GUI"):ToggleBPGPCooldownsFrame()
  elseif command == "wp" then
    BPGP.GetModule("GUI"):ToggleBPGPWipeProtectionFrame()
  elseif command == "listcd" then
    BPGP.GetModule("RaidCooldowns"):ListCooldowns()
  elseif command == "mh" then
    BPGP.GetModule("MaggyHelper").ToggleWidgetFrame()
  elseif command == "assign" then
    BPGP.GetModule("MaggyHelper").ToggleAssignmentsFrame()
  elseif command == "mhtest" then
    BPGP.GetModule("MaggyHelper").TestNovaCounter()
  elseif command == "standby" then
    BPGP.GetModule("StandbyTracker").RequestStandby()
  elseif command == "help" then
    local help = {
      BPGP.GetVersion().." "..L["Chat Commands:"],
      "/bpgp standby - "..L["Send standby request to current BPGP operator"],
      "/bpgp cd - "..L["Toggle Raid Cooldowns window"],
      "/bpgp wp - "..L["Toggle Wipe Protection window"],
      "/bpgp mh - "..L["Toggle Maggy Helper window"],
      "/bpgp assign - "..L["Toggle Maggy Helper assignments window"],
      "/bpgp lc - "..L["Start whose loot check"],
      "/bpgp vc - "..L["Start BPGP version check"],
      "/bpgp listcd - "..L["List own active raid cooldowns"],
    }
    BPGP.Print(table.concat(help, "\n"))
  else
    BPGP.ToggleUI()
  end
end
