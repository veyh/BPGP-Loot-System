local _, BPGP = ...

local StandingsManager = BPGP.NewModule("StandingsManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local RollTracker = BPGP.GetModule("RollTracker")
local DistributionTracker = BPGP.GetModule("DistributionTracker")
local StandbyTracker = BPGP.GetModule("StandbyTracker")

local math, type, pairs, ipairs = math, type, pairs, ipairs
local table, tinsert, wipe = table, tinsert, wipe

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      tableId = 1,
      filterMode = 3,
      sort = {
        sequence = {"INDEX"},
        directions = {["INDEX"]=true},
      },
    },
  },
  standings = {},
  filterModes = {L["All"], L["Raid"], L["Mains"], L["Alts"], L["Active"], L["Inactive"], L["Roll"], L["Standby"], L["Alerts"]},
  guiUpdatePending = true,
  sortSequence = nil,
}
Debugger.Attach("StandingsManager", private)

function StandingsManager:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("StandingsManager", private.dbDefaults)
  private.ApplySortSequence()
end

function StandingsManager:OnEnable()
end

----------------------------------------
-- Public interface
----------------------------------------

function StandingsManager.GetTableId()
  return StandingsManager.db.profile.tableId
end

function StandingsManager.GetFilterMode()
  return StandingsManager.db.profile.filterMode
end

function StandingsManager.GetFilterModes()
  return private.filterModes
end

function StandingsManager.SetFilter(filterMode)
  StandingsManager.db.profile.filterMode = filterMode
  StandingsManager.DestroyStandings()
end

function StandingsManager.SetTableId(tableId)
  StandingsManager.db.profile.tableId = tableId
  StandingsManager.DestroyStandings()
end

function StandingsManager.RegisterGuiUpdate()
  if not private.guiUpdatePending then return false end
  private.guiUpdatePending = false
  return true
end

function StandingsManager.GetNumMembers()
  if #private.standings == 0 then
    private.RefreshStandings()
  end
  return #private.standings
end

function StandingsManager.GetMember(i)
  if #private.standings == 0 then
    private.RefreshStandings()
  end
  return private.standings[i]
end

function StandingsManager.GetMemberStatus(playerName)
  local status1, status2 = 0, 0
  if DataManager.IsInRaid(playerName) then
    status1 = 1
  elseif StandbyTracker.IsEnlisted(playerName) then
    status1 = 2
  end
  if DataManager.GetAlerts(playerName) then
    status2 = 1
  elseif StandbyTracker.IsPending(playerName) then
    status2 = 2
  end
  return status1, status2
end

function StandingsManager.DestroyStandings()
  wipe(private.standings)
  private.guiUpdatePending = true
end

function StandingsManager.GetAverageBPGP()
  local totalBP, totalGP, numMembers = 0, 0, 0
  for playerName in pairs(DataManager.GetPlayersDB("id")) do
    local bp, gp = DataManager.GetBPGP(playerName, StandingsManager.GetTableId())
    totalBP = totalBP + bp
    totalGP = totalGP + gp
    numMembers = numMembers + 1
  end
  if numMembers == 0 then return 0, 0 end
  return totalBP / numMembers, totalGP / numMembers
end

function StandingsManager.SortStandings(order)
  local sequence = StandingsManager.db.profile.sort.sequence
  if sequence[1] == order then
    -- User clicked same column header, reversing sort direction
    StandingsManager.db.profile.sort.directions[order] = not StandingsManager.db.profile.sort.directions[order]
  else
    if order then
      -- Got new sorting order, updating applied sorting orders history
      assert(private.sortValues[order], "Unknown sort order"..tostring(order))
      -- Primary sorting order was changed, we need to build the sequence anew
      local newSequence = {order}
      StandingsManager.db.profile.sort.directions[order] = true
      -- Here we add previously used sorts to the new sequence, while skipping new one if found - it goes first now
      for i = 1, #sequence do
        if sequence[i] ~= order then
          table.insert(newSequence, sequence[i])
        end
      end
      StandingsManager.db.profile.sort.sequence = newSequence
      -- Converting sorts history sequence into sorting function readable format
      private.ApplySortSequence()
    else
      -- New order is not specified, table will be sorted using current sort sequence
    end
  end
  StandingsManager.DestroyStandings()
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.RefreshStandings()
  Debugger("Refreshing standings")
  
  -- Filter modes: {"All", "Raid", "Active", "Inactive", "Alts", "Standby"}
  local filterMode = StandingsManager.GetFilterMode()
  local dataTables, filterFunction, includePugs = nil, nil, false
  if filterMode == 1 then
    -- "All" includes all guild members, both with and without points, as well as alts
    dataTables = {"active", "inactive"}
    includePugs = true
  elseif filterMode == 2 then
    -- "Raid" includes all raid members that are in the guild, standby list and standby requests
    dataTables = {"active", "inactive"}
    includePugs = true
    filterFunction = function (playerName)
      return DataManager.IsInRaid(playerName) or StandbyTracker.IsEnlisted(playerName) or StandbyTracker.IsPending(playerName)
    end
  elseif filterMode == 3 then
    -- "Mains" includes guild members with points
    dataTables = {"active", "inactive"}
    filterFunction = function (playerName)
      return not DataManager.IsAltRankIndex(DataManager.GetRankIndex(playerName)) and not DataManager.GetMain(playerName)
    end
  elseif filterMode == 4 then
    -- "Alts" includes guild members with alt rank (see settings) and alts with assigned main ('@'-marked)
    dataTables = {"active", "inactive"}
    filterFunction = function (playerName)
      return DataManager.GetMain(playerName) or DataManager.IsAltRankIndex(DataManager.GetRankIndex(playerName))
    end
  elseif filterMode == 5 then
    -- "Active" includes guild members with at least 1 BP/GP point and alts with assigned main ('@'-marked)
    dataTables = {"active"}
  elseif filterMode == 6 then
    -- "Inactive" includes guild members without any BP/GP points and alts without assigned main
    dataTables = {"inactive"}
  elseif filterMode == 7 then
    -- "Roll" includes raid members that rolled for item announce
    dataTables = {"active", "inactive"}
    includePugs = true
    filterFunction = function (playerName)
      return RollTracker.GetRollResult(playerName)
    end
  elseif filterMode == 8 then
    -- "Standby" includes guild members that are already in standby list or sent standby request
    dataTables = {"active", "inactive"}
    filterFunction = function (playerName)
      return StandbyTracker.IsEnlisted(playerName) or StandbyTracker.IsPending(playerName)
    end
  elseif filterMode == 9 then
    -- "Alerts" includes guild members with found data issues, like inexistent main for alt
    local alerts = DataManager.GetAlerts()
    dataTables = {"active", "inactive"}
    filterFunction = function (playerName)
      return alerts[playerName]
    end
  end
  
  for i = 1, #dataTables do
    for playerName in pairs(DataManager.GetPlayersDB(dataTables[i])) do
      if not filterFunction or filterFunction(playerName) then
        tinsert(private.standings, playerName)
      end
    end
  end
  
  if includePugs then
    for playerName in pairs(DataManager.GetRaidDB("raidRank")) do
      if not DataManager.IsInGuild(playerName) and (not filterFunction or filterFunction(playerName)) then
        tinsert(private.standings, playerName)
      end
    end
  end
  
  table.sort(private.standings, private.Comparator)
