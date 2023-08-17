local _, BPGP = ...

local lib = {}
BPGP.RegisterLibrary("Common", lib)

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local LibDeformat = LibStub("LibDeformat-3.0")

local assert, next, pairs, ipairs, select, type, tostring, tonumber = assert, next, pairs, ipairs, select, type, tostring, tonumber
local wipe, tinsert, strsplit, strfind, getglobal = wipe, tinsert, strsplit, strfind, getglobal
local GetItemInfo, GetInventoryItemLink, GetItemStats = GetItemInfo, GetInventoryItemLink, GetItemStats

-- Strings

function lib:Trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function lib:Ltrim(s)
  return (s:gsub("^%s*", ""))
end

function lib:Rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do n = n - 1 end
  return s:sub(1, n)
end

function lib:Split(s, delim)
    local parts = {}
    for match in (s..delim):gmatch("(.-)"..delim) do
      tinsert(parts, match)
    end
    return parts
end

-- Flags (bitmasks)

function lib:TestFlag(set, flag)
  return set % (2 * flag) >= flag
end

function lib:SetFlag(set, flag)
  if set % (2 * flag) >= flag then
    return set
  end
  return set + flag
end

function lib:DelFlag(set, flag)
  if set % (2 * flag) >= flag then
    return set - flag
  end
  return set
end

-- Integers

function lib:Round(num, precision)
  if not num then return end
  return tonumber((("%%.%df"):format(precision)):format(num))
end

-- Tables

function lib:JoinKeys(t, delim)
    local s = ""
    for key in pairs(t) do
      if s == "" then
        s = key
      else
        s = s .. delim .. tostring(key)
      end
    end
    return s
end

function lib:KeysCount(t)
  if type(t) ~= "table" then return 0 end
  local len = 0
  for key in pairs(t) do
    len = len + 1
  end
  return len
end

function lib:ValuesCount(t)
  if type(t) ~= "table" then return 0 end
  local len = 0
  for _, value in pairs(t) do
    if value then
      len = len + 1
    end
  end
  return len
end

function lib:Contains(t, value)
  if type(t) ~= "table" then return false end
  for _, val in pairs(t) do
    if val == value then
      return true
    end
  end
  return false
end

function lib:Copy(src, dest)
	for index, value in pairs(src) do
		if type(value) == "table" then
			dest[index] = {}
			lib:Copy(value, dest[index])
		else
			dest[index] = value
		end
	end
end

function lib:NewCopy(src)
  local dest = {}
	lib:Copy(src, dest)
  return dest
end

function lib:FindNext(t, value)
  for i = 1, #t do
    if t[i] == value then
      return i
    end
  end
end

function lib:Find(t, value)
  for k, v in pairs(t) do
    if v == value then
      return k
    end
  end
end

function lib:FindKey(t, key)
  for k, v in pairs(t) do
    if k == key then
      return true
    end
  end
  return false
end

function lib:Dump(object, recursionLevel)
  recursionLevel = recursionLevel or 0
  if type(object) == "table" and recursionLevel >= 0 then
    local s = "{"
    for k, v in pairs(object) do
      s = s .. lib:Dump(k, recursionLevel - 1) .. "=" .. lib:Dump(v, recursionLevel - 1) .. ", "
    end
    if s ~= "{" then s = s:sub(1, -3) end
    return s .. "}"
  elseif type(object) == "number" then
    return tostring(object)
  else
    return '"'..tostring(object)..'"'
  end
end

-- In-game objects

function lib:ExtractCharacterName(playerName)
  if not playerName then return end
  return strsplit("-", playerName)
end

function lib:GetItemId(itemLink)
  if not itemLink then return end
  return select(3, strfind(itemLink, "item:(%d-):"))
end

function lib:GetUnitGUID(CreatureGUID)
  if not CreatureGUID then return end
  local unitID, spawnUID = select(6, strsplit("-", CreatureGUID))
  return unitID.."-"..spawnUID
end

