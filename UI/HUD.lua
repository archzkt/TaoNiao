--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/HUD.lua
-- 常驻 HUD：构造（CreateHUD）、布局（Layout*）、位置管理、刷新（UpdateHUD/UpdateLocation）。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local setShown = Theme.setShown
local statColor = Theme.statColor
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local createRoundedBlock = Widgets.createRoundedBlock
local createIconButton = Widgets.createIconButton
local applyRoundedCorners = Widgets.applyRoundedCorners
local makeDraggable = Widgets.makeDraggable
local createPanel = Widgets.createPanel
local Layout = Theme.Layout
local LIST_DEFAULT_WIDTH = Layout.LIST_DEFAULT_WIDTH
local LIST_MIN_WIDTH = Layout.LIST_MIN_WIDTH
local LIST_MAX_WIDTH = Layout.LIST_MAX_WIDTH
local LIST_MIN_HEIGHT = Layout.LIST_MIN_HEIGHT
local LIST_MAX_HEIGHT = Layout.LIST_MAX_HEIGHT
local LIST_ROWS_TOP = Layout.LIST_ROWS_TOP
local LIST_ROW_PITCH = Layout.LIST_ROW_PITCH
local LIST_BOTTOM_PAD = Layout.LIST_BOTTOM_PAD
local LIST_MIN_ROWS = Layout.LIST_MIN_ROWS
local LIST_MAX_ROWS = Layout.LIST_MAX_ROWS
local HUD_EXPANDED_HEIGHT = Layout.HUD_EXPANDED_HEIGHT

-- 应用面板不透明度（背景色 alpha）到 HUD 与敌方列表
function TN:ApplyUIAlpha()
  local a = (self.db and self.db.profile and self.db.profile.uiAlpha) or 0.92
  local pc = Theme.C.panel
  local r, g, b = pc[1], pc[2], pc[3]
  if self.hud then
    self.hud:SetBackdropColor(r, g, b, a)
    self.hud:SetBackdropBorderColor(Theme.C.line[1], Theme.C.line[2], Theme.C.line[3], a)
  end
  if self.list then
    self.list:SetBackdropColor(r, g, b, a)
  end
end
local HUD_COLLAPSED_HEIGHT = Layout.HUD_COLLAPSED_HEIGHT
local HUD_FORCE_TOP = Layout.HUD_FORCE_TOP
local HUD_FORCE_HEIGHT = Layout.HUD_FORCE_HEIGHT
local HUD_STAT_HEIGHT = Layout.HUD_STAT_HEIGHT
local HUD_PHASE_BAR_H = Layout.HUD_PHASE_BAR_H
local GROUP_GAP = Layout.GROUP_GAP

