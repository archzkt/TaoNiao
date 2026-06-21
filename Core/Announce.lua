--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/Announce.lua
-- 通报：查找本地防务通道 + 发送结构化通报（敌方数量/职业分布/友方人数）。

local TN = TaoNiao

function TN:SendToChannel(msg, channel)
  if channel == "CHANNEL" then
    local def = self:GetLocalDefenseChannel()
    if not def then return end
    SendChatMessage(msg, "CHANNEL", nil, def.id)
  else
    SendChatMessage(msg, channel)
  end
end

-- 快速通报：统一模板，含敌方+友方信息
function TN:QuickAnnounce(channel)
  local stats = self:GetStats()
  local enemyN = stats.enemyTotal or 0
  local friendlyN = stats.nearbyFriendlies or 0
  if enemyN == 0 and friendlyN == 0 then
    self:Print("附近没有发现敌方和友方")
    return
  end

  local zone = GetZoneText() or "未知区域"
  local subZone = GetSubZoneText() or ""
  local loc = zone
  if subZone ~= "" and subZone ~= zone then loc = zone .. "-" .. subZone end
  local coord = self:GetPlayerCoord()
  local coordStr = coord and (" <" .. coord .. ">") or ""

  -- 敌方
  local enemyPart
  if enemyN > 0 then
    local distParts = {}
    for _, item in ipairs(self:GetSortedClassCounts(stats.enemyClassCounts)) do
      table.insert(distParts, item.count .. item.info.text)
    end
    local dist = table.concat(distParts, "，")
    local names = {}
    for _, e in ipairs(stats.enemies) do
      names[#names + 1] = (e.name or "?")
    end
    local nameStr = "，包括<" .. table.concat(names, ",") .. ">"
    enemyPart = "发现敌方" .. enemyN .. "人(" .. dist .. ")" .. nameStr
  else
    enemyPart = "没有发现敌方"
  end

  -- 友方
  local friendlyPart
  if friendlyN > 0 then
    local fCounts = self:GetFriendlyClassCounts()
    local distParts = {}
    for _, item in ipairs(self:GetSortedClassCounts(fCounts)) do
      table.insert(distParts, item.count .. item.info.text)
    end
    local dist = table.concat(distParts, "，")
    friendlyPart = "，友方" .. friendlyN .. "人"
    if dist ~= "" then friendlyPart = friendlyPart .. "(" .. dist .. ")" end
  else
    if enemyN > 0 then
      friendlyPart = "，没有友方，孤立无援"
    end
  end

  local msg = ("[TaoNiao] 势力通报：%s%s %s%s"):format(loc, coordStr, enemyPart, friendlyPart or "")
  self:SendToChannel(msg, channel)
end

-- 通报具体玩家到指定频道（不检查 autoAnnounce）
function TN:AnnounceEnemyTo(enemy, channel)
  if not enemy or not channel then return end
  local name = enemy.name or ""
  if name == "" then return end
  local classFile = enemy.classFile or "UNKNOWN"
  local ci = self.classInfo and self.classInfo[classFile]
  local classText = ci and ci.name or classFile
  local msg = "[TaoNiao] 发现附近敌人：" .. name
  if enemy.guild and enemy.guild ~= "" then
    msg = msg .. "<" .. enemy.guild .. ">"
  end
  msg = msg .. "-" .. tostring(enemy.level or "??") .. "级" .. classText
  local zone = GetZoneText() or "未知区域"
  local subZone = GetSubZoneText() or ""
  local loc = zone
  if subZone ~= "" and subZone ~= zone then loc = zone .. "-" .. subZone end
  msg = msg .. "，位置：" .. loc
  local coord = self:GetPlayerCoord()
  if coord then msg = msg .. " <" .. coord .. ">" end
  self:SendToChannel(msg, channel)
end

-- 通报见之必杀玩家（手动右键菜单触发）
function TN:AnnounceKOSEnemy(enemy, channel)
  if not enemy or not channel then return end
  local name = enemy.name or ""
  if name == "" then return end
  local classFile = enemy.classFile or "UNKNOWN"
  local ci = self.classInfo and self.classInfo[classFile]
  local classText = ci and ci.name or classFile
  local msg = "[TaoNiao] 发现必杀目标：" .. name
  if enemy.guild and enemy.guild ~= "" then
    msg = msg .. "<" .. enemy.guild .. ">"
  end
  msg = msg .. "-" .. tostring(enemy.level or "??") .. "级" .. classText .. "，这人我见之必杀"
  local zone = GetZoneText() or "未知区域"
  local subZone = GetSubZoneText() or ""
  local loc = zone
  if subZone ~= "" and subZone ~= zone then loc = zone .. "-" .. subZone end
  msg = msg .. "，位置：" .. loc
  local coord = self:GetPlayerCoord()
  if coord then msg = msg .. " <" .. coord .. ">" end
  self:SendToChannel(msg, channel)
end

function TN:ToggleAutoAnnounce()
  local p = self.db and self.db.profile
  if not p then return end
  p.autoAnnounce = (p.autoAnnounce == false) and true or false
  if p.autoAnnounce ~= false then
    local ch = p.autoAnnounceChannel or "AUTO"
    local chNames = { AUTO = "智能", PARTY = "小队", RAID = "团队", GUILD = "公会" }
    if UIErrorsFrame then
      UIErrorsFrame:AddMessage("|cff34c6e8自动通报已开启（" .. (chNames[ch] or ch) .. "）|r", 1, 0.3, 0.3, 1, 3)
    end
  else
    if UIErrorsFrame then
      UIErrorsFrame:AddMessage("|cffff4d4f自动通报已关闭|r", 1, 0.3, 0.3, 1, 3)
    end
  end
  if self.RenderDetailSettingsRefresh then self:RenderDetailSettingsRefresh() end
end

-- 获取玩家当前坐标字符串（"x,y"，如 "42,67"），无 API 时返回 nil
function TN:GetPlayerCoord()
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
      local pos = C_Map.GetPlayerMapPosition(mapID, "player")
      if pos then
        local x, y = pos:GetXY()
        return string.format("%.0f,%.0f", x * 100, y * 100)
      end
    end
  end
  return nil
end

-- 查找本地防务（LocalDefense）通道，返回 { id, name } 或 nil
function TN:GetLocalDefenseChannel()
  if not GetChannelList then return nil end
  for i = 1, 20 do
    local id, name = GetChannelName(i)
    if id and name and name ~= "" then
      if name:find("防务") or name:find("Defense") or name:find("防卫") then
        return { id = id, name = name }
      end
    end
  end
  return nil
end

-- 发送结构化通报到指定频道
function TN:AnnounceTo(channel, channelId)
  local stats = self:GetStats()
  local zone = GetZoneText() or "未知区域"
  local subZone = GetSubZoneText() or ""
  local loc = zone
  if subZone ~= "" and subZone ~= zone then loc = zone .. "-" .. subZone end
  local enemyN = stats.enemyTotal or 0

  -- 职业分布：3贼，1牧
  local distParts = {}
  for _, item in ipairs(self:GetSortedClassCounts(stats.enemyClassCounts)) do
    table.insert(distParts, item.count .. item.info.text)
  end
  local dist = table.concat(distParts, "，")

  local coord = self:GetPlayerCoord()
  local coordStr = coord and ("<" .. coord .. ">") or ""
  local msg
  if enemyN > 0 and dist ~= "" then
    msg = string.format("[TaoNiao] 敌情通报：我在 %s %s 发现敌方%d人(%s)", loc, coordStr, enemyN, dist)
  else
    msg = string.format("[TaoNiao] 敌情通报：我在 %s %s 发现敌方%d人", loc, coordStr, enemyN)
  end

  -- 通道可用性校验
  if channel == "PARTY" and not IsInGroup() then
    self:Print("不在小队中，无法发送。"); return
  elseif channel == "RAID" and not IsInRaid() then
    self:Print("不在团队中，无法发送。"); return
  elseif channel == "GUILD" and not IsInGuild() then
    self:Print("不在公会中，无法发送。"); return
  elseif channel == "CHANNEL" then
    if not channelId then
      self:Print("未加入本地防务频道，无法发送。"); return
    end
    SendChatMessage(msg, "CHANNEL", nil, channelId); return
  end

  SendChatMessage(msg, channel)
end

-- 自动通报具体敌人（对齐 Spy AnnouncePlayer）：发现/KOS + 名字 + 公会 + 等级职业 + 区域
-- 触发于首次发现某敌人；智能选频道（团队→RAID，否则小队→PARTY）
function TN:AnnounceEnemy(enemy)
  if not enemy then return end
  local p = self.db and self.db.profile
  if not p or p.autoAnnounce == false then return end
  -- 乘坐飞行路线时关闭通报（对齐 Spy StopAlertsOnTaxi）
  if p.stopAlertsOnTaxi ~= false and UnitOnTaxi and UnitOnTaxi("player") then return end
  -- 自动通报频道选择
  local ch = p.autoAnnounceChannel or "AUTO"
  if ch == "AUTO" then
    if IsInRaid and IsInRaid() then ch = "RAID"
    elseif IsInGroup and IsInGroup() then ch = "PARTY"
    else return end
  elseif ch == "PARTY" and not (IsInGroup and IsInGroup()) then return
  elseif ch == "RAID" and not (IsInRaid and IsInRaid()) then return
  elseif ch == "GUILD" and not (IsInGuild and IsInGuild()) then return
  end
  local name = enemy.name or ""
  if name == "" then return end
  -- KOS 判定
  local isKOS = false
  if self.GetDetailKOSData then
    for _, row in ipairs(self:GetDetailKOSData()) do
      if row.name == name or row.name == enemy.name then isKOS = true; break end
    end
  end
  -- OnlyAnnounceKoS：仅 KOS 时通报
  if p.onlyAnnounceKoS and not isKOS then return end
  local classFile = enemy.classFile or "UNKNOWN"
  local ci = self.classInfo and self.classInfo[classFile]
  local classText = ci and ci.name or classFile
  -- 消息：[TaoNiao] 发现必杀目标：名字<公会>-等级 职业，这人我见之必杀，位置：区域 <坐标>
  local msg = (isKOS and "[TaoNiao] 发现必杀目标：" or "[TaoNiao] 发现附近敌人：") .. name
  if enemy.guild and enemy.guild ~= "" then
    msg = msg .. "<" .. enemy.guild .. ">"
  end
  msg = msg .. "-" .. tostring(enemy.level or "??") .. "级" .. classText
  if isKOS then msg = msg .. "，这人我见之必杀" end
  local zone = GetZoneText() or "未知区域"
  local subZone = GetSubZoneText() or ""
  local loc = zone
  if subZone ~= "" and subZone ~= zone then loc = zone .. "-" .. subZone end
  msg = msg .. "，位置：" .. loc
  local coord = self:GetPlayerCoord()
  if coord then msg = msg .. " <" .. coord .. ">" end
  SendChatMessage(msg, ch)
end

-- 潜行警告通报（对齐 EnemyTracker 的潜行检测）
function TN:AnnounceStealth(enemy)
  if not enemy then return end
  local p = self.db and self.db.profile
  if not p or p.autoAnnounce == false then return end
  if p.stopAlertsOnTaxi ~= false and UnitOnTaxi and UnitOnTaxi("player") then return end
  local ch = p.autoAnnounceChannel or "AUTO"
  if ch == "AUTO" then
    if IsInRaid and IsInRaid() then ch = "RAID"
    elseif IsInGroup and IsInGroup() then ch = "PARTY"
    else return end
  elseif ch == "PARTY" and not (IsInGroup and IsInGroup()) then return
  elseif ch == "RAID" and not (IsInRaid and IsInRaid()) then return
  elseif ch == "GUILD" and not (IsInGuild and IsInGuild()) then return
  end
  local name = enemy.name or ""
  if name == "" then return end
  local coord = self:GetPlayerCoord()
  local msg = "[TaoNiao] 警告：附近有潜行敌人，" .. name
  if coord then msg = msg .. " <" .. coord .. ">" end
  SendChatMessage(msg, ch)
end
