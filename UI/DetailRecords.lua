--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailRecords.lua
-- 详情页 · 数据统计：今日/历史 统计卡 + 战斗明细表 + 历史对手档案 + 子 tab 切换。
-- 暂用 mock 数据（Phase 4 接真实数据）。从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local setShown = Theme.setShown
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createFont = Widgets.createFont
local createIcon = Widgets.createIcon
local DetailWidgets = TN.DetailWidgets
local createDetailBox = DetailWidgets.createDetailBox
local createDetailHeader = DetailWidgets.createDetailHeader
local createDetailInput = DetailWidgets.createDetailInput
local clearDetailMain = DetailWidgets.clearDetailMain
local addDetailFrame = DetailWidgets.addDetailFrame
local Data = TN.DetailData
local classColor = Data.classColor
local classText = Data.classText
local DETAIL_WIDTH = Theme.Layout.DETAIL_WIDTH
local DETAIL_SIDE_WIDTH = Theme.Layout.DETAIL_SIDE_WIDTH
local DETAIL_CONTENT_WIDTH = Theme.Layout.DETAIL_CONTENT_WIDTH

-- 真实数据访问
function TN:GetBattleLog()
  return (self.db and self.db.char and self.db.char.battleLog) or {}
end

local function matchupList(self)
  local mu = (self.db and self.db.char and self.db.char.matchups) or {}
  local list = {}
  for name, m in pairs(mu) do
    local last = "—"
    if m.last and m.last > 0 and time then
      local dt = time() - m.last
      if dt < 60 then last = math.floor(dt) .. "s"
      elseif dt < 3600 then last = math.floor(dt / 60) .. "m"
      elseif dt < 86400 then last = math.floor(dt / 3600) .. "h"
      else last = math.floor(dt / 86400) .. "d" end
    end
    -- 军衔号转名称
    local rankName = ""
    if m.rank and type(m.rank) == "number" and m.rank > 0 then
      if GetPVPRankInfo then rankName = (GetPVPRankInfo(m.rank)) or "" end
    elseif m.rank and type(m.rank) == "string" and m.rank ~= "" then
      rankName = m.rank
    end
    list[#list + 1] = {
      name = name, cls = m.cls or "UNKNOWN", lv = m.lv or "??",
      guild = m.guild or "", rank = rankName,
      win = m.win or 0, loss = m.loss or 0,
      last = last, lastTs = m.last or 0, zone = m.zone or "未知区域",
    }
  end
  table.sort(list, function(a, b) return (a.lastTs or 0) > (b.lastTs or 0) end)
  return list
end

function TN:GetHistoryStats()
  local char = (self.db and self.db.char) or {}
  local p = (self.db and self.db.profile) or {}
  local kills = char.kills or 0
  local deaths = char.deaths or 0
  local total = kills + deaths
  local winrate = total > 0 and math.floor(kills / total * 100) or 0
  local honorKills = 0
  if GetPVPLifetimeStats then honorKills = (select(1, GetPVPLifetimeStats())) or 0 end
  return {
    { label = "累计击杀", value = tostring(kills), sub = "", color = C.green },
    { label = "累计死亡", value = tostring(deaths), sub = "", color = C.red },
    { label = "荣誉击杀", value = tostring(honorKills), sub = "", color = C.cyan },
    { label = "总胜率", value = winrate .. "%", sub = "", color = C.purple },
  }
end

function TN:CreateDetailStat(parent, index, stat, total)
  local gap = 12
  total = total or 4
  local width = math.floor((DETAIL_WIDTH - DETAIL_SIDE_WIDTH - 44 - gap * (total - 1)) / total)
  local compact = total >= 5
  local cell = createDetailBox(parent, 0.42)
  cell:SetSize(width, 68)
  cell:SetPoint("TOPLEFT", 22 + (index - 1) * (width + gap), -20)
  cell.iconBox = nil
  cell.icon = nil
  cell.label = createFont(cell, compact and 11 or 12, C.text2, "", "bold")
  cell.label:SetPoint("TOPLEFT", 10, -10)
  cell.label:SetText(stat.label)
  cell.value = createFont(cell, compact and 20 or 22, stat.color, "", "number")
  cell.value:SetPoint("TOP", 0, -28)
  cell.value:SetJustifyH("CENTER")
  cell.value:SetWidth(width - 16)
  cell.value:SetText(stat.value)
  cell.sub = createFont(cell, compact and 11 or 12, C.text3)
  cell.sub:SetPoint("TOPLEFT", 14, -55)
  cell.sub:SetText(stat.sub)
  return cell
