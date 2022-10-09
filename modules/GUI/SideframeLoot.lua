local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local DistributionTracker = BPGP.GetModule("DistributionTracker")
local LootTracker = BPGP.GetModule("LootTracker")
local MasterLooter = BPGP.GetModule("MasterLooter")

local private = {
  lootItem = {
    links = {},
    linkMap = {},
    count = 0,
    currentPage = 1,
    frame = nil,
    ITEMS_PER_PAGE = 10,
    MAX_COUNT = 200,
    FULL_WARNING_COUNT = 190
  },
  frame = nil
}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.LootItemsAdd(itemLink, itemQuantity)
  if not private.lootItem.linkMap[itemLink] then
    private.lootItem.linkMap[itemLink] = 0
  end
  while private.lootItem.linkMap[itemLink] < (itemQuantity or 1) do
    if private.lootItem.count >= private.lootItem.MAX_COUNT then
      BPGP.Print(L["Loot list is full (%d). %s will not be added into list."]:format(private.lootItem.MAX_COUNT, itemLink))
      return
    end
    private.lootItem.linkMap[itemLink] = private.lootItem.linkMap[itemLink] + 1
    table.insert(private.lootItem.links, itemLink)
    table.insert(BPGP.db.profile.lootItemLinks, itemLink)
    private.lootItem.count = private.lootItem.count + 1
    private.lootItem.currentPage = math.ceil(private.lootItem.count / private.lootItem.ITEMS_PER_PAGE)
    private.LootControlsUpdate()
    if private.lootItem.count >= private.lootItem.FULL_WARNING_COUNT then
      BPGP.Print(L["Loot list is almost full (%d/%d)."]:format(private.lootItem.count, private.lootItem.MAX_COUNT))
    end
  end
end

function GUI.LootItemsRemove(itemLink)
  for i,v in pairs(private.lootItem.links) do
    if Common:GetItemId(v) == Common:GetItemId(itemLink) then
      private.LootItemsRemoveByIndex(i)
      break
    end
  end
end

function GUI.LootItemsResume()
  if not BPGP.db.profile.lootItemLinks then
    BPGP.db.profile.lootItemLinks = {}
    return
  end
  for i, v in pairs(BPGP.db.profile.lootItemLinks) do
    if not private.lootItem.linkMap[v] then
      private.lootItem.linkMap[v] = 1
    else
      private.lootItem.linkMap[v] = private.lootItem.linkMap[v] + 1
    end
    table.insert(private.lootItem.links, v)
  end
  private.lootItem.count = #private.lootItem.links
end

function GUI.CreateBPGPLootFrame()
	local f = GUI.CreateCustomFrame("BPGPLootFrame", BPGPFrame, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  GUI.RegisterSideframe(f)

  f:Hide()
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -27)

  f:SetHeader(L["Loot Distribution"])
  
  private.lootItem.frame = CreateFrame("Frame", nil, f)
  local itemFrame = private.lootItem.frame
  itemFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -15)
  itemFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -15)
  itemFrame:SetScript("OnShow", function()
    private.LootControlsUpdate()
    if itemFrame.OnShow then itemFrame:OnShow() end
  end)
  if not itemFrame.initiated then
    private.AddLootControls(itemFrame)
    f:SetWidth(itemFrame:GetWidth() + 30)
    f:SetHeight(itemFrame:GetHeight() + 30)
  end
  
  private.frame = f
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.SetLootControlItem(frame, itemLink)
  if not itemLink or itemLink == "" then
    frame:Hide()
    return
  end
  if not Common:GetItemId(itemLink) then
    BPGP.Print("Removed invalid loot list entry ["..tostring(itemLink).."]")
    GUI.LootItemsRemove(itemLink)
    return
  end
  
  frame.itemLink = itemLink
  frame.icon:SetTexture(GetItemIcon(Common:GetItemId(itemLink)))
  frame.name:SetText(itemLink)
  frame:Show()
end

function private.LootControlsUpdate()
  local frame = private.lootItem.frame
  if not frame or not frame.initiated then return end

  local itemsN = private.lootItem.count
  local pageMax = math.max(math.ceil(itemsN / private.lootItem.ITEMS_PER_PAGE), 1)
  if itemsN > 0 then
    frame.clearButton:Enable()
  else
    frame.clearButton:Disable()
  end
  if private.lootItem.currentPage >= pageMax then
    private.lootItem.currentPage = pageMax
    frame.nextPageButton:Disable()
  else
    frame.nextPageButton:Enable()
  end
  if private.lootItem.currentPage == 1 then
    frame.lastPageButton:Disable()
  else
    frame.lastPageButton:Enable()
  end

  local baseN = (private.lootItem.currentPage - 1) * private.lootItem.ITEMS_PER_PAGE

  local showN = math.min(itemsN - baseN, private.lootItem.ITEMS_PER_PAGE)
  for i = 1, showN do
    private.SetLootControlItem(frame.items[i], private.lootItem.links[i + baseN])
  end
  for i = showN + 1, private.lootItem.ITEMS_PER_PAGE do
    private.SetLootControlItem(frame.items[i])
  end
