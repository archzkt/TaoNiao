--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailWidgets.lua
-- 详情页专用构造函数：卡片/分隔线/标题/按钮/输入框/滚动容器。
-- 依赖 Theme（颜色/字体）与 Widgets（纹理/图标/字体）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local applyFont = Theme.applyFont
local setColor = Theme.setColor
local setShown = Theme.setShown
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local createRoundedBlock = Widgets.createRoundedBlock

local DetailWidgets = {}
TN.DetailWidgets = DetailWidgets

function DetailWidgets.createDetailBox(parent, alpha)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  box:SetBackdropColor(C.panel2[1], C.panel2[2], C.panel2[3], alpha or 0.52)
  box:SetBackdropBorderColor(rgba(C.lineSoft))
  return box
end

function DetailWidgets.createDetailDivider(parent, anchor, y)
  local line = createTexture(parent, "ARTWORK", C.lineSoft)
  line:SetPoint("TOPLEFT", anchor or parent, "TOPLEFT", 0, y or 0)
  line:SetPoint("TOPRIGHT", anchor or parent, "TOPRIGHT", 0, y or 0)
  line:SetHeight(1)
  return line
end

function DetailWidgets.createDetailHeader(parent, icon, title)
  local iconTex = createIcon(parent, icon, 17, C.cyan)
  iconTex:SetPoint("TOPLEFT", 16, -15)
  local text = createFont(parent, 15, C.text, "OUTLINE", "bold")
  text:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
  text:SetText(title)
  return text
end

function DetailWidgets.createDetailButton(parent, label, width, onClick)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(width or 68, 30)
  btn.bg = createTexture(btn, "BACKGROUND", C.cell)
  btn.bg:SetAllPoints()
  btn.text = createFont(btn, 12, C.text2, "", "medium")
  btn.text:SetPoint("CENTER")
  btn.text:SetText(label)
  btn:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
    setColor(self.text, C.cyan)
  end)
  btn:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
    setColor(self.text, C.text2)
  end)
  btn:SetScript("OnClick", onClick)
  return btn
end

function DetailWidgets.createDetailInput(parent, width, placeholder)
  local input = CreateFrame("EditBox", nil, parent)
  input:SetSize(width or 120, 30)
  input:SetAutoFocus(false)
  applyFont(input, 12, "", "regular")
  input:SetTextColor(rgba(C.text))
  input:SetJustifyH("LEFT")
  input:SetTextInsets(10, 8, 0, 0)
  input.bg = createTexture(input, "BACKGROUND", { 1, 1, 1, 0.035 })
  input.bg:SetAllPoints()
  input.placeholder = createFont(input, 12, C.text3)
  input.placeholder:SetPoint("LEFT", 10, 0)
  input.placeholder:SetText(placeholder or "")
  input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  input:SetScript("OnEditFocusGained", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
  end)
  input:SetScript("OnEditFocusLost", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0.035)
  end)
  input:SetScript("OnTextChanged", function(self)
    setShown(self.placeholder, (self:GetText() or "") == "")
  end)
  return input
end

function DetailWidgets.clearDetailMain(detail)
  if not detail or not detail.contentFrames then return end
  for _, frame in ipairs(detail.contentFrames) do
    frame:Hide()
  end
end

function DetailWidgets.addDetailFrame(detail, frame)
  detail.contentFrames = detail.contentFrames or {}
  table.insert(detail.contentFrames, frame)
  return frame
end

