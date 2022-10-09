local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")

local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local LootTracker = BPGP.GetModule("LootTracker")

local private = {}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPSideFrame(self)
	local f = GUI.CreateCustomFrame("BPGPSideFrame", BPGPFrame, "DefaultBackdrop, CloseButtonX")
  GUI.RegisterSideframe(f)

  f:Hide()
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -8)
  f:SetWidth(240)
  f:SetHeight(410)

  local h = f:CreateTexture(nil, "ARTWORK")
  h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  h:SetWidth(300)
  h:SetHeight(68)
  h:SetPoint("TOP", -9, 12)

  f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  f.title:SetPoint("TOP", h, "TOP", 0, -15)

  local gpFrame = CreateFrame("Frame", nil, f)
  gpFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -40)
  gpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -40)

  local bpFrame = CreateFrame("Frame", nil, f)
  bpFrame:SetPoint("TOPLEFT", gpFrame, "BOTTOMLEFT", 0, -25)
  bpFrame:SetPoint("TOPRIGHT", gpFrame, "BOTTOMRIGHT", 0, -25)

  local altFrame = CreateFrame("Frame", nil, f)
  altFrame:SetPoint("TOPLEFT", bpFrame, "BOTTOMLEFT", 0, -25)
  altFrame:SetPoint("TOPRIGHT", bpFrame, "BOTTOMRIGHT", 0, -25)
  
  private.AddGPControls(gpFrame)
  private.AddBPControls(bpFrame)
  private.AddAltControls(altFrame)

  f:SetScript("OnShow", function(self)
    if not DataManager.IsInGuild(self.name) then GUI.ToggleSideFrame() return end
    self.title:SetText(self.name)
    if gpFrame.OnShow then gpFrame:OnShow() end
    if bpFrame.OnShow then bpFrame:OnShow() end
    if altFrame.OnShow then altFrame:OnShow() end
  end)
end

function GUI.CreateBPGPSideFrame2()
	local f = GUI.CreateCustomFrame("BPGPSideFrame2", BPGPFrame, "DefaultBackdrop, CloseButtonX")
  GUI.RegisterSideframe(f)

  f:Hide()
  f:SetPoint("BOTTOMLEFT", BPGPFrame, "BOTTOMRIGHT", -6, 8)
  f:SetWidth(240)
  f:SetHeight(170)

  local bpFrame = CreateFrame("Frame", nil, f)
  bpFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -20)
  bpFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -15)
  bpFrame:SetScript("OnShow", function()
    if bpFrame.OnShow then bpFrame:OnShow() end
  end)
  private.AddBPControls(bpFrame, true)
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

function private.BPReasonsDropDown_SetList(dropDown)
  local list = {}
  local seen = {}

  tinsert(list, L["< Custom >"])
  tinsert(list, L["Karazhan"])
  tinsert(list, L["Gruul's Lair"])
  tinsert(list, L["Magtheridon's Lair"])
  tinsert(list, L["Serpentshrine Cavern"])
  tinsert(list, L["Tempest Keep"])
  tinsert(list, L["Hyjal Summit"])
  tinsert(list, L["Black Temple"])
  tinsert(list, L["Zul'Aman"])
  tinsert(list, L["Sunwell Plateau"])
  dropDown:SetList(list)
  
  local text = dropDown.text:GetText()
  for i=1,#list do
    if list[i] == text then
      dropDown:SetValue(i)
      break
    end
  end
end

