local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local Logger = BPGP.GetModule("Logger")

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPOptionsFrame()
	local f = GUI.CreateCustomFrame("BPGPOptionsFrame", BPGPFrame, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  GUI.RegisterSideframe(f)
  
  f:Hide()
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -27)
  f:SetWidth(610)
  f:SetHeight(465)

  f:SetHeader(L["Options"])
  
  local frame = AceGUI:Create("BPGPOptionsFrame")
  frame:Hide()
  
  frame:ClearAllPoints()
  frame:SetPoint("LEFT", f, "LEFT")
  frame:SetPoint("RIGHT", f, "RIGHT")
  frame:SetPoint("TOP", f, "TOP")
  frame:SetPoint("BOTTOM", f, "BOTTOM")
  frame.frame:SetParent(f)
  frame.frame:SetScale(0.9)

  f:SetScript("OnShow", function (self)
    AceConfigDialog:Open("BPGPConfig", frame)
  end)

  f:SetScript("OnHide", function (self)
    AceConfigDialog:Close("BPGPConfig", frame)
    frame:Hide()
  end)
  
  f:SetScript("OnUpdate", function() 
    if not f.modelUpdated then return end
    f.modelUpdated = false
    f:Hide()
    f:Show()
  end)
  local function RegisterModelUpdate()
    f.modelUpdated = true
  end
  BPGP.RegisterCallback("OptionsUpdated", RegisterModelUpdate)
end

----------------------------------------
-- Custom Ace GUI 3.0 container widget
----------------------------------------

-- Original container type has poor integration support, so we will use our own

local methods = {
	["OnAcquire"] = function(self)
		self:Show()
	end,

	["OnRelease"] = function(self)
		self.status = nil
		wipe(self.localstatus)
	end,

	["Hide"] = function(self)
		self.frame:Hide()
	end,

	["Show"] = function(self)
		self.frame:Show()
	end,
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	--Container Support
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 10, -2)
	content:SetPoint("BOTTOMRIGHT", -10, 10)

	local widget = {
		localstatus = {},
		content     = content,
		frame       = frame,
		type        = "BPGPOptionsFrame"
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType("BPGPOptionsFrame", Constructor, 1)