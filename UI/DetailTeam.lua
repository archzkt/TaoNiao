--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailTeam.lua
-- 详情页 · 团队助手：队伍管理/权限管理/自动化开关 + HUD 快捷操作自定义网格。
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
local DetailWidgets = TN.DetailWidgets
local createDetailBox = DetailWidgets.createDetailBox
local createDetailDivider = DetailWidgets.createDetailDivider
local createDetailHeader = DetailWidgets.createDetailHeader
local createDetailInput = DetailWidgets.createDetailInput
local clearDetailMain = DetailWidgets.clearDetailMain
local addDetailFrame = DetailWidgets.addDetailFrame
local DETAIL_CONTENT_WIDTH = Theme.Layout.DETAIL_CONTENT_WIDTH

local TEAM_TOGGLE_DATA = {
  { key = "autoInvite",       label = "密语自动邀请", icon = "megaphone",  inputKey = "inviteKeyword",  inputPlaceholder = "加 1 进组" },
  { key = "autoConvertRaid",  label = "队满自动转团", icon = "portal",    inputKey = nil },
  { key = "autoPromote",      label = "新进队自动给A",  icon = "crosshair", inputKey = nil },
  { key = "autoFreeLoot",     label = "自动自由拾取", icon = "flag",      inputKey = nil },
}

local function createTeamToggle(parent, data, y)
  local db = TN.db and TN.db.profile and TN.db.profile.team or {}
  local isOn = db[data.key]

  local row = CreateFrame("Button", nil, parent)
  row:SetPoint("TOPLEFT", 14, y)
  row:SetPoint("TOPRIGHT", -14, y)
  row:SetHeight(36)

  row.bg = createTexture(row, "BACKGROUND", C.cell)
  row.bg:SetAllPoints()

  row.icon = createIcon(row, data.icon, 16, isOn and C.cyan or C.text3)
  row.icon:SetPoint("LEFT", 10, 0)
  row.label = createFont(row, 13, isOn and C.text or C.text3, "", "medium")
  row.label:SetPoint("LEFT", 28, 0)
  row.label:SetText(data.label)

  row.dot = createRoundedBlock(row, "ARTWORK", isOn and C.cyan or C.text3)
  row.dot:SetSize(10, 10)
  row.dot:SetPoint("RIGHT", -10, 0)

  if data.inputKey then
    local savedText = db[data.inputKey]
    row.input = createDetailInput(row, 180, data.inputPlaceholder or "")
    row.input:SetPoint("RIGHT", row.dot, "LEFT", -8, 0)
    row.input:SetHeight(24)
    if savedText and savedText ~= "" then
      row.input:SetText(savedText)
    end
    row.input:SetScript("OnTextChanged", function(self)
      local text = self:GetText() or ""
      setShown(self.placeholder, text == "")
      local teamDB = TN.db and TN.db.profile and TN.db.profile.team
      if teamDB then teamDB[data.inputKey] = text end
    end)
    row.input:SetScript("OnEnter", function() end)
    row.input:SetScript("OnLeave", function() end)
  end

  row:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
  end)
  row:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
  end)

  row:SetScript("OnClick", function()
    if row.input and row.input:HasFocus() then
      row.input:ClearFocus()
      return
    end
    local teamDB = TN.db and TN.db.profile and TN.db.profile.team
    if not teamDB then return end
    teamDB[data.key] = not teamDB[data.key]
    local nowOn = teamDB[data.key]
    row.icon:SetVertexColor(rgba(nowOn and C.cyan or C.text3))
    setColor(row.label, nowOn and C.text or C.text3)
    row.dot:SetVertexColor(rgba(nowOn and C.cyan or C.text3))
    TN:TeamToggleChanged(data.key, nowOn)
  end)

  return row
end

