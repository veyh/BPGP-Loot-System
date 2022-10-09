local _, BPGP = ...

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local DataManager = BPGP.GetModule("DataManager")

DLG:Register("BPGP_BOSS_KILLED", {
  buttons = {
    {
      text = L["Award BP"],
      on_click = function(self, data, reason)
        DataManager.MassAwardBP(data, DataManager.GetBPAward())
      end,
    },
  },
  on_show = function(self, data)
    self.text:SetFormattedText(string.format("%s".."\n\n".."|cFF00FF00".."%s %s".."|r", L["%s is defeated!"], L["Unlocked table:"], DataManager.GetUnlockedTableName()), data)
  end,
  on_hide = function(self, data)
    if ChatEdit_GetActiveWindow() then
      ChatEdit_FocusActiveWindow()
    end
  end,
  on_update = function(self, elapsed)
    if DataManager.IsAllowedIncBPGPByX(self.data, DataManager.GetBPAward()) then
      self.buttons[1]:Enable()
    else
      self.buttons[1]:Disable()
    end
  end,
  show_while_dead = true,
})