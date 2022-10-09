local _, BPGP = ...

local GUI = BPGP.NewModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      backgroundColor = {0, 0, 0, 1},
      borderColor = {1, 1, 1, 1},
      lootFilterLocked = true,
      cache = {
        lastSideframe = nil,
        lastAwards = {},
        showCooldownsFrame = false,
        lockCooldownsFrame = false,
        showWipeProtectionFrame = false,
        lockWipeProtectionFrame = false,
      },
    },
  },
  frames = {},
  sideframes = {},
  raidOnlyControls = {},
}
Debugger.Attach("GUI", private)

function GUI:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("GUI", private.dbDefaults)
  GUI.CreateBPGPFrame()
  GUI.CreateBPGPFrameStandings()
  GUI.CreateBPGPDataExportFrame()
  GUI.CreateBPGPDataImportFrame()
  GUI.CreateBPGPCooldownsFrame()
  GUI.CreateBPGPWipeProtectionFrame()
  BPGP.Fire("LoadWidgets")
  -- TODO: Encapsulate RaidCooldowns and WipeProtection modules to widgets, make all widgets unloadable.
end

function GUI:OnEnable()
  GUI.LootItemsResume()
  GUI.ToggleSideFrame(GUI.db.profile.lastSideframe)
  HideUIPanel(BPGPFrame)
  BPGPFrame:SetScript("OnShow", GUI.OnShow)
  if GUI.db.profile.cache.showCooldownsFrame then
    BPGPCooldownsFrame:Show()
  end
  if GUI.db.profile.cache.showWipeProtectionFrame then
    BPGPWipeProtectionFrame:Show()
  end
--  ShowUIPanel(BPGPFrame)
end

function GUI:OnDisable()
end

----------------------------------------
-- Event handlers
----------------------------------------

function GUI:OnShow()
  GUI.ToggleRaidOlnyControls()
  
end

----------------------------------------
-- Public interface
----------------------------------------

function GUI.GetButtonTextPadding()
  return 20
end

function GUI.GetButtonHeight()
  return 22
end

function GUI.GetRowTextPadding()
  return 5
end

function GUI.RegisterRaidOlnyControl(frame)
  tinsert(private.raidOnlyControls, frame)
end

function GUI.ToggleRaidOlnyControls()
  if DataManager.SelfInRaid() then
    for i, v in pairs(private.raidOnlyControls) do v:Enable() end
    GUI.UpdateBPGPCooldownsFrameMetadata(true)
    GUI.UpdateBPGPWipeProtectionFrameMetadata(true)
  else
    for i, v in pairs(private.raidOnlyControls) do v:Disable() end
    GUI.UpdateBPGPCooldownsFrameMetadata(false)
    GUI.UpdateBPGPWipeProtectionFrameMetadata(false)
  end
end

function GUI.RegisterSideframe(frame)
  tinsert(private.sideframes, frame)
end

function GUI.ToggleSideFrame(frame)
  for _, f in ipairs(private.sideframes) do
    if f == frame or f:GetName() == frame then
      if f:IsShown() then
        f:Hide()
      else
        f:Show()
      end
    else
      f:Hide()
    end
  end
end

function GUI.RememberLastSideFrame()
  GUI.db.profile.lastSideframe = ""
  for _, f in ipairs(private.sideframes) do
    if f:IsShown() then GUI.db.profile.lastSideframe = f:GetName() break end
  end
end

function GUI.CreateCustomFrame(name, parent, features)
	local f = CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate")
	if features:find("DefaultBackdrop") then
		f:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\CHATFRAMEBACKGROUND",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left=5, right=6, top=6, bottom=5 }
		})
    f:SetBackdropColor(unpack(GUI.db.profile.backgroundColor))
    f:SetBackdropBorderColor(unpack(GUI.db.profile.borderColor))
	end
	if features:find("CloseButtonX") then
		local t = f:CreateTexture(nil, "OVERLAY")
		t:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		cb:SetPoint("TOPRIGHT", f, "TOPRIGHT", 3, 3)
	end
	if features:find("DialogHeader") then
    local header = f:CreateTexture(nil, "OVERLAY")
    header:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    header:SetTexCoord(0.31, 0.67, 0, 0.63)
    header:SetPoint("TOP", -5, 28)
    header:SetWidth(300)
    header:SetHeight(40)
    local header_l = f:CreateTexture(nil, "OVERLAY")
    header_l:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    header_l:SetTexCoord(0.21, 0.31, 0, 0.63)
    header_l:SetPoint("RIGHT", header, "LEFT", 5, 0)
    header_l:SetWidth(30)
    header_l:SetHeight(40)
    local header_r = f:CreateTexture(nil, "OVERLAY")
    header_r:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
    header_r:SetTexCoord(0.67, 0.77, 0, 0.63)
    header_r:SetPoint("LEFT", header, "RIGHT", 0, 0)
    header_r:SetWidth(30)
    header_r:SetHeight(40)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetHeight(16)
    text:SetPoint("TOP", header, "TOP", 5, -13)
    header.text = text
    f.header = header
    f.SetHeader = function(self, headerText)
      self.header.text:SetText(headerText)
      self.header:SetWidth(self.header.text:GetWidth()+10)
    end
    if features:find("CloseButtonHeaderX") then
      local t1 = GUI.CreateCustomFrame(nil, f, "DefaultBackdrop")
      t1:SetPoint("LEFT", text, "RIGHT", 21, 2)
      t1:SetWidth(26)
      t1:SetHeight(26)
      local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
      cb:SetPoint("LEFT", t1, "LEFT", -2, 0)
    end
	end
  tinsert(private.frames, f)
	return f
end

function GUI.CreateBPGPFrame()
  local f = GUI.CreateCustomFrame("BPGPFrame", UIParent, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  
  f:Hide()

  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetUserPlaced(true)
  f:SetClampedToScreen(true)
  
  f:SetPoint("TOPLEFT", nil, "TOPLEFT", 20, -100)
  f:SetWidth(480)
  f:SetHeight(525)

  f:SetHitRectInsets(0, 0, -20, 0)

  f:SetScript("OnMouseDown", function (self) self:StartMoving() end)
  f:SetScript("OnMouseUp", function (self) self:StopMovingOrSizing() end)

  f:SetHeader("BPGP Loot System "..BPGP.GetVersion())
  
  f:SetScript("OnUpdate", DataManager.UpdateData)
  f:SetScript("OnHide", function() GUI.RememberLastSideFrame() end)
  
  tinsert(UISpecialFrames, f:GetName())
end

function GUI.UpdateFrames()
  for i = 1, #private.frames do
    local frame = private.frames[i]
    frame:SetBackdropColor(unpack(GUI.db.profile.backgroundColor))
    frame:SetBackdropBorderColor(unpack(GUI.db.profile.borderColor))
  end
end

--local function Add_Item_Level(tooltip)
--    local _, itemLink = tooltip:GetItem()
--    local _, _, _, itemLevel = GetItemInfo(itemLink)
--    tooltip:AddLine("Item Level "..tostring(itemLevel))
--end

--GameTooltip:HookScript("OnTooltipSetItem", Add_Item_Level)