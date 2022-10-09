local _, BPGP = ...

local MaggyHelper = BPGP.GetModule("MaggyHelper")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local GUI = BPGP.GetModule("GUI")
local DataManager = BPGP.GetModule("DataManager")

local MouseIsOver = MouseIsOver

local select, pairs, ipairs = select, pairs, ipairs
local UnitBuff, UnitDebuff, UnitIsDeadOrGhost = UnitBuff, UnitDebuff, UnitIsDeadOrGhost

local private = {
  classSpecIcons = {
    ["DRUID"] = {"Spell_nature_starfall", "Ability_druid_catform", "Spell_nature_healingtouch"},
    ["HUNTER"] = {"Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike"},
    ["MAGE"] = {"Spell_holy_magicalsentry", "Spell_fire_flamebolt", "Spell_Frost_FrostBolt02"},
    ["PALADIN"] = {"Spell_holy_holybolt", "Spell_holy_devotionaura", "Spell_holy_auraoflight"},
    ["PRIEST"] = {"Spell_Holy_WordFortitude", "Spell_holy_holybolt", "Spell_shadow_demonicfortitude"},
    ["ROGUE"] = {"Ability_rogue_eviscerate", "Ability_backstab", "Ability_stealth"},
    ["SHAMAN"] = {"Spell_nature_lightning", "Ability_shaman_stormstrike", "Spell_nature_healingwavegreater"},
    ["WARLOCK"] = {"Spell_shadow_deathcoil", "Spell_shadow_metamorphosis", "Spell_shadow_rainoffire"},
    ["WARRIOR"] = {"Ability_warrior_savageblow", "Ability_warrior_innerrage", "Ability_warrior_defensivestance"},
  },
}

function private.HandleLoadWidgets()
  MaggyHelper.CreateBPGPMaggyHelperFrame()
end
BPGP.RegisterCallback("LoadWidgets", private.HandleLoadWidgets)

function MaggyHelper.ShowWidgetFrame()
  private.frame:Show()
end

function MaggyHelper.HideWidgetFrame()
  private.frame:Hide()
end

-- Toggle core widget frame
function MaggyHelper.ToggleWidgetFrame()
  if private.frame:IsShown() then
    MaggyHelper.HideWidgetFrame()
  else
    MaggyHelper.ShowWidgetFrame()
  end
  MaggyHelper.db.profile.showFrame = private.frame:IsShown()
end

-- Toggle assignments frame
function MaggyHelper.ToggleAssignmentsFrame()
  MaggyHelper.ShowWidgetFrame()
  if private.assignmentsFrame:IsShown() then
    private.assignmentsFrame:Hide()
  else
    private.assignmentsFrame:Show()
  end
end

----------------------------------------
-- Popup-type frame for picking icon for selected cube position
----------------------------------------

function private.CreateTargetIconsControlsFrame(parent)
	local f = GUI.CreateCustomFrame("BPGPMaggyHelperTargetIconsControlsFrame", parent, "DefaultBackdrop")
  
  f:Hide()
  
  f:SetClampedToScreen(true)
  f:SetFrameStrata("TOOLTIP")
  
	f:SetWidth(110)
	f:SetHeight(80)
  
  local targetIconsLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  targetIconsLabel:SetPoint("TOP", f, "TOP", 0, -8)
  targetIconsLabel:SetText(L["Select Icon"])
  
  -- Default target icons order is "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Scull"
  f.targetIconButtons = {}
  for i = 1, 8 do
    local targetIconButton = CreateFrame("Button", nil, f)
    targetIconButton:SetWidth(24)
    targetIconButton:SetHeight(24)
    local iconId = 9-i -- Inverse order to match in-game list
    local texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..tostring(iconId)
    targetIconButton:SetNormalTexture(texture)
    targetIconButton:SetHighlightTexture(texture)
    targetIconButton:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.8)
    if i == 1 then
      targetIconButton:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -22)
    elseif i == 5 then
      targetIconButton:SetPoint("TOPLEFT", f.targetIconButtons[1], "BOTTOMLEFT", 0, 0)
    else
      targetIconButton:SetPoint("LEFT", f.targetIconButtons[i-1], "RIGHT", 0, 0)
    end
    targetIconButton:SetScript("OnClick", function (self)
      MaggyHelper.UpdateTargetIconPosition(f.activePositionButton.id, iconId)
      f:Hide()
    end)
  
    f.targetIconButtons[i] = targetIconButton
  end
  
  f:SetScript("OnShow", function (self)
    private.assignControlsFrame:Hide() -- Keep only one control frame active at the same time to not confuse the user
  end)

  f:SetScript("OnHide", function (self)
  end)

  private.iconsControlsFrame = f
end

----------------------------------------
-- Popup-type frame for picking assigned cube position and Blast Nova number
----------------------------------------

