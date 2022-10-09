local _, BPGP = ...

local VashjHelper = BPGP.GetModule("VashjHelper")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local GUI = BPGP.GetModule("GUI")
local DataManager = BPGP.GetModule("DataManager")

local MouseIsOver = MouseIsOver

local select, pairs, ipairs = select, pairs, ipairs
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetServerTime = GetServerTime

local private = {
  taintedCoreIcon = GetItemIcon(31088)
}

function private.HandleLoadWidgets()
  VashjHelper.CreateBPGPVashjHelperFrame()
end
BPGP.RegisterCallback("LoadWidgets", private.HandleLoadWidgets)

function VashjHelper.ShowWidgetFrame()
  private.frame:Show()
end

function VashjHelper.HideWidgetFrame()
  private.frame:Hide()
end

-- Toggle core widget frame
function VashjHelper.ToggleWidgetFrame()
  if private.frame:IsShown() then
    VashjHelper.HideWidgetFrame()
  else
    VashjHelper.ShowWidgetFrame()
  end
  VashjHelper.db.profile.showFrame = private.frame:IsShown()
end

----------------------------------------
-- Core VashjHelper widget frame
----------------------------------------
  
function VashjHelper.CreateBPGPVashjHelperFrame()
	local f = GUI.CreateCustomFrame("BPGPVashjHelperFrame", UIParent, "")
	f:Hide()
	f:SetWidth(110)
	f:SetHeight(70)
  
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetUserPlaced(true)
  f:SetClampedToScreen(true)
  
  f:SetPoint("TOP", nil, "TOP", 0, -24)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", f, "TOP", 0, 0)
  label:SetJustifyH("CENTER")
	label:SetText(L["Vashj Helper"])
  
  f.playerFrames = {}

  for i = 1, 5 do
    local previousFrame = f.playerFrames[i - 1] or label
    table.insert(f.playerFrames, private.CreatePlayerFrame(f, previousFrame))
  end

  f.Update = function()
    local taintedCores = VashjHelper.GetTaintedCoresStatus()
    local i = 1
    for playerName, timeLooted in pairs(taintedCores) do
      local playerFrame = f.playerFrames[i]
      if timeLooted then
        playerFrame.name:SetText(playerName)
        local timeDiff = GetServerTime() - timeLooted
        playerFrame.time:SetText(string.format("%d:%02d", timeDiff / 60, timeDiff % 60))
        local color = DataManager.GetRaidClassColor(playerName)
        playerFrame:SetBackdropColor(color.r, color.g, color.b, 0.65)
        if UnitIsDeadOrGhost(playerName) then
          playerFrame.name:SetTextColor(1, 0, 0)
        else
          playerFrame.name:SetTextColor(1, 1, 1)
        end
        playerFrame:Show()
      else
        playerFrame:Hide()
      end
      i = i + 1
    end
    for i = i, 5 do
      f.playerFrames[i]:Hide()
    end
  end
  BPGP.RegisterCallback("TaintedCoresStatusUpdate", f.Update)

  function f.AsyncUpdate()
    while f:IsShown() do
      f.Update()
      Coroutine:Sleep(0.1)
    end
  end
  
  f:SetScript("OnShow", function (self)
    Coroutine:RunAsync(f.AsyncUpdate)
  end)

  ----------------------------------------
  -- Menu
  ----------------------------------------
  local titleDropDownMenu = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  titleDropDownMenu.displayMode = "MENU"
  local info = {}
  titleDropDownMenu.initialize = function(self, level)
    wipe(info)
    if VashjHelper.db.profile.lockFrame then
      info.text = L["Unlock Window"]
    else
      info.text = L["Lock Window"]
    end
    info.func = function()
      VashjHelper.db.profile.lockFrame = not VashjHelper.db.profile.lockFrame
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
    wipe(info)
    info.text = L["Hide Window"]
    info.func = function()
      VashjHelper.ToggleWidgetFrame()
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
  
  ----------------------------------------
  -- Frame Drag with lock
  ----------------------------------------
  f:SetScript("OnMouseDown", function (self, button)
    if button == "LeftButton" then
      CloseDropDownMenus(1)
      if not VashjHelper.db.profile.lockFrame then
        self:StartMoving()
      end
    elseif button == "RightButton" then
      ToggleDropDownMenu(1, nil, titleDropDownMenu, label, 0, 0)
    end
  end)
  f:SetScript("OnMouseUp", function (self)
    if not VashjHelper.db.profile.lockFrame then
      self:StopMovingOrSizing()
    end
  end)

  private.frame = f
end

function private.CreatePlayerFrame(parent, previousFrame)
  local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
  f:Hide()
  f:SetWidth(110)
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
--  f.cdFrame:SetPoint("TOP", f, "TOP", 0, -1)
  f.cdFrame:SetHeight(12)
  f.cdFrame:SetWidth(40)
  
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.name:SetPoint("LEFT", f, "LEFT", 4, 0)
	f.name:SetPoint("RIGHT", f.cdFrame, "LEFT", 0, 0)
  f.name:SetJustifyH("LEFT")

  f.icon = f.cdFrame:CreateTexture(nil, ARTWORK)
  f.icon:SetWidth(12)
  f.icon:SetHeight(12)
	f.icon:SetPoint("LEFT", f.cdFrame, "LEFT", 2, 0)
  f.icon:SetTexture(private.taintedCoreIcon)
  
  f.time = f.cdFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.time:SetPoint("LEFT", f.icon, "RIGHT", 2, 0)
  
  return f
end
