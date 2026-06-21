--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/EnemyList.lua
-- 敌方玩家列表：表头/行池/tooltip/实时刷新。
-- 含私有辅助（formatSeenAgo/targetMacroText/applyTargetAction/enemyListName 等）。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local setShown = Theme.setShown
local enemyThreatColor = Theme.enemyThreatColor
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createRoundedBlock = Widgets.createRoundedBlock
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local makeDraggable = Widgets.makeDraggable
local createCircle = Widgets.createCircle
local utf8Truncate = Widgets.utf8Truncate
local Layout = Theme.Layout
local LIST_DEFAULT_WIDTH = Layout.LIST_DEFAULT_WIDTH
local LIST_MIN_WIDTH = Layout.LIST_MIN_WIDTH
local LIST_MIN_HEIGHT = Layout.LIST_MIN_HEIGHT
local LIST_MAX_WIDTH = Layout.LIST_MAX_WIDTH
local LIST_MAX_HEIGHT = Layout.LIST_MAX_HEIGHT
local LIST_HEADER_HEIGHT = Layout.LIST_HEADER_HEIGHT
local LIST_ROWS_TOP = Layout.LIST_ROWS_TOP
local LIST_ROW_HEIGHT = Layout.LIST_ROW_HEIGHT
local LIST_ROW_PITCH = Layout.LIST_ROW_PITCH
local LIST_MIN_ROWS = Layout.LIST_MIN_ROWS
local LIST_MAX_ROWS = Layout.LIST_MAX_ROWS
local LIST_BOTTOM_PAD = Layout.LIST_BOTTOM_PAD

-- ── 私有辅助 ──
local function getSpyPlayerData(name)
  if not name or not SpyPerCharDB or not SpyPerCharDB.PlayerData then return nil end
  return SpyPerCharDB.PlayerData[name]
end

local function formatSeenAgo(seconds)
  seconds = math.max(0, tonumber(seconds) or 0)
  if seconds < 60 then return math.floor(seconds) .. "s 前" end
  local minutes = math.floor(seconds / 60)
  if minutes < 60 then return minutes .. " 分钟前" end
  local hours = math.floor(minutes / 60)
  if hours < 24 then return hours .. " 小时前" end
  return math.floor(hours / 24) .. " 天前"
end

local function targetMacroText(enemy)
  if not enemy then return "/targetexact nil" end
  local name = enemy.name
  if not name or name == "" then return "/targetexact nil" end
  return "/cleartarget\n/targetexact " .. name
end

local function applyTargetAction(row, enemy)
  if not row or InCombatLockdown() then return end
  if enemy and enemy.unit and UnitExists(enemy.unit) and UnitGUID(enemy.unit) == enemy.guid then
    row:SetAttribute("type1", "target")
    row:SetAttribute("*type1", "target")
    row:SetAttribute("unit", enemy.unit)
    row:SetAttribute("target", enemy.unit)
    row:SetAttribute("macrotext", nil)
    row:SetAttribute("macrotext1", nil)
    return
  end
  local macro = targetMacroText(enemy)
  row:SetAttribute("type1", "macro")
  row:SetAttribute("*type1", "macro")
  row:SetAttribute("unit", nil)
  row:SetAttribute("target", nil)
  row:SetAttribute("macrotext", macro)
  row:SetAttribute("macrotext1", macro)
end

local function enemyListName(enemy)
  local name = enemy.name or ""
  local guild = enemy.guild
  if guild and guild ~= "" then
    return name .. " |cff9aa6b2<" .. utf8Truncate(guild, 14) .. ">|r"
  end
  return name
end

