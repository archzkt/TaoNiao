--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailKOS.lua
-- 详情页 · 死刑名单：行构造、数据存取（mock 副本）、搜索/排序、选中、CRUD、刷新。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createFont = Widgets.createFont
local utf8Truncate = Widgets.utf8Truncate
local Data = TN.DetailData
local classColor = Data.classColor
local classText = Data.classText
local timeValue = Data.timeValue
local DetailWidgets = TN.DetailWidgets
local createDetailBox = DetailWidgets.createDetailBox
local createDetailHeader = DetailWidgets.createDetailHeader
local createDetailInput = DetailWidgets.createDetailInput
local createDetailButton = DetailWidgets.createDetailButton
local clearDetailMain = DetailWidgets.clearDetailMain
local addDetailFrame = DetailWidgets.addDetailFrame
local setShown = Theme.setShown
local DETAIL_CONTENT_WIDTH = Theme.Layout.DETAIL_CONTENT_WIDTH

function TN:CreateDetailKOSRow(parent, index)
  local row = CreateFrame("Button", nil, parent)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetPoint("TOPLEFT", 0, -(index - 1) * 36)
  row:SetPoint("TOPRIGHT", 0, -(index - 1) * 36)
  row:SetHeight(34)
  row.bg = createTexture(row, "BACKGROUND", { 1, 1, 1, index % 2 == 0 and 0.02 or 0.04 })
  row.bg:SetAllPoints()
  row.name = createFont(row, 12, C.text, "", "medium")
  row.name:SetPoint("LEFT", 12, 0)
  row.name:SetWidth(128)
  row.guild = createFont(row, 12, C.text3, "", "medium")
  row.guild:SetPoint("LEFT", 140, 0)
  row.guild:SetWidth(80)
  row.level = createFont(row, 12, C.text2, "", "medium")
  row.level:SetPoint("LEFT", 220, 0)
  row.level:SetWidth(36)
  row.classBox = createTexture(row, "BORDER", C.lineSoft)
  row.classBox:SetPoint("LEFT", 256, 0)
  row.classBox:SetSize(20, 20)
  row.class = createFont(row, 12, C.text, "", "bold")
  row.class:SetPoint("LEFT", 256, 0)
  row.class:SetWidth(20)
  row.class:SetJustifyH("CENTER")
  row.crime = createFont(row, 12, C.text2, "", "medium")
  row.crime:SetPoint("LEFT", 284, 0)
  row.crime:SetWidth(240)
  row.win = createFont(row, 12, C.green, "", "medium")
  row.win:SetPoint("LEFT", 524, 0)
  row.win:SetWidth(44)
  row.win:SetJustifyH("LEFT")
  row.loss = createFont(row, 12, C.red, "", "medium")
  row.loss:SetPoint("LEFT", 568, 0)
  row.loss:SetWidth(44)
  row.loss:SetJustifyH("LEFT")
  row.last = createFont(row, 12, C.text2, "", "medium")
  row.last:SetPoint("LEFT", 612, 0)
  row.last:SetWidth(80)
  row.last:SetJustifyH("LEFT")
  row:SetScript("OnClick", function(self) TN:SelectDetailKOS(self.actualIndex) end)
  row:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
    if self.data and self.data.name then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:ClearLines()
      local cc = classColor(self.data.cls)
      GameTooltip:AddLine(self.data.name or "", cc[1], cc[2], cc[3])
      if self.data.guild and self.data.guild ~= "" then
        GameTooltip:AddLine(self.data.guild, C.green[1], C.green[2], C.green[3])
      end
      GameTooltip:AddLine("等级" .. (self.data.lv or "??") .. " -职业：" .. (self.data.cls or "未知"), C.text2[1], C.text2[2], C.text2[3])
      local tw, tl, tm = TN:LookupHistoryWL(self.data.name)
      GameTooltip:AddLine("胜: " .. tw .. "  负: " .. tl, C.text[1], C.text[2], C.text[3])
      local agoText = "--"
      if type(tm) == "number" and tm > 0 then
        local dt = time() - tm
        if dt < 60 then agoText = math.floor(dt) .. "s"
        elseif dt < 3600 then agoText = math.floor(dt / 60) .. "m"
        elseif dt < 86400 then agoText = math.floor(dt / 3600) .. "h"
        else agoText = math.floor(dt / 86400) .. "d" end
      end
      GameTooltip:AddLine(agoText .. " 在 " .. (self.data.zone or "未知区域") .. " 遇到", C.text3[1], C.text3[2], C.text3[3])
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function(self)
    local selected = TN.detailSelectedKOSIndex and self.actualIndex == TN.detailSelectedKOSIndex
    self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], selected and 0.10 or (index % 2 == 0 and 0.02 or 0.04))
    GameTooltip:Hide()
  end)
  row:SetScript("PreClick", function(self, button)
    if button == "RightButton" and self.actualIndex then
      TN:ShowKOSContextMenu(self.actualIndex, self.data)
    end
  end)
  return row