function TN:CreateHUD()
  self.hud = createPanel("TaoNiaoHUD", LIST_DEFAULT_WIDTH, HUD_EXPANDED_HEIGHT + LIST_MIN_HEIGHT)
  local hud = self.hud
  hud:SetScale(self.db.profile.scale or 1.0)
  self:ApplyUIAlpha()
  hud:SetScript("OnSizeChanged", function()
    TN:SetGroupWidth(hud:GetWidth(), true)
    TN:LayoutPanelHeight()
  end)

  hud.header = CreateFrame("Frame", nil, hud)
  hud.header:SetPoint("TOPLEFT")
  hud.header:SetPoint("TOPRIGHT")
  hud.header:SetHeight(36)
  hud.header.line = createTexture(hud.header, "ARTWORK", C.lineSoft)
  hud.header.line:SetPoint("BOTTOMLEFT", 1, 0)
  hud.header.line:SetPoint("BOTTOMRIGHT", -1, 0)
  hud.header.line:SetHeight(1)
  makeDraggable(hud, hud.header, "hud")

  hud.logo = createFont(hud.header, 14, C.text, "THICKOUTLINE", "bold")
  hud.logo:SetPoint("LEFT", 12, 0)
  hud.logo:SetText(UnitName("player") or "TAONIAO")
  hud.loc = createFont(hud.header, 11, C.text, "", "regular")
  hud.loc:SetPoint("RIGHT", hud.collapse, "LEFT", -8, 0)
  hud.loc:SetJustifyH("RIGHT")

  hud.collapse = createIconButton(hud.header, "chevron", "折叠/展开", function()
    TN.db.profile.collapsed = not TN.db.profile.collapsed
    TN:UpdateHUD()
  end)
  hud.collapse:SetPoint("RIGHT", -12, 0)

  hud.stats = {
    self:CreateStat(hud, 1, "users", "附近队友", "mates"),
    self:CreateStat(hud, 2, "swords", "今日击杀", "kills"),
    self:CreateStat(hud, 3, "skull", "今日死亡", "deaths"),
    self:CreateStat(hud, 4, "flag", "危险指数", "threat"),
  }
  hud.forceZone = self:CreateForceZone(hud)

  hud.mini = CreateFrame("Frame", nil, hud)
  hud.mini:SetPoint("TOPLEFT")
  hud.mini:SetPoint("TOPRIGHT")
  hud.mini:SetHeight(HUD_COLLAPSED_HEIGHT)
  makeDraggable(hud, hud.mini, "hud")
  hud.mini.stats = {}
  local miniInfo = {
    { "crosshair", "detected", C.cyan, "活跃敌方" },
    { "skull",     "high",     C.red,  "必杀目标" },
    { "users",     "friendlies", C.blue, "附近友方" },
    { "swords",    "kills",    C.green, "今日击杀" },
    { "skull",     "deaths",   C.purple, "今日死亡" },
  }
  for i, info in ipairs(miniInfo) do
    local item = CreateFrame("Button", nil, hud.mini)
    item:SetSize(38, 22)
    item:SetPoint("LEFT", 12 + (i - 1) * 48, 0)
    item.icon = createIcon(item, info[1], 13, info[3])
    item.icon:SetPoint("CENTER", -10, 0)
    item.value = createFont(item, 16, info[3], "", "number")
    item.value:SetPoint("CENTER", 10, 0)
    item.key = info[2]
    item.tooltip = info[4]
    item:SetScript("OnEnter", function(self)
      if self.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tooltip, rgba(info[3]))
        GameTooltip:Show()
      end
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hud.mini.stats[i] = item
  end
  -- 威胁指示灯：与敌人列表圆点同方案（circle.tga 实心圆 texture，SetVertexColor 原生着色）
  hud.mini.threatLamp = createTexture(hud.mini, "ARTWORK", C.green)
  hud.mini.threatLamp:SetTexture("Interface\\AddOns\\TaoNiao\\Textures\\circle.tga")
  hud.mini.threatLamp:SetPoint("CENTER", hud.mini.stats[5], "RIGHT", 22, 0)
  hud.mini.threatLamp:SetSize(14, 14)
  hud.mini.expand = createIconButton(hud.mini, "chevron", "展开", function()
    TN.db.profile.collapsed = false
    TN:UpdateHUD()
  end)
  hud.mini.expand:SetPoint("RIGHT", -12, 0)
  hud.mini.expand.icon:SetTexCoord(0, 1, 1, 0)

  hud.actions = {
    self:CreateAction(hud, 1, "megaphone", "通报", function() TN:ToggleAutoAnnounce() end),
    self:CreateAction(hud, 2, "portal", "位面", function() TN:ShowPhaseMenu() end),
    self:CreateAction(hud, 3, "users", "团队", function() TN:ShowTeamMenu() end),
    self:CreateAction(hud, 4, "details", "详情", function() TN:ToggleDetailWindow() end),
  }

  -- 内嵌位面选择条
  hud.phaseBar = CreateFrame("Frame", nil, hud)
  hud.phaseBar:SetHeight(HUD_PHASE_BAR_H)
  hud.phaseBar:EnableMouse(true)
  applyRoundedCorners(hud.phaseBar, 8, C.panel2)
  hud.phaseBar:Hide()

  -- 内嵌通报频道条
  hud.announceBar = CreateFrame("Frame", nil, hud)
  hud.announceBar:SetHeight(HUD_PHASE_BAR_H)
  hud.announceBar:EnableMouse(true)
  applyRoundedCorners(hud.announceBar, 8, C.panel2)
  hud.announceBar:Hide()

  -- 内嵌团队快捷操作条
  hud.teamBar = CreateFrame("Frame", nil, hud)
  hud.teamBar:SetHeight(HUD_PHASE_BAR_H)
  hud.teamBar:EnableMouse(true)
  applyRoundedCorners(hud.teamBar, 8, C.panel2)
  hud.teamBar:Hide()

  self:LayoutHUD()

  self:CreateEnemyList()
  self:CreateToastStack()
  self:RestorePositions()
