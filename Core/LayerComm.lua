--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/LayerComm.lua
-- 位面检测与同步
--   有 Nova → 读 SavedVariable NWBdatabase + 层号 = NWB_CurrentLayer
--   无 Nova → 自身 GUID 扫描 + 解析 Nova 的 data/l 消息

local TN = TaoNiao
local NWB_PREFIX = "NWB"
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")

function TN:EnableLayerComm()
  self:SyncFromNovaDB()
end

function TN:SyncFromNovaDB()
  -- Nova 装 → 读 SavedVariable；没装 → 监听频道消息（仅注册一次）
  if not NovaWorldBuffs then
    if not self._layerCommRegistered then
      if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(NWB_PREFIX)
      elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(NWB_PREFIX)
      end
      self:RegisterEvent("CHAT_MSG_ADDON", "OnLayerCommReceived")
      self._layerCommRegistered = true
    end
  end
  local layers = nil
  if NWBdatabase and NWBdatabase.global then
    local realm = GetRealmName()
    if realm and NWBdatabase.global[realm] then
      for _, fdb in pairs(NWBdatabase.global[realm]) do
        if type(fdb) == "table" and fdb.layers then
          layers = fdb.layers
          break
        end
      end
    end
  end
  if not layers then return end
  local ch = self.db and self.db.char
  if not ch then return end
  if not ch.layerSet then ch.layerSet = {} end
  for zoneID in pairs(layers) do
    local id = tonumber(zoneID)
    if id and id > 0 and not ch.layerSet[id] then
      ch.layerSet[id] = true
    end
  end
  self:RefreshCurrentLayer()
end

function TN:OnLayerCommReceived(event, prefix, message, distribution, sender)
  if sender == self.playerName then return end
  if prefix ~= NWB_PREFIX or not message then return end
  local cmd, rest = message:match("^(%S+)%s+(.*)$")
  if not cmd then return end
  if cmd == "l" and rest then
    local afterVersion = rest:match("^[%d%.%-]+ (%S+)")
    if afterVersion then
      local zoneID = afterVersion:match("^(%d+)")
      if zoneID then self:AddLayerZoneID(tonumber(zoneID)) end
    end
  elseif cmd == "data" and rest and LibDeflate and LibSerialize then
    self:ParseNovaDataMessage(rest)
  end
end

function TN:ParseNovaDataMessage(data)
  if not LibDeflate or not LibSerialize then return end
  local decoded = LibDeflate:DecodeForWoWAddonChannel(data)
  if not decoded then return end
  local decompressed = LibDeflate:DecompressDeflate(decoded)
  if not decompressed then return end
  local ok, deserialized = pcall(LibSerialize.Deserialize, decompressed)
  if not ok or not deserialized then return end
  if deserialized.layers then
    for zoneID in pairs(deserialized.layers) do
      local id = tonumber(zoneID)
      if id and id > 0 then self:AddLayerZoneID(id) end
    end
  end
end

function TN:AddLayerZoneID(zoneID)
  if not zoneID or zoneID <= 0 then return end
  local ch = self.db and self.db.char
  if not ch then return end
  if not ch.layerSet then ch.layerSet = {} end
  if not ch.layerSet[zoneID] then
    ch.layerSet[zoneID] = true
    self:RefreshCurrentLayer()
  end
end

function TN:RefreshCurrentLayer()
  if self.currentZoneID then
    self.currentLayer = self:ComputeLayerRank(self.currentZoneID)
    if self.UpdateLocation then self:UpdateLocation() end
  end
end

function TN:AfterLayerChange()
  self:SyncFromNovaDB()
end