-- ── 列表构造 ──
function TN:CreateEnemyList()
  self.list = CreateFrame("Frame", "TaoNiaoEnemyList", self.hud)
  self.list:SetSize(LIST_DEFAULT_WIDTH, LIST_MIN_HEIGHT)
  local list = self.list
  list:EnableMouse(true)

  list.header = CreateFrame("Frame", nil, list)
  list.header:SetPoint("TOPLEFT")
  list.header:SetPoint("TOPRIGHT")
  list.header:SetHeight(LIST_HEADER_HEIGHT)
  list.header.bg = createTexture(list.header, "BACKGROUND", { 1, 1, 1, 0.04 })
  list.header.bg:SetAllPoints()
  list.header.line = createTexture(list.header, "ARTWORK", C.lineSoft)
  list.header.line:SetPoint("BOTTOMLEFT", 1, 0)
  list.header.line:SetPoint("BOTTOMRIGHT", -1, 0)
  list.header.line:SetHeight(1)
  makeDraggable(self.hud, list.header, "hud")

  list.title = createFont(list.header, 12, C.text, "OUTLINE", "bold")
  list.title:SetPoint("LEFT", 10, 0)
  list.title:SetText("敌方玩家")
  list.count = createFont(list.header, 12, C.cyan, "", "number")
  list.count:SetPoint("LEFT", list.title, "RIGHT", 6, 0)
  list.count:Hide()
  list.updated = createFont(list.header, 9, C.text3)
  list.updated:SetWidth(74)
  list.updated:SetJustifyH("RIGHT")
  list.updated:SetPoint("RIGHT", -6, 0)

  list.nameHead = createFont(list, 10, C.text3, "", "medium")
  list.nameHead:SetWidth(206)
  list.nameHead:SetJustifyH("LEFT")
  list.nameHead:SetPoint("TOPLEFT", 30, -40)
  list.nameHead:SetText("名字")
  list.nameHead:Hide()
  list.levelHead = createFont(list, 10, C.text3, "", "medium")
  list.levelHead:SetWidth(30)
  list.levelHead:SetJustifyH("CENTER")
  list.levelHead:SetPoint("TOPRIGHT", -43, -40)
  list.levelHead:SetText("等级")
  list.levelHead:Hide()
  list.classHead = createFont(list, 10, C.text3, "", "medium")
  list.classHead:SetWidth(26)
  list.classHead:SetJustifyH("CENTER")
  list.classHead:SetPoint("TOPRIGHT", -17, -40)
  list.classHead:SetText("职业")
  list.classHead:Hide()

  list.rows = {}
  for i = 1, TN.maxRows do
    list.rows[i] = self:CreateEnemyRow(list, i)
  end

  list:SetResizable(true)
  list:SetResizeBounds(LIST_MIN_WIDTH, LIST_MIN_HEIGHT, LIST_MAX_WIDTH, LIST_MAX_HEIGHT)

  list.sizer = CreateFrame("Button", nil, list)
  list.sizer:SetSize(16, 16)
  list.sizer:SetPoint("BOTTOMRIGHT", -2, 2)
  list.sizer.icon = createIcon(list.sizer, "chevron", 8, C.text3)
  list.sizer.icon:SetPoint("CENTER")
  list.sizer.icon:SetTexCoord(0, 1, 1, 0)
  list.sizer:SetScript("OnEnter", function(self)
    self.icon:SetVertexColor(rgba(C.cyan))
  end)
  list.sizer:SetScript("OnLeave", function(self)
    self.icon:SetVertexColor(rgba(C.text3))
  end)
  list.sizer:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not TN.db.profile.locked then
      list.isResizing = true
      list:StartSizing("BOTTOMRIGHT")
    end
  end)
  list.sizer:SetScript("OnMouseUp", function(self)
    if list.isResizing then
      list:StopMovingOrSizing()
      list.isResizing = false
      local rows = math.max(LIST_MIN_ROWS, math.min(LIST_MAX_ROWS,
        math.floor((list:GetHeight() - LIST_ROWS_TOP + LIST_BOTTOM_PAD) / LIST_ROW_PITCH)))
      TN.db.profile.list.maxVisibleRows = rows
      TN:UpdateHUD()
    end
  end)

  list:SetScript("OnSizeChanged", function(self)
    if self.isResizing then
      local hudWidth = self:GetParent() and self:GetParent():GetWidth() or LIST_DEFAULT_WIDTH
      self:SetWidth(hudWidth)
      TN:LayoutPanelHeight()
      TN:ManageBarsDisplayed()
    end
  end)

  list:SetScript("OnHide", function(self)
    if self.isResizing then
      self:StopMovingOrSizing()
      self.isResizing = false
    end
  end)
end

function TN:CreateEnemyRow(parent, index)
  local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
  row.id = index
  row:SetSize(LIST_DEFAULT_WIDTH - 16, LIST_ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 8, -LIST_ROWS_TOP - (index - 1) * LIST_ROW_PITCH)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetAttribute("type1", "macro")
  row:SetAttribute("*type1", "macro")
  row:SetAttribute("macrotext", "/targetexact nil")
  row:SetAttribute("macrotext1", "/targetexact nil")
  row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, 0 })
  row.bg:SetAllPoints()
  -- 死刑名单标记：骷髅纹理，KOS 成员显示红色，否则隐藏
  row.dot = createTexture(row, "ARTWORK", C.red)
  row.dot:SetTexture("Interface\\AddOns\\TaoNiao\\Textures\\Icons\\skull.tga")
  row.dot:SetPoint("LEFT", 7, 0)
  row.dot:SetSize(11, 11)
  row.dot:Hide()
  row.name = createFont(row, 11, C.text, "", "medium")
  row.name:SetPoint("LEFT", 22, 0)
  row.name:SetPoint("RIGHT", row, "RIGHT", -60, 0)
  row.level = createFont(row, 10, C.text2, "", "medium")
  row.level:SetWidth(30)
  row.level:SetPoint("CENTER", row, "RIGHT", -50, 0)
  row.level:SetJustifyH("CENTER")
  row.class = createFont(row, 10, C.text, "", "bold")
  row.class:SetWidth(26)
  row.class:SetPoint("CENTER", row, "RIGHT", -22, 0)
  row.class:SetJustifyH("CENTER")
  row.classBox = createTexture(row, "BORDER", C.lineSoft)
  row.classBox:SetPoint("CENTER", row.class)
  row.classBox:SetSize(16, 16)
  row:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
    TN:ShowEnemyTooltip(self, true)
  end)
  row:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0)
    TN:ShowEnemyTooltip(self, false)
  end)
  row:SetScript("PreClick", function(self, button)
    if button == "LeftButton" and self.enemy then
      applyTargetAction(self, self.enemy)
    elseif button == "RightButton" and self.enemy then
      TN:ShowEnemyContextMenu(self.enemy)
    end
  end)
  row:Hide()
  return row