-- ── 滚动容器 ──
function TN:UpdateDetailScrollThumb(scroll)
  if not scroll or not scroll.thumb or not scroll.track then return end
  local maxScroll = scroll:GetVerticalScrollRange() or 0
  local trackHeight = scroll.track:GetHeight() or 1
  local child = scroll:GetScrollChild()
  local childHeight = child and child:GetHeight() or scroll:GetHeight()
  local viewHeight = scroll:GetHeight() or 1
  if maxScroll <= 0 or childHeight <= viewHeight then
    scroll.track:Hide()
    scroll.thumb:Hide()
    return
  end
  local thumbHeight = math.max(28, math.floor(trackHeight * viewHeight / childHeight))
  local offset = (scroll:GetVerticalScroll() or 0) / maxScroll * math.max(1, trackHeight - thumbHeight)
  scroll.track:Show()
  scroll.thumb:Show()
  scroll.thumb:SetHeight(thumbHeight)
  scroll.thumb:ClearAllPoints()
  scroll.thumb:SetPoint("TOP", scroll.track, "TOP", 0, -offset)
end

function TN:ShowDetailScrollNotice(scroll, text, isTop)
  if not scroll then return end
  local indicator = isTop and scroll.topIndicator or scroll.bottomIndicator
  if not indicator then return end
  local token = (scroll.noticeToken or 0) + 1
  scroll.noticeToken = token
  indicator.text:SetText(text)
  indicator.bg:SetAlpha(0.85)
  indicator.text:SetAlpha(1)
  indicator:SetHeight(28)
  indicator:Show()
  indicator.animToken = token
  if C_Timer and C_Timer.After then
    C_Timer.After(0.6, function()
      if indicator.animToken == token and indicator:IsShown() then
        indicator.bg:SetAlpha(0)
        indicator.text:SetAlpha(0)
        indicator:SetHeight(0)
        indicator:Hide()
      end
    end)
  end
end

