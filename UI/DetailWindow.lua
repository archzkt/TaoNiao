--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailWindow.lua
-- 详情页窗口外壳：标题栏/品牌/tab/关闭按钮、侧栏导航、位置卡、视图分发。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local setShown = Theme.setShown
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local createRoundedBlock = Widgets.createRoundedBlock
local createPanel = Widgets.createPanel
local DetailWidgets = TN.DetailWidgets
local createDetailBox = DetailWidgets.createDetailBox
local createDetailDivider = DetailWidgets.createDetailDivider
local createDetailHeader = DetailWidgets.createDetailHeader
local createDetailButton = DetailWidgets.createDetailButton
local createDetailInput = DetailWidgets.createDetailInput
local clearDetailMain = DetailWidgets.clearDetailMain
local addDetailFrame = DetailWidgets.addDetailFrame
local Layout = Theme.Layout
local DETAIL_WIDTH = Layout.DETAIL_WIDTH
local DETAIL_HEIGHT = Layout.DETAIL_HEIGHT
local DETAIL_TITLE_HEIGHT = Layout.DETAIL_TITLE_HEIGHT
local DETAIL_SIDE_WIDTH = Layout.DETAIL_SIDE_WIDTH
local DETAIL_CONTENT_WIDTH = Layout.DETAIL_CONTENT_WIDTH

function TN:CreateDetailNavButton(parent, index, item)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(178, 44)
  btn:SetPoint("TOPLEFT", 14, -16 - (index - 1) * 48)
  btn.id = item.id
  btn.bg = createTexture(btn, "BACKGROUND", { 1, 1, 1, 0 })
  btn.bg:SetAllPoints()
  btn.accent = createRoundedBlock(btn, "ARTWORK", C.cyan)
  btn.accent:SetPoint("LEFT", 0, 0)
  btn.accent:SetSize(3, 26)
  btn.icon = createIcon(btn, item.icon, 19, C.text2)
  btn.icon:SetPoint("LEFT", 14, 0)
  btn.label = createFont(btn, 15, C.text2, "", "medium")
  btn.label:SetPoint("LEFT", 45, 0)
  btn.label:SetText(item.label)
  btn:SetScript("OnEnter", function(self)
    if self.id ~= TN.detailView then
      self.bg:SetVertexColor(rgba(C.cell))
      setColor(self.label, C.text)
    end
  end)
  btn:SetScript("OnLeave", function(self)
    TN:UpdateDetailNav()
  end)
  btn:SetScript("OnClick", function(self)
    TN:SetDetailView(self.id)
  end)
  return btn
end

function TN:UpdateDetailNav()
  local detail = self.detail
  if not detail or not detail.navButtons then return end
  for _, btn in ipairs(detail.navButtons) do
    local on = btn.id == self.detailView
    btn.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], on and 0.13 or 0)
    btn.accent:SetAlpha(on and 1 or 0)
    btn.icon:SetVertexColor(rgba(on and C.cyan or C.text2))
    setColor(btn.label, on and C.text or C.text2)
  end
end

function TN:RenderDetailSimple(view)
  local detail = self.detail
  clearDetailMain(detail)
  detail.simpleFrames = detail.simpleFrames or {}
  if detail.simpleFrames[view] then
    detail.simpleFrames[view]:Show()
    return
  end
  local data = TN.DetailData.SIMPLE_ROWS[view]
  local frame = addDetailFrame(detail, CreateFrame("Frame", nil, detail.main))
  detail.simpleFrames[view] = frame
  frame:SetAllPoints()
  local card = createDetailBox(frame, 0.40)
  card:SetPoint("TOPLEFT", 22, -20)
  card:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(card, data.icon, data.title)
  local lead = createFont(card, 12, C.text3)
  lead:SetPoint("TOPLEFT", 17, -42)
  lead:SetText("更多设置项规划中，敬请期待。")
  for i, rowData in ipairs(data.rows) do
    local row = createDetailBox(card, 0.28)
    row:SetPoint("TOPLEFT", 16, -78 - (i - 1) * 68)
    row:SetPoint("TOPRIGHT", -16, -78 - (i - 1) * 68)
    row:SetHeight(56)
    row.dot = createRoundedBlock(row, "ARTWORK", rowData[3])
    row.dot:SetPoint("LEFT", 16, 0)
    row.dot:SetSize(8, 28)
    row.title = createFont(row, 15, C.text, "OUTLINE", "bold")
    row.title:SetPoint("TOPLEFT", 36, -12)
    row.title:SetText(rowData[1])
    row.sub = createFont(row, 12, C.text2)
    row.sub:SetPoint("TOPLEFT", 36, -32)
    row.sub:SetText(rowData[2])
  end
  frame:Show()
end

-- 清空所有持久化数据（死刑名单/战斗明细/对手统计/公会胜负）
function TN:ClearAllData()
  local ch = self.db and self.db.char
  if not ch then return end
  ch.kosList = {}
  ch.battleLog = {}
  ch.matchups = {}
  ch.guildWL = {}
  ch.kills = 0; ch.deaths = 0; ch.killsToday = 0; ch.deathsToday = 0
  self:Print("|cffff4d4f已清空所有战斗与死刑名单数据。|r")
  if self.UpdateDetailHighRisk then self:UpdateDetailHighRisk() end
