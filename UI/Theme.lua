--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/Theme.lua
-- 视觉主题：色板、字体、图标路径、布局尺寸、通用颜色/字体辅助函数。
-- 挂到 TN.Theme 命名空间，UI.lua 顶部用 local 导入。

local TN = TaoNiao
local Theme = {}
TN.Theme = Theme

-- ── 色板 ──
Theme.Schemes = {
  default = {
    name  = "默认经典",
    panel  = { 0.04, 0.06, 0.09, 0.86 },
    panel2 = { 0.055, 0.082, 0.125, 0.94 },
    line     = { 0.47, 0.67, 0.82, 0.18 },
    lineSoft = { 0.47, 0.67, 0.82, 0.10 },
    cyan    = { 0.20, 0.78, 0.91, 1 },
    text    = { 0.92, 0.95, 0.97, 1 },
    text2   = { 0.62, 0.70, 0.76, 1 },
    text3   = { 0.40, 0.47, 0.54, 1 },
  },
  shadow = {
    name  = "暗影",
    panel  = { 0.047, 0.047, 0.047, 0.90 },
    panel2 = { 0.063, 0.063, 0.063, 0.94 },
    line     = { 0.50, 0.50, 0.64, 0.16 },
    lineSoft = { 0.50, 0.50, 0.64, 0.08 },
    cyan    = { 0.41, 0.41, 1.00, 1 },
    text    = { 0.90, 0.90, 0.94, 1 },
    text2   = { 0.60, 0.60, 0.68, 1 },
    text3   = { 0.38, 0.38, 0.45, 1 },
  },
  warmgrey = {
    name  = "鼠灰",
    panel  = { 0.078, 0.078, 0.074, 0.88 },
    panel2 = { 0.094, 0.094, 0.090, 0.94 },
    line     = { 0.76, 0.72, 0.53, 0.18 },
    lineSoft = { 0.76, 0.72, 0.53, 0.10 },
    cyan    = { 0.94, 0.72, 0.16, 1 },
    text    = { 0.90, 0.88, 0.84, 1 },
    text2   = { 0.62, 0.60, 0.56, 1 },
    text3   = { 0.40, 0.38, 0.36, 1 },
  },
  icecrown = {
    name  = "冰冠",
    panel  = { 0.031, 0.051, 0.078, 0.86 },
    panel2 = { 0.043, 0.070, 0.102, 0.94 },
    line     = { 0.47, 0.78, 0.91, 0.18 },
    lineSoft = { 0.47, 0.78, 0.91, 0.10 },
    cyan    = { 0.47, 0.78, 0.91, 1 },
    text    = { 0.90, 0.94, 0.97, 1 },
    text2   = { 0.60, 0.68, 0.76, 1 },
    text3   = { 0.38, 0.45, 0.54, 1 },
  },
}

-- 初始化默认配色
Theme.C = {
  panel  = { 0.04, 0.06, 0.09, 0.86 },
  panel2 = { 0.055, 0.082, 0.125, 0.94 },
  cell   = { 1, 1, 1, 0.035 },
  cellHi = { 1, 1, 1, 0.07 },
  line     = { 0.47, 0.67, 0.82, 0.18 },
  lineSoft = { 0.47, 0.67, 0.82, 0.10 },
  cyan    = { 0.20, 0.78, 0.91, 1 },
  red     = { 1.00, 0.30, 0.31, 1 },
  orange  = { 1.00, 0.54, 0.24, 1 },
  yellow  = { 1.00, 0.78, 0.24, 1 },
  green   = { 0.29, 0.87, 0.50, 1 },
  blue    = { 0.30, 0.62, 1.00, 1 },
  purple  = { 0.71, 0.48, 1.00, 1 },
  text    = { 0.92, 0.95, 0.97, 1 },
  text2   = { 0.62, 0.70, 0.76, 1 },
  text3   = { 0.40, 0.47, 0.54, 1 },
}

-- 色调别名
Theme.TONE = {
  red = Theme.C.red, orange = Theme.C.orange, yellow = Theme.C.yellow,
  green = Theme.C.green, blue = Theme.C.blue, purple = Theme.C.purple,
}

function Theme:ApplyScheme(key)
  local scheme = self.Schemes[key or "default"] or self.Schemes.default
  if not scheme then return end
  -- 原地更新 C 表值，保证所有文件级 local C 引用不失效
  for k, v in pairs(scheme) do
    local target = self.C[k]
    if target then
      target[1], target[2], target[3], target[4] = v[1], v[2], v[3], v[4]
    end
  end
  -- 更新 TONE 和 STAT_COLOR 映射
  self.TONE.red = self.C.red; self.TONE.orange = self.C.orange; self.TONE.yellow = self.C.yellow
  self.TONE.green = self.C.green; self.TONE.blue = self.C.blue; self.TONE.purple = self.C.purple
  self.STAT_COLOR.detected = self.C.cyan; self.STAT_COLOR.high = self.C.red
  self.STAT_COLOR.mates = self.C.blue; self.STAT_COLOR.friendlies = self.C.blue
  self.STAT_COLOR.kills = self.C.green; self.STAT_COLOR.deaths = self.C.purple
end

