--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/PlayerTracker.lua
-- 玩家追踪：敌方增删/裁剪/排序 + 友方记录 + 战斗日志解析

local TN = TaoNiao
local bit_band = bit and bit.band or bit32 and bit32.band

-- ── 私有辅助 ──
local function isHostilePlayer(flags)
  if not flags then return false end
  local hostile = bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40) > 0
  local player = bit_band(flags, COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) > 0
  return hostile and player
end

-- 敌对玩家或玩家控制单位（含猎人宝宝、术士宠物等）
local function isHostilePlayerOrPet(flags)
  if not flags then return false end
  local hostile = bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40) > 0
  local player = bit_band(flags, COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) > 0
  local pet = bit_band(flags, 0x1000) > 0  -- COMBATLOG_OBJECT_CONTROL_PLAYER
  return hostile and (player or pet)
end

local function normalizeName(name)
  if not name then return nil end
  return name:gsub(" %- ", "-")
end

local function getGuidPlayerInfo(guid)
  if not guid or not GetPlayerInfoByGUID then return nil, nil end
  local _, classFile, _, _, _, name = GetPlayerInfoByGUID(guid)
  return name, classFile
end

local function getSpyPlayerData(name)
  if not name or not SpyPerCharDB or not SpyPerCharDB.PlayerData then return nil end
  return SpyPerCharDB.PlayerData[name]
end

local function isStealthAura(spellId, spellName)
  if spellId == 1784 or spellId == 1856 or spellId == 1857 or spellId == 5215 or spellId == 20580 then
    return true
  end
  return spellName == "潜行" or spellName == "消失" or spellName == "影遁"
      or spellName == "Prowl" or spellName == "Stealth" or spellName == "Vanish" or spellName == "Shadowmeld"
end

local function isGroupMember(guid)
  if not guid then return false end
  local num = GetNumGroupMembers and GetNumGroupMembers() or 0
  if num == 0 then return false end
  if IsInRaid() then
    for i = 1, num do
      if UnitGUID("raid" .. i) == guid then return true end
    end
  else
    for i = 1, num do
      if UnitGUID("party" .. i) == guid then return true end
    end
  end
  return false
end