end

function TN:CreateFriendlyHeader()
  if self.hud.friendlyHeader then return end
  local h = CreateFrame("Frame", nil, self.hud)
  h:SetHeight(LIST_HEADER_HEIGHT or 22)
  h.bg = createTexture(h, "BACKGROUND", { 1, 1, 1, 0.04 })
  h.bg:SetAllPoints()
  h.line = createTexture(h, "ARTWORK", C.lineSoft)
  h.line:SetPoint("BOTTOMLEFT", 1, 0)
  h.line:SetPoint("BOTTOMRIGHT", -1, 0)
  h.line:SetHeight(1)
  h.title = createFont(h, 12, C.text, "OUTLINE", "bold")
  h.title:SetPoint("LEFT", 10, 0)
  h.title:SetText("附近友方")
  h.count = createFont(h, 12, C.cyan, "", "number")
  h.count:SetPoint("LEFT", h.title, "RIGHT", 6, 0)
  h.detail = createFont(h, 9, C.text3)
  h.detail:SetJustifyH("RIGHT")
  h.detail:SetPoint("RIGHT", -6, 0)
  h:Hide()
  self.hud.friendlyHeader = h
end

function TN:ClampGroupWidth(width)
  return math.max(LIST_MIN_WIDTH, math.min(LIST_MAX_WIDTH, width or LIST_DEFAULT_WIDTH))
end

function TN:SetGroupWidth(width, skipHudWidth)
  width = self:ClampGroupWidth(width)
  if self.hud and not skipHudWidth then
    local parentTop = UIParent:GetTop() or GetScreenHeight()
    local left = self.hud:GetLeft()
    local top = self.hud:GetTop()
    if left and top then
      self.hud:ClearAllPoints()
      self.hud:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - parentTop)
    end
    self.hud:SetWidth(width)
  end
  if self.list then
    self.list:SetWidth(width)
  end
  self:LayoutHUD()
  self:LayoutEnemyList()
end

function TN:ClampEnemyListSize()
  if not self.list then return end
  local w = self:ClampGroupWidth(self.list:GetWidth() or LIST_DEFAULT_WIDTH)
  local h = math.max(LIST_MIN_HEIGHT, math.min(LIST_MAX_HEIGHT, self.list:GetHeight() or LIST_MIN_HEIGHT))
  self.list:SetSize(w, h)
end

function TN:GetEnemyListCapacity()
  return self.db.profile.list.maxVisibleRows or LIST_MAX_ROWS
end

function TN:SetEnemyListRowsHeight(rowCount)
  if not self.list then return end
  local rows = math.max(LIST_MIN_ROWS, math.min(LIST_MAX_ROWS, rowCount or LIST_MIN_ROWS))
  local height = rows == 0 and LIST_MIN_HEIGHT or (LIST_ROWS_TOP + rows * LIST_ROW_PITCH + LIST_BOTTOM_PAD)
  self.list:SetHeight(height)
  if self.db and self.db.profile and self.db.profile.list then
    self.db.profile.list.h = height
  end
  self:LayoutPanelHeight()
end

function TN:LayoutPanelHeight()
  if not self.hud or not self.list then return end
  local controlHeight = self.db.profile.collapsed and HUD_COLLAPSED_HEIGHT or (self.hudExpandedHeight or HUD_EXPANDED_HEIGHT)
  local listHeight = self.list:IsShown() and (self.list:GetHeight() or LIST_MIN_HEIGHT) or 0
  self.hud:SetHeight(controlHeight + listHeight + GROUP_GAP)
  if self.list:IsShown() then
    self.list:ClearAllPoints()
    self.list:SetPoint("TOPLEFT", self.hud, "TOPLEFT", 0, -controlHeight - GROUP_GAP)
    self.list:SetPoint("TOPRIGHT", self.hud, "TOPRIGHT", 0, -controlHeight - GROUP_GAP)
  end
