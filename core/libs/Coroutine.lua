local _, BPGP = ...

local lib = {}
BPGP.RegisterLibrary("Coroutine", lib)

LibStub("AceTimer-3.0"):Embed(lib)

local assert, error, unpack = assert, error, unpack
local coroutine = coroutine

local function running_co_checked()
  local co = coroutine.running()
  assert(co, "Should not be called from the main thread")
  return co
end

local function runner(co, ...)
  local ok, err = coroutine.resume(co, ...)
  if not ok then
    error(err)
  end
end

function lib:Yield()
  return self:Sleep(0)
end

function lib:Sleep(t)
  local co = running_co_checked()
  lib:ScheduleTimer(runner, t, co)
  return coroutine.yield(co)
end

local function event_runner(co, event, ...)
  BPGP.UnregisterEvent(co, event)
  runner(co, ...)
end

function lib:WaitForEvent(event)
  local co = running_co_checked()
  BPGP.RegisterEvent(co, event, event_runner, co)
  return coroutine.yield(co)
end

function lib:RunAsync(fn, ...)
  local co = coroutine.create(fn)
  lib:ScheduleTimer(function(args) runner(args[1], unpack(args, 2)) end, 0, {co, ...})
end
