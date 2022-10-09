local _, BPGP = ...

local GUI = BPGP.GetModule("GUI")

local pairs, tostring = pairs, tostring

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")

local Common = BPGP.GetLibrary("Common")

local DataManager = BPGP.GetModule("DataManager")
local StandingsManager = BPGP.GetModule("StandingsManager")

local private = {}

----------------------------------------
-- Public interface
----------------------------------------

function GUI.CreateBPGPStatsFrame()
	local f = GUI.CreateCustomFrame("BPGPStatsFrame", BPGPFrame, "DefaultBackdrop,DialogHeader,CloseButtonHeaderX")
  GUI.RegisterSideframe(f)

  f:Hide()
  f:SetPoint("TOPLEFT", BPGPFrame, "TOPRIGHT", -6, -27)
  f:SetWidth(180)
	f:SetHeight(310)
  
  f:SetHeader(L["Stats"])
  
  f.tableLabel = private.AddStatsLabel(f, f.header, L["Table"])
  f.averageBP = private.AddStatsEntry(f, f.tableLabel, L["Average BP:"])
  f.averageGP = private.AddStatsEntry(f, f.averageBP, L["Average GP:"])
  
  f.guildLabel = private.AddStatsLabel(f, f.averageGP, L["Guild"])
  f.totalMains = private.AddStatsEntry(f, f.guildLabel, L["Total mains:"])
  f.totalAlts = private.AddStatsEntry(f, f.totalMains, L["Total alts:"])
  
  f.settingsLabel = private.AddStatsLabel(f, f.totalAlts, L["Settings"])
  f.minBP = private.AddStatsEntry(f, f.settingsLabel, L["Minimal BP"]..":")
  f.baseGP = private.AddStatsEntry(f, f.minBP, L["Base GP"]..":")
  f.bossAward = private.AddStatsEntry(f, f.baseGP, L["Boss BP Award"]..":")
  f.itemCost = private.AddStatsEntry(f, f.bossAward, L["Item GP Cost"]..":")
  f.standbyAward = private.AddStatsEntry(f, f.itemCost, L["Standby Award"]..":")
  f.decayRatio = private.AddStatsEntry(f, f.standbyAward, L["Decay Ratio"]..":")
  
  local statsTable = nil
  
  local function UpdateStatsFrame()
    local numMains, numAlts = 0, 0
    for playerName in pairs(DataManager.GetPlayersDB("active")) do
      if DataManager.GetMain(playerName) then
        numAlts = numAlts + 1
      else
        numMains = numMains + 1
      end
    end
    local avgBP, avgGP = StandingsManager.GetAverageBPGP()
    f.totalMains.val:SetText(tostring(numMains))
    f.totalAlts.val:SetText(tostring(numAlts))
    f.averageBP.val:SetText(tostring(Common:Round(avgBP, 2)))
    f.averageGP.val:SetText(tostring(Common:Round(avgGP, 2)))
    f.minBP.val:SetText(tostring(DataManager.GetMinBP(StandingsManager.GetTableId())))
    f.baseGP.val:SetText(tostring(DataManager.GetBaseGP(StandingsManager.GetTableId())))
    f.bossAward.val:SetText(tostring(DataManager.GetBPAward()))
    f.itemCost.val:SetText(tostring(DataManager.GetGPCredit()))
    f.standbyAward.val:SetText(tostring(DataManager.GetStandbyPercent()).."%")
    f.decayRatio.val:SetText(tostring(DataManager.GetDecayPercent()).."%")
  end
  BPGP.RegisterCallback("SettingsUpdated", UpdateStatsFrame)
  
  local function AutoUpdateStatsFrame()
    if statsTable == StandingsManager.GetTableId() then return end
    statsTable = StandingsManager.GetTableId()
    UpdateStatsFrame()
  end
  
	f:SetScript("OnUpdate", AutoUpdateStatsFrame)
end

function private.AddStatsLabel(frame, topItem, label)
  local f = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  f:SetPoint("TOP", topItem, "BOTTOM", 0, -20)
  f:SetPoint("LEFT", frame, "LEFT", 18, 0)
  f:SetText(label)
  
  return f
end

function private.AddStatsEntry(frame, topItem, label)
  local f = CreateFrame("Frame", nil, frame)
  f:SetPoint("LEFT")
  f:SetPoint("RIGHT")
  f:SetPoint("TOP", topItem, "BOTTOMLEFT")
  
	f.lbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.lbl:SetPoint("TOP", f, "TOP", 0, -10)
	f.lbl:SetPoint("LEFT", f, "LEFT", 18, 0)
  f.lbl:SetText(label)
  
	f.val = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.val:SetPoint("TOP", f, "TOP", 0, -10)
	f.val:SetPoint("RIGHT", f, "RIGHT", -18, 0)
  
  f:SetHeight(f.lbl:GetHeight())
  
  return f
end