end

function TN:CreateDetailTableHeader(parent, labels, y, startX)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", 12, y)
  row:SetPoint("TOPRIGHT", -12, y)
  row:SetHeight(28)
  row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, 0.025 })
  row.bg:SetAllPoints()
  local x = startX or 12
  for _, col in ipairs(labels) do
    local sortKey = col.sortKey
    local onClick = col.onClick
    local parentFrame = row
    if sortKey or onClick then
      parentFrame = CreateFrame("Button", nil, row)
      parentFrame:SetPoint("LEFT", x, 0)
      parentFrame:SetSize(col.w, 28)
    end
    local fs = createFont(parentFrame, 11, C.text3, "", "medium")
    fs:SetPoint("LEFT", (sortKey or onClick) and 0 or x, 0)
    fs:SetWidth(col.w)
    fs:SetJustifyH("LEFT")
    fs:SetText(col.t)
    if sortKey or onClick then
      parentFrame.text = fs
      parentFrame:SetScript("OnEnter", function(self) setColor(self.text, C.cyan) end)
      parentFrame:SetScript("OnLeave", function(self) setColor(self.text, C.text3) end)
      parentFrame:SetScript("OnClick", onClick or function() TN:SortDetailKOS(sortKey) end)
    end
    x = x + col.w
  end
  return row
end

function TN:CreateDetailBattleRow(parent, index, data)
  local row = CreateFrame("Button", nil, parent)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetPoint("TOPLEFT", 0, -(index - 1) * 36)
  row:SetPoint("TOPRIGHT", 0, -(index - 1) * 36)
  row:SetHeight(34)
  row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, index % 2 == 0 and 0.02 or 0.04 })
  row.bg:SetAllPoints()
  local resultColor = data.result == "击杀" and C.green or C.red
  local cols = {
    { data.t, 78, C.text2, "LEFT" },
    { data.result, 84, resultColor, "LEFT" },
    { data.name, 170, classColor(data.cls), "LEFT" },
    { tostring(data.lv), 70, C.text2, "LEFT" },
    { classText(data.cls), 70, classColor(data.cls), "CENTER", true },
    { data.zone, 170, C.text2, "LEFT" },
  }
  local x = 12
  for _, col in ipairs(cols) do
    if col[5] then
      local box = createTexture(row, "BORDER", C.lineSoft)
      box:SetPoint("LEFT", x, 0)
      box:SetSize(20, 20)
    end
    local fs = createFont(row, 12, col[3], "", "medium")
    fs:SetPoint("LEFT", x, 0)
    fs:SetWidth(col[5] and 20 or col[2])
    fs:SetJustifyH(col[5] and "CENTER" or col[4])
    fs:SetText(col[1])
    x = x + col[2]
  end
  row:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
    if self.data then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:ClearLines()
      local cc = classColor(self.data.cls)
      GameTooltip:AddLine(self.data.name or "", cc[1], cc[2], cc[3])
      if self.data.guild and self.data.guild ~= "" then
        GameTooltip:AddLine(self.data.guild, C.green[1], C.green[2], C.green[3])
      end
      GameTooltip:AddLine("等级" .. (self.data.lv or "??") .. " -职业：" .. (self.data.cls or "未知"), C.text2[1], C.text2[2], C.text2[3])
      if self.data.result == "胜" then
        GameTooltip:AddLine("胜: 1  负: 0", C.text[1], C.text[2], C.text[3])
      else
        GameTooltip:AddLine("胜: 0  负: 1", C.text[1], C.text[2], C.text[3])
      end
      GameTooltip:AddLine((self.data.t or "") .. " 在 " .. (self.data.zone or "未知区域") .. " 遇到", C.text3[1], C.text3[2], C.text3[3])
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function(self)
    local parity = self.displayIndex or index
    self.bg:SetVertexColor(1, 1, 1, parity % 2 == 0 and 0.02 or 0.04)
    GameTooltip:Hide()
  end)
  row:SetScript("PreClick", function(self, button)
    if button == "RightButton" and self.data then
      TN:ShowDetailRecordContextMenu(self.data)
    end
  end)
  return row
end

function TN:SortDetailHistory(key)
  if self.detailHistorySortKey == key then
    self.detailHistorySortAsc = not self.detailHistorySortAsc
  else
    self.detailHistorySortKey = key
    self.detailHistorySortAsc = false
  end
  self:UpdateDetailHistoryList()
