local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local StandingsManager = BPGP.GetModule("StandingsManager")
local ChecksManager = BPGP.GetModule("ChecksManager")

local private = {}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPToolsFrame()
	local f = GUI.CreateCustomFrame("BPGPToolsFrame", BPGPFrame, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  GUI.RegisterSideframe(f)

  f:Hide()
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -27)
  f:SetWidth(162)
	f:SetHeight(380)
  
  f:SetHeader(L["Tools"])
  
  local standbyLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  standbyLabel:SetText(L["Standby List"])
  standbyLabel:SetPoint("TOP", f, 0, -20)
  standbyLabel:SetPoint("LEFT", f, "LEFT", 18, 0)
  
  local toggleAnnounceStandbyButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleAnnounceStandbyButton:SetNormalFontObject("GameFontNormalSmall")
  toggleAnnounceStandbyButton:SetHighlightFontObject("GameFontHighlightSmall")
  toggleAnnounceStandbyButton:SetDisabledFontObject("GameFontDisableSmall")
  toggleAnnounceStandbyButton:SetHeight(GUI.GetButtonHeight())
  toggleAnnounceStandbyButton:SetText(L["Announce List"])
  toggleAnnounceStandbyButton:SetWidth(130)
  toggleAnnounceStandbyButton:SetPoint("LEFT", standbyLabel, "LEFT", -2, 0)
  toggleAnnounceStandbyButton:SetPoint("TOP", standbyLabel, "BOTTOM", 0, -5)
  toggleAnnounceStandbyButton:SetScript("OnClick", function(self)
    BPGP.GetModule("StandbyTracker").AnnounceStandbyList()
  end)
  toggleAnnounceStandbyButton.Update = function(self)
    if DataManager.SelfSA() then
      toggleAnnounceStandbyButton:Enable()
    else
      toggleAnnounceStandbyButton:Disable()
    end
  end
  BPGP.RegisterCallback("DataManagerUpdated", toggleAnnounceStandbyButton.Update)
  
  local toggleRequestStandbyButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleRequestStandbyButton:SetNormalFontObject("GameFontNormalSmall")
  toggleRequestStandbyButton:SetHighlightFontObject("GameFontHighlightSmall")
  toggleRequestStandbyButton:SetDisabledFontObject("GameFontDisableSmall")
  toggleRequestStandbyButton:SetHeight(GUI.GetButtonHeight())
  toggleRequestStandbyButton:SetText(L["Send Request"])
  toggleRequestStandbyButton:SetWidth(130)
  toggleRequestStandbyButton:SetPoint("TOP", toggleAnnounceStandbyButton, "BOTTOM", 0, -5)
  toggleRequestStandbyButton:SetScript("OnClick", function(self)
    BPGP.GetModule("StandbyTracker").RequestStandby()
  end)
  toggleRequestStandbyButton.Update = function(self)
    if DataManager.SelfSA() then
      toggleRequestStandbyButton:Disable()
    else
      toggleRequestStandbyButton:Enable()
    end
  end
  BPGP.RegisterCallback("DataManagerUpdated", toggleRequestStandbyButton.Update)
  
  local massLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  massLabel:SetText(L["BP&GP Management"])
  massLabel:SetPoint("TOP", toggleRequestStandbyButton, "BOTTOM", 0, -10)
  massLabel:SetPoint("LEFT", f, "LEFT", 18, 0)

  local award = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  award:SetNormalFontObject("GameFontNormalSmall")
  award:SetHighlightFontObject("GameFontHighlightSmall")
  award:SetDisabledFontObject("GameFontDisableSmall")
  award:SetHeight(GUI.GetButtonHeight())
  award:SetPoint("LEFT", massLabel, "LEFT", -2, 0)
  award:SetPoint("TOP", massLabel, "BOTTOM", 0, -5)
  award:SetText(L["Mass BP Award"])
  award:SetWidth(130)
  award:SetScript("OnClick", function() GUI.ToggleSideFrame(BPGPSideFrame2) end)
  award:SetScript("OnUpdate", function(self)
    if DataManager.IsAllowedDataWrite() then
      self:Enable()
    else
      self:Disable()
    end
  end)
  GUI.RegisterRaidOlnyControl(award)

  local decay = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  decay:SetNormalFontObject("GameFontNormalSmall")
  decay:SetHighlightFontObject("GameFontHighlightSmall")
  decay:SetDisabledFontObject("GameFontDisableSmall")
  decay:SetHeight(GUI.GetButtonHeight())
  decay:SetPoint("TOP", award, "BOTTOM", 0, -5)
  decay:SetText(L["Decay"])
  decay:SetWidth(130)
  decay:SetScript("OnClick", function() DLG:Spawn("BPGP_DECAY_BPGP", DataManager.GetDecayPercent()) end)
  decay.Update = function()
    if DataManager.IsAllowedDataWrite() and DataManager.GetDecayPercent() > 0 then
      decay:Enable()
    else
      decay:Disable()
    end
  end
  BPGP.RegisterCallback("DataManagerUpdated", decay.Update)
  
  local raidToolsLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  raidToolsLabel:SetText(L["Raid Tools"])
  raidToolsLabel:SetPoint("LEFT", f, "LEFT", 18, 0)
  raidToolsLabel:SetPoint("TOP", decay, "BOTTOM", 0, -10)
  
  local toggleCooldownButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleCooldownButton:SetNormalFontObject("GameFontNormalSmall")
  toggleCooldownButton:SetHighlightFontObject("GameFontHighlightSmall")
  toggleCooldownButton:SetDisabledFontObject("GameFontDisableSmall")
  toggleCooldownButton:SetHeight(GUI.GetButtonHeight())
  toggleCooldownButton:SetText(L["Raid Cooldowns"])
  toggleCooldownButton:SetWidth(130)
  toggleCooldownButton:SetPoint("LEFT", raidToolsLabel, "LEFT", -2, 0)
  toggleCooldownButton:SetPoint("TOP", raidToolsLabel, "BOTTOM", 0, -5)
  toggleCooldownButton:SetScript("OnClick", function(self)
    GUI.ToggleBPGPCooldownsFrame()
  end)
  
  local toggleWipeProtectionButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleWipeProtectionButton:SetNormalFontObject("GameFontNormalSmall")
  toggleWipeProtectionButton:SetHighlightFontObject("GameFontHighlightSmall")
  toggleWipeProtectionButton:SetDisabledFontObject("GameFontDisableSmall")
  toggleWipeProtectionButton:SetHeight(GUI.GetButtonHeight())
  toggleWipeProtectionButton:SetText(L["Wipe Protection"])
  toggleWipeProtectionButton:SetWidth(130)
  toggleWipeProtectionButton:SetPoint("TOP", toggleCooldownButton, "BOTTOM", 0, -5)
  toggleWipeProtectionButton:SetScript("OnClick", function(self)
    GUI.ToggleBPGPWipeProtectionFrame()
  end)
  
  local toggleMaggyHelperButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleMaggyHelperButton:SetNormalFontObject("GameFontNormalSmall")
  toggleMaggyHelperButton:SetHighlightFontObject("GameFontHighlightSmall")
  toggleMaggyHelperButton:SetDisabledFontObject("GameFontDisableSmall")
  toggleMaggyHelperButton:SetHeight(GUI.GetButtonHeight())
  toggleMaggyHelperButton:SetText(L["Maggy Helper"])
  toggleMaggyHelperButton:SetWidth(130)
  toggleMaggyHelperButton:SetPoint("TOP", toggleWipeProtectionButton, "BOTTOM", 0, -5)
  toggleMaggyHelperButton:SetScript("OnClick", function(self)
    BPGP.GetModule("MaggyHelper").ToggleWidgetFrame()
  end)
  
  local toggleVashjHelperButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleVashjHelperButton:SetNormalFontObject("GameFontNormalSmall")
  toggleVashjHelperButton:SetHighlightFontObject("GameFontHighlightSmall")
  toggleVashjHelperButton:SetDisabledFontObject("GameFontDisableSmall")
  toggleVashjHelperButton:SetHeight(GUI.GetButtonHeight())
  toggleVashjHelperButton:SetText(L["Vashj Helper"])
  toggleVashjHelperButton:SetWidth(130)
  toggleVashjHelperButton:SetPoint("TOP", toggleMaggyHelperButton, "BOTTOM", 0, -5)
  toggleVashjHelperButton:SetScript("OnClick", function(self)
    BPGP.GetModule("VashjHelper").ToggleWidgetFrame()
  end)
  
  local lootCheckButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  lootCheckButton:SetNormalFontObject("GameFontNormalSmall")
  lootCheckButton:SetHighlightFontObject("GameFontHighlightSmall")
  lootCheckButton:SetDisabledFontObject("GameFontDisableSmall")
  lootCheckButton:SetHeight(GUI.GetButtonHeight())
  lootCheckButton:SetText(L["Whose Loot Check"])
  lootCheckButton:SetWidth(130)
  lootCheckButton:SetPoint("TOP", toggleVashjHelperButton, "BOTTOM", 0, -5)
  lootCheckButton:SetScript("OnClick", function(self)
    ChecksManager.RequestLootCheck()
  end)
  
  local serviceLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  serviceLabel:SetText(L["Utilities"])
  serviceLabel:SetPoint("LEFT", f, "LEFT", 18, 0)
  serviceLabel:SetPoint("TOP", lootCheckButton, "BOTTOM", 0, -10)
  
  local versionCheckButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  versionCheckButton:SetNormalFontObject("GameFontNormalSmall")
  versionCheckButton:SetHighlightFontObject("GameFontHighlightSmall")
  versionCheckButton:SetDisabledFontObject("GameFontDisableSmall")
  versionCheckButton:SetHeight(GUI.GetButtonHeight())
  versionCheckButton:SetText(L["Versions Check"])
  versionCheckButton:SetWidth(130)
  versionCheckButton:SetPoint("LEFT", serviceLabel, "LEFT", -2, 0)
  versionCheckButton:SetPoint("TOP", serviceLabel, "BOTTOM", 0, -5)
  versionCheckButton:SetScript("OnClick", function(self)
    ChecksManager.RequestVersionCheck()
  end)
  
end