local function createTeamActionButton(parent, icon, label, iconColor, onClick, x, y, w, h, disabled, tooltip)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(w or 120, h or 32)
  btn:SetPoint("TOPLEFT", x, y)
  btn.bg = createTexture(btn, "BACKGROUND", C.cell)
  btn.bg:SetAllPoints()
  btn.icon = createIcon(btn, icon, 15, disabled and C.text3 or (iconColor or C.cyan))
  btn.icon:SetPoint("LEFT", 12, 0)
  btn.text = createFont(btn, 13, disabled and C.text3 or C.text, "", "medium")
  btn.text:SetPoint("LEFT", 30, 0)
  btn.text:SetText(label)

  if disabled then
    btn.bg:SetVertexColor(1, 1, 1, 0.015)
    btn:SetScript("OnEnter", function(self)
      if tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip, C.text3[1], C.text3[2], C.text3[3], C.text3[4], true)
        GameTooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  else
    btn:SetScript("OnEnter", function(self)
      self.bg:SetVertexColor(rgba(C.cellHi))
      self.icon:SetVertexColor(rgba(C.cyan))
      setColor(self.text, C.cyan)
    end)
    btn:SetScript("OnLeave", function(self)
      self.bg:SetVertexColor(rgba(C.cell))
      self.icon:SetVertexColor(rgba(iconColor or C.cyan))
      setColor(self.text, C.text)
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
  end
  return btn
end

function TN:RenderDetailTeam()
  local detail = self.detail
  clearDetailMain(detail)
  detail.teamFrame = detail.teamFrame or {}
  if detail.teamFrame.frame then
    detail.teamFrame.frame:Show()
    return
  end

  local frame = addDetailFrame(detail, CreateFrame("Frame", nil, detail.main))
  detail.teamFrame.frame = frame
  frame:SetAllPoints()

  local card = createDetailBox(frame, 0.40)
  card:SetPoint("TOPLEFT", 22, -20)
  card:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(card, "users", "团队助手")

  local innerW = DETAIL_CONTENT_WIDTH - 28
  local teamDB = self.db and self.db.profile and self.db.profile.team or {}
  local y = 0

  -- 内容区用裸 ScrollFrame，超长可滚动（不需要到顶/到底提示）
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
  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(innerW)
  scroll:SetScrollChild(content)

  -- ── 队伍管理区 ──
  local mgLabel = createFont(content, 12, C.text3, "", "medium")
  mgLabel:SetPoint("TOPLEFT", 16, y)
  mgLabel:SetText("队伍管理")
  y = y - 24

  local statusLine = createFont(content, 12, C.text3, "", "regular")
  statusLine:SetPoint("TOPLEFT", 16, y)
  statusLine:SetText("当前: " .. (IsInRaid() and "团队" or IsInGroup() and "小队" or "未组队"))
  y = y - 28

  local btnW4 = math.floor((innerW - 24) / 4)
  local inGroup = IsInGroup()
  local inRaid = IsInRaid()
  local savedMembers = teamDB.savedMembers or {}
  local isLeader = inRaid and (UnitIsGroupLeader and UnitIsGroupLeader("player") or false) or (inGroup and (UnitIsGroupLeader and UnitIsGroupLeader("player") or false))

  createTeamActionButton(content, "details", "保存队伍", C.blue,
    function() TN:TeamSaveMembers() end, 14, y, btnW4, 32,
    not inGroup, "需要先加入队伍")

  createTeamActionButton(content, "skull", "解散队伍", C.red,
    function() TN:TeamDisband() end, 14 + btnW4 + 8, y, btnW4, 32,
    not inGroup, "需要先加入队伍")

  createTeamActionButton(content, "portal", "恢复队伍", C.cyan,
    function() TN:TeamRestoreMembers() end, 14 + 2 * (btnW4 + 8), y, btnW4, 32,
    #savedMembers == 0, "没有保存的队伍成员")

  createTeamActionButton(content, "buoy", "清除记忆", C.orange,
    function() TN:TeamClearSaved() end, 14 + 3 * (btnW4 + 8), y, btnW4, 32,
    #savedMembers == 0, "没有保存的队伍成员")
  y = y - 40

  local announceLabel = createFont(content, 11, C.text3, "", "regular")
  announceLabel:SetPoint("TOPLEFT", 16, y)
  announceLabel:SetText("解散通告")
  y = y - 18
  local announceInput = createDetailInput(content, innerW, "留空使用默认：队伍即将解散，感谢各位！")
  announceInput:SetPoint("TOPLEFT", 14, y)
  announceInput:SetPoint("TOPRIGHT", -14, y)
  announceInput:SetHeight(24)
  local disbandMsg = teamDB.disbandMessage
  announceInput:SetText(disbandMsg and disbandMsg ~= "" and disbandMsg or "队伍即将解散，感谢各位！")
  announceInput:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    setShown(self.placeholder, text == "")
    local tDB = TN.db and TN.db.profile and TN.db.profile.team
    if tDB then tDB.disbandMessage = text end
  end)
  y = y - 32

  local savedLine = createFont(content, 12, C.text3, "", "regular")
  savedLine:SetPoint("TOPLEFT", 16, y)
  local savedInfo = #savedMembers > 0 and (#savedMembers .. " 人") or "无"
  if #savedMembers > 0 and teamDB.savedAt then
    savedInfo = savedInfo .. " · " .. (date("%m/%d %H:%M", teamDB.savedAt) or "")
  end
  savedLine:SetText("已保存: " .. savedInfo)
  y = y - 20
  if #savedMembers > 0 then
    local savedList = createFont(content, 11, C.text3, "", "regular")
    savedList:SetPoint("TOPLEFT", 16, y)
    savedList:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    savedList:SetWordWrap(true)
    savedList:SetJustifyH("LEFT")
    savedList:SetText(table.concat(savedMembers, " · "))
    y = y - 36
  end

  -- 恢复有效期
  local expireLabel = createFont(content, 11, C.text3, "", "regular")
  expireLabel:SetPoint("TOPLEFT", 16, y)
  expireLabel:SetText("恢复有效期（分钟，0=永不过期）")
  y = y - 22
  local expireInput = createDetailInput(content, 80, "")
  expireInput:SetPoint("TOPLEFT", 14, y)
  expireInput:SetHeight(24)
  expireInput:SetNumeric(true)
  expireInput:SetText(tostring(teamDB.restoreExpire or 30))
  expireInput:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    setShown(self.placeholder, text == "")
    local val = tonumber(text)
    if val then
      local tDB = TN.db and TN.db.profile and TN.db.profile.team
      if tDB then tDB.restoreExpire = val end
    end
  end)
  y = y - 32

  -- ── 分隔线 ──
  y = y - 6
  createDetailDivider(content, content, y)
  y = y - 20

  -- ── 权限管理区 ──
  local opLabel = createFont(content, 12, C.text3, "", "medium")
  opLabel:SetPoint("TOPLEFT", 16, y)
  opLabel:SetText("权限管理")
  y = y - 24

  local btnW = math.floor((innerW - 8) / 2)
  createTeamActionButton(content, "crosshair", "全团给A", C.green,
    function() TN:TeamPromoteAll() end, 14, y, btnW, 32,
    not inRaid, "仅团队模式可用")
  createTeamActionButton(content, "skull", "全团收A", C.red,
    function() TN:TeamDemoteAll() end, 14 + btnW + 8, y, btnW, 32,
    not inRaid, "仅团队模式可用")
  y = y - 48

  -- ── 分隔线 ──
  y = y - 6
  createDetailDivider(content, content, y)
  y = y - 20

  -- ── 自动化区 ──
  for i, data in ipairs(TEAM_TOGGLE_DATA) do
    createTeamToggle(content, data, y)
    y = y - 36 - 14
  end

  -- ── 分隔线 ──
  y = y - 6
  createDetailDivider(content, content, y)
  y = y - 20

  -- ── HUD 快捷操作自定义区 ──
  local qaLabel = createFont(content, 12, C.text3, "", "medium")
  qaLabel:SetPoint("TOPLEFT", 16, y)
  qaLabel:SetText("HUD 快捷操作（勾选显示在团队按钮）")
  y = y - 22

  local qaHint = createFont(content, 10, C.text3, "", "regular")
  qaHint:SetPoint("TOPLEFT", 16, y)
  qaHint:SetPoint("RIGHT", content, "RIGHT", -16, 0)
  qaHint:SetWordWrap(true)
  qaHint:SetText("最多 5 项；顺序即显示顺序；默认为 保存 / 解散 / 恢复。")
  y = y - 18

  teamDB.quickActions = teamDB.quickActions or { "save", "disband", "restore" }
  local qaOrder = { "save", "disband", "restore", "promoteAll", "demoteAll", "autoInvite", "convertRaid", "promote", "freeLoot" }
  local cols = 3
  local colGap = 12
  local rowGap = 8
  local rowH = 24
  local cellW = math.floor((innerW - colGap * (cols - 1)) / cols)
  for i, id in ipairs(qaOrder) do
    local def = TN.TEAM_QUICK_ACTIONS[id]
    if def then
      local r = math.floor((i - 1) / cols)
      local c = (i - 1) % cols
      local cellX = c * (cellW + colGap)
      local on = false
      for _, qid in ipairs(teamDB.quickActions) do if qid == id then on = true break end end
      local row = CreateFrame("Button", nil, content)
      row:SetSize(cellW, rowH)
      row:SetPoint("TOPLEFT", 16 + cellX, y - r * (rowH + rowGap))
      row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, 0 })
      row.bg:SetAllPoints()
      row.check = createRoundedBlock(row, "ARTWORK", on and C.cyan or C.text3)
      row.check:SetSize(9, 9)
      row.check:SetPoint("LEFT", 3, 0)
      row.label = createFont(row, 12, on and C.text or C.text2, "", "regular")
      row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
      row.label:SetWidth(cellW - 24)
      row.label:SetJustifyH("LEFT")
      row.label:SetText(def.label .. (def.kind == "toggle" and "（切换）" or ""))
      local function refreshRow()
        local nowOn = false
        for _, qid in ipairs(TN.db.profile.team.quickActions) do if qid == id then nowOn = true break end end
        row.check:SetVertexColor(rgba(nowOn and C.cyan or C.text3))
        setColor(row.label, nowOn and C.text or C.text2)
      end
      row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
      row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
      row:SetScript("OnClick", function()
        local qa = TN.db.profile.team.quickActions
        local found, pos
        for i2, qid in ipairs(qa) do if qid == id then found = true; pos = i2; break end end
        if found then
          table.remove(qa, pos)
          GameTooltip:Hide()
        else
          if #qa >= 5 then
            GameTooltip:SetOwner(row, "ANCHOR_TOP")
            GameTooltip:SetText("最多只能选择 5 个快捷操作", C.yellow[1], C.yellow[2], C.yellow[3], C.yellow[4], true)
            GameTooltip:Show()
            return
          end
          table.insert(qa, id)
          GameTooltip:Hide()
        end
        refreshRow()
        -- 如果 HUD 团队条正在显示，就地刷新内容
        if TN.hud and TN.hud.teamBar and TN.hud.teamBar:IsShown() then
          TN:BuildTeamMenuBar()
        end
      end)
    end
  end
  local rows = math.ceil(#qaOrder / cols)
  y = y - rows * (rowH + rowGap)

  -- 设置 content 高度，启用滚动
  content:SetHeight(-y + 20)

  frame:Show()
end