function private.CreatePlayerAssignControlsFrame(parent)
	local f = GUI.CreateCustomFrame("BPGPMaggyHelperPlayerAssignControlsFrame", parent, "DefaultBackdrop")
  
  f:Hide()
  
  f:SetClampedToScreen(true)
  f:SetFrameStrata("TOOLTIP")
  
  f:SetPoint("LEFT", parent, "RIGHT", 0, 17)
	f:SetWidth(120)
	f:SetHeight(105)
  
  local targetIconsLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  targetIconsLabel:SetPoint("TOP", f, "TOP", 0, -8)
  targetIconsLabel:SetText(L["Select Cube"])
  
  f.targetIconButtons = {}
  for i = 1, 5 do
    local targetIconButton = CreateFrame("Button", nil, f)
    targetIconButton:SetWidth(20)
    targetIconButton:SetHeight(20)
    if i == 1 then
      targetIconButton:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -22)
    else
      targetIconButton:SetPoint("LEFT", f.targetIconButtons[i-1], "RIGHT", 0, 0)
    end
    targetIconButton:SetScript("OnClick", function (self)
      f.positionId = i
      f.UpdatePlayerAssignment()
      f:Hide()
      f:Show()
    end)
    f.targetIconButtons[i] = targetIconButton
  end

  local playerAssignLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  playerAssignLabel:SetPoint("TOP", f, "TOP", 0, -45)
  playerAssignLabel:SetText(L["Select Nova"])
  
  f.playerAssignButtons, f.playerAssignLabels = {}, {}
  for i = 1, 4 do
    local playerAssignLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    playerAssignLabel:SetText(i)
    playerAssignLabel:SetFont("Fonts\\FRIZQT__.TTF", 16)
    playerAssignLabel:SetTextColor(1, 1, 1, 1)
    if i == 1 then
      playerAssignLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -60)
    else
      playerAssignLabel:SetPoint("LEFT", f.playerAssignLabels[i-1], "RIGHT", 15, 0)
    end
    f.playerAssignLabels[i] = playerAssignLabel
    
    local playerAssignButton = CreateFrame("Button", nil, f)
    playerAssignButton:SetPoint("CENTER", playerAssignLabel, "CENTER")
    playerAssignButton:SetHeight(20)
    playerAssignButton:SetWidth(30)
    playerAssignButton:SetScript("OnClick", function (self)
      f.novaId = i
      f.UpdatePlayerAssignment()
    end)
    f.playerAssignButtons[i] = playerAssignButton
  end
  
  function f.UpdatePlayerAssignment()
    local sourceSlotId = MaggyHelper.GetAssignedSlotId(DataManager.GetSelfName())
    local targetSlotId = (f.positionId - 1) * 4 + f.novaId
    if not private.assignmentsFrame:IsShown() then
      private.assignmentsFrame.Update()
    end
    private.assignmentsFrame.SwapPlayerFrames(sourceSlotId, targetSlotId)
  end
  
  local acceptButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  acceptButton:SetNormalFontObject("GameFontNormalSmall")
  acceptButton:SetHighlightFontObject("GameFontHighlightSmall")
  acceptButton:SetDisabledFontObject("GameFontDisableSmall")
  acceptButton:SetHeight(GUI.GetButtonHeight())
  acceptButton:SetText(L["Close"])
  acceptButton:SetWidth(60)
  acceptButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 5)
  acceptButton:SetScript("OnClick", function(self)
    f:Hide()
  end)

  function f.Update()
    local playerName = DataManager.GetSelfName()
    f.positionId = MaggyHelper.GetAssignedPositionId(playerName)
    f.novaId = MaggyHelper.GetAssignedNovaId(playerName)
    
    -- Sync target icons textures according to parent frame configuration
    for i = 1, 5 do
      local targetIconButton = f.targetIconButtons[i]
      local iconId = MaggyHelper.db.profile.currentPositions[i]
      local texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..tostring(iconId)
      targetIconButton:SetNormalTexture(texture)
      targetIconButton:SetHighlightTexture(texture)
      targetIconButton:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.8)
    end
    -- Saturate player-assigned target icon, grey-out the rest
    for index = 1, 5 do
      if index == f.positionId then
        f.targetIconButtons[index]:GetNormalTexture():SetDesaturated(false)
        f.targetIconButtons[index]:SetAlpha(1)
      else
        f.targetIconButtons[index]:GetNormalTexture():SetDesaturated(true)
        f.targetIconButtons[index]:SetAlpha(0.5)
      end
    end
    -- Make player-assigned Blast Nova number green, rest white
    for index = 1, 4 do
      if index == f.novaId then
        f.playerAssignLabels[index]:SetTextColor(1, 0, 0, 1)
      else
        f.playerAssignLabels[index]:SetTextColor(1, 1, 1, 1)
      end
    end
  end
  BPGP.RegisterCallback("AssignmentsCRCUpdated", f.Update)

  f:SetScript("OnShow", function (self)
    private.iconsControlsFrame:Hide() -- Keep only one control frame active at the same time to not confuse the user
    f.Update()
  end)
  
  f:SetScript("OnHide", function (self)
    f:GetParent().Update()
  end)

  private.assignControlsFrame = f
end

----------------------------------------
-- Popup-type frame for importing incoming assignments
----------------------------------------

