local AddonName, BPGP = ...

local private = {
  addonLoaded = false,
  dataLoaded = false,
  addonUnloading = false,
  libraries = {},
  modules = {},
  modulesLoadOrder = {},
}

local ModulePrototype = {
  OnAddonLoad = function (self) return end,
  OnDataLoad = function (self) return end,
  OnAddonUnload = function (self) return end,
  OnEnable = function (self) return end,
  OnDisable = function (self) return end,
  IsEnabled = function (self) return self.enabled end,
  IsDisabled = function (self) return not self.enabled end,
  Enable = function (self) 
    if self:IsEnabled() then return end
    self.enabled = true
    self:OnEnable()
  end,
  Disable = function (self)
    if self:IsDisabled() then return end
    self.enabled = false
    self:OnDisable()
  end,
  Reload = function (self)
    self:Disable()
    self:Enable()
  end,
  GetDBVar = function (self, i) return self.db.profile[i[#i]] end,
  SetDBVar = function (self, i, v) self.db.profile[i[#i]] = v end,
}

function BPGP.RegisterLibrary(libraryName, libraryObject)
  assert(not private.libraries[libraryName])
  private.libraries[libraryName] = libraryObject
end

function BPGP.GetLibrary(libraryName)
  assert(private.libraries[libraryName], "Library '"..tostring(libraryName).."' not found!")
  return private.libraries[libraryName]
end

function BPGP.NewModule(moduleName)
  assert(not private.modules[moduleName])
  local newModule = {}
  tinsert(private.modulesLoadOrder, moduleName)
  private.modules[moduleName] = newModule
  
  local mt = {
    __index = ModulePrototype
  }
  setmetatable(newModule, mt)
  
  return newModule
end

function BPGP.GetModule(moduleName)
  assert(private.modules[moduleName], "Module '"..tostring(moduleName).."' not found!")
  return private.modules[moduleName]
end

function BPGP.GetModules()
  return private.modules
end

function BPGP.GetModulesLoadOrder()
  return private.modulesLoadOrder
end

----------------------------------------
-- Event handlers
----------------------------------------

function private.HandleAddonLoad(event, addonName)
  BPGP.Debugger(event)
  if addonName ~= AddonName or private.addonLoaded then return end
  assert(not private.dataLoaded and not private.addonUnloading)
  private.addonLoaded = true
  
  for i = 1, #private.modulesLoadOrder do
    local module = private.modules[private.modulesLoadOrder[i]]
    module:OnAddonLoad()
  end
  
  BPGP.UnregisterEvent("ADDON_LOADED", private.HandleAddonLoad)
end

function private.HandlePlayerLogin(event)
  BPGP.Debugger(event)
  assert(private.addonLoaded and not private.addonUnloading)
  private.dataLoaded = true
  
  for i = 1, #private.modulesLoadOrder do
    local module = private.modules[private.modulesLoadOrder[i]]
    module:OnDataLoad()
  end
end

function private.HandlePlayerLogout(event)
  BPGP.Debugger(event)
  assert(private.addonLoaded and not private.addonUnloading)
  private.addonUnloading = true
  if not private.dataLoaded then return end
  
  for i = 1, #private.modulesLoadOrder do
    local module = private.modules[private.modulesLoadOrder[i]]
    module:OnAddonUnload()
  end
end

do
  BPGP.RegisterEvent("ADDON_LOADED", private.HandleAddonLoad)
  BPGP.RegisterEvent("PLAYER_LOGIN", private.HandlePlayerLogin)
  BPGP.RegisterEvent("PLAYER_LOGOUT", private.HandlePlayerLogout)
end