end

function private.ApplySortSequence()
  -- This sequence will be used by sorting function
  private.sortSequence = {"InRaid", "InStandby"} -- Raid and standby members always go first
  -- Some sorts are complex, here we include the subsequences from the specs
  for i, sequence in ipairs(StandingsManager.db.profile.sort.sequence) do
    for i, sort in ipairs(private.sortSequences[sequence]) do
      table.insert(private.sortSequence, sort)
    end
  end
end

function private.Comparator(a, b, recursionLevel)
  -- Acquiring sorting order based on recursion level
  local order = private.sortSequence[recursionLevel or 1]
  -- We have run through the entire sort orders sequence but values are still equal
  if not order then return false end
  -- Acquiring values to compare based on specified sorting type
  local valueA, valueB = private.sortValues[order](a, b)
  -- Values are equal for this recursion level sorting conditions, we will try to go deeper
  if valueA == valueB then
    return private.Comparator(a, b, (recursionLevel or 1) + 1)
  end
  -- Values are not equal, we can compare them based in their type (boolean, int, string)
  if StandingsManager.db.profile.sort.directions[order] then
    if type(valueA) == "boolean" then
      return not valueA
    else
      return valueA > valueB
    end
  else
    if type(valueA) == "boolean" then
      return valueA
    else
      return valueA < valueB
    end
  end
end

private.sortSequences = {
  CLASS = {"CLASS"},
  NAME = {"NAME"},
  BP = {"BP"},
  GP = {"GP"},
  INDEX = {"INDEX", "DISTRIBUTION", "ROLL"},
  DISTRIBUTION = {"DISTRIBUTION", "INDEX", "ROLL"},
  ROLL = {"ROLL", "DISTRIBUTION", "INDEX"},
}

private.sortValues = {
  CLASS = function(a, b) return DataManager.GetClass(b), DataManager.GetClass(a) end, -- Reversing for alphabetical sort
  NAME = function(a, b) return b, a end, -- Reversing for alphabetical sort
  BP = function(a, b)
    local bpA = DataManager.GetBPGP(a, StandingsManager.db.profile.tableId)
    local bpB = DataManager.GetBPGP(b, StandingsManager.db.profile.tableId)
    return bpA, bpB
  end,
  GP = function(a, b)
    local bpA, gpA = DataManager.GetBPGP(a, StandingsManager.db.profile.tableId)
    local bpB, gpB = DataManager.GetBPGP(b, StandingsManager.db.profile.tableId)
    return gpA, gpB
  end,
  INDEX = function(a, b)
    local bpA, gpA = DataManager.GetBPGP(a, StandingsManager.db.profile.tableId)
    local bpB, gpB = DataManager.GetBPGP(b, StandingsManager.db.profile.tableId)
    return DataManager.CalculateIndex(bpA, gpA), DataManager.CalculateIndex(bpB, gpB)
  end,
  DISTRIBUTION = function(a, b)
    return DistributionTracker.GetDistributionPriority(b), DistributionTracker.GetDistributionPriority(a)
  end,
  ROLL = function(a, b) return RollTracker.GetRollResult(a) or 0, RollTracker.GetRollResult(b) or 0 end,
  InRaid = function(a, b) return DataManager.IsInRaid(a), DataManager.IsInRaid(b) end,
  InStandby = function(a, b) return StandbyTracker.IsEnlisted(a), StandbyTracker.IsEnlisted(b) end,
}
