local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local private = {
  id = nil,
  name = UnitName("player"),
  level = UnitLevel("player"),
  guildName = "Unknown",
  class = select(2, UnitClass("player")),
  localizedClass = select(1, UnitClass("player")),
  rank = "Unknown",
  rankIndex = nil,
  aboveMinimalLevel = false,
  canWriteNotes = false,
  inGuild = false,
  inRaid = false,
  inCombat = false,
  isRL = false,
  isML = false,
  isActive = false,
  isGM = false,
  isSA = false,
}
Debugger.Attach("SelfDB", private)

----------------------------------------
-- Public interface
----------------------------------------

function DataManager.GetGuildName()
  return private.guildName
end

function DataManager.GetSelfId()
  return private.id
end

function DataManager.SelfAboveMinimalLevel()
  return private.aboveMinimalLevel
end

function DataManager.GetSelfName()
  return private.name
end

function DataManager.GetSelfLevel()
  return private.level
end

function DataManager.GetSelfClass()
  return private.class
end

function DataManager.GetSelfClassLocalized()
  return private.localizedClass
end

function DataManager.SelfCanWriteNotes()
  return private.canWriteNotes
end

function DataManager.SelfInGuild()
  return private.inGuild
end

function DataManager.SelfInCombat()
  return private.inCombat
end

function DataManager.SelfInRaid()
  return private.inRaid
end

function DataManager.SelfActive()
  return private.isActive
end

function DataManager.SelfGM()
  return private.isGM
end

function DataManager.SelfRL()
  return private.isRL
end

function DataManager.SelfML()
  return private.isML
end

function DataManager.SelfSA()
  return private.isSA
end

-- Setters

function DataManager.UpdateSelfDB()
  private.isActive = DataManager.IsActive(private.name) or false
  private.id = DataManager.GetId(private.name)
  private.rank = DataManager.GetRank(private.name)
  private.rankIndex = DataManager.GetRankIndex(private.name)
  DataManager.UpdateSelfRoleGM()
end

function DataManager.UpdateSelfGetInCombat()
  private.inCombat = true
  BPGP.Fire("CombatUpdate", true)
end

function DataManager.UpdateSelfOutOfCombat()
  private.inCombat = false
  BPGP.Fire("CombatUpdate", false)
end

function DataManager.UpdateSelfRaidStatus()
  private.inRaid = DataManager.GetNumRaidMembers() > 0
  private.isRL = DataManager.IsRL(private.name)
  private.isML = DataManager.IsML(private.name)
end

function DataManager.UpdateSelfGuildStatus()
  private.inGuild = IsInGuild()
  private.guildName = GetGuildInfo("player") or ""
end

function DataManager.UpdateSelfNoteEditStatus()
  if not private.aboveMinimalLevel then
    private.level = UnitLevel("player")
    private.aboveMinimalLevel = private.level >= DataManager.GetMinimalLevel()
  end
  private.canWriteNotes = CanEditOfficerNote() and private.name ~= DataManager.GetSettingsHolder()
end

function DataManager.UpdateSelfRoleGM()
  private.isGM = private.rankIndex == 0
end

function DataManager.UpdateSelfRoleSA()
  private.isSA = DataManager.IsSA(private.name)
end
