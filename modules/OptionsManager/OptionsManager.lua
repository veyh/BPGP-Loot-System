local _, BPGP = ...

local OptionsManager = BPGP.NewModule("OptionsManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local Debugger = BPGP.Debugger

local private = {
  options = {
    name = "BPGPConfig",
    type = "group",
    childGroups = "tab",
    handler = OptionsManager,
    args = {},
  },
}
Debugger.Attach("OptionsManager", private)

function OptionsManager.SetupOptions()
  for name, m in pairs(BPGP.GetModules()) do
    if m.GetOptions then
      local options = m.GetOptions()
      assert(not private.options[options.name])
      assert(options.name and options.order and options.desc and options.args)
      if type(options.get) == "string" or type(options.set) == "string" then assert(options.handler) end
      options.type = options.type or "group"
      options.get = options.get or "GetDBVar"
      options.set = options.set or "SetDBVar"
      private.options.args[options.name] = options
    end
  end
  AceConfigRegistry:RegisterOptionsTable("BPGPConfig", private.options)
end

--function OptionsManager.ReloadConfig()
--  AceConfigRegistry:NotifyChange("BPGPConfig")
--end
