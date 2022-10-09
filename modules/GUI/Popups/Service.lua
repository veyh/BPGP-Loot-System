local _, BPGP = ...

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local DataManager = BPGP.GetModule("DataManager")

DLG:Register("INITIALIZE_BPGP", {
  text = "",
  buttons = {
    {
      text = _G.ACCEPT,
      on_click = function(self, data, reason)
        DataManager.InitializeBPGP()
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  on_update = function(self, elapsed)
    if DataManager.SelfGM() and not DataManager.SelfActive() then
      self.buttons[1]:Enable()
    else
      self.buttons[1]:Disable()
    end
  end,
  on_show = function(self)
    self.text:SetFormattedText(L["Initialization requires <%s> ranked level 1 character, his Officer Note will be used to store Enforced Settings. Your Officer Note will also be overwritten with zero BPGP record."]:format(DataManager.GetGuildRank(1)))
  end,
  hide_on_escape = true,
  show_while_dead = true,
  width = 380,
})

DLG:Register("BPGP_WIPE_DATA", {
  text = L["Perform the wipe of empty BPGP data containers from the Officer Notes?"],
  buttons = {
    {
      text = _G.ACCEPT,
      on_click = function(self, data, reason)
        DataManager.WipeData()
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
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

DLG:Register("BPGP_WIPE_SETTINGS", {
  text = L["Perform the wipe of Enforced Settings container from the settings holder's Officer Note?"],
  buttons = {
    {
      text = _G.ACCEPT,
      on_click = function(self, data, reason)
        DataManager.WipeSettings()
      end,
    },
    {
      text = _G.CANCEL,
    },
  },
  hide_on_escape = true,
  show_while_dead = true,
})