end

function TN:ManageBarsDisplayed()
  if not self.list or not self.list.rows then return end
  local listHeight = self.list:GetHeight() or LIST_MIN_HEIGHT
  local bars = math.max(LIST_MIN_ROWS, math.min(LIST_MAX_ROWS,
    math.floor((listHeight - LIST_ROWS_TOP + LIST_BOTTOM_PAD) / LIST_ROW_PITCH)))
  local shownEnemies = 0
  for _, row in ipairs(self.list.rows) do
    if row.enemy then shownEnemies = shownEnemies + 1 end
  end
  if bars > shownEnemies then bars = shownEnemies end
  for i, row in ipairs(self.list.rows) do
    if i <= bars and row.enemy then
      row:Show()
    else
      row:Hide()
    end
  end
end

function TN:LayoutEnemyList()
  if not self.list or not self.list.rows then return end
  local width = self.list:GetWidth() or LIST_DEFAULT_WIDTH
  local rowWidth = math.max(1, width - 16)
  local nameWidth = math.max(70, rowWidth - 170)
  if self.list.nameHead then
    self.list.nameHead:SetWidth(nameWidth)
  end
  for i, row in ipairs(self.list.rows) do
    row:SetWidth(rowWidth)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 8, -LIST_ROWS_TOP - (i - 1) * LIST_ROW_PITCH)
    row.name:SetWidth(nameWidth)
  end
end