end

function TN:ShowEnemyTooltip(row, show)
  if not show then
    GameTooltip:Hide()
    return
  end
  local enemy = row and row.enemy
  if not enemy then return end
  local spyData = getSpyPlayerData(enemy.name)
  local classFile = enemy.classFile ~= "UNKNOWN" and enemy.classFile or (spyData and spyData.class)
  local class = self.classInfo[classFile or "UNKNOWN"] or self.classInfo.UNKNOWN
  local level = (enemy.level and type(enemy.level) == "number") and enemy.level or (spyData and spyData.level) or "??"

  GameTooltip:SetOwner(row, "ANCHOR_LEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine(enemy.name, class.color[1], class.color[2], class.color[3])
  local guild = enemy.guild or (spyData and spyData.guild)
  if guild and guild ~= "" then
    GameTooltip:AddLine(guild, C.green[1], C.green[2], C.green[3])
  end
  GameTooltip:AddLine("等级" .. tostring(level) .. " -职业：" .. (class.name or "未知"), C.text2[1], C.text2[2], C.text2[3])
  local wins, losses = enemy.myWins or 0, enemy.myLosses or 0
  local mu = (TN.db and TN.db.char and TN.db.char.matchups or {})[enemy.name]
  if mu then wins = mu.win or wins; losses = mu.loss or losses end
  GameTooltip:AddLine("胜: " .. wins .. "  负: " .. losses, C.text[1], C.text[2], C.text[3])
  local ago = formatSeenAgo(enemy.age)
  GameTooltip:AddLine(ago .. " 在 " .. (GetZoneText and GetZoneText() or "未知区域") .. " 遇到", C.text3[1], C.text3[2], C.text3[3])
  GameTooltip:Show()
end

function TN:UpdateEnemyList(stats)
  local list = self.list
  if not list then return end
  local enemies = stats.enemies
  local first = enemies[1]
  list.updated:SetText(first and ("更新: " .. math.floor(first.age or 0) .. "s 前") or "更新: --")
  local showTable = (stats.nearbyTotal or #enemies) > 0
  setShown(list.header, showTable)
  setShown(list.nameHead, showTable)
  setShown(list.levelHead, showTable)
  setShown(list.classHead, showTable)
  if not showTable then
    for i = 1, self.maxRows do
      list.rows[i].enemy = nil
      list.rows[i]._enemyGuid = nil
      applyTargetAction(list.rows[i], nil)
      list.rows[i]:Hide()
    end
    list:Hide()
    TN:LayoutPanelHeight()
    return
  end

  list:Show()
  local shown = 0
  local capacity = self:GetEnemyListCapacity()
  for _, enemy in ipairs(enemies) do
    if shown >= capacity then break end
    shown = shown + 1
    local row = list.rows[shown]
    -- 差量：同一敌人占位时只更新随年龄变化的透明度，跳过稳定的 name/level/class
    if row._enemyGuid == enemy.guid then
      row:SetAlpha(enemy.age > self.staleTTL and 0.42 or 1)
    else
      local class = self.classInfo[enemy.classFile or "UNKNOWN"] or self.classInfo.UNKNOWN
      row.enemy = enemy
      applyTargetAction(row, enemy)
      row.name:SetText(enemyListName(enemy))
      local lv = enemy.level or "??"
      row.level:SetText(tostring(lv))
      row.class:SetText(class.text)
      setColor(row.name, class.color)
      setColor(row.class, class.color)
      row:SetAlpha(enemy.age > self.staleTTL and 0.42 or 1)
      row._enemyGuid = enemy.guid
    end
    -- 死刑名单：显示红色骷髅图标，否则隐藏
    if enemy.isKOS then
      row.dot:Show()
      row.dot:SetVertexColor(C.red[1], C.red[2], C.red[3], 1)
    else
      row.dot:Hide()
    end
    row:Show()
  end
  for i = shown + 1, self.maxRows do
    list.rows[i].enemy = nil
    list.rows[i]._enemyGuid = nil
    applyTargetAction(list.rows[i], nil)
    list.rows[i]:Hide()
  end
  if not (self.list and self.list.isResizing) then
    self:SetEnemyListRowsHeight(shown)
  end
end
