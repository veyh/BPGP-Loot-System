local _, BPGP = ...

local string, tconcat, debugstack, GetTime = string, table.concat, debugstack, GetTime
local tostring, select, unpack, pcall = tostring, select, unpack, pcall

local Debugger = {
  enabled = false,
  frame = nil,
  timeStart = GetTime(),
  locals = {},
}

----------------------------------------
-- Public interface
----------------------------------------

function Debugger.Enable()
  if Debugger.enabled then return end
  getmetatable(Debugger).__call = Debugger.PrintMessage
  Debugger.enabled = true
  Debugger("Debugger enabled")
end

function Debugger.Disable()
  if not Debugger.enabled then return end
  Debugger("Debugger disabled")
  getmetatable(Debugger).__call = Debugger.DropMessage
  Debugger.enabled = false
end

function Debugger.ToggleFrame()
  if Debugger.frame:IsShown() then
    Debugger.frame:Hide()
  else
    Debugger.frame:Show()
  end
end

function Debugger.Attach(k, v)
  Debugger.locals[k] = v
  if Debugger.enabled and ViragDevTool_AddData then
    ViragDevTool_AddData(v, k)
  end
end

function Debugger.Watch()
  if Debugger.enabled and ViragDevTool_AddData then
    for k, v in pairs(Debugger.locals) do
      ViragDevTool_AddData(v, k)
    end
  end
end

----------------------------------------
-- Internal methods
----------------------------------------

function Debugger.Initialize()
  setmetatable(Debugger, {})
  Debugger:CreateMainFrame()
  Debugger:Enable()
end

function Debugger.Embed(target)
  target.Debugger = Debugger
end

function Debugger.DropMessage() end

local toStringArgs = {}
function Debugger.ArgsToString(...)
  local numArgs = select("#", ...)
  for i = 1, numArgs do
    toStringArgs[i] = tostring(select(i, ...))
  end
  return unpack(toStringArgs, 1, numArgs)
end

-- Wrapper for string.format function with runtime errors handling and extra debug output on catch
function Debugger.SafeFormat(fmt, ...)
  local status, result = pcall(string.format, fmt, Debugger.ArgsToString(...))
  if status == false then
    local msg, fmt, args = tostring(result:match(".*: (.*)") or result), tostring(fmt), tconcat({Debugger.ArgsToString(...)}, ", ")
    result = string.format("Error: %s [format string: '%s' args: '%s']", msg, fmt, args)
  end
  return tostring(result)
end

function Debugger.PrintMessage(self, fmt, ...)
  local trace = debugstack(2, 1, 0)
  trace = trace:match("([^\\]-): in") or trace
  local prefix = Debugger.SafeFormat("[%06.3f][%s]: ", GetTime() - Debugger.timeStart, trace)
  local message = Debugger.SafeFormat(fmt, ...)
  Debugger.frame.msg:AddMessage(prefix .. message)
end

function Debugger.CreateMainFrame()
  local f = CreateFrame("Frame", "BPGPDebuggerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
  
  f:Hide()
  
  f:EnableMouse()
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:SetFrameStrata("TOOLTIP")
  
  f:SetPoint("CENTER", UIParent)
  f:SetWidth(800)
  f:SetHeight(600)

  f:SetResizable(true)
  BPGP.compat.SetResizeBounds(f, 300, 100)
  
  f:SetBackdrop(
    {
      bgFile = "Interface\\Tooltips\\ChatBubble-Background",
      edgeFile = "Interface\\Tooltips\\ChatBubble-BackDrop",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left=16, right=16, top=16, bottom=16 }
    })
  f:SetBackdropColor(0, 0, 0, 1)

  f.title = CreateFrame("Button", nil, f)
  f.title:SetNormalFontObject("GameFontNormal")
  f.title:SetText("Debugger")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
  f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
  f.title:SetHeight(8)
  f.title:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
  f.title:SetScript("OnMouseDown", function (self) self:GetParent():StartMoving() end)
  f.title:SetScript("OnMouseUp", function (self) self:GetParent():StopMovingOrSizing() end)

  f.sizer = CreateFrame("Button", nil, f)
  f.sizer:SetHeight(16)
  f.sizer:SetWidth(16)
  f.sizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
  f.sizer:SetScript("OnMouseDown", function (self) self:GetParent():StartSizing("BOTTOMRIGHT") end)
  f.sizer:SetScript("OnMouseUp", function (self) self:GetParent():StopMovingOrSizing() end)

  local line1 = f.sizer:CreateTexture(nil, "BACKGROUND")
  line1:SetWidth(14)
  line1:SetHeight(14)
  line1:SetPoint("BOTTOMRIGHT", -8, 8)
  line1:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local x = 0.1 * 14/17
  line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

  local line2 = f.sizer:CreateTexture(nil, "BACKGROUND")
  line2:SetWidth(8)
  line2:SetHeight(8)
  line2:SetPoint("BOTTOMRIGHT", -8, 8)
  line2:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local x = 0.1 * 8/17
  line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

  f.bottom = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.bottom:SetJustifyH("LEFT")
  f.bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
  f.bottom:SetPoint("BOTTOMRIGHT", f.sizer)
  f.bottom:SetHeight(8)
  f.bottom:SetText("Scroll: Mouse Wheel; Instant Scroll: Shift + Mouse Wheel; Move Window: click title; Resize Window: click bottom-right corner")

  f.msg = CreateFrame("ScrollingMessageFrame", nil, f)
  f.msg:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT")
  f.msg:SetPoint("TOPRIGHT", f.title, "BOTTOMRIGHT")
  f.msg:SetPoint("BOTTOM", f.bottom, "TOP", 0, 8)

  f.msg:SetMaxLines(10000)
  f.msg:SetFading(false)
  f.msg:SetFontObject(GameFontHighlightLeft)
  f.msg:EnableMouseWheel(true)
  
  local function Scroll(self, arg)
    if arg > 0 then
      if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
    elseif arg < 0 then
      if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
    end
  end
  f.msg:SetScript("OnMouseWheel", Scroll)
  
  Debugger.frame = f
end

Debugger.Initialize()
Debugger.Embed(BPGP)