function private.AddBPControls(frame, massIncrease)
  local bpLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  bpLabel:SetText(L["Award BP"])
  bpLabel:SetPoint("TOPLEFT")
  
  local reasonLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  reasonLabel:SetText(L["Reason"])
  reasonLabel:SetPoint("TOP", bpLabel, "BOTTOM", 0, -5)

  local dropDown = AceGUI:Create("Dropdown")
  dropDown:SetWidth(168)
  dropDown.frame:SetParent(frame)
  dropDown:SetPoint("TOP", reasonLabel, "BOTTOM")
  dropDown:SetPoint("LEFT", frame, "LEFT", 15, 0)
  dropDown.text:SetJustifyH("LEFT")
  dropDown:SetCallback("OnValueChanged", function(self, event, ...)
    local parent = self.frame:GetParent()
    local reason = self.text:GetText()
    local other = reason == L["< Custom >"]
    parent.otherLabel:SetAlpha(other and 1 or 0.25)
    parent.otherEditBox:SetAlpha(other and 1 or 0.25)
    parent.otherEditBox:EnableKeyboard(other)
    parent.otherEditBox:EnableMouse(other)
    if other then
      parent.otherEditBox:SetFocus()
      reason = parent.otherEditBox:GetText()
    else
      parent.otherEditBox:ClearFocus()
    end
    local lastAward = GUI.db.profile.cache.lastAwards[reason]
    if lastAward then
        parent.editBox:SetText(lastAward)
    end
  end)
  dropDown.button:HookScript("OnMouseDown", function(self)
    if not self.obj.open then private.BPReasonsDropDown_SetList(self.obj) end
  end)
  dropDown.button:HookScript("OnClick", function(self)
    if self.obj.open then self.obj.pullout:SetWidth(285) end
  end)
  dropDown.button_cover:HookScript("OnMouseDown", function(self)
    if not self.obj.open then private.BPReasonsDropDown_SetList(self.obj) end
  end)
  dropDown.button_cover:HookScript("OnClick", function(self)
    if self.obj.open then self.obj.pullout:SetWidth(285) end
  end)

  local otherLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  otherLabel:SetText(L["Custom reason"])
  otherLabel:SetPoint("LEFT", reasonLabel)
  otherLabel:SetPoint("TOP", dropDown.frame, "BOTTOM", 0, -5)

  local otherEditBox = CreateFrame("EditBox", "$parentBPControlOtherEditBox", frame, "InputBoxTemplate")
  otherEditBox:SetFontObject("GameFontHighlightSmall")
  otherEditBox:SetHeight(24)
  otherEditBox:SetAutoFocus(false)
  otherEditBox:SetPoint("LEFT", frame, "LEFT", 25, 0)
  otherEditBox:SetPoint("RIGHT", frame, "RIGHT", -15, 0)
  otherEditBox:SetPoint("TOP", otherLabel, "BOTTOM")
  otherEditBox:SetScript("OnTextChanged", function(self)
    local lastAward = GUI.db.profile.cache.lastAwards[self:GetText()]
    if lastAward then
      frame.editBox:SetText(lastAward)
    end
  end)
  hooksecurefunc("ChatEdit_InsertLink", function(itemLink)
    if otherEditBox:IsVisible() and otherEditBox:HasFocus() then
      local insertedItemId = Common:GetItemId(otherEditBox:GetText())
      if Common:GetItemId(otherEditBox:GetText()) then
        if Common:GetItemId(itemLink) == insertedItemId then return end
        otherEditBox:SetText(itemLink)
      else 
        otherEditBox:Insert(itemLink)
      end
      LootTracker.AddRecentLoot(itemLink)
    end
  end)

  local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  label:SetText(L["Amount"])
  label:SetPoint("LEFT", reasonLabel)
  label:SetPoint("TOP", otherEditBox, "BOTTOM")

  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetNormalFontObject("GameFontNormalSmall")
  button:SetHighlightFontObject("GameFontHighlightSmall")
  button:SetDisabledFontObject("GameFontDisableSmall")
  button:SetHeight(GUI.GetButtonHeight())
  button:SetText(L["Award BP"])
  button:SetWidth(button:GetTextWidth() + GUI.GetButtonTextPadding())
  button:SetPoint("RIGHT", otherEditBox, "RIGHT")
  button:SetPoint("TOP", label, "BOTTOM", 0, -1)

  local editBox = CreateFrame("EditBox", "$parentBPControlEditBox", frame, "InputBoxTemplate")
  editBox:SetFontObject("GameFontHighlightSmall")
  editBox:SetHeight(24)
  editBox:SetAutoFocus(false)
  editBox:SetPoint("LEFT", frame, "LEFT", 25, 0)
  editBox:SetPoint("RIGHT", button, "LEFT")
  editBox:SetPoint("TOP", label, "BOTTOM")
      
  button:SetScript("OnClick", function(self)
    local reason = dropDown.text:GetText()
    if reason == L["< Custom >"] then
      reason = otherEditBox:GetText()
    end
    local amount = editBox:GetNumber()
    if massIncrease then
      DataManager.MassAwardBP(reason, amount)
    else
      DataManager.IncBP(frame:GetParent().name, reason, amount)
    end
  end)

  local function EnabledStatus(self)
    local reason = dropDown.text:GetText()
    if reason == L["< Custom >"] then
      reason = otherEditBox:GetText()
    end
    local amount = editBox:GetNumber()
    if DataManager.IsAllowedIncBPGPByX(reason, amount) then
      self:Enable()
    else
      self:Disable()
    end
  end
  button:SetScript("OnUpdate", EnabledStatus)

  frame:SetHeight(
    bpLabel:GetHeight() +
    reasonLabel:GetHeight() +
    dropDown.frame:GetHeight() +
    otherLabel:GetHeight() +
    otherEditBox:GetHeight() +
    label:GetHeight() +
    button:GetHeight())

  frame.reasonLabel = reasonLabel
  frame.dropDown = dropDown
  frame.otherLabel = otherLabel
  frame.otherEditBox = otherEditBox
  frame.label = label
  frame.editBox = editBox
  frame.button = button

  frame.OnShow = function(self)
    if not self.dropDown:GetValue() then
      self.dropDown:SetText(L["< Custom >"])
    end
    self.editBox:SetText(tostring(DataManager.GetBPAward()))
    self.dropDown.frame:Show()
  end
