local _, BPGP = ...

local DistributionTracker = BPGP.NewModule("DistributionTracker")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")
local LibDeformat = LibStub("LibDeformat-3.0")
LibStub("AceComm-3.0"):Embed(DistributionTracker)

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local DataManager = BPGP.GetModule("DataManager")
local MasterLooter = BPGP.GetModule("MasterLooter")

local next, select, unpack, tonumber, tconcat, tinsert = next, select, unpack, tonumber, table.concat, table.insert
local GetItemCount, GetItemInfo, GetItemIcon, IsEquippableItem = GetItemCount, GetItemInfo, GetItemIcon, IsEquippableItem

local private = {
  dbDefaults = {
    profile = {
      enabled = false, -- Loading is managed by MasterLooter module
      whitelistedRoles = {
        [L["Tank"]] = true,
        [L["Healer"]] = true,
        [L["Caster DPS"]] = true,
        [L["Physical DPS"]] = true,
      },
      cache = {
        mode = nil,
        itemLink = nil,
        responses = {},
        lootPopupComments = {},
        wishlist = {},
      },
    },
  },
  decoder = {L["Need"], L["Roll"], L["Greed"], L["Pass"], L["Auto Pass"], L["Waiting..."]},
  equippableMultiSlots = {
    ["INVTYPE_FINGER"] = true,
    ["INVTYPE_TRINKET"] = true,
    ["INVTYPE_WEAPON"] = true,
    ["INVTYPE_BAG"] = true,
  },
  priorities = {1, 1, 2, 4, 5, 3},
  distributionStartFormat = "%d\31%s\31%s",
  itemStatsKeywordWordings = {
    ["ITEM_MOD_DEFENSE_SKILL_RATING"] = L["Defense"],
    ["ITEM_MOD_DODGE_RATING"] = L["Dodge"],
    ["ITEM_MOD_PARRY_RATING"] = L["Parry"],
    ["ITEM_MOD_BLOCK_RATING"] = L["Block"],
    
    ["ITEM_MOD_HASTE_RATING"] = L["Phys Haste"],
    ["ITEM_MOD_HIT_RATING"] = L["Phys Hit"],
    ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = L["Armor Pen"],
    ["ITEM_SPELL_TRIGGER_ONPROC"] = L["Chance on hit"],
    
    ["ITEM_MOD_ATTACK_POWER_SHORT"] = L["Attack Power"],
    ["ITEM_MOD_CRIT_RATING"] = L["Phys Crit"],
    
    ["ITEM_MOD_EXPERTISE_RATING"] = L["Expertise"],
    
    ["ITEM_MOD_MELEE_ATTACK_POWER_SHORT"] = L["Feral Power"],

    ["ITEM_MOD_POWER_REGEN0_SHORT"] = L["Mana Regen"],
    
    ["ITEM_MOD_HIT_SPELL_RATING"] = L["Spell Hit"],
    ["ITEM_MOD_SPELL_PENETRATION_SHORT"] = L["Spell Pen"],
    ["ITEM_MOD_SPELL_POWER_SHORT"] = L["Spell Power"],
    ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] = L["Spell Damage"],
    ["ITEM_MOD_HASTE_SPELL_RATING"] = L["Spell Haste"],
    ["ITEM_MOD_CRIT_SPELL_RATING"] = L["Spell Crit"],
    ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = L["Healing Power"],
  },
  itemStatsKeywordBindings = {
    ["ITEM_MOD_DEFENSE_SKILL_RATING"] = {"TANK"}, -- Found only on tank items
    ["ITEM_MOD_DODGE_RATING"] = {"TANK"}, -- Found only on tank items
    ["ITEM_MOD_PARRY_RATING"] = {"TANK"}, -- Found only on plate armor, driud tanks will auto-pass
    ["ITEM_MOD_BLOCK_RATING"] = {"TANK"}, -- Found only on plate armor, driud tanks will auto-pass
    
    ["ITEM_MOD_HASTE_RATING"] = {"PHYS_DPS", "TANK"}, -- Found on phys dps and some tank items
    ["ITEM_MOD_HIT_RATING"] = {"PHYS_DPS", "TANK"}, -- Found on phys dps and some tank items
    ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = {"PHYS_DPS", "TANK"}, -- Found on phys dps and some tank items
    ["ITEM_SPELL_TRIGGER_ONPROC"] = {"PHYS_DPS", "TANK"}, -- Found on phys dps and some tank items
    
    ["ITEM_MOD_ATTACK_POWER_SHORT"] = {"PHYS_DPS"}, -- Found only on phys dps items
    ["ITEM_MOD_CRIT_RATING"] = {"PHYS_DPS"}, -- Found only on phys dps items
    
    ["ITEM_MOD_EXPERTISE_RATING"] = {"MELEE"}, -- Can't use PHYS_DPS 'cause of hunters
    
    ["ITEM_MOD_MELEE_ATTACK_POWER_SHORT"] = {"FERAL"}, -- Druids-only stat

    ["ITEM_MOD_POWER_REGEN0_SHORT"] = {"SPELL_DPS", "HEALER", "MANA_USER"}, -- Casters + some phys specs
    
    ["ITEM_MOD_HIT_SPELL_RATING"] = {"SPELL_DPS"},
    ["ITEM_MOD_SPELL_PENETRATION_SHORT"] = {"SPELL_DPS"},
    ["ITEM_MOD_SPELL_POWER_SHORT"] = {"SPELL_DPS", "SPELL_TANK"}, -- May be useful for prot pallies
    ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] = {"SPELL_DPS", "HEALER"}, -- Dedicated spell schools & damage part of healing stat
    ["ITEM_MOD_HASTE_SPELL_RATING"] = {"SPELL_DPS", "HEALER"},
    ["ITEM_MOD_CRIT_SPELL_RATING"] = {"SPELL_DPS", "HEALER", "SPELL_TANK"}, -- May be useful for prot pallies
    ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = {"HEALER"},
  },
  -- Auto-pass is blacklist based:
  -- Item stats without stated keywords will be blacklisted
  -- Item stats with stated keywords will be removed from blacklist
  classSpecKeywordBindings = {
    ["DRUID"] = {
      [L["Caster DPS"]] = {"SPELL_DPS"},
      [L["Physical DPS"]] = {"MELEE", "PHYS_DPS", "FERAL"},
      [L["Tank"]] = {"MELEE", "TANK", "FERAL"},
      [L["Healer"]] = {"HEALER"},
    },
    ["HUNTER"] = {
      [L["Physical DPS"]] = {"PHYS_DPS", "MANA_USER"},
    },
    ["MAGE"] = {
      [L["Caster DPS"]] = {"SPELL_DPS"},
    },
    ["PALADIN"] = {
      [L["Healer"]] = {"HEALER"},
      [L["Tank"]] = {"MELEE", "TANK", "MANA_USER", "SPELL_TANK"},
      [L["Physical DPS"]] = {"MELEE", "PHYS_DPS", "MANA_USER"},
    },
    ["PRIEST"] = {
      [L["Healer"]] = {"HEALER"},
      [L["Caster DPS"]] = {"SPELL_DPS"},
    },
    ["ROGUE"] = {
      [L["Physical DPS"]] = {"MELEE", "PHYS_DPS"},
    },
    ["SHAMAN"] = {
      [L["Caster DPS"]] = {"SPELL_DPS"},
      [L["Physical DPS"]] = {"MELEE", "PHYS_DPS", "MANA_USER"},
      [L["Healer"]] = {"HEALER"},
    },
    ["WARLOCK"] = {
      [L["Caster DPS"]] = {"SPELL_DPS"},
    },
    ["WARRIOR"] = {
      [L["Physical DPS"]] = {"MELEE", "PHYS_DPS"},
      [L["Tank"]] = {"MELEE", "TANK"},
    },
  },
  classRoleIcons = {
    ["DRUID"] = {
      [L["Caster DPS"]] = {1, "Interface\\Icons\\Spell_nature_starfall"},
      [L["Physical DPS"]] = {2, "Interface\\Icons\\Ability_druid_catform"},
      [L["Tank"]] = {3, "Interface\\Icons\\Ability_racial_bearform"},
      [L["Healer"]] = {4, "Interface\\Icons\\Spell_nature_healingtouch"},
    },
    ["HUNTER"] = {
      [L["Physical DPS"]] = {1, "Interface\\Icons\\Classicon_hunter"},
    },
    ["MAGE"] = {
      [L["Caster DPS"]] = {1, "Interface\\Icons\\Classicon_mage"},
    },
    ["PALADIN"] = {
      [L["Healer"]] = {1, "Interface\\Icons\\Spell_holy_holybolt"},
      [L["Tank"]] = {2, "Interface\\Icons\\Spell_holy_devotionaura"},
      [L["Physical DPS"]] = {3, "Interface\\Icons\\Spell_holy_auraoflight"},
    },
    ["PRIEST"] = {
      [L["Healer"]] = {1, "Interface\\Icons\\Classicon_priest"},
      [L["Caster DPS"]] = {2, "Interface\\Icons\\Spell_shadow_demonicfortitude"},
    },
    ["ROGUE"] = {
      [L["Physical DPS"]] = {1, "Interface\\Icons\\Classicon_rogue"},
    },
    ["SHAMAN"] = {
      [L["Caster DPS"]] = {1, "Interface\\Icons\\Spell_nature_lightning"},
      [L["Physical DPS"]] = {2, "Interface\\Icons\\Ability_shaman_stormstrike"},
      [L["Healer"]] = {3, "Interface\\Icons\\Spell_nature_healingwavegreater"},
    },
    ["WARLOCK"] = {
      [L["Caster DPS"]] = {1, "Interface\\Icons\\Classicon_warlock"},
    },
    ["WARRIOR"] = {
      [L["Physical DPS"]] = {1, "Interface\\Icons\\Ability_warrior_innerrage"},
      [L["Tank"]] = {2, "Interface\\Icons\\Ability_warrior_defensivestance"},
    },
  },
  softPass = false,
  classSpecKeywordsWhitelist = {},
  itemStatsBlacklist = {},
}
Debugger.Attach("DistributionTracker", private)

