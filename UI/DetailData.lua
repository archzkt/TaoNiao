--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailData.lua
-- 详情页 mock 数据与中文名→职业辅助（战绩/历史/死刑名单暂用演示数据，Phase 4 接真实数据）。
-- 暴露为 TN.DetailData 命名空间供各详情子页导入。

local TN = TaoNiao
local C = TN.Theme.C

local Data = {}
TN.DetailData = Data

Data.NAV = {
  { id = "records", icon = "crosshair", label = "数据统计" },
  { id = "highrisk", icon = "skull", label = "见之必杀" },
  { id = "phase", icon = "portal", label = "位面助手" },
  { id = "team", icon = "users", label = "团队助手" },
  { id = "settings", icon = "details", label = "设置" },
}

-- TODO(Phase 后续): 战斗明细/历史对手暂无真实数据源（需接战斗日志历史），
-- 今日战绩统计维度（与总战绩对应：击杀/死亡/交手玩家/荣誉击杀/胜率）
-- 真实数值由 DetailRecords 从 GetStats 注入（这里仅声明维度与样式）
Data.TODAY_STATS = {
  { key = "kills", icon = "swords", label = "今日击杀", value = "0", sub = "", color = C.green },
  { key = "deaths", icon = "skull", label = "今日死亡", value = "0", sub = "", color = C.red },
  { key = "honor", icon = "flag", label = "荣誉击杀", value = "0", sub = "", color = C.cyan },
  { key = "winrate", icon = "flag", label = "今日胜率", value = "0%", sub = "", color = C.purple },
}

Data.SIMPLE_ROWS = {
  team = {
    title = "团队助手",
    icon = "users",
    rows = {
      { "主力推进队", "10 人 · 2 坦克 · 3 治疗 · 5 输出", C.green },
      { "防守反击队", "10 人 · 2 坦克 · 4 治疗 · 4 输出", C.blue },
      { "临时侦察队", "3 人 · 盗贼 / 德鲁伊 / 猎人", C.yellow },
    },
  },
  settings = {
    title = "设置",
    icon = "details",
    rows = {
      { "雷达灵敏度", "使用 Spy 风格活跃分级和列表刷新", C.cyan },
      { "界面缩放", "随游戏 UIParent 缩放，保持位置记录", C.blue },
      { "Toast 提示", "仅发现潜行目标时显示在状态栏上方", C.red },
    },
  },
}

-- 中文名 → 颜色/职业字 辅助（mock 数据用中文名）
local CLASS_COLOR_BY_NAME = {
  ["战士"] = { 0.78, 0.61, 0.43, 1 },
  ["骑士"] = { 0.96, 0.55, 0.73, 1 },
  ["猎人"] = { 0.67, 0.83, 0.45, 1 },
  ["盗贼"] = { 1.00, 0.96, 0.41, 1 },
  ["牧师"] = { 1.00, 1.00, 1.00, 1 },
  ["萨满"] = { 0.00, 0.44, 0.87, 1 },
  ["法师"] = { 0.25, 0.78, 0.92, 1 },
  ["术士"] = { 0.53, 0.53, 0.93, 1 },
  ["德鲁伊"] = { 1.00, 0.49, 0.04, 1 },
}

function Data.classColor(className)
  return CLASS_COLOR_BY_NAME[className] or C.text2
end

function Data.classText(className)
  for _, info in pairs(TN.classInfo or {}) do
    if info.name == className then return info.text end
  end
  return "?"
end

-- "HH:MM" → 分钟数（排序用）
function Data.timeValue(timeText)
  local h, m = tostring(timeText or "0:0"):match("^(%d+):(%d+)$")
  return (tonumber(h) or 0) * 60 + (tonumber(m) or 0)
end

-- "Xs/Xm/Xh/Xd" → 分钟数（排序用，对齐 Spy 时间展示格式）
function Data.recentValue(text)
  text = tostring(text or "")
  if text == "—" then return 999999 end
  local s = text:match("^(%d+)s$")
  if s then return tonumber(s) / 60 end
  local m = text:match("^(%d+)m$")
  if m then return tonumber(m) end
  local h = text:match("^(%d+)h$")
  if h then return tonumber(h) * 60 end
  local d = text:match("^(%d+)d$")
  if d then return tonumber(d) * 1440 end
  return 999999
end
