local _, BPGP = ...

local DataManager = BPGP.GetModule("DataManager")

local GUI = BPGP.GetModule("GUI")
local DistributionTracker = BPGP.GetModule("DistributionTracker")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local OptionsManager = BPGP.GetModule("OptionsManager")

function GUI.GetOptions()
  local options = {
    order = 1,
    name = L["Interface"],
    desc = L["BPGP appearance."],
    handler = GUI,
    args = {
      groupGeneral = {
        order = 100,
        inline = true,
        type = "group",
        name = L["General"],
        args = {
          backgroundColor = {
            order = 110,
            type = "color",
            name = L["Background Color"],
            hasAlpha = true,
            width = 1,
            get = function(optionData) return unpack(GUI:GetDBVar(optionData)) end,
            set = function(optionData, ...) GUI:SetDBVar(optionData, {...}) GUI.UpdateFrames() end,
          },
          borderColor = {
            order = 120,
            type = "color",
            name = L["Border Color"],
            hasAlpha = true,
            width = 1,
            get = function(optionData) return unpack(GUI:GetDBVar(optionData)) end,
            set = function(optionData, ...) GUI:SetDBVar(optionData, {...}) GUI.UpdateFrames() end,
          },
        },
      },
      groupRankFilter = {
        order = 300,
        inline = true,
        type = "group",
        name = L["Rank Filter"],
        args = {
          filterRanks = {
            order = 310,
            type = "toggle",
            name = L["Enabled"],
            desc = L["Allows to grey out guild members below certain rank."],
            width = 0.7,
            set = function(optionData, ...) GUI:SetDBVar(optionData, ...) BPGP.Fire("RankFilterUpdated") end,
          },
          minimalRank = {
            order = 320,
            type = "select",
            name = L["Minimal Rank"],
            desc = L["Everyone who is below specified rank will be greyed out in the main table."],
            values = function () 
              local guildRanks = {}
              for i = 0, 9 do
                local rankName = DataManager.GetGuildRank(i)
                if rankName then
                  guildRanks[i] = rankName
                else
                  break
                end
              end
              return guildRanks
            end,
            width = 0.9,
            set = function(optionData, ...) GUI:SetDBVar(optionData, ...) BPGP.Fire("RankFilterUpdated") end,
          },
        },
      },
      groupWishlist = {
        order = 400,
        inline = true,
        type = "group",
        name = L["Wishlist"],
        args = {
          wishlistEnabled = {
            order = 440,
            type = "toggle",
            name = L["Enabled"],
            desc = L["Listed items will have special indication in Loot Distribution Popups."],
            width = 2.3,
          },
          importWishlist = {
            order = 460,
            type = "execute",
            name = L["Import Items"],
            desc = L["Open tool for items list import."],
            func = function() BPGPWishlistImportFrame:Show() end,
          },
        },
      },
    },
  }
  return options
end
