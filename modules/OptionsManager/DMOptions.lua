local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Debugger = BPGP.Debugger
local Common = BPGP.GetLibrary("Common")
local OptionsManager = BPGP.GetModule("OptionsManager")

local private = {
  options = {},
  writePending = false,
}
Debugger.Attach("DMOptions", private)

function DataManager.UpdateOptions()
  private.writePending = false
  Debugger("UpdateOptions")
  DataManager.LoadOptions()
  BPGP.Fire("OptionsUpdated")
end

function DataManager.LoadOptions()
  private.options = DataManager.SettingsToOptions()
end

function DataManager.ApplyOptions()
  private.writePending = true
  local settings = DataManager.OptionsToSettings()
  DataManager.ApplySettings(settings)
end

function DataManager.GetOption(optionData)
  return private.options[optionData[#optionData]]
end

function DataManager.SetOption(optionData, optionValue)
  private.options[optionData[#optionData]] = optionValue
end

function DataManager.OptionsChanged()
  local currentOptions = DataManager.SettingsToOptions()
  for k, v in pairs(private.options) do
    if currentOptions[k] ~= v then return true end
  end
  return false
end

function DataManager.SettingsToOptions()
  local settings, options = DataManager.GetSettings(), {}
  options["baseGPOld"] = settings.baseGPOld
  options["decayPercent"] = settings.decayPercent / 100
  options["standbyPercent"] = settings.standbyPercent / 100
  for i = 2, 9 do
    if settings.altRanks[i] then
      options["altRank"..tostring(i)] = settings.altRanks[i]
    else
      options["altRank"..tostring(i)] = false
    end
  end
  options["wideTables"] = settings.wideTables
  options["namedTables"] = settings.namedTables
  options["integerIndex"] = settings.integerIndex
  options["numTables"] = settings.numTables
  for i = 1, 6 do
    options["tableName"..tostring(i)] = settings.tableNames[i] or 9
  end
  options["bpAward"] = settings.bpAward
  options["gpCredit"] = settings.gpCredit
  for i = 1, 6 do
    options["minBP"..tostring(i)] = settings.minBP[i] or 0
  end
  for i = 1, 6 do
    options["baseGP"..tostring(i)] = settings.baseGP[i] or 1
  end
  return options
end

function DataManager.OptionsToSettings()
  local settings = Common:NewCopy(DataManager.GetSettings())
  settings.baseGPOld = private.options["baseGPOld"]
  settings.decayPercent = private.options["decayPercent"] * 100
  settings.standbyPercent = private.options["standbyPercent"] * 100
  table.wipe(settings.altRanks)
  for i = 2, 9 do
    if private.options["altRank"..tostring(i)] then
      settings.altRanks[i] = true
    end
  end
  settings.wideTables = private.options["wideTables"]
  settings.namedTables = private.options["namedTables"]
  settings.integerIndex = private.options["integerIndex"]
  settings.numTables = private.options["numTables"]
  table.wipe(settings.tableNames)
  for i = 1, private.options["numTables"] do
    table.insert(settings.tableNames, private.options["tableName"..tostring(i)] or 9)
  end
  settings.bpAward = private.options["bpAward"]
  settings.gpCredit = private.options["gpCredit"]
  table.wipe(settings.minBP)
  for i = 1, 6 do
    table.insert(settings.minBP, private.options["minBP"..tostring(i)] or 0)
  end
  table.wipe(settings.baseGP)
  for i = 1, 6 do
    table.insert(settings.baseGP, private.options["baseGP"..tostring(i)] or 1)
  end
  
  return settings
end

local function Spacer(order, width, height)
  return {
    type = "description",
    order = order,
    name = " ",
    fontSize = "small",
    width = width or "full",
  }
end

function DataManager.GetOptions()
  local options = {
    order = 4,
    name = L["Enforced Settings"],
    desc = L["Guild-wide BPGP settings."],
    handler = DataManager,
    get = DataManager.GetOption,
    set = DataManager.SetOption,
    args = {
      groupGeneral = {
        order = 100,
        inline = true,
        type = "group",
        name = L["General"],
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {
--          baseGPOld = {
--            name = L["Base GP"],
--            desc = L["Everyone will have their GP virtually increased by specified amount. GP can't drop below it."],
--            order = 10,
--            type = "range",
--            min = 1,
--            max = 1000,
--            softMin = 0,
--            softMax = 1000,
--            step = 1,
--            bigStep = 10,
--            width = 1.05,
--          },
--          spacer1 = Spacer(11, 0.15),
          decayPercent = {
            name = L["Decay Ratio"],
            desc = L["Both BP and GP will be decreased by specified percentage on every usage of 'Decay' button."],
            order = 20,
            type = "range",
            isPercent = true,
            min = 0,
            max = 1,
            step = 0.01,
            bigStep =  0.05,
            width = 1.05,
          },
          spacer2 = Spacer(21, 0.15),
          standbyPercent = {
            name = L["Standby Award"],
            desc = L["Standby list members will get specified percentage of each BP award received by the raid."],
            order = 30,
            type = "range",
            isPercent = true,
            min = 0,
            max = 1,
            step = 0.01,
            bigStep = 0.05,
            width = 1.05,
          },
        },
      },
      groupBaseGP = {
        order = 140,
        inline = true,
        type = "group",
        name = L["Base GP"],
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {},
      },
      groupMinBP = {
        order = 150,
        inline = true,
        type = "group",
        name = L["Minimal BP"],
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {},
      },
      groupPointsHandling = {
        order = 200,
        inline = true,
        type = "group",
        name = L["Awards & Credits"],
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {
          bpAward = {
            name = L["BP Award Size"],
            desc = L["Amount of Boss Points to be awarded to the raid on boss kills via BP Award Popup."],
            order = 10,
            type = "range",
            min = 1,
            max = 1000,
            step = 1,
            softMin = 0,
            softMax = 1000,
            bigStep = 5,
            width = 1.05,
          },
          spacer1 = Spacer(11, 0.15),
          gpCredit = {
            name = L["GP Item Cost"],
            desc = L["Amount of Gear Points to be credited for any item via GP Credit Popup."],
            order = 20,
            type = "range",
            min = 1,
            max = 1000,
            softMin = 0,
            softMax = 1000,
            step = 1,
            bigStep = 5,
            width = 1.05,
          },
          spacer2 = Spacer(21, 0.15),
          spacer3 = Spacer(22, 0.2),
          integerIndex = {
            order = 30,
            type = "toggle",
            name = L["Integer Index"],
            desc = L["Drop the usage of decimal part of Index in UI and calculations."],
            width = 0.85,
--            validate = function (optionData, optionValue)
--              BPGP.Fire("OptionsUpdated")
--              return "This feature is not implemented yet."
--            end,
          },
        },
      },
      groupAltRanks = {
        order = 300,
        inline = true,
        type = "group",
        name = L["Alt Ranks"],
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {},
      },
      groupStorage = {
        order = 400,
        inline = true,
        type = "group",
        name = L["Data Storage"],
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {
          numTables = {
            order = 110,
            type = "select",
            name = L["Tables number"],
            desc = L["Desired amount of BPGP tables to store and use."],
            values = {"1", "2", "3", "4", "5", "6"},
            width = 0.6,
            validate = function (optionData, optionValue)
              if optionValue < DataManager.GetNumTables() then
                BPGP.Fire("OptionsUpdated")
                return "Reducing amount of tables is not supported yet."
              end
              return true
            end,
            confirm = function (optionData, optionValue)
              if optionValue > DataManager.GetNumTables() then
                return "You won't be able to reduce amount of tables after pressing the 'Enforce Settings' button."
              end
              return false
            end,
          },
          spacer1 = Spacer(111, 0.2),
          namedTables = {
            order = 120,
            type = "toggle",
            name = L["Named tables"],
            desc = L["Allows to select table names from preset. They will be displayed instead of numeral IDs."],
            width = 0.8,
          },
          wideTables = {
            order = 130,
            type = "toggle",
            name = L["Wide tables"],
            desc = L["Rises BP and GP maximum from 3'000 to over 9'000'000. Doubles data length."],
            width = 1,
          },
          groupTableNames = {
            order = 300,
            inline = true,
            type = "group",
            name = L["Table names"],
            args = {},
            hidden = function () return not private.options["namedTables"] end,
          },
        },
      },
      groupManagement = {
        order = 500,
        inline = true,
        type = "group",
        name = L["Management"],
        hidden = function() return not DataManager.SelfGM() end,
        disabled = function() return not DataManager.SelfGM() or private.writePending end,
        args = {
          enforceSettings = {
            order = 110,
            type = "execute",
            name = L["Enforce Settings"],
            desc = L["Apply configured Enforced Settings and save them to the Officer Note of settings holder."],
            func = function()
              if not DataManager.OptionsChanged() then BPGP.Print(L["No changed settings found."]) return end
              DataManager.ApplyOptions()
              BPGP.Fire("OptionsUpdated")
            end,
            disabled = function() return private.writePending or not DataManager.IsAllowedDataWrite() and DataManager.GetSysAdminId() ~= 0 end,
          },
          cancelChanges = {
            order = 120,
            type = "execute",
            name = L["Cancel Changes"],
            desc = L["Reset all changed but not yet applied settings to their current values."],
            func = function()
              DataManager.LoadOptions()
              BPGP.Fire("OptionsUpdated")
            end,
            disabled = function() return not DataManager.OptionsChanged() or private.writePending end,
          },
        },
      },
    },
  }
  -- Fill groupBaseGP
  for i = 1, 6 do
    options.args.groupBaseGP.args["baseGP"..tostring(i)] = {
      order = 10 * i,
      type = "range",
      name = function () return L["Table %s"]:format(DataManager.GetTableName(i) or i) end,
      desc = L["Minimal allowed GP value for the table. Used as default divisor or to flatten Index growth curves."],
      min = 1,
      max = 1000,
      softMin = 0,
      softMax = 1000,
      step = 1,
      bigStep = 10,
      width = 1.05,
      hidden = function () return i > DataManager.GetNumTables() end,
      confirm = function (optionData, optionValue)
        if not private.notifiedBaseGPUpdate and optionValue ~= DataManager.GetSettings().baseGPOld then
          private.notifiedBaseGPUpdate = true
          return "Please ensure everyone in the guild has BPGP 1.1.1 or above. Older versions won't be able to read this setting after pressing the 'Enforce Settings' button."
        end
        return false
      end,
    }
    if i ~= 3 then
      options.args.groupBaseGP.args["spacer"..tostring(i)] = Spacer(10 * i + 1, 0.15)
    end
  end
  -- Fill groupMinBP
  for i = 1, 6 do
    options.args.groupMinBP.args["minBP"..tostring(i)] = {
      order = 10 * i,
      type = "range",
      name = function () return L["Table %s"]:format(DataManager.GetTableName(i) or i) end,
      desc = L["Everyone who has less BP then specified will be greyed out in the main window."],
      min = 0,
      max = 1000,
      step = 1,
      bigStep = 10,
      width = 1.05,
      hidden = function () return i > DataManager.GetNumTables() end,
    }
    if i ~= 3 then
      options.args.groupMinBP.args["spacer"..tostring(i)] = Spacer(10 * i + 1, 0.15)
    end
  end
  -- Fill groupAltRanks
  -- Rank 0 - GM, Rank 1 - MLs
  for i = 2, 9 do
    options.args.groupAltRanks.args["altRank"..tostring(i)] = {
      order = i,
      type = "toggle",
      name = function () return DataManager.GetGuildRank(i) or L["Rank %d"]:format(i + 1) end,
      desc = L["All guild members of this rank will be filtered as alts. Alt ranked character can't be assigned as main for another alt. Up to 3 alt ranks allowed."]:format(i + 1),
      width = 0.8,
      hidden = function () return not DataManager.GetGuildRank(i) end,
      disabled = function(optionData)
        if not DataManager.SelfGM() or private.writePending then return true end
        if private.options[optionData[#optionData]] then return end
        local numAltRanks = 0
        for i = 2, 9 do
         if private.options["altRank"..tostring(i)] then numAltRanks = numAltRanks + 1 end
        end
        return numAltRanks >= 3
      end,
    }
  end
  -- Fill groupTableNames
  for i = 1, 6 do
    options.args.groupStorage.args.groupTableNames.args["tableName"..tostring(i)] = {
      order = i,
      type = "select",
      name = L["Table #%d"]:format(i),
      desc = L["Display this name for table #%d."]:format(i),
      values = DataManager.GetTableNames(),
      width = 0.55,
      hidden = function () return i > (private.options["numTables"] or 1) end,
      validate = function (optionData, optionValue)
        for i = 1, private.options["numTables"] do
          if private.options["tableName"..tostring(i)] == optionValue then
            BPGP.Fire("OptionsUpdated")
            return L["Table names must be unique!"]
          end
        end
        return true
      end,
    }
  end
  return options
end
