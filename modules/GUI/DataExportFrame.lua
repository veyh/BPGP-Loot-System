local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Coroutine = BPGP.GetLibrary("Coroutine")

local Logger = BPGP.GetModule("Logger")

local private = {
  frame = nil,
  bufferedLog = "",
  exportedLog = "",
}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPDataExportFrame()
	local f = GUI.CreateCustomFrame("BPGPDataExportFrame", UIParent, "DefaultBackdrop")
  f:Hide()
  f:SetFrameStrata("TOOLTIP")
  f:SetPoint("CENTER")
  f:SetHeight(120)
  f:SetWidth(500)
  f:SetToplevel(true)
  private.frame = f

  local help = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  help:SetPoint("TOP", f, "TOP", 0, -20)
  help:SetWidth(f:GetWidth() - 40)
  f.help = help

  local button1 = CreateFrame("Button", nil, f, "StaticPopupButtonTemplate")
  button1:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
  button1:SetPoint("CENTER")
  button1:SetText(CLOSE)
  button1:SetScript("OnClick", function (self) self:GetParent():Hide() end)
  f.button1 = button1

  local editBox = CreateFrame("EditBox", nil, f)
  editBox:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
  editBox:SetPoint("TOPRIGHT", help, "BOTTOMRIGHT", 0, 0)
  editBox:SetPoint("BOTTOM", button1, "TOP", 0, 10)
  editBox:SetWidth(425)
  editBox:EnableMouse(true)
  editBox:SetAutoFocus(false)
  editBox:SetMultiLine(false)
  editBox:SetJustifyH("CENTER")
  editBox:SetFontObject(GameFontHighlight)
  editBox:SetScript("OnTextChanged", function (self)
    if self:GetText() ~= private.bufferedLog then
      BPGP.Print(L["Please don't try to alter the exported data, any change will make it unreadable!"])
      self:SetText(private.bufferedLog)
    end
  end)
  editBox:SetScript("OnEscapePressed", function (self) self:ClearFocus() end)
  f.editBox = editBox

  f:SetScript("OnShow", function (self)
    self.help:SetText(L["Log records from '%s' table(s) have been exported."]:format(Logger.GetFilterTable()).."\n"..
                 L["You may use the text below as log backup or share it with your guildies!"])
    self.editBox:HighlightText()
    self.editBox:SetText(L["Exporting data, please wait..."])
    private.bufferedLog = f.editBox:GetText()
    Coroutine:RunAsync(private.AsyncExportData)
  end)
  f:SetScript("OnHide", function (self)
    private.ClearBuffers()
  end)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.ClearBuffers()
  private.exportedLog = ""
  private.bufferedLog = ""
  private.frame.editBox:SetText("")
end

function private.AsyncExportData()
  private.exportedLog = Logger.Export()
  private.bufferedLog = private.exportedLog
  private.frame.editBox:SetText(private.exportedLog)
  private.frame.editBox:HighlightText()
  private.frame.editBox:SetFocus()
end

