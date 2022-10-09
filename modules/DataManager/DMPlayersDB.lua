local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local assert, tostring, pairs, tinsert = assert, tostring, pairs, tinsert

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Storage = BPGP.GetLibrary("Storage")
local Common = BPGP.GetLibrary("Common")

local AnnounceSender = BPGP.GetModule("AnnounceSender")
local Logger = BPGP.GetModule("Logger")

local private = {
  active = {}, -- {PlayerName = bool} - Conatins all active private (guild members with readable BPGP data container)
  inactive = {}, -- {PlayerName = bool} - Conatins all inactive private (guild members without readable BPGP data container)
  id = {}, -- {PlayerName = PlayerId} - Contains only mains
  name = {}, -- {PlayerId = PlayerName} - Contains only mains
  main = {}, -- {PlayerName = MainName} - Contains only alts
  alts = {}, -- {MainName = {1 = AltName1 ... N = AltNameN}} - Contains only mains with alts
  bpgp = {}, -- {PlayerName = {1 = {BP, GP} ... N = {BP, GP}}} - Contains only mains
  alerts = {},
}
Debugger.Attach("PlayersDB", private)

----------------------------------------
-- Public interface
----------------------------------------

function DataManager.GetPlayersDB(tableName)
  return private[tableName]
end

function DataManager.IsActive(playerName)
  return private.active[playerName]
end

function DataManager.IsInactive(playerName)
  return private.inactive[playerName]
end

function DataManager.GetId(playerName)
  return private.id[playerName]
end

function DataManager.GetName(playerId)
  return private.name[playerId]
end

function DataManager.GetMain(altName)
  return private.main[altName]
end

function DataManager.GetNumAlts(mainName)
  local alts = private.alts[mainName]
  if alts then
    return #alts
  end
  return 0
end

function DataManager.GetAlt(mainName, i)
  return private.alts[mainName][i]
end

-- Returns the list of all known player characters, both main and alts
function DataManager.GetMemberCharacters(playerName)
  local charactersList, mainName, altNames = {}, DataManager.GetMain(playerName)
  if not mainName then
    mainName = playerName
  end
  tinsert(charactersList, mainName)
  if private.alts[mainName] then
    for i = 1, #private.alts[mainName] do
      tinsert(charactersList, private.alts[mainName][i])
    end
  end
  return charactersList
end

-- Checks if guild member is in raid with this character, his main or other alt
function DataManager.GuildMemberInRaid(playerName)
  local charactersList = DataManager.GetMemberCharacters(playerName)
  for i = 1, #charactersList do
    if DataManager.IsInRaid(charactersList[i]) then
      return charactersList[i]
    end
  end
  return nil
end

function DataManager.GetBPGP(playerName, tableId)
  local mainName = DataManager.GetMain(playerName)
  if mainName then
    playerName = mainName
  end
  local bpgp = {}
  if private.bpgp[playerName] then
    bpgp = private.bpgp[playerName][tableId or DataManager.GetUnlockedTableId()] or {}
  end
  return bpgp.bp or 0, (bpgp.gp or 0) + DataManager.GetBaseGP(tableId), mainName
end

function DataManager.GetRawBPGP(playerName)
  return private.bpgp[playerName]
end

function DataManager.GetNewIds(numIds, playerName)
  local ids = {}
  for i = 1, 3067 do
    if not private.name[i] then
      private.name[i] = playerName or "Reserved_"..tostring(i)
      tinsert(ids, i)
    end
    if #ids == numIds then
      return ids
    end
  end
end

function DataManager.GetNewId(playerName)
  return DataManager.GetNewIds(1, playerName)[1]
end

function DataManager.UpdatePlayersDB(pending)
  for playerName in pairs(pending.updated) do
    DataManager.UpdatePlayer(playerName)
  end
  for playerName in pairs(pending.removed) do
    DataManager.RemovePlayer(playerName)
  end
  for playerName, alert in pairs(private.alerts) do
    DataManager.NewAlert(playerName, alert)
  end
end

