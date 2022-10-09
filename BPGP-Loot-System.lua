local _, BPGP = ...

local select, tostring = select, tostring
local tconcat, DEFAULT_CHAT_FRAME = table.concat, DEFAULT_CHAT_FRAME

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Coroutine = BPGP.GetLibrary("Coroutine")

local AddonLoader = BPGP.NewModule("AddonLoader")

local private = {
  dbDefaults = {
    profile = {
      version = "",
      minimapIconPos = {},
      snapshot = {},
      debug = false,
    },
  },
  version = GetAddOnMetadata("BPGP-Loot-System", "Version"),
}

function AddonLoader:OnAddonLoad()
  BPGP.db = LibStub("AceDB-3.0"):New("BPGP_DB")
  BPGP.db:RegisterDefaults(private.dbDefaults)
  BPGP.db.global.version = private.version
  BPGP.SetupDebug()
end

function AddonLoader:OnDataLoad()
  Debugger.Watch()
  
  BPGP.RegisterEvent("GUILD_ROSTER_UPDATE", AddonLoader.HandleGuildRosterUpdate)
  BPGP.RegisterEvent("GROUP_ROSTER_UPDATE", AddonLoader.HandleGroupRosterUpdate)
  
  Debugger("System loading started")
  
  BPGP.GetModule("OptionsManager").SetupOptions()
  
  AddonLoader.LoadModules()
  
  AddonLoader.HandleGroupRosterUpdate()
end

function AddonLoader.LoadModules()
  for _, moduleName in ipairs(BPGP.GetModulesLoadOrder()) do
    local module = BPGP.GetModule(moduleName)
    if not module.db or module.db.profile.enabled then
      if module:IsDisabled() then
        Debugger("Autoloading module: %s", moduleName)
        module:Enable()
      else
        Debugger("Reloading module: %s", moduleName)
        module:Reload()
      end
    elseif module:IsEnabled() then
      Debugger("Unloading module: %s", moduleName)
      module:Disable()
    end
  end  
end

----------------------------------------
-- Event handlers
----------------------------------------

function AddonLoader.HandleGuildRosterUpdate()
  Debugger("Received GUILD_ROSTER_UPDATE")

  local DataManager = BPGP.GetModule("DataManager")
  
  DataManager.UpdateSelfGuildStatus()
  
  if DataManager.SelfInGuild() then
    local guildName = DataManager.GetGuildName()
    if #guildName == 0 then
      Debugger("Got empty guild data, retrying...")
      GuildRoster()
      return
    elseif BPGP.db:GetCurrentProfile() ~= guildName then
      Debugger("Setting DB profile to: %s", guildName)
      BPGP.db:SetProfile(guildName)
      AddonLoader.LoadModules()
    end
    DataManager.QueueGuildRosterUpdate()
  end
end

function AddonLoader.HandleGroupRosterUpdate()
  Debugger("Received GROUP_ROSTER_UPDATE")
  BPGP.GetModule("DataManager").UpdateRaidDB()
  BPGP.GetModule("DataManager").UpdateSelfRaidStatus()
  BPGP.GetModule("MasterLooter").SetupTrackers()
  BPGP.GetModule("StandbyTracker").UpdateData()
  BPGP.GetModule("GUI").ToggleRaidOlnyControls()
  BPGP.GetModule("StandingsManager").DestroyStandings()
  BPGP.Fire("RaidDataUpdate")
end

----------------------------------------
-- Public interface
----------------------------------------

function BPGP.GetVersion()
  return private.version
end

function BPGP.SetupDebug()
  if BPGP.db.profile.debug then
    _G.BPGP = BPGP
    Debugger.Enable()
  else
    _G.BPGP = nil
    Debugger.Disable()
  end
end

function BPGP.ToggleDebug()
  BPGP.db.profile.debug = not BPGP.db.profile.debug
  BPGP.SetupDebug()
  BPGP.Print(BPGP.db.profile.debug and L["Debug system enabled"] or L["Debug system disabled"])
end

function BPGP.ToggleUI()
  if BPGPFrame then
    if BPGPFrame:IsShown() then
      BPGPFrame:Hide()
    else
      BPGPFrame:Show()
    end
  end
end

function BPGP.Print(...)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff8000".."BPGP".."|r: " .. tconcat({Debugger.ArgsToString(...)}, " "))
end

function BPGP.Printf(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage("|cffff8000".."BPGP".."|r: " .. Debugger.SafeFormat(fmt, ...))
end