local itemSlotIds = {
  ["INVTYPE_AMMO"] =           { 0 },
  ["INVTYPE_HEAD"] =           { 1 },
  ["INVTYPE_NECK"] =           { 2 },
  ["INVTYPE_SHOULDER"] =       { 3 },
  ["INVTYPE_BODY"] =           { 4 },
  ["INVTYPE_CHEST"] =          { 5 },
  ["INVTYPE_ROBE"] =           { 5 },
  ["INVTYPE_WAIST"] =          { 6 },
  ["INVTYPE_LEGS"] =           { 7 },
  ["INVTYPE_FEET"] =           { 8 },
  ["INVTYPE_WRIST"] =          { 9 },
  ["INVTYPE_HAND"] =           { 10 },
  ["INVTYPE_FINGER"] =         { 11, 12 },
  ["INVTYPE_TRINKET"] =        { 13, 14 },
  ["INVTYPE_CLOAK"] =          { 15 },
  ["INVTYPE_WEAPON"] =         { 16, 17 },
  ["INVTYPE_SHIELD"] =         { 17 },
  ["INVTYPE_2HWEAPON"] =       { 16 },
  ["INVTYPE_WEAPONMAINHAND"] = { 16 },
  ["INVTYPE_WEAPONOFFHAND"] =  { 17 },
  ["INVTYPE_HOLDABLE"] =       { 17 },
  ["INVTYPE_RANGED"] =         { 18 },
  ["INVTYPE_THROWN"] =         { 18 },
  ["INVTYPE_RANGEDRIGHT"] =    { 18 },
  ["INVTYPE_RELIC"] =          { 18 },
  ["INVTYPE_TABARD"] =         { 19 },
  ["INVTYPE_BAG"] =            { 20, 21, 22, 23 },
  ["INVTYPE_QUIVER"] =         { 20, 21, 22, 23 }
}

function lib:GetEquippedItemLinks(itemEquipLoc)
  local slotIds = itemSlotIds[itemEquipLoc]
  if not slotIds then return end
  local itemLinks = {}
  for i = 1, #slotIds do
    local itemLink = GetInventoryItemLink("player", slotIds[i])
    if itemLink then table.insert(itemLinks, itemLink) end
  end
  return itemLinks
end

-- Items class filtering

local localizedClassDecoder = {}
local classIds = {1, 2, 3, 4, 5, 6, 7, 8, 9, 11}

for i = 1, #classIds do
	local classInfo = C_CreatureInfo.GetClassInfo(classIds[i])

  if classInfo
  and classInfo.className
  and classInfo.classFile
  then
    localizedClassDecoder[classInfo.className] = classInfo.classFile
  end
end

local commonTooltip = CreateFrame("GameTooltip", "BPGPCommonTooltip", nil, "GameTooltipTemplate")
local commonTooltipItemLink = nil
local commonTooltipSetCounter = 0
function lib:OnTooltipSetItem()
  commonTooltipSetCounter = commonTooltipSetCounter + 1
end
commonTooltip:SetScript("OnTooltipSetItem", lib.OnTooltipSetItem)

function lib:LoadParser(itemLink)
  if itemLink ~= commonTooltipItemLink then
    commonTooltipItemLink = itemLink
    commonTooltipSetCounter = 0
    commonTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    commonTooltip:SetHyperlink(itemLink)
  end
  return commonTooltipSetCounter
end

function lib:UnloadParser(itemLink)
  if itemLink == commonTooltipItemLink then
    commonTooltipItemLink = nil
    commonTooltipSetCounter = 0
    commonTooltip:Hide()
  end
end

function lib:ParseUnique(itemLink)
  for i = 1, commonTooltip:NumLines() or 0 do
    local line = getglobal("BPGPCommonTooltipTextLeft" .. i)
    if line and line.GetText then
      local text = line:GetText()
      if text and text ~= "" then
        if string.find(text, ITEM_UNIQUE, 1, true) then
          return true
        end
      end
    end
  end
  return false
end

function lib:ParseClasses(itemLink)
  local itemClassesAllowedPattern, delim, result = _G.ITEM_CLASSES_ALLOWED:gsub("%%s", "%(%.%+%)"), ", ", {}
  for i = 1, commonTooltip:NumLines() or 0 do
    local line = getglobal("BPGPCommonTooltipTextLeft" .. i)
    if line and line.GetText then
      local text = line:GetText() or ""
      local classesText = text:match(itemClassesAllowedPattern)
      if classesText then
        if LIST_DELIMITER and LIST_DELIMITER ~= "" and classesText:find(LIST_DELIMITER:gsub("%%s","")) then
          delim = LIST_DELIMITER:gsub("%%s","")
        elseif PLAYER_LIST_DELIMITER and PLAYER_LIST_DELIMITER ~= "" and classesText:find(PLAYER_LIST_DELIMITER) then
          delim = PLAYER_LIST_DELIMITER
        end
        for className in string.gmatch(classesText..delim, "(.-)"..delim) do
          tinsert(result, localizedClassDecoder[className])
        end
      end
    end
  end
  return result
end

-- Items types filtering

