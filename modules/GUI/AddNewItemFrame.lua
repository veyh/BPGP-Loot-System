local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")

local Common = BPGP.GetLibrary("Common")

local LootTracker = BPGP.GetModule("LootTracker")

local private = {
}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPAddNewItemFrame()
	local f = GUI.CreateCustomFrame("BPGPAddNewItemFrame", BPGPFrame, "DefaultBackdrop, CloseButtonX")
  GUI.RegisterSideframe(f)

	f:Hide()
	f:SetFrameStrata("HIGH")
	f:SetPoint("TOP", BPGPSideFrame, "TOP", 5, -35)
	f:SetWidth(280)
	f:SetHeight(120)
  f:EnableMouse(true)
  
	local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOP", f, 0, -20)
  label:SetText(L["Add to the loot list:"])
  
  local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  editBox:SetPoint("TOP", label, "BOTTOM")
  editBox:SetFontObject("GameFontDisableSmall")
	editBox:SetWidth(240)
  editBox:SetHeight(24)
  editBox:SetAutoFocus(false)
  editBox:SetScript("OnTextChanged", function(self)
    if Common:GetItemId(f.itemLink) then
      editBox:SetText(f.itemLink)
      f.button:Enable()
    else
      editBox:SetText(L["Insert new item or choose a recently seen one"])
      f.button:Disable()
    end
  end)
  editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  hooksecurefunc("ChatEdit_InsertLink", function(itemLink)
    if editBox:IsVisible() and editBox:HasFocus() then
      if Common:GetItemId(itemLink) then
        f.itemLink = itemLink
        editBox:SetText(itemLink)
        LootTracker.AddRecentLoot(itemLink)
      end
    end
  end)
  
  local dropDown = AceGUI:Create("Dropdown")
  dropDown:SetWidth(180)
  dropDown.frame:SetParent(f)
  dropDown:SetPoint("TOP", editBox, "BOTTOM")
  dropDown.text:SetJustifyH("LEFT")
  dropDown:SetCallback("OnValueChanged", function(self, event, ...)
    local itemLink = self.text:GetText()
    if Common:GetItemId(itemLink) then
      f.itemLink = itemLink
      editBox:SetText(itemLink)
    end
  end)
  dropDown.button:HookScript("OnMouseDown", function(self)
    if not self.obj.open then private.RecentLootDropDown_SetList(self.obj) end
  end)
  dropDown.button:HookScript("OnClick", function(self)
    if self.obj.open then self.obj.pullout:SetWidth(285) end
  end)
  dropDown.button_cover:HookScript("OnMouseDown", function(self)
    if not self.obj.open then private.RecentLootDropDown_SetList(self.obj) end
  end)
  dropDown.button_cover:HookScript("OnClick", function(self)
    if self.obj.open then self.obj.pullout:SetWidth(285) end
  end)
  dropDown:SetCallback("OnEnter", function(self)
    local itemLink = self.text:GetText()
    if Common:GetItemId(itemLink) then
      local anchor = self.open and self.pullout.frame or self.frame:GetParent()
      GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT", 5)
      GameTooltip:SetHyperlink(itemLink)
    end
  end)
  dropDown:SetCallback("OnLeave", function() GameTooltip:Hide() end)

	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
	button:SetText(L["Add Item"])
	button:SetHeight(GUI.GetButtonHeight())
	button:SetWidth(button:GetTextWidth() + GUI.GetButtonTextPadding())
	button:SetNormalFontObject("GameFontNormal")
	button:SetHighlightFontObject("GameFontHighlight")
	button:SetDisabledFontObject("GameFontDisable")
	button:SetScript("OnClick", function(self)
    GUI.LootItemsAdd(editBox:GetText())
    f:Hide()
  end)
  
	f.label = label
	f.dropDown = dropDown
	f.editBox = editBox
	f.button = button

	f:SetScript("OnShow", function (self)
    f.itemLink = nil
    self.editBox:SetText("")
    dropDown:SetValue(0)
    dropDown:SetText(L["< Recent Items >"])
  end)
end

function GUI.ToggleBPGPAddNewItemFrame()
  if BPGPAddNewItemFrame:IsShown() then
    BPGPAddNewItemFrame:Hide()
  else
    BPGPAddNewItemFrame:Show()
  end
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.RecentLootDropDown_SetList(dropDown)
  local list = {}
  for i = 1, LootTracker.GetNumRecentItems() do
    tinsert(list, LootTracker.GetRecentItemLink(i))
  end
  local empty = #list == 0
  if empty then list[1] = EMPTY end
  dropDown:SetList(list)
  dropDown:SetItemDisabled(1, empty)
  if empty then
    dropDown:SetValue(nil)
  else
    local text = dropDown.text:GetText()
    for i=1,#list do
      if list[i] == text then
        dropDown:SetValue(i)
        break
      end
    end
  end
end