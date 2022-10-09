local _, BPGP = ...

local L = LibStub("AceLocale-3.0"):GetLocale("BPGP")
local DLG = LibStub("LibDialog-1.0")

local DataManager = BPGP.GetModule("DataManager")
local GUI = BPGP.GetModule("GUI")
local DistributionTracker = BPGP.GetModule("DistributionTracker")

DLG:Register("BPGP_ITEM_DISTRIBUTION", {
  text = "Unknown Item",
  icon = [[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]],
  buttons = {
    {
      text = L["Need"],
      on_click = function(self, data, reason)
        self.response = 1
      end,
    },
    {
      text = L["Greed"],
      on_click = function(self, data, reason)
        self.response = 3
      end,
    },
    {
      text = L["Pass"],
      on_click = function(self, data, reason)
        self.response = 4
      end,
    },
  },
  on_show = function(self, data)
    self.response = 4
    local comment = ""
    if data.comment ~= "<NONE>" then comment = " ("..data.comment..")" end
    local text = "BPGP Loot"..comment.."\n".."\n"..data.item.."\n"
    local edit = ""
    self.icon:SetTexture(data.icon)
    self.icon:SetWidth(32)
    self.icon:SetHeight(32)
    self.text:SetFormattedText(text)
    if not self.icon_overlay then
      local icon_overlay = CreateFrame("Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate")
      icon_overlay:SetPoint("CENTER", self.icon, "CENTER")
      icon_overlay:SetWidth(36)
      icon_overlay:SetHeight(36)
      icon_overlay:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left=5, right=5, top=5, bottom=5 }
      })
      icon_overlay:SetBackdropColor(0, 0, 0, 0);
      icon_overlay:SetBackdropBorderColor(0, 1, 0, 1)
      
      local inWishlist = icon_overlay:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      inWishlist:SetPoint("TOP", icon_overlay, "BOTTOM", 0, 2)
      inWishlist:SetTextColor(0, 1, 0)
      icon_overlay.inWishlist = inWishlist
      
      self.icon_overlay = icon_overlay
      self.icon_overlay:Show()
    end
    local wishlistPrio = DistributionTracker.GetWishlistStatus(data.item)
    if GUI.db.profile.wishlistEnabled and wishlistPrio then
      self.icon_overlay.inWishlist:SetText("#"..tostring(wishlistPrio))
      self.icon_overlay:Show()
    else
      self.icon_overlay:Hide()
    end
    if not self.icon_frame then
      local icon_frame = CreateFrame("Frame", nil, self)
      icon_frame:ClearAllPoints()
      icon_frame:SetHeight(32)
      icon_frame:SetPoint("LEFT", self.icon, "LEFT")
      icon_frame:SetPoint("RIGHT", self.text, "RIGHT")
      icon_frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", - 3, icon_frame:GetHeight() + 6)
        GameTooltip:SetHyperlink(self:GetParent().data.item)
      end)
      icon_frame:SetScript("OnLeave", function(self)
        GameTooltip:FadeOut()
      end)
      self.icon_frame = icon_frame
    end
    if self.icon_frame then
      self.icon_frame:EnableMouse(true)
      self.icon_frame:Show()
    end
    if data.mode == 3 then
      self.buttons[2]:Disable()
    else
      self.buttons[2]:Enable()
    end
  end,
  on_hide = function(self, data)
    if ChatEdit_GetActiveWindow() then
      ChatEdit_FocusActiveWindow()
    end
    if self.icon_frame then
      self.icon_frame:EnableMouse(false)
      self.icon_frame:Hide()
    end
    if self.icon_overlay and self.icon_overlay:IsShown() then
      self.icon_overlay:Hide()
    end
    DistributionTracker.ResponseDistribution(data.item, self.response)
  end,
  hide_on_escape = false,
  show_while_dead = true,
})

DLG:Register("BPGP_CONFIRM_GP_CREDIT", {
  text = "Unknown Item",
  icon = [[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]],
  buttons = {
    {
      text = L["Credit GP"],
      on_click = function(self, data, reason)
        DataManager.IncGP(data.name, data.item, DataManager.GetGPCredit())
      end,
    },
    {
      text = L["Log free loot"],
      on_click = function(self, data, reason)
        DataManager.FreeItem(data.item, data.name)
      end,
    },
    {
      text = _G.GUILD_BANK,
      on_click = function(self, data, reason)
        DataManager.BankItem(data.item, data.name)
      end,
    },
  },
  on_show = function(self, data)
    local text = ("\n"..L["%s received loot: %s"].."\n"):format(data.name, data.item)
    self.icon:SetTexture(data.icon)
    self.icon:SetWidth(32)
    self.icon:SetHeight(32)
    self.text:SetFormattedText(text)
    if not self.icon_frame then
      local icon_frame = CreateFrame("Frame", nil, self)
      icon_frame:ClearAllPoints()
      icon_frame:SetHeight(32)
      icon_frame:SetPoint("LEFT", self.icon, "LEFT")
      icon_frame:SetPoint("RIGHT", self.text, "RIGHT")
      icon_frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", - 3, icon_frame:GetHeight() + 6)
        GameTooltip:SetHyperlink(self:GetParent().data.item)
      end)
      icon_frame:SetScript("OnLeave", function(self)
        GameTooltip:FadeOut()
      end)
      self.icon_frame = icon_frame
    end
    if self.icon_frame then
      self.icon_frame:EnableMouse(true)
      self.icon_frame:Show()
    end
  end,
  on_hide = function(self, data)
    if ChatEdit_GetActiveWindow() then
      ChatEdit_FocusActiveWindow()
    end
    if self.icon_frame then
      self.icon_frame:EnableMouse(false)
      self.icon_frame:Hide()
    end
  end,
  on_update = function(self, elapsed)
    if DataManager.IsAllowedIncBPGPByX(self.data.item, DataManager.GetGPCredit()) then
      self.buttons[1]:Enable()
    else
      self.buttons[1]:Disable()
    end
  end,
  hide_on_escape = false,
  show_while_dead = true,
})