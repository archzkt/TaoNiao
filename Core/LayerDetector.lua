--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/LayerDetector.lua
-- 世界分层检测：解析 Creature GUID 第 5 段 zoneID 得到分层指纹，
-- 按已知 zoneID 升序排名得到位面号（Nova 同款做法）。副本内为 nil。

local TN = TaoNiao

-- 从指定单位的 GUID 解析分层 ID（仅 Creature/NPC 实时准确）
function TN:ParseUnitLayer(unit)
  local guid = UnitGUID(unit)
  if not guid or guid == "" then return nil end
  local unitType, _, _, _, zoneUID = strsplit("-", guid)
  if unitType ~= "Creature" then return nil end
  return tonumber(zoneUID)
end

-- 尝试检测并缓存分层（单位存在且为生物时更新）
function TN:TryDetectLayer(unit)
  if not unit or unit == "" then return end
  local zoneID = self:ParseUnitLayer(unit)
  if zoneID and zoneID > 0 then
    local ch = self.db and self.db.char
    if not ch then return end
    if not ch.layerSet then ch.layerSet = {} end
    if not ch.layerSet[zoneID] then
      ch.layerSet[zoneID] = true
    end
    if self.currentZoneID ~= zoneID then
      self.currentZoneID = zoneID
      self.currentLayer = self:ComputeLayerRank(zoneID)
      if self.UpdateLocation then self:UpdateLocation() end
      if self.AfterLayerChange then self:AfterLayerChange() end
    end
  end
end

-- 计算 zoneID 在已知集合中的升序排名（永远输出 1/2/3/4…）
function TN:ComputeLayerRank(zoneID)
  local ch = self.db and self.db.char
  if not ch or not ch.layerSet then return nil end
  local sorted = {}
  for id in pairs(ch.layerSet) do table.insert(sorted, id) end
  table.sort(sorted)
  for i, id in ipairs(sorted) do
    if id == zoneID then return i end
  end
  return nil
end

-- 清空分层缓存（区域/队伍变更后需重新检测当前位面，但保留指纹集合）
function TN:ClearLayer()
  self.currentLayer = nil
  self.currentZoneID = nil
  -- 重新从 Nova 同步最新 zoneID 集合
  if self.SyncFromNovaDB then self:SyncFromNovaDB() end
end

-- 获取当前位面序号：Nova 安装时直接用其全局变量，否则用本地（同步自 Nova/TaoNiao 频道）
function TN:GetCurrentLayer()
  local _, instType = GetInstanceInfo()
  if instType ~= "none" then
    return nil, "副本内不存在野外分层"
  end
  -- Nova 安装：NWB_CurrentLayer 是全局变量，与 Nova 显示完全一致
  if NWB_CurrentLayer then
    return NWB_CurrentLayer > 0 and NWB_CurrentLayer or nil
  end
  -- 无 Nova：至少 2 个 zoneID 才输出层号，避免单点误判
  local ch = self.db and self.db.char
  if ch and ch.layerSet then
    local count = 0; for _ in pairs(ch.layerSet) do count = count + 1 end
    if count < 2 then return nil end
  end
  return self.currentLayer
end
