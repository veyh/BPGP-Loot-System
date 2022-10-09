local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local string, tinsert, tsort, pairs, wipe = string, tinsert, table.sort, pairs, wipe
local GetServerTime = GetServerTime

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")
local AceGUI = LibStub("AceGUI-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local DataManager = BPGP.GetModule("DataManager")
local RaidCooldowns = BPGP.GetModule("RaidCooldowns")

local private = {
  numRaidMembers = 0,
  classOrder = {["WARRIOR"]=1,["DRUID"]=2,["PALADIN"]=3,["WARLOCK"]=4,["PRIEST"]=5,["HUNTER"]=6,["ROGUE"]=7,["MAGE"]=8,["SHAMAN"]=9},
  iterationOrder = {},
  cachedSpellTextures = {},
}
Debugger.Attach("CooldownsFrame", private)

function private.UpdateMetadata()
  local numRaidMembers = DataManager.GetNumRaidMembers()
  if numRaidMembers == private.numRaidMembers then return end
  wipe(private.iterationOrder)
  local trackedClasses, classOrder = RaidCooldowns.GetTrackedCooldownsList(), {}
  for playerName, playerClass in pairs(DataManager.GetRaidDB("class")) do
    if trackedClasses[playerClass] then
      tinsert(private.iterationOrder, playerName)
      classOrder[playerName] = private.classOrder[playerClass]
    end
  end
  tsort(private.iterationOrder, function(a, b)
    if classOrder[a] == classOrder[b] then
      return a < b
    else
      return classOrder[a] < classOrder[b]
    end
  end)
  private.numRaidMembers = numRaidMembers
end

function private.CacheSpellTexture(spellId)
  local spellTexture = GetSpellTexture(spellId)
  private.cachedSpellTextures[spellId] = spellTexture
  return spellTexture
end

function private.GetSpellTexture(spellId)
  return private.cachedSpellTextures[spellId] or private.CacheSpellTexture(spellId)
end

function GUI.UpdateBPGPCooldownsFrameMetadata(isInRaid)
  if DataManager.SelfInRaid() then
    if GUI.db.profile.cache.showCooldownsFrame then
      private.frame:Show()
    end
  else
    private.frame:Hide()
    private.numRaidMembers = 0
  end
end

function GUI.ToggleBPGPCooldownsFrame()
  if private.frame:IsShown() then
    private.frame:Hide()
  else
    private.frame:Show()
  end
  GUI.db.profile.cache.showCooldownsFrame = private.frame:IsShown()
end

function GUI.CreateBPGPCooldownsFrame()
	local f = GUI.CreateCustomFrame("BPGPCooldownsFrame", UIParent, "")
	f:Hide()
	f:SetWidth(150)
	f:SetHeight(110)
  
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetUserPlaced(true)
  f:SetClampedToScreen(true)
  
  f:SetPoint("TOPLEFT", nil, "TOPLEFT", 30, -300)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", f, "TOP", 0, 0)
  label:SetJustifyH("CENTER")
	label:SetText(L["Raid Cooldowns"])
  
  local titleDropDownMenu = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  titleDropDownMenu.displayMode = "MENU"
  local info = {}
  titleDropDownMenu.initialize = function(self, level)
    wipe(info)
    if GUI.db.profile.cache.lockCooldownsFrame then
      info.text = L["Unlock Window"]
    else
      info.text = L["Lock Window"]
    end
    info.func = function()
      GUI.db.profile.cache.lockCooldownsFrame = not GUI.db.profile.cache.lockCooldownsFrame
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
    wipe(info)
    info.text = L["Hide Window"]
    info.func = function()
      GUI.ToggleBPGPCooldownsFrame()
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
      if not GUI.db.profile.cache.lockCooldownsFrame then
        self:StartMoving()
      end
    elseif button == "RightButton" then
      ToggleDropDownMenu(1, nil, titleDropDownMenu, label, 0, 0)
    end
  end)
  f:SetScript("OnMouseUp", function (self)
    if not GUI.db.profile.cache.lockCooldownsFrame then
      self:StopMovingOrSizing()
    end
  end)

  f.playerFrames = {}

  for i = 1, 40 do
    local previousFrame = f.playerFrames[i - 1] or label
    table.insert(f.playerFrames, private.CreatePlayerFrame(f, previousFrame))
  end

  f:SetScript("OnShow", function (self)
    Coroutine:RunAsync(private.AsyncUpdateCooldownsFrame)
  end)

  private.frame = f
end

