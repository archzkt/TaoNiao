--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/Widgets.lua
-- 底层 UI 构造函数：纹理/字体/图标/面板/圆角/可拖拽/图标按钮。
-- 挂到 TN.Widgets，UI.lua 顶部用 local 导入。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local I = Theme.I
local ROUNDED_BLOCK_TEXTURE = Theme.ROUNDED_BLOCK_TEXTURE
local RC = Theme.RC
local rgba = Theme.rgba
local setColor = Theme.setColor
local applyFont = Theme.applyFont

local Widgets = {}
TN.Widgets = Widgets

function Widgets.createTexture(parent, layer, color)
  local tex = parent:CreateTexture(nil, layer or "ARTWORK")
  tex:SetTexture("Interface\\Buttons\\WHITE8x8")
  tex:SetVertexColor(rgba(color))
  return tex
end

-- 弹出面板：不带 HUD 装饰，深色不透明背景，用于右键菜单和弹窗
function Widgets.createPopupPanel(name, width, height)
  local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1)
  frame:SetBackdropBorderColor(C.cyan[1], C.cyan[2], C.cyan[3], 1)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  return frame
end

function Widgets.createRoundedBlock(parent, layer, color)
  local tex = Widgets.createTexture(parent, layer, color)
  tex:SetTexture(ROUNDED_BLOCK_TEXTURE)
  return tex
end

-- 9-slice 圆角矩形：从 128×128 rounded-block 纹理中切片拼装
-- 角部独立渲染（radius×radius），边只沿单轴拉伸 → 角弧对称、不模糊
function Widgets.applyRoundedCorners(frame, radius, color)
  local p = {}
  -- 4 角
  p.tl = frame:CreateTexture(nil, "BACKGROUND")
  p.tl:SetTexture(ROUNDED_BLOCK_TEXTURE); p.tl:SetTexCoord(0, 0, 0, RC, RC, 0, RC, RC)
  p.tl:SetSize(radius, radius); p.tl:SetPoint("TOPLEFT"); p.tl:SetVertexColor(rgba(color))

  p.tr = frame:CreateTexture(nil, "BACKGROUND")
  p.tr:SetTexture(ROUNDED_BLOCK_TEXTURE); p.tr:SetTexCoord(1 - RC, 0, 1 - RC, RC, 1, 0, 1, RC)
  p.tr:SetSize(radius, radius); p.tr:SetPoint("TOPRIGHT"); p.tr:SetVertexColor(rgba(color))

  p.bl = frame:CreateTexture(nil, "BACKGROUND")
  p.bl:SetTexture(ROUNDED_BLOCK_TEXTURE); p.bl:SetTexCoord(0, 1 - RC, 0, 1, RC, 1 - RC, RC, 1)
  p.bl:SetSize(radius, radius); p.bl:SetPoint("BOTTOMLEFT"); p.bl:SetVertexColor(rgba(color))

  p.br = frame:CreateTexture(nil, "BACKGROUND")
  p.br:SetTexture(ROUNDED_BLOCK_TEXTURE); p.br:SetTexCoord(1 - RC, 1 - RC, 1 - RC, 1, 1, 1 - RC, 1, 1)
  p.br:SetSize(radius, radius); p.br:SetPoint("BOTTOMRIGHT"); p.br:SetVertexColor(rgba(color))

  -- 4 边（单轴拉伸，另一轴固定 radius）
  p.top = frame:CreateTexture(nil, "BACKGROUND")
  p.top:SetTexture(ROUNDED_BLOCK_TEXTURE); p.top:SetTexCoord(RC, 0, RC, RC, 1 - RC, 0, 1 - RC, RC)
  p.top:SetPoint("TOPLEFT", radius, 0); p.top:SetPoint("TOPRIGHT", -radius, 0)
  p.top:SetHeight(radius); p.top:SetVertexColor(rgba(color))

  p.bottom = frame:CreateTexture(nil, "BACKGROUND")
  p.bottom:SetTexture(ROUNDED_BLOCK_TEXTURE); p.bottom:SetTexCoord(RC, 1 - RC, RC, 1, 1 - RC, 1 - RC, 1 - RC, 1)
  p.bottom:SetPoint("BOTTOMLEFT", radius, 0); p.bottom:SetPoint("BOTTOMRIGHT", -radius, 0)
  p.bottom:SetHeight(radius); p.bottom:SetVertexColor(rgba(color))

  p.left = frame:CreateTexture(nil, "BACKGROUND")
  p.left:SetTexture(ROUNDED_BLOCK_TEXTURE); p.left:SetTexCoord(0, RC, 0, 1 - RC, RC, RC, RC, 1 - RC)
  p.left:SetPoint("TOPLEFT", 0, -radius); p.left:SetPoint("BOTTOMLEFT", 0, radius)
  p.left:SetWidth(radius); p.left:SetVertexColor(rgba(color))

  p.right = frame:CreateTexture(nil, "BACKGROUND")
  p.right:SetTexture(ROUNDED_BLOCK_TEXTURE); p.right:SetTexCoord(1 - RC, RC, 1 - RC, 1 - RC, 1, RC, 1, 1 - RC)
  p.right:SetPoint("TOPRIGHT", 0, -radius); p.right:SetPoint("BOTTOMRIGHT", 0, radius)
  p.right:SetWidth(radius); p.right:SetVertexColor(rgba(color))

  -- 中心（双轴拉伸）
  p.center = frame:CreateTexture(nil, "BACKGROUND")
  p.center:SetTexture(ROUNDED_BLOCK_TEXTURE); p.center:SetTexCoord(RC, RC, RC, 1 - RC, 1 - RC, RC, 1 - RC, 1 - RC)
  p.center:SetPoint("TOPLEFT", radius, -radius); p.center:SetPoint("BOTTOMRIGHT", -radius, radius)
  p.center:SetVertexColor(rgba(color))

  return p
