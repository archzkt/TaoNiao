--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/Outcomes.lua
-- 记录我对某敌人的胜负：per-enemy 会话内计数 + KOS 行持久化 + 公会胜负持久化。

local TN = TaoNiao

function TN:RecordEnemyOutcome(guid, won, combatLogName)
  local enemy = guid and self.enemies[guid]
  local name, classFile, guild, level
  if enemy then
    if won then enemy.myWins = (enemy.myWins or 0) + 1
    else enemy.myLosses = (enemy.myLosses or 0) + 1 end
    name = enemy.name
    classFile = enemy.classFile or "UNKNOWN"
    guild = enemy.guild
    level = enemy.level or "??"
  else
    -- 对齐 Spy：用战斗日志名字直接记录（敌人可能已被裁剪）
    name = combatLogName
    if not name and guid and GetPlayerInfoByGUID then
      name = select(6, GetPlayerInfoByGUID(guid))
    end
    if guid and GetPlayerInfoByGUID then
      _, classFile = GetPlayerInfoByGUID(guid)
    end
    classFile = classFile or "UNKNOWN"
    level = "??"
  end
  if not name or name == "" then return end
  local ch = self.db and self.db.char
  -- KOS 自身不存储胜负，展示时从 matchups 动态取
  if name and self.GetDetailKOSData then
    local shortName = name:match("^([^%-]+)")
    for _, row in ipairs(self:GetDetailKOSData()) do
      if row.name == name or (shortName and row.name == shortName) then
        row.last = time and time() or 0
        break
      end
    end
  end
  -- 公会胜负持久化
  local g = guild
  if g and g ~= "" and ch and ch.guildWL then
    local gw = ch.guildWL[g] or { win = 0, loss = 0 }
    if won then gw.win = (gw.win or 0) + 1 else gw.loss = (gw.loss or 0) + 1 end
    ch.guildWL[g] = gw
  end
  -- 战斗明细持久化（最新插到最前，上限 500 条）
  if ch and ch.battleLog then
    table.insert(ch.battleLog, 1, {
      result = won and "胜" or "负",
      name = name,
      cls = (self.classInfo[classFile] and self.classInfo[classFile].name) or classFile,
      lv = level or "??",
      guild = guild or "",
      zone = (GetZoneText and GetZoneText()) or "未知区域",
      ts = time and time() or 0,
    })
    while #ch.battleLog > 500 do table.remove(ch.battleLog) end
  end
  -- 历史对手统计（per-敌人胜负，按名字索引）
  if ch and ch.matchups and name then
    local rank = ""
    if enemy and enemy.unit and UnitExists(enemy.unit) then
      local rankNum = UnitPVPRank(enemy.unit)
      if rankNum and rankNum > 0 and GetPVPRankInfo then
        rank = GetPVPRankInfo(rankNum) or ""
      end
    end
    local m = ch.matchups[name] or { cls = (self.classInfo[classFile] and self.classInfo[classFile].name) or classFile, lv = level or "??", guild = guild or "", rank = rank, win = 0, loss = 0, last = 0, zone = (GetZoneText and GetZoneText()) or "未知区域" }
    if won then m.win = m.win + 1 else m.loss = m.loss + 1 end
    if rank ~= "" then m.rank = rank end
    m.last = time and time() or 0
    m.zone = (GetZoneText and GetZoneText()) or "未知区域"
    ch.matchups[name] = m
  end
end

-- 补齐战斗记录和对手统计中的敌人信息（TouchEnemy 获取到新信息时调用）
function TN:UpdateBattleLogInfo(name, classFile, level, guild)
  if not name or name == "" then return end
  local ch = self.db and self.db.char
  if not ch then return end
  if ch.battleLog then
    for _, entry in ipairs(ch.battleLog) do
      if entry.name == name then
        if classFile and classFile ~= "UNKNOWN" and self.classInfo then
          local ci = self.classInfo[classFile]
          if ci and entry.cls == ci.name then break end -- 已补齐
          if ci then entry.cls = ci.name end
        end
        if level and level ~= "??" and entry.lv == "??" then entry.lv = level end
        if guild and guild ~= "" and entry.guild == "" then entry.guild = guild end
        break
      end
    end
  end
  if ch.matchups then
    local m = ch.matchups[name]
    if m then
      if classFile and classFile ~= "UNKNOWN" and self.classInfo then
        local ci = self.classInfo[classFile]
        if ci then m.cls = ci.name end
      end
      if level and level ~= "??" then m.lv = level end
      if guild and guild ~= "" then m.guild = guild end
    end
  end
end
