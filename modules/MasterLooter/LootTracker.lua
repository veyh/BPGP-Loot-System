local _, BPGP = ...

local LootTracker = BPGP.NewModule("LootTracker")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local LibDeformat = LibStub("LibDeformat-3.0")
LibStub("AceComm-3.0"):Embed(LootTracker)
LibStub("AceHook-3.0"):Embed(LootTracker)

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local AnnounceSender = BPGP.GetModule("AnnounceSender")
local DataManager = BPGP.GetModule("DataManager")
local MasterLooter = BPGP.GetModule("MasterLooter")

local private = {
  dbDefaults = {
    profile = {
      enabled = false, -- Loading is managed by MasterLooter module
      cache = {
        unitLoot = {},
        recentLootQueue = {},
        recentLootMap = {},
      },
    },
  },
  masterLootingErrors = {
   [ERR_INV_FULL] = true, -- errorType 2
   [ERR_ITEM_MAX_COUNT] = true, -- errorType 22
   [ERR_LOOT_PLAYER_NOT_FOUND] = true, -- errorType 500
   [ERR_LOOT_MASTER_INV_FULL] = true, -- errorType ?
   [ERR_LOOT_MASTER_UNIQUE_ITEM] = true, -- errorType ?
   [ERR_LOOT_MASTER_OTHER] = true, -- errorType ?
  }
}
Debugger.Attach("LootTracker", private)

function LootTracker:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("LootTracker", private.dbDefaults)
end

function LootTracker:OnEnable()
  Debugger("LootTracker:OnEnable()")
  if MasterLooter.db.profile.lootAutoAdd or MasterLooter.db.profile.lootAnnounce then
    BPGP.RegisterEvent("LOOT_OPENED", self.HandleLootOpened)
  end
  if MasterLooter.db.profile.lootAnnounce then
    self:RegisterComm("BPGPUNITLOOT", private.HandleUnitLootComm)
  end
  if MasterLooter.db.profile.lootPopup then
    self:Hook("GiveMasterLoot", private.HandleGiveMasterLoot, true)
  end
  if not DataManager.SelfInRaid() then
    self:Disable()
  end
end

function LootTracker:OnDisable()
  Debugger("LootTracker:OnDisable()")
  BPGP.UnregisterEvent("LOOT_OPENED", self.HandleLootOpened)
  self:UnregisterComm("BPGPUNITLOOT", private.HandleUnitLootComm)
  self:Unhook("GiveMasterLoot", private.HandleGiveMasterLoot)
  LootTracker.ResetUnitLoot()
end

----------------------------------------
-- Public interface
----------------------------------------

function LootTracker.AddRecentLoot(itemLink)
  if not Common:GetItemId(itemLink) then return end
  if LootTracker.db.profile.cache.recentLootMap[itemLink] then return end
  table.insert(LootTracker.db.profile.cache.recentLootQueue, 1, itemLink)
  LootTracker.db.profile.cache.recentLootMap[itemLink] = true
  if #LootTracker.db.profile.cache.recentLootQueue > 15 then
    local itemLink = table.remove(LootTracker.db.profile.cache.recentLootQueue)
    LootTracker.db.profile.cache.recentLootMap[itemLink] = nil
  end
end

function LootTracker.GetNumRecentItems()
  return #LootTracker.db.profile.cache.recentLootQueue
end

function LootTracker.GetRecentItemLink(i)
  return LootTracker.db.profile.cache.recentLootQueue[i]
end

function LootTracker.ResetUnitLoot()
  wipe(LootTracker.db.profile.cache.unitLoot)
end

----------------------------------------
-- Event handlers
----------------------------------------