function TN:LayoutHUD()
  if not self.hud then return end
  local hud = self.hud
  local width = hud:GetWidth() or LIST_DEFAULT_WIDTH
  local margin = 12

  local fh = self.forceZoneHeight or HUD_FORCE_HEIGHT
  local forceTop = HUD_FORCE_TOP
  local forceBottom = forceTop - fh
  local statTop = forceBottom - 4
  local statBottom = statTop - HUD_STAT_HEIGHT
  local actionTop = statBottom - 4

  local statGap = 5
  local statWidth = math.floor((width - margin * 2 - statGap * 3) / 4)
  local statsSpan = 4 * statWidth + 3 * statGap
  if hud.stats then
    for i, cell in ipairs(hud.stats) do
      cell:SetWidth(statWidth)
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", margin + (i - 1) * (statWidth + statGap), statTop)
      if cell.label then cell.label:SetWidth(math.max(1, statWidth - 15)) end
      cell.value:SetWidth(statWidth)
    end
  end

  if hud.forceZone then
    local zoneWidth = statsSpan
    hud.forceZone:SetWidth(zoneWidth)
    hud.forceZone:ClearAllPoints()
    hud.forceZone:SetPoint("TOPLEFT", margin, forceTop)
    hud.forceZone:SetHeight(fh)

    local halfWidth = math.floor(zoneWidth / 2)
    hud.forceZone.enemyCol:ClearAllPoints()
    hud.forceZone.enemyCol:SetPoint("TOPLEFT", hud.forceZone.announceLine, "BOTTOMLEFT", 0, -2)
    hud.forceZone.enemyCol:SetPoint("BOTTOMLEFT")
    hud.forceZone.enemyCol:SetWidth(halfWidth - 1)
    hud.forceZone.enemyChips:SetPoint("TOPRIGHT", -5, -24)

    hud.forceZone.friendCol:ClearAllPoints()
    hud.forceZone.friendCol:SetPoint("TOPRIGHT", hud.forceZone.announceLine, "BOTTOMRIGHT", 0, -2)
    hud.forceZone.friendCol:SetPoint("BOTTOMRIGHT")
    hud.forceZone.friendCol:SetWidth(halfWidth - 1)
    hud.forceZone.friendChips:SetPoint("TOPRIGHT", -5, -24)

    hud.forceZone.vsep:ClearAllPoints()
    hud.forceZone.vsep:SetPoint("TOP", hud.forceZone.announceLine, "BOTTOM", 0, -2)
    hud.forceZone.vsep:SetPoint("BOTTOM", hud.forceZone, "BOTTOM", 0, 6)
    hud.forceZone.vsep:Show()
    hud.forceZone.friendCol:Show()
  end

  local actionGap = 5
  local actionWidth = math.floor((statsSpan - actionGap * 3) / 4)
  if hud.actions then
    for i, action in ipairs(hud.actions) do
      action:SetWidth(actionWidth)
      action:ClearAllPoints()
      action:SetPoint("TOPLEFT", margin + (i - 1) * (actionWidth + actionGap), actionTop)
      action.text:SetWidth(math.max(1, actionWidth - 36))
    end
  end

  -- 内嵌条：同一槽位定位在 actions 正下方（action 高度 28）
  local barTop = actionTop - 28 - 6
  local anyBarShown = false
  for _, bar in ipairs({ hud.phaseBar, hud.announceBar, hud.teamBar }) do
    if bar then
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", margin, barTop)
      bar:SetPoint("TOPRIGHT", -margin, barTop)
      if bar:IsShown() then anyBarShown = true end
    end
  end
  local phaseExtra = anyBarShown and (HUD_PHASE_BAR_H + 6) or 0
  self.hudExpandedHeight = -(actionTop - 28 - 14) + phaseExtra

  if hud.loc then
    hud.loc:ClearAllPoints()
    hud.loc:SetPoint("RIGHT", hud.collapse, "LEFT", -8, 0)
    hud.loc:SetWidth(math.max(100, width - 100))
    hud.loc:SetJustifyH("RIGHT")
  end

  if hud.mini and hud.mini.stats then
    local miniStep = math.max(34, math.floor((width - 80) / 5))
    for i, item in ipairs(hud.mini.stats) do
      item:ClearAllPoints()
      item:SetPoint("LEFT", margin + (i - 1) * miniStep, 0)
    end
    if hud.mini.threatLamp then
      hud.mini.threatLamp:ClearAllPoints()
      hud.mini.threatLamp:SetPoint("LEFT", hud.mini.stats[5], "RIGHT", 14, 0)
    end
  end
end

function TN:RestorePositions()
  local hudPos = self.db.profile.hud
  local listPos = self.db.profile.list
  local groupWidth = LIST_DEFAULT_WIDTH
  local parentWidth = UIParent:GetWidth() or GetScreenWidth()
  local x = math.floor((hudPos.x or 40) + 0.5)
  local y = math.floor((hudPos.y or -40) + 0.5)
  if hudPos.point and hudPos.point:find("RIGHT") then
    x = parentWidth + (hudPos.x or 40) - groupWidth
    x = math.floor(x + 0.5)
  end
  self.hud:ClearAllPoints()
  self.hud:SetWidth(groupWidth)
  self.hud:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
  self.db.profile.hud.point = "TOPLEFT"
  self.db.profile.hud.x = x
  self.db.profile.hud.y = y
  self.list:SetSize(groupWidth, listPos.h or LIST_MIN_HEIGHT)
  self:ClampEnemyListSize()
  self:LayoutEnemyList()
  self:LayoutHUD()
  self:LayoutPanelHeight()

  -- ToastStack 锚定屏幕顶部居中（与 Spy 一致），由 CreateToastStack 一次性设定，
  -- 不随 HUD 移动/缩放变化，故此处不再重设。
end

