local _, BPGP = ...

local AnnounceSender = BPGP.NewModule("AnnounceSender")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local SendChatMessage = _G.SendChatMessage
if ChatThrottleLib then
  SendChatMessage = function(...) ChatThrottleLib:SendChatMessage("ALERT", "BPGP", ...) end
end

----------------------------------------
-- Public interface
----------------------------------------

function AnnounceSender.AnnounceTo(medium, fmt, ...)
  if not medium then medium = BPGP.GetModule("MasterLooter").db.profile.announceMedium end

  local channel = GetChannelName(BPGP.GetModule("MasterLooter").db.profile.announceChannel or 0)
  -- Override raid and party if we are not grouped
  if medium == "RAID" and not UnitInRaid("player") then
    medium = "GUILD"
  end
  local msg = string.format(fmt, ...)
  local parts = {strsplit(" ", msg)}
  if string.find(msg, "|c") then
    -- We can't split item strings between messages, so we need to reconstruct them if found 
    local complexParts, itemString = {}, nil
    for _, s in pairs(parts) do
      if itemString then
        if string.find(s, "|r") then
          table.insert(complexParts, itemString.." "..s) -- Found end of item string, adding complex text part
          itemString = nil -- Stopping reconstruction
        else
          itemString = itemString.." "..s -- End of item string not found, reconstruction ongoing
        end
      else
        if string.find(s, "|c") then
          itemString = s -- Found start of item string, pending reconstruction
          if string.find(s, "|r") then
            table.insert(complexParts, itemString) -- Found end of item string whithin same part, adding complex text part
            itemString = nil -- Stopping reconstruction
          end
        else
          table.insert(complexParts, s) -- No pending reconstruction, adding plain-text part
        end
      end
    end
    parts = complexParts
  end
  local str = "BPGP:"
  for _, s in pairs(parts) do
    if #str + #s >= 250 then
      SendChatMessage(str, medium, nil, channel)
      str = "BPGP:"
    end
    str = str .. " " .. s
  end
  SendChatMessage(str, medium, nil, channel)
end

function AnnounceSender.Announce(fmt, ...)
  return AnnounceSender.AnnounceTo(BPGP.GetModule("MasterLooter").db.profile.announceMedium, fmt, ...)
end

function AnnounceSender.AnnounceEvent(event, ...)
  if Common:FindKey(BPGP.GetModule("MasterLooter").db.profile.announceEvents, event) and not BPGP.GetModule("MasterLooter").db.profile.announceEvents[event] then return end
  local tableName = BPGP.GetModule("DataManager").GetUnlockedTableName()
  if event == "MemberAwardedBP" then
    local name, reason, amount = ...
    AnnounceSender.Announce(L["%s: %+d BP (%s) to %s"], tableName, amount, reason, name)
  elseif event == "MemberAwardedGP" then
    local name, reason, amount = ...
    AnnounceSender.Announce(L["%s: %+d GP (%s) to %s"], tableName, amount, reason, name)
  elseif event == "BankedItem" then
    local name, item = ...
    AnnounceSender.Announce(L["%s: %s to %s (Guild Bank)"], tableName, item, name)
  elseif event == "FreeItem" then
    local name, item = ...
    AnnounceSender.Announce(L["%s: %s to %s (Free Item)"], tableName, item, name)
  elseif event == "LockShift" then
    local playerName, lockState = ...
    if lockState == "LOCKED" then
      AnnounceSender.AnnounceTo("GUILD", L["System is locked by %s. All actions disabled."], playerName)
    else
      AnnounceSender.AnnounceTo("GUILD", L["Table %s is unlocked for %s."], lockState, playerName)
    end
  elseif event == "RaidAwardedBP" then
    local batch, reason, comment, medium = ...
    AnnounceSender.AnnounceTo(medium, L["%s: %+d BP (%s) to %s"], tableName, comment, reason, Common:JoinKeys(batch, ", "))
  elseif event == "RaidAwardedGP" then
    local batch, reason, comment, medium = ...
    AnnounceSender.AnnounceTo(medium, L["%s: %+d GP (%s) to %s"], tableName, comment, reason, Common:JoinKeys(batch, ", "))
  elseif event == "AnnounceEpicLoot" then
    local sourceType, reportedLoot, reportedBy = ...
    local lootTypes = {L["Boss"], L["Trash"], L["Boss"]} -- Container loot is basically boss loot in raids
    local lootType, lootList = lootTypes[sourceType], table.concat(reportedLoot, ", ")
    if not reportedBy then
      AnnounceSender.AnnounceTo("RAID", L["%s Loot: %s (don't roll yet)"], lootType, lootList)
    else
      AnnounceSender.AnnounceTo("RAID", L["%s reports %s Loot: %s (don't roll yet)"], reportedBy, lootType, lootList)
    end
  elseif event == "PendingCorpseLoot" then
    local playerName, corpseName = ...
    SendChatMessage(L["%s please loot the %s"]:format(playerName, corpseName), "RAID_WARNING", nil, 0)
  elseif event == "SysResetBP" then
    local batch, reason, comment = ...
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done BP reset"], tableName)
  elseif event == "SysResetGP" then
    local batch, reason, comment = ...
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done GP reset"], tableName)
  elseif event == "SysRescaleBP" then
    local batch, reason, comment = ...
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done BP rescale (x%s)"], tableName, comment)
  elseif event == "SysRescaleGP" then
    local batch, reason, comment = ...
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done GP rescale (x%s)"], tableName, comment)
  elseif event == "SysDecayBP" then
    local batch, reason, comment = ...
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done BP decay (%s%%)"], tableName, comment)
  elseif event == "SysDecayGP" then
    local batch, reason, comment = ...
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done GP decay (%s%%)"], tableName, comment)
  elseif event == "SysWipeBPGP" then
    AnnounceSender.AnnounceTo("GUILD", L["%s: Done empty containers wipe"], tableName)
  elseif event == "AnnounceStandbyList" then
    local medium, standbyList = ...
    local sortedList = {}
    for playerName in pairs(standbyList) do
      tinsert(sortedList, playerName)
    end
    table.sort(sortedList)
    AnnounceSender.AnnounceTo(medium, L["%s: Standby List: %s"], tableName, table.concat(sortedList, ", "))
    AnnounceSender.AnnounceTo(medium, L["%s: Whisper me 'bpgp standby' or use '/bpgp standby' to join."], tableName)
  end
end
