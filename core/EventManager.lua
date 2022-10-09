local _, BPGP = ...

local assert, next, pairs, select, type, unpack, tonumber = assert, next, pairs, select, type, unpack, tonumber
local tinsert, wipe, strsplit = tinsert, wipe, strsplit
local CombatLogGetCurrentEventInfo, GetSpellInfo = CombatLogGetCurrentEventInfo, GetSpellInfo

local locked = false

local registeredCallbacks = {}
local callbacksCache = {}

local eventQueue = {}
local pushPointer = 0
local shiftPointer = 0

-- High-performance event queue for simultaneous events processing in FIFO order

-- Adds event to the end of the queue
local function PushEvent(...)
  pushPointer = pushPointer + 1
  local eventStackHandle = eventQueue[pushPointer]
  if not eventStackHandle then
    eventStackHandle = {}
    eventQueue[pushPointer] = eventStackHandle
  end
	for i = 1, select("#", ...) do
    eventStackHandle[i] = select(i, ...)
	end
end

-- Wipes unpacked table for recycle
local function WipeHandle(handle, ...)
  wipe(handle)
  return ...
end

-- Retrieves the event from the beginning of the queue, resets pointers on reaching the end
local function ShiftEvent()
  shiftPointer = shiftPointer + 1
  local eventStackHandle = eventQueue[shiftPointer]
  if shiftPointer == pushPointer then
    pushPointer = 0
    shiftPointer = 0
  end
  return WipeHandle(eventStackHandle, unpack(eventStackHandle))
end

-- Event handling

local function HandleEvent(event, ...)
  wipe(callbacksCache)
	local callbacks = registeredCallbacks[event]
	if callbacks then
    for callback in pairs(callbacks) do
      tinsert(callbacksCache, callback)
    end
		for i = 1, #callbacksCache do
			callbacksCache[i](event, ...)
		end
	end
end

local function OnEvent(_, event, ...)
  if locked then
    PushEvent(event, ...)
    return
  end
  locked = true
  HandleEvent(event, ...)
	while pushPointer > 0 do
		HandleEvent(ShiftEvent())
	end
  locked = false
end

local EventFrame = CreateFrame("Frame")
EventFrame:SetScript("OnEvent", OnEvent)

-- Core methods

local unitEventFrames = {}
local registeredUnitEvents = {}

local function RegisterUnitEvent(event, ...)
  registeredUnitEvents[event] = true
  for i = 1, select("#", ...) do
    local unit = select(i, ...)
    if not unit then break end
    assert(type(unit) == "string", "Invalid Unit Id!")
    local frame = unitEventFrames[unit]
    if not frame then
      frame = CreateFrame("Frame")
      frame:SetScript("OnEvent", OnEvent)
      unitEventFrames[unit] = frame
    end
    frame:RegisterUnitEvent(event, unit)
  end
end

local function UnregisterUnitEvent(event, ...)
  if registeredCallbacks[event] then return end
  registeredUnitEvents[event] = nil
  for i = 1, select("#", ...) do
    local unit = select(i, ...)
    if not unit then break end
    assert(type(unit) == "string", "Invalid Unit Id!")
    local frame = unitEventFrames[unit]
    if frame then
      frame:UnregisterEvent(event)
    end
  end
end

local registeredCLEUEvents = {}
local filteredCLEUEvents = {}
local unfilteredCLEUEvents = {}

local function RegisterCLEUEvent(event)
	local args = {strsplit(" ", event)}
  if #args > 1 then
    event = args[1]
    for i = 2, #args do
      local spellId = tonumber(args[i])
      assert(type(spellId) == "number", "Invalid Spell Id!")
      assert(select(7, GetSpellInfo(spellId)), "Invalid or stale Spell Id!")
      if not filteredCLEUEvents[event] then filteredCLEUEvents[event] = {} end
      filteredCLEUEvents[event][spellId] = (filteredCLEUEvents[event][spellId] or 0) + 1
    end
  else
    unfilteredCLEUEvents[event] = (unfilteredCLEUEvents[event] or 0) + 1
  end
  registeredCLEUEvents[event] = true
end

local function UnregisterCLEUEvent(event)
  local args = {strsplit(" ", event)}
  if #args > 1 then
    event = args[1]
    if not filteredCLEUEvents[event] then return end
    for i = 2, #args do
      local spellId = tonumber(args[i])
      assert(type(spellId) == "number", "Invalid Spell Id!")
      assert(select(7, GetSpellInfo(spellId)), "Invalid or stale Spell Id!")
      local regsCount = (filteredCLEUEvents[event][spellId] or 0) - 1
      if regsCount > 0 then
        filteredCLEUEvents[event][spellId] = regsCount
      else
        filteredCLEUEvents[event][spellId] = nil
      end
    end
    if not next(filteredCLEUEvents[event]) then
      filteredCLEUEvents[event] = nil
    end
  else
    local regsCount = (unfilteredCLEUEvents[event] or 0) - 1
    if regsCount > 0 then
      unfilteredCLEUEvents[event] = regsCount
    else
      unfilteredCLEUEvents[event] = nil
    end
  end
  if not filteredCLEUEvents[event] and not unfilteredCLEUEvents[event] then
    registeredCLEUEvents[event] = nil
  end
