--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/Stats.lua
-- 统计聚合：今日击杀/死亡跨日重置 + GetStats 汇总（威胁打分、死刑逃犯、附近友方等）。

local TN = TaoNiao

-- 跨日时重置今日计数（击杀/死亡只统计当天）
function TN:RollDaily()
  local today = tonumber(date("%Y%m%d"))
  if self.db.char.todayDate ~= today then
    self.db.char.todayDate = today
    self.db.char.killsToday = 0
    self.db.char.deathsToday = 0
  end
end

function TN:GetStats()
  local enemies = self:GetSortedEnemies()
  local active = 0
  for _, enemy in ipairs(enemies) do
    if (enemy.age or 0) <= self.activeTTL then active = active + 1 end
  end
  self:ScanFriendlies()
  local friendlyTotal = 0
  for _, count in pairs(self.friendlyClassCounts) do
    friendlyTotal = friendlyTotal + count
  end
  local enemyClassCounts = self:GetEnemyClassCounts()
  local enemyTotal = #enemies

  -- 死刑名单集合 + 胜负（持久化，优先用于胜率计算）
  local kosSet, kosWL = {}, {}
  local rows = self.GetDetailKOSData and self:GetDetailKOSData() or {}
  for _, row in ipairs(rows) do
    if row.name then
      kosSet[row.name] = true
      kosWL[row.name] = { win = row.win or 0, loss = row.loss or 0 }
    end
  end
  -- 死刑逃犯：附近敌人中在死刑名单里的人数（isKOS 标记由 GetSortedEnemies 统一设置）
  local high = 0
  for _, enemy in ipairs(enemies) do
    if kosSet[enemy.name] then
      high = high + 1
    end
  end

  self:RollDaily()
  local _, playerClass = UnitClass("player")
  playerClass = playerClass or "UNKNOWN"
  local guildWL = (self.db and self.db.char and self.db.char.guildWL) or {}
  local threat = self:CalcThreat(enemies, kosSet, kosWL, guildWL, playerClass, self.nearbyMates or 0, self.nearbyFriendlies or 0)

  return {
    detected = active,
    activeDetected = active,
    nearbyTotal = enemyTotal,
    high = high,
    highTotal = high,
    mates = friendlyTotal,
    kills = self.db.char.killsToday or 0,
    deaths = self.db.char.deathsToday or 0,
    killsTotal = self.db.char.kills or 0,
    deathsTotal = self.db.char.deaths or 0,
    threat = threat.score,
    threatBreakdown = threat.breakdown,
    nearbyMates = self.nearbyMates or 0,
    nearbyFriendlies = (self.GetNearbyFriendlies and #(self:GetNearbyFriendlies())) or 0,
    enemies = enemies,
    friendlyClassCounts = self.friendlyClassCounts,
    enemyClassCounts = enemyClassCounts,
    friendlyTotal = friendlyTotal,
    enemyTotal = enemyTotal,
  }
end
