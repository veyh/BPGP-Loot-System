local _, BPGP = ...

local Logger = BPGP.NewModule("Logger")

local tonumber, select, tinsert = tonumber, select, table.insert

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("BPGP")
local LibDeformat = LibStub("LibDeformat-3.0")
local LibJSON = LibStub("LibJSON-1.0")
LibStub("AceComm-3.0"):Embed(Logger)

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local Encryption = BPGP.GetLibrary("Encryption")

local SystemManager = BPGP.GetModule("SystemManager")
local AnnounceSender = BPGP.GetModule("AnnounceSender")
local DataManager = BPGP.GetModule("DataManager")

local private = {
  dbDefaults = {
    profile = {
      enabled = true,
      filterTable = L["All"],
      filterRecordKinds = {
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
      },
      cache = {
        logs = {
          ['*'] = {},
        },
        tempLogs = {
          ['*'] = {},
        },
        redo = {},
      },
    },
  },
  bufferedLogs = {},
  chainHashes = {},
  bufferedLogsUpdated = false,
  fakeTimestampCounter = 0,
  kindAnnounceEvents = {"MemberAwardedBP", "MemberAwardedGP", "FreeItem", "BankedItem", "LockShift"},
  modePrefix = {"", L["Undo"].." ", L["Redo"].." "},
}
Debugger.Attach("Logger", private)

----------------------------------------
-- Core module methods
----------------------------------------

function Logger:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("Logger", private.dbDefaults)
  self.db.profile.enabled = true
end

function Logger:OnEnable()
  if SystemManager.db.profile.logSync then
    self:RegisterComm("BPGPLB", private.HandleLogBroadcast)
  end
  private.loggerDbUpdated = true
end

function Logger:OnDisable()
  self:UnregisterComm("BPGPLOG", private.HandleCorpseLootComm)
end

function Logger:Reload()
  self:Disable()
  self:Enable()
end

----------------------------------------
-- Event handlers
----------------------------------------

function private.HandleLogBroadcast(prefix, msg, distribution, sender)
  -- Broadcasts are supposed to be real-time from ML, therefore if sender is not active, something went wrong
  if prefix ~= "BPGPLB" or sender == UnitName("player") or not DataManager.IsActive(sender) then return end
  -- Drop if record is invalid
  local dbRecord = Logger.DeserializeDBRecord(msg)
  if not dbRecord then return end
  -- Drop if table is invalid
  local tableName, timestamp, kind, mode, origin, hash = Logger.DecodeDBRecordGUID(dbRecord[1])
  if not tableName then return end
  -- Drop if sender is not present in GUID 
  if sender ~= origin then return end
  -- All checks are passed, writing record to db
  Logger.WriteDBRecord(tableName, dbRecord)
end

----------------------------------------
-- Public interface
----------------------------------------

function Logger.LogAwardBP(mode, target, value, reason, isBatchWrite)
  Logger.AppendToLog(1, mode, target, value, reason, isBatchWrite)
end

function Logger.LogCreditGP(mode, target, value, reason, isBatchWrite)
  Logger.AppendToLog(2, mode, target, value, reason, isBatchWrite)
end

function Logger.LogFreeItem(mode, target, value, reason)
  Logger.AppendToLog(3, mode, target, value, reason)
end

function Logger.LogBankItem(mode, target, value, reason)
  Logger.AppendToLog(4, mode, target, value, reason)
end

function Logger.LogLockShift(playerName, tableName)
  Logger.AppendToLog(5, 1, playerName, 0, tableName)
end

function Logger.GetHeadHash()
  return "=0M6W7F1337h4$h="
end

function Logger.SetChainHash(tableName, origin, hash)
  if origin == DataManager.GetSelfName() then
    private.chainHashes[tableName] = hash
  end
end

function Logger.GetChainHash(tableName)
  return private.chainHashes[tableName] or Logger.GetHeadHash()
end

function Logger.ReadChainHashes()
  local playerName = DataManager.GetSelfName()
  for tableName, tableLog in pairs(Logger.db.profile.cache.logs) do
    for i = #tableLog, 1, -1 do
      local _, _, _, _, origin, hash = Logger.DecodeDBRecordGUID(tableLog[i][1])
      if origin == playerName then
        Debugger("Found chainhash %s %s", tableName, hash)
        private.chainHashes[tableName] = hash
        break
      end
    end
  end