end

function Widgets.createIcon(parent, icon, size, color)
  local tex = parent:CreateTexture(nil, "OVERLAY")
  tex:SetTexture(I[icon])
  tex:SetSize(size, size)
  tex:SetVertexColor(rgba(color or C.text2))
  return tex
end

function Widgets.createFont(parent, size, color, flags, weight)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  applyFont(fs, size, flags, weight)
  fs:SetJustifyH("LEFT")
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
  setColor(fs, color or C.text)
  return fs
end

function Widgets.createPanel(name, width, height)
  local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(rgba(C.panel))
  frame:SetBackdropBorderColor(rgba(C.line))
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)

  frame.topGlow = Widgets.createTexture(frame, "BORDER", { C.cyan[1], C.cyan[2], C.cyan[3], 0.18 })
  frame.topGlow:SetPoint("TOPLEFT", 12, -1)
  frame.topGlow:SetPoint("TOPRIGHT", -12, -1)
  frame.topGlow:SetHeight(1)

  local accents = {}
  for i = 1, 8 do
    accents[i] = Widgets.createTexture(frame, "OVERLAY", C.cyan)
    accents[i]:SetAlpha(0.72)
  end
  accents[1]:SetPoint("TOPLEFT", 5, -5); accents[1]:SetSize(16, 1)
  accents[2]:SetPoint("TOPLEFT", 5, -5); accents[2]:SetSize(1, 16)
  accents[3]:SetPoint("TOPRIGHT", -5, -5); accents[3]:SetSize(16, 1)
  accents[4]:SetPoint("TOPRIGHT", -5, -5); accents[4]:SetSize(1, 16)
  accents[5]:SetPoint("BOTTOMLEFT", 5, 5); accents[5]:SetSize(16, 1)
  accents[6]:SetPoint("BOTTOMLEFT", 5, 5); accents[6]:SetSize(1, 16)
  accents[7]:SetPoint("BOTTOMRIGHT", -5, 5); accents[7]:SetSize(16, 1)
  accents[8]:SetPoint("BOTTOMRIGHT", -5, 5); accents[8]:SetSize(1, 16)
  return frame
end

function Widgets.savePosition(frame, key)
  if key == "hud" then
    local point, _, _, x, y = frame:GetPoint(1)
    TN.db.profile.hud.point = point or "TOPLEFT"
    TN.db.profile.hud.x = math.floor(x + 0.5)
    TN.db.profile.hud.y = math.floor(y + 0.5)
    TN.db.profile.hud.w = frame:GetWidth()
    return
  end
  local point, _, _, x, y = frame:GetPoint(1)
  TN.db.profile[key].point = point or "TOPLEFT"
  TN.db.profile[key].x = x or 0
  TN.db.profile[key].y = y or 0
