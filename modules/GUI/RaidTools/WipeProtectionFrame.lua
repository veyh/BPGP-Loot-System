local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local string, tinsert, tsort, pairs, wipe, select = string, tinsert, table.sort, pairs, wipe, select
local GetServerTime, UnitBuff, UnitIsDead = GetServerTime, UnitBuff, UnitIsDead

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")
local AceGUI = LibStub("AceGUI-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local DataManager = BPGP.GetModule("DataManager")
local RaidCooldowns = BPGP.GetModule("RaidCooldowns")

local private = {
  playerClassColors = {},
  cachedSpellTextures = {},
  broadcastedCooldowns = nil,
  broadcastedProtections = nil,
  lastBroadcastedProtections = {},
  usedProtections = {},
  activeProtections = {},
  lowRankSoulstones = {},
  timeDiffs = { -- Time differences between cooldown duration and protection effect duration
--    [20906] = 1800 - 60, -- TEST
    [26994] = 1800 - 360, -- Rebirth
    [19752] = 3600 - 180, -- DI
    [27239] = 1800 - 1800, -- SS
    [20608] = 0 - 0, -- Reincarnation
  },
  lowRankSS = {
    [20707] = 1,
    [20762] = 2,
    [20763] = 3,
    [20764] = 4,
    [20765] = 5,
  }
}
Debugger.Attach("WipeProtection", private)

function private.CacheSpellTexture(spellId)
  local spellTexture = GetSpellTexture(spellId)
  private.cachedSpellTextures[spellId] = spellTexture
  return spellTexture
end

function private.GetSpellTexture(spellId)
  return private.cachedSpellTextures[spellId] or private.CacheSpellTexture(spellId)
end

function GUI.UpdateBPGPWipeProtectionFrameMetadata(isInRaid)
  if DataManager.SelfInRaid() then
    if GUI.db.profile.cache.showWipeProtectionFrame then
      private.frame:Show()
    end
  else
    private.frame:Hide()
  end
end

function GUI.ToggleBPGPWipeProtectionFrame()
  if private.frame:IsShown() then
    private.frame:Hide()
  else
    private.frame:Show()
  end
  GUI.db.profile.cache.showWipeProtectionFrame = private.frame:IsShown()
end

function GUI.CreateBPGPWipeProtectionFrame()
	local f = GUI.CreateCustomFrame("BPGPWipeProtectionFrame", UIParent, "")
	f:Hide()
	f:SetWidth(110)
	f:SetHeight(60)
  
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetUserPlaced(true)
  f:SetClampedToScreen(true)
  
  f:SetPoint("TOPLEFT", nil, "TOPLEFT", 30, -400)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", f, "TOP", 0, 0)
  label:SetJustifyH("CENTER")
	label:SetText(L["Wipe Protection"])
  
  local titleDropDownMenu = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  titleDropDownMenu.displayMode = "MENU"
  local info = {}
  titleDropDownMenu.initialize = function(self, level)
    wipe(info)
    if GUI.db.profile.cache.lockWipeProtectionFrame then
      info.text = L["Unlock Window"]
    else
      info.text = L["Lock Window"]
    end
    info.func = function()
      GUI.db.profile.cache.lockWipeProtectionFrame = not GUI.db.profile.cache.lockWipeProtectionFrame
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
    wipe(info)
    info.text = L["Hide Window"]
    info.func = function()
      GUI.ToggleBPGPWipeProtectionFrame()
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
    wipe(info)
    info.text = L["Cancel"]
    info.func = function()
      CloseDropDownMenus(1)
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
  end

  f:SetScript("OnMouseDown", function (self, button)
    if button == "LeftButton" then
      CloseDropDownMenus(1)
      if not GUI.db.profile.cache.lockWipeProtectionFrame then
        self:StartMoving()
      end
    elseif button == "RightButton" then
      ToggleDropDownMenu(1, nil, titleDropDownMenu, label, 0, 0)
    end
  end)
  f:SetScript("OnMouseUp", function (self)
    if not GUI.db.profile.cache.lockWipeProtectionFrame then
      self:StopMovingOrSizing()
    end
  end)

  f.playerFrames = {}

  for i = 1, 10 do
    local previousFrame = f.playerFrames[i - 1] or label
    table.insert(f.playerFrames, private.CreatePlayerFrame(f, previousFrame))
  end

  f:SetScript("OnShow", function (self)
    private.broadcastedCooldowns = RaidCooldowns.GetCooldowns()
    private.broadcastedProtections = RaidCooldowns.GetProtections()
    for spellId in pairs(private.broadcastedProtections) do
      if not private.activeProtections[spellId] then
        private.activeProtections[spellId] = {}
        private.lastBroadcastedProtections[spellId] = {}
        private.usedProtections[spellId] = {}
      end
    end
    private.activeProtections[20608] = {}
    Coroutine:RunAsync(private.AsyncUpdateWipeProtectionFrame)
  end)

--  f:SetScript("OnHide", function (self)
--  end)

  private.frame = f
end

function private.CreatePlayerFrame(parent, previousFrame)
  local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
  f:Hide()
  f:SetWidth(120)
  f:SetHeight(14)
	f:SetPoint("TOP", previousFrame, "BOTTOM", 0, -2)
	f:SetPoint("LEFT", parent, "LEFT", 0, 0)
  f:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\CHATFRAMEBACKGROUND",
    tile = true,
    tileSize = 16,
  })
  
  f.cdFrame = CreateFrame("Frame", nil, f)
	f.cdFrame:SetPoint("RIGHT", f, "RIGHT", -2, 0)
  f.cdFrame:SetHeight(12)
  f.cdFrame:SetWidth(48)
  
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.name:SetPoint("LEFT", f, "LEFT", 4, 0)
	f.name:SetPoint("RIGHT", f.cdFrame, "LEFT", 0, 0)
  f.name:SetJustifyH("LEFT")
  
  f.icon = f.cdFrame:CreateTexture(nil, ARTWORK)
  f.icon:SetWidth(12)
  f.icon:SetHeight(12)
	f.icon:SetPoint("LEFT", f.cdFrame, "LEFT", 0, 0)
  
  f.time = f.cdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.time:SetPoint("LEFT", f.icon, "RIGHT", 2, 0)
	f.time:SetPoint("RIGHT", f.cdFrame, "RIGHT", 0, 0)
  
  return f