function DistributionTracker:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("DistributionTracker", private.dbDefaults)
  
  local availableRoles = private.classSpecKeywordBindings[DataManager.GetSelfClass()]
  for role in pairs(DistributionTracker.db.profile.whitelistedRoles) do
    if not availableRoles[role] then
      DistributionTracker.db.profile.whitelistedRoles[role] = nil
    end
  end
  
  private.HandleAutoPassModeUpdate()
  BPGP.RegisterCallback("AutoPassModeUpdate", private.HandleAutoPassModeUpdate)
end

function DistributionTracker:OnEnable()
  Debugger("DistributionTracker:OnEnable()")
  self:RegisterComm("BPGPDISTRSTART", private.HandleDistributionStartComm)
  self:RegisterComm("BPGPDISTRRESP", private.HandleDistributionResponseComm)
  self:RegisterComm("BPGPDISTRSTOP", private.HandleDistributionStopComm)
  if not DataManager.SelfInRaid() then
    self:Disable()
  end
end

function DistributionTracker:OnDisable()
  Debugger("DistributionTracker:OnDisable()")
  self:UnregisterComm("BPGPDISTRSTART", private.HandleDistributionStartComm)
  self:UnregisterComm("BPGPDISTRRESP", private.HandleDistributionResponseComm)
  self:UnregisterComm("BPGPDISTRSTOP", private.HandleDistributionStopComm)
  self.ResetDistributionResults()
  BPGP.Fire("LootDistributionStop")