end

function Logger.GetBufferedLogs()
  return private.bufferedLogs
end

function Logger.WipeTableLog(tableName)
  table.wipe(Logger.db.profile.cache.logs[tableName])
end
  
function Logger.WipeBufferedLog(tableName)
  if not private.bufferedLogs[tableName] then return end
  table.wipe(private.bufferedLogs[tableName])
end

function Logger.WipeClassicEraLogs()
  BPGP.Print(L["Starting Classic Era logs wipe..."])
  for tableName, tableLog in pairs(Logger.db.profile.cache.logs) do
    if tableName ~= "SYSTEM" then
      local newLog, firstTimestamp = {}, time{year=2021, month=6, day=2, hour=0}
      for i = 1, #tableLog do
        local timestamp = tonumber(select(2, Logger.DecodeDBRecordGUID(tableLog[i][1])):sub(1, -4))
        if timestamp > firstTimestamp then
          tinsert(newLog, tableLog[i])
        end
      end
      Logger.db.profile.cache.logs[tableName] = newLog
      Logger.WipeBufferedLog(tableName)
    end
  end
  private.loggerDbUpdated = true
  BPGP.Print(L["Classic Era logs wipe finished!"])
end

function Logger.AppendToLog(kind, mode, target, value, reason, isBatchWrite)
  local tableName, origin = DataManager.GetUnlockedTableName(), DataManager.GetSelfName()
  if not mode then
    mode = 1 -- No service mode code provided, it's normal record
    table.wipe(Logger.db.profile.cache.redo)
  end
  if kind == 5 then tableName = L["SYSTEM"] end
  
  local dbRecord = Logger.NewDBRecord(nil, tableName, kind, mode, origin, value, target, reason)
  Logger.WriteDBRecord(tableName, dbRecord)
  
  if not isBatchWrite then
    AnnounceSender.AnnounceEvent(private.kindAnnounceEvents[kind], target, private.modePrefix[mode]..reason, value)
  end
  Logger:SendCommMessage("BPGPLB", Logger.SerializeDBRecord(dbRecord), "GUILD", nil, "BULK")
end
  
function Logger.UpdateBufferedLogs()
  if not private.loggerDbUpdated then return end
  private.loggerDbUpdated = false
  
  local newRecordsPosIndex = {}
  for tableName, dbRecords in pairs(Logger.db.profile.cache.logs) do
    if not private.bufferedLogs[tableName] then private.bufferedLogs[tableName] = {} end
    -- See if there are any new db records and buffer them once found
    if #dbRecords > #private.bufferedLogs[tableName] then
      -- Here we remember positions from where the GUI model will start indexing
      local firstNewRecord = #private.bufferedLogs[tableName] + 1
      newRecordsPosIndex[tableName] = firstNewRecord
      -- Start buffering for given table log
      for i = firstNewRecord, #dbRecords do
        -- Creating log buffer record
        local dbRecord = dbRecords[i]
        local _, timestamp, kind, mode, origin, hash = Logger.DecodeDBRecordGUID(dbRecord[1])
        local record = Logger.NewLogRecord(tableName, timestamp, kind, mode, origin, hash, dbRecord[2], dbRecord[3], dbRecord[4])
        tinsert(private.bufferedLogs[tableName], record)
      end
    end
  end
  return newRecordsPosIndex
end
  
function Logger.WriteDBRecord(tableName, dbRecord)
  tinsert(Logger.db.profile.cache.logs[tableName], dbRecord)
  private.loggerDbUpdated = true
end