function private.CreateAssignmentsImportFrame(parent)
	local f = GUI.CreateCustomFrame("BPGPMaggyHelperAssignmentsImportFrame", parent, "DefaultBackdrop")
  
  f:Hide()
  
	f:SetWidth(180)
	f:SetHeight(80)
	f:SetPoint("TOP", parent, "BOTTOM", 0, -56)
  
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  
  local frameLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  frameLabel:SetPoint("TOP", f, "TOP", 0, -12)
  frameLabel:SetText(L["Incoming assignments:"])
  
  local descLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  descLabel:SetPoint("CENTER", frameLabel, "CENTER", 0, -20)
  
  local acceptButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  acceptButton:SetNormalFontObject("GameFontNormalSmall")
  acceptButton:SetHighlightFontObject("GameFontHighlightSmall")
  acceptButton:SetDisabledFontObject("GameFontDisableSmall")
  acceptButton:SetHeight(GUI.GetButtonHeight())
  acceptButton:SetText(L["Accept"])
  acceptButton:SetWidth(70)
  acceptButton:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -8, 8)
  acceptButton:SetScript("OnClick", function(self)
    MaggyHelper.ResponseAssignmentsBroadcast(1)
    f:Hide()
  end)
  
  local declineButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  declineButton:SetNormalFontObject("GameFontNormalSmall")
  declineButton:SetHighlightFontObject("GameFontHighlightSmall")
  declineButton:SetDisabledFontObject("GameFontDisableSmall")
  declineButton:SetHeight(GUI.GetButtonHeight())
  declineButton:SetText(L["Decline"])
  declineButton:SetWidth(70)
  declineButton:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 8)
  declineButton:SetScript("OnClick", function(self)
    MaggyHelper.ResponseAssignmentsBroadcast(0)
    f:Hide()
  end)

  function f.HandleAssignmentsBroadcast(event, incomingAssignments)
    if incomingAssignments.notResponded then
      descLabel:SetText(incomingAssignments.watermark)
      f:Show()
    end
  end
  BPGP.RegisterCallback("AssignmentsBroadcastProcessed", f.HandleAssignmentsBroadcast)
  
  private.assignmentsImportFrame = f
end

----------------------------------------
-- Drag&Drop frame for configuring assignments
----------------------------------------

