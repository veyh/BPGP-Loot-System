local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")
local AceGUI = LibStub("AceGUI-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local StandbyTracker = BPGP.GetModule("StandbyTracker")
local StandingsManager = BPGP.GetModule("StandingsManager")
local RollTracker = BPGP.GetModule("RollTracker")
local DistributionTracker = BPGP.GetModule("DistributionTracker")

local math, pairs, ipairs, next = math, pairs, ipairs, next
local GameTooltip, GameTooltip_SetDefaultAnchor = GameTooltip, GameTooltip_SetDefaultAnchor
local FauxScrollFrame_GetOffset, FauxScrollFrame_Update = FauxScrollFrame_GetOffset, FauxScrollFrame_Update
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local IsShiftKeyDown, GetItemIcon, CLASS_ICON_TCOORDS = IsShiftKeyDown, GetItemIcon, CLASS_ICON_TCOORDS

local private = {}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPFrameStandings()
  local f = CreateFrame("Frame", nil, BPGPFrame)
  f:SetHeight(28)
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPLEFT", 10, -2)
  f:SetPoint("RIGHT", BPGPFrame, "RIGHT", -10, -2)
  
  local separator = f:CreateTexture(nil, "BACKGROUND")
  separator:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  separator:SetHeight(42)
  separator:SetPoint("LEFT", f, "LEFT", 0, -6)
  separator:SetPoint("RIGHT", f, "RIGHT", 0, -6)
  separator:SetTexCoord(0.09375, 0.90625, 0, 1)
  
  local alertFrame = CreateFrame("Frame", nil, f)
  alertFrame:SetPoint("LEFT", f, 6, -3)
  alertFrame:SetHeight(24)
  
  local alertButton = CreateFrame("Button", nil, f)
  alertButton:SetNormalTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  alertButton:SetHighlightTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  alertButton:GetHighlightTexture():SetVertexColor(1, 0, 0, 1)
  alertButton:SetHeight(24)
  alertButton:SetWidth(24)
  alertButton:SetPoint("LEFT", alertFrame, 0, 0)
  alertButton:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:AddLine(L["Alerts"].."\n")
    local alerts = DataManager.GetAlerts()
    if alerts["BPGP"] then
      for i, alert in ipairs(alerts["BPGP"]) do
        GameTooltip:AddLine("BPGP: ".."|cFFFFFFFF"..alert.."|r")
      end
    end
    for target, targetAlerts in pairs(alerts) do
      if target ~= "BPGP" then
        for i, alert in ipairs(targetAlerts) do
          GameTooltip:AddLine(target..": ".."|cFFFFFFFF"..alert.."|r")
        end
      end
    end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT")
    GameTooltip:Show()
  end)
  alertButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function alertFrame:Update()
    local alerts = DataManager.GetAlerts()
    if next(alerts) then
      alertButton:Show()
      alertFrame:SetWidth(28)
    else
      alertButton:Hide()
      alertFrame:SetWidth(1)
    end
  end
  alertButton:SetScript("OnClick", function(self)
    f.filterModeDropDown:SetValue(9)
    StandingsManager.SetFilter(9)
  end)
  
  local tableIdLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  tableIdLabel:SetPoint("LEFT", alertFrame, "RIGHT", 0, 0)
  tableIdLabel:SetText(L["Table:"])
  
  local lockButton = CreateFrame("Button", nil, f)
  
  local tableIdDropDown = AceGUI:Create("Dropdown")
  tableIdDropDown:SetWidth(90)
  tableIdDropDown.frame:SetParent(f)
  tableIdDropDown:SetPoint("LEFT", tableIdLabel, "RIGHT", 0, 1)
  tableIdDropDown.text:SetJustifyH("RIGHT")
  tableIdDropDown:SetCallback("OnValueChanged", function(self, event, ...)
    StandingsManager.SetTableId(self:GetValue())
    lockButton:Update()
  end)
  function tableIdDropDown:Update()
    tableIdDropDown.pullout:Close()
    local tableIdDropDownList = {}
    for i = 1, DataManager.GetNumTables() do
      table.insert(tableIdDropDownList, DataManager.GetTableName(i))
    end
    tableIdDropDown:SetList(tableIdDropDownList)
    tableIdDropDown:SetValue(StandingsManager.GetTableId())
    tableIdDropDown:SetText(tableIdDropDownList[tableIdDropDown:GetValue()])
  end
  BPGP.RegisterCallback("SettingsUpdated", tableIdDropDown.Update)

  lockButton:SetNormalTexture("Interface\\PetBattles\\PetBattle-LockIcon")
  lockButton:GetNormalTexture():SetVertexColor(1, 0, 0, 0.8)
  lockButton:SetHighlightTexture("Interface\\PetBattles\\PetBattle-LockIcon")
  lockButton:GetHighlightTexture():SetVertexColor(0, 1, 0, 1)
  lockButton:SetDisabledTexture("Interface\\PetBattles\\PetBattle-LockIcon")
  lockButton:GetDisabledTexture():SetVertexColor(0.25, 0.25, 0, 1)
  lockButton:SetHeight(24)
  lockButton:SetWidth(24)
  lockButton:SetPoint("LEFT", tableIdDropDown.frame, "RIGHT", 2, 0)
  lockButton:SetScript("OnClick", function(self)
    if DataManager.SelfSA() and DataManager.GetLockState() == tableIdDropDown:GetValue() then
      DataManager.HardLock()
    else
      DataManager.SoftLock()
    end
    lockButton:GetScript("OnLeave")()
  end)
  lockButton:SetScript("OnUpdate", function(self)
    if DataManager.GetLockState() == 0 then
      if DataManager.SelfSA() or DataManager.SelfGM() then
        self:Enable()
      else
        self:Disable()
      end
    else
      if not DataManager.IsWriteLocked() then
        self:Enable()
      else
        self:Disable()
      end
    end 
  end)
  function lockButton:Update()
    if DataManager.SelfSA() and DataManager.GetLockState() == tableIdDropDown:GetValue() then
      self:GetNormalTexture():SetVertexColor(0, 1, 0, 1)
    else
      self:GetNormalTexture():SetVertexColor(1, 0, 0, 0.9)
    end
  end
  lockButton:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:AddLine(L["System Lock Control"].."\n")
    if DataManager.SelfSA() and DataManager.GetLockState() == tableIdDropDown:GetValue() then
      GameTooltip:AddLine(L["System is currently in |cFF00FF00Soft Locked|r state:"], 1, 1, 1)
      GameTooltip:AddLine(L["• You can edit selected table."], 1, 1, 1)
      GameTooltip:AddLine(L["• System can be Soft Locked only to one member at any given time."], 1, 1, 1)
      GameTooltip:AddLine(L["• While system is in Soft Lock state any member with Officer Notes writing access can Soft Lock it to himself."], 1, 1, 1, 1)
      GameTooltip:AddLine("\n")
      GameTooltip:AddLine(L["Click to Hard Lock the system:"], 1, 1, 1)
      GameTooltip:AddLine(L["• Nobody will be able to edit any table."], 1, 1, 1)
      if DataManager.SelfGM() then
        GameTooltip:AddLine(L["• Guild Master's Hard Lock cannot be lifted by anybody else."], 1, 1, 1)
      else
        GameTooltip:AddLine(L["• Only you and Guild Master will be able to lift your Hard Lock."], 1, 1, 1)
      end
    else
      GameTooltip:AddLine(L["System is currently in |cFFFF0000Hard Locked|r state:"], 1, 1, 1)
      GameTooltip:AddLine(L["• Nobody is able to edit any table."], 1, 1, 1)
      if DataManager.SelfGM() then
        GameTooltip:AddLine(L["• Only you can Soft Lock the system at the moment."], 1, 1, 1)
      else
        GameTooltip:AddLine(L["• Only you and Guild Master can Soft Lock the system at the moment."], 1, 1, 1)
      end
      GameTooltip:AddLine("\n")
      GameTooltip:AddLine(L["Click to Soft Lock the system to you."], 1, 1, 1)
      GameTooltip:AddLine(L["• You will be able to edit selected table."], 1, 1, 1)
      GameTooltip:AddLine(L["• System can be Soft Locked only to one member at any given time."], 1, 1, 1)
      GameTooltip:AddLine(L["• While system is in Soft Lock state any member with Officer Notes writing access can Soft Lock it to himself."], 1, 1, 1, 1)
    end
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
    GameTooltip:Show()
  end)
  lockButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  local lootFilterFrame = CreateFrame("Frame", nil, f)
  
  local lootFilterLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  lootFilterLabel:SetPoint("LEFT", lockButton, "RIGHT", 7, -1)
  lootFilterLabel:SetText(L["Loot Filter:"])

  lootFilterFrame.roleButtons = {}
  for i = 1, 4 do
    local roleButton = CreateFrame("Button", nil, f)
    roleButton:SetWidth(12)
    roleButton:SetHeight(12)
    if i == 1 then
      roleButton:SetPoint("LEFT", lootFilterLabel, "RIGHT", 3, 0)
    else
      roleButton:SetPoint("LEFT", lootFilterFrame.roleButtons[i-1], "RIGHT", 3, 0)
    end
    roleButton:Hide()
    roleButton:SetScript("OnClick", function (self)
      if not GUI.db.profile.lootFilterLocked then
        DistributionTracker.SetWhitelistedRole(self.role, self:GetNormalTexture():IsDesaturated())
      else
        BPGP.Print(L["Loot Filter is locked!"])
      end
      roleButton:GetScript("OnLeave")()
      roleButton:GetScript("OnEnter")(roleButton)
    end)
    roleButton:SetScript("OnEnter", function(self)
      GameTooltip_SetDefaultAnchor(GameTooltip, self)
      GameTooltip:AddLine(self.role)
      if not DistributionTracker.IsWhitelistedRole(self.role) then
        GameTooltip:AddLine(L["Role is |cFFFF0000Disabled|r. Click to enable."], 1, 1, 1)
      end
      GameTooltip:AddLine(L["• Toggling this role will affect item stats based auto-passing."], 1, 1, 1)
      GameTooltip:AddLine(L["• Disabling all roles will auto-pass everything except mounts, recipes and bags."], 1, 1, 1)
      GameTooltip:AddLine(L["• You can view current rules by hovering over Loot Filter label."], 1, 1, 1)
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
      GameTooltip:Show()
    end)
    roleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lootFilterFrame.roleButtons[i] = roleButton
  end
  
  local lootFilterLockButton = CreateFrame("Button", nil, f)
  
  function lootFilterFrame.Update()
    local roleIcons = DistributionTracker.GetRoleIcons(DataManager.GetSelfClass())
    for role, iconData in pairs(roleIcons) do
      local roleButton = lootFilterFrame.roleButtons[iconData[1]]
      roleButton.role = role
      roleButton:SetNormalTexture(iconData[2])
      roleButton:SetHighlightTexture(iconData[2])
      roleButton:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.8)
      if DistributionTracker.IsWhitelistedRole(role) then
        roleButton:GetNormalTexture():SetDesaturated(false)
        roleButton:SetAlpha(1)
      else
        roleButton:GetNormalTexture():SetDesaturated(true)
        roleButton:SetAlpha(0.5)
      end
      roleButton:Show()
    end
    lootFilterFrame.numAvailableRoles = Common:KeysCount(roleIcons)
    lootFilterLockButton:SetPoint("LEFT", lootFilterFrame.roleButtons[lootFilterFrame.numAvailableRoles], "RIGHT", 0, 0)
  end
  BPGP.RegisterCallback("AutoPassModeUpdate", lootFilterFrame.Update)
  lootFilterFrame.Update()
  
  lootFilterLockButton:SetNormalTexture("Interface\\PetBattles\\PetBattle-LockIcon")
  lootFilterLockButton:SetHighlightTexture("Interface\\PetBattles\\PetBattle-LockIcon")
  lootFilterLockButton:SetWidth(16)
  lootFilterLockButton:SetHeight(16)
  function lootFilterLockButton.Update()
    if GUI.db.profile.lootFilterLocked then
      lootFilterLockButton:GetNormalTexture():SetDesaturated(false)
      lootFilterLockButton:SetAlpha(1)
      lootFilterFrame:SetPoint("RIGHT", lootFilterFrame.roleButtons[lootFilterFrame.numAvailableRoles], "RIGHT")
    else
      lootFilterLockButton:GetNormalTexture():SetDesaturated(true)
      lootFilterLockButton:SetAlpha(0.5)
      lootFilterFrame:SetPoint("RIGHT", lootFilterLabel, "RIGHT")
    end
  end
  lootFilterLockButton:SetScript("OnClick", function (self)
    GUI.db.profile.lootFilterLocked = not GUI.db.profile.lootFilterLocked
    lootFilterLockButton.Update()
  end)
  lootFilterLockButton.Update()
  lootFilterLockButton:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:AddLine(L["Loot Filter Lock"])
    GameTooltip:AddLine(L["Protects role buttons from accidental clicking."], 1, 1, 1)
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
    GameTooltip:Show()
  end)
  lootFilterLockButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  lootFilterFrame:SetPoint("LEFT", lootFilterLabel, "LEFT")
  lootFilterFrame:SetWidth(lootFilterLabel:GetWidth())
  lootFilterFrame:SetHeight(28)
  lootFilterFrame:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:AddLine(L["Loot Popup Filter"].."\n\n")
    if GUI.db.profile.lootFilterLocked then
      GameTooltip:AddLine(L["Panel is |cFFFF0000Locked|r. Press yellow lock button to unlock."].."\n\n", 1, 1, 1)
    end
    GameTooltip:AddLine(L["Controls item filtering during loot distribution:"], 1, 1, 1)
    GameTooltip:AddLine(L["• Popups with items for selected (colored) roles will be displayed."], 1, 1, 1)
    GameTooltip:AddLine(L["• Items for disabled (greyed out) roles will be auto-passed."], 1, 1, 1)
    GameTooltip:AddLine("\n")
    GameTooltip:AddLine(L["Items with following properties will be auto-passed:"], 1, 1, 1)
    if DistributionTracker.IsSoftPassEnabled() then
      GameTooltip:AddLine(L["• All equippable items except bags."], 1, 1, 1)
      GameTooltip:AddLine(L["• Class-limited non-equippable items (i.e. tokens)."], 1, 1, 1)
      GameTooltip:AddLine(L["• Mounts, recipes and bags will NOT be auto-passed!"], 0, 1, 0)
    else
      GameTooltip:AddLine(L["• Duplicates of unique or single-slot items that are already equipped or stored."], 1, 1, 1)
      GameTooltip:AddLine(L["• Items that can't be used by your class."], 1, 1, 1)
      local blacklistedStats = table.concat(DistributionTracker.GetBlacklistedStatsList(), ", ")
      if blacklistedStats ~= "" then
        GameTooltip:AddLine(L["• Items with following stats: %s."]:format(blacklistedStats), 1, 1, 1, 1)
      end
    end
    
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
    GameTooltip:Show()
  end)
  lootFilterFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local filterLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  filterLabel:SetText(L["Filter:"])
  
  local filterModeDropDown = AceGUI:Create("Dropdown")
  filterModeDropDown:SetWidth(90)
  filterModeDropDown.frame:SetParent(f)
  filterModeDropDown:SetPoint("RIGHT", f, "RIGHT", 0, -2)
  filterModeDropDown.text:SetJustifyH("RIGHT")
  local filterModeDropDownList = {}
  for k, v in pairs(StandingsManager.GetFilterModes()) do
    table.insert(filterModeDropDownList, v)
  end
  filterModeDropDown:SetList(filterModeDropDownList)
  filterModeDropDown:SetValue(StandingsManager.GetFilterMode())
  filterModeDropDown:SetText(filterModeDropDownList[filterModeDropDown:GetValue()])
  filterModeDropDown:SetCallback("OnValueChanged", function(self, event, ...)
    StandingsManager.SetFilter(self:GetValue())
  end)
  f.filterModeDropDown = filterModeDropDown
  
  filterLabel:SetPoint("RIGHT", filterModeDropDown.frame, "LEFT", 0, -1)
  
  f:Show()
  
  -- Make the options frame
  GUI.CreateBPGPOptionsFrame()

  -- Make the stats frame
  GUI.CreateBPGPStatsFrame()
  
  -- Make the stats frame
  GUI.CreateBPGPToolsFrame()
  
  -- Make the log frame
  GUI.CreateBPGPLogFrame()

  -- Make the side frame
  GUI.CreateBPGPSideFrame()

  -- Make the second side frame
  GUI.CreateBPGPSideFrame2()

  -- Make the loot frame
  GUI.CreateBPGPLootFrame()

	-- Make the roll announcement frame
	GUI.CreateBPGPDistributionStartFrame()
  
  -- Make item adding to loot distribution list frame
	GUI.CreateBPGPAddNewItemFrame()
  
  -- Make Loot Popup comments preset import frame
	GUI.CreateBPGPLootPopupCommentsImportFrame()
  
  -- Make Wishlist items import frame
	GUI.CreateBPGPWishlistImportFrame()
  
  -- Make Ongoing Distribution status frame
  GUI.CreateBPGPOngoingDistributionFrame()

  -- Make the main frame
  local main = CreateFrame("Frame", nil, BPGPFrame)
  main:SetWidth(468)
  main:SetHeight(480)
  main:SetPoint("TOPLEFT", BPGPFrame, 6, -36)
  
  local options = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  options:SetNormalFontObject("GameFontNormalSmall")
  options:SetHighlightFontObject("GameFontHighlightSmall")
  options:SetDisabledFontObject("GameFontDisableSmall")
  options:SetHeight(GUI.GetButtonHeight())
  options:SetText(L["Options"])
  options:SetWidth(math.max(options:GetTextWidth() + GUI.GetButtonTextPadding(), 70))
  options:SetPoint("BOTTOMLEFT", 2, 0)
  options:SetScript("OnClick", function(self)
    GUI.ToggleSideFrame(BPGPOptionsFrame)
  end)
  
  local stats = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  stats:SetNormalFontObject("GameFontNormalSmall")
  stats:SetHighlightFontObject("GameFontHighlightSmall")
  stats:SetDisabledFontObject("GameFontDisableSmall")
  stats:SetHeight(GUI.GetButtonHeight())
  stats:SetPoint("LEFT", options, "RIGHT")
  stats:SetText(L["Stats"])
  stats:SetWidth(math.max(stats:GetTextWidth() + GUI.GetButtonTextPadding(), 70))
  stats:SetScript("OnClick", function() GUI.ToggleSideFrame(BPGPStatsFrame) end)

  local log = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  log:SetNormalFontObject("GameFontNormalSmall")
  log:SetHighlightFontObject("GameFontHighlightSmall")
  log:SetDisabledFontObject("GameFontDisableSmall")
  log:SetHeight(GUI.GetButtonHeight())
  log:SetPoint("LEFT", stats, "RIGHT")
  log:SetText(L["Log"])
  log:SetWidth(math.max(log:GetTextWidth() + GUI.GetButtonTextPadding(), 70))
  log:SetScript("OnClick", function(self, button, down) GUI.ToggleSideFrame(BPGPLogFrame) end)

  local loot = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  loot:SetNormalFontObject("GameFontNormalSmall")
  loot:SetHighlightFontObject("GameFontHighlightSmall")
  loot:SetDisabledFontObject("GameFontDisableSmall")
  loot:SetHeight(GUI.GetButtonHeight())
  loot:SetPoint("BOTTOMRIGHT", -2, 0)
  loot:SetText(L["Loot Distribution"])
  loot:SetWidth(math.max(loot:GetTextWidth() + GUI.GetButtonTextPadding(), 120))
  loot:SetScript("OnClick", function() GUI.ToggleSideFrame(BPGPLootFrame) end)

  local tools = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  tools:SetNormalFontObject("GameFontNormalSmall")
  tools:SetHighlightFontObject("GameFontHighlightSmall")
  tools:SetDisabledFontObject("GameFontDisableSmall")
  tools:SetHeight(GUI.GetButtonHeight())
  tools:SetPoint("RIGHT", loot, "LEFT")
  tools:SetText(L["Tools"])
  tools:SetWidth(math.max(tools:GetTextWidth() + GUI.GetButtonTextPadding(), 70))
  tools:SetScript("OnClick", function() GUI.ToggleSideFrame(BPGPToolsFrame) end)

  local fontHeight = select(2, GameFontNormal:GetFont())

  -- Make the status text
  local statusText = main:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  statusText:SetHeight(fontHeight)
  statusText:SetJustifyH("CENTER")
  statusText:SetPoint("BOTTOMLEFT", options, "TOPLEFT", 0, 1)
  statusText:SetPoint("BOTTOMRIGHT", loot, "TOPRIGHT", 0, 1)
  function statusText:Update()
    if DataManager.GetLockState() == 0 then
      self:SetText(L["BPGP is %s by %s"]:format("|cFFFF0000"..L["Locked"].."|r", DataManager.GetSysAdminName()))
    else
      self:SetText(L["Table %s is %s for %s"]:format(DataManager.GetUnlockedTableName(), "|cFF00FF00"..L["Unlocked"].."|r", DataManager.GetSysAdminName()))
    end
  end
  
  -- Make the table frame
  local tabl = CreateFrame("Frame", nil, main)
  tabl:SetPoint("TOPLEFT")
  tabl:SetPoint("TOPRIGHT")
  tabl:SetPoint("BOTTOM", statusText, "TOP")
  -- Also hook the status texts to update on show
  tabl:SetScript("OnShow", function (self) statusText:Update() end)

  -- Populate the table
  private.CreateTable(tabl,
    {" ", "Name", "BP", "GP", "Index", "Distribution", "Roll"},
    {22, 0, 60, 60, 60, 94, 42},
    {"LEFT", "LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT", "RIGHT"},
    27)  -- The scrollBarWidth

  -- Make the scrollbar
  local rowFrame = tabl.rowFrame
  rowFrame.needUpdate = true
  local scrollBar = CreateFrame("ScrollFrame", "BPGPScrollFrame", rowFrame, "FauxScrollFrameTemplateLight")
  scrollBar:SetWidth(rowFrame:GetWidth())
  scrollBar:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", 0, -2)
  scrollBar:SetPoint("BOTTOMRIGHT")

  -- Make all our rows have a check on them and setup the OnClick handler for each row.
  for i, r in ipairs(rowFrame.rows) do
    r.class = r:CreateTexture(nil, "BACKGROUND")
    r.class:SetWidth(r:GetHeight())
    r.class:SetHeight(r:GetHeight())
    r.class:SetPoint("LEFT", r.cells[1])
    
    r.icon1 = r:CreateTexture(nil, "BACKGROUND")
    r.icon1:SetWidth(r:GetHeight())
    r.icon1:SetHeight(r:GetHeight())
    r.icon1:SetPoint("RIGHT", r.cells[2])
    
    r.icon2 = r:CreateTexture(nil, "BACKGROUND")
    r.icon2:SetWidth(r:GetHeight())
    r.icon2:SetHeight(r:GetHeight())
    r.icon2:SetPoint("RIGHT", r.icon1, "LEFT")
    
    r.itemIcon1 = r:CreateTexture(nil, "BACKGROUND")
    r.itemIcon1:SetWidth(r:GetHeight())
    r.itemIcon1:SetHeight(r:GetHeight())
    r.itemIcon1:SetPoint("LEFT", r.cells[6])
  
    local itemIcon1Frame = CreateFrame("Frame", nil, r)
    itemIcon1Frame:ClearAllPoints()
    itemIcon1Frame:SetAllPoints(r.itemIcon1)
    itemIcon1Frame:SetScript("OnEnter", function(self)
      local itemLink = self:GetParent().itemLink1 or ""
      if not Common:GetItemId(itemLink) then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", - 3, itemIcon1Frame:GetHeight() + 6)
      GameTooltip:SetHyperlink(itemLink)
    end)
    itemIcon1Frame:SetScript("OnLeave", function(self)
      GameTooltip:FadeOut()
    end)
    
    r.itemIcon2 = r:CreateTexture(nil, "BACKGROUND")
    r.itemIcon2:SetWidth(r:GetHeight())
    r.itemIcon2:SetHeight(r:GetHeight())
    r.itemIcon2:SetPoint("LEFT", r.itemIcon1, "RIGHT")
  
    local itemIcon2Frame = CreateFrame("Frame", nil, r)
    itemIcon2Frame:ClearAllPoints()
    itemIcon2Frame:SetAllPoints(r.itemIcon2)
    itemIcon2Frame:SetScript("OnEnter", function(self)
      local itemLink = self:GetParent().itemLink2 or ""
      if not Common:GetItemId(itemLink) then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", - 3, itemIcon2Frame:GetHeight() + 6)
      GameTooltip:SetHyperlink(itemLink)
    end)
    itemIcon2Frame:SetScript("OnLeave", function(self)
      GameTooltip:FadeOut()
    end)

    r:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    r:SetScript("OnClick", function(self, value)
      if IsShiftKeyDown() then -- SHIFT + Click
       -- status1: 0 = none, 1 = in raid, 2 = standby enlisted
       -- status2: 0 = none, 1 = alert, 2 = requested standby
        local status1, status2 = StandingsManager.GetMemberStatus(self.name)
        if value == "LeftButton" then
          if status2 == 2 then
            StandbyTracker.AcceptRequest(self.name)
          elseif status1 == 0 then
            StandbyTracker.Enlist(self.name)
          end
        elseif value == "RightButton" then
          if status2 == 2 then
            StandbyTracker.DeclineRequest(self.name)
          elseif status1 == 2 then
            StandbyTracker.Delist(self.name)
          end
        end
      else
        if BPGPSideFrame.name ~= self.name then
          self:LockHighlight()
          BPGPSideFrame:Hide()
          BPGPSideFrame.name = self.name
        end
        GUI.ToggleSideFrame(BPGPSideFrame)
      end
    end)

    r:SetScript("OnEnter", function(self)
      GameTooltip_SetDefaultAnchor(GameTooltip, self)
      GameTooltip:AddLine(self.name.."\n")
      local alerts = DataManager.GetAlerts(self.name)
      if alerts then
        for i, alert in ipairs(alerts) do
          GameTooltip:AddLine(L["Alert"]..": ".."|cFFFFFFFF"..alert.."|r")
        end
        GameTooltip:AddLine("")
      end
      GameTooltip:AddLine(L["Rank"]..": ".."|cFFFFFFFF"..DataManager.GetRank(self.name).."|r")
      if DataManager.GetNumAlts(self.name) > 0 then
        GameTooltip:AddLine(L["Alts"]..": ")
        for i = 1,DataManager.GetNumAlts(self.name) do
          local altName = DataManager.GetAlt(self.name, i)
          GameTooltip:AddLine(altName, 1, 1, 1)
        end
      elseif DataManager.GetMain(self.name) and DataManager.GetMain(self.name) ~= self.name then
        GameTooltip:AddLine(L["Main"]..": ".."|cFFFFFFFF"..DataManager.GetMain(self.name).."|r")
      end
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("TOPLEFT", r.cells[7], "TOPRIGHT")
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- Hook up the headers
  tabl.headers[1]:SetScript("OnClick", function(self) StandingsManager.SortStandings("CLASS") end)
  tabl.headers[2]:SetScript("OnClick", function(self) StandingsManager.SortStandings("NAME") end)
  tabl.headers[3]:SetScript("OnClick", function(self) StandingsManager.SortStandings("BP") end)
  tabl.headers[4]:SetScript("OnClick", function(self) StandingsManager.SortStandings("GP") end)
  tabl.headers[5]:SetScript("OnClick", function(self) StandingsManager.SortStandings("INDEX") end)
  tabl.headers[6]:SetScript("OnClick", function(self) StandingsManager.SortStandings("DISTRIBUTION") end)
  tabl.headers[7]:SetScript("OnClick", function(self) StandingsManager.SortStandings("ROLL") end)

  -- Install the update function on rowFrame.
  local function UpdateStandings()
    if not rowFrame.needUpdate then return end

    local offset = FauxScrollFrame_GetOffset(BPGPScrollFrame)
    local numMembers = StandingsManager.GetNumMembers()
    local numDisplayedMembers = math.min(#rowFrame.rows, numMembers - offset)
    if offset > 0 and numDisplayedMembers < #rowFrame.rows then
      numDisplayedMembers = math.min(#rowFrame.rows, numMembers)
      offset = 0
    end
    local minBP = DataManager.GetMinBP(StandingsManager.GetTableId())

    for i = 1, #rowFrame.rows do
      local row = rowFrame.rows[i]
      local j = i + offset
      if j <= numMembers then
        local name = StandingsManager.GetMember(j)
        row.name = name
        row.cells[1]:SetText("")
        if DataManager.GetMain(name) then
          row.cells[2]:SetText("@"..row.name)
        elseif DataManager.IsInGuild(name) then
          row.cells[2]:SetText(row.name)
        else
          row.cells[2]:SetText("+"..row.name)
        end
        
        local c = DataManager.GetClassColor(row.name)
        row.cells[2]:SetTextColor(c.r, c.g, c.b)
        
        local bp, gp = DataManager.GetBPGP(row.name, StandingsManager.GetTableId())
        row.cells[3]:SetText(bp)
        row.cells[4]:SetText(gp)
        
        local index = DataManager.CalculateIndex(bp, gp)
        if index > 9999 then
          row.cells[5]:SetText(math.floor(index))
        else
          row.cells[5]:SetFormattedText("%.4g", index)
        end
        
        -- status1: 0 = none, 1 = in raid, 2 = standby enlisted
        -- status2: 0 = none, 1 = alert, 2 = requested standby
        local status1, status2 = StandingsManager.GetMemberStatus(row.name)
        
        if status1 == 1 then
        local response, equipped1, equipped2 = DistributionTracker.GetDecodedDistributionResponse(row.name)
          row.cells[6]:SetText(response)
          if equipped1 then
            row.itemLink1 = equipped1
            row.itemIcon1:SetTexture(GetItemIcon(Common:GetItemId(equipped1)))
            row.itemIcon1:Show()
          else
            row.itemLink1 = nil
            row.itemIcon1:Hide()
          end
          if equipped2 then
            row.itemLink2 = equipped2
            row.itemIcon2:SetTexture(GetItemIcon(Common:GetItemId(equipped2)))
            row.itemIcon2:Show()
          else
            row.itemLink2 = nil
            row.itemIcon2:Hide()
          end
        else
          row.cells[6]:SetText()
          row.itemIcon1:Hide()
          row.itemLink1 = nil
          row.itemIcon2:Hide()
          row.itemLink2 = nil
        end

        local roll_result, roll_violate = RollTracker.GetRollResult(name)
        row.cells[7]:SetText(roll_result)
        if roll_violate then
          row.cells[7]:SetTextColor(1, 0, 0)
        else
          row.cells[7]:SetTextColor(1, 1, 1)
        end
        
        row.class:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        row.class:SetTexCoord(unpack(CLASS_ICON_TCOORDS[DataManager.GetClass(row.name)]))
        
        if status1 == 1 then
          row.icon1:SetTexture("Interface\\CURSOR\\Attack")
          row.icon1:Show()
        elseif status1 == 2 then
          row.icon1:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
          row.icon1:Show()
        else
          row.icon1:Hide()
        end
        if status2 == 1 then
          row.icon2:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
          row.icon2:Show()
        elseif status2 == 2 then
          row.icon2:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
          row.icon2:Show()
        else
          row.icon2:Hide()
        end
        row:SetAlpha(bp < minBP and 0.6 or 1)
        row:Show()
      else
        row:Hide()
      end
      if row.name == BPGPSideFrame.name then
        row:LockHighlight()
      else
        row:UnlockHighlight()
      end
    end
    
    if GUI.db.profile.filterRanks and GUI.db.profile.minimalRank then
      local minRank = GUI.db.profile.minimalRank
      for i = 1, #rowFrame.rows do
        local row = rowFrame.rows[i]
        local rank = DataManager.GetRankIndex(row.name)
        if rank and rank > minRank then
          row:SetAlpha(0.6)
        end
      end
    end
      
    if not tableIdDropDown:GetValue() and DataManager.IsInitialized() then
      tableIdDropDown:Update()
    end
  
    lockButton:Update()
    alertFrame:Update()
    statusText:Update()
    
    FauxScrollFrame_Update(BPGPScrollFrame, numMembers, numDisplayedMembers, rowFrame.rowHeight, nil, nil, nil, nil, nil, nil, true)
    BPGPSideFrame:SetScript("OnHide", function(self)
      self.name = nil
      rowFrame.needUpdate = true
      UpdateStandings()
    end)
    rowFrame.needUpdate = nil
  end
  
  local function AutoUpdateStandings()
    if not StandingsManager.RegisterGuiUpdate() then return end
    rowFrame.needUpdate = true
    UpdateStandings()
  end
  
  local function ForceUpdateStandings()
    rowFrame.needUpdate = true
    UpdateStandings()
  end 
  BPGP.RegisterCallback("RankFilterUpdated", ForceUpdateStandings)

  rowFrame:SetScript("OnUpdate", AutoUpdateStandings)
  rowFrame:SetScript("OnShow", UpdateStandings)
  scrollBar:SetScript("OnVerticalScroll", function(self, value)
    rowFrame.needUpdate = true
    FauxScrollFrame_OnVerticalScroll(self, value, rowFrame.rowHeight, UpdateStandings)
  end)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.CreateTableHeader(parent)
  local h = CreateFrame("Button", nil, parent)
  h:SetHeight(24)

  local tl = h:CreateTexture(nil, "BACKGROUND")
  tl:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tl:SetWidth(5)
  tl:SetHeight(24)
  tl:SetPoint("TOPLEFT")
  tl:SetTexCoord(0, 0.07815, 0, 0.75)

  local tr = h:CreateTexture(nil, "BACKGROUND")
  tr:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tr:SetWidth(5)
  tr:SetHeight(24)
  tr:SetPoint("TOPRIGHT")
  tr:SetTexCoord(0.90625, 0.96875, 0, 0.75)

  local tm = h:CreateTexture(nil, "BACKGROUND")
  tm:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tm:SetHeight(24)
  tm:SetPoint("LEFT", tl, "RIGHT")
  tm:SetPoint("RIGHT", tr, "LEFT")
  tm:SetTexCoord(0.07815, 0.90625, 0, 0.75)

  h:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")

  return h
end

function private.CreateTableRow(parent, rowHeight, widths, justifiesH)
  local row = CreateFrame("Button", nil, parent)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row:SetHeight(rowHeight)
  row:SetPoint("LEFT")
  row:SetPoint("RIGHT")

  row.cells = {}
  for i,w in ipairs(widths) do
    local c = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    c:SetHeight(rowHeight)
    c:SetWidth(w - (2 * GUI.GetRowTextPadding()))
    c:SetJustifyH(justifiesH[i])
    if #row.cells == 0 then
      c:SetPoint("LEFT", row, "LEFT", GUI.GetRowTextPadding(), 0)
    else
      c:SetPoint("LEFT", row.cells[#row.cells], "RIGHT", 2 * GUI.GetRowTextPadding(), 0)
    end
    table.insert(row.cells, c)
    c:SetText(w)
  end

  return row
end

function private.CreateTable(parent, texts, widths, justfiesH, rightPadding)
  assert(#texts == #widths and #texts == #justfiesH, "All specification tables must be the same size")
  -- Compute widths
  local totalFixedWidths = rightPadding or 0
  local numDynamicWidths = 0
  for i,w in ipairs(widths) do
    if w > 0 then
      totalFixedWidths = totalFixedWidths + w
    else
      numDynamicWidths = numDynamicWidths + 1
    end
  end
  local remainingWidthSpace = parent:GetWidth() - totalFixedWidths
  assert(remainingWidthSpace >= 0, "Widths specified exceed parent width")

  local dynamicWidth = math.floor(remainingWidthSpace / numDynamicWidths)
  local leftoverWidth = remainingWidthSpace % numDynamicWidths
  for i, w in ipairs(widths) do
    if w <= 0 then
      numDynamicWidths = numDynamicWidths - 1
      if numDynamicWidths then
        widths[i] = dynamicWidth
      else
        widths[i] = dynamicWidth + leftoverWidth
      end
    end
  end

  -- Make headers
  parent.headers = {}
  for i = 1, #texts do
    local text, width, justifyH = texts[i], widths[i], justfiesH[i]
    local h = private.CreateTableHeader(parent, text, width)
    h:SetNormalFontObject("GameFontHighlightSmall")
    h:SetText(text)
    h:GetFontString():SetJustifyH(justifyH)
    h:SetWidth(width)
    if #parent.headers == 0 then
      h:SetPoint("TOPLEFT")
    else
      h:SetPoint("TOPLEFT", parent.headers[#parent.headers], "TOPRIGHT")
    end
    table.insert(parent.headers, h)
  end

  -- Make a frame for the rows
  local rowFrame = CreateFrame("Frame", nil, parent)
  rowFrame:SetPoint("TOP", parent.headers[#parent.headers], "BOTTOM")
  rowFrame:SetPoint("BOTTOMLEFT")
  rowFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightPadding, 0)
  parent.rowFrame = rowFrame

  -- Compute number of rows
  local fontHeight = select(2, GameFontNormalSmall:GetFont())
  local rowHeight = fontHeight + 4
  rowFrame.rowHeight = rowHeight
  local numRows = math.floor(rowFrame:GetHeight() / rowHeight)

  -- Make rows
  rowFrame.rows = {}
  for i=1,numRows do
    local r = private.CreateTableRow(rowFrame, rowHeight, widths, justfiesH)
    if #rowFrame.rows == 0 then
      r:SetPoint("TOP")
    else
      r:SetPoint("TOP", rowFrame.rows[#rowFrame.rows], "BOTTOM")
    end
    table.insert(rowFrame.rows, r)
  end
end