end

function TN:GetDetailKOSData()
  return (self.db and self.db.char and self.db.char.kosList) or {}
end

-- 从总战绩（对手统计）查询某玩家的历史胜负，供新增死刑名单时回填
function TN:LookupHistoryWL(name)
  if not name then return 0, 0, nil end
  local mu = (self.db and self.db.char and self.db.char.matchups) or {}
  local m = mu[name]
  if m then return m.win or 0, m.loss or 0, m.last end
  local short = name:match("^([^%-]+)")
  if short and short ~= name then
    m = mu[short]
    if m then return m.win or 0, m.loss or 0, m.last end
  end
  return 0, 0, nil
end

function TN:GetFilteredDetailKOS()
  local query = self.detail and self.detail.kosSearch and self.detail.kosSearch:GetText() or ""
  local rows = {}
  for index, data in ipairs(self:GetDetailKOSData()) do
    local matched = query == "" or (data.name and data.name:find(query, 1, true))
    if matched then
      table.insert(rows, { index = index, data = data })
    end
  end
  local sortKey = self.detailKOSSortKey or "time"
  local asc = self.detailKOSSortAsc
  table.sort(rows, function(a, b)
    if sortKey == "time" then
      if asc then return a.index < b.index end
      return a.index > b.index
    end
    local av, bv
    if sortKey == "win" then
      av, bv = self:LookupHistoryWL(a.data.name)
      bv = select(2, self:LookupHistoryWL(b.data.name))
    elseif sortKey == "loss" then
      av = select(2, self:LookupHistoryWL(a.data.name))
      bv = select(2, self:LookupHistoryWL(b.data.name))
    else
      av = select(3, self:LookupHistoryWL(a.data.name)) or 0
      bv = select(3, self:LookupHistoryWL(b.data.name)) or 0
    end
    if av == bv then
      return tostring(a.data.name or "") < tostring(b.data.name or "")
    end
    if asc then return av < bv end
    return av > bv
  end)
  return rows
end

function TN:SortDetailKOS(key)
  if self.detailKOSSortKey == key then
    self.detailKOSSortAsc = not self.detailKOSSortAsc
  else
    self.detailKOSSortKey = key
    self.detailKOSSortAsc = false
  end
  self:UpdateDetailHighRisk()
end

function TN:SelectDetailKOS(index)
  if not index then return end
  local data = self:GetDetailKOSData()[index]
  if not data then return end
  self.detailSelectedKOSIndex = index
  if self.detail then
    if self.detail.kosNameInput then self.detail.kosNameInput:SetText(data.name or "") end
    if self.detail.kosCrimeInput then self.detail.kosCrimeInput:SetText(data.crime or "") end
    local w, l = self:LookupHistoryWL(data.name)
    if self.detail.kosWinInput then self.detail.kosWinInput:SetText(tostring(w)) end
    if self.detail.kosLossInput then self.detail.kosLossInput:SetText(tostring(l)) end
    if self.detail.kosTimeInput then self.detail.kosTimeInput:SetText(data.last or "") end
  end
  self:UpdateDetailHighRisk()
end

function TN:SaveDetailKOS()
  local detail = self.detail
  if not detail then return end
  local name = detail.kosNameInput and detail.kosNameInput:GetText() or ""
  local crime = detail.kosCrimeInput and detail.kosCrimeInput:GetText() or ""
  if name == "" then
    if UIErrorsFrame then UIErrorsFrame:AddMessage("|cffff4d4f请输入玩家名|r", 1, 0.3, 0.3, 1, 3) end
    return
  end
  if crime == "" then crime = "宣判死刑" end
  local rows = self:GetDetailKOSData()
  -- 查总战绩获取真实职业/等级/公会
  local mu = (self.db.char.matchups or {})[name]
  local classFile = mu and mu.cls or "UNKNOWN"
  local ci = self.classInfo[classFile]
  local last = time and time() or 0
  local row = self.detailSelectedKOSIndex and rows[self.detailSelectedKOSIndex]
  if row then
    row.name = name
    row.crime = crime
    row.last = last
  else
    table.insert(rows, {
      name = name,
      cls = ci and ci.name or classFile,
      lv = (mu and mu.lv) or "??",
      crime = crime,
      win = (mu and mu.win) or 0,
      loss = (mu and mu.loss) or 0,
      last = last,
      zone = GetZoneText and (GetZoneText() or "未知区域") or "未知区域",
      tone = C.red,
    })
    self.detailSelectedKOSIndex = #rows
  end
  -- 保存后清空输入
  if detail.kosNameInput then detail.kosNameInput:SetText("") end
  if detail.kosCrimeInput then detail.kosCrimeInput:SetText("") end
  self:Print("|cffff4d4f" .. name .. " 已加入见之必杀|r")
  self:UpdateDetailHighRisk()
end

function TN:NewDetailKOS()
  self:ShowKOSAddDialog()
end

