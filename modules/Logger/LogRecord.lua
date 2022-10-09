local _, BPGP = ...

local Logger = BPGP.GetModule("Logger")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("BPGP")
local LibDeformat = LibStub("LibDeformat-3.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local private = {
  modePrefix = {"", L["Undo"].." ", L["Redo"].." "},
}

function Logger.NewLogRecord(tableName, timestamp, kind, mode, origin, hash, value, target, reason)
  local logRecord = {}
  logRecord.tableName = tableName
  logRecord.timestamp = timestamp
  logRecord.kind = kind
  logRecord.mode = mode
  logRecord.origin = origin
  logRecord.hash = hash
  logRecord.value = value
  logRecord.target = target
  logRecord.reason = reason
  
  logRecord.plainText = Logger.MakePlainTextLogRecord(tableName, timestamp, kind, mode, origin, value, target, reason)
  logRecord.plainTextUpper = logRecord.plainText:upper()
  
  return logRecord
end

function Logger.MakePlainTextLogRecord(tableName, timestamp, kind, mode, origin, value, target, reason)
  local datetime = date("%Y-%m-%d %H:%M:%S", timestamp:sub(1, -4))
  reason = private.modePrefix[mode]..reason
  if kind == 1 then
    return string.format(L["[%s][%s][%s]: %+d BP to %s (%s)"], datetime, tableName, origin, value, target, reason)
  elseif kind == 2 then
    return string.format(L["[%s][%s][%s]: %+d GP to %s (%s)"], datetime, tableName, origin, value, target, reason)
  elseif kind == 3 then
    return string.format(L["[%s][%s][%s]: %s to %s (Free Item)"], datetime, tableName, origin, reason, target)
  elseif kind == 4 then
    return string.format(L["[%s][%s][%s]: %s to %s (Guild Bank)"], datetime, tableName, origin, reason, target)
  elseif kind == 5 then
    if reason == "LOCKED" then
      return string.format(L["[%s][%s][%s]: System is locked by %s"], datetime, tableName, origin, target)
    else
      return string.format(L["[%s][%s][%s]: Table %s is unlocked for %s"], datetime, tableName, origin, reason, target)
    end
  else
    return string.format(L["[%s][%s][%s]: Unknown log record {%d,%s,%s,%s}"], datetime, tableName, origin, kind, value, target, reason)
  end
end