end

function private.AddAltControls(frame)
  local assignLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  assignLabel:SetText(L["Assign main"])
  assignLabel:SetPoint("TOPLEFT")
  
  local reasonLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  reasonLabel:SetText(L["Main's name"])
  reasonLabel:SetPoint("TOP", assignLabel, "BOTTOM", 7, -5)
  
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetNormalFontObject("GameFontNormalSmall")
  button:SetHighlightFontObject("GameFontHighlightSmall")
  button:SetDisabledFontObject("GameFontDisableSmall")
  button:SetHeight(GUI.GetButtonHeight())
  button:SetText(L["Assign"])
  button:SetWidth(button:GetTextWidth() + GUI.GetButtonTextPadding())
  button:SetPoint("RIGHT", frame, "RIGHT", -15, 0)
  button:SetPoint("TOP", reasonLabel, "BOTTOM", 0, -1)
  
  local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  editBox:SetFontObject("GameFontHighlightSmall")
  editBox:SetHeight(24)
  editBox:SetAutoFocus(false)
  editBox:SetPoint("LEFT", frame, "LEFT", 25, 0)
  editBox:SetPoint("RIGHT", button, "LEFT")
  editBox:SetPoint("TOP", reasonLabel, "BOTTOM")
  button:SetScript("OnUpdate", function(self)
    if DataManager.SelfSA() and editBox:GetText() ~= "" then
      self:Enable()
    else
      self:Disable()
    end
  end)
  button:SetScript( "OnClick", function(self)
    DataManager.AssignMain(frame:GetParent().name, editBox:GetText())
  end)
  
  frame:SetHeight(reasonLabel:GetHeight()
    + assignLabel:GetHeight()
    + reasonLabel:GetHeight()
    + editBox:GetHeight()
    + button:GetHeight()
  )

  frame.reasonLabel = reasonLabel
end

