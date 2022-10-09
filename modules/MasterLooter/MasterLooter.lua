local _, BPGP = ...

local MasterLooter = BPGP.NewModule("MasterLooter")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local DataManager = BPGP.GetModule("DataManager")
local AnnounceSender = BPGP.GetModule("AnnounceSender")

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      rollAnnounceMedium = "RAID_WARNING",
      collectRollResults = true,
      resetRollResults = true,
      bossPopup = true,
      lootAnnounce = true,
      lootAnnounceThreshold = 4,
      lootAutoAdd = true,
      lootAutoAddThreshold = 4, -- 0 - Poor,  1 - Common, 2 - Uncommon, 3 - Rare, 4 - Epic, 5 - Legendary
  --    bossWipePopup = false,
      lootPopup = true,
      lootPopupThreshold = 4, -- 0 - Poor,  1 - Common, 2 - Uncommon, 3 - Rare, 4 - Epic, 5 - Legendary
      standbySupport = true,
      standbyRequests = true,
      standbyNotify = true,
      standbyAnnounceMedium = "GUILD",
      announceMedium = "GUILD",
      announceEvents = {
        ["BankedItem"] = true,
        ["FreeItem"] = true,
        ["MemberAwardedBP"] = true,
        ["MemberAwardedGP"] = true,
        ["RaidAwardedBP"] = true,
        ["RaidAwardedGP"] = true,
      },
    },
  },
  ignoredItemIds = {
    [20725] = true, -- Nexus Crystal
    [22450] = true, -- Void Crystal
    [30316] = true, -- Devastation
    [30318] = true, -- Netherstrand Longbow
    [30317] = true, -- Cosmic Infuser
    [30312] = true, -- Infinity Blade
    [30313] = true, -- Staff of Disintegration
    [30311] = true, -- Warp Slicer
    [30314] = true, -- Phaseshift Bulwark
  },
  trackersEnabled = false,
}
Debugger.Attach("MasterLooter", private)

function MasterLooter:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("MasterLooter", private.dbDefaults)
end

function MasterLooter:OnEnable()
end

function MasterLooter:OnDisable()
end

function MasterLooter.SetupTrackers()
  if DataManager.SelfInRaid() then
    Debugger("Looking for not loaded common trackers to load...")
    BPGP.GetModule("LootTracker"):Enable()
    BPGP.GetModule("RollTracker"):Enable()
    BPGP.GetModule("DistributionTracker"):Enable()
    if DataManager.SelfML() then
      Debugger("Looking for not loaded ML-only trackers to load...")
      BPGP.GetModule("StandbyTracker"):Enable()
      BPGP.GetModule("BossTracker"):Enable()
    else
      if DataManager.SelfSA() then
        BPGP.GetModule("StandbyTracker"):Enable()
      else
        BPGP.GetModule("StandbyTracker"):Disable()
      end
      BPGP.GetModule("BossTracker"):Disable()
    end
  else
    Debugger("Looking for loaded trackers to unload...")
    BPGP.GetModule("LootTracker"):Disable()
    BPGP.GetModule("RollTracker"):Disable()
    BPGP.GetModule("DistributionTracker"):Disable()
    BPGP.GetModule("StandbyTracker"):Disable()
    BPGP.GetModule("BossTracker"):Disable()
  end
end

----------------------------------------
-- Public interface
----------------------------------------

function MasterLooter.GetIgnoredItemIds()
  return private.ignoredItemIds
end
  
function MasterLooter:LootItemsAnnounce(itemLinks)
  local err = nil
  if not DataManager.SelfInRaid() then
    err = L["you should be in a raid group"]
  elseif not DataManager.SelfML() then
    err = L["you should be a Master Looter"]
  elseif #itemLinks == 0 then
    err = L["please add some items first"]
  end
  if err then
    BPGP.Print(L["Failed to announce the loot list: %s!"]:format(err))
    return
  end
  AnnounceSender.AnnounceTo(MasterLooter.db.profile.rollAnnounceMedium, L["Loot list: "] .. table.concat(itemLinks, " "))
end

function MasterLooter.StartDistribution(mode, itemLink, comment)
  local err = nil
  if not DataManager.SelfInRaid() then
    err = L["you should be in a raid group"]
  elseif not DataManager.SelfML() then
    err = L["you should be a Master Looter"]
  end
  if err then
    BPGP.Print(L["Failed to announce new distribution: %s!"]:format(err))
    return
  end
  local medium = MasterLooter.db.profile.rollAnnounceMedium
  if mode == 1 then
    AnnounceSender.AnnounceTo(medium, L["Starting /roll"] .. " " .. itemLink .. ": " .. comment)
  elseif mode == 2 or mode == 3 then
    AnnounceSender.AnnounceTo(medium, L["Starting distribution"] .. " " .. itemLink .. ": " .. comment) 
  end
  BPGP.GetModule("DistributionTracker").StartDistribution(mode, itemLink, comment)
end

function MasterLooter.ShowLootPopup(playerName, itemId, itemLink, itemQuantity)
  if not DataManager.SelfML() or private.ignoredItemIds[itemId] then return end
  BPGP.GetModule("DistributionTracker").StopDistribution(itemLink)
  if DataManager.IsAllowedDataWrite() then
    Coroutine:RunAsync(private.AsyncShowLootPopup, playerName, itemId, itemLink, itemQuantity)
  end
  BPGP.GetModule("GUI").LootItemsRemove(itemLink)
end

function private.AsyncShowLootPopup(playerName, itemId, itemLink, itemQuantity)
  while DLG:ActiveDialog("BPGP_CONFIRM_GP_CREDIT") do
    Coroutine:Sleep(0.1)
  end
  DLG:Spawn("BPGP_CONFIRM_GP_CREDIT", {name = playerName, item = itemLink, icon = GetItemIcon(itemId)})
end

----------------------------------------
-- Module options
----------------------------------------