function private.CreateAssignmentsFrame(parent)
	local f = GUI.CreateCustomFrame("BPGPMaggyHelperAssignmentsFrame", parent, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  
  f:Hide()
  
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetUserPlaced(true)
  f:SetClampedToScreen(true)
  f:SetHitRectInsets(0, 0, -20, 0)
  f:SetFrameStrata("HIGH")
  
  f:SetPoint("TOP", parent, "BOTTOM", 0, 17)
	f:SetWidth(470)
	f:SetHeight(230)
  
  f:SetScript("OnMouseDown", function (self) self:StartMoving() end)
  f:SetScript("OnMouseUp", function (self) self:StopMovingOrSizing() end)
  
  function f.UpdateHeader()
    f:SetHeader(L["Assignments |cFF00FF00#%d|r"]:format(MaggyHelper.GetCurrentCRC()))
  end
  f.UpdateHeader()
  BPGP.RegisterCallback("AssignmentsCRCUpdated", f.UpdateHeader)
  
  local assignmentsFrame = CreateFrame("Frame", nil, f)
  assignmentsFrame:SetPoint("TOP", f, "TOP", 8, -14)
	assignmentsFrame:SetWidth(470)
	assignmentsFrame:SetHeight(230)
  
  local unassignedLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  unassignedLabel:SetPoint("TOP", assignmentsFrame, "TOP", 0, -90)
  unassignedLabel:SetText(L["Not Assigned:"])
  
  f.groupFrames, f.slotFrames, f.targetIcons = {}, {}, {}
  for i = 1, 10 do
    local groupFrame = CreateFrame("Frame", nil, assignmentsFrame)
    
    groupFrame:SetWidth(80)
    groupFrame:SetHeight(90)
    
    if i == 1 then
      groupFrame:SetPoint("TOPLEFT", assignmentsFrame, "TOPLEFT", 10, 0)
    elseif i == 6 then
      groupFrame:SetPoint("TOPLEFT", assignmentsFrame, "TOPLEFT", 10, -90)
    else
      groupFrame:SetPoint("TOPLEFT", f.groupFrames[i-1], "TOPRIGHT", 10, 0)
    end
    
    f.groupFrames[i] = groupFrame
    
    if i < 6 then
      local targetIcon = groupFrame:CreateTexture(nil, ARTWORK)
      targetIcon:SetWidth(12)
      targetIcon:SetHeight(12)
      targetIcon:SetPoint("TOP", groupFrame, "TOP", 0, 0)
      f.targetIcons[i] = targetIcon
    end
  
    for index = 1, 4 do
      local slotFrame = CreateFrame("Frame", nil, groupFrame, BackdropTemplateMixin and "BackdropTemplate")
      slotFrame.id = #f.slotFrames + 1
      
      slotFrame:SetWidth(80)
      slotFrame:SetHeight(17)
      
      if index == 1 then
        slotFrame:SetPoint("TOP", groupFrame, "TOP", 0, -16)
      else
        slotFrame:SetPoint("TOP", f.slotFrames[(i-1)*4+index-1], "BOTTOM", 0, 0)
      end
      
      slotFrame:SetBackdrop({
  --      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  --      bgFile = "Interface/CharacterFrame/UI-Party-Background",
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
      })
      slotFrame:SetBackdropColor(0.07, 0.07, 0.07, 1)
      slotFrame:SetBackdropBorderColor(0, 0, 0, 1)
      
      if i < 6 then
        local numberLabel = slotFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        numberLabel:SetPoint("RIGHT", slotFrame, "LEFT", 1, 0)
        numberLabel:SetText(L["%d."]:format(index))
--        numberLabel:SetTextColor(1, 1, 1)
      end
      
      local backgroundLabel = slotFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      backgroundLabel:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
      backgroundLabel:SetText(L["Empty"])
      
      tinsert(f.slotFrames, slotFrame)
      
      function slotFrame:UpdateHighlight(highlight)
        if highlight then
          self.isHighlighted = true
          self:SetBackdropBorderColor(1, 1, 0, 1)
        else
          self.isHighlighted = true
          self:SetBackdropBorderColor(0, 0, 0, 1)
        end
      end
        
      slotFrame:SetScript("OnEnter", function(self)
        self:UpdateHighlight(true)
      end)
      slotFrame:SetScript("OnLeave", function(self)
        self:UpdateHighlight(false)
      end)
    end
    
  end
  
  f.playerFrames = {}
  for i = 1, 40 do
    local playerFrame = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")
    playerFrame.id = i
    
    playerFrame:Hide()
    
    playerFrame:EnableMouse(true)
    playerFrame:SetMovable(true)
    playerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    
    playerFrame:SetBackdrop({
      bgFile = "Interface/ChatFrame/ChatFrameBackground", -- "Interface/CharacterFrame/UI-Party-Background"
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    playerFrame:SetBackdropColor(0.2, 0.2, 0.2, 1)
    playerFrame:SetBackdropBorderColor(0, 0, 0, 1)
    
    local specIcon = playerFrame:CreateTexture(nil, ARTWORK)
    specIcon:SetWidth(11)
    specIcon:SetHeight(11)
    specIcon:SetPoint("LEFT", playerFrame, "LEFT", 3, 0)
    specIcon:SetTexCoord(.08, .92, .08, .92)
    
    local playerLabel = playerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    playerLabel:SetPoint("LEFT", specIcon, "RIGHT", 2, 0)
    playerLabel:SetText("Player"..tostring(i))
    playerLabel:SetJustifyH("LEFT")
    
    local statusIcon = playerFrame:CreateTexture(nil, ARTWORK)
    statusIcon:SetWidth(10)
    statusIcon:SetHeight(10)
    statusIcon:SetPoint("RIGHT", playerFrame, "RIGHT", -3, 0)
    
    playerLabel:SetPoint("RIGHT", statusIcon, "LEFT", 0, 0)
    
    function playerFrame:BindToSlot(slotId)
      self.boundSlotId = slotId
      local slotFrame = f.slotFrames[slotId]
      slotFrame.boundPlayerId = self.id
      self:SetAllPoints(slotFrame)
    end
    playerFrame:BindToSlot(i)
    
    function playerFrame:BindPlayer(playerName)
      MaggyHelper.SetAssignedSlotId(playerName, playerFrame.boundSlotId)
      playerFrame.name = playerName
      playerFrame.class = DataManager.GetRaidClass(playerName)
      playerLabel:SetText(playerName)
      playerFrame:Show()
    end
    
    function playerFrame:UnbindPlayer()
--      MaggyHelper.SetAssignedSlotId(playerFrame.name, nil)
      playerFrame:Hide()
      playerFrame.name = nil
      playerFrame.isDead = nil
      playerFrame.specId = nil
      playerLabel:SetText("")
    end
    
    function playerFrame:UpdateAliveState()
      if playerFrame:IsShown() then
        local isDead = UnitIsDeadOrGhost(playerFrame.name)
        if playerFrame.isDead ~= isDead then
          playerFrame.isDead = isDead
          if isDead then
            playerLabel:SetTextColor(1, 0, 0)
          else
            local color = DataManager.GetRaidClassColor(playerFrame.name)
            playerLabel:SetTextColor(color.r, color.g, color.b)
          end
        end
      end
    end
    
    function playerFrame:UpdateBackgroundColor()
      -- Update Mind Exhaustion debuff and Shadow Grasp states
      local buffId, debuffId = nil, nil
      for i = 1, 40 do
        buffId = select(10, UnitBuff(playerFrame.name, i))
        if buffId == 30410 then -- Shadow Grasp id = 30410
          playerFrame:SetBackdropColor(0, 0.4, 0, 1)
          break
        end
        if buffId == nil then break end
      end
      if not buffId then
        for i = 1, 40 do
          debuffId = select(10, UnitDebuff(playerFrame.name, i))
          if debuffId == 44032 then -- Mind Exhaustion id = 44032
            playerFrame:SetBackdropColor(0.24, 0, 0.48, 1)
            break
          end
          if debuffId == nil then break end
        end
      end
      if not (buffId or debuffId) then
        playerFrame:SetBackdropColor(0.2, 0.2, 0.2, 1)
      end
    end
    
    function playerFrame:UpdateSpecIcon()
      local specId = MaggyHelper.GetSpecId(playerFrame.name)
      if playerFrame.specId and playerFrame.specId == specId then return end
      playerFrame.specId = specId
      if specId then
        specIcon:SetTexture("Interface\\Icons\\"..private.classSpecIcons[playerFrame.class][specId])
        specIcon:SetDesaturated(false)
      else
        specIcon:SetTexture("Interface\\Icons\\Classicon_"..playerFrame.class)
        specIcon:SetDesaturated(true)
      end
    end
    
    function playerFrame:UpdateStatusIcon()
      local playerCRC = MaggyHelper.GetPlayerCRC(playerFrame.name)
      if not playerCRC then
        statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
      elseif playerCRC == MaggyHelper.GetCurrentCRC() then
        statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
      else
        statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
      end
--      statusIcon:Show()
    end
--    BPGP.RegisterCallback("BroadcastResponseProcessed", playerFrame.UpdateStatusIcon)
  
  
    function playerFrame:UpdateHighlight(highlight)
      if self.isMoving then return end
      if highlight then
        self.isHighlighted = true
        self:SetBackdropBorderColor(1, 1, 0, 1)
      else
        self.isHighlighted = true
        self:SetBackdropBorderColor(0, 0, 0, 1)
      end
    end
    
    playerFrame:SetScript("OnEnter", function(self)
      self:UpdateHighlight(true)
    end)
  
    playerFrame:SetScript("OnLeave", function(self)
      self:UpdateHighlight(false)
    end)
    
    playerFrame:SetScript("OnMouseDown", function (self, button, ...)
      if button == "LeftButton" then
        self:UpdateHighlight(true)
        self.isMoving = true
        self:StartMoving()
        self:SetFrameStrata("TOOLTIP")
        assignmentsFrame:SetScript("OnUpdate", function (self, ...)
          local dragTargetSlotId = 0
          for i = 1, 40 do
            local slotFrame = f.slotFrames[i]
            if MouseIsOver(slotFrame) then
              dragTargetSlotId = slotFrame.id
              slotFrame:UpdateHighlight(true)
              f.playerFrames[slotFrame.boundPlayerId]:UpdateHighlight(true)
            elseif slotFrame.isHighlighted then
              slotFrame:UpdateHighlight(false)
              f.playerFrames[slotFrame.boundPlayerId]:UpdateHighlight(false)
            end
          end
          f.dragTargetSlotId = dragTargetSlotId
        end)
      end
    end)
  
    function f.SwapPlayerFrames(sourceSlotId, targetSlotId)
      local sourceSlotFrame = f.slotFrames[sourceSlotId]
      local targetSlotFrame = f.slotFrames[targetSlotId]
      local sourcePlayerFrame = f.playerFrames[sourceSlotFrame.boundPlayerId]
      local targetPlayerFrame = f.playerFrames[targetSlotFrame.boundPlayerId]
      
      sourcePlayerFrame:BindToSlot(targetSlotFrame.id)
      targetPlayerFrame:BindToSlot(sourceSlotFrame.id)
      targetSlotFrame:UpdateHighlight(false)
      targetPlayerFrame:UpdateHighlight(false)
      
      MaggyHelper.SetAssignedSlotId(sourcePlayerFrame.name, sourcePlayerFrame.boundSlotId)
      MaggyHelper.SetAssignedSlotId(targetPlayerFrame.name, targetPlayerFrame.boundSlotId)
      MaggyHelper.UpdateCurrentCRC()
    end
  
    playerFrame:SetScript("OnMouseUp", function (self, ...)
      assignmentsFrame:SetScript("OnUpdate", nil)
      self.isMoving = false
      self:StopMovingOrSizing()
      self:SetFrameStrata("FULLSCREEN_DIALOG")
      
      if f.dragTargetSlotId ~= 0 and f.dragTargetSlotId ~= self.boundSlotId then
        f.SwapPlayerFrames(self.boundSlotId, f.dragTargetSlotId)
      else
        self:BindToSlot(self.boundSlotId)
      end
      f.dragTargetSlotId = 0
    end)
    
    tinsert(f.playerFrames, playerFrame)
  end
  
  local broadcastButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  broadcastButton:SetNormalFontObject("GameFontNormalSmall")
  broadcastButton:SetHighlightFontObject("GameFontHighlightSmall")
  broadcastButton:SetDisabledFontObject("GameFontDisableSmall")
  broadcastButton:SetHeight(GUI.GetButtonHeight())
  broadcastButton:SetText(L["Broadcast"])
  broadcastButton:SetWidth(80)
  broadcastButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 12)
  broadcastButton:SetScript("OnClick", function(self)
    MaggyHelper.BroadcastAssignments()
  end)
  
  local announceButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  announceButton:SetNormalFontObject("GameFontNormalSmall")
  announceButton:SetHighlightFontObject("GameFontHighlightSmall")
  announceButton:SetDisabledFontObject("GameFontDisableSmall")
  announceButton:SetHeight(GUI.GetButtonHeight())
  announceButton:SetText(L["Announce"])
  announceButton:SetWidth(80)
--  announceButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 12)
  announceButton:SetPoint("LEFT", broadcastButton, "RIGHT", 6, 0)
  announceButton:SetScript("OnClick", function(self)
    MaggyHelper.AnnounceCurrentAssignments()
  end)
  
  local autoAssignButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  autoAssignButton:SetNormalFontObject("GameFontNormalSmall")
  autoAssignButton:SetHighlightFontObject("GameFontHighlightSmall")
  autoAssignButton:SetDisabledFontObject("GameFontDisableSmall")
  autoAssignButton:SetHeight(GUI.GetButtonHeight())
  autoAssignButton:SetText(L["Auto Assign"])
  autoAssignButton:SetWidth(80)
--  announceButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 12)
  autoAssignButton:SetPoint("LEFT", announceButton, "RIGHT", 6, 0)
  autoAssignButton:SetScript("OnClick", function(self)
    MaggyHelper.AutoAssign()
  end)
  
  local revertChangesButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  revertChangesButton:Hide()
  revertChangesButton:SetNormalFontObject("GameFontNormalSmall")
  revertChangesButton:SetHighlightFontObject("GameFontHighlightSmall")
  revertChangesButton:SetDisabledFontObject("GameFontDisableSmall")
  revertChangesButton:SetHeight(GUI.GetButtonHeight())
  revertChangesButton:SetWidth(110)
  revertChangesButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 12)
  revertChangesButton:SetScript("OnClick", function(self)
    MaggyHelper.LoadLastKnownAssignments()
  end)
  revertChangesButton.Update = function ()
    local crc = MaggyHelper.GetIncomingAssignmentsCRC()
    revertChangesButton:SetText(L["Load #%d"]:format(crc)) 
    if not crc or crc == MaggyHelper.GetCurrentCRC() or MaggyHelper.GetCurrentCRC() == 0 then 
      revertChangesButton:Hide()
    else
      revertChangesButton:Show()
    end
  end
  BPGP.RegisterCallback("AssignmentsBroadcastProcessed", revertChangesButton.Update)
  BPGP.RegisterCallback("AssignmentsCRCUpdated", revertChangesButton.Update)
  
  local raidCache = {}
  function f.HandleNewAssignmentsReceived()
    for i = 1, 40 do
      local playerFrame = f.playerFrames[i]
      if playerFrame:IsShown() then
        raidCache[playerFrame.name] = nil
        playerFrame:UnbindPlayer()
      end
    end
  end
  BPGP.RegisterCallback("NewAssignmentsReceived", f.HandleNewAssignmentsReceived)
  
  function f.Update()
    -- Update target icons
    for i = 1, 5 do
      local targetIcon = f.targetIcons[i]
      local textureId = MaggyHelper.db.profile.currentPositions[i]
      targetIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..tostring(textureId))
    end
    -- Routine data updating of filled slots
    for i = 1, 40 do
      local playerFrame = f.playerFrames[i]
      -- Empty playerFrame's are hidden. If it's shown, we should take care of it
      if playerFrame:IsShown() then
        if DataManager.IsInRaid(playerFrame.name) then
          -- Players is in the raid, updating dynamic data
          playerFrame:UpdateAliveState()
          playerFrame:UpdateStatusIcon()
          playerFrame:UpdateSpecIcon()
          playerFrame:UpdateBackgroundColor()
        else
          -- Players is no longer present, some clean-up required
          raidCache[playerFrame.name] = nil
          playerFrame:UnbindPlayer()
        end
      end
    end
    -- Fitting new players to empty slots
    local dataUpdated = false
    for playerName, playerClass in pairs(DataManager.GetRaidDB("class")) do
      if not raidCache[playerName] then
        local playerFrame = nil
        -- If there is cached assignment for given player, we'll try to fit him to his slot if it's still empty
        local assignedSlotId = MaggyHelper.GetAssignedSlotId(playerName)
        if assignedSlotId > 0 then
          local assignedSlotFrame = f.slotFrames[assignedSlotId]
          local assignedPlayerFrame = f.playerFrames[assignedSlotFrame.boundPlayerId]
          if not assignedPlayerFrame:IsShown() then
            playerFrame = assignedPlayerFrame
          end
        end
        -- If player wasn't assigned to any slot earlier, we'll assign him to the empty slot with highest id
        if not playerFrame then
          for i = 40, 1, -1 do
            local boundPlayerFrame = f.playerFrames[f.slotFrames[i].boundPlayerId]
            if not boundPlayerFrame:IsShown() then
              playerFrame = boundPlayerFrame
              break
            end
          end
        end
        -- Here we bind player to target playerFrame. If we fail to do so, then there is some bug present.
        if playerFrame then
          playerFrame:BindPlayer(playerName)
          raidCache[playerFrame.name] = true
          playerFrame:UpdateAliveState()
          playerFrame:UpdateStatusIcon()
          playerFrame:UpdateSpecIcon()
          dataUpdated = true
        else
          BPGP.Printf("Maggy Helper: Failed to bind player %s to any slot!", playerName)
        end
      end
    end
    if dataUpdated then
      MaggyHelper.UpdateCurrentCRC()
    end
    -- Update buttons access
    if (DataManager.GetRaidRank(DataManager.GetSelfName()) or 0) > 0 then 
      broadcastButton:Enable()
      announceButton:Enable()
      autoAssignButton:Enable()
    else
      broadcastButton:Disable()
      announceButton:Disable()
      autoAssignButton:Disable()
    end
    -- Cleanup if not in raid
    if not DataManager.SelfInRaid() and MaggyHelper.GetCurrentCRC() ~= 0 then
      MaggyHelper.ResetCurrentCRC()
    end
  end

  function f.AsyncUpdate()
    while f:IsShown() do
  --    local startTime = debugprofilestop()
      f.Update()
  --    Debugger("AsyncUpdate took "..tostring(debugprofilestop() - startTime).." ms")
      Coroutine:Sleep(0.5)
    end
  end

  f:SetScript("OnShow", function (self)
    Coroutine:RunAsync(f.AsyncUpdate)
  end)

  f:SetScript("OnHide", function (self)
  end)
  
  private.assignmentsFrame = f