end

function Widgets.makeDraggable(frame, handle, key)
  if key == "hud" then
    frame:SetMovable(true)
    handle:SetScript("OnMouseDown", function(_, button)
      if button ~= "LeftButton" or TN.db.profile.locked then return end
      frame:StartMoving()
      frame.isMoving = true
    end)
    handle:SetScript("OnMouseUp", function()
      if not frame.isMoving then return end
      frame:StopMovingOrSizing()
      frame.isMoving = false
      local left = frame:GetLeft()
      local top = frame:GetTop()
      if not left or not top then return end
      local parentTop = UIParent:GetTop() or GetScreenHeight()
      TN.db.profile.hud.point = "TOPLEFT"
      TN.db.profile.hud.x = math.floor(left + 0.5)
      TN.db.profile.hud.y = math.floor(top - parentTop + 0.5)
    end)
    return
  end
  handle:EnableMouse(true)
  local function onThreshold()
    if not frame.pendingMove or frame.isMoving then return end
    local x, y = GetCursorPosition()
    if not x or not y then return end
    local dx = x - (frame.dragStartX or x)
    local dy = y - (frame.dragStartY or y)
    if (dx * dx + dy * dy) >= 16 then
      frame:StartMoving()
      frame.isMoving = true
      frame.pendingMove = false
    end
  end
  handle:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not TN.db.profile.locked then
      local x, y = GetCursorPosition()
      frame.dragStartX = x
      frame.dragStartY = y
      frame.pendingMove = true
      handle:SetScript("OnUpdate", onThreshold)
    end
  end)
  handle:SetScript("OnMouseUp", function()
    if frame.isMoving then
      frame:StopMovingOrSizing()
      Widgets.savePosition(frame, key)
      frame.isMoving = false
    end
    frame.pendingMove = false
    frame.dragStartX = nil
    frame.dragStartY = nil
    handle:SetScript("OnUpdate", nil)
  end)
  handle:SetScript("OnHide", function()
    frame.pendingMove = false
    frame.dragStartX = nil
    frame.dragStartY = nil
    handle:SetScript("OnUpdate", nil)
  end)
end

function Widgets.createIconButton(parent, icon, tooltip, onClick)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(26, 26)
  btn.bg = Widgets.createTexture(btn, "BACKGROUND", C.cell)
  btn.bg:SetAllPoints()
  btn.icon = Widgets.createIcon(btn, icon, 15, C.text2)
  btn.icon:SetPoint("CENTER")
  btn:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
    self.icon:SetVertexColor(rgba(C.cyan))
    if tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(tooltip, rgba(C.cyan))
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
    self.icon:SetVertexColor(rgba(C.text2))
    GameTooltip:Hide()
  end)
  btn:SetScript("OnClick", onClick)
  return btn
end

-- 创建圆形指示点：applyRoundedCorners 以 radius = size/2 构成正圆。
-- 返回的 frame 有 .SetVertexColor(r,g,b,a) 方法（代理到内部 9-slice 纹理）。
function Widgets.createCircle(parent, size, color)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  local rc = applyRoundedCorners(f, size / 2, color)
  f.SetVertexColor = function(_, r, g, b, a)
    for _, tex in pairs(rc) do tex:SetVertexColor(r, g, b, a) end
  end
  f.SetAlpha = function(_, a)
    for _, tex in pairs(rc) do tex:SetAlpha(a) end
  end
  return f
end

-- 通用工具：按字符数截断 UTF-8 字符串（超出加省略号）
function Widgets.utf8Truncate(text, maxChars)
  if not text or text == "" then return text end
  local count, pos, bytes = 0, 1, #text
  while pos <= bytes do
    count = count + 1
    if count > maxChars then
      return text:sub(1, pos - 1) .. "..."
    end
    local byte = text:byte(pos)
    if byte >= 240 then
      pos = pos + 4
    elseif byte >= 224 then
      pos = pos + 3
    elseif byte >= 192 then
      pos = pos + 2
    else
      pos = pos + 1
    end
  end
  return text
end
