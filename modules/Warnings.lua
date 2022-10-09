local _, BPGP = ...

local Warnings = BPGP.NewModule("Warnings")

local DLG = LibStub("LibDialog-1.0")
LibStub("AceHook-3.0"):Embed(Warnings)

local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")

local private = {
    scriptsHooked = false,
}

function Warnings:OnEnable()
  if not private.scriptsHooked then
    Warnings:HookScripts()
  end
end

function Warnings:HookScripts()
  if GuildMemberOfficerNoteBackground and GuildMemberOfficerNoteBackground:HasScript("OnMouseUp") then
    self:RawHookScript(GuildMemberOfficerNoteBackground, "OnMouseUp", function ()
      local playerName = Common:ExtractCharacterName(GetGuildRosterInfo(GetGuildRosterSelection()))
      if DataManager.GetId(playerName) or playerName == DataManager.GetSettingsHolder() then
        DLG:Spawn("BPGP_OFFICER_NOTE_WARNING")
      else
        Warnings.hooks[GuildMemberOfficerNoteBackground]["OnMouseUp"]()
      end
    end)
  end
  private.scriptsHooked = true
end