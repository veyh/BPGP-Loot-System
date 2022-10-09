local _, BPGP = ...

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local DataManager = BPGP.GetModule("DataManager")

DLG:Register("BPGP_DECAY_BPGP", {
  buttons = {
    {
      text = _G.ACCEPT,
      on_click = function(self, data, reason)
        DataManager.DecayBPGP()
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  on_show = function(self, data)
    self.text:SetFormattedText(L["Decay BP and GP by %d%%?"], data)
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

DLG:Register("BPGP_RESCALE_BP", {
  text = "",
  buttons = {
    {
      text = L["Rescale"],
      on_click = function(self, data, reason)
        DataManager.RescaleBPGP(true, false, tonumber(self.editboxes[1]:GetText()))
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  editboxes = {
    {
      auto_focus = true,
    },
  },
  on_show = function(self)
    self.text:SetFormattedText(L["Table %s BP rescale"]:format(DataManager.GetUnlockedTableName()).."\n"..L["Please input a rescale factor (e.g. 0.7 or 2)"])
    self.editboxes[1]:SetText("1")
    self.editboxes[1]:HighlightText()
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

DLG:Register("BPGP_RESCALE_GP", {
  text = "",
  buttons = {
    {
      text = L["Rescale"],
      on_click = function(self, data, reason)
        DataManager.RescaleBPGP(false, true, tonumber(self.editboxes[1]:GetText()))
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  editboxes = {
    {
      auto_focus = true,
    },
  },
  on_show = function(self)
    self.text:SetFormattedText(L["Table %s GP rescale"]:format(DataManager.GetUnlockedTableName()).."\n"..L["Please input a rescale factor (e.g. 0.7 or 2)"])
    self.editboxes[1]:SetText("1")
    self.editboxes[1]:HighlightText()
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

DLG:Register("BPGP_RESCALE_BPGP", {
  text = "",
  buttons = {
    {
      text = L["Rescale"],
      on_click = function(self, data, reason)
        DataManager.RescaleBPGP(true, true, tonumber(self.editboxes[1]:GetText()))
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  editboxes = {
    {
      auto_focus = true,
    },
  },
  on_show = function(self)
    self.text:SetFormattedText(L["Table %s BP & GP rescale"]:format(DataManager.GetUnlockedTableName()).."\n"..L["Please input a rescale factor (e.g. 0.7 or 2)"])
    self.editboxes[1]:SetText("1")
    self.editboxes[1]:HighlightText()
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