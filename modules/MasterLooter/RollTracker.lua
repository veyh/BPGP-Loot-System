local _, BPGP = ...

local RollTracker = BPGP.NewModule("RollTracker")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger

local DataManager = BPGP.GetModule("DataManager")
local MasterLooter = BPGP.GetModule("MasterLooter")

local private = {
  dbDefaults = {
    profile = {
      enabled = false, -- Loading is managed by MasterLooter module
      cache = {
        itemLink = nil,
        results = {},
        violates = {},
      },
    },
  },
}
Debugger.Attach("RollTracker", private)

function RollTracker:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("RollTracker", private.dbDefaults)
  private.randomRollPattern = private.GetRandomRollPattern()
end

function RollTracker:OnEnable()
  Debugger("RollTracker:OnEnable()")
  if MasterLooter.db.profile.collectRollResults then
    if RollTracker.db.profile.cache.itemLink then
      self.StartTracking(RollTracker.db.profile.cache.itemLink, true)
      BPGP.GetModule("StandingsManager").SortStandings()
    end
  end
  if not DataManager.SelfInRaid() then
    self:Disable()
  end
end

function RollTracker:OnDisable()
  Debugger("RollTracker:OnDisable()")
  BPGP.UnregisterEvent("CHAT_MSG_SYSTEM", RollTracker.HandleChatMsgSystem)
  self.ResetRollResults()
end

----------------------------------------
-- Public interface
----------------------------------------

function RollTracker.ResetRollResults()
  if not RollTracker.db.profile.cache.itemLink then return end
  RollTracker.db.profile.cache.itemLink = nil
  table.wipe(RollTracker.db.profile.cache.results)
  table.wipe(RollTracker.db.profile.cache.violates)
  BPGP.UnregisterEvent("CHAT_MSG_SYSTEM", RollTracker.HandleChatMsgSystem)
end

function RollTracker.StartTracking(itemLink, withoutReset)
  if not withoutReset and MasterLooter.db.profile.resetRollResults then
    RollTracker.ResetRollResults()
  end
  BPGP.RegisterEvent("CHAT_MSG_SYSTEM", RollTracker.HandleChatMsgSystem)
  RollTracker.db.profile.cache.itemLink = itemLink
end

function RollTracker.StopTracking(itemLink)
  if itemLink ~= RollTracker.db.profile.cache.itemLink then return end
  RollTracker.ResetRollResults()
end

function RollTracker.AddRollResult(playerName, rollResult, min, max)
  if RollTracker.db.profile.cache.results[playerName] then
    RollTracker.db.profile.cache.violates[playerName] = true
  else
    RollTracker.db.profile.cache.results[playerName] = rollResult
    if min ~= 1 or max ~= 100 then
      RollTracker.db.profile.cache.violates[playerName] = true
    end
  end
  BPGP.GetModule("DistributionTracker").HandleSimpleRoll(playerName)
  BPGP.GetModule("StandingsManager").DestroyStandings()
end

function RollTracker.GetRollResult(playerName)
  return RollTracker.db.profile.cache.results[playerName], RollTracker.db.profile.cache.violates[playerName]
end

----------------------------------------
-- Event handlers
----------------------------------------

function RollTracker.HandleChatMsgSystem(event, msg)
  local playerName, rollResult, min, max = string.match(msg, private.randomRollPattern)
  if not (playerName and rollResult and min and max) then return end
  rollResult, min, max = tonumber(rollResult), tonumber(min), tonumber(max)
  RollTracker.AddRollResult(playerName, rollResult, min, max)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.GetRandomRollPattern()
  local pattern = RANDOM_ROLL_RESULT
  pattern = pattern:gsub("[%(%)%-]", "%%%1")
  pattern = pattern:gsub("%%s", "%(%.%+%)")
  pattern = pattern:gsub("%%d", "%(%%d+%)")
  pattern = pattern:gsub("%%%d%$s", "%(%.%+%)") -- for "deDE"
  pattern = pattern:gsub("%%%d%$d", "%(%%d+%)") -- for "deDE"
  return pattern
end