end

----------------------------------------
-- Event handlers
----------------------------------------

function private.HandleAutoPassModeUpdate()
  wipe(private.classSpecKeywordsWhitelist)
  wipe(private.itemStatsBlacklist)
  private.softPass = true
  for role, keywords in pairs(private.classSpecKeywordBindings[DataManager.GetSelfClass()]) do
    if DistributionTracker.db.profile.whitelistedRoles[role] then
      for _, keyword in ipairs(keywords) do
        private.classSpecKeywordsWhitelist[keyword] = true
      end
      private.softPass = false
    end
  end
  for itemStat, keywords in pairs(private.itemStatsKeywordBindings) do
    local isWhitelisted = false
    for _, keyword in ipairs(keywords) do
      if private.classSpecKeywordsWhitelist[keyword] then
        isWhitelisted = true
      end
    end
    if not isWhitelisted then
      private.itemStatsBlacklist[itemStat] = true
    end
  end
end

function private.HandleDistributionStartComm(prefix, message, distribution, sender)
  if not DataManager.IsML(sender) then return end
  local mode, itemLink, comment = LibDeformat(message, private.distributionStartFormat)
  local itemId = Common:GetItemId(itemLink)
  if not mode or not itemId then return end
  DistributionTracker.ResetDistributionResults()
  DistributionTracker.db.profile.cache.mode = mode
  DistributionTracker.db.profile.cache.itemLink = itemLink
  if mode == 1 then
    BPGP.GetModule("RollTracker").StartTracking(itemLink)
  elseif mode == 2 or mode == 3 then
    BPGP.GetModule("RollTracker").StartTracking(itemLink)
    Coroutine:RunAsync(private.AsyncHandleDistributionStartComm, mode, itemId, itemLink, comment)
  end
  BPGP.GetModule("StandingsManager").DestroyStandings()
  BPGP.Fire("LootDistributionStart", itemLink, comment)
