local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local assert, tostring, pairs, select, tinsert, tremove, wipe = assert, tostring, pairs, select, tinsert, table.remove, wipe
local GetNumGuildMembers, GuildControlGetNumRanks = GetNumGuildMembers, GuildControlGetNumRanks
local GuildControlGetRankName, GetGuildRosterInfo = GuildControlGetRankName, GetGuildRosterInfo
local GuildRosterSetOfficerNote, RAID_CLASS_COLORS = GuildRosterSetOfficerNote, RAID_CLASS_COLORS

local private = {
  settingsHolder = nil,
  pending = {
    settings = false,
    updated = {},
    removed = {},
  },
  index = {}, -- {PlayerName = PlayerIndex} - Contains all guild members
  level = {}, -- {PlayerName = PlayerLevel} - Contains all guild members
  class = {}, -- {PlayerName = PlayerClass} - Contains all guild members
  classColor = {}, -- {PlayerName = PlayerClassColor} - Contains all guild members
  rank = {}, -- {PlayerName = PlayerRank} - Contains all guild members
  rankIndex = {}, -- {PlayerName = PlayerRankIndex} - Contains all guild members
  note = {}, -- {PlayerName = PlayerNote} - Contains all guild members
  stale = {}, -- {PlayerName = bool} - Contains all guild members
  guildRank = {}, -- {RankIndex = RankName} -- Contains all guild ranks, 0-9
}
Debugger.Attach("GuildDB", private)

----------------------------------------
-- Public interface
----------------------------------------

function DataManager.GetUpdatedData()
  return private.pending
end

function DataManager.GetGuildDB(tableName)
  return private[tableName]
end

function DataManager.GetNameByIndex(playerIndex)
  return Common:Find(private.index, playerIndex)
end

function DataManager.IsInGuild(playerName)
  return not not private.index[playerName]
end

--function DataManager.IsOnline(playerName)
--  return select(9, GetGuildRosterInfo(private.index[playerName]))
--end

function DataManager.GetClass(playerName)
  return private.class[playerName] or DataManager.GetRaidClass(playerName)
end

function DataManager.GetClassColor(playerName)
  return private.classColor[playerName] or DataManager.GetRaidClassColor(playerName)
end

function DataManager.GetRank(playerName)
  return private.rank[playerName] or L["< Not in guild >"]
end

function DataManager.GetRankIndex(playerName)
  return private.rankIndex[playerName]
end

function DataManager.GetNote(playerName)
  return private.note[playerName]
end

function DataManager.GetSettingsHolder()
  return private.settingsHolder
end

function DataManager.GetGuildRank(rankIndex)
  return private.guildRank[rankIndex]
end

function DataManager.UpdateGuildDB()
  local numGuildMembers = GetNumGuildMembers()
  if numGuildMembers == 0 then return end
  
  local dataUpdated = false
  
  -- Cache guild ranks
  for i = 1, 10 do
    if private.guildRank[i - 1] ~= GuildControlGetRankName(i) then
      local rankName = GuildControlGetRankName(i) or ""
      if rankName ~= "" then
        private.guildRank[i - 1] = rankName
        BPGP.Debugger("Registered guild rank #%d '%s'", i, rankName)
      elseif private.guildRank[i - 1] then
        tremove(private.guildRank, i - 1)
        BPGP.Debugger("Removed guild rank #%d '%s'", i, rankName)
      end
      private.pending.settings = true
      dataUpdated = true
    end
  end
  
  -- Cache guild roster
  local settingsHolders, seen = {}, {}
  for index = 1, numGuildMembers do
    local playerName, rank, rankIndex, level, _, _, _, note, _, _, class = GetGuildRosterInfo(index)
    if playerName then
      playerName = Common:ExtractCharacterName(playerName)
      if level >= DataManager.GetMinimalLevel() or rankIndex <= 1 then
        if level == 1 and rankIndex == 1 then
          tinsert(settingsHolders, playerName)
        end
        private.index[playerName] = index
        if private.note[playerName] ~= note or private.rankIndex[playerName] ~= rankIndex or private.level[playerName] ~= level then
          private.pending.updated[playerName] = true
          private.level[playerName] = level
          private.class[playerName] = class
          private.classColor[playerName] = RAID_CLASS_COLORS[class]
          private.rank[playerName] = rank
          private.rankIndex[playerName] = rankIndex
          private.note[playerName] = note
          private.stale[playerName] = false
          dataUpdated = true
        end
        seen[playerName] = true
      end
    end
  end
  if dataUpdated or not private.settingsHolder then
    -- Detect settings handler and settings update
    if #settingsHolders == 1 then
      if not private.settingsHolder then
        private.pending.settings = true
      end
      private.settingsHolder = settingsHolders[1]
      if private.pending.updated[private.settingsHolder] then
        private.pending.settings = true
        private.pending.updated[private.settingsHolder] = nil
      end
    else
      local holderRank = GuildControlGetRankName(2)
      DataManager.ResetAlerts()
      if #settingsHolders == 0 then
        DataManager.NewAlert("BPGP", L["Failed to load BPGP data! No settings holder (level 1 character with rank %s) found."]:format(holderRank))
      elseif #settingsHolders > 1 then
        DataManager.NewAlert("BPGP", L["Failed to load BPGP data! Multiple settings holders (level 1 characters with rank %s) found."]:format(holderRank))
        for i = 1, #settingsHolders do private.pending.updated[settingsHolders[i]] = nil end
      end
      private.settingsHolder = nil
      private.pending.settings = true
    end
    -- Force roster re-read if settings changed
    if private.pending.settings then
      for playerName in pairs(private.index) do
        if not Common:FindNext(settingsHolders, playerName) then
          private.pending.updated[playerName] = true
        end
      end
    end
  end
  -- Leaved or kicked players cleanup
  for playerName in pairs(private.index) do
    if not seen[playerName] then
      private.index[playerName] = nil
      private.level[playerName] = nil
      private.class[playerName] = nil
      private.classColor[playerName] = nil
      private.rank[playerName] = nil
      private.rankIndex[playerName] = nil
      private.note[playerName] = nil
      private.stale[playerName] = nil
      if playerName == private.settingsHolder then
        private.settingsHolder = nil
        private.pending.settings = true
      else
        private.pending.removed[playerName] = true
      end
      dataUpdated = true
    end
  end
  -- Data integrity safeguarding
  for playerName, isStale in pairs(private.stale) do
    if isStale then
      dataUpdated = false -- We are not up to date until all write results are received
    end
  end
  if dataUpdated then
    wipe(private.stale)
  end

  return dataUpdated
end

function DataManager.SetNote(playerName, note, isBatchWrite)
  if not isBatchWrite then
    assert(DataManager.IsAllowedDataWrite(), "Failed to write data: DataManager is write-locked!")
  end
  if private.stale[playerName] then
    private.stale[playerName] = false
    BPGP.Printf("Failed to write previous note for %s (current note: %s, new note: %s)! Please report this error.", playerName, private.note[playerName], note)
  end  
  local index = private.index[playerName]
  assert(index, "Failed to write Officer Note: "..tostring(playerName).." is not found!")
  if note == private.note[playerName] then return end
  Debugger("Overwriting note for "..playerName.." ["..tostring(private.note[playerName]).."]->["..tostring(note).."]")
  DataManager.WriteLock()
  private.stale[playerName] = true
  GuildRosterSetOfficerNote(index, note)
end
