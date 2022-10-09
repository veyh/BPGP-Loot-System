local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local select, tinsert, wipe, RAID_CLASS_COLORS = select, tinsert, wipe, RAID_CLASS_COLORS
local UnitInRaid, IsInInstance, GetNumGroupMembers, GetRaidRosterInfo, C_TimerAfter = UnitInRaid, IsInInstance, GetNumGroupMembers, GetRaidRosterInfo, C_Timer.After

local private = {
  numRaidMembers = 0,
  raidLeader = nil,
  masterLooter = nil,
  raidRank = {},
  raidId = {},
  class = {}, -- {PlayerName = PlayerClass} - Contains all raid members
  classColor = {}, -- {PlayerName = PlayerClass} - Contains all raid members
  updateOngoing = false,
}
Debugger.Attach("RaidDB", private)

function DataManager.UpdateRaidDB()
  Debugger("UpdateRaidDB")
  DataManager.ResetRaidDB()
  if not UnitInRaid("player") then Debugger("Not in raid") return end
  if select(2, IsInInstance()) == "pvp" then Debugger("Not in raid (on BG)") return end
  local numRaidMembers = GetNumGroupMembers()
  for i = 1, numRaidMembers do
    local playerName, rank, _, _, _, playerClass, _, online, _, _, isML = GetRaidRosterInfo(i)
    if not playerName then
      Debugger("Got empty raid roster data, retrying...")
      DataManager.ResetRaidDB()
      if not private.updateOngoing then
        Debugger("Forcing async raid roster update")
        private.updateOngoing = true
        C_TimerAfter(0.1, private.AsyncUpdateRaidDB)
      else
        Debugger("Async raid roster update is already running")
      end
      return
    end
    private.raidId[playerName] = i
    private.raidRank[playerName] = rank
    private.class[playerName] = playerClass
    private.classColor[playerName] = RAID_CLASS_COLORS[playerClass]
    if rank == 2 then
      private.raidLeader = playerName
    end
    if isML then
      private.masterLooter = playerName
    end
  end
  private.numRaidMembers = numRaidMembers
  Debugger("RaidDB updated, numRaidMembers: " .. tostring(numRaidMembers))
end

function private.AsyncUpdateRaidDB()
  private.updateOngoing = false
  Debugger("Firing GROUP_ROSTER_UPDATE...")
  BPGP.FireEvent("GROUP_ROSTER_UPDATE")
end

function DataManager.ResetRaidDB()
  private.numRaidMembers = 0
  private.raidLeader = nil
  private.masterLooter = nil
  wipe(private.raidId)
  wipe(private.raidRank)
  wipe(private.class)
  wipe(private.classColor)
end

function DataManager.GetRaidDB(tableName)
  return private[tableName]
end

function DataManager.GetNumRaidMembers()
  return private.numRaidMembers
end

function DataManager.GetRaidId(playerName)
  return private.raidId[playerName]
end

function DataManager.GetRaidRank(playerName)
  return private.raidRank[playerName]
end

function DataManager.GetRaidClass(playerName)
  return private.class[playerName]
end

function DataManager.GetRaidClassColor(playerName)
  return private.classColor[playerName]
end

function DataManager.GetRL()
  return private.raidLeader
end

function DataManager.GetML()
  return private.masterLooter
end

function DataManager.IsInRaid(playerName)
  return not not private.raidRank[playerName]
end

function DataManager.IsRL(playerName)
  return playerName == private.raidLeader
end

function DataManager.IsML(playerName)
  return playerName == private.masterLooter
end

function DataManager.IsAssist(playerName)
  return private.raidRank[playerName] == 1
end