-- ── 战斗日志 ──
function TN:CombatLogEvent()
  if self.db.profile.enabled == false then return end
  local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellId, spellName = CombatLogGetCurrentEventInfo()
  if isHostilePlayer(sourceFlags) then
    local guidName, classFile = getGuidPlayerInfo(sourceGUID)
    self:TouchEnemy(sourceGUID, guidName or sourceName, nil, classFile, subevent)
  end
  if isHostilePlayer(destFlags) then
    local guidName, classFile = getGuidPlayerInfo(destGUID)
    self:TouchEnemy(destGUID, guidName or destName, nil, classFile, subevent)
  end
  -- 附近友方追踪（同 CounterPlus：战斗日志中所有友方玩家记录到友好列表）
  if bit_band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) > 0
     and bit_band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x10) > 0 then
    local _, classFile = getGuidPlayerInfo(destGUID)
    self:TrackFriendly(destGUID, destName, classFile)
  end
  -- 记录最后攻击者（敌对玩家及宠物，排除 NPC）
  if destGUID == self.playerGUID and sourceGUID and sourceName and isHostilePlayerOrPet(sourceFlags) then
    self._lastAttacker = sourceName
    self._lastAttackerGUID = sourceGUID
    self._lastAttackTime = GetTime()
  end
  if subevent == "SPELL_AURA_APPLIED" and isHostilePlayer(destFlags) and isStealthAura(spellId, spellName) then
    local enemy = self.enemies and self.enemies[destGUID]
    local now = GetTime()
    if enemy and ((now - (enemy.lastStealthToast or 0)) > 8) then
      enemy.lastStealthToast = now
      local isKOS = enemy.isKOS
      if not isKOS and self.GetDetailKOSData then
        for _, row in ipairs(self:GetDetailKOSData()) do
          if row.name == enemy.name then isKOS = true; break end
        end
      end
      local kind = isKOS and "rival" or "stealth"
      local classInfo = self.classInfo[enemy.classFile or "UNKNOWN"]
      local className = classInfo and classInfo.name or "未知"
      local lvText = (enemy.level and type(enemy.level) == "number") and (enemy.level .. "级 · ") or ""
      self:PushToast(kind, enemy.name, lvText .. className, spellName or "潜行", classInfo and classInfo.color)
      self:AnnounceStealth(enemy)
    end
  end
  if subevent == "PARTY_KILL" and sourceGUID == self.playerGUID and isHostilePlayer(destFlags) then
    self:RollDaily()
    self.db.char.kills = (self.db.char.kills or 0) + 1
    self.db.char.killsToday = (self.db.char.killsToday or 0) + 1
    self:RecordEnemyOutcome(destGUID, true, destName)
    -- 广播给队友
    local _, cf = getGuidPlayerInfo(destGUID)
    local ci = self.classInfo[cf or "UNKNOWN"] or self.classInfo.UNKNOWN
    self:BroadcastMateKill(self.playerName, destName, ci.name, nil, nil)
    -- 团队/小队聊天通报
    local ch = IsInRaid() and "RAID" or (IsInGroup() and "PARTY")
    if ch then
      SendChatMessage("[TaoNiao] 我击杀了 " .. (destName or "敌方") .. "-" .. ci.name, ch)
    end
  elseif subevent == "PARTY_KILL" and isHostilePlayer(destFlags) and sourceGUID ~= self.playerGUID then
    -- 队友击杀敌方
    if isGroupMember(sourceGUID) then
      local _, cf = getGuidPlayerInfo(destGUID)
      local ci = self.classInfo[cf or "UNKNOWN"] or self.classInfo.UNKNOWN
      self:PushToast("matekill", destName or "敌方", "", "被 " .. (sourceName or "队友") .. " 击杀", ci.color)
    end
  elseif subevent == "PARTY_KILL" and isHostilePlayer(sourceFlags) and destGUID ~= self.playerGUID then
    -- 队友被敌方击杀
    if isGroupMember(destGUID) then
      local sourceClassInfo = self.classInfo["UNKNOWN"]
      if sourceGUID then
        local _, cf = GetPlayerInfoByGUID(sourceGUID)
        sourceClassInfo = self.classInfo[cf or "UNKNOWN"] or sourceClassInfo
      end
      self:PushToast("matedeath", sourceName or "敌方", "", "击杀了 " .. (destName or "队友"), sourceClassInfo and sourceClassInfo.color)
    end
  end
  self:MarkDirty()
end

-- 玩家死亡处理（对齐 Spy：PLAYER_DEAD + 最后攻击者 0.5s 窗口）
function TN:OnPlayerDead()
  if self.db.profile.enabled == false then return end
  if self._lastAttacker and self._lastAttackTime then
    local diff = GetTime() - self._lastAttackTime
    if diff < 0.5 then
      self:RollDaily()
      self.db.char.deaths = (self.db.char.deaths or 0) + 1
      self.db.char.deathsToday = (self.db.char.deathsToday or 0) + 1
      self:RecordEnemyOutcome(self._lastAttackerGUID, false, self._lastAttacker)
      -- 广播给队友
      local _, cf = GetPlayerInfoByGUID(self._lastAttackerGUID)
      local ci = self.classInfo[cf or "UNKNOWN"] or self.classInfo.UNKNOWN
      self:BroadcastMateDeath(self.playerName, self._lastAttacker, ci.name)
      -- 团队/小队聊天通报
      local ch = IsInRaid() and "RAID" or (IsInGroup() and "PARTY")
      if ch then
        SendChatMessage("[TaoNiao] 我被 " .. (self._lastAttacker or "敌方") .. "-" .. ci.name .. " 击杀了", ch)
      end
    end
  end
  self._lastAttacker = nil
  self._lastAttackerGUID = nil
  self._lastAttackTime = nil
end

-- ── 单位扫描 ──
function TN:ScanUnit(unit, reason)
  if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end
  local classFile = select(2, UnitClass(unit)) or "UNKNOWN"
  local guid = UnitGUID(unit)
  local guild = GetGuildInfo(unit)
  self:TouchEnemy(guid, GetUnitName(unit, true) or UnitName(unit), UnitLevel(unit), classFile, reason or "UNIT_SCAN", guild, unit)
end

function TN:ScanTarget()
  if self.db.profile.enabled == false then return end
  self:ScanUnit("target", "TARGET")
  self:ScanFriendly("target")
  self:TryDetectLayer("target")
end