end

function private.LootItemsClear()
  table.wipe(private.lootItem.linkMap)
  table.wipe(private.lootItem.links)
  table.wipe(BPGP.db.profile.lootItemLinks)
  private.lootItem.count = 0
  private.lootItem.currentPage = 1
  private.LootControlsUpdate()
  DistributionTracker.StopDistribution()
end

function private.LootItemsRemoveByIndex(index)
  if not index or index < 1 or index > private.lootItem.count then return end
  private.lootItem.linkMap[private.lootItem.links[index]] = nil
  table.remove(private.lootItem.links, index)
  table.remove(BPGP.db.profile.lootItemLinks, index)
  private.lootItem.count = private.lootItem.count - 1
  private.LootControlsUpdate()
end

function private.AddLootControlItems(frame, topItem, index)
  local f = CreateFrame("Frame", nil, frame)
  f:SetPoint("LEFT")
  f:SetPoint("RIGHT")
  f:SetPoint("TOP", topItem, "BOTTOMLEFT")

  local icon = f:CreateTexture(nil, ARTWORK)
  icon:SetWidth(36)
  icon:SetHeight(36)
  icon:SetPoint("LEFT")
  icon:SetPoint("TOP")

  local iconFrame = CreateFrame("Frame", nil, f)
  iconFrame:ClearAllPoints()
  iconFrame:SetAllPoints(icon)
  iconFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", - 3, iconFrame:GetHeight() + 6)
    GameTooltip:SetHyperlink(f.itemLink)
  end)
  iconFrame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
  iconFrame:EnableMouse(true)

  local itemFrame = CreateFrame("Frame", nil, f)
  itemFrame:SetAllPoints(icon)
  itemFrame:SetPoint("RIGHT", f, "RIGHT", 0, 0)

  local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  name:SetPoint("TOP", 0, -2)
  name:SetPoint("LEFT", icon, "RIGHT", 2, 0)
  name:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  name:SetJustifyV("TOP")
  name:SetJustifyH("LEFT")
  name:SetHeight(22)

  local modeDistributionButton = CreateFrame("Button", "modeDistributionButton", f)
  modeDistributionButton:SetNormalFontObject("GameFontNormalSmall")
  modeDistributionButton:SetHighlightFontObject("GameFontHighlightSmall")
  modeDistributionButton:SetDisabledFontObject("GameFontDisableSmall")
  modeDistributionButton:SetHeight(GUI.GetButtonHeight())
  modeDistributionButton:SetWidth(GUI.GetButtonHeight())
  modeDistributionButton:SetNormalTexture("Interface\\CURSOR\\OPENHAND")
  modeDistributionButton:SetHighlightTexture("Interface\\CURSOR\\openhandglow")
  modeDistributionButton:SetPushedTexture("Interface\\CURSOR\\OPENHAND")
  modeDistributionButton:SetPoint("LEFT", icon, "RIGHT", 5, 0)
  modeDistributionButton:SetPoint("BOTTOM", 0, 0)
  modeDistributionButton:SetScript("OnClick", function()
    GUI.ShowDistributionStartFrame(2, L["Announce Distribution Start:"], f.itemLink, f)
  end)

  local modeSimpleRollButton = CreateFrame("Button", "modeSimpleRollButton", f)
  modeSimpleRollButton:SetNormalFontObject("GameFontNormalSmall")
  modeSimpleRollButton:SetHighlightFontObject("GameFontHighlightSmall")
  modeSimpleRollButton:SetDisabledFontObject("GameFontDisableSmall")
  modeSimpleRollButton:SetHeight(GUI.GetButtonHeight())
  modeSimpleRollButton:SetWidth(GUI.GetButtonHeight())
  modeSimpleRollButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
  modeSimpleRollButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight")
  modeSimpleRollButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
  modeSimpleRollButton:SetPoint("LEFT", modeDistributionButton, "RIGHT", 3, 0)
  modeSimpleRollButton:SetPoint("BOTTOM", 0, -2)
  modeSimpleRollButton:SetScript("OnClick", function()
    GUI.ShowDistributionStartFrame(1, L["Announce Simple Roll Start:"], f.itemLink, f)
  end)