function DataManager.UpdatePlayer(playerName)
  local data = DataManager.GetNote(playerName)
  Debugger("Updating player %s %s", tostring(playerName), tostring(data))

  local playerId, bpgp = DataManager.DecodeMainData(playerName, data)
  
  if playerId and bpgp then
    -- Found primary record, handling main data update
    if private.main[playerName] then
      DataManager.RemovePlayer(playerName) -- Unregister if player was an alt
    end
    private.id[playerName] = playerId
    private.name[playerId] = playerName
    private.bpgp[playerName] = bpgp
    private.active[playerName] = true
    private.inactive[playerName] = nil
    DataManager.UpdateAlts(playerName)
  else
    local mainName = DataManager.DecodeAltData(data)
    if mainName then
      -- Found ID of main, handling alt data update
      local currentMainName = private.main[playerName]
      local mainChanged = currentMainName and currentMainName ~= mainName
      if not currentMainName or mainChanged then
        if mainChanged then
          DataManager.RemoveAlt(playerName, currentMainName) -- Unregistering alt from old main
        end
        if private.id[playerName] then
          DataManager.RemovePlayer(playerName) -- Unregister if player was a main
        end
        -- Registering alt
        private.main[playerName] = mainName
        if not private.alts[mainName] then
          private.alts[mainName] = {}
        end
        tinsert(private.alts[mainName], playerName)
        private.active[playerName] = true
        private.inactive[playerName] = nil
      end
    else
      -- Player is not alt or main, handling unknown data update
      DataManager.RemovePlayer(playerName)
      private.inactive[playerName] = true
    end
  end
  
  -- Wrong alt data may cause numerous issues, we must ensure its integrity
  private.alerts[playerName] = nil
  local mainName = private.main[playerName]
  if mainName then
    if not DataManager.IsInGuild(mainName) then
      private.alerts[playerName] = L["Main %s is below level %d or not in guild!"]:format(mainName, DataManager.GetMinimalLevel())
    elseif DataManager.GetMain(mainName) then
      private.alerts[playerName] = L["Main %s is also an alt!"]:format(mainName)
    elseif DataManager.IsAltRankIndex(DataManager.GetRankIndex(mainName)) then
      private.alerts[playerName] = L["Main %s has alt-marked rank <%s> in options!"]:format(mainName, DataManager.GetRank(mainName))
    elseif not DataManager.IsAltRankIndex(DataManager.GetRankIndex(playerName)) then
      private.alerts[playerName] = L["Rank <%s> isn't marked as alt rank in options!"]:format(DataManager.GetRank(playerName))
    end
  elseif DataManager.IsAltRankIndex(DataManager.GetRankIndex(playerName)) then
    if private.id[playerName] then
      private.alerts[playerName] = L["Alt-ranked character can't store BP/GP! Please decrease his BP/GP to minimal values and use 'Assign Main'."]
    else
      private.alerts[playerName] = L["Alt-ranked character must have an assigned main!"]
    end
  end
end

function DataManager.UpdateAlts(playerName)
  local alts = private.alts[playerName]
  if alts then
    for i = 1, #alts do
      DataManager.UpdatePlayer(alts[i])
    end
  end
end

function DataManager.RemovePlayer(playerName)
  if private.main[playerName] then
    -- Found link to main, unregistering alt
    DataManager.RemoveAlt(playerName, private.main[playerName])
    private.main[playerName] = nil
  else
    -- Unregistering main
    local playerId = private.id[playerName]
    if playerId then
      private.id[playerName] = nil
      private.name[playerId] = nil
    end
    private.bpgp[playerName] = nil
  end
  private.active[playerName] = nil
  private.inactive[playerName] = nil
  private.alerts[playerName] = nil
  DataManager.UpdateAlts(playerName)
end

function DataManager.RemoveAlt(playerName, mainName)
  for i, altName in ipairs(private.alts[mainName]) do
    if altName == playerName then
      table.remove(private.alts[mainName], i)
      break
    end
  end
end

function DataManager.BankItem(item, target, mode)
  Logger.LogBankItem(mode, target, 0, item)
end

function DataManager.FreeItem(item, target, mode)
  Logger.LogFreeItem(mode, target, 0, item)
end

----------------------------------------
-- BP/GP shift operations
----------------------------------------

function DataManager.IncBP(playerName, bpReason, bpInc, logMode)
  DataManager.IncBPGP(playerName, bpInc, nil, bpReason, nil, logMode)
end

function DataManager.IncGP(playerName, gpReason, gpInc, logMode)
  DataManager.IncBPGP(playerName, nil, gpInc, nil, gpReason, logMode)
end

function DataManager.IncBPGP(playerName, bpInc, gpInc, bpReason, gpReason, logMode)
  assert(bpInc or gpInc, "BP/GP shift failed: no data provided!")
  assert(DataManager.IsAllowedDataWrite(), "BP/GP shift failed: data write is forbidden")
  if bpInc then
    assert(DataManager.IsValidReason(bpReason), "BP shift failed: invalid reason "..tostring(bpReason))
    assert(DataManager.IsValidIncrement(bpInc), "BP shift failed: invalid BP value "..tostring(bpInc))
  end
  if gpInc then
    assert(DataManager.IsValidReason(gpReason), "GP shift failed: invalid reason "..tostring(gpReason))
    assert(DataManager.IsValidIncrement(gpInc), "GP shift failed: invalid GP value "..tostring(gpInc))
  end
  assert(type(playerName) == "string", "BP/GP shift failed: got "..type(playerName).." as player name, string expected")
  
  local mainName = DataManager.GetMain(playerName)
  if mainName then
    playerName = mainName
  end

  DataManager.IncPlayerBPGP(playerName, bpInc, gpInc, bpReason, gpReason, false, logMode)