end

function private.AsyncHandleDistributionStartComm(mode, itemId, incomingItemLink, comment)
  local itemLink = nil
  for i = 1, 6 do
    itemLink = select(2, GetItemInfo(incomingItemLink))
    local parserState = Common:LoadParser(itemLink)
    if i == 6 then break end
    if parserState >= 2 then break end
    Coroutine:Sleep(0.05)
    if DataManager.SelfML() then break end
  end
  local autopass, reason = private.ShouldAutopass(itemLink)
  Common:UnloadParser(itemLink) -- Wipes chached tooltip
  local delayPopup = private.HideDistributionPopup()
  if autopass then
    BPGP.Print(L["Auto Pass: %s (%s)"]:format(itemLink, reason))
    DistributionTracker.ResponseDistribution(incomingItemLink, 5)
  else
    Coroutine:RunAsync(private.AsyncShowDistributionPopup, delayPopup, mode, itemId, incomingItemLink, comment)
  end
end

function private.ShouldAutopass(itemLink)
  if Common:IsRecipe(itemLink) then
    return false
  end
  local playerClass, classLimit = DataManager.GetSelfClass(), Common:ParseClasses(itemLink)
  if #classLimit > 0 and not Common:FindNext(classLimit, playerClass) then
    return true, L["it's not intended for %s"]:format(DataManager.GetSelfClassLocalized():lower())
  end
  if not IsEquippableItem(itemLink) then
    if private.softPass and #classLimit > 0 then -- Autopass on tokens
      return true, L["all loot filter roles are disabled"]
    else
      return false
    end
  end
  if not Common:CanEquipItem(itemLink, playerClass) then
    return true, L["it's not equippable by %s"]:format(DataManager.GetSelfClassLocalized():lower())
  end
  local blacklistedStats = Common:GetBlacklistedStats(itemLink, private.itemStatsBlacklist, private.itemStatsKeywordWordings)
  if next(blacklistedStats) then
    return true, L["filtered out by stats: %s"]:format(tconcat(blacklistedStats, ", "))
  end
  local itemCount = GetItemCount(itemLink, true)
  if itemCount > 0 then
    local isUnique = Common:ParseUnique(itemLink)
    if isUnique then
      return true, L["you already have that unique item"]
    else
      local slotName = select(9, GetItemInfo(itemLink))
      if private.equippableMultiSlots[slotName] then
        if itemCount >= 2 and slotName ~= "INVTYPE_BAG" then
          return true, L["you already have %d of that items"]:format(itemCount)
        end
      else
        return true, L["you already have that item"]
      end
    end
  end
  if private.softPass then
    local slotName = select(9, GetItemInfo(itemLink))
    if slotName ~= "INVTYPE_BAG" then -- Autopass on equippable gear except bags
      return true, L["all loot filter roles are disabled"]
    end
  end
  return false
end