--  local modeBidButton = CreateFrame("Button", "modeBidButton", f)
--  modeBidButton:SetNormalFontObject("GameFontNormalSmall")
--  modeBidButton:SetHighlightFontObject("GameFontHighlightSmall")
--  modeBidButton:SetDisabledFontObject("GameFontDisableSmall")
--  modeBidButton:SetHeight(GUI.GetButtonHeight())
--  modeBidButton:SetWidth(GUI.GetButtonHeight())
--  modeBidButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
--  modeBidButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")
--  modeBidButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Down")
--  modeBidButton:SetPoint("LEFT", modeSimpleRollButton, "RIGHT", 4, 0)
--  modeBidButton:SetPoint("BOTTOM", 0, -3)

  local removeButton = CreateFrame("Button", "removeButton", f)
  removeButton:SetNormalFontObject("GameFontNormalSmall")
  removeButton:SetHighlightFontObject("GameFontHighlightSmall")
  removeButton:SetDisabledFontObject("GameFontDisableSmall")
  removeButton:SetHeight(GUI.GetButtonHeight())
  removeButton:SetWidth(GUI.GetButtonHeight())
  removeButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  removeButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
  removeButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
  removeButton:SetPoint("RIGHT", itemFrame, "RIGHT", 0, -1)
  removeButton:SetPoint("BOTTOM", 0, 0)
  
  local bankButton = CreateFrame("Button", "bankButton", f)
  bankButton:SetNormalFontObject("GameFontNormalSmall")
  bankButton:SetHighlightFontObject("GameFontHighlightSmall")
  bankButton:SetDisabledFontObject("GameFontDisableSmall")
  bankButton:SetHeight(GUI.GetButtonHeight())
  bankButton:SetWidth(GUI.GetButtonHeight())
  bankButton:SetNormalTexture("Interface\\MINIMAP\\Minimap_chest_normal")
  bankButton:SetHighlightTexture("Interface\\MINIMAP\\Minimap_chest_elite")
  bankButton:SetPushedTexture("Interface\\MINIMAP\\Minimap_chest_normal")
  bankButton:SetPoint("RIGHT", removeButton, "LEFT", -1, 0)
  bankButton:SetPoint("BOTTOM", 0, 0)

  f.index = index
  f.icon = icon
  f.iconFrame = iconFrame
  f.name = name
  f.modeDistributionButton = modeDistributionButton
  f.modeSimpleRollButton = modeSimpleRollButton
--  f.modeBidButton = modeBidButton
  f.bankButton = bankButton
  f.removeButton = removeButton

  f:SetHeight(icon:GetHeight())
  f:Hide()

  return f
end

function private.LootItemRemoveButtonOnClick(bt)
  local index = bt:GetParent().index
  private.LootItemsRemoveByIndex(index + (private.lootItem.currentPage - 1) * private.lootItem.ITEMS_PER_PAGE)
end

function private.LootItemBankButtonOnClick(bt)
  local itemLink = bt:GetParent().itemLink
  DataManager.BankItem(itemLink, DataManager.GetSelfName())
  private.LootItemRemoveButtonOnClick(bt)
end

