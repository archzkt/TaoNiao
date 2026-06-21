--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- Core/TeamComm.lua
-- 队友击杀/阵亡同步：通过 AddonMessage 在队/团内广播击杀事件

local TN = TaoNiao
local PREFIX = "TNK"
local VERSION = "1"

function TN:EnableTeamComm()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  elseif RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(PREFIX)
  end
  self:RegisterEvent("CHAT_MSG_ADDON", "OnTeamCommReceived")
end

-- 广播队友击杀
function TN:BroadcastMateKill(sourceName, destName, destClass, destGuild, destLevel)
  if not IsInGroup() then return end
  local msg = table.concat({ VERSION, "KILL", sourceName, destName, destClass or "", destGuild or "", destLevel or "" }, "|")
  self:SendTeamComm(msg)
end

-- 广播队友阵亡
function TN:BroadcastMateDeath(playerName, sourceName, sourceClass)
  if not IsInGroup() then return end
  local msg = table.concat({ VERSION, "DEATH", playerName, sourceName, sourceClass or "" }, "|")
  self:SendTeamComm(msg)
end

function TN:SendTeamComm(msg)
  local dist = IsInRaid() and "RAID" or "PARTY"
  SendAddonMessage(PREFIX, msg, dist)
end

function TN:OnTeamCommReceived(_, prefix, message, dist, sender)
  if prefix ~= PREFIX or not message or sender == self.playerName then return end
  local parts = {}
  for part in message:gmatch("([^|]+)") do parts[#parts + 1] = part end
  local ver = parts[1]
  if ver ~= VERSION then return end
  local kind = parts[2]
  if kind == "KILL" then
    local sourceName = parts[3]
    local destName = parts[4]
    local destClass = parts[5] or ""
    local destGuild = parts[6] or ""
    local classFile = self.CLASS_FILE_BY_NAME[destClass] or "UNKNOWN"
    local ci = self.classInfo[classFile] or self.classInfo.UNKNOWN
    self:PushToast("matekill", destName or "敌方", "", "被 " .. (sourceName or "队友") .. " 击杀", ci.color)
  elseif kind == "DEATH" then
    local playerName = parts[3]
    local sourceName = parts[4]
    local sourceClass = parts[5] or ""
    local classFile = self.CLASS_FILE_BY_NAME[sourceClass] or "UNKNOWN"
    local ci = self.classInfo[classFile] or self.classInfo.UNKNOWN
    self:PushToast("matedeath", sourceName or "敌方", "", "击杀了 " .. (playerName or "队友"), ci.color)
  end
end
