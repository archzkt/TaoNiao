--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Config/Defaults.lua
-- AceDB 默认值 + profile 嵌套表实化逻辑。
-- AceDB 对 defaults 里的子表默认走代理表，直接改子字段（如 phaseHelpers[i].helper）
-- 可能不落盘；EnsureProfileTables 强制实化以规避该隐患。

local TN = TaoNiao
TN.Config = TN.Config or {}

local Defaults = {
	profile = {
		enabled = true,
		locked = false,
		collapsed = false,
		scale = 1.0,
		snapList = false,
		-- 副本/战场自动关闭
		disableInInstance = true,
		disableInBattleground = true,
		-- 配色方案：default / shadow / warmgrey / icecrown
		colorScheme = "default",
		-- 威胁指数呼吸灯特效
		threatBreathing = false,
		-- 面板不透明度（0.3-1，应用到 HUD/列表背景）
		uiAlpha = 0.92,
		announceChannel = "INSTANCE_CHAT",
		-- 自动通报：侦测到新敌人且在小队/团队时自动发送（参考 Spy 的 Announce）
		autoAnnounce = false,
		-- 自动通报目标频道：AUTO=智能（团→RAID，队→PARTY），PARTY/RAID/GUILD=指定
		autoAnnounceChannel = "AUTO",
		-- 仅通报死刑名单成员（对齐 Spy OnlyAnnounceKoS）
		onlyAnnounceKoS = false,
		-- 乘坐飞行路线时关闭通报（对齐 Spy StopAlertsOnTaxi）
		stopAlertsOnTaxi = true,
		-- 用户通过位面助手切换后记录的当前位面（游戏无公开 API，仅本地追踪）
		currentPhase = nil,
		phaseHelpers = {
			{ name = "位面 1", helper = "", message = "1", enabled = false },
			{ name = "位面 2", helper = "", message = "2", enabled = false },
			{ name = "位面 3", helper = "", message = "3", enabled = false },
			{ name = "位面 4", helper = "", message = "4", enabled = false },
			{ name = "位面 5", helper = "", message = "5", enabled = false },
		},
		hud = { point = "TOPLEFT", x = 40, y = -40 },
		list = { point = "TOPLEFT", x = 40, y = -360, h = 0, maxVisibleRows = 12 },
		team = {
			autoInvite = false,
			inviteKeyword = "加 1 进组",
			autoConvertRaid = false,
			autoPromote = false,
			autoFreeLoot = false,
			disbandMessage = "队伍即将解散，感谢各位！",
			savedMembers = {},
			-- 队伍保存时间戳（time()，用于恢复时判定过期）
			savedAt = nil,
			-- 恢复过期阈值（分钟），0=永不过期
			restoreExpire = 30,
			-- HUD 团队按钮显示的快捷操作 id 列表（可在详情页自定义）
			quickActions = { "save", "disband", "restore" },
		},
		-- 音效告警（参考 Spy：检测到敌人/KOS/潜行时播放提示音）
		sound = {
			enabled = true,
			-- 声音通道：SFX / Master / Music / Ambience / Dialog
			channel = "SFX",
			-- 仅极危（rival/KOS）与潜行时才播放，普通附近敌人不响
			onlyKOS = false,
		},
		-- Toast 弹窗：位置与不透明度
		toast = {
			alpha = 0.70,
			locked = true,
			x = 0,
			y = -140,
		},
		-- Toast 提醒过滤（kind → 启用/禁用）
		toastFilters = {
			stealth   = true,
			rival     = true,
			spot      = false,
			kill      = false,
			death     = false,
			matedeath = true,
			matekill  = true,
		},
	},
	char = {
		kills = 0,
		deaths = 0,
		killsToday = 0,
		deathsToday = 0,
		todayDate = nil,
		-- 公会历史胜负（威胁打分的公会因子，持久化，角色隔离）
		guildWL = {},
		-- 死刑名单（用户维护的仇敌列表，持久化，角色隔离）
		kosList = {},
		-- 战斗明细（每场交战记录，最新在前，角色隔离）
		battleLog = {},
		-- 历史对手统计（per-敌人 胜负，按敌人名索引，角色隔离）
		matchups = {},
	},
}
TN.Config.Defaults = Defaults

-- 把默认值中的数组/嵌套表深拷贝进真实存档，确保后续字段修改能持久化。

local function fillDefaults(defaults, target)
  for k, v in pairs(defaults) do
    if target[k] == nil then
      target[k] = (type(v) == "table") and {} or v
    end
  end
end

function TN:EnsureProfileTables()
  local p = self.db.profile
  if not p then return end
  if p.uiAlpha == nil then p.uiAlpha = 0.92 end
  if p.autoAnnounce == nil then p.autoAnnounce = true end
  if p.autoAnnounceChannel == nil then p.autoAnnounceChannel = "AUTO" end
  if p.onlyAnnounceKoS == nil then p.onlyAnnounceKoS = false end
  if p.stopAlertsOnTaxi == nil then p.stopAlertsOnTaxi = true end
  -- 位面助手：缺失或长度不足 5 时，用全新表重建（保留已有项数据）
  if not p.phaseHelpers or #p.phaseHelpers < 5 then
    local PH = Defaults.profile.phaseHelpers
    local merged = {}
    for i = 1, 5 do
      local cur = p.phaseHelpers and p.phaseHelpers[i] or {}
      local tpl = PH[i]
      merged[i] = {
        name = cur.name or tpl.name,
        helper = cur.helper or tpl.helper,
        message = cur.message or tpl.message,
        enabled = cur.enabled or tpl.enabled,
      }
    end
    p.phaseHelpers = merged
  end
  -- 团队助手嵌套表实化
  if not p.team then p.team = {} end
  fillDefaults(Defaults.profile.team, p.team)
  if not p.team.savedMembers then p.team.savedMembers = {} end
  if not p.team.quickActions or #p.team.quickActions == 0 then
    p.team.quickActions = { "save", "disband", "restore" }
  end
  -- 音效配置嵌套表实化
  if not p.sound then p.sound = {} end
  fillDefaults(Defaults.profile.sound, p.sound)
  -- Toast 弹窗配置实化
  if not p.toast then p.toast = {} end
  fillDefaults(Defaults.profile.toast, p.toast)
  -- Toast 提醒过滤实化
  if not p.toastFilters then p.toastFilters = {} end
  fillDefaults(Defaults.profile.toastFilters, p.toastFilters)
end

-- 确保角色隔离的持久化表已实化（角色级数据）
function TN:EnsureCharTables()
	local ch = self.db.char
	if not ch then return end
	-- 公会胜负表
	if not ch.guildWL then ch.guildWL = {} end
	-- 死刑名单
	if not ch.kosList then ch.kosList = {} end
	-- 战斗明细
	if not ch.battleLog then ch.battleLog = {} end
	-- 历史对手统计
	if not ch.matchups then ch.matchups = {} end
end