function private.HandleGiveMasterLoot(slotId, candidateId, ...)
  local playerName = tostring(GetMasterLootCandidate(slotId, candidateId))
  local itemLink = tostring(GetLootSlotLink(slotId))
  local itemQuantity = select(3, GetLootSlotInfo(slotId)) or 1
  Debugger("HandleGiveMasterLoot: %s, %s, %s", playerName, itemLink, itemQuantity)
  if not DataManager.IsInRaid(playerName) then 
    Debugger("Skipped popup (unit not in raid): %s, %s, %s", playerName, itemLink, itemQuantity)
    return
  end
  local itemId = Common:GetItemId(itemLink)
  if not itemId then 
    Debugger("Skipped popup (invalid item id): %s, %s, %s", playerName, itemLink, itemQuantity)
    return
  end
  local itemQuality = Common:GetItemQuality(itemLink)
  if not itemQuality or itemQuality < MasterLooter.db.profile.lootPopupThreshold then 
    Debugger("Skipped popup (low item quality): %s, %s, %s", playerName, itemLink, itemQuantity)
    return
  end
  private.giveMasterLootFailed = false
  BPGP.RegisterEvent("UI_ERROR_MESSAGE", private.HandleUIErrorMessage)
  Coroutine:RunAsync(private.AsyncHandleGiveMasterLoot, playerName, itemId, itemLink, itemQuantity)
end

function private.HandleUIErrorMessage(event, errorType, message)
  if private.masterLootingErrors[message] then
    Debugger("Masterlooting Error: type=%s msg=%s", errorType, message)
    private.giveMasterLootFailed = true
    BPGP.UnregisterEvent("UI_ERROR_MESSAGE", private.HandleUIErrorMessage)
  end
end

function private.AsyncHandleGiveMasterLoot(playerName, itemId, itemLink, itemQuantity)
  for i = 1, 10 do
    if private.giveMasterLootFailed then
      Debugger("Skipped popup (delivery failed): %s, %s, %s", playerName, itemLink, itemQuantity) 
      return 
    end
    Coroutine:Sleep(0.1)
  end
  Debugger("Show popup: %s, %s, %s", playerName, itemLink, itemQuantity) 
  BPGP.UnregisterEvent("UI_ERROR_MESSAGE", private.HandleUIErrorMessage)
  MasterLooter.ShowLootPopup(playerName, itemId, itemLink, itemQuantity)
end

function LootTracker.HandleLootOpened()
  -- Loot source detection
  -- Looting a corpse forces to target it and CanLootUnit("CorpseGUID") returns hasLoot = true, canLoot = false 
  -- So, when loot window is opened but target hasLoot == false or canLoot = true, we're most likely looting container
  -- The only undetectable case is if we target some unlooted corpse while looting container
  -- Target type by BPGP classification: 1 - Raid Boss , 2 - Trash, 3 - Container
  local targetGUID, targetLevel, unitType, unitGUID = UnitGUID("target"), UnitLevel("target"), 2, nil
  if not targetGUID then -- No target selected
    unitGUID, unitType = "Container", 3 -- Container type detected
  else
    local hasLoot, canLoot = CanLootUnit(targetGUID)
    if not hasLoot or canLoot then -- Empty corpse or raid member targeted
      unitGUID, unitType = "Container", 3 -- Container type detected
    else
      unitGUID = Common:GetUnitGUID(targetGUID) -- Extracting ID-SpawnUID part of GUID, there is no need in repeating part
      if targetLevel == -1 then
        unitType = 1 -- Raid Boss type detected
      end
    end
  end
  
  local idsList, linksList, qualityList = {}, {}, {}
  for i = 1, GetNumLootItems() do
    local itemLink = GetLootSlotLink(i)
    if itemLink ~= nil then
      local itemId, itemQuality = Common:GetItemId(itemLink), Common:GetItemQuality(itemLink)
      if itemId and itemQuality then
        table.insert(idsList, itemId)
        table.insert(linksList, itemLink)
        table.insert(qualityList, itemQuality)
      end
    end
  end
  
  private.ProcessUnitLootList(unitType, unitGUID, idsList, linksList, qualityList, nil, true)
end

function private.HandleUnitLootComm(prefix, message, distribution, sender)
  if sender == DataManager.GetSelfName() or not DataManager.IsInRaid(sender) then return end
  local unitType, unitGUID, itemIds = private.DecodeCommUnitLoot(message)
  if #itemIds < 11 then
    Coroutine:RunAsync(private.AsyncHandleUnitLootComm, unitType, unitGUID, itemIds, sender)
  else
    BPGP.Print(L["Loot announce spam detected from %s"]:format(sender))
  end
end

