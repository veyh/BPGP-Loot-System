local _, BPGP = ...

local Logger = BPGP.GetModule("Logger")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")

local private = {
  bufferedLogs = Logger.GetBufferedLogs(),
  
  logDataUpdated = false,
  filterConditionsUpdated = false,
  searchConditionsUpdated = false,
  
  filterApplied = true,
  searchApplied = true,
  
  searchKeywords = {},
  
  filteredLog = {},
  searchedLog = {},
  
  logFilterIndex = {},
}


function Logger.GetTableNames()
  local tableNames = {}
  for tableName in pairs(private.logFilterIndex) do
    table.insert(tableNames, tableName)
  end
  table.sort(tableNames)
  return tableNames
end

function Logger.SetFilterRecordKind(recordKind, value)
  Logger.db.profile.filterRecordKinds[recordKind] = value
  private.filterConditionsUpdated = true
end

function Logger.GetFilterRecordKind(recordKind)
  return Logger.db.profile.filterRecordKinds[recordKind]
end

function Logger.SetFilterTable(filterTable)
  Logger.db.profile.filterTable = filterTable
  private.filterConditionsUpdated = true
end

function Logger.GetFilterTable()
  return Logger.db.profile.filterTable
end

function Logger.SetSearchKeywords(keywords)
  table.wipe(private.searchKeywords)
  keywords = strtrim(keywords)
  if keywords ~= "" then
    local rawKeywords = {strsplit(",", keywords)}
    for i = 1, #rawKeywords do
      local keyword = strtrim(rawKeywords[i])
      if #keyword > 0 then
        local itemId = Common:GetItemId(keyword)
        if itemId then
          table.insert(private.searchKeywords, itemId)
        else
          table.insert(private.searchKeywords, keyword:upper())
        end
      end
    end
  end
  private.searchConditionsUpdated = true
end

function Logger.ResetFilters()
  if private.logFilterIndex[DataManager.GetUnlockedTableName()] then
    Logger.db.profile.filterTable = DataManager.GetUnlockedTableName()
  else
    Logger.db.profile.filterTable = L["All"]
  end
  for recordKind in pairs(Logger.db.profile.filterRecordKinds) do
    Logger.db.profile.filterRecordKinds[recordKind] = true
  end
  Logger.RefreshFilteredLog()
  Logger.SetSearchKeywords("")
end

function Logger.GetNumRecords()
  if #private.searchKeywords > 0 then
    return #private.searchedLog
  else
    return #private.filteredLog
  end
end

function Logger.GetLogRecord(i)
  if #private.searchKeywords > 0 then
    return private.filteredLog[private.searchedLog[#private.searchedLog - i]]
  else
    return private.filteredLog[#private.filteredLog - i]
  end
end

function Logger.UpdateModel()
  Logger.RefreshFilterIndex()
  if private.logDataUpdated then
    private.logDataUpdated = false
    Logger.RefreshFilteredLog()
    Logger.RefreshSearchResults()
    return true
  elseif private.filterConditionsUpdated then
    private.filterConditionsUpdated = false
    Logger.RefreshFilteredLog()
    Logger.RefreshSearchResults()
    return true
  elseif private.searchConditionsUpdated then
    private.searchConditionsUpdated = false
    Logger.RefreshSearchResults()
    return true
  end
  return false
end

function Logger.RefreshFilterIndex()
  local newRecordsPosIndex = Logger.UpdateBufferedLogs()
  if not newRecordsPosIndex then return end
  if Common:KeysCount(newRecordsPosIndex) > 0 then
    for tableName, posIndex in pairs(newRecordsPosIndex) do
      if not private.logFilterIndex[tableName] then
        private.logFilterIndex[tableName] = {}
      elseif posIndex == 1 then
        table.wipe(private.logFilterIndex[tableName])
      end
      for recordKind in pairs(Logger.db.profile.filterRecordKinds) do
        if not private.logFilterIndex[tableName][recordKind] then
          private.logFilterIndex[tableName][recordKind] = {}
        end
      end
    end
    for tableName, posIndex in pairs(newRecordsPosIndex) do
      for i = posIndex, #private.bufferedLogs[tableName] do
        local record = private.bufferedLogs[tableName][i]
        table.insert(private.logFilterIndex[tableName][record.kind], i)
      end
    end
    private.logDataUpdated = true
  end
end

function Logger.LogFiltersApplied()
  return private.filterApplied or private.searchApplied
end

function Logger.RefreshFilteredLog()
  table.wipe(private.filteredLog)
  private.filterApplied = false
  for tableName, logFilterIndex in pairs(private.logFilterIndex) do
    if tableName == Logger.db.profile.filterTable or Logger.db.profile.filterTable == L["All"] then
      for recordKind, logIndex in pairs(logFilterIndex) do
        if Logger.db.profile.filterRecordKinds[recordKind] then
          for i = 1, #logIndex do
            table.insert(private.filteredLog, private.bufferedLogs[tableName][logIndex[i]])
          end
        end
      end
    end
  end
  table.sort(private.filteredLog, function(a,b) return a.timestamp < b.timestamp end)
  -- Marking Undone records for highlighting 
  local numUndoneRecords = 0
  for i = #private.filteredLog, 1, -1 do
    local record = private.filteredLog[i]
    if record.mode == 2 then -- This is "Undo" type record. Previous "Normal" or "Redo" type record should be greyed out.
      numUndoneRecords = numUndoneRecords + 1 -- We got 1 more "Undo" to use.
      record.stale = true
    elseif numUndoneRecords > 0 then
      if record.mode == 1 then -- This is "Normal" type record. It will be greyed out if "unused" Undo present. 
        numUndoneRecords = numUndoneRecords - 1 -- We used 1 "Undo".
        record.stale = true
      elseif record.mode == 3 then -- This is "Redo" type record. It will be greyed out if "unused" Undo present. 
        numUndoneRecords = numUndoneRecords - 1 -- We used 1 "Undo".
        record.stale = true
      end
    end
  end
  
  if Logger.db.profile.filterTable == L["All"] then
    private.filterApplied = true
  else
    for recordKind, show in pairs(Logger.db.profile.filterRecordKinds) do
      if not show then private.filterApplied = true end
    end
  end
end

function Logger.RefreshSearchResults()
  private.searchApplied = false
  table.wipe(private.searchedLog)
  local keywords = private.searchKeywords
  if #keywords > 0 then
    for i = 1, #private.filteredLog do
      for k = 1, #keywords do
        if string.find(private.filteredLog[i].plainTextUpper, keywords[k], 1, true) then
          table.insert(private.searchedLog, i)
          break
        end
      end
    end
    private.searchApplied = #private.searchedLog ~= #private.filteredLog
  end
end