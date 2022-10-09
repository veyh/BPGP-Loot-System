local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Common = BPGP.GetLibrary("Common")
local Coroutine = BPGP.GetLibrary("Coroutine")

local DistributionTracker = BPGP.GetModule("DistributionTracker")

local private = {
  frame = nil,
  importBuffer = {},
  parsedData = nil,
  inputBlocked = false,
}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPLootPopupCommentsImportFrame()
	local f = GUI.CreateCustomFrame("BPGPLootPopupCommentsImportFrame", UIParent, "DefaultBackdrop")
  f:Hide()
  f:SetFrameStrata("TOOLTIP")
  f:SetPoint("CENTER")
  f:SetHeight(150)
  f:SetWidth(500)
  f:SetToplevel(true)
  private.frame = f

  local help = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  help:SetPoint("TOP", f, "TOP", 0, -20)
  help:SetWidth(f:GetWidth() - 40)
  help:SetText(L["To import Loot Popup Comments please paste the text to the field below."].."\n"..
               L["Lines formatted different from 'Item Name - Some Comment' will be ignored."])
  f.help = help

  local button1 = CreateFrame("Button", nil, f, "StaticPopupButtonTemplate")
  button1:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
  button1:SetPoint("CENTER", -button1:GetWidth()/2-5, 0)
  button1:SetText(L["Import"])
  button1:SetScript("OnClick", function (self)
    DistributionTracker.ImportLootPopupComments(private.parsedData)
    f:Hide()
  end)
  f.button1 = button1
  
  local button2 = CreateFrame("Button", nil, f, "StaticPopupButtonTemplate")
  button2:SetPoint("BOTTOM", button1, "BOTTOM")
  button2:SetPoint("LEFT", button1, "RIGHT", 10, 0)
  button2:SetText(CANCEL)
  button2:SetScript("OnClick", function (self) self:GetParent():Hide() end)
  f.button2 = button2

  local editBox = CreateFrame("EditBox", nil, f)
  editBox:SetWidth(425)
  editBox:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
  editBox:SetPoint("TOPRIGHT", help, "BOTTOMRIGHT", 0, 0)
  editBox:SetPoint("BOTTOM", button1, "TOP", 0, 10)
  editBox:EnableMouse(true)
  editBox:SetAutoFocus(false)
  editBox:SetMultiLine(true)
  editBox:SetJustifyH("CENTER")
  editBox:SetFontObject(GameFontHighlight)
  editBox:SetMaxBytes(512) -- Prevents UI from drawing huge strings while still providing some space for drawing responses
  editBox:SetScript('OnChar', function(self, char)
    if private.inputBlocked then return end
    table.insert(private.importBuffer, char)
  end)
  editBox:SetScript('OnEditFocusGained', function(self)
    private.ClearBuffers()
    editBox:SetScript('OnUpdate', private.HandleDataInput)
  end) 
  editBox:SetScript('OnEditFocusLost', function(self) editBox:SetScript('OnUpdate', nil) end)
  editBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
  f.editBox = editBox

  f:SetScript("OnShow", function (self)
    self.editBox:SetFocus()
  end)
  f:SetScript("OnHide", function (self)
    private.ClearBuffers()
  end)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.HandleDataInput()
  if not private.inputBlocked then
    if #private.importBuffer > 0 then
      private.inputBlocked = true
      private.frame.editBox:SetScript('OnUpdate', nil)
      private.frame.editBox:SetText(L["Validating pasted data, please wait..."])
      private.frame.editBox:ClearFocus()
      Coroutine:RunAsync(private.AsyncParseData)
    end
  end
end

function private.AsyncParseData()
  local importString = strtrim(table.concat(private.importBuffer))
  local popupComments = DistributionTracker.ParseLootPopupComments(importString)
  local numComments = Common:KeysCount(popupComments)
  if numComments == 0 then
    private.frame.editBox:SetText("|cFFFF0000"..L["Warning! No valid comments found!"])
  else
    private.parsedData = popupComments
    private.frame.button1:Enable()
    private.frame.editBox:SetText("|cFF00FF00"..L["Comments found: %d"]:format(numComments).."|r".."\n\n"..
                                 L["Pressing 'Import' will overwrite existing comments list."])
  end
  
  private.inputBlocked = false
end

function private.ClearBuffers()
  table.wipe(private.importBuffer)
  private.parsedData = nil
  private.frame.editBox:SetText("")
  private.frame.button1:Disable()
end