function private.AsyncShowDistributionPopup(mode, delayPopup, itemId, itemLink, comment)
  if delayPopup then
    Coroutine:Sleep(0.2) -- Add a bit of delay to make it look like dialog actually respawned.
  end
  DLG:Spawn("BPGP_ITEM_DISTRIBUTION", {mode = mode, item = itemLink, icon = GetItemIcon(itemId), comment = comment})
end

function private.HideDistributionPopup()
  local activeDialog = DLG:ActiveDialog("BPGP_ITEM_DISTRIBUTION")
  if activeDialog then
    if activeDialog.data and activeDialog.data["item"] then
      BPGP.Print(L["Distribution of %s is finished!"]:format(activeDialog.data["item"]))
    end
    DLG:Dismiss("BPGP_ITEM_DISTRIBUTION")
    return true
  end
end

function private.HandleDistributionResponseComm(prefix, message, distribution, sender)
  if not DataManager.IsInRaid(sender) then return end
  local itemLink, response, itemLinks = strsplit(";", message)
  if itemLink ~= DistributionTracker.db.profile.cache.itemLink then return end
  local equipped1, equipped2 = strsplit(",", itemLinks or "")
  DistributionTracker.RegisterDistributionResponse(itemLink, sender, response, equipped1, equipped2)
end

function private.HandleDistributionStopComm(prefix, message, distribution, sender)
  if not DataManager.IsML(sender) or DataManager.SelfML() then return end
  DistributionTracker.ResetDistributionResults()
  BPGP.GetModule("RollTracker").StopTracking(message)
  BPGP.Fire("LootDistributionStop")
end

function DistributionTracker.HandleSimpleRoll(playerName)
  local response, equipped1, equipped2 = DistributionTracker.db.profile.cache.responses[playerName], nil, nil
  if response then 
    response, equipped1, equipped2 = unpack(response)
    if response < 4 then 
      return
    end
  end
  DistributionTracker.RegisterDistributionResponse(DistributionTracker.db.profile.cache.itemLink, playerName, 2, equipped1, equipped2)
end

----------------------------------------
-- Public interface
----------------------------------------

function DistributionTracker.GetRoleIcons(class)
  return private.classRoleIcons[class]
end

function DistributionTracker.GetWhitelistedRoles()
  return DistributionTracker.db.profile.whitelistedRoles
end

function DistributionTracker.IsWhitelistedRole(role)
  return DistributionTracker.db.profile.whitelistedRoles[role]
end

function DistributionTracker.IsSoftPassEnabled()
  return private.softPass
end

function DistributionTracker.SetWhitelistedRole(role, isWhitelisted)
  DistributionTracker.db.profile.whitelistedRoles[role] = isWhitelisted
  BPGP.Fire("AutoPassModeUpdate")
end

function DistributionTracker.GetBlacklistedStatsList()
  local blacklistedStatsList = {}
  for itemStat in pairs(private.itemStatsBlacklist) do
    tinsert(blacklistedStatsList, private.itemStatsKeywordWordings[itemStat])
  end
  table.sort(blacklistedStatsList)
  return blacklistedStatsList
end

function DistributionTracker.ResetDistributionResults()
  if not DistributionTracker.db.profile.cache.itemLink then return end
  private.HideDistributionPopup()
  DistributionTracker.db.profile.cache.mode = nil
  DistributionTracker.db.profile.cache.itemLink = nil
  table.wipe(DistributionTracker.db.profile.cache.responses)
  BPGP.GetModule("RollTracker").ResetRollResults()
  BPGP.GetModule("StandingsManager").DestroyStandings()
end

function DistributionTracker.StartDistribution(mode, itemLink, comment)
  if not DataManager.SelfML() then return end
  if not comment or comment == "" then comment = "<NONE>" end
  local message = string.format(private.distributionStartFormat, mode, itemLink, comment)
  DistributionTracker:SendCommMessage("BPGPDISTRSTART", message, "RAID", nil, "ALERT")
end

