--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/Menus.lua
-- HUD 操作行内嵌菜单：位面选择条、通报频道条、团队快捷操作条。
-- 三者共享同一槽位、互斥展开、撑高控制区使敌方列表自然下移。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local setColor = Theme.setColor
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createFont = Widgets.createFont
local Layout = Theme.Layout
local HUD_PHASE_BAR_H = Layout.HUD_PHASE_BAR_H
local LIST_DEFAULT_WIDTH = Layout.LIST_DEFAULT_WIDTH

function TN:ShowPhaseMenu()
  -- 在队伍/团队中时禁用位面切换（会误操作队友）
  if (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) then
    if UIErrorsFrame then
      UIErrorsFrame:AddMessage("|cffff4d4f已在队伍/团队中，位面切换已禁用|r", 1, 0.3, 0.3, 1, 4)
    end
    self:Print("|cffff4d4f已在队伍/团队中，位面切换已禁用。|r")
    return
  end
  local phases = self.db.profile.phaseHelpers or {}
  local enabled = {}
  for _, p in ipairs(phases) do
    if p.enabled and p.helper and p.helper ~= "" then
      table.insert(enabled, p)
    end
  end

  if #enabled == 0 then
    self:ToggleDetailWindow()
    self:SetDetailView("phase")
    self:Print("尚未配置位面助手，请在详情页中配置")
    return
  end

  local bar = self.hud and self.hud.phaseBar
  if not bar then return end

  if bar:IsShown() then
    self:HidePhasePanel()
    return
  end

  for _, child in ipairs(bar.cells or {}) do child:Hide() end
  bar.cells = {}

  -- 互斥：关闭通报条/团队条
  TN:HideAnnouncePanel()
  TN:HideTeamPanel()

  bar:Show()
  self:LayoutHUD()

  local count = #enabled
  local itemH = HUD_PHASE_BAR_H
  local margin = 4
  local cellW = (bar:GetWidth() or (LIST_DEFAULT_WIDTH - 28)) / count
  local function makeItem(idx)
    local item = CreateFrame("Button", nil, bar)
    item:SetSize(cellW, itemH)
    item:SetPoint("TOPLEFT", margin + (idx - 1) * cellW, 0)
    item.bg = createTexture(item, "BACKGROUND", { 1, 1, 1, 0 })
    item.bg:SetAllPoints()
    item.name = createFont(item, 11, C.text, "OUTLINE", "medium")
    item.name:SetPoint("CENTER")
    item.name:SetWidth(cellW - 8)
    item.name:SetJustifyH("CENTER")
    return item
  end

  for idx, p in ipairs(enabled) do
    local item = makeItem(idx)
    item.name:SetText(p.name)
    if idx < count then
      local sep = createTexture(item, "ARTWORK", C.lineSoft)
      sep:SetSize(1, itemH - 10)
      sep:SetPoint("RIGHT")
    end
    local msg = p.message or ""
    if msg == "" then msg = tostring(idx) end
    item:SetScript("OnEnter", function(self)
      self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
      setColor(self.name, C.text)
    end)
    item:SetScript("OnLeave", function(self)
      self.bg:SetVertexColor(1, 1, 1, 0)
      setColor(self.name, C.text)
    end)
    item:SetScript("OnClick", function()
      TN:HidePhasePanel()
      SendChatMessage(msg, "WHISPER", nil, p.helper)
      TN.db.profile.currentPhase = { name = p.name, helper = p.helper }
      TN:UpdateLocation()
      TN:Print("已密语 " .. p.helper .. " 切换至 " .. p.name)
    end)
    table.insert(bar.cells, item)
  end

  bar:Show()
  self:LayoutHUD()
  self:LayoutPanelHeight()
end

function TN:HidePhasePanel()
  if self.hud and self.hud.phaseBar then
    self.hud.phaseBar:Hide()
    self:LayoutHUD()
    self:LayoutPanelHeight()
  end
end