end

function TN:UpdateDetailBattleList()
  local detail = self.detail
  if not detail then return end
  local query = detail.battleSearch and detail.battleSearch:GetText() or ""
  local allData = self:GetBattleLog()
  -- 今日tab只显示今日记录
  if self.detailRecordTab == "today" then
    local startOfToday
    if date and time then local d = date("*t"); d.hour = 0; d.min = 0; d.sec = 0; startOfToday = time(d) end
    if startOfToday then
      local filtered = {}
      for _, d in ipairs(allData) do
        if (d.ts or 0) >= startOfToday then filtered[#filtered + 1] = d end
      end
      allData = filtered
    end
  end
  if query ~= "" then
    local filtered = {}
    for _, d in ipairs(allData) do
      if d.name and d.name:find(query, 1, true) then filtered[#filtered + 1] = d end
    end
    allData = filtered
  end
  local scroll = detail.battleScroll
  if detail.battleContent then detail.battleContent:SetHeight(#allData * 36) end
  if scroll then
    scroll._data = allData
    scroll:SetVerticalScroll(0)
    if scroll._refresh then scroll._refresh() end
  end
  if detail.battleFoot then
    detail.battleFoot:SetText("共 " .. tostring(#allData) .. " 条记录，最多500条")
  end
end

function TN:UpdateDetailHistoryList()
  local detail = self.detail
  if not detail then return end
  local query = detail.historySearch and detail.historySearch:GetText() or ""
  -- 搜索/排序走数据层，不走行层
  local allData = matchupList(self)
  if query ~= "" then
    local filtered = {}
    for _, d in ipairs(allData) do
      if d.name and d.name:find(query, 1, true) then filtered[#filtered + 1] = d end
    end
    allData = filtered
  end
  if self.historyFilterWinLoss then
    local filtered = {}
    for _, d in ipairs(allData) do
      if (d.win or 0) > 0 or (d.loss or 0) > 0 then filtered[#filtered + 1] = d end
    end
    allData = filtered
  end
  local sortKey = self.detailHistorySortKey or "recent"
  local asc = self.detailHistorySortAsc
  table.sort(allData, function(a, b)
    local av, bv
    if sortKey == "win" then av, bv = a.win or 0, b.win or 0
    elseif sortKey == "loss" then av, bv = a.loss or 0, b.loss or 0
    else av, bv = a.lastTs or 0, b.lastTs or 0 end
    if av == bv then return tostring(a.name or "") < tostring(b.name or "") end
    if asc then return av < bv end
    return av > bv
  end)
  -- 更新 content 高度和 data 引用
  local scroll = detail.historyScroll
  if detail.historyContent then detail.historyContent:SetHeight(#allData * 36) end
  if scroll then
    scroll._data = allData
    scroll:SetVerticalScroll(0)
    if scroll._refresh then scroll._refresh() end
  end
  if detail.historyFoot then
    detail.historyFoot:SetText("共 " .. tostring(#allData) .. " 名玩家")
  end
end

function TN:RenderDetailRecords()
  local detail = self.detail
  clearDetailMain(detail)
  local frame = addDetailFrame(detail, CreateFrame("Frame", nil, detail.main))
  detail.records = frame
  frame:SetAllPoints()
  frame.today = CreateFrame("Frame", nil, frame)
  frame.today:SetAllPoints()
  frame.history = CreateFrame("ScrollFrame", nil, frame)
  frame.history:SetAllPoints()
  frame.history:EnableMouseWheel(true)
  local histContent = CreateFrame("Frame", nil, frame.history)
  histContent:SetWidth(DETAIL_WIDTH - DETAIL_SIDE_WIDTH)
  frame.history:SetScrollChild(histContent)
  frame.history:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local maxScroll = self:GetVerticalScrollRange() or 0
    if maxScroll > 0 then self:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * 28))) end
  end)
  frame.rank = CreateFrame("Frame", nil, frame)
  frame.rank:SetAllPoints()

  frame.stats = {}
  local stats = self:GetStats()
  local todayKills = stats.kills or 0
  local todayDeaths = stats.deaths or 0
  local todayPlayers = 0
  local startOfToday
  if date and time then local d = date("*t"); d.hour = 0; d.min = 0; d.sec = 0; startOfToday = time(d) end
  local log = self:GetBattleLog()
  if startOfToday then
    local seen = {}
    for _, r in ipairs(log) do
      if (r.ts or 0) >= startOfToday and r.name and not seen[r.name] then
        seen[r.name] = true; todayPlayers = todayPlayers + 1
      end
    end
  else todayPlayers = stats.enemyTotal or 0 end
  local honorKills = 0
  if GetPVPSessionStats then honorKills = (select(1, GetPVPSessionStats())) or 0 end
  local totalBattles = todayKills + todayDeaths
  local todayWinrate = totalBattles > 0 and math.floor(todayKills / totalBattles * 100) or 0
  local todayStats = {}
  for i, stat in ipairs(Data.TODAY_STATS) do
    local value = ""
    if stat.key == "kills" then value = tostring(todayKills)
    elseif stat.key == "deaths" then value = tostring(todayDeaths)
    elseif stat.key == "players" then value = tostring(todayPlayers)
    elseif stat.key == "honor" then value = tostring(honorKills)
    elseif stat.key == "winrate" then value = todayWinrate .. "%" end
    todayStats[i] = { label = stat.label, value = value, sub = "", color = stat.color }
  end
  for i, stat in ipairs(todayStats) do
    frame.stats[i] = self:CreateDetailStat(frame.today, i, stat, #todayStats)
  end

  local card = createDetailBox(frame.today, 0.40)
  card:SetPoint("TOPLEFT", 22, -98)
  card:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(card, "details", "明细数据")
  detail.battleSearch = createDetailInput(card, 176, "搜索玩家名")
  detail.battleSearch:SetPoint("TOPRIGHT", -16, -10)
  detail.battleSearch:SetScript("OnTextChanged", function(self)
    setShown(self.placeholder, (self:GetText() or "") == "")
    TN:UpdateDetailBattleList()
  end)
  self:CreateDetailTableHeader(card, {
    { t = "时间", w = 78 }, { t = "结果", w = 84 }, { t = "敌方玩家", w = 150 },
    { t = "公会", w = 110 }, { t = "等级", w = 64 }, { t = "职业", w = 64 }, { t = "地点", w = 150 },
  }, -58, 12)
  local scroll = self:CreateDetailScroll(card, 12, -92, -12, 42)
  detail.battleScroll = scroll
  local battleLog = self:GetBattleLog()
  local content = CreateFrame("Frame", nil, scroll)
  detail.battleContent = content
  content:SetSize(DETAIL_CONTENT_WIDTH, #battleLog * 36)
  scroll:SetScrollChild(content)

  -- 虚拟滚动：战斗记录
  local battlePoolSize = 20
  detail.battleRows = {}
  for i = 1, battlePoolSize do
    local row = CreateFrame("Button", nil, content)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHeight(34)
    row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, 0 })
    row.bg:SetAllPoints()
    row.tCol = createFont(row, 12, C.text2, "", "medium")
    row.tCol:SetPoint("LEFT", 12, 0)
    row.tCol:SetWidth(78)
    row.resCol = createFont(row, 12, C.text2, "", "medium")
    row.resCol:SetPoint("LEFT", 12 + 78, 0)
    row.resCol:SetWidth(84)
    row.nameCol = createFont(row, 12, C.text, "", "medium")
    row.nameCol:SetPoint("LEFT", 12 + 78 + 84, 0)
    row.nameCol:SetWidth(150)
    row.guildCol = createFont(row, 12, C.text3, "", "medium")
    row.guildCol:SetPoint("LEFT", 12 + 78 + 84 + 150, 0)
    row.guildCol:SetWidth(110)
    row.lvCol = createFont(row, 12, C.text2, "", "medium")
    row.lvCol:SetPoint("LEFT", 12 + 78 + 84 + 150 + 110, 0)
    row.lvCol:SetWidth(64)
    row.clsBox = createTexture(row, "BORDER", C.lineSoft)
    row.clsBox:SetPoint("LEFT", 12 + 78 + 84 + 150 + 110 + 64, 0)
    row.clsBox:SetSize(20, 20)
    row.clsCol = createFont(row, 12, C.text, "", "bold")
    row.clsCol:SetPoint("LEFT", 12 + 78 + 84 + 150 + 110 + 64, 0)
    row.clsCol:SetWidth(20)
    row.clsCol:SetJustifyH("CENTER")
    row.zoneCol = createFont(row, 12, C.text2, "", "medium")
    row.zoneCol:SetPoint("LEFT", 12 + 78 + 84 + 150 + 110 + 64 + 64, 0)
    row.zoneCol:SetWidth(150)
    row:SetScript("OnEnter", function(self)
      self.bg:SetVertexColor(rgba(C.cellHi))
      if self.data then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local cc = classColor(self.data.cls)
        GameTooltip:AddLine(self.data.name or "", cc[1], cc[2], cc[3])
        local info = (self.data.lv or "??") .. " · " .. (self.data.cls or "")
        if self.data.guild and self.data.guild ~= "" then
          info = info .. " · " .. self.data.guild
        end
        GameTooltip:AddLine(info, C.text2[1], C.text2[2], C.text2[3])
        local rc = self.data.result == "胜" and C.green or C.red
        GameTooltip:AddDoubleLine("结果", self.data.result or "", 1, 1, 1, rc[1], rc[2], rc[3])
        GameTooltip:AddDoubleLine("地点", self.data.zone or "", 1, 1, 1, C.text3[1], C.text3[2], C.text3[3])
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function(self)
      self.bg:SetVertexColor(1, 1, 1, self._alpha or 0)
      GameTooltip:Hide()
    end)
    row:SetScript("PreClick", function(self, button)
      if button == "RightButton" and self.data then
        TN:ShowDetailRecordContextMenu(self.data)
      end
    end)
    detail.battleRows[i] = row
  end
  local function refreshBattle()
    if not scroll then return end
    local data = scroll._data or battleLog
    local offset = scroll:GetVerticalScroll() or 0
    local rowH = 36
    local firstIdx = math.floor(offset / rowH) + 1
    for i = 1, battlePoolSize do
      local row = detail.battleRows[i]
      local dataIdx = firstIdx + i - 1
      local d = data[dataIdx]
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(dataIdx - 1) * rowH)
      row:SetPoint("TOPRIGHT", 0, -(dataIdx - 1) * rowH)
      if d then
        -- 数据不全时从总战绩玩家列表补齐
        local mu = (TN.db and TN.db.char and TN.db.char.matchups) or {}
        local m = mu[d.name]
        if m then
          if not d.cls or d.cls == "UNKNOWN" or d.cls == "" then d.cls = m.cls end
          if not d.lv or d.lv == "??" then d.lv = m.lv end
          if not d.guild or d.guild == "" then d.guild = m.guild end
        end
        row.data = d
        local resultColor = d.result == "胜" and C.green or C.red
        row.tCol:SetText(d.t or "")
        row.resCol:SetText(d.result or "")
        setColor(row.resCol, resultColor)
        row.nameCol:SetText(d.name or "")
        setColor(row.nameCol, classColor(d.cls))
        row.guildCol:SetText(d.guild or "—")
        row.lvCol:SetText(tostring(d.lv or "??"))
        row.clsCol:SetText(classText(d.cls))
        setColor(row.clsCol, classColor(d.cls))
        row.zoneCol:SetText(d.zone or "")
        row._alpha = dataIdx % 2 == 0 and 0.02 or 0.04
        row.bg:SetVertexColor(1, 1, 1, row._alpha)
        row:Show()
      else
        row.data = nil
        row:Hide()
      end
    end
  end
  scroll._refresh = refreshBattle
  scroll._data = battleLog
  scroll:SetScript("OnVerticalScroll", function(self)
    TN:UpdateDetailScrollThumb(self)
    if self._refresh then self._refresh() end
  end)
  local oldBWheel = scroll:GetScript("OnMouseWheel")
  scroll:SetScript("OnMouseWheel", function(self, delta)
    if oldBWheel then oldBWheel(self, delta) end
    if self._refresh then self._refresh() end
  end)
  self:UpdateDetailScrollThumb(scroll)
  refreshBattle()
  detail.battleFoot = createFont(card, 12, C.text3)
  detail.battleFoot:SetPoint("BOTTOMRIGHT", -18, 18)
  detail.battleFoot:SetJustifyH("RIGHT")
  detail.battleFoot:SetText("共 " .. tostring(#battleLog) .. " 条记录，最多500条")

  local historyStats = {}
  local historyStatData = self:GetHistoryStats()
  for i, stat in ipairs(historyStatData) do
    historyStats[i] = self:CreateDetailStat(histContent, i, stat, #historyStatData)
  end

  -- TOP 榜单（排行榜页）
  if detail.topPanels then
    for _, p in ipairs(detail.topPanels) do
      if p.box then p.box:Hide(); p.box:SetParent(nil) end
    end
    detail.topPanels = nil
  end
  detail.topPanels = {}
  local statGap = 12
  local statWidth = math.floor((DETAIL_CONTENT_WIDTH - 36) / 4)
  local topW2 = statWidth * 2 + statGap
  local topInfos = {{"swords", "我击杀的玩家 TOP10", C.green}, {"skull", "击杀我的玩家 TOP10", C.red}}
  for side = 1, 2 do
    local info = topInfos[side]
    local box = createDetailBox(frame.rank, 0.42)
    box:SetSize(topW2, 210)
    local leftX = 22 + (side == 1 and 0 or 2) * (statWidth + statGap)
    local rightX = -22 - (side == 1 and 2 or 0) * (statWidth + statGap)
    box:SetPoint("TOPLEFT", leftX, -20)
    box:SetPoint("TOPRIGHT", rightX, -20)
    local icon = createIcon(box, info[1], 14, info[3])
    icon:SetPoint("TOPLEFT", 10, -10)
    local hdr = createFont(box, 12, C.text2, "", "bold")
    hdr:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    hdr:SetText(info[2])
    detail.topPanels[side] = { box = box, rows = {} }
    for i = 1, 10 do
      local row = CreateFrame("Button", nil, box)
      row:SetSize(topW2 - 20, 18)
      row:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 18)
      row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, 0 })
      row.bg:SetAllPoints()
      row.name = createFont(row, 12, C.text, "", "regular")
      row.name:SetPoint("LEFT", 0, 0)
      row.num = createFont(row, 12, info[3], "", "regular")
      row.num:SetPoint("RIGHT", 0, 0)
      row:RegisterForClicks("RightButtonUp")
      row.bg:SetVertexColor(1, 1, 1, 0)
      row._data = nil
      row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(rgba(C.cellHi)) end)
      row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, self._alpha or 0.03) end)
      row:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" and self._data then
          TN:ShowDetailRecordContextMenu(self._data)
        end
      end)
      row:Hide()
      detail.topPanels[side].rows[i] = row
    end
  end
  -- 刷新 TOP 数据
  local muData = matchupList(self)
  local lists = {{}, {}}
  for _, d in ipairs(muData) do
    if (d.win or 0) > 0 then lists[1][#lists[1] + 1] = d end
    if (d.loss or 0) > 0 then lists[2][#lists[2] + 1] = d end
  end
  table.sort(lists[1], function(a, b) return (a.win or 0) > (b.win or 0) end)
  table.sort(lists[2], function(a, b) return (a.loss or 0) > (b.loss or 0) end)
  for side = 1, 2 do
    local panel = detail.topPanels[side]
    if panel then
      local key = side == 1 and "win" or "loss"
      for i = 1, 10 do
        local d = lists[side][i]
        local row = panel.rows[i]
        if d then
          local cc = classColor(d.cls)
          setColor(row.name, cc)
          row.name:SetText(d.name or "?")
          row.num:SetText(tostring(d[key] or 0))
          row._data = d
          row._alpha = i % 2 == 0 and 0.02 or 0.04
          row.bg:SetVertexColor(1, 1, 1, row._alpha)
          row:Show()
        else
          row:Hide()
        end
      end
    end
  end

  local historyCard = createDetailBox(histContent, 0.40)
  historyCard:SetPoint("TOPLEFT", 22, -120)
  historyCard:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(historyCard, "details", "玩家列表")
  detail.historySearch = createDetailInput(historyCard, 176, "搜索玩家名")
  detail.historySearch:SetPoint("TOPRIGHT", -16, -10)
  detail.historySearch:SetScript("OnTextChanged", function(self)
    setShown(self.placeholder, (self:GetText() or "") == "")
    TN:UpdateDetailHistoryList()
  end)
  -- 仅显示有胜负
  local winLossBtn = CreateFrame("Button", nil, historyCard)
  winLossBtn:SetSize(110, 22)
  winLossBtn:SetPoint("RIGHT", detail.historySearch, "LEFT", -8, 0)
  local dot = createTexture(winLossBtn, "ARTWORK", C.text3)
  dot:SetSize(8, 8)
  dot:SetPoint("LEFT", 4, 0)
  winLossBtn.text = createFont(winLossBtn, 11, C.text3, "", "regular")
  winLossBtn.text:SetPoint("LEFT", dot, "RIGHT", 4, 0)
  winLossBtn.text:SetText("仅显示有胜负")
  winLossBtn:SetScript("OnClick", function()
    self.historyFilterWinLoss = not self.historyFilterWinLoss
    dot:SetVertexColor(rgba(self.historyFilterWinLoss and C.cyan or C.text3))
    setColor(winLossBtn.text, self.historyFilterWinLoss and C.cyan or C.text3)
    self:UpdateDetailHistoryList()
  end)
  self:CreateDetailTableHeader(historyCard, {
    { t = "敌方玩家", w = 120 }, { t = "公会", w = 90 }, { t = "军衔", w = 70 },
    { t = "等级", w = 40 }, { t = "职业", w = 50 },
    { t = "胜", w = 40, onClick = function() TN:SortDetailHistory("win") end },
    { t = "负", w = 40, onClick = function() TN:SortDetailHistory("loss") end },
    { t = "最近", w = 56, onClick = function() TN:SortDetailHistory("recent") end },
    { t = "地区", w = 100 },
  }, -58)
  detail.historyScroll = self:CreateDetailScroll(historyCard, 12, -94, -12, 42)
  local matchupData = matchupList(self)
  detail.historyContent = CreateFrame("Frame", nil, detail.historyScroll)
  detail.historyContent:SetSize(DETAIL_CONTENT_WIDTH, #matchupData * 36)
  detail.historyScroll:SetScrollChild(detail.historyContent)

  -- 虚拟滚动：只创建 20 行，滚动时复用
  local poolSize = 20
  detail.historyRows = {}
  for i = 1, poolSize do
    local row = CreateFrame("Button", nil, detail.historyContent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHeight(34)
    row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, 0 })
    row.bg:SetAllPoints()
    row.name = createFont(row, 12, C.text, "", "medium")
    row.name:SetPoint("LEFT", 12, 0)
    row.name:SetWidth(120)
    row.guild = createFont(row, 12, C.text3, "", "medium")
    row.guild:SetPoint("LEFT", 12 + 120, 0)
    row.guild:SetWidth(90)
    row.rank = createFont(row, 12, C.text3, "", "medium")
    row.rank:SetPoint("LEFT", 12 + 120 + 90, 0)
    row.rank:SetWidth(70)
    row.lv = createFont(row, 12, C.text2, "", "medium")
    row.lv:SetPoint("LEFT", 12 + 120 + 90 + 70, 0)
    row.lv:SetWidth(40)
    row.clsBox = createTexture(row, "BORDER", C.lineSoft)
    row.clsBox:SetPoint("LEFT", 12 + 120 + 90 + 70 + 40, 0)
    row.clsBox:SetSize(20, 20)
    row.cls = createFont(row, 12, C.text, "", "bold")
    row.cls:SetPoint("LEFT", 12 + 120 + 90 + 70 + 40, 0)
    row.cls:SetWidth(20)
    row.cls:SetJustifyH("CENTER")
    row.win = createFont(row, 12, C.green, "", "medium")
    row.win:SetPoint("LEFT", 12 + 120 + 90 + 70 + 40 + 50, 0)
    row.win:SetWidth(40)
    row.loss = createFont(row, 12, C.red, "", "medium")
    row.loss:SetPoint("LEFT", 12 + 120 + 90 + 70 + 40 + 50 + 40, 0)
    row.loss:SetWidth(40)
    row.last = createFont(row, 12, C.text2, "", "medium")
    row.last:SetPoint("LEFT", 12 + 120 + 90 + 70 + 40 + 50 + 40 + 40, 0)
    row.last:SetWidth(56)
    row.zone = createFont(row, 12, C.text3, "", "medium")
    row.zone:SetPoint("LEFT", 12 + 120 + 90 + 70 + 40 + 50 + 40 + 40 + 56, 0)
    row.zone:SetWidth(100)
    row:SetScript("OnEnter", function(self)
      self.bg:SetVertexColor(rgba(C.cellHi))
      if self.data then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local cc = classColor(self.data.cls)
        GameTooltip:AddLine(self.data.name or "", cc[1], cc[2], cc[3])
        if self.data.guild and self.data.guild ~= "" then
          GameTooltip:AddLine(self.data.guild, C.green[1], C.green[2], C.green[3])
        end
        GameTooltip:AddLine("等级" .. (self.data.lv or "??") .. " -职业：" .. (self.data.cls or "未知"), C.text2[1], C.text2[2], C.text2[3])
        GameTooltip:AddLine("胜: " .. (self.data.win or 0) .. "  负: " .. (self.data.loss or 0), C.text[1], C.text[2], C.text[3])
        GameTooltip:AddLine((self.data.last or "--") .. " 在 " .. (self.data.zone or "未知区域") .. " 遇到", C.text3[1], C.text3[2], C.text3[3])
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function(self)
      self.bg:SetVertexColor(1, 1, 1, self._alpha or 0)
      GameTooltip:Hide()
    end)
    row:SetScript("PreClick", function(self, button)
      if button == "RightButton" and self.data then
        TN:ShowDetailRecordContextMenu(self.data)
      end
    end)
    detail.historyRows[i] = row
  end

  -- 刷新数据到可见行
  local function refreshVisible()
    local scroll = detail.historyScroll
    if not scroll then return end
    local data = scroll._data or matchupData
    local offset = scroll:GetVerticalScroll() or 0
    local rowH = 36
    local firstIdx = math.floor(offset / rowH) + 1
    for i = 1, poolSize do
      local row = detail.historyRows[i]
      local dataIdx = firstIdx + i - 1
      local d = data[dataIdx]
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(dataIdx - 1) * rowH)
      row:SetPoint("TOPRIGHT", 0, -(dataIdx - 1) * rowH)
      if d then
        row.data = d
        row.name:SetText(d.name or "")
        setColor(row.name, classColor(d.cls))
        row.guild:SetText(d.guild or "—")
        row.rank:SetText(d.rank or "—")
        row.lv:SetText(tostring(d.lv or "??"))
        row.cls:SetText(classText(d.cls))
        setColor(row.cls, classColor(d.cls))
        row.win:SetText(tostring(d.win or 0))
        row.loss:SetText(tostring(d.loss or 0))
        row.last:SetText(d.last or "—")
        row.zone:SetText(d.zone or "—")
        row._alpha = dataIdx % 2 == 0 and 0.02 or 0.04
        row.bg:SetVertexColor(1, 1, 1, row._alpha)
        row:Show()
      else
        row.data = nil
        row:Hide()
      end
    end
  end
  -- 存到 scroll frame 上，回调可访问
  detail.historyScroll._refresh = refreshVisible
  detail.historyScroll:SetScript("OnVerticalScroll", function(self)
    TN:UpdateDetailScrollThumb(self)
    if self._refresh then self._refresh() end
  end)
  local oldWheel = detail.historyScroll:GetScript("OnMouseWheel")
  detail.historyScroll:SetScript("OnMouseWheel", function(self, delta)
    if oldWheel then oldWheel(self, delta) end
    if self._refresh then self._refresh() end
  end)
  refreshVisible()

  detail.historyFoot = createFont(historyCard, 12, C.text3)
  detail.historyFoot:SetPoint("BOTTOMRIGHT", -18, 18)
  detail.historyFoot:SetJustifyH("RIGHT")
  detail.historyFoot:SetText("共 " .. tostring(#matchupData) .. " 名玩家")
  histContent:SetHeight(800)
  frame:Show()
  self:UpdateDetailBattleList()
  self:UpdateDetailHistoryList()
  self:UpdateDetailRecordTabs()
end

function TN:SetDetailRecordTab(tab)
  self.detailRecordTab = tab or "today"
  self:UpdateDetailRecordTabs()
end

function TN:UpdateDetailRecordTabs()
  local detail = self.detail
  if not detail or not detail.records then return end
  local tab = self.detailRecordTab or "today"
  setShown(detail.records.today, tab == "today")
  setShown(detail.records.history, tab == "history")
  setShown(detail.records.rank, tab == "rank")
  if detail.todayTab then
    detail.todayTab:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], tab == "today" and 0.45 or 0.10)
    if tab == "today" then
      detail.todayTab:SetBackdropColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.12)
    else
      detail.todayTab:SetBackdropColor(C.panel2[1], C.panel2[2], C.panel2[3], 0.16)
    end
    setColor(detail.todayTab.text, tab == "today" and C.cyan or C.text2)
  end
  if detail.historyTab then
    detail.historyTab:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], tab == "history" and 0.45 or 0.10)
    if tab == "history" then
      detail.historyTab:SetBackdropColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.12)
    else
      detail.historyTab:SetBackdropColor(C.panel2[1], C.panel2[2], C.panel2[3], 0.16)
    end
    setColor(detail.historyTab.text, tab == "history" and C.cyan or C.text2)
  end
  if detail.rankTab then
    detail.rankTab:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], tab == "rank" and 0.45 or 0.10)
    if tab == "rank" then
      detail.rankTab:SetBackdropColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.12)
    else
      detail.rankTab:SetBackdropColor(C.panel2[1], C.panel2[2], C.panel2[3], 0.16)
    end
    setColor(detail.rankTab.text, tab == "rank" and C.cyan or C.text2)
  end
end