function private.CreatePlayerFrame(parent, previousFrame)
  local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
  f:Hide()
  f:SetWidth(150)
	f:SetPoint("TOP", previousFrame, "BOTTOM", 0, -2)
	f:SetPoint("LEFT", parent, "LEFT", 0, 0)
  f:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\CHATFRAMEBACKGROUND",
    tile = true,
    tileSize = 16,
  })
  f.icons = {}
  f.times = {}
  
  f.cdFrame = CreateFrame("Frame", nil, f)
	f.cdFrame:SetPoint("RIGHT", f, "RIGHT", -2, 0)
  
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.name:SetPoint("LEFT", f, "LEFT", 4, 0)
	f.name:SetPoint("RIGHT", f.cdFrame, "LEFT", 0, 0)
  f.name:SetJustifyH("LEFT")
  
  for i = 1, 4 do
    table.insert(f.icons, f.cdFrame:CreateTexture(nil, ARTWORK))
    f.icons[i]:SetWidth(12)
    f.icons[i]:SetHeight(12)
    table.insert(f.times, f.cdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
  end
  
	f.icons[1]:SetPoint("LEFT", f.cdFrame, "LEFT", 0, 0)
	f.times[1]:SetPoint("LEFT", f.icons[1], "RIGHT", 1, 0)
  
	f.icons[2]:SetPoint("LEFT", f.icons[1], "RIGHT", 33, 0)
	f.times[2]:SetPoint("LEFT", f.icons[2], "RIGHT", 1, 0)
  
	f.icons[3]:SetPoint("TOP", f.icons[1], "BOTTOM", 0, 0)
	f.icons[3]:SetPoint("LEFT", f.cdFrame, "LEFT", 0, 0)
	f.times[3]:SetPoint("LEFT", f.icons[3], "RIGHT", 1, 0)
  
	f.icons[4]:SetPoint("TOP", f.icons[2], "BOTTOM", 0, 0)
	f.icons[4]:SetPoint("LEFT", f.icons[3], "RIGHT", 33, 0)
	f.times[4]:SetPoint("LEFT", f.icons[4], "RIGHT", 1, 0)
  
  return f
end

function private.AsyncUpdateCooldownsFrame()
  while private.frame:IsShown() do
--    local startTime = debugprofilestop()
    private.UpdateMetadata()
    private.UpdateCooldownsFrame()
--    Debugger("AsyncUpdateCooldownsFrame took "..tostring(debugprofilestop() - startTime).." ms")
    Coroutine:Sleep(0.5)
  end
end

function private.UpdateCooldownsFrame()
  local serverTime = GetServerTime()
  local f = private.frame
  local frameId = 1
  local cooldownsData = RaidCooldowns.GetCooldowns()
  for i = 1, #private.iterationOrder do
    local playerName = private.iterationOrder[i]
    local cooldowns = cooldownsData[playerName]
    if cooldowns then
      local playerFrame = f.playerFrames[frameId]
      local renderCooldowns = {}
      for spellId, cooldownEnds in pairs(cooldowns) do
        local timeLeft = cooldownEnds - serverTime
        if timeLeft > 0 then
          tinsert(renderCooldowns, {spellId, timeLeft})
        else
          cooldowns[spellId] = nil
        end
      end
      if #renderCooldowns > 0 then
        frameId = frameId + 1
        tsort(renderCooldowns, function(a, b) return a[2] > b[2] end)
        for i = 1, #renderCooldowns do
          playerFrame.icons[i]:SetTexture(private.GetSpellTexture(renderCooldowns[i][1]))
          playerFrame.times[i]:SetText(string.format("%02d:%02d", renderCooldowns[i][2] / 60, renderCooldowns[i][2] % 60))
          playerFrame.icons[i]:Show()
          playerFrame.times[i]:Show()
        end
        playerFrame.name:SetText(playerName)
        local color = DataManager.GetRaidClassColor(playerName)
        playerFrame:SetBackdropColor(color.r, color.g, color.b, 0.65)
        if #renderCooldowns == 1 then
          playerFrame.cdFrame:SetPoint("TOP", playerFrame, "TOP", 0, -1)
          playerFrame.cdFrame:SetHeight(12)
          playerFrame.cdFrame:SetWidth(45)
          playerFrame:SetHeight(14)
        elseif #renderCooldowns == 2 then
          playerFrame.cdFrame:SetPoint("TOP", playerFrame, "TOP", 0, -1)
          playerFrame.cdFrame:SetHeight(12)
          playerFrame.cdFrame:SetWidth(90)
          playerFrame:SetHeight(14)
        else
          playerFrame.cdFrame:SetPoint("TOP", playerFrame, "TOP", 0, 5)
          playerFrame.cdFrame:SetHeight(24)
          playerFrame.cdFrame:SetWidth(90)
          playerFrame:SetHeight(26)
        end
        playerFrame:Show()
      end
      for i = #renderCooldowns + 1, 4 do
        playerFrame.icons[i]:Hide()
        playerFrame.times[i]:Hide()
      end
    end
  end
  for i = frameId, #f.playerFrames do
    f.playerFrames[i]:Hide()
  end
end