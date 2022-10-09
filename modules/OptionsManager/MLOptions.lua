local _, BPGP = ...

local MasterLooter = BPGP.GetModule("MasterLooter")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger

local DataManager = BPGP.GetModule("DataManager")
local OptionsManager = BPGP.GetModule("OptionsManager")

function MasterLooter:SetCollectRollResults(info, value)
  MasterLooter.db.profile.collectRollResults = value
  BPGP.GetModule("RollTracker"):Reload()
end

function MasterLooter:SetBossPopup(info, value)
  MasterLooter.db.profile.bossPopup = value
  BPGP.GetModule("BossTracker"):Reload()
end

function MasterLooter:SetAnnounceEpicLoot(info, value)
  MasterLooter.db.profile.lootAnnounce = value
  BPGP.GetModule("LootTracker"):Reload()
end

function MasterLooter:SetLootAutoAdd(info, value)
  MasterLooter.db.profile.lootAutoAdd = value
  BPGP.GetModule("LootTracker"):Reload()
end

function MasterLooter:SetLootPopup(info, value)
  MasterLooter.db.profile.lootPopup = value
  BPGP.GetModule("LootTracker"):Reload()
end

function MasterLooter:SetStandbyRequests(info, value)
  MasterLooter.db.profile.standbyRequests = value
  BPGP.GetModule("StandbyTracker"):Reload()
end

function MasterLooter:GetAnnounceEvent(i, e)
  return MasterLooter.db.profile.announceEvents[e]
end

function MasterLooter:SetAnnounceEvent(i, e, v)
  if v then
    Debugger("Enabling announce of: %s", e)
  else
    Debugger("Disabling announce of: %s", e)
  end
  MasterLooter.db.profile.announceEvents[e] = v
end

local function Spacer(o, height)
  return {
    type = "description",
    order = o,
    name = " ",
    fontSize = "small",
  }
end

