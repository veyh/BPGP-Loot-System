local _, BPGP = ...

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local DataManager = BPGP.GetModule("DataManager")

DLG:Register("BPGP_RESET_BPGP", {
  text = "",
  buttons = {
    {
      text = L["Reset"],
      on_click = function(self, data, reason)
        DataManager.ResetBPGP(true, true)
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  on_show = function(self)
    self.text:SetFormattedText(L["Table %s BP & GP reset"]:format(DataManager.GetUnlockedTableName()))
  end,
  on_update = function(self, elapsed)
    if DataManager.IsAllowedDataWrite() then
      self.buttons[1]:Enable()
    else
      self.buttons[1]:Disable()
    end
  end,
  hide_on_escape = true,
  show_while_dead = true,
})

DLG:Register("BPGP_RESET_BP", {
  text = "",
  buttons = {
    {
      text = L["Reset"],
      on_click = function(self, data, reason)
        DataManager.ResetBPGP(true, false)
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  on_show = function(self)
    self.text:SetFormattedText(L["Table %s BP reset"]:format(DataManager.GetUnlockedTableName()))
  end,
  on_update = function(self, elapsed)
    if DataManager.IsAllowedDataWrite() then
      self.buttons[1]:Enable()
    else
      self.buttons[1]:Disable()
    end
  end,
  hide_on_escape = true,
  show_while_dead = true,
})

DLG:Register("BPGP_RESET_GP", {
  text = "",
  buttons = {
    {
      text = L["Reset"],
      on_click = function(self, data, reason)
        DataManager.ResetBPGP(false, true)
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  on_show = function(self)
    self.text:SetFormattedText(L["Table %s GP reset"]:format(DataManager.GetUnlockedTableName()))
  end,
  on_update = function(self, elapsed)
    if DataManager.IsAllowedDataWrite() then
      self.buttons[1]:Enable()
    else
      self.buttons[1]:Disable()
    end
  end,
  hide_on_escape = true,
  show_while_dead = true,
})