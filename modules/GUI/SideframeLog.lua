local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")

local Common = BPGP.GetLibrary("Common")

local Logger = BPGP.GetModule("Logger")

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPLogFrame()
	local f = GUI.CreateCustomFrame("BPGPLogFrame", BPGPFrame, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  GUI.RegisterSideframe(f)

  f:Hide()
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -27)
  f:SetWidth(550)
  f:SetHeight(465)

  f:SetResizable(true)
  BPGP.compat.SetResizeBounds(f, 550, 465, 700, 465)

  f:SetHeader(L["Personal Action Log"])
  
  ----------------------------------------
  -- Log filter bar
  ----------------------------------------
  
  local filterBarFrame = CreateFrame("Frame", nil, f)
  filterBarFrame:SetHeight(28)
  filterBarFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -9)
  filterBarFrame:SetPoint("RIGHT", f, "RIGHT", -10, 0)

  -- Filter by table name
  local tableFilterLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  tableFilterLabel:SetPoint("LEFT", filterBarFrame, "LEFT", 0, 1)
  tableFilterLabel:SetText(L["Table:"])
  
  local tableFilterDropDown = AceGUI:Create("Dropdown")
  tableFilterDropDown:SetWidth(80)
  tableFilterDropDown.frame:SetParent(filterBarFrame)
  tableFilterDropDown:SetPoint("LEFT", tableFilterLabel, "RIGHT", 0, 1)
  tableFilterDropDown.text:SetJustifyH("RIGHT")
  tableFilterDropDown:SetCallback("OnValueChanged", function(self, event, ...)
    Logger.SetFilterTable(self.list[self:GetValue()])
  end)

  -- Filter by record kind
  local filterCkeckButtonsGroupLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  filterCkeckButtonsGroupLabel:SetPoint("LEFT", tableFilterDropDown.frame, "RIGHT", 10, -1)
  filterCkeckButtonsGroupLabel:SetText(L["Show:"])
  
  -- Filter BP records
  local bpfilterCheckButton = CreateFrame("CheckButton", nil, filterBarFrame, "UICheckButtonTemplate")
  bpfilterCheckButton:SetWidth(20)
  bpfilterCheckButton:SetHeight(20)
  bpfilterCheckButton:SetPoint("LEFT", filterCkeckButtonsGroupLabel, "RIGHT", 5, 0)
  bpfilterCheckButton:SetScript("OnClick", function(self)
    Logger.SetFilterRecordKind(1, not not self:GetChecked())
  end)
  local bpfilterCheckButtonLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  bpfilterCheckButtonLabel:SetPoint("LEFT", bpfilterCheckButton, "RIGHT", 0, 0)
  bpfilterCheckButtonLabel:SetText(L["BP"])
  
  -- Filter GP records
  local gpfilterCheckButton = CreateFrame("CheckButton", nil, filterBarFrame, "UICheckButtonTemplate")
  gpfilterCheckButton:SetWidth(20)
  gpfilterCheckButton:SetHeight(20)
  gpfilterCheckButton:SetPoint("LEFT", bpfilterCheckButtonLabel, "RIGHT", 0, 0)
  gpfilterCheckButton:SetScript("OnClick", function(self)
    Logger.SetFilterRecordKind(2, not not self:GetChecked())
  end)
  local gpfilterCheckButtonLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  gpfilterCheckButtonLabel:SetPoint("LEFT", gpfilterCheckButton, "RIGHT", 0, 0)
  gpfilterCheckButtonLabel:SetText(L["GP"])
  
  -- Filter Free Item records
  local freeItemFilterCheckButton = CreateFrame("CheckButton", nil, filterBarFrame, "UICheckButtonTemplate")
  freeItemFilterCheckButton:SetWidth(20)
  freeItemFilterCheckButton:SetHeight(20)
  freeItemFilterCheckButton:SetPoint("LEFT", gpfilterCheckButtonLabel, "RIGHT", 0, 0)
  freeItemFilterCheckButton:SetScript("OnClick", function(self)
    Logger.SetFilterRecordKind(3, not not self:GetChecked())
  end)
  local freeItemFilterCheckButtonLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  freeItemFilterCheckButtonLabel:SetPoint("LEFT", freeItemFilterCheckButton, "RIGHT", 0, 0)
  freeItemFilterCheckButtonLabel:SetText(L["Free"])
  
  -- Filter Banked Item records
  local bankItemFilterCheckButton = CreateFrame("CheckButton", nil, filterBarFrame, "UICheckButtonTemplate")
  bankItemFilterCheckButton:SetWidth(20)
  bankItemFilterCheckButton:SetHeight(20)
  bankItemFilterCheckButton:SetPoint("LEFT", freeItemFilterCheckButtonLabel, "RIGHT", 0, 0)
  bankItemFilterCheckButton:SetScript("OnClick", function(self)
    Logger.SetFilterRecordKind(4, not not self:GetChecked())
  end)
  local bankItemFilterCheckButtonLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  bankItemFilterCheckButtonLabel:SetPoint("LEFT", bankItemFilterCheckButton, "RIGHT", 0, 0)
  bankItemFilterCheckButtonLabel:SetText(L["Bank"])

  local function UpdateFilterValues()
    -- Update table filter state
    local tableFilterDropDownList = {}
    table.insert(tableFilterDropDownList, L["All"])
    for i, tableName in ipairs(Logger.GetTableNames()) do table.insert(tableFilterDropDownList, tableName) end
    tableFilterDropDown:SetList(tableFilterDropDownList)
    tableFilterDropDown:SetValue(Common:Find(tableFilterDropDownList, Logger.GetFilterTable()) or 1)
    -- Update CheckButtons state
    bpfilterCheckButton:SetChecked(Logger.GetFilterRecordKind(1))
    gpfilterCheckButton:SetChecked(Logger.GetFilterRecordKind(2))
    freeItemFilterCheckButton:SetChecked(Logger.GetFilterRecordKind(3))
    bankItemFilterCheckButton:SetChecked(Logger.GetFilterRecordKind(4))
  end

  -- Filter by search keywords
  local filterSearchLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  filterSearchLabel:SetPoint("LEFT", bankItemFilterCheckButtonLabel, "RIGHT", 10, 0)
  filterSearchLabel:SetText(L["Search:"])

  local searchFilterEditBox = CreateFrame("EditBox", nil, filterBarFrame, "InputBoxTemplate")
  searchFilterEditBox:SetPoint("LEFT", filterSearchLabel, "RIGHT", 10, 1)
  searchFilterEditBox:SetFontObject("GameFontHighlightSmall")
  searchFilterEditBox:SetHeight(24)
  searchFilterEditBox:SetAutoFocus(false)
  searchFilterEditBox:SetScript("OnTextChanged", function(self)
    Logger.SetSearchKeywords(self:GetText())
  end)
  searchFilterEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  hooksecurefunc("ChatEdit_InsertLink", function(itemLink)
    if searchFilterEditBox:IsVisible() and searchFilterEditBox:HasFocus() then
      local insertedItemId = Common:GetItemId(searchFilterEditBox:GetText())
      if Common:GetItemId(searchFilterEditBox:GetText()) then
        if Common:GetItemId(itemLink) == insertedItemId then return end
        searchFilterEditBox:SetText(itemLink)
      else 
        searchFilterEditBox:Insert(itemLink)
      end
    end
  end)
  
  -- Reset all filters to default
  local resetAllFiltersButton = CreateFrame("Button", nil, filterBarFrame)
  resetAllFiltersButton:SetNormalTexture("Interface\\Buttons\\CancelButton-Up")
  resetAllFiltersButton:SetPushedTexture("Interface\\Buttons\\CancelButton-Down")
  resetAllFiltersButton:SetHighlightTexture("Interface\\Buttons\\CancelButton-Highlight")
  resetAllFiltersButton:SetHeight(40)
  resetAllFiltersButton:SetWidth(40)
  resetAllFiltersButton:SetHitRectInsets(8, 8, 8, 8)
  resetAllFiltersButton:SetPoint("RIGHT", filterBarFrame, "RIGHT", 0, 0)
  resetAllFiltersButton:SetScript("OnClick", function(self)
    searchFilterEditBox:SetText("")
    searchFilterEditBox:ClearFocus() 
    Logger.ResetFilters()
  end)

  searchFilterEditBox:SetPoint("RIGHT", resetAllFiltersButton, "LEFT", 8, 0)

  ----------------------------------------
  -- Log frame records container
  ----------------------------------------
  
  local scrollParent = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")
  scrollParent:SetPoint("TOP", f, "TOP", 0, -36)
  scrollParent:SetPoint("LEFT", f, "LEFT", 16, 0)
  scrollParent:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  scrollParent:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left=5, right=5, top=5, bottom=5 }
  })
  scrollParent:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
  scrollParent:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)

  local font = "ChatFontSmall"
  local fontHeight = select(2, getglobal(font):GetFont())
  local recordHeight = fontHeight + 2
  local recordWidth = scrollParent:GetWidth() - 35
  local numLogRecordFrames = math.floor((scrollParent:GetHeight() - 3) / recordHeight)
  
  for i = 1, numLogRecordFrames do
    local record = scrollParent:CreateFontString("BPGPLogRecordFrame"..i, "OVERLAY", font)
    record:SetHeight(recordHeight)
    record:SetWidth(recordWidth)
    record:SetNonSpaceWrap(false)
    if i == 1 then
      record:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 5, -3)
    else
      record:SetPoint("TOPLEFT", "BPGPLogRecordFrame"..(i-1), "BOTTOMLEFT")
    end
    local tooltipFrame = CreateFrame("Frame", nil, f)
    tooltipFrame:ClearAllPoints()
    tooltipFrame:SetHeight(recordHeight)
    tooltipFrame:SetPoint("LEFT", record, "LEFT")
    tooltipFrame:SetPoint("RIGHT", record, "RIGHT")
    tooltipFrame:SetScript("OnEnter", function(self)
      local link = record:GetText():match("(|Hitem:%d+:.+|h|r)")
      if link then
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 0)
        GameTooltip:SetHyperlink(link)
      end
    end)
    tooltipFrame:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
  end

  local scrollBar = CreateFrame("ScrollFrame", "BPGPLogRecordScrollFrame", scrollParent, "FauxScrollFrameTemplateLight")
  scrollBar:SetWidth(scrollParent:GetWidth() - 35)
  scrollBar:SetHeight(scrollParent:GetHeight() - 10)
  scrollBar:SetPoint("TOPRIGHT", scrollParent, "TOPRIGHT", -28, -6)

  ----------------------------------------
  -- Log Export/Import buttons
  ----------------------------------------

  local exportLogButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  exportLogButton:SetNormalFontObject("GameFontNormalSmall")
  exportLogButton:SetHighlightFontObject("GameFontHighlightSmall")
  exportLogButton:SetDisabledFontObject("GameFontDisableSmall")
  exportLogButton:SetHeight(GUI.GetButtonHeight())
  exportLogButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 17, 13)
  exportLogButton:SetText(L["Export"])
  exportLogButton:SetWidth(exportLogButton:GetTextWidth() + GUI.GetButtonTextPadding())
  exportLogButton:SetScript("OnClick", function(self, button, down) BPGPDataExportFrame:Show() end)

  local importLogButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  importLogButton:SetNormalFontObject("GameFontNormalSmall")
  importLogButton:SetHighlightFontObject("GameFontHighlightSmall")
  importLogButton:SetDisabledFontObject("GameFontDisableSmall")
  importLogButton:SetHeight(GUI.GetButtonHeight())
  importLogButton:SetPoint("LEFT", exportLogButton, "RIGHT")
  importLogButton:SetText(L["Import"])
  importLogButton:SetWidth(importLogButton:GetTextWidth() + GUI.GetButtonTextPadding())
  importLogButton:SetScript("OnClick", function(self, button, down) BPGPDataImportFrame:Show() end)


  -- Filter by search keywords
  local foundRecordsLabel = filterBarFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  foundRecordsLabel:SetPoint("BOTTOM", f, "BOTTOM", 0, 17)

  ----------------------------------------
  -- Log Undo/Redo actions buttons
  ----------------------------------------

  local undo = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  undo:SetNormalFontObject("GameFontNormalSmall")
  undo:SetHighlightFontObject("GameFontHighlightSmall")
  undo:SetDisabledFontObject("GameFontDisableSmall")
  undo:SetHeight(GUI.GetButtonHeight())
  undo:SetText(L["Undo"])
  undo:SetWidth(undo:GetTextWidth() + GUI.GetButtonTextPadding())
  undo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 13)
  undo:SetScript("OnClick", function (self, value) Logger.UndoLastAction() end)

  local redo = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  redo:SetNormalFontObject("GameFontNormalSmall")
  redo:SetHighlightFontObject("GameFontHighlightSmall")
  redo:SetDisabledFontObject("GameFontDisableSmall")
  redo:SetHeight(GUI.GetButtonHeight())
  redo:SetText(L["Redo"])
  redo:SetWidth(redo:GetTextWidth() + GUI.GetButtonTextPadding())
  redo:SetPoint("RIGHT", undo, "LEFT")
  redo:SetScript("OnClick", function (self, value) Logger.RedoLastUndo() end)
  
  scrollParent:SetPoint("BOTTOM", redo, "TOP", 0, 0)

  ----------------------------------------
  -- Log frame Resize button
  ----------------------------------------
  
  local sizer = CreateFrame("Button", nil, f)
  sizer:SetHeight(16)
  sizer:SetWidth(16)
  sizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  sizer:SetScript("OnMouseDown", function (self) self:GetParent():StartSizing("BOTTOMRIGHT") end)
  sizer:SetScript("OnMouseUp", function (self)
    local f = self:GetParent()
    -- Log frame will be attached to UIParent by StopMovingOrSizing
    f:StopMovingOrSizing()
    -- Here we attach log frame back to BPGP frame at correct position
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -27)
  end)

  local line1 = sizer:CreateTexture(nil, "BACKGROUND")
  line1:SetWidth(14)
  line1:SetHeight(14)
  line1:SetPoint("BOTTOMRIGHT", -4, 4)
  line1:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local x = 0.1 * 14/17
  line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

  local line2 = sizer:CreateTexture(nil, "BACKGROUND")
  line2:SetWidth(8)
  line2:SetHeight(8)
  line2:SetPoint("BOTTOMRIGHT", -4, 4)
  line2:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local x = 0.1 * 8/17
  line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

  ----------------------------------------
  -- Log frame data update functions
  ----------------------------------------

  local function UpdateLogFrame()
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    local numRecords = Logger.GetNumRecords()
    local numDisplayedRecords = math.min(numLogRecordFrames, numRecords - offset)
    if offset > 0 and numDisplayedRecords < numLogRecordFrames then
      numDisplayedRecords = math.min(numLogRecordFrames, numRecords)
      offset = 0
    end
    local recordWidth = scrollParent:GetWidth() - 35
    for i = 1, numLogRecordFrames do
      local record = getglobal("BPGPLogRecordFrame"..i)
      record:SetWidth(recordWidth)
      local logIndex = i + offset - 1
      if logIndex < numRecords then
        local recordData = Logger.GetLogRecord(logIndex)
        if recordData.stale then
          record:SetText("|cFF808080"..recordData.plainText.."|r")
        else
          record:SetText(recordData.plainText)
        end
        record:SetJustifyH("LEFT")
        record:Show()
      else
        record:Hide()
      end
    end
    FauxScrollFrame_Update(scrollBar, numRecords, numDisplayedRecords, recordHeight)
    foundRecordsLabel:SetText(L["Found %d records"]:format(numRecords))
  end
  
  local function AutoUpdateLogFrame()
    if not Logger.UpdateModel() then return end
    UpdateFilterValues()
    UpdateLogFrame()
  end

  BPGPLogFrame:SetScript("OnUpdate", AutoUpdateLogFrame)
  BPGPLogFrame:SetScript("OnSizeChanged", UpdateLogFrame)
  scrollBar:SetScript("OnVerticalScroll", function(self, value)
    FauxScrollFrame_OnVerticalScroll(scrollBar, value, recordHeight, UpdateLogFrame)
  end)
end
