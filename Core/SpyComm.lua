--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/SpyComm.lua
-- 监听 Spy 插件通信，接收其他玩家探测到的敌人数据并加入本地追踪

local TN = TaoNiao

local SPY_PREFIX = "[Spy]"

function TN:EnableSpyComm()
  if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then
    if RegisterAddonMessagePrefix then
      RegisterAddonMessagePrefix(SPY_PREFIX)
    end
  else
    C_ChatInfo.RegisterAddonMessagePrefix(SPY_PREFIX)
  end
  self:RegisterEvent("CHAT_MSG_ADDON", "OnSpyCommReceived")
end

function TN:OnSpyCommReceived(event, prefix, message, distribution, sender)
  if prefix ~= SPY_PREFIX or not message or sender == self.playerName then return end
  local version, player, class, level, race, zone, subZone, mapX, mapY, guild, mapID = strsplit("|", message)
  if not player or player == "" then return end
  -- 只处理敌对阵营玩家
  local classFile = class and class ~= "" and class or "UNKNOWN"
  local ci = self.classInfo and self.classInfo[classFile]
  if not ci or not ci.enemy then return end
  -- 记录到本地对手统计（无 GUID，用名字索引）
  local mu = self.db.char.matchups or {}
  self.db.char.matchups = mu
  if not mu[player] then
    mu[player] = {
      cls = ci and ci.name or classFile,
      lv = level or "??",
      guild = guild or "",
      rank = "",
      win = 0, loss = 0,
      last = time and time() or 0,
      zone = zone or "未知区域",
    }
  else
    if level and tonumber(level) then mu[player].lv = level end
    if guild and guild ~= "" then mu[player].guild = guild end
    mu[player].last = time and time() or 0
    mu[player].zone = zone or mu[player].zone
  end
  self:MarkDirty()
end
