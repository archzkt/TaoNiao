--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/ToastStack.lua
-- 通知堆叠：5 行预分配的 toast 容器 + 实时刷新（色调/图标/标题/进度条）。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local TONE = Theme.TONE
local I = Theme.I
local setColor = Theme.setColor
local setShown = Theme.setShown
local Widgets = TN.Widgets
local createIcon = Widgets.createIcon
local createTexture = Widgets.createTexture
local createFont = Widgets.createFont
local LIST_DEFAULT_WIDTH = Theme.Layout.LIST_DEFAULT_WIDTH

function TN:CreateToastStack()
  local toastCfg = self.db and self.db.profile and self.db.profile.toast or {}
  local stack = CreateFrame("Frame", "TaoNiaoToastStack", UIParent)
  stack:SetSize(LIST_DEFAULT_WIDTH, 420)
  stack:SetPoint("TOP", UIParent, "TOP", toastCfg.x or 0, toastCfg.y or -140)
  stack:SetFrameStrata("DIALOG")
  stack:EnableMouse(false)

  stack.header = CreateFrame("Frame", nil, stack)
  stack.header:SetPoint("TOPLEFT")
  stack.header:SetPoint("TOPRIGHT")
  stack.header:SetHeight(20)
  stack.header:EnableMouse(true)
  stack.header.bg = createTexture(stack.header, "BACKGROUND", {1, 1, 1, 0})
  stack.header.bg:SetAllPoints()
  stack.header:SetScript("OnEnter", function()
    stack.header.bg:SetVertexColor(1, 1, 1, 0.06)
  end)
  stack.header:SetScript("OnLeave", function()
    stack.header.bg:SetVertexColor(1, 1, 1, 0)
  end)
  -- 自定义拖拽：检查 toast.locked 而非 HUD locked
  stack:SetMovable(true)
  stack:SetClampedToScreen(true)
  stack.header:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then return end
    local tc = TN.db and TN.db.profile and TN.db.profile.toast
    if not tc or tc.locked ~= false then return end
    stack:StartMoving()
    stack.isDragging = true
  end)
  stack.header:SetScript("OnMouseUp", function()
    if stack.isDragging then
      stack:StopMovingOrSizing()
      stack.isDragging = false
      local _, _, _, x, y = stack:GetPoint(1)
      local tc = TN.db and TN.db.profile and TN.db.profile.toast
      if tc then
        tc.x = x or 0
        tc.y = y or -140
      end
    end
  end)

  stack.anchorIcon = createIcon(stack, "flag", 12, C.cyan)
  stack.anchorIcon:SetPoint("TOPLEFT", 2, -2)
  stack.anchorIcon:Hide()
  stack.anchorText = createFont(stack, 11, C.text3, "", "bold")
  stack.anchorText:SetPoint("LEFT", stack.anchorIcon, "RIGHT", 6, 0)
  stack.anchorText:Hide()

  -- 占位行：解锁定位时显示，用于拖拽
  stack.placeholder = CreateFrame("Button", nil, stack)
  stack.placeholder:SetSize(LIST_DEFAULT_WIDTH, 68)
  stack.placeholder:SetPoint("TOPLEFT", 0, -18)
  stack.placeholder.bg = createTexture(stack.placeholder, "BACKGROUND", {0.04, 0.055, 0.085, toastCfg.alpha or 0.70})
  stack.placeholder.bg:SetAllPoints()
  stack.placeholder.edge = createTexture(stack.placeholder, "BORDER", C.cyan)
  stack.placeholder.edge:SetPoint("TOPLEFT")
  stack.placeholder.edge:SetPoint("BOTTOMLEFT")
  stack.placeholder.edge:SetWidth(3)
  stack.placeholder.edgeRight = createTexture(stack.placeholder, "BORDER", C.cyan)
  stack.placeholder.edgeRight:SetPoint("TOPRIGHT")
  stack.placeholder.edgeRight:SetPoint("BOTTOMRIGHT")
  stack.placeholder.edgeRight:SetWidth(1)
  stack.placeholder.edgeTop = createTexture(stack.placeholder, "BORDER", C.cyan)
  stack.placeholder.edgeTop:SetPoint("TOPLEFT")
  stack.placeholder.edgeTop:SetPoint("TOPRIGHT")
  stack.placeholder.edgeTop:SetHeight(1)
  stack.placeholder.edgeBottom = createTexture(stack.placeholder, "BORDER", C.cyan)
  stack.placeholder.edgeBottom:SetPoint("BOTTOMLEFT")
  stack.placeholder.edgeBottom:SetPoint("BOTTOMRIGHT")
  stack.placeholder.edgeBottom:SetHeight(1)
  stack.placeholder:Hide()
  -- 占位框内任意位置可拖拽
  stack.placeholder:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then return end
    stack:StartMoving()
    stack.isDragging = true
  end)
  stack.placeholder:SetScript("OnMouseUp", function()
    if stack.isDragging then
      stack:StopMovingOrSizing()
      stack.isDragging = false
      local _, _, _, x, y = stack:GetPoint(1)
      local tc = TN.db and TN.db.profile and TN.db.profile.toast
      if tc then tc.x = x or 0; tc.y = y or -140 end
    end
  end)
  local phCat = createFont(stack.placeholder, 11, C.cyan, "", "bold")
  phCat:SetPoint("TOPLEFT", 16, -11)
  phCat:SetText("这是提醒弹窗")
  local phText = createFont(stack.placeholder, 14, C.text, "OUTLINE", "bold")
  phText:SetPoint("TOPLEFT", 16, -32)
  phText:SetText("拖动调整位置")

  stack.rows = {}
  for i = 1, 5 do
    local row = CreateFrame("Frame", nil, stack, "BackdropTemplate")
    row:SetSize(LIST_DEFAULT_WIDTH, 68)
    row:SetPoint("TOPLEFT", 0, -18 - (i - 1) * 78)
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    row:SetBackdropColor(0.04, 0.055, 0.085, toastCfg.alpha or 0.70)
    row.toneBar = createTexture(row, "ARTWORK", C.cyan)
    row.toneBar:SetPoint("TOPLEFT")
    row.toneBar:SetPoint("BOTTOMLEFT")
    row.toneBar:SetWidth(3)
    row.iconBox = createTexture(row, "BACKGROUND", { 1, 1, 1, 0.05 })
    row.iconBox:SetPoint("LEFT", 14, 0)
    row.iconBox:SetSize(38, 38)
    row.icon = createIcon(row, "crosshair", 20, C.cyan)
    row.icon:SetPoint("CENTER", row.iconBox)
    row.cat = createFont(row, 11, C.cyan, "", "bold")
    row.cat:SetPoint("TOPLEFT", 64, -11)
    row.title = createFont(row, 14, C.text, "", "medium")
    row.title:SetPoint("TOPLEFT", 64, -27)
    row.title:SetWidth(LIST_DEFAULT_WIDTH - 90)
    row.sub = createFont(row, 12, C.text2)
    row.sub:SetPoint("TOPLEFT", 64, -46)
    row.sub:SetWidth(LIST_DEFAULT_WIDTH - 80)
    row.ttl = createFont(row, 13, C.text2, "", "bold")
    row.ttl:SetPoint("TOPRIGHT", -12, -12)
    row.progress = createTexture(row, "OVERLAY", C.cyan)
    row.progress:SetPoint("BOTTOMLEFT")
    row.progress:SetHeight(2)
    stack.rows[i] = row
    row:Hide()
  end
  self.toastStack = stack
  self:ApplyToastAlpha()
  self:UpdateToastStack()