function TN:ScanMouseover()
  if self.db.profile.enabled == false then return end
  self:ScanUnit("mouseover", "MOUSEOVER")
  self:ScanFriendly("mouseover")
  self:TryDetectLayer("mouseover")
end

function TN:ScanNamePlate(_, unit)
  if self.db.profile.enabled == false then return end
  self:ScanUnit(unit, "NAME_PLATE")
  self:ScanFriendly(unit)
  self:TryDetectLayer(unit)
end

function TN:ScanFriendly(unit)
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
  if UnitCanAttack("player", unit) then return end
  local guid = UnitGUID(unit)
  if not guid or guid == self.playerGUID then return end
  local _, classFile = UnitClass(unit)
  self:TrackFriendly(guid, GetUnitName(unit, true) or UnitName(unit), classFile)
end

function TN:OnNamePlateRemoved(_, unit)
  if self.db.profile.enabled == false then return end
  if not unit then return end
  local guid = UnitGUID(unit)
  if not guid then return end
  local removed = false
  if self.enemies and self.enemies[guid] then
    local enemy = self.enemies[guid]
    if self.enemiesByName and enemy and enemy.name then
      self.enemiesByName[enemy.name] = nil
    end
    self.enemies[guid] = nil
    for i, g in ipairs(self.enemyOrder) do
      if g == guid then table.remove(self.enemyOrder, i); break end
    end
    removed = true
  end
  if self.friendlies and self.friendlies[guid] then
    self.friendlies[guid] = nil
    removed = true
  end
  if removed then self:MarkDirty() end
end

function TN:ScanVisibleUnits()
  if self.db.profile.enabled == false then return end
  self:ScanUnit("target", "VISIBLE_SCAN")
  self:ScanUnit("mouseover", "VISIBLE_SCAN")
  self:ScanUnit("focus", "VISIBLE_SCAN")
  self:ScanFriendly("target")
  self:ScanFriendly("mouseover")
  self:ScanFriendly("focus")
end

function TN:ScanFriendlies()
  if self.db.profile.enabled == false then return end
  wipe(self.friendlyClassCounts)
  self.nearbyMates = 0
  self.nearbyFriendlies = 0
  -- 只扫附近队友（party/raid 成员在附近），不扫散人
  local inRaid = IsInRaid and IsInRaid()
  local maxGroup = inRaid and 40 or 4
  for i = 1, maxGroup do
    local unit = inRaid and ("raid" .. i) or ("party" .. i)
    if not UnitIsUnit(unit, "player") and UnitExists(unit) and not UnitIsDeadOrGhost(unit) and CheckInteractDistance(unit, 4) then
      self.nearbyMates = self.nearbyMates + 1
    end
  end
end