end

----------------------------------------
-- Core MaggyHelper widget frame
----------------------------------------
  
function MaggyHelper.CreateBPGPMaggyHelperFrame()
	local f = GUI.CreateCustomFrame("BPGPMaggyHelperFrame", UIParent, "")
	f:Hide()
	f:SetWidth(110)
	f:SetHeight(150)
  
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetUserPlaced(true)
  f:SetClampedToScreen(true)
  
  f:SetPoint("TOP", nil, "TOP", 0, -24)
  
  -- Create child frames (user controls)
  private.CreateTargetIconsControlsFrame(f)
  private.CreatePlayerAssignControlsFrame(f)
  private.CreateAssignmentsFrame(f)
  private.CreateAssignmentsImportFrame(f)

  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOP", f, "TOP", 0, 0)
  label:SetJustifyH("CENTER")
	label:SetText(L["Maggy Helper"])
  
  -- Next Blast Nova number display, turns red if next Nova is assigned to player
  local novaCounterLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  novaCounterLabel:SetPoint("CENTER", f, "CENTER", 0, 20)
  novaCounterLabel:SetFont("Fonts\\FRIZQT__.TTF", 28)
  novaCounterLabel.DelayedFlashing = function ()
    novaCounterLabel.flashingScheduled = true
    MaggyHelper.SetNextNovaCastTime(nil)
    Coroutine:Sleep(10)
    novaCounterLabel:SetTextColor(1, 0, 0, 1)
    Coroutine:Sleep(30)
    local nextNovaCastTime = MaggyHelper.GetNextNovaCastTime()
    if nextNovaCastTime then
      Coroutine:Sleep(nextNovaCastTime-GetServerTime())
    end
    MaggyHelper.PlaySoundWarning()
    local state = true
    while novaCounterLabel.flashingScheduled do
      if state then
        state = false
        novaCounterLabel:SetFont("Fonts\\FRIZQT__.TTF", 28)
      else
        state = true
        if DataManager.SelfInCombat() then
          novaCounterLabel:SetFont("Fonts\\FRIZQT__.TTF", 34)
        end
      end
      Coroutine:Sleep(0.3)
    end
  end
  novaCounterLabel.Update = function (event)
    local nextNova = MaggyHelper.GetNextNovaNumber()
    novaCounterLabel:SetText(nextNova)
    
    local assignedNova = MaggyHelper.GetAssignedNovaId(DataManager.GetSelfName())
    
    if assignedNova > 0 and (nextNova == assignedNova or nextNova == assignedNova + 4) then
      novaCounterLabel:SetTextColor(1, 1, 0, 1)
      if not novaCounterLabel.flashingScheduled then
        Coroutine:RunAsync(novaCounterLabel.DelayedFlashing)
      end
    else
      novaCounterLabel:SetTextColor(1, 1, 1, 1)
      novaCounterLabel.flashingScheduled = false
    end
  end
  BPGP.RegisterCallback("NovaCounterUpdate", novaCounterLabel.Update)
  
  -- "Fake" button to handle user clicks (as no "OnClick" for "FontString" type)
  local novaCounterFrame = CreateFrame("Button", nil, f)
  novaCounterFrame:SetPoint("CENTER", novaCounterLabel, "CENTER")
  novaCounterFrame:SetHeight(30)
  novaCounterFrame:SetWidth(30)
  novaCounterFrame:SetScript("OnEnter", function (self)
    novaCounterLabel:SetFont("Fonts\\FRIZQT__.TTF", 34)
  end)
  novaCounterFrame:SetScript("OnLeave", function (self)
    novaCounterLabel:SetFont("Fonts\\FRIZQT__.TTF", 28)
  end)
  novaCounterFrame:SetScript("OnClick", function (self)
    if private.assignControlsFrame:IsShown() then
      private.assignControlsFrame:Hide()
    else
      private.assignControlsFrame:Show()
    end
  end)

  -- A bit of basic math to make perfect icon positions, starting point ("0" angle) is [x = radius, y = 0]
  local positionButtonAngles = {54, 342, 270, 198, 126}
  local function GetCirclePointCoords(radius, angle)
    return radius * math.cos(math.rad(angle)), radius * math.sin(math.rad(angle)) -- Degrees to radians 'cause Lua
  end
  
  -- Target icons display for each Cube, also shows numbers of assigned Novas
  f.positionButtons, f.assignedNovasLabels = {}, {}
  for i = 1, 5 do
    local positionButton = CreateFrame("Button", nil, f)
    positionButton:SetWidth(24)
    positionButton:SetHeight(24)
    positionButton:SetPoint("CENTER", novaCounterLabel, "CENTER", GetCirclePointCoords(35, positionButtonAngles[i]))
    positionButton.id = i
    positionButton:SetScript("OnClick", function (self)
      if private.iconsControlsFrame.activePositionButton ~= self then
        private.iconsControlsFrame.activePositionButton = self
        private.iconsControlsFrame:SetPoint("TOP", self, "BOTTOM", 0, 0)
        private.iconsControlsFrame:Show()
      else
        if private.iconsControlsFrame:IsShown() then
          private.iconsControlsFrame:Hide()
        else
          private.iconsControlsFrame:Show()
        end
      end
    end)
    tinsert(f.positionButtons, positionButton)
    
    local assignedNovasLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    assignedNovasLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    assignedNovasLabel:SetPoint("TOP", positionButton, "BOTTOM", 0, 0)
    tinsert(f.assignedNovasLabels, assignedNovasLabel)
  end
  
  local assignmentsButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  assignmentsButton:Hide()
  assignmentsButton:SetNormalFontObject("GameFontNormalSmall")
  assignmentsButton:SetHighlightFontObject("GameFontHighlightSmall")
  assignmentsButton:SetDisabledFontObject("GameFontDisableSmall")
  assignmentsButton:SetHeight(GUI.GetButtonHeight())
  assignmentsButton:SetText(L["Assignments"])
  assignmentsButton:SetWidth(80)
  assignmentsButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
  assignmentsButton:SetScript("OnClick", function(self)
    MaggyHelper.ToggleAssignmentsFrame()
  end)
  function assignmentsButton.AsyncUpdate()
    while f:IsShown() do
      if MouseIsOver(f) then
        assignmentsButton:Show()
      else
        assignmentsButton:Hide()
      end
      Coroutine:Sleep(0.1)
    end
  end

  -- Full Maggy Helper frame state update
  f.Update = function()
    local playerName = DataManager.GetSelfName()
    for index = 1, 5 do
      local iconId = MaggyHelper.db.profile.currentPositions[index]
      local texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..tostring(iconId)
      f.positionButtons[index]:SetNormalTexture(texture)
      f.positionButtons[index]:SetHighlightTexture(texture)
      if index == MaggyHelper.GetAssignedPositionId(playerName) then
        f.positionButtons[index]:GetNormalTexture():SetDesaturated(false)
        f.positionButtons[index]:SetAlpha(1)
        local assignedNova = MaggyHelper.GetAssignedNovaId(playerName)
        f.assignedNovasLabels[index]:SetText(L["%d, %d"]:format(assignedNova, assignedNova+4)) -- Assigned novas list
      else
        f.positionButtons[index]:GetNormalTexture():SetDesaturated(true)
        f.positionButtons[index]:SetAlpha(0.5)
        f.assignedNovasLabels[index]:SetText("")
      end
    end
    novaCounterLabel.Update()
  end
  f.Update()
  BPGP.RegisterCallback("AssignmentsCRCUpdated", f.Update)
  
  f:SetScript("OnShow", function (self)
    Coroutine:RunAsync(assignmentsButton.AsyncUpdate)
  end)

  ----------------------------------------
  -- Menu
  ----------------------------------------
  local titleDropDownMenu = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  titleDropDownMenu.displayMode = "MENU"
  local info = {}
  titleDropDownMenu.initialize = function(self, level)
    wipe(info)
    if MaggyHelper.db.profile.lockFrame then
      info.text = L["Unlock Window"]
    else
      info.text = L["Lock Window"]
    end
    info.func = function()
      MaggyHelper.db.profile.lockFrame = not MaggyHelper.db.profile.lockFrame
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
    wipe(info)
    info.text = L["Hide Window"]
    info.func = function()
      MaggyHelper.ToggleWidgetFrame()
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, level)
    wipe(info)
    if MaggyHelper.db.profile.soundEnabled then
      info.text = L["Disable Sound"]
    else
      info.text = L["Enable Sound"]
    end
    info.func = function()
      MaggyHelper.ToggleSound()
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
      if not MaggyHelper.db.profile.lockFrame then
        self:StartMoving()
      end
    elseif button == "RightButton" then
      ToggleDropDownMenu(1, nil, titleDropDownMenu, label, 0, 0)
    end
  end)
  f:SetScript("OnMouseUp", function (self)
    if not MaggyHelper.db.profile.lockFrame then
      self:StopMovingOrSizing()
    end
  end)

  private.frame = f
end