end

-- 从同级 Spy 插件迁移数据（死刑名单 + 玩家数据）
-- mode: "merge" 合并 / "overwrite" 覆盖
function TN:ImportSpyData(mode)
  mode = mode or "merge"
  if not SpyPerCharDB then
    if UIErrorsFrame then
      UIErrorsFrame:AddMessage("|cffff4d4f请先启用 Spy 插件，再点击迁移|r", 1, 0.3, 0.3, 1, 4)
    end
    self:Print("|cffff4d4f请先启用 Spy 插件，再点击迁移。|r")
    return
  end
  if not SpyPerCharDB.KOSData and not SpyPerCharDB.PlayerData then
    self:Print("Spy 插件数据为空，请先在 Spy 中累积一些侦测记录。")
    return
  end

  -- 覆盖模式：先清空现有数据
  if mode == "overwrite" then
    local ch = self.db.char
    if ch then
      ch.kosList = {}
      ch.matchups = {}
      ch.battleLog = {}
      ch.kills = 0
      ch.deaths = 0
      ch.spyImported = false
    end
  end

  local addedKOS = 0
  local addedPlayers = 0
  local totalWins = 0
  local totalLosses = 0

  -- 1. 迁移死刑名单
  if SpyPerCharDB.KOSData then
    local rows = self:GetDetailKOSData()
    local existing = {}
    for _, r in ipairs(rows) do existing[r.name] = true end
    local playerData = SpyPerCharDB.PlayerData or {}
    for name, _ in pairs(SpyPerCharDB.KOSData) do
      if not existing[name] then
        local pd = playerData[name]
        local classFile = pd and pd.class or "UNKNOWN"
        local ci = (self.classInfo and self.classInfo[classFile]) or (self.classInfo and self.classInfo.UNKNOWN)
        table.insert(rows, {
          name = name, cls = ci and ci.name or classFile,
          lv = (pd and pd.level) or "??",
          crime = "由 Spy 导入", win = 0, loss = 0,
          last = 0,  -- Spy 导入不记录实际时间
          zone = (pd and pd.zone) or "未知区域", tone = C.red,
        })
        existing[name] = true
        addedKOS = addedKOS + 1
      end
    end
  end

  -- 2. 迁移玩家数据到对手统计（含胜/负）
  if SpyPerCharDB.PlayerData then
    local mu = self.db.char.matchups or {}
    self.db.char.matchups = mu
    for name, pd in pairs(SpyPerCharDB.PlayerData) do
      local hasWL = (pd.wins and pd.wins > 0) or (pd.loses and pd.loses > 0)
      if hasWL then
        totalWins = totalWins + (pd.wins or 0)
        totalLosses = totalLosses + (pd.loses or 0)
      end
      if not mu[name] then
        local classFile = pd.class or "UNKNOWN"
        local ci = self.classInfo and self.classInfo[classFile]
        mu[name] = {
          cls = ci and ci.name or classFile,
          lv = pd.level or "??",
          guild = pd.guild or "",
          rank = pd.rank or "",
          win = pd.wins or 0,
          loss = pd.loses or 0,
          last = (pd.time and pd.time > 0) and pd.time or nil,
          zone = pd.zone or "未知区域",
        }
        addedPlayers = addedPlayers + 1
      else
        -- 更新已有记录
        if pd.level and tonumber(pd.level) then mu[name].lv = pd.level end
        if pd.guild and pd.guild ~= "" then mu[name].guild = pd.guild end
        if pd.wins then mu[name].win = math.max(mu[name].win or 0, pd.wins) end
        if pd.loses then mu[name].loss = math.max(mu[name].loss or 0, pd.loses) end
      end
    end
  end

  -- 累计击杀/死亡由胜负数据汇总得出
  -- 合并模式：仅首次计入，防重复累计
  -- 覆盖模式：直接设置为 Spy 汇总值
  local doAccum = (totalWins > 0 or totalLosses > 0)
  if doAccum then
    local ch = self.db.char
    if ch then
      if mode == "overwrite" then
        ch.kills = totalWins
        ch.deaths = totalLosses
      elseif not ch.spyImported then
        ch.kills = (ch.kills or 0) + totalWins
        ch.deaths = (ch.deaths or 0) + totalLosses
        ch.spyImported = true
      end
    end
  end

  local modeLabel = mode == "overwrite" and "覆盖" or "合并"
  local msg = ("|cff34c6e8[%s]|r KOS %d 人 · 玩家 %d 人 · 胜 %d 负 %d"):format(modeLabel, addedKOS, addedPlayers, totalWins, totalLosses)
  if UIErrorsFrame then
    UIErrorsFrame:AddMessage(msg, 0.2, 0.78, 0.91, 1, 5)
  end
  self:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
  if self.UpdateDetailHighRisk then self:UpdateDetailHighRisk() end
end