-- 通报：展开频道选择条（与位面/团队条互斥）
function TN:ShowAnnounceMenu()
  local bar = self.hud and self.hud.announceBar
  if not bar then return end

  if bar:IsShown() then
    self:HideAnnouncePanel()
    return
  end

  for _, child in ipairs(bar.cells or {}) do child:Hide() end
  bar.cells = {}

  TN:HidePhasePanel()
  TN:HideTeamPanel()

  local channels = {
    { label = "小队",     channel = "PARTY" },
    { label = "团队",     channel = "RAID" },
    { label = "公会",     channel = "GUILD" },
    { label = "防务", channel = "CHANNEL" },
  }

  bar:Show()
  self:LayoutHUD()

  local autoMode = self.db.profile.autoAnnounce ~= false
  local count = #channels + 1  -- +1 给自动模式开关
  local itemH = HUD_PHASE_BAR_H
  local margin = 4
  local cellW = (bar:GetWidth() or (LIST_DEFAULT_WIDTH - 28)) / count

  -- 自动模式开关
  local autoBtn = CreateFrame("Button", nil, bar)
  autoBtn:SetSize(cellW, itemH)
  autoBtn:SetPoint("TOPLEFT", margin, 0)
  autoBtn.bg = createTexture(autoBtn, "BACKGROUND", { 1, 1, 1, 0 })
  autoBtn.bg:SetAllPoints()
  autoBtn.name = createFont(autoBtn, 11, autoMode and C.cyan or C.text3, "OUTLINE", "medium")
  autoBtn.name:SetPoint("CENTER")
  autoBtn.name:SetWidth(cellW - 4)
  autoBtn.name:SetJustifyH("CENTER")
  autoBtn.name:SetText(autoMode and "自动模式" or "手动模式")
  local sep = createTexture(autoBtn, "ARTWORK", C.lineSoft)
  sep:SetSize(1, itemH - 10)
  sep:SetPoint("RIGHT")
  autoBtn:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
    setColor(self.name, C.text)
  end)
  autoBtn:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0)
    local on = TN.db.profile.autoAnnounce ~= false
    setColor(self.name, on and C.cyan or C.text3)
  end)
  autoBtn:SetScript("OnClick", function()
    TN:ToggleAutoAnnounce()
    local on = TN.db.profile.autoAnnounce ~= false
    autoBtn.name:SetText(on and "自动模式" or "手动模式")
    setColor(autoBtn.name, on and C.cyan or C.text3)
  end)
  table.insert(bar.cells, autoBtn)

  for idx, ch in ipairs(channels) do
    local item = CreateFrame("Button", nil, bar)
    item:SetSize(cellW, itemH)
    item:SetPoint("TOPLEFT", margin + idx * cellW, 0)
    item.bg = createTexture(item, "BACKGROUND", { 1, 1, 1, 0 })
    item.bg:SetAllPoints()
    item.name = createFont(item, 11, C.text, "OUTLINE", "medium")
    item.name:SetPoint("CENTER")
    item.name:SetWidth(cellW - 8)
    item.name:SetJustifyH("CENTER")
    item.name:SetText(ch.label)
    if idx < count then
      local sep = createTexture(item, "ARTWORK", C.lineSoft)
      sep:SetSize(1, itemH - 10)
      sep:SetPoint("RIGHT")
    end
    item:SetScript("OnEnter", function(self)
      self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
      setColor(item.name, C.text)
    end)
    item:SetScript("OnLeave", function(self)
      self.bg:SetVertexColor(1, 1, 1, 0)
      setColor(item.name, C.text)
    end)
    item:SetScript("OnClick", function()
      TN:HideAnnouncePanel()
      local cid = nil
      if ch.channel == "CHANNEL" then
        local def = TN:GetLocalDefenseChannel()
        cid = def and def.id or nil
      end
      TN:AnnounceTo(ch.channel, cid)
    end)
    table.insert(bar.cells, item)
  end

  bar:Show()
  self:LayoutHUD()
  self:LayoutPanelHeight()