end

function private.AsyncUpdateWipeProtectionFrame()
  while private.frame:IsShown() do
--    local startTime = debugprofilestop()
--    Debugger("AsyncUpdateWipeProtectionFrame took "..tostring(debugprofilestop() - startTime).." ms")
    private.UpdateWipeProtectionFrame()
    Coroutine:Sleep(1)
  end
end

function private.UpdateWipeProtectionFrame()
  local serverTime = GetServerTime()
  
  for spellId, protections in pairs(private.broadcastedProtections) do
    -- Here we will store most recent valid buff fading times for each target
    local lastProtections = private.lastBroadcastedProtections[spellId]
    -- Wiping cache tables for re-use
    wipe(lastProtections)
    wipe(private.activeProtections[spellId])
    -- Raw broadcasts data processing
    for cooldownTimeEnd, target in pairs(protections) do
      -- Broadcasts come with cooldown ending times, we need to convert them to buff fading ones
      local newTimeEnd = cooldownTimeEnd - private.timeDiffs[spellId]
      if newTimeEnd < serverTime then
        -- Buff faded, clearing stale entry
        protections[cooldownTimeEnd] = nil
      else
        local oldTimeEnd = lastProtections[target]
        if not oldTimeEnd or newTimeEnd > oldTimeEnd then
          -- This cooldown broadcast is more recent
          if DataManager.IsInRaid(target) then
            -- Target is indexed as raid member, let's guess it's valid time data
            lastProtections[target] = newTimeEnd
          end
          if oldTimeEnd and oldTimeEnd > 0 then
            -- Previous entry is no longer the most recent, let's clear it
            protections[oldTimeEnd + private.timeDiffs[spellId]] = nil
          end
        end
      end
    end
  end
  
  wipe(private.activeProtections[20608])
  wipe(private.lowRankSoulstones)
  for playerName, playerClass in pairs(DataManager.GetRaidDB("class")) do
    if playerClass == "SHAMAN" then
      private.activeProtections[20608][playerName] = 0
      local broadcastedCooldown = private.broadcastedCooldowns[playerName]
      if broadcastedCooldown then 
        local reincarnationCDTimeEnd = broadcastedCooldown[20608]
        if reincarnationCDTimeEnd and serverTime <= reincarnationCDTimeEnd then
          private.activeProtections[20608][playerName] = nil
        end
      end
    end
    for j = 1, 40 do
      local buffId = select(10, UnitBuff(playerName, j))
      if not buffId then break end
      if buffId == 19753 then -- DI
        private.activeProtections[19752][playerName] = 0
      elseif buffId == 27239 then -- SS
        private.activeProtections[27239][playerName] = 0
      elseif private.lowRankSS[buffId] then
        -- Used for low rank warning
        private.lowRankSoulstones[playerName] = private.lowRankSS[buffId]
        private.activeProtections[27239][playerName] = 0