local invalidItemTypes = {
	[LE_ITEM_CLASS_ARMOR] = {
		[LE_ITEM_ARMOR_CLOTH] = {}, -- All classes should be eligible due to cloacks're cloth
		[LE_ITEM_ARMOR_LEATHER] = {"MAGE", "PRIEST", "WARLOCK"},
		[LE_ITEM_ARMOR_MAIL] = {"DRUID", "MAGE", "PRIEST", "ROGUE", "WARLOCK"},
		[LE_ITEM_ARMOR_PLATE] = {"DRUID", "HUNTER", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK"},
		[LE_ITEM_ARMOR_SHIELD] = {"DRUID", "HUNTER", "MAGE", "PRIEST", "ROGUE", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_ARMOR_IDOL] = {"HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARRIOR", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_ARMOR_LIBRAM] = {"DRUID", "HUNTER", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARRIOR", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_ARMOR_TOTEM] = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "WARRIOR", "WARLOCK", "DEATHKNIGHT"},
	},
	[LE_ITEM_CLASS_WEAPON] = {
		[LE_ITEM_WEAPON_BOWS] = {"DRUID", "MAGE", "PALADIN", "PRIEST", "SHAMAN", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_CROSSBOW] = {"DRUID", "MAGE", "PALADIN", "PRIEST", "SHAMAN", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_DAGGER] = {"PALADIN", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_UNARMED] = {"MAGE", "PALADIN", "PRIEST", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_GUNS] = {"DRUID", "MAGE", "PALADIN", "PRIEST", "SHAMAN", "WARLOCK", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_AXE1H] = {"DRUID", "MAGE", "PRIEST", "WARLOCK"},
		[LE_ITEM_WEAPON_MACE1H] = {"HUNTER", "MAGE", "WARLOCK"},
		[LE_ITEM_WEAPON_SWORD1H] = {"DRUID", "PRIEST", "SHAMAN"},
		[LE_ITEM_WEAPON_POLEARM] = {"DRUID", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK"},
		[LE_ITEM_WEAPON_STAFF] = {"PALADIN", "ROGUE", "WARRIOR", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_AXE2H] = {"DRUID", "MAGE", "PRIEST", "ROGUE", "WARLOCK"},
		[LE_ITEM_WEAPON_MACE2H] = {"HUNTER", "MAGE", "PRIEST", "ROGUE", "WARLOCK"},
		[LE_ITEM_WEAPON_SWORD2H] = {"DRUID", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK"},
		[LE_ITEM_WEAPON_WAND] = {"DRUID", "HUNTER", "PALADIN", "ROGUE", "SHAMAN", "WARRIOR", "DEATHKNIGHT"},
		[LE_ITEM_WEAPON_THROWN] = {"DRUID", "MAGE", "PALADIN", "PRIEST", "SHAMAN", "WARLOCK", "DEATHKNIGHT"},
	},
}

if LE_ITEM_ARMOR_SIGIL then
  invalidItemTypes[LE_ITEM_CLASS_ARMOR][LE_ITEM_ARMOR_SIGIL] = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "SHAMAN", "ROGUE", "WARRIOR", "WARLOCK"}
end

-- Items stats filtering
--local ignoreStats = { -- For testing purposes
--  ["ITEM_MOD_AGILITY_SHORT"] = {"SKIP"},
--  ["ITEM_MOD_INTELLECT_SHORT"] = {"SKIP"},
--  ["ITEM_MOD_STAMINA_SHORT"] = {"SKIP"},
--  ["ITEM_MOD_SPIRIT_SHORT"] = {"SKIP"},
--  ["ITEM_MOD_STRENGTH_SHORT"] = {"SKIP"},
--  ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"] = {"SKIP"},
--  ["EMPTY_SOCKET_YELLOW"] = {"SKIP"},
--  ["EMPTY_SOCKET_RED"] = {"SKIP"},
--  ["EMPTY_SOCKET_BLUE"] = {"SKIP"},
--  ["EMPTY_SOCKET_META"] = {"SKIP"},
--}
local extraItemMods = {"ITEM_SPELL_TRIGGER_ONPROC", "Your attacks ignore"}

local statsCache = {}
local blacklistedStats = {}
function lib:GetBlacklistedStats(itemLink, statsBlacklist, statsWordings)
--  BPGP.Printf("Testing %s", itemLink)
  wipe(statsCache)
  wipe(blacklistedStats)
  GetItemStats(itemLink, statsCache)
  
  for i = 1, commonTooltip:NumLines() or 0 do
    local line = getglobal("BPGPCommonTooltipTextLeft" .. i)
    if line and line.GetText then
      local text = line:GetText()
      if text and text ~= "" then
        for _, wording in ipairs(extraItemMods) do
          if strfind(text, _G[wording] or wording) then
            -- Armor Penetration is is returned by GetItemStats as Spell one, so bugfixing required
            if wording == "Your attacks ignore" and statsCache["ITEM_MOD_SPELL_PENETRATION_SHORT"] then
              statsCache["ITEM_MOD_SPELL_PENETRATION_SHORT"] = nil
              statsCache["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = true
            else
              statsCache[wording] = true
            end
          end
        end
      end
    end
  end
  
  for statName in pairs(statsCache) do
  --  BPGP.Printf("Testing stat %s", statName)
    if statsBlacklist[statName] then
--        BPGP.Printf("Stat %s IS blacklisted", statName)
      tinsert(blacklistedStats, statsWordings[statName] or statName)
--      else
--        BPGP.Printf("Stat %s is NOT blacklisted", statName)
    end
  end
--  BPGP.Print("Done test")
  return blacklistedStats
end

function lib:CanEquipItem(itemLink, class)
  local _, _, _, _, _, _, _, _, _, _, _, typeID, subTypeID = GetItemInfo(itemLink)
  if invalidItemTypes[typeID] and invalidItemTypes[typeID][subTypeID] then
    if lib:FindNext(invalidItemTypes[typeID][subTypeID], class) then
      return false
    end
  end
  return true
end

function lib:IsRecipe(itemLink)
  local _, _, _, _, _, _, _, _, _, _, _, typeID = GetItemInfo(itemLink)
  if typeID == LE_ITEM_CLASS_RECIPE then
    return true
  end
  return false
end

----------------------------------------
-- Item quality detection
----------------------------------------

function lib:ParseColor(s)
  return select(3, strfind(s, "|c(%x-)|Hitem"))
end

-- Known quality colors from web
local itemQualityColors = {
  ["ff9d9d9d"] = 0, -- Poor
  ["ffffffff"] = 1, -- Common
  ["ff1eff00"] = 2, -- Uncommon
  ["ff0070dd"] = 3, -- Rare
  ["ffa334ee"] = 4, -- Epic
  ["ffa335ee"] = 4, -- Epic
  ["ffff8000"] = 5, -- Legendary
}

-- Fetching quality colors from ITEM_QUALITY_COLORS
for itemQuality, colorTable in pairs(ITEM_QUALITY_COLORS) do
  itemQualityColors[colorTable.color:GenerateHexColor()] = itemQuality
end

-- Fetching quality colors from predefined item list
local predefinedItemIds = {
  [3949] = 0, -- Poor [Twill Pants]
  [4334] = 1, -- Common [Formal White Shirt]
  [13871] = 2, -- Uncommon [Frostweave Pants]
  [18727] = 3, -- Rare [Crimson Felt Hat]
  [17103] = 4, -- Epic [Azuresong Mageblade]
  [17182] = 5, -- Legendary [Sulfuras, Hand of Ragnaros]
}
local pendingItemIds = {}

-- Processing server responces for GetItemInfo requests done on PLAYER_ENTERING_WORLD
local function ProcessPredefinedItemInfo(event, itemId, success)
  local i = lib:FindNext(pendingItemIds, itemId)
  if not i then return end -- None of queued ids found in this event's payload, so we can skip it
    
  local _, itemLink, fetchedQuality = GetItemInfo(itemId)
  if predefinedItemIds[itemId] == fetchedQuality then
    itemQualityColors[lib:ParseColor(itemLink)] = fetchedQuality
  end
  -- We don't want to spam server with retries, this fetch is "failover for failover" anyway
  table.remove(pendingItemIds, i)
  if #pendingItemIds == 0 then
    BPGP.UnregisterEvent("GET_ITEM_INFO_RECEIVED", ProcessPredefinedItemInfo)
  end
end
BPGP.RegisterEvent("GET_ITEM_INFO_RECEIVED", ProcessPredefinedItemInfo)

local function FetchPredefinedItems(event)
  for itemId, itemQuality in pairs(predefinedItemIds) do
    local _, itemLink, fetchedQuality = GetItemInfo(itemId)
    if itemQuality ~= fetchedQuality then
      tinsert(pendingItemIds, itemId) -- Failed to fetch quality, adding to waitlist
    else
      itemQualityColors[lib:ParseColor(itemLink)] = itemQuality
    end
  end
  -- All items are fetched on login, no need to listen for GetItemInfo responses
  if #pendingItemIds == 0 then
    BPGP.UnregisterEvent("GET_ITEM_INFO_RECEIVED", ProcessPredefinedItemInfo)
  end
end
BPGP.RegisterEvent("PLAYER_ENTERING_WORLD", FetchPredefinedItems)

function lib:GetItemQuality(itemLink)
  if not lib:GetItemId(itemLink) then return end
  -- Trying to detect quality by link color
  local linkColor = lib:ParseColor(itemLink)
  if linkColor then
    return itemQualityColors[linkColor]
  end
  -- Falling back to GetItemInfo()
  local _, _, itemQuality = GetItemInfo(itemLink)
  return itemQuality
end
