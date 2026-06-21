--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core.lua
-- 生命周期：OnInitialize / OnEnable（事件注册 + 定时器）/ 区域与队伍事件 / 聊天命令。
-- 业务方法已拆分到 Core/ 各模块（PlayerTracker/LayerDetector/Outcomes/Threat/Stats/Toasts/Announce）。

local AceDB = LibStub("AceDB-3.0")
local TN = TaoNiao
local defaults = TN.Config.Defaults

-- ── 渲染节流：数据层只标记脏，由单一 0.2s 定时器统一刷新 UI ──
-- 避免 CombatLogEvent / ScanUnit / PruneEnemies 等高频源每秒触发 5-10 次 UpdateHUD。
function TN:MarkDirty()
  if self.db.profile.enabled == false then return end
  self.hudDirty = true
end

-- 渲染节拍：脏则刷新一次并清位。由 OnEnable 的 ScheduleRepeatingTimer 驱动。
function TN:RenderTick()
  if self.hudDirty then
    self.hudDirty = false
    self:UpdateHUD()
  end
  -- 威胁指示灯呼吸动画（展开/折叠模式下持续刷新）
  if self.hud and self.db.profile.threatBreathing then
    local miniShown = self.hud.mini and self.hud.mini:IsShown()
    local expandedShown = self.hud.stats and self.hud.stats[4] and self.hud.stats[4]:IsShown()
    if miniShown or expandedShown then
      self:UpdateThreatLamp()
    end
  end
end

function TN:UpdateThreatLamp()
  local lamp = self.hud and self.hud.mini and self.hud.mini.threatLamp
  local statCell = self.hud and self.hud.stats and self.hud.stats[4]
  if not lamp and not statCell then return end

  local stats = self:GetStats()
  local threat = stats.threat or 0
  local _, tone = self:ThreatTone(threat)
  local t = GetTime()
  local freq
  if threat >= 80 then freq = 2.0
  elseif threat >= 60 then freq = 0.8
  elseif threat >= 25 then freq = 0.4
  else freq = 0.2 end

  local v = 0.5 + 0.5 * math.sin(2 * math.pi * freq * t)
  local bri = v ^ 2.2
  local s = 9 + bri * 8
  local a = 0.45 + bri * 0.5

  if threat >= 80 then
    local flash = math.floor(t * 8) % 2
    s = flash == 1 and 18 or 12
    a = flash == 1 and 0.95 or 0.5
  end

  -- mini 面板呼吸灯
  if lamp then
    lamp:SetSize(s, s)
    lamp:SetVertexColor(tone[1], tone[2], tone[3], a)
  end

  -- 展开面板危险指数文字呼吸
  if statCell and statCell.value and statCell:IsShown() then
    local r, g, b = tone[1], tone[2], tone[3]
    statCell.value:SetTextColor(r, g, b, a)
  end
end

function TN:OnInitialize()
  self.db = AceDB:New("TaoNiaoDB", defaults, true)
  -- 应用配色方案（必须在 UI 创建之前）
  self.Theme:ApplyScheme(self.db.profile.colorScheme)
  -- 强制把数组/嵌套表实化到 profile，避免 AceDB 默认值代理表导致字段修改不落盘
  self:EnsureProfileTables()
  -- 强制把角色隔离的嵌套表实化到 char
  self:EnsureCharTables()
  self.enemies = {}
  self.enemyOrder = {}
  self.enemiesByName = {}
  self.friendlies = {}
  self.toasts = {}
  self.friendlyClassCounts = {}
  self.nearbyMates = 0
  self.nearbyFriendlies = 0
  self.toastId = 0
  self.playerGUID = UnitGUID("player")
  self.playerName = UnitName("player")
  -- 当前世界分层缓存（解析 Creature GUID 得到，副本内为 nil）
  self.currentLayer = nil
  -- 位面检测指纹集合持久化在 db.char.layerSet 中，跨会话累计
  self:CreateHUD()
  self:RegisterChatCommand("taoniao", "SlashCommand")
  self:RegisterChatCommand("tn", "SlashCommand")