--      elseif buffId == 20906 then -- TEST
--        private.activeProtections[20906][playerName] = 0
      end
    end
  end
  
  for spellId, protections in pairs(private.lastBroadcastedProtections) do
    local activeProtections = private.activeProtections[spellId]
    for playerName, timeEnd in pairs(protections) do
      local playerAlive = not UnitIsDead(playerName)
      if activeProtections[playerName] == 0 then
        -- Buff is found, we're going do display its actual duration
        activeProtections[playerName] = timeEnd -- Overriding zero time with received one
        private.usedProtections[spellId][playerName] = nil
      else
        -- Clearing Rebirth or Soulstone broadcasted data if player is alive to prevent displaying on next death
        if playerAlive then
          local usedTimeEnd = private.usedProtections[spellId][playerName]
          if usedTimeEnd and timeEnd <= usedTimeEnd then
            private.broadcastedProtections[spellId][timeEnd + private.timeDiffs[spellId]] = nil
          end
        end
        if spellId ~= 19752 then
          -- No buff found, most likely this Rebirth or SS effect is active or already used 
          private.usedProtections[spellId][playerName] = timeEnd
          -- If player is dead, we need to display pending resurrection
          if not playerAlive then
            -- Trying to display Rebirth or SS if player is dead
            activeProtections[playerName] = timeEnd
  --        elseif spellId == 20906 then -- TEST
  --          private.broadcastedProtections[20906][timeEnd + private.timeDiffs[20906]] = nil
          end
        end
      end
    end
  end
    
  local f = private.frame
  local frameId = 1
  
  for spellId, protections in pairs(private.activeProtections) do
    for playerName, timeEnd in pairs(protections) do
      if frameId > 10 then break end
      local playerFrame = f.playerFrames[frameId]
      frameId = frameId + 1
      playerFrame.name:SetText(playerName)
      playerFrame.icon:SetTexture(private.GetSpellTexture(spellId))
      local duration = timeEnd - serverTime
      if spellId == 27239 and private.lowRankSoulstones[playerName] then
        playerFrame.time:SetText("|cFFFF0000"..L["Rank%d"]:format(private.lowRankSoulstones[playerName]).."|r")
      elseif duration > 0 then
        playerFrame.time:SetText(string.format("%02d:%02d", duration / 60, duration % 60))
      elseif spellId == 20608 then
        playerFrame.time:SetText(L["∞"])      
      else
        playerFrame.time:SetText(L["N/A"])
      end
      local color = DataManager.GetRaidClassColor(playerName)
      playerFrame:SetBackdropColor(color.r, color.g, color.b, 0.65)
      playerFrame:Show()
    end
  end
    
  for i = frameId, #f.playerFrames do
    f.playerFrames[i]:Hide()
  end
end