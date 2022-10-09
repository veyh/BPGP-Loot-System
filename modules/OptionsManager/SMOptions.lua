local _, BPGP = ...

local SystemManager = BPGP.GetModule("SystemManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local OptionsManager = BPGP.GetModule("OptionsManager")

function SystemManager:SetLogSync(info, value)
  SystemManager.db.profile.sync = value
  self:Reload()
end

function SystemManager.GetOptions()
  local options = {
    order = 3,
    name = L["Service"],
    desc = L["Service operations and options."],
    handler = SystemManager,
    args = {
      groupService = {
        order = 100,
        inline = true,
        type = "group",
        name = L["Service operations"],
        hidden = function() return not DataManager.SelfGM() end,
        args = {
          initialize_bpgp = {
            order = 110,
            type = "execute",
            name = L["Initialize BPGP"],
            desc = L["Configure BPGP for first-time use."],
            func = function() DLG:Spawn("INITIALIZE_BPGP") end,
            disabled = function() return DataManager.SelfActive() end,
          },
          wipe_data = {
            order = 120,
            type = "execute",
            name = L["Wipe Zero Notes"],
            desc = L["Remove zero BP and GP data containers from the Officer Notes."],
            func = function() DLG:Spawn("BPGP_WIPE_DATA") end,
            disabled = function() return not DataManager.SelfSA() or not DataManager.GetLockState() == 0 end,
          },
          wipe_settings = {
            order = 130,
            type = "execute",
            name = L["Wipe Settings Note"],
            desc = L["Remove the Enforced Settings container from the settings holder's Officer Note."],
            func = function() DLG:Spawn("BPGP_WIPE_SETTINGS") end,
            disabled = function() return DataManager.SelfActive() end,
          },
        },
      },
      groupGlobal = {
        order = 200,
        inline = true,
        type = "group",
        name = L["Table operations"],
        hidden = function() return not DataManager.SelfGM() end,
        disabled = function() return not DataManager.SelfSA() or not DataManager.GetLockState() == 0 end,
        args = {
          rescale_bpgp = {
            order = 302,
            type = "execute",
            name = L["Rescale BP & GP"],
            desc = L["Rescale all BP and GP values in unlocked table by desired factor."],
            func = function() DLG:Spawn("BPGP_RESCALE_BPGP") end,
          },
          rescale_bp = {
            order = 303,
            type = "execute",
            name = L["Rescale BP"],
            desc = L["Rescale all BP values in unlocked table by desired factor."],
            func = function() DLG:Spawn("BPGP_RESCALE_BP") end,
          },
          rescale_gp = {
            order = 304,
            type = "execute",
            name = L["Rescale GP"],
            desc = L["Rescale all GP values in unlocked table by desired factor."],
            func = function() DLG:Spawn("BPGP_RESCALE_GP") end,
          },
          reset_bpgp = {
            order = 305,
            type = "execute",
            name = L["Reset BP & GP"],
            desc = L["Reset all BP and GP values in unlocked table."],
            func = function() DLG:Spawn("BPGP_RESET_BPGP") end,
          },
          reset_bp = {
            order = 306,
            type = "execute",
            name = L["Reset BP"],
            desc = L["Reset all BP values in unlocked table."],
            func = function() DLG:Spawn("BPGP_RESET_BP") end,
          },
          reset_gp = {
            order = 307,
            type = "execute",
            name = L["Reset GP"],
            desc = L["Reset all GP values in unlocked table."],
            func = function() DLG:Spawn("BPGP_RESET_GP") end,
          },
        },
      },
      groupLogging = {
        order = 300,
        inline = true,
        type = "group",
        name = L["Log syncing"],
        args = {
          logSync = {
            order = 101,
            type = "toggle",
            name = L["Sync ongoing actions"],
            desc = L["Listen for BPGP actions broadcasts and append to your local log. Applies only for ongoing ML actions, log history synchronization is not supported."],
            set = "SetLogSync",
            width = 1,
          },
          logTrim = {
            order = 102,
            type = "toggle",
            name = L["Limit log history to 30 days"],
            desc = L["Trim more than 30 days old log entries on each login."],
            width = 2,
            hidden = function () return DataManager.SelfCanWriteNotes() end,
          },
          wipe_classic_logs = {
            order = 103,
            type = "execute",
            name = L["Wipe Classic Logs"],
            desc = L["Clear Classic Era log entries to reduce memory usage."],
            func = function() BPGP.GetModule("Logger").WipeClassicEraLogs() end,
          },
        },
      },
    },
  }
  return options
end