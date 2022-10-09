local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Common = BPGP.GetLibrary("Common")

local MasterLooter = BPGP.GetModule("MasterLooter")
local DistributionTracker = BPGP.GetModule("DistributionTracker")

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPDistributionStartFrame()
	local f = GUI.CreateCustomFrame("BPGPDistributionStartFrame", BPGPFrame, "DefaultBackdrop, CloseButtonX")
  GUI.RegisterSideframe(f)

	f:Hide()
	f:SetFrameStrata("HIGH")
	f:SetPoint("LEFT", BPGPSideFrame, "LEFT", -84, -20)
	f:SetWidth(380)
	f:SetHeight(110)
  f:EnableMouse(true)

	f.mode = 0

	local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOP", f, 0, -20)

	local itemName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	itemName:SetPoint("TOP", label, "BOTTOM", 8, -2)

	local itemIcon = f:CreateTexture(nil, ARTWORK)
	itemIcon:SetPoint("RIGHT", itemName, "LEFT", -2, 0)
	itemIcon:SetWidth(14)
	itemIcon:SetHeight(14)
  
	local nameFrame = CreateFrame("Frame", nil, f)
	nameFrame:SetAllPoints(itemIcon)
	nameFrame:SetPoint("RIGHT", itemName, "RIGHT")
	nameFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 3, nameFrame:GetHeight() + 6)
    GameTooltip:SetHyperlink(f.itemLink)
  end)
	nameFrame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
	nameFrame:EnableMouse(true)

	local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	editBox:SetPoint("TOP", itemName, "BOTTOM", 0, -2)
	editBox:SetPoint("LEFT", f, "LEFT", 20, 0)
	editBox:SetPoint("RIGHT", f, "RIGHT", -15, 0)
	editBox:SetHeight(24)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEditFocusGained", function(self)
    self:SetFontObject("GameFontHighlightSmall")
    if f.editBoxAutoclear then
      self:SetText("")
    end
    f.editBoxFocused = true
  end)

  local disableGreedFrame = CreateFrame("Frame", nil, f)
  disableGreedFrame:SetPoint("BOTTOMLEFT", 13, 15)
  
  local disableGreedCheckButton = CreateFrame("CheckButton", nil, disableGreedFrame, "UICheckButtonTemplate")
  disableGreedCheckButton:SetWidth(20)
  disableGreedCheckButton:SetHeight(20)
  disableGreedCheckButton:SetPoint("LEFT")
  disableGreedCheckButton:SetScript("OnClick", function(self)
    f.disableGreed = not f.disableGreed
  end)

  local disableGreedCheckButtonLabel = disableGreedFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  disableGreedCheckButtonLabel:SetPoint("LEFT", disableGreedCheckButton, "RIGHT", 2, 0)
  disableGreedCheckButtonLabel:SetText(L["Disable Greed"])
  
  disableGreedFrame:SetWidth(disableGreedCheckButton:GetWidth() + disableGreedCheckButtonLabel:GetWidth())
  disableGreedFrame:SetHeight(disableGreedCheckButton:GetHeight())
  disableGreedFrame:SetScript("OnMouseDown", function(self)
    f.disableGreed = not f.disableGreed
    disableGreedCheckButton:SetChecked(f.disableGreed)
  end)

	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetPoint("TOP", editBox, "BOTTOM", 0, -2)
	button:SetText(L["Announce"])
	button:SetHeight(GUI.GetButtonHeight())
	button:SetWidth(button:GetTextWidth() + GUI.GetButtonTextPadding())
	button:SetNormalFontObject("GameFontNormal")
	button:SetHighlightFontObject("GameFontHighlight")
	button:SetDisabledFontObject("GameFontDisable")
	button:SetScript("OnClick", function(self)
    local extraText = ""
    if f.editBoxFocused then extraText = editBox:GetText() end
    BPGP.GetModule("MasterLooter").StartDistribution(f.disableGreed and 3 or f.mode, f.itemLink, extraText)
    f:Hide()
  end)
  
	f.label = label
	f.itemName = itemName
	f.itemIcon = itemIcon
	f.editBox = editBox
	f.button = button

	f:SetScript("OnShow", function (self)
    self.label:SetText(self.labelText)
    self.itemName:SetText(self.itemLink)
    self.itemIcon:SetTexture(GetItemIcon(Common:GetItemId(self.itemLink)))
    self.editBox:SetFontObject("GameFontDisableSmall")
    self.editBox:SetText(L["Input here optional comment (e.g. 'Main Spec - Casters')"])
    f.editBoxFocused = false
    f.editBoxAutoclear = true
    if MasterLooter.db.profile.autoComments then
      local itemName = select(3, strfind(self.itemLink, "|h%[(.+)%]|h"))
      local autoComment = DistributionTracker.db.profile.cache.lootPopupComments[itemName]
      if autoComment then
        self.editBox:SetText(autoComment)
        f.editBoxAutoclear = false
        self.editBox:SetFocus()
      end
    end
    if f.mode == 1 then
      disableGreedFrame:Hide()
    else
      disableGreedCheckButton:SetChecked(false)
      f.disableGreed = false
      disableGreedFrame:Show()
    end
  end)
end

function GUI.ShowDistributionStartFrame(mode, labelText, itemLink, parentFrame)
  if BPGPDistributionStartFrame:IsShown() then
    BPGPDistributionStartFrame:Hide()
  end
	BPGPDistributionStartFrame:SetPoint("TOP", parentFrame, "BOTTOM", 0, 0)
	BPGPDistributionStartFrame.mode = mode
	BPGPDistributionStartFrame.labelText = labelText
	BPGPDistributionStartFrame.itemLink = itemLink
	BPGPDistributionStartFrame:Show()
end