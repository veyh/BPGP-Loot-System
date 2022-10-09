local _, BPGP = ...

local Logger = BPGP.GetModule("Logger")

local LibDeformat = LibStub("LibDeformat-3.0")

local Common = BPGP.GetLibrary("Common")
local Encryption = BPGP.GetLibrary("Encryption")

local private = {
  guidFormat = "%s-%s-%d-%d-%s-%s", -- tableName, timestamp, kind, mode, origin, hash
  logFormat = "%s\31%d\31%s\31%s", -- guid, value, target, reason
}
  
function Logger.NewDBRecord(guid, tableName, kind, mode, origin, value, target, reason, timestamp, chainHash)
  if not guid then
    -- It's a new log record, here we need to thoroughly check the data
    assert(tableName and #tableName > 0, "invalid table name "..tostring(tableName))
    assert(kind and kind >= 1 and kind <= 5, "invalid record type "..tostring(kind))
    assert(mode and mode >= 1 and mode <= 3, "invalid record mode "..tostring(mode))
    assert(origin and #origin > 0, "invalid origin "..tostring(origin))
    assert(value, "invalid value "..tostring(value))
    assert(target and #target > 0 and #target <= 24, "invalid target "..tostring(target))
    assert(reason and #reason > 0, "invalid reason "..tostring(reason))
    if timestamp then assert(timestamp and #timestamp == 13, "invalid timestamp "..tostring(timestamp)) end
    if chainHash then assert(chainHash and #chainHash >= 12, "invalid chainHash "..tostring(chainHash)) end
    local timestamp = timestamp or Logger.GetFakeMillisecondTimestamp()
    local chainHash = chainHash or Logger.GetChainHash(tableName)
    local hash = Logger.GetRecordHash(tableName, timestamp, kind, mode, origin, value, target, reason, chainHash)
    guid = Logger.EncodeDBRecordGUID(tableName, timestamp, kind, mode, origin, hash)
    Logger.SetChainHash(tableName, origin, hash)
  end
  local dbRecord = {}
  table.insert(dbRecord, guid)
  table.insert(dbRecord, value)
  table.insert(dbRecord, target)
  table.insert(dbRecord, reason)
  return dbRecord
end

function Logger.SerializeDBRecord(dbRecord)
  return string.format(private.logFormat, unpack(dbRecord))
end

function Logger.DeserializeDBRecord(serializedDBRecord)
  return {LibDeformat(serializedDBRecord, private.logFormat)}
end

function Logger.EncodeDBRecordGUID(tableName, timestamp, kind, mode, origin, hash)
  return string.format(private.guidFormat, tableName, timestamp, kind, mode, origin, hash)
end

function Logger.DecodeDBRecordGUID(recordGUID)
  return LibDeformat(recordGUID, private.guidFormat)
end

function Logger.GetRecordHash(tableName, timestamp, kind, mode, origin, value, target, reason, chainHash)
  local hash, seed, valueSign = nil, string.sub(tostring(timestamp), -12), "+"
  if value < 0 then valueSign = "-" end
  hash = Encryption:RunXOR(seed, tableName..tostring(kind)..tostring(mode)..valueSign..tostring(math.abs(value)))
  hash = Encryption:RunXOR(hash, origin)
  hash = Encryption:RunXOR(hash, target)
  hash = Encryption:RunXOR(hash, Common:GetItemId(reason) or reason)
  hash = Encryption:RunXOR(hash, chainHash)
  return Encryption:EncodeBase64(hash)
end