function private.AddLootControls(frame)
  
  local resetButton = CreateFrame("Button", "resetButton", frame, "UIPanelButtonTemplate")
  resetButton:SetNormalFontObject("GameFontNormalSmall")
  resetButton:SetHighlightFontObject("GameFontHighlightSmall")
  resetButton:SetDisabledFontObject("GameFontDisableSmall")
  resetButton:SetHeight(GUI.GetButtonHeight())
  resetButton:SetText(L["Reset Results"])
  resetButton:SetWidth(math.max(resetButton:GetTextWidth() + GUI.GetButtonTextPadding(), 110))
  resetButton:SetPoint("TOPLEFT")
  resetButton:Enable()
  resetButton:SetScript("OnClick", function(self) DistributionTracker.StopDistribution() end)
  
  local addButton = CreateFrame("Button", "addButton", frame, "UIPanelButtonTemplate")
  addButton:SetNormalFontObject("GameFontNormalSmall")
  addButton:SetHighlightFontObject("GameFontHighlightSmall")
  addButton:SetDisabledFontObject("GameFontDisableSmall")
  addButton:SetHeight(GUI.GetButtonHeight())
  addButton:SetText(L["Add New Item"])
  addButton:SetWidth(math.max(addButton:GetTextWidth() + GUI.GetButtonTextPadding(), 110))
  addButton:SetPoint("LEFT", resetButton, "RIGHT")
  addButton:SetScript("OnClick", function(self) GUI.ToggleBPGPAddNewItemFrame() end)

  local announceButton = CreateFrame("Button", "announceButton", frame, "UIPanelButtonTemplate")
  announceButton:SetNormalFontObject("GameFontNormalSmall")
  announceButton:SetHighlightFontObject("GameFontHighlightSmall")
  announceButton:SetDisabledFontObject("GameFontDisableSmall")
  announceButton:SetHeight(GUI.GetButtonHeight())
  announceButton:SetText(L["Announce List"])
  announceButton:SetWidth(math.max(announceButton:GetTextWidth() + GUI.GetButtonTextPadding(), 110))
  announceButton:SetPoint("LEFT")
  announceButton:SetPoint("TOP", resetButton, "BOTTOM", 0, -2)
  announceButton:Enable()
  announceButton:SetScript("OnClick", function(self) MasterLooter:LootItemsAnnounce(private.lootItem.links) end)

  local clearButton = CreateFrame("Button", "clearButton", frame, "UIPanelButtonTemplate")
  clearButton:SetNormalFontObject("GameFontNormalSmall")
  clearButton:SetHighlightFontObject("GameFontHighlightSmall")
  clearButton:SetDisabledFontObject("GameFontDisableSmall")
  clearButton:SetHeight(GUI.GetButtonHeight())
  clearButton:SetText(L["Clear List"])
  clearButton:SetWidth(math.max(clearButton:GetTextWidth() + GUI.GetButtonTextPadding(), 110))
  clearButton:SetPoint("LEFT", announceButton, "RIGHT")
  clearButton:Disable()
  clearButton:SetScript("OnClick", private.LootItemsClear)

  local separator = CreateFrame("Frame", nil, frame)
  separator:SetPoint("LEFT", frame, "LEFT")
  separator:SetPoint("RIGHT", frame, "RIGHT")
  separator:SetPoint("TOP", announceButton, "BOTTOM")
  separator:SetHeight(8)

  frame.items = {}

  local lastPageButton = CreateFrame("Button", "lastPageButton", frame, "UIPanelButtonTemplate")
  lastPageButton:SetNormalFontObject("GameFontNormalSmall")
  lastPageButton:SetHighlightFontObject("GameFontHighlightSmall")
  lastPageButton:SetDisabledFontObject("GameFontDisableSmall")
  lastPageButton:SetHeight(GUI.GetButtonHeight())
  lastPageButton:SetText("<")
  lastPageButton:SetWidth(lastPageButton:GetTextWidth() + GUI.GetButtonTextPadding())
  lastPageButton:SetPoint("BOTTOM", frame, "BOTTOM", -lastPageButton:GetWidth()/2, -5)
  lastPageButton:Disable()
  lastPageButton:SetScript("OnClick", function(self)
    private.lootItem.currentPage = private.lootItem.currentPage - 1
    private.LootControlsUpdate()
  end)

  local nextPageButton = CreateFrame("Button", "nextPageButton", frame, "UIPanelButtonTemplate")
  nextPageButton:SetNormalFontObject("GameFontNormalSmall")
  nextPageButton:SetHighlightFontObject("GameFontHighlightSmall")
  nextPageButton:SetDisabledFontObject("GameFontDisableSmall")
  nextPageButton:SetHeight(GUI.GetButtonHeight())
  nextPageButton:SetText(">")
  nextPageButton:SetWidth(nextPageButton:GetTextWidth() + GUI.GetButtonTextPadding())
  nextPageButton:SetPoint("LEFT", lastPageButton, "RIGHT")
  nextPageButton:Disable()
  nextPageButton:SetScript("OnClick", function(self)
    private.lootItem.currentPage = private.lootItem.currentPage + 1
    private.LootControlsUpdate()
  end)

  for i = 1, private.lootItem.ITEMS_PER_PAGE do
    if i == 1 then
      frame.items[i] = private.AddLootControlItems(frame, separator, i)
    else
      frame.items[i] = private.AddLootControlItems(frame, frame.items[i - 1], i)
    end
    local item = frame.items[i]
    item.bankButton:SetScript("OnClick", private.LootItemBankButtonOnClick)
    item.removeButton:SetScript("OnClick", private.LootItemRemoveButtonOnClick)
  end

  frame.initiated = true
  frame.addButton = addButton
  frame.clearButton = clearButton
  frame.lastPageButton = lastPageButton
  frame.nextPageButton = nextPageButton

  frame:SetWidth(addButton:GetWidth() + resetButton:GetWidth())
  frame:SetHeight(resetButton:GetHeight() + announceButton:GetHeight() + frame.items[1]:GetHeight() * private.lootItem.ITEMS_PER_PAGE + lastPageButton:GetHeight() + 10)

end