function private.AddGPControls(frame)
  local gpLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  gpLabel:SetText(L["Credit GP"])
  gpLabel:SetPoint("TOPLEFT")
  
  local reasonLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  reasonLabel:SetText(L["Reason"])
  reasonLabel:SetPoint("TOP", gpLabel, "BOTTOM", 0, -5)
  
  local reasonBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  reasonBox:SetPoint("LEFT", frame, "LEFT", 25, 0)
  reasonBox:SetPoint("RIGHT", frame, "RIGHT", -15, 0)
  reasonBox:SetPoint("TOP", reasonLabel, "BOTTOM")
  reasonBox:SetFontObject("GameFontHighlightSmall")
  reasonBox:SetHeight(24)
  reasonBox:SetAutoFocus(false)
  reasonBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus() 
  end)
  reasonBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  hooksecurefunc("ChatEdit_InsertLink", function(itemLink)
    if reasonBox:IsVisible() and reasonBox:HasFocus() then
      local insertedItemId = Common:GetItemId(reasonBox:GetText())
      if Common:GetItemId(reasonBox:GetText()) then
        if Common:GetItemId(itemLink) == insertedItemId then return end
        reasonBox:SetText(itemLink)
      else 
        reasonBox:Insert(itemLink)
      end
      LootTracker.AddRecentLoot(itemLink)
    end
  end)
  
  local dropDown = AceGUI:Create("Dropdown")
  dropDown:SetWidth(168)
  dropDown.frame:SetParent(frame)
  dropDown:SetPoint("TOP", reasonBox, "BOTTOM")
  dropDown:SetPoint("LEFT", frame, "LEFT", 15, 0)
  dropDown.text:SetJustifyH("LEFT")
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
  dropDown:SetCallback("OnValueChanged",  function(self)
    reasonBox:SetText(self.text:GetText()) 
  end)
  dropDown:SetText(L["< Recent Items >"])
  
  local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  label:SetText(L["Amount"])
  label:SetPoint("LEFT", reasonLabel)
  label:SetPoint("TOP", dropDown.frame, "BOTTOM", 0, -5)

  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetNormalFontObject("GameFontNormalSmall")
  button:SetHighlightFontObject("GameFontHighlightSmall")
  button:SetDisabledFontObject("GameFontDisableSmall")
  button:SetHeight(GUI.GetButtonHeight())
  button:SetText(L["Credit GP"])
  button:SetWidth(button:GetTextWidth() + GUI.GetButtonTextPadding())
  button:SetPoint("RIGHT", dropDown.frame, "RIGHT", 0, 0)
  button:SetPoint("TOP", label, "BOTTOM", 0, -1)

  local editBox = CreateFrame("EditBox", "$parentGPControlEditBox", frame, "InputBoxTemplate")
  editBox:SetFontObject("GameFontHighlightSmall")
  editBox:SetHeight(24)
  editBox:SetAutoFocus(false)
  editBox:SetPoint("LEFT", frame, "LEFT", 25, 0)
  editBox:SetPoint("RIGHT", button, "LEFT")
  editBox:SetPoint("TOP", label, "BOTTOM")

  local function EditBotSetText(text)
    editBox:SetText(text)
    editBox:SetFocus()
    editBox:HighlightText()
  end
  
  button:SetScript("OnClick", function(self)
    DataManager.IncGP(frame:GetParent().name, reasonBox:GetText(), editBox:GetNumber())
  end)
  button:SetScript("OnUpdate", function(self)
    if DataManager.IsAllowedIncBPGPByX(reasonBox:GetText(), editBox:GetNumber()) then
      self:Enable()
    else
      self:Disable()
    end
  end)

  frame:SetHeight(
    gpLabel:GetHeight() +
    reasonLabel:GetHeight() +
    reasonBox:GetHeight() +
    dropDown.frame:GetHeight() +
    label:GetHeight() +
    button:GetHeight())

  frame.reasonLabel = reasonLabel
  frame.reasonBox = reasonBox
  frame.recentLabel = reasonLabel
  frame.dropDown = dropDown
  frame.label = label
  frame.button = button
  frame.editBox = editBox

  frame.OnShow = function(self)
    self.editBox:SetText(tostring(DataManager.GetGPCredit()))
    self.dropDown:SetValue(nil)
    self.dropDown.frame:Show()
  end
end