function TN:CreateDetailScroll(parent, topLeftX, topLeftY, bottomRightX, bottomRightY)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  scroll:SetPoint("TOPLEFT", topLeftX, topLeftY)
  scroll:SetPoint("BOTTOMRIGHT", bottomRightX, bottomRightY)
  scroll:EnableMouseWheel(true)

  -- 滚动条轨道
  scroll.track = CreateFrame("Frame", nil, scroll)
  scroll.track:SetPoint("TOPRIGHT", -2, 0)
  scroll.track:SetPoint("BOTTOMRIGHT", -2, 0)
  scroll.track:SetWidth(6)
  scroll.track.bg = createTexture(scroll.track, "BACKGROUND", { 1, 1, 1, 0.05 })
  scroll.track.bg:SetAllPoints()
  scroll.track:Hide()
  -- 滚动条滑块
  scroll.thumb = CreateFrame("Button", nil, scroll.track)
  scroll.thumb:SetWidth(6)
  scroll.thumb:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
  scroll.thumb:GetNormalTexture():SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.35)
  scroll.thumb:GetNormalTexture():SetAllPoints()
  scroll.thumb:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
  scroll.thumb:GetHighlightTexture():SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.65)
  scroll.thumb:GetHighlightTexture():SetAllPoints()
  scroll.thumb:EnableMouse(true)
  scroll.thumb:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
  scroll.thumb:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    self:GetParent():GetParent().dragging = true
  end)
  scroll.thumb:SetScript("OnMouseUp", function(self)
    self:GetParent():GetParent().dragging = false
  end)
  scroll.thumb:Hide()
  -- 点击轨道跳转
  scroll.track:EnableMouse(true)
  scroll.track:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    local s = self:GetParent()
    local maxScroll = s:GetVerticalScrollRange() or 0
    if maxScroll <= 0 then return end
    local trackH = self:GetHeight() or 1
    local child = s:GetScrollChild()
    local childH = child and child:GetHeight() or s:GetHeight()
    local viewH = s:GetHeight() or 1
    local thumbH = math.max(28, math.floor(trackH * viewH / childH))
    local cursorY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
    local trackTop = self:GetTop() or 0
    local ratio = (trackTop - cursorY - thumbH / 2) / math.max(1, trackH - thumbH)
    s:SetVerticalScroll(math.max(0, math.min(maxScroll, ratio * maxScroll)))
    TN:UpdateDetailScrollThumb(s)
  end)
  scroll.track:Hide()

  -- 顶部过滚指示器
  scroll.topIndicator = CreateFrame("Frame", nil, parent)
  scroll.topIndicator:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", topLeftX, topLeftY)
  scroll.topIndicator:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", bottomRightX, topLeftY)
  scroll.topIndicator:SetHeight(0)
  scroll.topIndicator:SetFrameLevel(parent:GetFrameLevel() + 5)
  scroll.topIndicator.bg = createTexture(scroll.topIndicator, "BACKGROUND", { C.panel[1], C.panel[2], C.panel[3], 0 })
  scroll.topIndicator.bg:SetAllPoints()
  scroll.topIndicator.text = createFont(scroll.topIndicator, 12, C.cyan, "OUTLINE", "medium")
  scroll.topIndicator.text:SetPoint("CENTER")
  scroll.topIndicator.text:SetJustifyH("CENTER")
  scroll.topIndicator.text:SetText("已经到顶了")
  scroll.topIndicator.text:SetAlpha(0)
  scroll.topIndicator:Hide()

  -- 底部过滚指示器
  scroll.bottomIndicator = CreateFrame("Frame", nil, parent)
  scroll.bottomIndicator:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", topLeftX, bottomRightY)
  scroll.bottomIndicator:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", bottomRightX, bottomRightY)
  scroll.bottomIndicator:SetHeight(0)
  scroll.bottomIndicator:SetFrameLevel(parent:GetFrameLevel() + 5)
  scroll.bottomIndicator.bg = createTexture(scroll.bottomIndicator, "BACKGROUND", { C.panel[1], C.panel[2], C.panel[3], 0 })
  scroll.bottomIndicator.bg:SetAllPoints()
  scroll.bottomIndicator.text = createFont(scroll.bottomIndicator, 12, C.cyan, "OUTLINE", "medium")
  scroll.bottomIndicator.text:SetPoint("CENTER")
  scroll.bottomIndicator.text:SetJustifyH("CENTER")
  scroll.bottomIndicator.text:SetText("没有更多数据了")
  scroll.bottomIndicator.text:SetAlpha(0)
  scroll.bottomIndicator:Hide()

  scroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local maxScroll = self:GetVerticalScrollRange() or 0
    -- 内容不超长时无需滚动，也不弹提示
    if maxScroll <= 0 then return end
    if delta > 0 and current <= 0 then
      TN:ShowDetailScrollNotice(self, "已经到顶了", true); return
    end
    if delta < 0 and current >= maxScroll then
      TN:ShowDetailScrollNotice(self, "没有更多数据了", false); return
    end
    local nextScroll = math.max(0, math.min(maxScroll, current - delta * 28))
    self:SetVerticalScroll(nextScroll)
    if delta > 0 and nextScroll <= 0 then
      TN:ShowDetailScrollNotice(self, "已经到顶了", true)
    elseif delta < 0 and nextScroll >= maxScroll then
      TN:ShowDetailScrollNotice(self, "没有更多数据了", false)
    end
    TN:UpdateDetailScrollThumb(self)
  end)
  -- 拖拽滑块滚动
  scroll:SetScript("OnUpdate", function(self)
    if not self.dragging then return end
    local maxScroll = self:GetVerticalScrollRange() or 0
    if maxScroll <= 0 then return end
    local trackH = self.track:GetHeight() or 1
    local child = self:GetScrollChild()
    local childH = child and child:GetHeight() or self:GetHeight()
    local viewH = self:GetHeight() or 1
    local thumbH = math.max(28, math.floor(trackH * viewH / childH))
    local cursorY = select(2, GetCursorPosition()) / (self:GetEffectiveScale() or 1)
    local trackTop = self.track:GetTop() or 0
    local ratio = (trackTop - cursorY - thumbH / 2) / math.max(1, trackH - thumbH)
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, ratio * maxScroll)))
    TN:UpdateDetailScrollThumb(self)
  end)

  return scroll
end
