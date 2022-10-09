local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Common = BPGP.GetLibrary("Common")

local DistributionTracker = BPGP.GetModule("DistributionTracker")

local unpack = unpack
local GetItemIcon = GetItemIcon

local private = {
  frame = nil,
}

function GUI.CreateBPGPOngoingDistributionFrame()
	local f = GUI.CreateCustomFrame("BPGPOngoingDistributionFrame", BPGPFrame, "DefaultBackdrop, CloseButtonX")

	f:Hide()
	f:SetFrameStrata("HIGH")
	f:SetPoint("BOTTOM", BPGPFrame, "TOP", 0, -6)
	f:SetWidth(480)
	f:SetHeight(35)
  f:EnableMouse(false)

	f.mode = 0

	local itemName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	itemName:SetPoint("TOP", f, "TOP", 0, -12)

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

	local comment = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	comment:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
	comment:SetWidth(460)
	comment:SetMaxLines(2)
  
	f.itemName = itemName
	f.itemIcon = itemIcon
	f.comment = comment

--	f:SetScript("OnShow", function (self)
--  end)

	f:SetScript("OnHide", function (self)
    if BPGPFrame:IsShown() then
      if f.cachedBPGPFrameHeaderPoint and f.cachedBPGPFrameHitRectInsets then
        BPGPFrame.header:SetPoint(unpack(f.cachedBPGPFrameHeaderPoint))
        BPGPFrame:SetHitRectInsets(unpack(f.cachedBPGPFrameHitRectInsets))
      end
    end
  end)

  f.HandleDistributionStart = function(event, itemLink, comment)
    if not f:IsShown() then
      f.cachedBPGPFrameHeaderPoint = {BPGPFrame.header:GetPoint()}
      f.cachedBPGPFrameHitRectInsets = {BPGPFrame:GetHitRectInsets()}
    end
    f:Show()
    f.itemLink = itemLink
    f.itemName:SetText(itemLink)
    f.itemIcon:SetTexture(GetItemIcon(Common:GetItemId(itemLink)))
    if comment ~= "<NONE>" then
      f.comment:SetText(comment)
      f:SetHeight(40 + f.comment:GetHeight())
    else
      f.comment:SetText()
      f:SetHeight(35)
    end
    
    BPGPFrame.header:SetPoint("TOP", -5, 28 + f:GetHeight() - 6)
    BPGPFrame:SetHitRectInsets(0, 0, -20 - f:GetHeight(), 0)
  end
  BPGP.RegisterCallback("LootDistributionStart", f.HandleDistributionStart)
  
  f.HandleDistributionStop = function()
    if f.cachedBPGPFrameHeaderPoint and f.cachedBPGPFrameHitRectInsets then
      BPGPFrame.header:SetPoint(unpack(f.cachedBPGPFrameHeaderPoint))
      BPGPFrame:SetHitRectInsets(unpack(f.cachedBPGPFrameHitRectInsets))
    end
    f:Hide()
  end
  BPGP.RegisterCallback("LootDistributionStop", f.HandleDistributionStop)
  
end