end

function TN:ApplyToastAlpha()
  local alpha = (self.db and self.db.profile and self.db.profile.toast and self.db.profile.toast.alpha) or 0.70
  if self.toastStack and self.toastStack.rows then
    for _, row in ipairs(self.toastStack.rows) do
      row:SetBackdropColor(0.04, 0.055, 0.085, alpha)
    end
  end
  if self.toastStack and self.toastStack.placeholder then
    self.toastStack.placeholder.bg:SetVertexColor(0.04, 0.055, 0.085, alpha)
  end
end

function TN:ShowToastPlaceholder()
  if self.toastStack then
    self.toastStack:SetFrameLevel(100)
    if self.toastStack.placeholder then self.toastStack.placeholder:Show() end
  end
end

function TN:HideToastPlaceholder()
  if self.toastStack then
    self.toastStack:SetFrameLevel(1)
    if self.toastStack.placeholder then self.toastStack.placeholder:Hide() end
  end
  local tc = self.db and self.db.profile and self.db.profile.toast
  if tc then tc.locked = true end
end

function TN:UpdateToastStack()
  if not self.toastStack then return end
  local toasts = self.toasts or {}
  local shown = #toasts > 0
  setShown(self.toastStack.anchorIcon, shown)
  setShown(self.toastStack.anchorText, shown)
  -- 有真实 toast 时隐藏占位框
  if shown and self.toastStack.placeholder:IsShown() then
    self.toastStack.placeholder:Hide()
  end
  for i, row in ipairs(self.toastStack.rows) do
    local toast = toasts[i]
    if toast then
      -- 差量：同一 toast.id 占位时只更新 ttl 文本 + 进度条宽度（每 tick 仅变化的字段）
      if row._toastId == toast.id then
        row.ttl:SetText(string.format("%.1fs", math.max(0, toast.remaining or 0)))
        local pct = math.max(0, math.min(1, (toast.remaining or 0) / (toast.total or 1)))
        row.progress:SetWidth((TN.hud and TN.hud:GetWidth() or LIST_DEFAULT_WIDTH) * pct)
      else
        local tone = TONE[toast.tone] or C.cyan
        row:SetBackdropBorderColor(tone[1], tone[2], tone[3], 0.75)
        row.toneBar:SetVertexColor(tone[1], tone[2], tone[3], 1)
        row.iconBox:SetVertexColor(tone[1], tone[2], tone[3], 0.12)
        row.icon:SetTexture(I[toast.icon] or I.crosshair)
        row.icon:SetVertexColor(tone[1], tone[2], tone[3], 1)
        row.cat:SetText(toast.cat or "提示")
        setColor(row.cat, tone)
        row.title:SetText(toast.title or "")
        setColor(row.title, toast.nameColor or C.text)
        row.sub:SetText(((toast.highlight and toast.highlight .. " · ") or "") .. (toast.subtitle or ""))
        row.progress:SetVertexColor(tone[1], tone[2], tone[3], 0.85)
        row._toastId = toast.id
        row._tone = tone
        -- 首帧也更新 ttl/progress
        row.ttl:SetText(string.format("%.1fs", math.max(0, toast.remaining or 0)))
        local pct = math.max(0, math.min(1, (toast.remaining or 0) / (toast.total or 1)))
        row.progress:SetWidth((TN.hud and TN.hud:GetWidth() or LIST_DEFAULT_WIDTH) * pct)
      end
      row:Show()
    else
      row:Hide()
      row._toastId = nil
    end
  end
end
