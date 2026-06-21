--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/Toasts.lua
-- Toast 通知：推入与每 0.1s 衰减计数。

local TN = TaoNiao

-- Toast kind → 优先级（高优先可驱逐低优先，反之不行）
local TOAST_PRIORITY = {
  rival = 100, stealth = 90, matedeath = 80,
  matekill = 60,
  kill = 40, death = 40, spot = 30, phase = 30,
}
local TOAST_CFG = {
  stealth   = { cat = "潜行目标", tone = "yellow", icon = "skull",     ttl = 4.5 },
  rival     = { cat = "必杀目标", tone = "red",    icon = "skull",     ttl = 5 },
  spot      = { cat = "注意",   tone = "yellow", icon = "crosshair", ttl = 2.8 },
  kill      = { cat = "击杀",   tone = "green",  icon = "swords",    ttl = 2.8 },
  death     = { cat = "死亡",   tone = "purple", icon = "skull",     ttl = 3.8 },
  matedeath = { cat = "队友阵亡", tone = "orange", icon = "skull",   ttl = 4 },
  matekill  = { cat = "队友击杀", tone = "green",  icon = "swords",  ttl = 3 },
  phase     = { cat = "提示",   tone = "blue",   icon = "portal",    ttl = 2.6 },
}

-- Toast kind → 音效文件（音效由 Spy 项目提供，已复制到 Sounds/）
-- nil 表示该类型不播放音效。highRisk 标记仅在 onlyKOS 模式下放行。
local SOUND_DIR = "Interface\\AddOns\\TaoNiao\\Sounds\\"
local TOAST_SOUND = {
  stealth = SOUND_DIR .. "detected-stealth.mp3",
  rival   = SOUND_DIR .. "detected-kos.mp3",
  spot    = SOUND_DIR .. "detected-nearby.mp3",
  kill    = SOUND_DIR .. "list-add.mp3",
  death   = SOUND_DIR .. "list-remove.mp3",
  phase   = nil,
}

function TN:PushToast(kind, title, highlight, subtitle, nameColor, force)
  -- Toast 过滤：禁用类型不推送（force 跳过过滤，供测试用）
  local filters = self.db and self.db.profile and self.db.profile.toastFilters
  if not force and filters and filters[kind] == false then return end
  -- 同类型间隔限流：避免同一类事件在短时间内刷屏
  if not force then
    self._toastCooldowns = self._toastCooldowns or {}
    local now = GetTime()
    local last = self._toastCooldowns[kind] or 0
    if now - last < 1 then return end
    self._toastCooldowns[kind] = now
  end
  if not self.toasts then self.toasts = {} end
  -- 同类型去重：移除队列中已有的同 kind toast，确保每种最多 1 条
  for i = #self.toasts, 1, -1 do
    if self.toasts[i].kind == kind then
      table.remove(self.toasts, i)
    end
  end
  self.toastId = (self.toastId or 0) + 1
  local c = TOAST_CFG[kind] or TOAST_CFG.spot
  table.insert(self.toasts, 1, {
    id = self.toastId,
    kind = kind,
    cat = c.cat,
    tone = c.tone,
    icon = c.icon,
    total = c.ttl,
    remaining = c.ttl,
    title = title,
    highlight = highlight,
    subtitle = subtitle,
    nameColor = nameColor,
  })
  -- 淘汰最低优先级（同分则保留先入队，即位置靠前的）
  while #self.toasts > 2 do
    local lowestIdx = 1
    local lowestPri = TOAST_PRIORITY[self.toasts[1].kind or kind] or 0
    for i = 1, #self.toasts do
      local p = TOAST_PRIORITY[self.toasts[i].kind or kind] or 0
      if p < lowestPri then lowestIdx = i; lowestPri = p end
    end
    table.remove(self.toasts, lowestIdx)
  end
  self:PlayToastSound(kind)
  self:UpdateToastStack()
end

-- 按 kind 播放对应音效；受 sound.enabled / sound.onlyKOS / sound.channel 控制。
function TN:PlayToastSound(kind)
  local s = self.db and self.db.profile and self.db.profile.sound
  if not s or not s.enabled then return end
  local file = TOAST_SOUND[kind]
  if not file then return end
  -- onlyKOS：仅极危/潜行（高危）提示发声，普通附近敌人/位面提示静音
  if s.onlyKOS and kind ~= "rival" and kind ~= "stealth" then return end
  PlaySoundFile(file, s.channel or "SFX")
end

function TN:UpdateToasts()
  if self.db.profile.enabled == false then return end
  if not self.toasts or #self.toasts == 0 then return end
  for i = #self.toasts, 1, -1 do
    local toast = self.toasts[i]
    toast.remaining = toast.remaining - 0.1
    if toast.remaining <= 0 then
      table.remove(self.toasts, i)
    end
  end
  self:UpdateToastStack()
end