function private.AsyncHandleUnitLootComm(unitType, unitGUID, idsList, sender)
  local linksList, qualityList, ignoredItemIds = {}, {}, MasterLooter.GetIgnoredItemIds()
  for c = 1, 10 do
    for i, rawItemId in ipairs(idsList) do
      local itemId = tonumber(rawItemId)
      if not ignoredItemIds[itemId] then 
        local itemLink = select(2, GetItemInfo(itemId))
        local itemQuality = Common:GetItemQuality(itemLink)
        if itemLink and itemQuality then
          linksList[i] = itemLink
          qualityList[i] = itemQuality
        end
      else
        Debugger("Ignored item (blacklisted): %s", tostring(itemId)) 
      end
    end
    if #linksList == #idsList then break end
    Coroutine:Sleep(0.5)
  end
  if #linksList ~= #idsList then return end
  private.ProcessUnitLootList(unitType, unitGUID, idsList, linksList, qualityList, sender, false)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.ProcessUnitLootList(unitType, unitGUID, idsList, linksList, qualityList, reportedBy, sendCommMessage)
  if #idsList == 0 then return end
  if not private.RegisterUnitLoot(unitGUID, idsList) then return end
  private.AnnounceLoot(unitType, unitGUID, idsList, linksList, qualityList, reportedBy, sendCommMessage)
  private.AutoAddLoot(idsList, linksList, qualityList)
end

function private.RegisterUnitLoot(unitGUID, itemIds)
  if LootTracker.db.profile.cache.unitLoot[unitGUID] then
    if unitGUID == "Container" then
      for unit, items in pairs(LootTracker.db.profile.cache.unitLoot) do
        if Common:FindNext(items, itemIds[1]) then
          return false -- Container loot in Classic raids never matches with corpse loot
        end
      end
    else
      return false
    end
  end
  if LootTracker.db.profile.cache.unitLoot["Container"] and unitGUID ~= "Container" then
    if Common:FindNext(LootTracker.db.profile.cache.unitLoot["Container"], itemIds[1]) then
      return false -- Container loot in Classic raids never matches with corpse loot
    end
  end
  LootTracker.db.profile.cache.unitLoot[unitGUID] = itemIds
  return true
end

function private.AnnounceLoot(unitType, unitGUID, idsList, linksList, qualityList, reportedBy, sendCommMessage)
  if not MasterLooter.db.profile.lootAnnounce then return end
  local filteredIds, filteredLinks = {}, {}
  for i, itemQuality in ipairs(qualityList) do
    local itemId, itemLink = tonumber(idsList[i]), linksList[i]
    if itemQuality >= MasterLooter.db.profile.lootAnnounceThreshold then
      table.insert(filteredIds, itemId)
      table.insert(filteredLinks, itemLink)
    end
  end
  if next(filteredLinks) then
    if DataManager.SelfML() then
      AnnounceSender.AnnounceEvent("AnnounceEpicLoot", unitType, filteredLinks, reportedBy)
    end
    if sendCommMessage then
      local commMessage = private.EncodeCommUnitLoot(unitType, unitGUID, filteredIds)
      LootTracker:SendCommMessage("BPGPUNITLOOT", commMessage, "RAID", nil, "ALERT")
    end
  end
end

function private.AutoAddLoot(idsList, linksList, qualityList)
  if not MasterLooter.db.profile.lootAutoAdd then return end
  local filteredItems = {}
  for i, itemQuality in ipairs(qualityList) do
    if itemQuality >= MasterLooter.db.profile.lootAutoAddThreshold then
      local itemLink = linksList[i]
      if not filteredItems[itemLink] then
        filteredItems[itemLink] = 1
      else
        filteredItems[itemLink] = filteredItems[itemLink] + 1
      end
      LootTracker.AddRecentLoot(itemLink)
    end
  end
  if next(filteredItems) then
  if not DataManager.SelfML() then return end
    for itemLink, itemQuantity in pairs(filteredItems) do
      BPGP.GetModule("GUI").LootItemsAdd(itemLink, itemQuantity)
    end
  end
end

function private.EncodeCommUnitLoot(unitType, unitGUID, itemIds)
  return string.format("%d@%s@%s", unitType, unitGUID, table.concat(itemIds, ";"))
end

function private.DecodeCommUnitLoot(message)
  local unitType, unitGUID, itemIds = strsplit("@", message)
  return tonumber(unitType), unitGUID, {strsplit(";", itemIds)}
end