end

function DataManager.MultiBatchIncBPGP(bpBatches, gpBatches)
  assert(bpBatches or gpBatches, "Multi-batch BP/GP shift failed: no data provided!")
  assert(DataManager.IsAllowedDataWrite(), "Multi-batch BP/GP shift failed: data write is forbidden!")
  for i = 1, Common:KeysCount(bpBatches or gpBatches) do
    DataManager.WriteUnlock() -- We already ensured unlocked state, so we can write multiple batches safely
    local bpBatch, gpBatch = nil, nil
    if bpBatches and Common:KeysCount(bpBatches[i]) > 0 then bpBatch = bpBatches[i] end
    if gpBatches and Common:KeysCount(gpBatches[i]) > 0 then gpBatch = gpBatches[i] end
    if bpBatch or gpBatch then
      DataManager.BatchIncBPGP(bpBatch, gpBatch)
    end
  end
end

function DataManager.BatchIncBPGP(bpBatch, gpBatch, isLockChecked)
  if Common:KeysCount(bpBatch) == 0 then bpBatch = nil end
  if Common:KeysCount(gpBatch) == 0 then gpBatch = nil end
  assert(bpBatch or gpBatch, "Batch BP/GP shift failed: no data provided!")
  if not isLockChecked then -- Must be True only for consequent batch writes and only from the second and following
    assert(DataManager.IsAllowedDataWrite(), "Batch BP/GP shift failed: data write is forbidden!")
  end
  if bpBatch then DataManager.AssertBPBatch(bpBatch) end
  if gpBatch then DataManager.AssertGPBatch(gpBatch) end
  if bpBatch and gpBatch then DataManager.AssertEqualBatchKeys(bpBatch, gpBatch) end
  
  local bpReason, gpReason = nil, nil
  if bpBatch then bpReason = bpBatch.reason end
  if gpBatch then gpReason = gpBatch.reason end
  
  local memberList = {}
  
  for playerName in pairs(bpBatch or gpBatch) do
    local bpInc, gpInc = nil, nil
    if bpBatch then bpInc = bpBatch[playerName] end
    if gpBatch then gpInc = gpBatch[playerName] - DataManager.GetBaseGP() end
    
    local mainName = DataManager.GetMain(playerName)
    if mainName then
      playerName = mainName
    end
    
    if not memberList[playerName] then
      DataManager.IncPlayerBPGP(playerName, bpInc, gpInc, bpReason, gpReason, true)
    else
      BPGP.Print("Ignoring BP/GP inc for "..tostring(playerName)..": member is already in the list!")
    end
    
    memberList[playerName] = bpInc or gpInc
  end
  
  if bpBatch then
    AnnounceSender.AnnounceEvent(bpBatch.event, memberList, bpBatch.reason, bpBatch.comment, bpBatch.medium)
  end
  if gpBatch then
    AnnounceSender.AnnounceEvent(gpBatch.event, memberList, gpBatch.reason, gpBatch.comment, gpBatch.medium)
  end
end

function DataManager.IncPlayerBPGP(playerName, bpInc, gpInc, bpReason, gpReason, isBatchWrite, logMode)
  if not DataManager.IsInGuild(playerName) then
    BPGP.Print(L["Ignoring BP/GP edit attempt: no guild member '%s' found."]:format(playerName))
    return
  end
  assert(DataManager.GetLockState() > 0, "Failed to write BP/GP: all tables are locked!")
  local bpOld, gpOld, mainName = DataManager.GetBPGP(playerName)
  assert(mainName == nil, "Failed to write BP/GP: "..tostring(playerName).." is "..tostring(mainName).."'s alt!")
  if bpReason then BPGP.GetModule("GUI").db.profile.cache.lastAwards[bpReason] = bpInc end
  gpOld = gpOld - DataManager.GetBaseGP() -- We need to deduct Base GP before increments checking  
  bpInc = DataManager.GetPossibleBPGPInc(bpOld, (bpInc or 0))
  gpInc = DataManager.GetPossibleBPGPInc(gpOld, (gpInc or 0))
  local bpNew = bpOld + bpInc
  local gpNew = gpOld + gpInc
  if not DataManager.WideTablesEnabled() and (bpNew > 2500 or gpNew > 2500) then
    BPGP.Print(L["Please enable Wide Tables mode before %s's BP or GP hit 3067 limit."]:format(playerName))
  end