end

function TN:OnEnable()
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
  self:RegisterEvent("PLAYER_TARGET_CHANGED", "ScanTarget")
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "ScanMouseover")
  self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "ScanNamePlate")
  self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnNamePlateRemoved")
  self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
  self:RegisterEvent("ZONE_CHANGED", "UpdateHUD")
  self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateHUD")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
  self:RegisterEvent("PLAYER_DEAD", "OnPlayerDead")
  self:RegisterEvent("CHAT_MSG_WHISPER", "OnTeamEvent")
  self:EnableSpyComm()
  self:EnableLayerComm()
  self:EnableTeamComm()
  self:ScheduleRepeatingTimer("PruneEnemies", 1)
  self:ScheduleRepeatingTimer("PruneFriendlies", 1)
  self:ScheduleRepeatingTimer("UpdateToasts", 0.1)
  self:ScheduleRepeatingTimer("ScanVisibleUnits", 0.5)
  self:ScheduleRepeatingTimer("ScanFriendlies", 2)
  self:ScheduleRepeatingTimer("RenderTick", 0.2)  -- 统一渲染节拍
  self.hudDirty = false
  self:CheckInstanceState()
  self:UpdateHUD()
end

function TN:PlayerEnteringWorld()
  self.playerGUID = UnitGUID("player")
  self.playerName = UnitName("player")
  self:ClearLayer()
  self:CheckInstanceState()
  self:MarkDirty()
end

function TN:OnGroupRosterUpdate()
  self:ClearLayer()
  self:MarkDirty()
  self:OnTeamEvent("GROUP_ROSTER_UPDATE")
end

function TN:OnZoneChanged()
  -- 跨大区域分层可能变化，清空缓存待重新检测
  self:ClearLayer()
  self:MarkDirty()
  self:CheckInstanceState()
end

function TN:CheckInstanceState()
  local p = self.db and self.db.profile
  if not p then return end
  local _, instType = GetInstanceInfo()
  local shouldDisable = false
  if instType == "pvp" and p.disableInBattleground then
    shouldDisable = true
  elseif instType ~= "none" and p.disableInInstance then
    shouldDisable = true
  end
  if shouldDisable and (p.enabled ~= false) then
    p._wasEnabled = true
    p.enabled = false
    self.hudDirty = true
  elseif not shouldDisable and p.enabled == false and p._wasEnabled then
    p.enabled = true
    p._wasEnabled = nil
    self.hudDirty = true
  end
end

function TN:SetColorScheme(key)
  local p = self.db and self.db.profile
  if not p then return end
  p.colorScheme = key
end

function TN:SlashCommand(input)
  input = (input or ""):lower()
  if input == "lock" then
    self.db.profile.locked = not self.db.profile.locked
    self:Print(self.db.profile.locked and "HUD 已锁定。" or "HUD 已解锁。")
  elseif input == "reset" then
    self.db.profile.hud = { point = "TOPLEFT", x = 40, y = -40 }
    self.db.profile.list = { point = "TOPLEFT", x = 40, y = -360, h = 0, maxVisibleRows = 12 }
    self:RestorePositions()
  elseif input == "clear" then
    self:ClearEnemies()
  elseif input == "sound" then
    local s = self.db.profile.sound
    s.enabled = not s.enabled
    self:Print(s.enabled and "音效告警已启用。" or "音效告警已禁用。")
  elseif input == "sound kos" then
    local s = self.db.profile.sound
    s.onlyKOS = not s.onlyKOS
    self:Print(s.onlyKOS and "仅极危/潜行时播放音效。" or "全部提示均播放音效。")
  else
    self:Print("/tn lock 锁定/解锁, /tn reset 重置位置, /tn clear 清空列表, /tn sound 开关音效, /tn sound kos 仅高危发声。")
  end
end