-- ── 敌人增删 ──
function TN:TouchEnemy(guid, name, level, classFile, reason, guild, unit)
  if not guid or not name or guid == self.playerGUID then return end
  local canonicalName = normalizeName(name)
  if not canonicalName then return end
  local spyData = getSpyPlayerData(canonicalName)
  if spyData then
    classFile = classFile or spyData.class
    level = level or spyData.level
    guild = guild or spyData.guild
  end
  local now = GetTime()
  local enemy = self.enemies[guid]
  -- 去重：同名已存在敌人 → 合并（对齐 Spy 单一名规范式）
  if not enemy and self.enemiesByName then
    local existingGuid = self.enemiesByName[canonicalName]
    if existingGuid and self.enemies[existingGuid] then
      enemy = self.enemies[existingGuid]
      guid = existingGuid
    end
  end
  local isNew = not enemy
  if isNew then
    enemy = { guid = guid, name = canonicalName, firstSeen = now, events = 0 }
    self.enemies[guid] = enemy
    table.insert(self.enemyOrder, guid)
    if self.enemiesByName then self.enemiesByName[canonicalName] = guid end
  end
  -- 名变更时同步 enemiesByName（如先 "百媚生" 后 "百媚生-法琳娜"）
  if not isNew and enemy.name ~= canonicalName and self.enemiesByName then
    self.enemiesByName[enemy.name] = nil
    self.enemiesByName[canonicalName] = guid
  end
  enemy.name = canonicalName
  if guild and guild ~= "" then enemy.guild = guild end
  if unit and UnitExists(unit) and UnitGUID(unit) == guid then
    enemy.unit = unit
  end
  local lv = tonumber(level)
  -- 对齐 Spy：骷髅（UnitLevel=-1）时推测等级，优先保留已知真实等级
  if lv and lv > 0 then
    enemy.level = lv
    enemy.levelGuess = false
  elseif level == -1 then
    local myLv = UnitLevel("player") or 60
    local maxLevel = (MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]) or 60
    local guess = math.min(myLv + 10, maxLevel)
    if enemy.level and type(enemy.level) == "number" and enemy.level > 0 then
      enemy.levelGuess = false
    else
      enemy.level = guess
      enemy.levelGuess = true
    end
  end
  -- 职业：已知职业不被 UNKNOWN 覆盖
  if classFile and classFile ~= "UNKNOWN" then enemy.classFile = classFile end
  if not enemy.classFile then enemy.classFile = "UNKNOWN" end
  -- 补齐已记录的战斗日志信息
  self:UpdateBattleLogInfo(enemy.name, enemy.classFile, enemy.level, enemy.guild)
  -- 同步到对手统计（对齐 Spy：探测即录入，胜负默认 0）
  local mu = self.db.char.matchups or {}
  self.db.char.matchups = mu
  local key = enemy.name
  if not mu[key] then
    mu[key] = {
      cls = (self.classInfo[enemy.classFile] and self.classInfo[enemy.classFile].name) or enemy.classFile or "UNKNOWN",
      lv = enemy.level or "??",
      guild = enemy.guild or "",
      rank = "",
      win = 0, loss = 0,
      last = time and time() or 0,
      zone = GetZoneText and GetZoneText() or "未知区域",
    }
  else
    if enemy.level and type(enemy.level) == "number" then mu[key].lv = enemy.level end
    if enemy.guild and enemy.guild ~= "" then mu[key].guild = enemy.guild end
    if enemy.classFile and enemy.classFile ~= "UNKNOWN" then
      mu[key].cls = (self.classInfo[enemy.classFile] and self.classInfo[enemy.classFile].name) or enemy.classFile
    end
    mu[key].last = time and time() or 0
    mu[key].zone = GetZoneText and GetZoneText() or mu[key].zone
  end
  enemy.lastSeen = now
  enemy.lastEvent = reason
  if reason ~= "VISIBLE_SCAN" then
    enemy.events = (enemy.events or 0) + 1
  end
  if not enemy.myWins then enemy.myWins = 0 end
  if not enemy.myLosses then enemy.myLosses = 0 end
  -- 首次发现敌人：触发自动通报（具体玩家，对齐 Spy）
  if isNew then
    self:AnnounceEnemy(enemy)
    -- 必杀目标首次出现弹 toast（30s 冷却防刷屏）
    if not enemy._lastKosToast or now - enemy._lastKosToast > 30 then
      local isKOS = enemy.isKOS
      if not isKOS and self.GetDetailKOSData then
        for _, row in ipairs(self:GetDetailKOSData()) do
          if row.name == enemy.name then isKOS = true; break end
        end
      end
      if isKOS then
        enemy._lastKosToast = now
        local classInfo = self.classInfo[enemy.classFile or "UNKNOWN"]
        local className = classInfo and classInfo.name or "未知"
        local lvText = (enemy.level and type(enemy.level) == "number") and (enemy.level .. "级 · ") or ""
        self:PushToast("rival", enemy.name, lvText .. className, "必杀目标出现", classInfo and classInfo.color)
      end
    end
  end
  self:MarkDirty()
end

function TN:ClearEnemies()
  wipe(self.enemies)
  wipe(self.enemyOrder)
  if self.enemiesByName then wipe(self.enemiesByName) end
  self:MarkDirty()
end

function TN:PruneEnemies()
  local now = GetTime()
  for i = #self.enemyOrder, 1, -1 do
    local guid = self.enemyOrder[i]
    local enemy = self.enemies[guid]
    if not enemy or now - (enemy.lastSeen or 0) > self.enemyTTL then
      self.enemies[guid] = nil
      table.remove(self.enemyOrder, i)
      if self.enemiesByName and enemy and enemy.name then
        self.enemiesByName[enemy.name] = nil
      end
    end
  end
  self:MarkDirty()
end

-- ── 排序与统计 ──
function TN:IsHighRisk(enemy)
  local classFile = enemy.classFile
  local activeAge = GetTime() - (enemy.lastSeen or 0)
  return enemy.events >= 5 or activeAge < 8 or classFile == "ROGUE" or classFile == "MAGE" or classFile == "PRIEST"