-- 设置页：界面设置 / 数据管理 / 命令 三块卡片
-- 设置页：统一风格（单卡片 + 分隔线，与团队助手等页一致）
function TN:RenderDetailSettings()
  local detail = self.detail
  clearDetailMain(detail)
  -- 不缓存，每次重新渲染（保证 HUD 菜单切换后状态同步）
  local frame = addDetailFrame(detail, CreateFrame("Frame", nil, detail.main))
  frame:SetAllPoints()

  local card = createDetailBox(frame, 0.40)
  card:SetPoint("TOPLEFT", 22, -20)
  card:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(card, "details", "设置")

  local innerW = DETAIL_CONTENT_WIDTH - 28
  local scroll = CreateFrame("ScrollFrame", nil, card)
  scroll:SetPoint("TOPLEFT", 12, -48)
  scroll:SetPoint("BOTTOMRIGHT", -12, 12)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local maxScroll = self:GetVerticalScrollRange() or 0
    if maxScroll <= 0 then return end
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * 28)))
  end)
  self.detail._settingsScroll = scroll
  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(innerW)
  scroll:SetScrollChild(content)
  local y = 0

  local p = self.db.profile
  local chr = self.db.char or {}
  local function sectionLabel(text)
    local lab = createFont(content, 12, C.text3, "", "medium")
    lab:SetPoint("TOPLEFT", 4, y)
    lab:SetText(text)
    y = y - 24
  end
  local function addDivider()
    y = y - 6
    createDetailDivider(content, content, y)
    y = y - 20
  end
  local function createToggle(label, getter, setter)
    local row = CreateFrame("Button", nil, content)
    row:SetPoint("TOPLEFT", 4, y)
    row:SetPoint("TOPRIGHT", -4, y)
    row:SetHeight(36)
    row.bg = createTexture(row, "BACKGROUND", C.cell)
    row.bg:SetAllPoints()
    local lab = createFont(row, 13, getter() and C.text or C.text3, "", "medium")
    lab:SetPoint("LEFT", 12, 0)
    lab:SetText(label)
    local dot = createRoundedBlock(row, "ARTWORK", getter() and C.cyan or C.text3)
    dot:SetSize(10, 10)
    dot:SetPoint("RIGHT", -10, 0)
    local function refresh()
      local on = getter()
      setColor(lab, on and C.text or C.text3)
      dot:SetVertexColor(rgba(on and C.cyan or C.text3))
    end
    row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
    row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(rgba(C.cell)) end)
    row:SetScript("OnClick", function()
      setter(not getter())
      refresh()
    end)
    y = y - 42
    return row
  end

  -- ── 界面设置 ──
  sectionLabel("界面设置")
  local alphaLabel = createFont(content, 12, C.text2, "", "medium")
  alphaLabel:SetPoint("TOPLEFT", 4, y)
  alphaLabel:SetText("面板不透明度")
  local function alphaText() return math.floor((self.db.profile.uiAlpha or 1) * 100) .. "%" end
  local alphaValue = createFont(content, 15, C.cyan, "", "number")
  alphaValue:SetPoint("LEFT", alphaLabel, "RIGHT", 14, 0)
  alphaValue:SetText(alphaText())
  local function adjustAlpha(delta)
    local a = math.max(0.3, math.min(1, (self.db.profile.uiAlpha or 1) + delta))
    self.db.profile.uiAlpha = a
    alphaValue:SetText(math.floor(a * 100) .. "%")
    self:ApplyUIAlpha()
  end
  local btnMinus = createDetailButton(content, "-", 34, function() adjustAlpha(-0.05) end)
  btnMinus:SetPoint("LEFT", alphaValue, "RIGHT", 10, 0)
  local btnPlus = createDetailButton(content, "+", 34, function() adjustAlpha(0.05) end)
  btnPlus:SetPoint("LEFT", btnMinus, "RIGHT", 6, 0)
  y = y - 30
  local alphaHint = createFont(content, 11, C.text3)
  alphaHint:SetPoint("TOPLEFT", 4, y)
  alphaHint:SetText("调整常驻面板背景透明度（30% - 100%）")
  y = y - 20
  addDivider()

  -- UI 缩放
  local scaleLabel = createFont(content, 12, C.text2, "", "medium")
  scaleLabel:SetPoint("TOPLEFT", 4, y)
  scaleLabel:SetText("面板缩放")
  local function scaleText() return math.floor((self.db.profile.scale or 1) * 100) .. "%" end
  local scaleValue = createFont(content, 15, C.cyan, "", "number")
  scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 14, 0)
  scaleValue:SetText(scaleText())
  local function adjustScale(delta)
    local s = math.max(0.7, math.min(1.5, (self.db.profile.scale or 1) + delta))
    self.db.profile.scale = s
    scaleValue:SetText(math.floor(s * 100) .. "%")
    if self.hud then self.hud:SetScale(s) end
  end
  local sMinus = createDetailButton(content, "-", 34, function() adjustScale(-0.05) end)
  sMinus:SetPoint("LEFT", scaleValue, "RIGHT", 10, 0)
  local sPlus = createDetailButton(content, "+", 34, function() adjustScale(0.05) end)
  sPlus:SetPoint("LEFT", sMinus, "RIGHT", 6, 0)
  y = y - 30
  local scaleHint = createFont(content, 11, C.text3)
  scaleHint:SetPoint("TOPLEFT", 4, y)
  scaleHint:SetText("调整常驻面板整体大小（70% - 150%）")
  y = y - 20
  -- 配色方案选择
  local schemeNames = {}
  local schemeOrder = {}
  for k, v in pairs(TN.Theme.Schemes) do
    schemeOrder[#schemeOrder + 1] = k
    schemeNames[k] = v.name
  end
  table.sort(schemeOrder)
  local schemeRow = CreateFrame("Button", nil, content)
  schemeRow:SetPoint("TOPLEFT", 4, y)
  schemeRow:SetPoint("TOPRIGHT", -4, y)
  schemeRow:SetHeight(36)
  schemeRow.bg = createTexture(schemeRow, "BACKGROUND", C.cell)
  schemeRow.bg:SetAllPoints()
  local schemeLabel = createFont(schemeRow, 13, C.text, "", "medium")
  schemeLabel:SetPoint("LEFT", 12, 0)
  schemeLabel:SetText("配色方案")
  local schemeValue = createFont(schemeRow, 13, C.cyan, "", "bold")
  schemeValue:SetPoint("RIGHT", -10, 0)
  schemeValue:SetText(schemeNames[p.colorScheme] or "默认经典")
  schemeRow:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
  schemeRow:SetScript("OnLeave", function(self) self.bg:SetVertexColor(rgba(C.cell)) end)
  schemeRow:SetScript("OnClick", function()
    local cur = p.colorScheme or "default"
    local nextIdx
    for i, k in ipairs(schemeOrder) do
      if k == cur then nextIdx = (i % #schemeOrder) + 1; break end
    end
    local nextScheme = schemeOrder[nextIdx or 1]
    local nextName = schemeNames[nextScheme] or nextScheme
    StaticPopupDialogs["TAONIAO_CONFIRM_SCHEME"] = {
      text = "|cff34c6e8配色方案将切换为 " .. nextName .. "|r|n界面重载后生效，是否立即重载？",
      button1 = "重载",
      button2 = "取消",
      OnAccept = function()
        TN:SetColorScheme(nextScheme)
        ReloadUI()
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("TAONIAO_CONFIRM_SCHEME")
  end)
  y = y - 42
  createToggle("呼吸灯特效", function() return p.threatBreathing == true end, function(v) p.threatBreathing = v; TN:MarkDirty() end)
  createToggle("副本内不启用", function() return p.disableInInstance == true end, function(v) p.disableInInstance = v end)
  createToggle("战场内不启用", function() return p.disableInBattleground == true end, function(v) p.disableInBattleground = v end)
  y = y - 4
  -- 通报设置
  addDivider()
  sectionLabel("通报设置")
  createToggle("自动通报", function() return p.autoAnnounce ~= false end, function(v) p.autoAnnounce = v end)
  -- 通报频道选择
  local chNames = { AUTO = "智能", PARTY = "小队", RAID = "团队", GUILD = "公会" }
  local chOrder = { "AUTO", "PARTY", "RAID", "GUILD" }
  local chRow = CreateFrame("Button", nil, content)
  chRow:SetPoint("TOPLEFT", 4, y)
  chRow:SetPoint("TOPRIGHT", -4, y)
  chRow:SetHeight(36)
  chRow.bg = createTexture(chRow, "BACKGROUND", C.cell)
  chRow.bg:SetAllPoints()
  local chLabel = createFont(chRow, 13, C.text, "", "medium")
  chLabel:SetPoint("LEFT", 12, 0)
  chLabel:SetText("通报频道")
  local chState = createFont(chRow, 13, C.cyan, "", "bold")
  chState:SetPoint("RIGHT", -10, 0)
  local function refreshChState()
    local cur = p.autoAnnounceChannel or "AUTO"
    chState:SetText(chNames[cur] or cur)
  end
  refreshChState()
  chRow:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
  chRow:SetScript("OnLeave", function(self) self.bg:SetVertexColor(rgba(C.cell)) end)
  chRow:SetScript("OnClick", function()
    local cur = p.autoAnnounceChannel or "AUTO"
    for i, v in ipairs(chOrder) do
      if v == cur then
        p.autoAnnounceChannel = chOrder[i % #chOrder + 1]
        break
      end
    end
    refreshChState()
  end)
  y = y - 42
  createToggle("仅通报见之必杀", function() return p.onlyAnnounceKoS == true end, function(v) p.onlyAnnounceKoS = v end)
  createToggle("飞行路线禁用", function() return p.stopAlertsOnTaxi ~= false end, function(v) p.stopAlertsOnTaxi = v end)
  y = y - 10
  local cdLabel = createFont(content, 12, C.text2, "", "medium")
  cdLabel:SetPoint("TOPLEFT", 4, y)
  cdLabel:SetText("重复通报冷却")
  local cdInput = createDetailInput(content, 50, "")
  cdInput:SetPoint("LEFT", cdLabel, "RIGHT", 14, 0)
  cdInput:SetText(p.announceCooldown == 0 and "" or tostring(p.announceCooldown or 15))
  local cdHintText = createFont(content, 12, C.text3, "", "medium")
  cdHintText:SetPoint("LEFT", cdInput, "RIGHT", 6, 0)
  cdHintText:SetText("秒（0=不限制）")
  cdInput:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    text = text:gsub("[^%d]", "")
    if text ~= self:GetText() then self:SetText(text) end
    setShown(self.placeholder, text == "")
    local v = tonumber(text)
    if v and v > 120 then
      self:SetText("120")
    end
  end)
  cdInput:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText()) or (p.announceCooldown or 15)
    v = math.max(0, math.min(120, v))
    p.announceCooldown = v
    self:SetText(v == 0 and "" or tostring(v))
    self:ClearFocus()
  end)
  cdInput:SetScript("OnEditFocusLost", function(self)
    local v = tonumber(self:GetText()) or (p.announceCooldown or 15)
    v = math.max(0, math.min(120, v))
    p.announceCooldown = v
    self:SetText(v == 0 and "" or tostring(v))
  end)
  y = y - 30
  local cdHint = createFont(content, 11, C.text3)
  cdHint:SetPoint("TOPLEFT", 4, y)
  cdHint:SetText("同一敌人两次通报最短间隔（0=不限制，最大120秒）")
  y = y - 20
  addDivider()

  -- ── 音效 ──
  sectionLabel("音效")
  local snd = p.sound or {}
  createToggle("启用音效", function() return snd.enabled ~= false end, function(v) snd.enabled = v end)
  createToggle("仅高危发声", function() return snd.onlyKOS == true end, function(v) snd.onlyKOS = v end)
  y = y - 4
  addDivider()

  -- ── 弹窗提醒 ──
  sectionLabel("弹窗提醒")
  -- Toast 不透明度
  local toastCfg = p.toast or {}
  local toastAlphaLabel = createFont(content, 12, C.text2, "", "medium")
  toastAlphaLabel:SetPoint("TOPLEFT", 4, y)
  toastAlphaLabel:SetText("弹窗不透明度")
  local toastAlphaValue = createFont(content, 15, C.cyan, "", "number")
  toastAlphaValue:SetPoint("LEFT", toastAlphaLabel, "RIGHT", 14, 0)
  toastAlphaValue:SetText(math.floor((toastCfg.alpha or 0.70) * 100) .. "%")
  local function adjustToastAlpha(delta)
    local a = math.max(0.2, math.min(1, (toastCfg.alpha or 0.70) + delta))
    toastCfg.alpha = a
    toastAlphaValue:SetText(math.floor(a * 100) .. "%")
    self:ApplyToastAlpha()
  end
  local taMinus = createDetailButton(content, "-", 34, function() adjustToastAlpha(-0.05) end)
  taMinus:SetPoint("LEFT", toastAlphaValue, "RIGHT", 10, 0)
  local taPlus = createDetailButton(content, "+", 34, function() adjustToastAlpha(0.05) end)
  taPlus:SetPoint("LEFT", taMinus, "RIGHT", 6, 0)
  y = y - 30
  -- Toast 位置：解锁/锁定
  local lockRow = CreateFrame("Frame", nil, content)
  lockRow:SetPoint("TOPLEFT", 4, y)
  lockRow:SetPoint("TOPRIGHT", -4, y)
  lockRow:SetHeight(36)
  local lockLabel = createFont(lockRow, 13, C.text, "", "medium")
  lockLabel:SetPoint("LEFT", 0, 0)
  lockLabel:SetText("弹窗位置")
  local unlockBtn = createDetailButton(lockRow, "解锁", 56, function()
    toastCfg.locked = false
    self:ShowToastPlaceholder()
    unlockBtn.text:SetText("已解锁")
    setColor(unlockBtn.text, C.cyan)
    lockBtn.text:SetText("锁定")
    setColor(lockBtn.text, C.text2)
  end)
  unlockBtn:SetPoint("RIGHT", -70, 0)
  local lockBtn = createDetailButton(lockRow, "锁定", 56, function()
    self:HideToastPlaceholder()
    unlockBtn.text:SetText("解锁")
    setColor(unlockBtn.text, C.text2)
    lockBtn.text:SetText("已锁定")
    setColor(lockBtn.text, C.cyan)
  end)
  lockBtn:SetPoint("RIGHT", -4, 0)
  y = y - 46
  addDivider()
  -- 弹窗类型开关
  local toastLabels = { stealth = "潜行敌人", rival = "见之必杀", matekill = "队友击杀", matedeath = "队友阵亡" }
  local toastOrder = { "stealth", "rival", "matekill", "matedeath" }
  local tf = p.toastFilters or {}
  for _, kind in ipairs(toastOrder) do
    local label = toastLabels[kind] or kind
    createToggle(label, function() return tf[kind] ~= false end, function(v) tf[kind] = v end)
  end
  y = y - 4
  addDivider()

  -- ── 数据管理 ──
  sectionLabel("数据管理")

  -- 导入 Spy
  local importRow = CreateFrame("Button", nil, content)
  importRow:SetPoint("TOPLEFT", 4, y)
  importRow:SetPoint("TOPRIGHT", -4, y)
  importRow:SetHeight(36)
  importRow.bg = createTexture(importRow, "BACKGROUND", C.cell)
  importRow.bg:SetAllPoints()
  importRow.label = createFont(importRow, 13, C.text, "", "medium")
  importRow.label:SetPoint("LEFT", 12, 0)
  importRow.label:SetText("迁移 Spy 插件数据")
  importRow.mergeBtn = createDetailButton(importRow, "合并", 50, function()
    self:ImportSpyData("merge")
    self:RenderDetailSettingsRefresh()
  end)
  importRow.mergeBtn:SetPoint("RIGHT", -70, 0)
  importRow.overwriteBtn = createDetailButton(importRow, "覆盖", 50, function()
    StaticPopupDialogs["TAONIAO_CONFIRM_OVERWRITE_SPY"] = {
      text = "|cffff4d4f覆盖模式将清空已有的死刑名单、对手统计和战斗记录，\n并以 Spy 数据重建！|r\n\n是否继续？",
      button1 = "确认覆盖", button2 = "取消",
      OnAccept = function()
        TN:ImportSpyData("overwrite")
        TN:RenderDetailSettingsRefresh()
      end,
      timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TAONIAO_CONFIRM_OVERWRITE_SPY")
  end)
  importRow.overwriteBtn:SetPoint("RIGHT", -10, 0)
  importRow.modeLabel = createFont(importRow, 11, C.text3, "", "regular")
  importRow.modeLabel:SetPoint("RIGHT", importRow.mergeBtn, "LEFT", -6, 0)
  importRow.modeLabel:SetText("模式:")
  importRow:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
  importRow:SetScript("OnLeave", function(self) self.bg:SetVertexColor(rgba(C.cell)) end)
  y = y - 42

  -- 清空战绩
  local function clearRow(iconName, label, countText, onClear, confirmText)
    local row = CreateFrame("Button", nil, content)
    row:SetPoint("TOPLEFT", 4, y)
    row:SetPoint("TOPRIGHT", -4, y)
    row:SetHeight(36)
    row.bg = createTexture(row, "BACKGROUND", C.cell)
    row.bg:SetAllPoints()
    row.icon = createIcon(row, iconName, 16, C.text3)
    row.icon:SetPoint("LEFT", 10, 0)
    row.lab = createFont(row, 13, C.text, "", "medium")
    row.lab:SetPoint("LEFT", 28, 0)
    row.lab:SetText(label)
    row.cnt = createFont(row, 13, C.text3, "", "medium")
    row.cnt:SetPoint("LEFT", row.lab, "RIGHT", 8, 0)
    row.cnt:SetText(countText)
    local btn = createDetailButton(row, "清空", 50, function()
      StaticPopupDialogs["TAONIAO_CONFIRM_CLEAR"] = {
        text = "|cffff4d4f确认清空" .. (confirmText or "数据") .. "？|r|n该操作不可撤销。",
        button1 = "清空", button2 = "取消",
        OnAccept = function() onClear(); self:RenderDetailSettingsRefresh() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
      }
      StaticPopup_Show("TAONIAO_CONFIRM_CLEAR")
    end)
    btn:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
    row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(rgba(C.cell)) end)
    y = y - 42
  end
  clearRow("skull", "今日战绩", (self.db.char.killsToday or 0) .. " 杀 · " .. (self.db.char.deathsToday or 0) .. " 死", function()
    local ch = self.db.char
    if ch then ch.killsToday = 0; ch.deathsToday = 0 end
    -- 删除今日战斗记录
    local bl = ch.battleLog or {}
    local todayStr = date and date("%Y%m%d")
    if todayStr then
      for i = #bl, 1, -1 do
        if bl[i].ts and bl[i].ts > 0 and date("%Y%m%d", bl[i].ts) == todayStr then table.remove(bl, i) end
      end
    end
    self:Print("已清空今日战绩。")
  end, "今日战绩")
  local ch = self.db.char or {}
  clearRow("skull", "总战绩", (ch.kills or 0) .. " 杀 · " .. (ch.deaths or 0) .. " 死 · " .. #(chr.battleLog or {}) .. " 条记录 · " .. #(chr.matchups or {}) .. " 人", function()
    chr.battleLog = {}
    chr.matchups = {}
    chr.guildWL = {}
    local ch = self.db.char
    if ch then ch.kills = 0; ch.deaths = 0 end
    self:Print("已清空总战绩。")
  end, "总战绩")
  clearRow("skull", "见之必杀", #(chr.kosList or {}) .. " 名", function()
    chr.kosList = {}
    self:Print("已清空见之必杀。")
  end, "见之必杀")
  y = y - 4
  local clearHint = createFont(content, 11, C.text3)
  clearHint:SetPoint("TOPLEFT", 4, y)
  clearHint:SetText("清空操作不可恢复，请谨慎使用")
  y = y - 20
  addDivider()

  -- ── 命令 ──
  sectionLabel("斜杠命令")
  local commands = {
    "/tn lock     锁定 / 解锁 HUD",
    "/tn reset    重置面板位置",
    "/tn clear    清空附近敌人列表",
    "/tn sound    开关音效告警",
    "/tn sound kos  仅高危（死刑/潜行）发声",
  }
  for i, cmd in ipairs(commands) do
    local line = createFont(content, 12, i % 2 == 0 and C.text2 or C.text, "", "medium")
    line:SetPoint("TOPLEFT", 8, y)
    line:SetText(cmd)
    y = y - 18
  end

  content:SetHeight(-y + 20)
  frame:Show()
end

-- 设置页刷新（清空数据/导入后）
function TN:RenderDetailSettingsRefresh()
  local oldScroll = self.detail and self.detail._settingsScroll
  local saved = oldScroll and oldScroll:GetVerticalScroll() or 0
  self:RenderDetailSettings()
  local newScroll = self.detail and self.detail._settingsScroll
  if newScroll and saved > 0 then
    local maxScroll = newScroll:GetVerticalScrollRange() or 0
    newScroll:SetVerticalScroll(math.min(saved, maxScroll))
  end
end

function TN:SetDetailView(view)
  -- 离开设置页时自动锁定 toast 位置
  if self.detailView == "settings" and view ~= "settings" then
    self:HideToastPlaceholder()
  end
  self.detailView = view or "records"
  if not self.detail then return end
  local titles = {
    records = "数据统计",
    highrisk = "见之必杀",
    phase = "位面助手",
    team = "团队助手",
    settings = "设置",
  }
  self.detail.title:SetText(titles[self.detailView] or "数据统计")
  setShown(self.detail.todayTab, self.detailView == "records")
  setShown(self.detail.historyTab, self.detailView == "records")
  setShown(self.detail.rankTab, self.detailView == "records")
  self:UpdateDetailNav()
  if self.detailView == "records" then
    self:RenderDetailRecords()
  elseif self.detailView == "highrisk" then
    self:RenderDetailHighRisk()
  elseif self.detailView == "phase" then
    self:RenderDetailPhase()
  elseif self.detailView == "team" then
    self:RenderDetailTeam()
  elseif self.detailView == "settings" then
    self:RenderDetailSettings()
  else
    self:RenderDetailSimple(self.detailView)
  end
end

function TN:CreateDetailWindow()
  if self.detail then
    self.detail:SetSize(DETAIL_WIDTH, DETAIL_HEIGHT)
    return
  end
  local detail = createPanel("TaoNiaoDetail", DETAIL_WIDTH, DETAIL_HEIGHT)
  self.detail = detail
  detail:SetFrameStrata("DIALOG")
  detail:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  detail:Hide()
  detail:SetBackdropColor(0.04, 0.06, 0.09, 0.94)

  detail.titlebar = CreateFrame("Frame", nil, detail)
  detail.titlebar:SetPoint("TOPLEFT")
  detail.titlebar:SetPoint("TOPRIGHT")
  detail.titlebar:SetHeight(DETAIL_TITLE_HEIGHT)
  detail.titlebar.bg = createTexture(detail.titlebar, "BACKGROUND", { 1, 1, 1, 0.025 })
  detail.titlebar.bg:SetAllPoints()
  createDetailDivider(detail.titlebar, detail.titlebar, -DETAIL_TITLE_HEIGHT)
  detail.titlebar:EnableMouse(true)
  detail.titlebar:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not TN.db.profile.locked then
      detail:StartMoving()
      detail.isMoving = true
    end
  end)
  detail.titlebar:SetScript("OnMouseUp", function()
    if detail.isMoving then
      detail:StopMovingOrSizing()
      detail.isMoving = false
    end
  end)

  detail.brandBox = createDetailBox(detail.titlebar, 0.36)
  detail.brandBox:SetSize(40, 40)
  detail.brandBox:SetPoint("LEFT", 22, 0)
  detail.brandIcon = createIcon(detail.brandBox, "crosshair", 24, C.cyan)
  detail.brandIcon:SetPoint("CENTER")
  detail.brand = createFont(detail.titlebar, 20, C.text, "OUTLINE", "number")
  detail.brand:SetPoint("TOPLEFT", detail.brandBox, "TOPRIGHT", 13, -3)
  detail.brand:SetText("TAONIAO")
  detail.sub = createFont(detail.titlebar, 12, C.text2)
  detail.sub:SetPoint("TOPLEFT", detail.brand, "BOTTOMLEFT", 0, -3)
   detail.sub:SetText("掏鸟开放世界PVP助手")

  detail.title = createFont(detail.titlebar, 15, C.text, "", "medium")
  detail.title:SetPoint("LEFT", DETAIL_SIDE_WIDTH + 18, 0)
  detail.title:SetText("数据统计")
  detail.todayTab = CreateFrame("Button", nil, detail.titlebar, "BackdropTemplate")
  detail.todayTab:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  detail.todayTab:SetSize(88, 32)
  detail.todayTab:SetPoint("LEFT", detail.title, "RIGHT", 12, 0)
  detail.todayTab:SetBackdropColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.12)
  detail.todayTab:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.45)
  detail.todayTab.text = createFont(detail.todayTab, 13, C.cyan, "", "medium")
  detail.todayTab.text:SetPoint("CENTER")
  detail.todayTab.text:SetText("今日战绩")
  detail.todayTab:SetScript("OnClick", function() TN:SetDetailRecordTab("today") end)
  detail.historyTab = CreateFrame("Button", nil, detail.titlebar, "BackdropTemplate")
  detail.historyTab:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  detail.historyTab:SetSize(88, 32)
  detail.historyTab:SetPoint("LEFT", detail.todayTab, "RIGHT", 6, 0)
  detail.historyTab:SetBackdropColor(C.panel2[1], C.panel2[2], C.panel2[3], 0.16)
  detail.historyTab:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.10)
  detail.historyTab.text = createFont(detail.historyTab, 13, C.text2, "", "medium")
  detail.historyTab.text:SetPoint("CENTER")
  detail.historyTab.text:SetText("总战绩")
  detail.historyTab:SetScript("OnClick", function() TN:SetDetailRecordTab("history") end)
  detail.rankTab = CreateFrame("Button", nil, detail.titlebar, "BackdropTemplate")
  detail.rankTab:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  detail.rankTab:SetSize(88, 32)
  detail.rankTab:SetPoint("LEFT", detail.historyTab, "RIGHT", 6, 0)
  detail.rankTab:SetBackdropColor(C.panel2[1], C.panel2[2], C.panel2[3], 0.16)
  detail.rankTab:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.10)
  detail.rankTab.text = createFont(detail.rankTab, 13, C.text2, "", "medium")
  detail.rankTab.text:SetPoint("CENTER")
  detail.rankTab.text:SetText("排行榜")
  detail.rankTab:SetScript("OnClick", function() TN:SetDetailRecordTab("rank") end)

  detail.close = CreateFrame("Button", nil, detail.titlebar)
  detail.close:SetSize(34, 34)
  detail.close:SetPoint("RIGHT", -18, 0)
  detail.close.bg = createTexture(detail.close, "BACKGROUND", C.cell)
  detail.close.bg:SetAllPoints()
  detail.close.text = createFont(detail.close, 16, C.text2, "OUTLINE", "bold")
  detail.close.text:SetPoint("CENTER")
  detail.close.text:SetText("X")
  detail.close:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(C.red[1], C.red[2], C.red[3], 0.12)
    setColor(self.text, C.red)
  end)
  detail.close:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
    setColor(self.text, C.text2)
  end)
  detail.close:SetScript("OnClick", function() self:HideToastPlaceholder(); detail:Hide() end)

  detail.sidebar = CreateFrame("Frame", nil, detail)
  detail.sidebar:SetPoint("TOPLEFT", 0, -DETAIL_TITLE_HEIGHT)
  detail.sidebar:SetPoint("BOTTOMLEFT")
  detail.sidebar:SetWidth(DETAIL_SIDE_WIDTH)
  detail.sidebar.bg = createTexture(detail.sidebar, "BACKGROUND", { 1, 1, 1, 0.018 })
  detail.sidebar.bg:SetAllPoints()
  detail.sidebar.line = createTexture(detail.sidebar, "ARTWORK", C.lineSoft)
  detail.sidebar.line:SetPoint("TOPRIGHT")
  detail.sidebar.line:SetPoint("BOTTOMRIGHT")
  detail.sidebar.line:SetWidth(1)
  detail.navButtons = {}
  for i, item in ipairs(TN.DetailData.NAV) do
    detail.navButtons[i] = self:CreateDetailNavButton(detail.sidebar, i, item)
  end
  detail.sideSep = createTexture(detail.sidebar, "ARTWORK", C.lineSoft)
  detail.sideSep:SetPoint("TOPLEFT", 18, -270)
  detail.sideSep:SetPoint("TOPRIGHT", -18, -270)
  detail.sideSep:SetHeight(1)
  detail.locCard = createDetailBox(detail.sidebar, 0.28)
  detail.locCard:SetPoint("TOPLEFT", 18, -292)
  detail.locCard:SetPoint("TOPRIGHT", -18, -292)
  detail.locCard:SetHeight(94)
  detail.locLabel = createFont(detail.locCard, 11, C.text3, "", "medium")
  detail.locLabel:SetPoint("TOP", 0, -13)
  detail.locLabel:SetText("当前位置")
  detail.locZone = createFont(detail.locCard, 18, C.text, "OUTLINE", "bold")
  detail.locZone:SetPoint("TOP", -34, -32)
  detail.locZone:SetText("荆棘谷")
  detail.locPhase = createFont(detail.locCard, 15, C.cyan, "OUTLINE", "bold")
  detail.locPhase:SetPoint("LEFT", detail.locZone, "RIGHT", 9, 0)
  detail.locPhase:SetText("位面 1")
  detail.locCoord = createFont(detail.locCard, 13, C.cyan, "", "medium")
  detail.locCoord:SetPoint("BOTTOM", 0, 12)
  detail.locCoord:SetText("坐标 44.6 , 12.1")

  detail.main = CreateFrame("Frame", nil, detail)
  detail.main:SetPoint("TOPLEFT", DETAIL_SIDE_WIDTH, -DETAIL_TITLE_HEIGHT)
  detail.main:SetPoint("BOTTOMRIGHT")
  self:SetDetailView("records")
end

function TN:ToggleDetailWindow()
  if not self.detail then
    self:CreateDetailWindow()
  end
  if self.detail:IsShown() then
    self:HideToastPlaceholder()
    self.detail:Hide()
  else
    self.detail:Show()
    self:SetDetailView(self.detailView or "records")
    self:UpdateLocation()
  end
end