function Logger.UndoLastAction()
  local isAllowed, errorMsg = Logger.IsServiceActionAllowed(2)
  if not isAllowed then
    BPGP.Print(errorMsg)
    return
  end
  
  local tableName = DataManager.GetUnlockedTableName()

  local record, numActionsToIgnore = nil, 0
  if private.bufferedLogs[tableName] then
    for i = #private.bufferedLogs[tableName], 1, -1 do
      if private.bufferedLogs[tableName][i].mode == 2 then
        -- We want to ignore 1 previous non-undo action for each found undo record
        numActionsToIgnore = numActionsToIgnore + 1
      else
        if numActionsToIgnore > 0 then
          -- This action is already undone
          numActionsToIgnore = numActionsToIgnore - 1
        else
          -- Here we found an action we can undo
          record = private.bufferedLogs[tableName][i]
          break
        end
      end
    end
  end
  
  if not record then
    BPGP.Print(L["To Undo last action please do some action first!"])
    return
  end

  tinsert(Logger.db.profile.cache.redo, record)
  
  if record.kind == 1 then
    DataManager.IncBP(record.target, record.reason, -record.value, 2)
  elseif record.kind == 2 then
    DataManager.IncGP(record.target, record.reason, -record.value, 2)
  elseif record.kind == 3 then
    DataManager.FreeItem(record.reason, record.target, 2)
  elseif record.kind == 4 then
    DataManager.BankItem(record.reason, record.target, 2)
  end
end

function Logger.RedoLastUndo()
  local isAllowed, errorMsg = Logger.IsServiceActionAllowed(3)
  if not isAllowed then
    BPGP.Print(errorMsg)
    return
  end
  
  if #Logger.db.profile.cache.redo == 0 then
    BPGP.Print(L["To Redo last action please Undo some action first!"])
    return
  end

  local record = table.remove(Logger.db.profile.cache.redo)
  
  if record.kind == 1 then
    DataManager.IncBP(record.target, record.reason, record.value, 3)
  elseif record.kind == 2 then
    DataManager.IncGP(record.target, record.reason, record.value, 3)
  elseif record.kind == 3 then
    DataManager.FreeItem(record.reason, record.target, 3)
  elseif record.kind == 4 then
    DataManager.BankItem(record.reason, record.target, 3)
  end
end

function Logger.IsServiceActionAllowed(mode)
  local serviceAction = strtrim(private.modePrefix[mode])
  if not DataManager.IsAllowedDataWrite() then
    return false, string.format(L["To %s last action please unlock the table first!"], serviceAction)
  end
  if Logger.LogFiltersApplied() then
    return false, string.format(L["To %s last action please reset search filters first!"], serviceAction)
  end
  local tableName = DataManager.GetUnlockedTableName()
  if Logger.db.profile.filterTable ~= tableName then
    return false, string.format(L["To %s last action please select table %s first!"], serviceAction, tableName)
  end
  return true, nil
end

function Logger.TrimToOneMonth()
  if SystemManager.db.profile.logTrim then
    if DataManager.SelfCanWriteNotes() then
      SystemManager.db.profile.logTrim = false
      return
    end
  else
    return
  end
  for tableName, tableLog in pairs(Logger.db.profile.cache.logs) do
    if tableName ~= "SYSTEM" then
      local newLog, firstTimestamp = {}, Logger.GetTimestamp({ month = -1 })
      for i = 1, #tableLog do
        local timestamp = tonumber(select(2, Logger.DecodeDBRecordGUID(tableLog[i][1])):sub(1, -4))
        if timestamp > firstTimestamp then
          tinsert(newLog, tableLog[i])
        end
      end
      Logger.db.profile.cache.logs[tableName] = newLog
    end
  end
end

function Logger.GetTimestamp(diff)
  local t = GetServerTime()
  if diff then
    local years  = (diff.year  or 0)
    local months = (diff.month or 0) + years  * 12
    local days   = (diff.day   or 0) + months * 30
    local hours  = (diff.hour  or 0) + days   * 24
    local mins   = (diff.min   or 0) + hours  * 60
    local secs   = (diff.sec   or 0) + mins   * 60
    return t + secs
  end
  return t
end

-- Kind of fake ms timestamp cause we can't get nanosecond precision within 1 function call
-- 999 or less calls per second supposed and we can't have more then 999 players in guild anyway
function Logger.GetFakeMillisecondTimestamp()
  if private.fakeTimestampCounter == 1000 then
    private.fakeTimestampCounter = 0
  end
  private.fakeTimestampCounter = private.fakeTimestampCounter + 1
  return string.format("%d%03d", Logger.GetTimestamp(), private.fakeTimestampCounter)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.Swap(t, i, j)
  t[i], t[j] = t[j], t[i]
end

function private.Reverse(t)
  for i = 1, math.floor(#t / 2) do
    private.Swap(t, i, #t - i + 1)
  end
end
