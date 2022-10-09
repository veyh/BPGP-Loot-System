local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local private = {}

function DataManager.NewBatch(reason, event, comment, medium)
  local mt = {
    __index = {
      reason = reason,
      event = event,
      comment = comment,
      medium = medium,
    }
  }
  return setmetatable({}, mt)
end

function DataManager.AssertBPBatch(batch)
    local filter = {["RaidAwardedBP"] = true, ["SysResetBP"] = true, ["SysRescaleBP"] = true, ["SysDecayBP"] = true}
    assert(filter[batch.event], "Bad BP batch: invalid event "..tostring(batch.event))
    assert(DataManager.IsValidReason(batch.reason), "Bad BP batch: invalid reason "..tostring(batch.reason))
    assert(type(batch) == "table", "Bad BP batch: got "..type(batch).." instead of table")
    for playerName, bpInc in pairs(batch) do
      assert(DataManager.IsValidIncrement(bpInc), "Bad BP batch: invalid BP "..tostring(bpInc).." for "..tostring(playerName))
    end
end

function DataManager.AssertGPBatch(batch)
    local filter = {["RaidAwardedGP"] = true, ["SysResetGP"] = true, ["SysRescaleGP"] = true, ["SysDecayGP"] = true}
    assert(filter[batch.event], "Bad GP batch: invalid event "..tostring(batch.event))
    assert(DataManager.IsValidReason(batch.reason), "Bad GP batch: invalid reason "..tostring(batch.reason))
    assert(type(batch) == "table", "Bad GP batch: got "..type(batch).." instead of table")
    for playerName, gpInc in pairs(batch) do
      assert(DataManager.IsValidIncrement(gpInc), "Bad GP batch: invalid GP "..tostring(gpInc).." for "..tostring(playerName))
    end
end

function DataManager.AssertEqualBatchKeys(bpBatch, gpBatch)
  assert(Common:KeysCount(bpBatch) == Common:KeysCount(gpBatch), "Bad BP or GP batch: size is not equal!")
  for playerName in pairs(bpBatch) do
    assert(gpBatch[playerName], "Bad BP or GP batch: keys are not equal!")
  end
end

function DataManager.FillResetBatches(bpBatch, gpBatch)
  for playerName in pairs(DataManager.GetPlayersDB("active")) do
    local bp, gp, mainName = DataManager.GetBPGP(playerName)
    if not mainName then
      if bpBatch then bpBatch[playerName] = -bp end
      if gpBatch then gpBatch[playerName] = -gp end
    end
  end
end

function DataManager.FillRescaleBatches(bpBatch, gpBatch, rescaleFactor)
  for playerName in pairs(DataManager.GetPlayersDB("active")) do
    local bp, gp, mainName = DataManager.GetBPGP(playerName)
    if not mainName then
      if bpBatch then
        bpBatch[playerName] = math.ceil(bp * rescaleFactor - bp)
      end
      if gpBatch then
        gpBatch[playerName] = math.ceil(gp * rescaleFactor - gp) + DataManager.GetBaseGP()
      end
    end
  end
  return bpBatch, gpBatch
end