end

local function IsInternalCallbackEvent(event)
  return event:sub(0, 7) == "CUSTOM_"
end

local function IsCLEUEvent(event)
  return event:sub(0, 6) == "SPELL_" and event ~= "SPELL_NAME_UPDATE" or event:sub(0, 6) == "RANGE_" or event:sub(0, 6) == "SWING_" or event == "UNIT_DIED" or event == "UNIT_DESTROYED" or event == "PARTY_KILL"
end

local function IsUnitEvent(event)
  return event:sub(0, 5) == "UNIT_"
end

local function RegisterEvent(event, callback, ...)
  assert(type(event) == "string" and type(callback) == "function")
	if not registeredCallbacks[event] then registeredCallbacks[event] = {} end
  if registeredCallbacks[event][callback] then return end
  if IsInternalCallbackEvent(event) then
    -- Internal callback is basically fake event which uses the same queue as events, no extra processing required
  elseif IsCLEUEvent(event) then
    RegisterCLEUEvent(event)
  elseif IsUnitEvent(event) then
    if select("#", ...) > 0 then
      assert(not next(registeredCallbacks[event]), "BPGP Event Handler supports only 1 registration per filtered unit event!")
      -- Special registration for filtered unit event, we'll use separate frame for each unit specified
      RegisterUnitEvent(event, ...)
    else
      assert(not registeredUnitEvents[event], "BPGP Event Handler doesn't support mixed registrations for same unit event!")
      EventFrame:RegisterEvent(event)
    end
  else
    EventFrame:RegisterEvent(event)
  end
	registeredCallbacks[event][callback] = true
end

local function UnregisterEvent(event, callback, ...)
  assert(type(event) == "string" and type(callback) == "function")
	local callbacks = registeredCallbacks[event]
	if callbacks and callbacks[callback] then
		callbacks[callback] = nil
		if not next(callbacks) then
			registeredCallbacks[event] = nil
		end
    if IsInternalCallbackEvent(event) then
      -- Internal callback is basically fake event which uses the same queue as events, no extra processing required
    elseif IsCLEUEvent(event) then
      UnregisterCLEUEvent(event) -- CLEU registry clean-up
    elseif IsUnitEvent(event) then
      UnregisterUnitEvent(event, ...) -- Units registry clean-up
    elseif not registeredCallbacks[event] then
      EventFrame:UnregisterEvent(event) -- Unregister generic events
    end
	end
end

local function HandleCLEUEvent(...)
  local timestamp, event, hideCaster, guid, name, flags, raidFlags, destGUID, destName, destFlags, destRaidFlags, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 = CombatLogGetCurrentEventInfo()
  if not registeredCLEUEvents[event] then return end
  local prefix = event:sub(0, 6)
  if (prefix == "SPELL_" or prefix == "RANGE_") then
    if filteredCLEUEvents[event] and filteredCLEUEvents[event][arg1] then
      local filteredEvent = event .. " " .. tostring(arg1)
      OnEvent(nil, filteredEvent, guid, name, flags, raidFlags, destGUID, destName, destFlags, destRaidFlags, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
    end
  end
  if unfilteredCLEUEvents[event] then
    OnEvent(nil, event, guid, name, flags, raidFlags, destGUID, destName, destFlags, destRaidFlags, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
  end
end
RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", HandleCLEUEvent)

local function FireEvent(event, ...)
  OnEvent(nil, event, ...)
end

local function RegisterCallback(event, callback, ...)
  RegisterEvent("CUSTOM_"..event, callback, ...)
end

local function UnregisterCallback(event, callback, ...)
  UnregisterEvent("CUSTOM_"..event, callback, ...)
end

local function Fire(event, ...)
  FireEvent("CUSTOM_"..event, ...)
end

local function EmulateEvent(event, ...)
  for _, frame in pairs({GetFramesRegisteredForEvent(event)}) do
    local func = frame:GetScript('OnEvent')
    pcall(func, frame, event, ...)
  end
end

----------------------------------------
-- Public interface
----------------------------------------

local function Embed(target)
  target.RegisterEvent = RegisterEvent
  target.UnregisterEvent = UnregisterEvent
  target.FireEvent = FireEvent
  target.EmulateEvent = EmulateEvent
  target.RegisterCallback = RegisterCallback
  target.UnregisterCallback = UnregisterCallback
  target.Fire = Fire
end

Embed(BPGP)