function MasterLooter.GetOptions()
  local options = {
    order = 3,
    name = L["Master Looter"],
    desc = L["Master Looter action loop automation."],
    handler = MasterLooter,
    args = {
      groupLootTracking = {
        order = 100,
        inline = true,
        type = "group",
        name = L["Loot tracking"],
        args = {
          lootAnnounce = {
            order = 110,
            type = "toggle",
            name = L["Announce dropped epic loot"],
            desc = L["For Raid Member enables loot lists broadcasting via hidden channel.\n\nFor Master Looter enables announcing of broadcasted loot lists and corpse loot window contents.\n\nEach loot list is unique and will be announced by ML only once, as well as raid members won't broadcast the list if it is already broadcasted by someone else."],
            width = 2.5,
            set = "SetAnnounceEpicLoot",
          },
          lootAnnounceThreshold = {
            order = 120,
            type = "select",
            name = L["Announce threshold"],
            desc = L["Items below this quality won't be announced."],
            values = {
              [0] = ITEM_QUALITY0_DESC,
              [1] = ITEM_QUALITY1_DESC,
              [2] = ITEM_QUALITY2_DESC,
              [3] = ITEM_QUALITY3_DESC,
              [4] = ITEM_QUALITY4_DESC,
              [5] = ITEM_QUALITY5_DESC,
            },
            width = 0.9,
            hidden = function () return not DataManager.SelfCanWriteNotes() end,
          },
          lootAutoAdd = {
            order = 130,
            type = "toggle",
            name = L["Auto-add loot to the 'Loot' tab and 'Recent Items' lists"],
            desc = L["Automatically add new items from the corpse window to the 'Loot' tab and 'Recent Items' lists."],
            width = 2.4,
            set = "SetLootAutoAdd",
          },
          lootAutoAddThreshold = {
            order = 140,
            type = "select",
            name = L["Auto-adding threshold"],
            desc = L["Items below this quality won't be automatically added to the loot tab."],
            values = {
              [0] = ITEM_QUALITY0_DESC,
              [1] = ITEM_QUALITY1_DESC,
              [2] = ITEM_QUALITY2_DESC,
              [3] = ITEM_QUALITY3_DESC,
              [4] = ITEM_QUALITY4_DESC,
              [5] = ITEM_QUALITY5_DESC,
            },
            width = 0.9,
          },
        },
      },
      groupRollTracking = {
        order = 200,
        type = "group",
        name = L["Roll tracking"],
        inline = true,
        args = {
          collectRollResults = {
            order = 210,
            type = "toggle",
            name = L["Enabled"],
            desc = L["Process roll messages to display roll results."],
            width = 0.7,
            set = "SetCollectRollResults",
          },
          resetRollResults = {
            order = 220,
            type = "toggle",
            name = L["Reset roll results"],
            desc = L["Reset collected roll results after new roll announce."],
            width = 1,
          },
          rollAnnounceMedium = {
            order = 230,
            type = "select",
            name = L["Roll announce channel"],
            desc = L["BPGP will use this channel to announce the starts of new rolls."],
            values = {
              ["RAID"] = CHAT_MSG_RAID,
              ["RAID_WARNING"] = CHAT_MSG_RAID_WARNING,
            },
            width = 0.9,
          },
        },
      },
      groupStandby = {
        order = 300,
        inline = true,
        type = "group",
        name = L["Standby List"],
        args = {
          standbySupport = {
            order = 310,
            type = "toggle",
            name = L["Enabled"],
            desc = L["Additional reward list for non-raid members who waiting for free slot. Standby members will receive BP rewards alongside actual raid members. \n\nUse Shift+LMB to enlist member.\nUse Shift+RMB to delist member."],
            width = 0.7,
          },
          standbyRequests = {
            order = 320,
            type = "toggle",
            name = L["Standby requests"],
            desc = L["Allow members to send requests to be added to standby list via whispers.\n\nIncoming whisper \"bpgp standby\" will register standby request for sender.\nIncoming whisper \"bpgp standby Name\" will register standby request for sender's alt or main.\n\nUse Shift+LMB to accept standby request and enlist member.\nUse Shift+RMB to decline standby request."],
            width = 1,
            set = "SetStandbyRequests",
          },
          standbyNotify = {
            order = 330,
            type = "toggle",
            name = L["Notify"],
            desc = L["Automatically notify enlisted or delisted members via whisper."],
            width = 0.7,
          },
          standbyAnnounceMedium = {
            order = 340,
            type = "select",
            name = L["Reward announce channel"],
            desc = L["BPGP will use this channel to announce BP rewards for standby list members."],
            values = {
              ["GUILD"] = CHAT_MSG_GUILD,
              ["RAID"] = CHAT_MSG_RAID,
              ["NONE"] = NONE,
            },
            width = 0.9,
          },
        },
      },
      groupPopups = {
        order = 400,
        inline = true,
        type = "group",
        name = L["BP/GP/Loot Popups"],
        args = {
          bossPopup = {
            order = 410,
            type = "toggle",
            name = L["Display BP Award Popup on boss kills (requires DBM or BigWigs)"],
            desc = L["BP Award Popup allows to award BP for boss kills with 1 click."],
            width = 30,
            disabled = function() return not DBM and not BigWigsLoader end,
            set = "SetBossPopup",
          },
          lootPopup = {
            order = 420,
            type = "toggle",
            name = L["Display GP Credit Popup when item was masterlooted"],
            desc = L["GP Credit Popup allows to chose between credit GP for given item or announce it as free or banked loot."],
            width = 2.4,
            set = "SetLootPopup",
          },
          lootPopupThreshold = {
            order = 430,
            type = "select",
            name = L["Credit Popup threshold"],
            desc = L["Items below this quality won't trigger GP Credit Popup."],
            values = {
              [0] = ITEM_QUALITY0_DESC,
              [1] = ITEM_QUALITY1_DESC,
              [2] = ITEM_QUALITY2_DESC,
              [3] = ITEM_QUALITY3_DESC,
              [4] = ITEM_QUALITY4_DESC,
              [5] = ITEM_QUALITY5_DESC,
            },
            width = 0.9,
          },
          autoComments = {
            order = 440,
            type = "toggle",
            name = L["Auto-fill Loot Distribution Popup comments"],
            desc = L["Automatically fill Loot Distribution Popup comments for items from imported list."],
            width = 2.3,
          },
          importComments = {
            order = 460,
            type = "execute",
            name = L["Import Comments"],
            desc = L["Open tool for comments list import."],
            func = function() BPGPLootPopupCommentsImportFrame:Show() end,
          },
        },
      },
      groupAnnouncing = {
        order = 500,
        inline = true,
        type = "group",
        name = L["Announcing"],
        args = {
          announceMedium = {
            order = 10,
            type = "select",
            name = L["Announce channel"],
            desc = L["BPGP will use this channel to announce general actions."],
            values = {
              ["GUILD"] = CHAT_MSG_GUILD,
              ["OFFICER"] = CHAT_MSG_OFFICER,
              ["RAID"] = CHAT_MSG_RAID,
              ["CHANNEL"] = CUSTOM,
            },
            width = 0.9,
          },
          announceChannel = {
            order = 11,
            type = "input",
            name = L["Custom channel name"],
            desc = L["BPGP will use this custom channel to announce general actions."],
            disabled = function(i) return MasterLooter.db.profile.announceMedium ~= "CHANNEL" end,
          },
          announceEvents = {
            order = 12,
            type = "multiselect",
            name = L["Announce when:"],
            values = {
              BankedItem = L["An item was deposited to the guild bank"],
              FreeItem = L["An item was given for free"],
              MemberAwardedBP = L["Member was awarded BP"],
              MemberAwardedGP = L["Member was credited GP"],
              RaidAwardedBP = L["Raid was awarded BP"],
            },
            width = "full",
            get = "GetAnnounceEvent",
            set = "SetAnnounceEvent",
          },
        },
      },
    },
  }
  return options
end
