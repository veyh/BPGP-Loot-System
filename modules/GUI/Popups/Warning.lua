local _, BPGP = ...

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

DLG:Register("BPGP_OFFICER_NOTE_WARNING", {
  text = L["BPGP is using this Officer Note to store encrypted data container. Any manual edit WILL cause data loss."],
  icon = [[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]],
  buttons = {
    {
      text = _G.CANCEL,
    },
  },
  hide_on_escape = true,
  show_while_dead = true,
})
