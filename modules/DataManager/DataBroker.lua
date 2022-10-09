local _, BPGP = ...

local DataBroker = BPGP.NewModule("DataBroker")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("BPGP")
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local Debugger = BPGP.Debugger

local dataObject = LibDataBroker:NewDataObject("bpgp", {
  type = "data source",
  icon = "Interface\\Icons\\Spell_Nature_EnchantArmor",
  text = L["Idle"],
  label = "BPGP",
  OnClick = function(self, button)
    if button == "LeftButton" then
      BPGP.ToggleUI()
    end
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine("BPGP")
    tooltip:AddLine(" ")
    tooltip:AddLine(L["Left-click to toggle the BPGP window"], 0, 1, 0)
  end,
})

function DataBroker:OnAddonLoad()
  BPGP.RegisterCallback("SettingsUpdated", DataBroker.UpdateStatusText)
end

function DataBroker:OnDataLoad()
  LibDBIcon:Register("bpgp", dataObject, BPGP.db.profile.minimapIconPos)
end

----------------------------------------
-- Public interface
----------------------------------------

function DataBroker.UpdateStatusText(event, settings)
  if settings.lockState == 0 then
    dataObject.text = "|cFFFF0000"..L["Locked"].."|r"
  else
    dataObject.text = "|cFF00FF00"..L["Unlocked"].."|r"
  end
end