local _, BPGP = ...

local RaidCooldowns = BPGP.NewModule("RaidCooldowns")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
LibStub("AceComm-3.0"):Embed(RaidCooldowns)

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local AnnounceSender = BPGP.GetModule("AnnounceSender")
local DataManager = BPGP.GetModule("DataManager")
local MasterLooter = BPGP.GetModule("MasterLooter")

local ipairs, pairs, tostring, tonumber, strsplit = ipairs, pairs, tostring, tonumber, strsplit
local GetServerTime = GetServerTime

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      cache = {
        broadcastedCooldowns = {},
        broadcastedProtections = {}, -- Rebirth, DI and SS
      },
    },
  },
  raidCooldownsList = {
--    ["MAGE"] = {{12051}, {120, 8492, 10159, 10160, 10161}, {122, 865, 6131, 10230}}, -- FOR TESTING ONLY!
--    ["HUNTER"] = {{19263}, {1499, 14310, 14311}, {20906}}, -- FOR TESTING ONLY! Deterrence, Freezing Trap
    ["DRUID"] = {{29166}, {20484, 20739, 20742, 20747, 20748, 26994}}, -- Innervate, Rebirth
    ["PALADIN"] = {{19752}, {642, 1020}, {1022, 5599, 10278}, {633, 2800, 10310, 27154}}, -- DI, DS, BoP, LoH
    ["PRIEST"] = {{10060}}, -- Power Infusion
    ["WARLOCK"] = {{20707, 20762, 20763, 20764, 20765, 27239}}, -- SS
    ["WARRIOR"] = {{871}, {12975}, {1161}}, -- Shield Wall, Last Stand, Challenging Shout
    ["SHAMAN"] = {{2825}, {32182}, {16190}, {20608}}, -- Bloodlust, Heroism, Mana Tide, Reincarnation
  },
  wipeProtectionsList = {
--    ["HUNTER"] = 20906, -- FOR TESTING ONLY!
    ["DRUID"] = 26994, -- Rebirth
    ["PALADIN"] = 19752, -- DI
    ["WARLOCK"] = 27239, -- SS
--    ["SHAMAN"] = 20608, -- Reincarnation -- Uses simplified logic
  },
  trackedProtection = nil,
  trackedCooldowns = {}, -- List of spell ids to be tracked for this character
  trackedCooldownsDecoder = {}, -- Returns spell id of max rank for any tracked spell id
  trackedCooldownsDurations = {}, -- List of cooldowns durations, builds based on raidCooldownsList
  broadcastDelay = 0, -- Delay before tracked cooldowns broadcasting, prevents spam on major raid roster changes
  broadcastedCooldowns = nil, -- Shortcut for broadcasted cooldowns DB table
  broadcastedProtections = nil,
  cooldowns = nil, -- Shortcut for player's cooldowns DB table
  spellcastTargets = {},
  trackingDisabled = false, -- Prevents cooldown tracking for unsupported class
}
Debugger.Attach("RaidCooldowns", private)

----------------------------------------
-- Core module methods
----------------------------------------