function TN:DeleteDetailKOS(index)
  local rows = self:GetDetailKOSData()
  if index and rows[index] then
    table.remove(rows, index)
  end
  self.detailSelectedKOSIndex = nil
  if self.detail then
    if self.detail.kosNameInput then self.detail.kosNameInput:SetText("") end
    if self.detail.kosCrimeInput then self.detail.kosCrimeInput:SetText("") end
    if self.detail.kosWinInput then self.detail.kosWinInput:SetText("") end
    if self.detail.kosLossInput then self.detail.kosLossInput:SetText("") end
    if self.detail.kosTimeInput then self.detail.kosTimeInput:SetText("") end
  end
  self:UpdateDetailHighRisk()
end

function TN:UpdateDetailHighRisk()
  local detail = self.detail
  if not detail or not detail.kosRows then return end
  local filtered = self:GetFilteredDetailKOS()
  for i, row in ipairs(detail.kosRows) do
    local item = filtered[i]
    if item then
      local data = item.data
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(i - 1) * 36)
      row:SetPoint("TOPRIGHT", 0, -(i - 1) * 36)
      row.data = data
      row.actualIndex = item.index
      row.name:SetText(data.name or "")
      setColor(row.name, classColor(data.cls))
      row.guild:SetText(data.guild or "—")
      row.level:SetText(tostring(data.lv or "??"))
      row.class:SetText(classText(data.cls))
      setColor(row.class, classColor(data.cls))
      row.crime:SetText(utf8Truncate(data.crime or "", 13))
      local w, l, ml = self:LookupHistoryWL(data.name)
      row.win:SetText(tostring(w))
      row.loss:SetText(tostring(l))
      local lastText = "--"
      if type(ml) == "number" and ml > 0 then
        local dt = time() - ml
        if dt < 60 then lastText = math.floor(dt) .. "s"
        elseif dt < 3600 then lastText = math.floor(dt / 60) .. "m"
        elseif dt < 86400 then lastText = math.floor(dt / 3600) .. "h"
        else lastText = math.floor(dt / 86400) .. "d" end
      end
      row.last:SetText(lastText)
      local selected = self.detailSelectedKOSIndex and item.index == self.detailSelectedKOSIndex
      row.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], selected and 0.10 or (i % 2 == 0 and 0.02 or 0.04))
      row:Show()
    else
      row.data = nil
      row.actualIndex = nil
      row:Hide()
    end
  end
  if detail.kosFoot then detail.kosFoot:SetText("共 " .. tostring(#filtered) .. " 名") end
  if detail.kosContent then detail.kosContent:SetHeight(math.max(1, math.min(#filtered, #detail.kosRows) * 36)) end
  if detail.kosScroll then detail.kosScroll:SetVerticalScroll(0) end
end

function TN:RenderDetailHighRisk()
  local detail = self.detail
  clearDetailMain(detail)
  if detail.highrisk then
    detail.highrisk:Show()
    self:UpdateDetailHighRisk()
    return
  end
  local frame = addDetailFrame(detail, CreateFrame("Frame", nil, detail.main))
  detail.highrisk = frame
  frame:SetAllPoints()

  local tableCard = createDetailBox(frame, 0.40)
  tableCard:SetPoint("TOPLEFT", 22, -20)
  tableCard:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(tableCard, "skull", "见之必杀")
  detail.kosSearch = createDetailInput(tableCard, 176, "搜索玩家名")
  detail.kosSearch:SetPoint("TOPRIGHT", -12, -10)
  detail.kosSearch:SetScript("OnTextChanged", function(self)
    setShown(self.placeholder, (self:GetText() or "") == "")
    TN:UpdateDetailHighRisk()
  end)

  self:CreateDetailTableHeader(tableCard, {
    { t = "玩家名", w = 128 }, { t = "公会", w = 80 }, { t = "等级", w = 36 }, { t = "职业", w = 28 },
    { t = "原因", w = 240 }, { t = "胜", w = 44, sortKey = "win" }, { t = "负", w = 44, sortKey = "loss" },
    { t = "最近", w = 80, sortKey = "time" },
  }, -58)
  detail.kosScroll = self:CreateDetailScroll(tableCard, 12, -94, -12, 42)
  detail.kosContent = CreateFrame("Frame", nil, detail.kosScroll)
  detail.kosContent:SetSize(DETAIL_CONTENT_WIDTH, 20 * 36)
  detail.kosScroll:SetScrollChild(detail.kosContent)
  detail.kosRows = {}
  for i = 1, 20 do
    detail.kosRows[i] = self:CreateDetailKOSRow(detail.kosContent, i)
  end
  detail.kosFoot = createFont(tableCard, 12, C.text3)
  detail.kosFoot:SetPoint("BOTTOMRIGHT", -18, 18)
  detail.kosFoot:SetJustifyH("RIGHT")
  detail.kosFoot:SetText("共 0 名")
  frame:Show()
  self:UpdateDetailHighRisk()
end