-- 更新当前位置信息：真实地区 + 追踪的当前位面 + 坐标
function TN:UpdateLocation()
  local subZone = GetSubZoneText()
  local zone = GetZoneText() or "未知区域"
  local zoneText = (subZone and subZone ~= "") and subZone or zone

  local layer = self:GetCurrentLayer()
  local phaseName
  if layer then
    phaseName = "位面 " .. layer
  else
    local _, instType = GetInstanceInfo()
    phaseName = (instType ~= "none") and "副本中" or "无位面"
  end

  local coordText = ""
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
      local pos = C_Map.GetPlayerMapPosition(mapID, "player")
      if pos then
        local x, y = pos:GetXY()
        coordText = string.format("%.1f, %.1f", x * 100, y * 100)
      end
    end
  end

  if self.hud and self.hud.loc then
    self.hud.loc:SetText(zoneText .. " · " .. phaseName)
  end
  if self.detail and self.detail.locZone then
    self.detail.locZone:SetText(zoneText)
    if self.detail.locPhase then self.detail.locPhase:SetText(phaseName) end
    if self.detail.locCoord then
      self.detail.locCoord:SetText(coordText ~= "" and ("坐标 " .. coordText) or "")
    end
  end
end

function TN:UpdateHUD()
  if not self.hud then return end
  if self.db.profile.enabled == false then
    self.hud:Hide()
    return
  end
  self.hud:Show()
  local stats = self:GetStats()
  local collapsed = self.db.profile.collapsed
  setShown(self.hud.header, not collapsed)
  setShown(self.hud.mini, collapsed)
  for _, child in ipairs({ self.hud.stats[1], self.hud.stats[2], self.hud.stats[3], self.hud.stats[4], self.hud.forceZone }) do
    setShown(child, not collapsed)
  end
  for _, action in ipairs(self.hud.actions) do setShown(action, not collapsed) end
  -- 更新通报按钮文字与提示
  local autoOn = self.db.profile.autoAnnounce ~= false
  if self.hud.actions[1] and self.hud.actions[1].text then
    self.hud.actions[1].text:SetText(autoOn and "启用" or "静默")
    setColor(self.hud.actions[1].text, autoOn and C.cyan or C.text3)
    self.hud.actions[1]._tooltip = autoOn and "发现敌人时自动通报" or "发现敌人时保持静默"
  end
  if collapsed and self.hud.phaseBar and self.hud.phaseBar:IsShown() then
    self:HidePhasePanel()
  end
  if collapsed and self.hud.announceBar and self.hud.announceBar:IsShown() then
    self:HideAnnouncePanel()
  end
  if collapsed and self.hud.teamBar and self.hud.teamBar:IsShown() then
    self:HideTeamPanel()
  end
  if collapsed then
    self.hud.collapse.icon:SetTexCoord(0, 1, 1, 0)
  else
    self.hud.collapse.icon:SetTexCoord(0, 1, 0, 1)
  end

  self:UpdateLocation()

  local badge, tone = self:ThreatTone(stats.threat)
  local statValues = { stats.nearbyMates or 0, stats.kills, stats.deaths, stats.threat }
  for i, cell in ipairs(self.hud.stats) do
    local col = cell.key == "threat" and statColor(cell.key, statValues[i]) or statColor(cell.key)
    if cell.key == "threat" then
      cell.value:SetText(badge)
    else
      cell.value:SetText(tostring(statValues[i] or 0))
    end
    setColor(cell.value, col)
    if cell.icon then cell.icon:SetVertexColor(rgba(col)) end
  end
  local miniValues = { stats.detected, stats.high, stats.nearbyFriendlies or 0, stats.kills, stats.deaths }
  for i, item in ipairs(self.hud.mini.stats) do
    local col = statColor(item.key)
    item.value:SetText(tostring(miniValues[i] or 0))
    setColor(item.value, col)
    item.icon:SetVertexColor(rgba(col))
  end

  local _, tone2 = self:ThreatTone(stats.threat)
  -- 非呼吸模式下还原指示灯和危险指数文字
  if not self.db.profile.threatBreathing then
    if self.hud.mini.threatLamp then
      self.hud.mini.threatLamp:SetSize(14, 14)
      self.hud.mini.threatLamp:SetVertexColor(tone2[1], tone2[2], tone2[3], 0.92)
    end
    if self.hud.stats[4] and self.hud.stats[4].value then
      setColor(self.hud.stats[4].value, statColor("threat", stats.threat))
    end
  end

  self:UpdateForceZone(stats)
  self:LayoutHUD()
  self:UpdateEnemyList(stats)
end