function RaidCooldowns:OnAddonLoad()
  -- Setup DB
  self.db = BPGP.db:RegisterNamespace("RaidCooldowns", private.dbDefaults)
  private.broadcastedCooldowns = RaidCooldowns.db.profile.cache.broadcastedCooldowns
  private.broadcastedProtections = RaidCooldowns.db.profile.cache.broadcastedProtections
  -- Clean up stale DB entries
  local serverTime = GetServerTime()
  for playerName, cooldowns in pairs(private.broadcastedCooldowns) do
    for spellId, timeEnd in pairs(cooldowns) do
      if timeEnd < serverTime then
        private.broadcastedCooldowns[playerName][spellId] = nil
        if private.broadcastedProtections[spellId] then
          private.broadcastedProtections[spellId][timeEnd] = nil
        end
      end
    end
    if not next(private.broadcastedCooldowns[playerName]) then
      private.broadcastedCooldowns[playerName] = nil
    end
  end
  -- Setup wipe protection
  for class, spellId in pairs(private.wipeProtectionsList) do
    if not private.broadcastedProtections[spellId] then
      private.broadcastedProtections[spellId] = {}
    end
  end
  private.trackedProtection = private.wipeProtectionsList[DataManager.GetSelfClass()]
  -- Setup or disable cooldown tracking
  if private.raidCooldownsList[DataManager.GetSelfClass()] then
    -- Create new entry for self
    if not private.broadcastedCooldowns[DataManager.GetSelfName()] then
      private.broadcastedCooldowns[DataManager.GetSelfName()] = {}
    end
    private.cooldowns = private.broadcastedCooldowns[DataManager.GetSelfName()]
    -- Setup cooldown tracking
    for _, cooldownGroup in ipairs(private.raidCooldownsList[DataManager.GetSelfClass()]) do
      for _, spellId in ipairs(cooldownGroup) do
        private.trackedCooldowns[spellId] = true
        private.trackedCooldownsDecoder[spellId] = cooldownGroup[#cooldownGroup]
        private.trackedCooldownsDurations[spellId] = GetSpellBaseCooldown(spellId) / 1000
      end
    end
--    private.trackedCooldownsDurations[20906] = 1800
    if DataManager.GetSelfClass() == "WARLOCK" then
      -- Override warlock SS cooldowns durations
      for i, spellId in ipairs(private.raidCooldownsList["WARLOCK"][1]) do
        private.trackedCooldownsDurations[spellId] = 1800
      end
    elseif DataManager.GetSelfClass() == "PALADIN" or DataManager.GetSelfClass() == "SHAMAN" then
      BPGP.RegisterEvent("PLAYER_ENTERING_WORLD", private.HandlePlayerEnteringWorld)
    end
    if DataManager.GetSelfClass() == "SHAMAN" then
      BPGP.RegisterEvent("PLAYER_ALIVE", private.HandlePlayerAlive)
    end
  else
    private.trackingDisabled = true
  end
end

function RaidCooldowns:OnEnable()
  self:RegisterComm("BPGPRCD", private.HandleRaidCD)
  if private.trackingDisabled then
    Debugger("Cooldown tracking for class %s is disabled", DataManager.GetSelfClass())
    return 
  end
  BPGP.RegisterEvent("GROUP_ROSTER_UPDATE", private.HandleGroupRosterUpdate)
  private.HandleGroupRosterUpdate()
  BPGP.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", private.HandleSpellcastSuccess, "player")
  if private.trackedProtection then
    BPGP.RegisterEvent("UNIT_SPELLCAST_SENT", private.HandleSpellcastSent)
  end
  Debugger("Started cooldown tracking")
end

function RaidCooldowns:OnDisable()
  self:UnregisterComm("BPGPRCD", private.HandleRaidCD)
  table.wipe(RaidCooldowns.db.profile.cache.broadcastedCooldowns)
  if private.trackingDisabled then return end
  BPGP.UnregisterEvent("GROUP_ROSTER_UPDATE", private.HandleGroupRosterUpdate)
  BPGP.UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED", private.HandleSpellcastSuccess, "player")
  if private.trackedProtection then
    BPGP.UnregisterEvent("UNIT_SPELLCAST_SENT", private.HandleSpellcastSent)
  end
  Debugger("Stopped cooldown tracking")
end

----------------------------------------
-- Event handlers
----------------------------------------

function private.HandlePlayerEnteringWorld()
  if DataManager.GetSelfClass() == "PALADIN" then
    -- Override paladin BoP cooldowns based on talents
    local guardiansFavorRank = tonumber(select(5, GetTalentInfo(2, 4)) or 0)
    for i, spellId in ipairs(private.raidCooldownsList["PALADIN"][3]) do
      private.trackedCooldownsDurations[spellId] = GetSpellBaseCooldown(spellId) / 1000 - 60 * guardiansFavorRank
    end
    -- Override paladin LoH cooldowns based on talents
    local improvedLoHRank = tonumber(select(5, GetTalentInfo(1, 7)) or 0)
    for i, spellId in ipairs(private.raidCooldownsList["PALADIN"][4]) do
      private.trackedCooldownsDurations[spellId] = GetSpellBaseCooldown(spellId) / 1000 - 600 * improvedLoHRank
    end
  end
  if DataManager.GetSelfClass() == "SHAMAN" then
    -- Override shaman Reincarnation cooldowns based on talents
    local improvedReincarnationRank = tonumber(select(5, GetTalentInfo(3, 3)) or 0)
    for i, spellId in ipairs(private.raidCooldownsList["SHAMAN"][3]) do
      private.trackedCooldownsDurations[spellId] = GetSpellBaseCooldown(spellId) / 1000 - 600 * improvedReincarnationRank
    end
  end
end
  
function private.HandleSpellcastSent(event, unitId, target, spellLineID, spellId)
  if spellId ~= private.trackedProtection then return end
--  target = "Spectriel" 20906
  private.spellcastTargets[spellLineID] = target
end

function private.HandleSpellcastSuccess(event, unitId, spellLineID, spellId)
  if not private.trackedCooldowns[spellId] then return end
  spellId = private.trackedCooldownsDecoder[spellId]
  local cooldown, target = GetServerTime() + private.trackedCooldownsDurations[spellId], nil
  private.cooldowns[spellId] = cooldown
  
  if private.trackedProtection then
    target = private.spellcastTargets[spellLineID]
    if target then
      private.broadcastedProtections[spellId][cooldown] = target
      private.spellcastTargets[spellLineID] = nil
    end
  end

  if DataManager.SelfInRaid() then
    RaidCooldowns.BroadcastCooldown(spellId, target)
  end
end

function private.HandleGroupRosterUpdate()
  if not private.trackingDisabled and DataManager.SelfInRaid() then
    RaidCooldowns.BroadcastCooldowns()
  end
end

function private.HandleRaidCD(prefix, message, distribution, sender)
  if sender == DataManager.GetSelfName() or not DataManager.SelfInRaid() then return end
  local spellId, endTime, target = strsplit(",", message)
  if not private.broadcastedCooldowns[sender] then
    private.broadcastedCooldowns[sender] = {}
  end
  spellId, endTime = tonumber(spellId), tonumber(endTime)
  private.broadcastedCooldowns[sender][spellId] = endTime
  if target ~= "0" and target and private.broadcastedProtections[spellId] then
    private.broadcastedProtections[spellId][endTime] = target
  end
end
-- Dedicated Reincarnation handling logic due to no UNIT_SPELLCAST_SUCCEEDED event for it
function private.HandlePlayerAlive()
  if private.cooldowns[20608] then
    local duration = private.cooldowns[20608] - GetServerTime()
    if duration > 3600 then -- Bugfix for 1.0.4 invalid Reinc timers
      local start, duration, enabled = GetSpellCooldown(20608)
      duration = duration - math.floor(GetTime() - start)
      if duration > 3600 then duration = 0 end
      private.cooldowns[20608] = GetServerTime() + duration
    end
    if duration > 0 then
      return
    end
  end
  Coroutine:RunAsync(private.AsyncHandlePlayerAlive)
end
-- GetSpellCooldown sometimes fails to detect cooldown right after Reincarnation, async handling required
function private.AsyncHandlePlayerAlive(event, bossName)
  for i = 1, 100 do -- 10 sec timeout just to be safe, usually we expect result within 100 ms
    local start, duration, enabled = GetSpellCooldown(20608)
    if start > 0 then 
      local offset = math.floor(GetTime() - start)
      if offset > 10 or offset < 0 then offset = 0 end -- Ignore invalid offset when Blizz fucks up as always
      local cooldown = GetServerTime() + private.trackedCooldownsDurations[20608] - offset
      private.cooldowns[20608] = cooldown
      if DataManager.SelfInRaid() then
        RaidCooldowns.BroadcastCooldown(20608, nil)
      end
      break
    end
    Coroutine:Sleep(0.1)
  end
end

----------------------------------------
-- Public interface
----------------------------------------

function RaidCooldowns.BroadcastCooldown(spellId, target)
  RaidCooldowns:SendCommMessage("BPGPRCD", string.format("%d,%d,%s", spellId, private.cooldowns[spellId], target or "0"), "RAID", nil, "BULK")
end

function RaidCooldowns.BroadcastCooldowns()
  if private.broadcastDelay == 0 then
    private.broadcastDelay = 5
    Coroutine:RunAsync(private.AsyncBroadcastCooldowns)
  else
    private.broadcastDelay = 5
  end
end

function private.AsyncBroadcastCooldowns()
  while private.broadcastDelay > 0 do
    Coroutine:Sleep(1)
    private.broadcastDelay = private.broadcastDelay - 1
  end
  local serverTime = GetServerTime()
  for spellId, endTime in pairs(private.cooldowns) do
    if endTime > serverTime then
      local target = nil
      if spellId == private.trackedProtection then
        target = private.broadcastedProtections[spellId][endTime]
      end
      RaidCooldowns.BroadcastCooldown(spellId, target)
    end
  end
end

function RaidCooldowns.GetTrackedCooldownsList()
  return private.raidCooldownsList
end

function RaidCooldowns.GetCooldowns()
  return private.broadcastedCooldowns
end

function RaidCooldowns.GetProtections()
  return private.broadcastedProtections
end

function RaidCooldowns.ListCooldowns()
  local serverTime = GetServerTime()
  for sender, cooldowns in pairs(private.broadcastedCooldowns) do
    for spellId, cooldownEnds in pairs(cooldowns) do
      if cooldownEnds > serverTime then
        local cooldownTime = cooldownEnds - serverTime
        BPGP.Print(L["%s: %s in %02d:%02d"]:format(sender, GetSpellInfo(spellId), cooldownTime / 60, cooldownTime % 60))
      end
    end
  end
end