--  Debugger("IncBPGP %s: bp %s -> %s, gp %s -> %s", playerName, bpOld, bpNew, gpOld, gpNew)
  if bpNew == bpOld and gpNew == gpOld then
    if gpReason then
      Logger.LogCreditGP(logMode, playerName, gpInc, gpReason, isBatchWrite) -- 0 GP credit is allowed
    end
    return -- Note MUST be changed to trigger the update event, so we just log it and exit here
  end
  DataManager.SetNote(playerName, DataManager.EncodeMainData(playerName, bpNew, gpNew, DataManager.GetLockState(), DataManager.GetNumTables(), DataManager.WideTablesEnabled()), isBatchWrite)
  if bpReason then
    Logger.LogAwardBP(logMode, playerName, bpInc, bpReason, isBatchWrite)
  end
  if gpReason then
    Logger.LogCreditGP(logMode, playerName, gpInc, gpReason, isBatchWrite)
  end
end

function DataManager.GetPossibleBPGPInc(currentValue, incrementValue)
  if not incrementValue then
    incrementValue = 0
  end
  if (currentValue + incrementValue) < 0 then
    return -currentValue
  end
  if (currentValue + incrementValue) > 3067 then
    if DataManager.WideTablesEnabled() then
      if (currentValue + incrementValue) > 9412623 then
        BPGP.Print(L["Wide Tables can handle up to 9412623 BP/GP. I really wonder why someone would need more, you know!"])
        return 9412623 - currentValue -- Wide tables support max 9412623 BP/GP (3067*3068+1*3068-1)
      end
    else
      BPGP.Print(L["Fast Tables can handle up to 3067 BP/GP. Please enable Wide Tables mode if you need more (over 9 000 000)."])
      return 3067 - currentValue -- Fast tables support max 3067 BP/GP (1*3068-1)
    end
  end
  return incrementValue
end

----------------------------------------
-- Data encoding / decoding
----------------------------------------

function DataManager.EncodeAltData(mainName)
  return string.format("@%s", mainName)
end

function DataManager.DecodeAltData(altData)
  if not altData or #altData == 0 then return end
  return string.match(altData, "^@([^%s]+)$")
end

function DataManager.EncodeMainData(mainName, bp, gp, tableId, numTables, wideTables)
  local mainId, mainData = private.id[mainName], {}
  local bpgpData = private.bpgp[mainName]
  if not bpgpData then
    mainId, bpgpData = DataManager.GetNewBPGP(mainName)
  end
  tinsert(mainData, mainId)
  for i = 1, numTables do
    local bpgp = bpgpData[i] or {bp = 0, gp = 0}
    if tableId > 0 and i == tableId and bp and gp then
      bpgp = {bp = math.max(bp, 0), gp = math.max(gp, 0)}
    end
    if wideTables then
      tinsert(mainData, math.floor(bpgp.bp / 3068))
      tinsert(mainData, bpgp.bp % 3068)
      tinsert(mainData, math.floor(bpgp.gp / 3068))
      tinsert(mainData, bpgp.gp % 3068)
    else
      if bpgp.bp > 3067 then bpgp.bp = 3067 end
      if bpgp.gp > 3067 then bpgp.gp = 3067 end
      tinsert(mainData, bpgp.bp)
      tinsert(mainData, bpgp.gp)
    end
  end
  return Storage:Encode(DataManager.GetSystemState(), mainName, mainData)
end

function DataManager.DecodeMainData(mainName, encodedData, decodedData)
  if encodedData then
    decodedData = Storage:Decode(DataManager.GetSystemState(), mainName, encodedData)
  end
  if not decodedData then return end
  local bpgp = {}
  if DataManager.WideTablesEnabled() then
    for i = 1, DataManager.GetNumTables() do
      local bp = decodedData[i * 4 - 2] * 3068 + decodedData[i * 4 - 1]
      local gp = decodedData[i * 4] * 3068 + decodedData[i * 4 + 1]
      bpgp[i] = {bp = bp, gp = gp}
    end
  else
    for i = 1, DataManager.GetNumTables() do
      bpgp[i] = {bp = decodedData[i * 2], gp = decodedData[i * 2 + 1]}
    end
  end
  return decodedData[1], bpgp
end

function DataManager.GetNewBPGP(playerName)
  return DataManager.DecodeMainData(nil, nil, {DataManager.GetNewId(playerName),0,0,0,0,0,0,0,0,0,0,0,0})
end
