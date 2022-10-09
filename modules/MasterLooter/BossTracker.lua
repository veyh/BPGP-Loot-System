local _, BPGP = ...

local BossTracker = BPGP.NewModule("BossTracker")

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local Debugger = BPGP.Debugger
local Coroutine = BPGP.GetLibrary("Coroutine")

local DataManager = BPGP.GetModule("DataManager")
local MasterLooter = BPGP.GetModule("MasterLooter")
  
local private = {
  dbDefaults = {
    profile = {
      enabled = false, -- Loading is managed by MasterLooter module
    },
  },
  loaded = false,
}

function BossTracker:OnAddonLoad()
  self.db = BPGP.db:RegisterNamespace("BossTracker", private.dbDefaults)
end

function BossTracker:OnEnable()
  Debugger("BossTracker:OnEnable()")
  if MasterLooter.db.profile.bossPopup then
    if DBM then
      BPGP.Print(L["Started boss tracking with %s"]:format("DBM"))
      DBM:RegisterCallback("DBM_Kill", private.dbmCallback)
      DBM:RegisterCallback("DBM_Wipe", private.dbmCallback)
    elseif BigWigsLoader then
      BPGP.Print(L["Started boss tracking with %s"]:format("BigWigs"))
      BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossWin", private.bwCallback)
      BigWigsLoader.RegisterMessage(self, "BigWigs_OnBossWipe", private.bwCallback)
    end
    private.loaded = true
  end
  if not DataManager.SelfInRaid() then
    self:Disable()
  end
end

function BossTracker:OnDisable()
  Debugger("BossTracker:OnDisable()")
  if private.loaded then
    if DBM then
      BPGP.Print(L["Stopped boss tracking with %s (not ML)"]:format("DBM"))
      DBM:UnregisterCallback("DBM_Kill", private.dbmCallback)
      DBM:UnregisterCallback("DBM_Wipe", private.dbmCallback)
    elseif BigWigsLoader then
      BPGP.Print(L["Stopped boss tracking with %s (not ML)"]:format("BigWigs"))
      BigWigsLoader.UnregisterMessage(self, "BigWigs_OnBossWin")
      BigWigsLoader.UnregisterMessage(self, "BigWigs_OnBossWipe")
    end
    private.loaded = false
  end
end

----------------------------------------
-- Event handlers
----------------------------------------

function private.dbmCallback(event, BossTracker)
  private.BossAttempt(event, BossTracker.combatInfo.name)
end

function private.bwCallback(event, module)
  private.BossAttempt(event == "BigWigs_OnBossWin" and "kill" or "wipe", module.displayName)
end

----------------------------------------
-- Internal methods
----------------------------------------

function private.BossAttempt(event, bossName)
  if not DataManager.SelfSA() or not DataManager.IsAllowedDataWrite() then return end
  Coroutine:RunAsync(private.ShowPopup, event, bossName)
end

function private.ShowPopup(event, bossName)
  while DLG:ActiveDialog("BPGP_BOSS_KILLED") do
    Coroutine:Sleep(0.1)
  end
  if event == "kill" or event == "DBM_Kill" or event == "BossKilled" then
    DLG:Spawn("BPGP_BOSS_KILLED", bossName)
  end
end

