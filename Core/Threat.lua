--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/Threat.lua
-- 多因子威胁打分：基础分 × 职业权重 × 克制 × 个人胜率 × 公会胜率，再按友方人数缓释。
-- 所有调参常量集中在 Config/Constants.lua。返回 { score, breakdown }。

local TN = TaoNiao

function TN:CalcThreat(enemies, kosSet, kosWL, guildWL, playerClass, nearbyMates, nearbyFriendlies)
  local base = TN.THREAT_BASE_SCORE or 12
  local raw = 0
  local countByWeight = 0
  local counterNote = nil
  local guildNote = nil
  local hard = TN.HARD_COUNTER_ME[playerClass] or {}
  local fav = TN.I_COUNTER[playerClass] or {}
  local function guildWR(guild)
    if not guild or guild == "" then return 0 end
    local g = guildWL[guild]
    if not g then return 0 end
    local total = (g.win or 0) + (g.loss or 0)
    if total <= 0 then return 0 end
    return (g.loss or 0) / total
  end
  for _, enemy in ipairs(enemies) do
    if (enemy.age or 0) <= self.enemyTTL then
      local cls = enemy.classFile or "UNKNOWN"
      local cw = TN.CLASS_WEIGHT[cls] or 0.5
      if hard[cls] then cw = cw * (TN.THREAT_HARD_COUNTER_MUL or 1.3); counterNote = cls end
      if fav[cls] then cw = cw * (TN.THREAT_ICOUNTER_MUL or 0.7) end
      if kosSet and kosSet[enemy.name] then
        local wl = kosWL and kosWL[enemy.name]
        local wins, losses = enemy.myWins or 0, enemy.myLosses or 0
        if wl then wins = wins + wl.win; losses = losses + wl.loss end
        local total = wins + losses
        local wr = total > 0 and (losses / total) or 0
        cw = cw * (1 + (TN.THREAT_PERSONAL_WR_WEIGHT or 0.5) * wr)
      end
      local gwr = guildWR(enemy.guild)
      if gwr > 0 then
        cw = cw * (1 + (TN.THREAT_GUILD_WR_WEIGHT or 0.25) * gwr)
        if not guildNote then guildNote = enemy.guild end
      end
      raw = raw + base * cw
      countByWeight = countByWeight + 1
    end
  end
  local mateCount = nearbyMates or 0
  local strangerCount = math.max(0, (nearbyFriendlies or 0) - mateCount)
  local mitigation = math.max(TN.THREAT_MIN_MITIGATION or 0.4, 1 - (TN.THREAT_MATE_MITIGATION or 0.10) * mateCount - (TN.THREAT_STRANGER_MITIGATION or 0.06) * strangerCount)
  raw = raw * mitigation
  local score = math.floor(math.min(TN.THREAT_MAX_SCORE or 99, math.max(TN.THREAT_MIN_SCORE or 5, raw)) + 0.5)
  if countByWeight == 0 then score = (TN.THREAT_MIN_SCORE or 5) end
  return {
    score = score,
    breakdown = {
      enemies = countByWeight,
      nearbyMates = nearbyMates or 0,
      nearbyFriendlies = nearbyFriendlies or 0,
      mitigation = mitigation,
      counter = counterNote,
      guild = guildNote,
      playerClass = playerClass,
    },
  }
end