function DistributionTracker.ResponseDistribution(itemLink, response)
  if not DataManager.SelfInRaid() then return end
  if itemLink ~= DistributionTracker.db.profile.cache.itemLink then
    BPGP.Print(L["Distribution of %s is finished!"]:format(itemLink))
    return
  end
  local message = string.format("%s;%d;", itemLink, response)
  if response == 1 or response == 3 then -- Need or Greed
    RandomRoll(1, 100)
  end
  if IsEquippableItem(itemLink) then
    local slotName = select(9, GetItemInfo(itemLink))
    local itemLinks = Common:GetEquippedItemLinks(slotName)
    if itemLinks then message = message..table.concat(itemLinks, ",") end
  end
  DistributionTracker:SendCommMessage("BPGPDISTRRESP", message, "RAID", nil, "BULK")
end

function DistributionTracker.RegisterDistributionResponse(itemLink, playerName, response, equipped1, equipped2)
  DistributionTracker.db.profile.cache.responses[playerName] = {tonumber(response), equipped1, equipped2}
  BPGP.GetModule("StandingsManager").DestroyStandings()
end

function DistributionTracker.GetDistributionResponse(playerName)
  if not DistributionTracker.db.profile.cache.itemLink then return end
  local result = DistributionTracker.db.profile.cache.responses[playerName]
  if result then
    return unpack(result)
  else
    return 6
  end
end

function DistributionTracker.GetDistributionPriority(playerName)
  return private.priorities[DistributionTracker.GetDistributionResponse(playerName)]
end

function DistributionTracker.GetDecodedDistributionResponse(playerName)
  local response, equipped1, equipped2 = DistributionTracker.GetDistributionResponse(playerName)
  return private.decoder[response], equipped1, equipped2
end

function DistributionTracker.StopDistribution(itemLink)
  if itemLink and itemLink ~= DistributionTracker.db.profile.cache.itemLink then return end
  if not itemLink then itemLink = DistributionTracker.db.profile.cache.itemLink end
  if itemLink and DataManager.SelfML() then
    DistributionTracker:SendCommMessage("BPGPDISTRSTOP", itemLink, "RAID", nil, "ALERT")
  end
  DistributionTracker.ResetDistributionResults()
  BPGP.GetModule("RollTracker").StopTracking(itemLink)
  BPGP.Fire("LootDistributionStop")
end

function DistributionTracker.ParseLootPopupComments(data)
  local commentStrings = {strsplit("\n", data)}
  local result = {}
  for i, commentString in ipairs(commentStrings) do
    local startPos, endPos = string.find(commentStrings[i], " - ", 1, true)
    if startPos then
      local itemName, comment = strtrim(commentString:sub(1, startPos-1)), strtrim(commentString:sub(endPos+1, -1))
      if #itemName > 0 and #comment > 0 then
        if result[itemName] then
          BPGP.Print(L["Comments Import: Warning! Ignored duplicate comment for %s!"]:format(itemName))
        else
          result[itemName] = comment
        end
      end
    end
  end
  return result
end
  
function DistributionTracker.ImportLootPopupComments(data)
  DistributionTracker.db.profile.cache.lootPopupComments = data
  BPGP.Print(L["Comments Import: Successfully imported comments for %d items!"]:format(Common:KeysCount(data)))
end

function DistributionTracker.ParseWishlist(data)
  local itemStrings = {strsplit("\n", data)}
  local result, prio = {}, 0
  for i, itemString in ipairs(itemStrings) do
    local itemId = tonumber(itemString)
    if itemId and itemId > 0 then
      prio = prio + 1
      result[itemId] = prio
    else
--      BPGP.Print(L["Wishlist Import: Warning! Ignored line %d ('%s' is not a number above 0)!"]:format(i, itemString))
    end
  end
  return result
end
  
function DistributionTracker.ImportWishlist(data)
  DistributionTracker.db.profile.cache.wishlist = data
  BPGP.Print(L["Wishlist Import: Successfully imported %d items!"]:format(Common:KeysCount(data)))
end
  
function DistributionTracker.GetWishlistStatus(itemLink)
  local itemId = tonumber(Common:GetItemId(itemLink))
  if not itemId or itemId == 0 then return false end
  return DistributionTracker.db.profile.cache.wishlist[itemId]
end
