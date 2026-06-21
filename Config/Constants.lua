--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Config/Constants.lua
-- 纯数据常量：职业信息、威胁权重、克制矩阵、布局尺寸、威胁分级阈值。
-- 全部挂到 TN 命名空间，业务代码可直接引用。

local TN = TaoNiao

-- ── 服务器名（动态，用于跨服名拼接） ──
TN.LOCAL_REALM = (GetRealmName and GetRealmName()) or ""

-- ── TTL / 容量（秒、行数） ──
TN.enemyTTL   = 60   -- 敌人留存时长
TN.activeTTL  = 30   -- 活跃判定
TN.staleTTL   = 30   -- 过时判定
TN.maxRows    = 12   -- 列表最大行数

-- ── 职业显示信息 ──
TN.classInfo = {
	DRUID   = { text = "德", color = { 1.00, 0.49, 0.04 }, name = "德鲁伊" },
	HUNTER  = { text = "猎", color = { 0.67, 0.83, 0.45 }, name = "猎人" },
	MAGE    = { text = "法", color = { 0.41, 0.80, 0.94 }, name = "法师" },
	PALADIN = { text = "骑", color = { 0.96, 0.55, 0.73 }, name = "骑士" },
	PRIEST  = { text = "牧", color = { 0.95, 0.95, 0.95 }, name = "牧师" },
	ROGUE   = { text = "贼", color = { 1.00, 0.96, 0.41 }, name = "盗贼" },
	SHAMAN  = { text = "萨", color = { 0.00, 0.44, 0.87 }, name = "萨满" },
	WARLOCK = { text = "术", color = { 0.58, 0.51, 0.79 }, name = "术士" },
	WARRIOR = { text = "战", color = { 0.78, 0.61, 0.43 }, name = "战士" },
	UNKNOWN = { text = "?", color = { 0.85, 0.91, 0.96 }, name = "未知" },
}

TN.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- 反查表：中文名 → classFile（由 classInfo 派生）
TN.CLASS_FILE_BY_NAME = {}
for classFile, info in pairs(TN.classInfo or {}) do
	TN.CLASS_FILE_BY_NAME[info.name] = classFile
end

-- ── 威胁打分：职业权重 ──
TN.CLASS_WEIGHT = {
	WARRIOR = 1.0, ROGUE = 0.95, HUNTER = 0.85, PRIEST = 0.85,
	PALADIN = 0.8, MAGE = 0.7, WARLOCK = 0.7, SHAMAN = 0.65,
	DRUID = 0.6, UNKNOWN = 0.5,
}

-- 硬克制我的职业（对方出现 → 该敌人贡献 ×1.3）
TN.HARD_COUNTER_ME = {
	WARRIOR = { MAGE = true, WARLOCK = true },
	ROGUE   = { WARRIOR = true, PALADIN = true },
	MAGE    = { ROGUE = true, HUNTER = true },
	HUNTER  = { ROGUE = true, WARRIOR = true },
	PRIEST  = { ROGUE = true, HUNTER = true },
	PALADIN = { MAGE = true, WARLOCK = true },
	SHAMAN  = { ROGUE = true, WARLOCK = true },
	WARLOCK = { ROGUE = true, HUNTER = true },
	DRUID   = { ROGUE = true, HUNTER = true },
}
-- 我克制的职业（对方出现 → 该敌人贡献 ×0.7）
TN.I_COUNTER = {
	WARRIOR = { ROGUE = true },
	ROGUE   = { MAGE = true, WARLOCK = true, PRIEST = true },
	MAGE    = { WARRIOR = true, PALADIN = true },
	HUNTER  = { MAGE = true },
	PRIEST  = { WARRIOR = true, PALADIN = true },
	PALADIN = { ROGUE = true },
	SHAMAN  = { WARRIOR = true },
	WARLOCK = { MAGE = true, PRIEST = true },
	DRUID   = { WARRIOR = true },
}

-- ── 威胁打分调参 ──
TN.THREAT_BASE_SCORE        = 12    -- 单敌基础分
TN.THREAT_HARD_COUNTER_MUL  = 1.3   -- 硬克制我方乘数
TN.THREAT_ICOUNTER_MUL      = 0.7   -- 我方克制乘数
TN.THREAT_PERSONAL_WR_WEIGHT = 0.5  -- 对该敌个人胜率权重
TN.THREAT_GUILD_WR_WEIGHT   = 0.25  -- 对该敌公会胜率权重
TN.THREAT_MATE_MITIGATION   = 0.10  -- 每位近距队友威胁降幅
TN.THREAT_STRANGER_MITIGATION = 0.06 -- 每位散人友方威胁降幅
TN.THREAT_MIN_MITIGATION    = 0.4   -- 友方缓释后最小占比
TN.THREAT_MAX_SCORE         = 99    -- 威胁上限
TN.THREAT_MIN_SCORE         = 5     -- 威胁下限