end

function TN:HideAnnouncePanel()
  if self.hud and self.hud.announceBar then
    self.hud.announceBar:Hide()
    self:LayoutHUD()
    self:LayoutPanelHeight()
  end
end

-- 团队：展开可配置快捷操作条（与位面/通报条互斥）
function TN:ShowTeamMenu()
  local bar = self.hud and self.hud.teamBar
  if not bar then return end

  if bar:IsShown() then
    self:HideTeamPanel()
    return
  end

  TN:HidePhasePanel()
  TN:HideAnnouncePanel()
  bar:Show()
  self:LayoutHUD()
  self:BuildTeamMenuBar()
end

function TN:BuildTeamMenuBar()
  local bar = self.hud and self.hud.teamBar
  if not bar then return end

  local teamDB = self.db.profile.team
  local ids = teamDB.quickActions or { "save", "disband", "restore" }

  for _, child in ipairs(bar.cells or {}) do child:Hide() end
  bar.cells = {}

  local items = {}
  for _, id in ipairs(ids) do
    if TN.TEAM_QUICK_ACTIONS[id] then table.insert(items, id) end
  end
  if #items == 0 then
    self:Print("未配置团队快捷操作，请在团队助手详情页选择")
    self:HideTeamPanel()
    self:ToggleDetailWindow()
    self:SetDetailView("team")
    return
  end

  local count = #items
  local itemH = HUD_PHASE_BAR_H
  local margin = 4
  local cellW = (bar:GetWidth() or (LIST_DEFAULT_WIDTH - 28)) / count

  for idx, id in ipairs(items) do
    local def = TN.TEAM_QUICK_ACTIONS[id]
    local item = CreateFrame("Button", nil, bar)
    item:SetSize(cellW, itemH)
    item:SetPoint("TOPLEFT", margin + (idx - 1) * cellW, 0)
    item.bg = createTexture(item, "BACKGROUND", { 1, 1, 1, 0 })
    item.bg:SetAllPoints()
    local function nameColor()
      if def.kind == "toggle" then
        return teamDB[def.toggleKey] and C.cyan or C.text
      end
      return C.text
    end
    item.name = createFont(item, 11, nameColor(), "OUTLINE", "medium")
    item.name:SetPoint("CENTER")
    item.name:SetWidth(cellW - 8)
    item.name:SetJustifyH("CENTER")
    item.name:SetText(def.label)
    if idx < count then
      local sep = createTexture(item, "ARTWORK", C.lineSoft)
      sep:SetSize(1, itemH - 10)
      sep:SetPoint("RIGHT")
    end
    local available = true
    if def.available then available = def.available() end
    if not available then
      setColor(item.name, C.text3)
      item:SetScript("OnEnter", function()
        GameTooltip:SetOwner(item, "ANCHOR_TOP")
        GameTooltip:SetText(def.reason or "当前不可用", C.yellow[1], C.yellow[2], C.yellow[3], C.yellow[4], true)
        GameTooltip:Show()
      end)
      item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
      item:SetScript("OnEnter", function()
        item.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
        setColor(item.name, nameColor())
      end)
      item:SetScript("OnLeave", function()
        item.bg:SetVertexColor(1, 1, 1, 0)
        setColor(item.name, nameColor())
      end)
    end
    item:SetScript("OnClick", function()
      TN:RunTeamQuickAction(id)
      if def.kind == "toggle" then
        setColor(item.name, nameColor())
      else
        TN:HideTeamPanel()
      end
    end)
    table.insert(bar.cells, item)
  end

  bar:Show()
  self:LayoutHUD()
  self:LayoutPanelHeight()
end

function TN:HideTeamPanel()
  if self.hud and self.hud.teamBar then
    self.hud.teamBar:Hide()
    self:LayoutHUD()
    self:LayoutPanelHeight()
  end
end