end

function TN:GetSortedEnemies()
  local now = GetTime()
  -- 死刑名单集合（供排序置顶 + isKOS 标记）
  local kosSet = {}
  if self.GetDetailKOSData then
    for _, row in ipairs(self:GetDetailKOSData()) do
      if row.name then
        kosSet[row.name] = true
      end
    end
  end
  local list = {}
  for _, guid in ipairs(self.enemyOrder) do
    local enemy = self.enemies[guid]
    if enemy then
      enemy.age = now - (enemy.lastSeen or now)
      enemy.highRisk = self:IsHighRisk(enemy)
      if kosSet[enemy.name] then
        enemy.isKOS = true
      else
        enemy.isKOS = nil
      end
      table.insert(list, enemy)
    end
  end
  table.sort(list, function(a, b)
    -- 死刑名单置顶
    local aKOS = a.isKOS and 1 or 0
    local bKOS = b.isKOS and 1 or 0
    if aKOS ~= bKOS then return aKOS > bKOS end
    -- 活跃 vs 陈旧
    if (a.age > self.staleTTL) ~= (b.age > self.staleTTL) then return a.age < b.age end
    if a.highRisk ~= b.highRisk then return a.highRisk end
    if (a.events or 0) ~= (b.events or 0) then return (a.events or 0) > (b.events or 0) end
    return (a.lastSeen or 0) > (b.lastSeen or 0)
  end)
  return list
end

function TN:GetEnemyClassCounts()
  local counts = {}
  for _, guid in ipairs(self.enemyOrder) do
    local enemy = self.enemies[guid]
    if enemy then
      local classFile = enemy.classFile or "UNKNOWN"
      if classFile ~= "UNKNOWN" then
        counts[classFile] = (counts[classFile] or 0) + 1
      end
    end
  end
  return counts
end

function TN:GetSortedClassCounts(counts)
  local list = {}
  for classFile, count in pairs(counts or {}) do
    if count > 0 then
      local info = self.classInfo[classFile]
      if info and classFile ~= "UNKNOWN" then
        local orderIdx = 0
        for i, cls in ipairs(self.CLASS_ORDER) do
          if cls == classFile then orderIdx = i; break end
        end
        table.insert(list, { classFile = classFile, count = count, info = info, orderIdx = orderIdx })
      end
    end
  end
  table.sort(list, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.orderIdx < b.orderIdx
  end)
  return list
end

function TN:GetFriendlyClassCounts()
  local counts = {}
  local friendlies = self:GetNearbyFriendlies()
  for _, f in ipairs(friendlies) do
    local classFile = f.classFile or "UNKNOWN"
    if classFile ~= "UNKNOWN" then
      counts[classFile] = (counts[classFile] or 0) + 1
    end
  end
  return counts
end

-- 附近友方追踪（对齐 CounterPlus：战斗日志友方玩家记入列表，30 秒过期）
function TN:TrackFriendly(guid, name, classFile)
  if not guid or guid == self.playerGUID or not name then return end
  local now = GetTime()
  local f = self.friendlies[guid]
  if not f then
    self.friendlies[guid] = { name = name, classFile = classFile or "UNKNOWN", firstSeen = now, lastSeen = now, events = 1 }
  else
    f.lastSeen = now
    f.events = (f.events or 1) + 1
    if classFile and classFile ~= "UNKNOWN" then f.classFile = classFile end
    if name then f.name = name end
  end
  self:MarkDirty()
end

function TN:PruneFriendlies()
  local now = GetTime()
  for guid, f in pairs(self.friendlies) do
    if now - (f.lastSeen or 0) > 30 then
      self.friendlies[guid] = nil
    end
  end
end

function TN:GetNearbyFriendlies()
  local now = GetTime()
  local list = {}
  for guid, f in pairs(self.friendlies) do
    if now - (f.lastSeen or 0) <= 30 then
      local ci = self.classInfo[f.classFile or "UNKNOWN"] or self.classInfo.UNKNOWN
      list[#list + 1] = { name = f.name, classFile = f.classFile, class = ci.name, color = ci.color, age = now - f.lastSeen }
    end
  end
  table.sort(list, function(a, b) return a.age < b.age end)
  return list
end