-- ── 图标路径 ──
local TEX = "Interface\\AddOns\\TaoNiao\\Textures\\Icons\\"
Theme.I = {
  buoy      = TEX .. "buoy.tga",
  chevron   = TEX .. "chevron.tga",
  crosshair = TEX .. "crosshair.tga",
  flag      = TEX .. "flag.tga",
  details   = TEX .. "details.tga",
  megaphone = TEX .. "megaphone.tga",
  pin       = TEX .. "pin.tga",
  portal    = TEX .. "portal.tga",
  skull     = TEX .. "skull.tga",
  swords    = TEX .. "swords.tga",
  users     = TEX .. "users.tga",
}

-- ── 字体路径 ──
-- 主体字体用系统字体（STANDARD_TEXT_FONT，中文客户端可正常显示中文），
-- 规避大字体文件加载失败/超时导致文字不渲染的问题。
local F_DIR = "Interface\\AddOns\\TaoNiao\\Fonts\\"
Theme.F = {
  regular = STANDARD_TEXT_FONT,
  medium  = STANDARD_TEXT_FONT,
  bold    = STANDARD_TEXT_FONT,
  -- 威胁徽章专用：仅含致命/高危/危险/警觉/平静/和平 + 数字的粗体子集（10KB）
  badge   = F_DIR .. "NotoSansSC-Bold.ttf",
  number  = F_DIR .. "Rajdhani-Bold.ttf",
}

Theme.ROUNDED_BLOCK_TEXTURE = "Interface\\AddOns\\TaoNiao\\Textures\\rounded-block.tga"

-- ── 布局尺寸 ──
Theme.Layout = {
  LIST_DEFAULT_WIDTH = 300,
  LIST_MIN_WIDTH     = 300,
  LIST_MAX_WIDTH     = 460,
  HUD_EXPANDED_HEIGHT  = 180,
  HUD_COLLAPSED_HEIGHT = 40,
  HUD_STAT_TOP    = -90,
  HUD_STAT_HEIGHT = 44,
  HUD_FORCE_TOP   = -48,
  HUD_FORCE_HEIGHT = 38,
  HUD_ACTION_TOP  = -138,
  HUD_PHASE_BAR_H = 30,
  GROUP_GAP       = 0,
  LIST_HEADER_HEIGHT = 30,
  LIST_ROWS_TOP    = 48,
  LIST_ROW_HEIGHT  = 20,
  LIST_ROW_PITCH   = 22,
  LIST_BOTTOM_PAD  = 8,
  LIST_MIN_ROWS    = 1,
  LIST_MAX_ROWS    = 12,
  DETAIL_WIDTH        = 980,
  DETAIL_HEIGHT       = 860,
  DETAIL_TITLE_HEIGHT = 72,
  DETAIL_SIDE_WIDTH   = 206,
}
-- 派生尺寸
local L = Theme.Layout
L.LIST_MIN_HEIGHT = L.LIST_ROWS_TOP + L.LIST_MIN_ROWS * L.LIST_ROW_PITCH + L.LIST_BOTTOM_PAD
L.LIST_MAX_HEIGHT = L.LIST_ROWS_TOP + L.LIST_MAX_ROWS * L.LIST_ROW_PITCH + L.LIST_BOTTOM_PAD
L.DETAIL_CONTENT_WIDTH = L.DETAIL_WIDTH - L.DETAIL_SIDE_WIDTH - 44

-- 9-slice 源纹理圆角比例（8px / 128px）
Theme.RC = 8 / 128

-- ── 颜色辅助 ──
local C = Theme.C
function Theme.rgba(color) return color[1], color[2], color[3], color[4] end
function Theme.setColor(fs, color) fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
function Theme.setShown(region, shown)
  if shown then region:Show() else region:Hide() end
end
function Theme.applyFont(fs, size, flags, weight)
  local F = Theme.F
  local path = F[weight or "regular"] or F.regular
  if not fs:SetFont(path, size, flags or "") then
    fs:SetFont(STANDARD_TEXT_FONT, size, flags or "")
  end
end

-- 语义颜色：每个指标对应固定色
Theme.STAT_COLOR = {
  detected    = C.cyan,
  high        = C.red,
  mates       = C.blue,
  friendlies  = C.blue,
  kills       = C.green,
  deaths      = C.purple,
}

function Theme.statColor(key, value)
  if key == "threat" then
    if value >= 80 then return C.red end
    if value >= 60 then return C.orange end
    if value >= 25 then return C.yellow end
    return C.green
  end
  return Theme.STAT_COLOR[key] or C.text
end

function Theme.enemyThreatColor(enemy)
  if enemy.highRisk then return C.red end
  if (enemy.events or 0) >= 3 then return C.orange end
  if (enemy.age or 0) <= 8 then return C.yellow end
  return C.text
end

-- ── 威胁分级文案 + 色 ──
function Theme.threatTone(pct)
  if pct >= 80 then return "致命", C.red end
  if pct >= 60 then return "高危", C.orange end
  if pct >= 40 then return "危险", C.yellow end
  if pct >= 25 then return "警觉", C.yellow end
  if pct >= 10 then return "平静", C.green end
  return "和平", C.green
end
