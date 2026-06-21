--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/Team.lua
-- 团队逻辑：快捷操作注册表与执行、权限批量操作、队伍保存/解散/恢复、自动化事件。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao

-- HUD 团队按钮可用的快捷操作注册表
-- kind: "action"（一次性）/ "toggle"（切换 teamDB[key]）
TN.TEAM_QUICK_ACTIONS = {
  save    = { id = "save",    label = "保存队伍", icon = "details",   kind = "action",  available = function() return IsInGroup() end,  reason = "需要先加入队伍" },
  disband = { id = "disband", label = "解散队伍", icon = "skull",      kind = "action",  available = function() return IsInGroup() end,  reason = "需要先加入队伍" },
  restore = { id = "restore", label = "恢复队伍", icon = "portal",    kind = "action",  available = function() return #((TN.db and TN.db.profile and TN.db.profile.team and TN.db.profile.team.savedMembers) or {}) > 0 end, reason = "没有保存的成员" },
  promoteAll = { id = "promoteAll", label = "全团给A", icon = "crosshair", kind = "action", available = function() return IsInRaid() end, reason = "仅团队模式可用" },
  demoteAll  = { id = "demoteAll",  label = "全团收A", icon = "skull",     kind = "action", available = function() return IsInRaid() end, reason = "仅团队模式可用" },
  autoInvite   = { id = "autoInvite",   label = "自动邀请", icon = "megaphone", kind = "toggle", toggleKey = "autoInvite" },
  convertRaid  = { id = "convertRaid",  label = "自动转团", icon = "users",     kind = "toggle", toggleKey = "autoConvertRaid" },
  promote      = { id = "promote",      label = "自动给A", icon = "crosshair", kind = "toggle", toggleKey = "autoPromote" },
  freeLoot     = { id = "freeLoot",     label = "自由拾取", icon = "details",   kind = "toggle", toggleKey = "autoFreeLoot" },
}

-- 执行某个快捷操作
function TN:RunTeamQuickAction(id)
  local def = TN.TEAM_QUICK_ACTIONS[id]
  if not def then return end
  if def.kind == "toggle" then
    local teamDB = self.db.profile.team
    teamDB[def.toggleKey] = not teamDB[def.toggleKey]
    self:TeamToggleChanged(def.toggleKey, teamDB[def.toggleKey])
    return
  end
  if def.available and not def.available() then
    self:Print(def.reason or "当前不可用")
    return
  end
  if id == "save" then self:TeamSaveMembers()
  elseif id == "disband" then self:TeamDisband()
  elseif id == "restore" then self:TeamRestoreMembers()
  elseif id == "promoteAll" then self:TeamPromoteAll()
  elseif id == "demoteAll" then self:TeamDemoteAll() end
end

function TN:TeamToggleChanged(key, value)
  -- 清缓存，确保团队助手页面下次渲染时同步最新状态
  if self.detail and self.detail.teamFrame then
    self.detail.teamFrame.frame = nil
  end
  -- 如果详情页当前正显示团队助手，立即刷新
  if self.detailView == "team" then
    self:RenderDetailTeam()
  end
  if key == "autoInvite" then
    if value then
      self:Print("密语自动邀请 已开启，关键词: " .. (self.db.profile.team.inviteKeyword or "加 1 进组"))
    else
      self:Print("密语自动邀请 已关闭")
    end
  elseif key == "autoConvertRaid" then
    self:Print(value and "队满自动转团 已开启" or "队满自动转团 已关闭")
  elseif key == "autoPromote" then
    self:Print(value and "新进队自动给A 已开启" or "新进队自动给A 已关闭")
  elseif key == "autoFreeLoot" then
    self:Print(value and "自动自由拾取 已开启" or "自动自由拾取 已关闭")
    if value and IsInGroup() then
      SetLootMethod("free")
    end
  end
end

function TN:TeamPromoteAll()
  local count = 0
  for i = 1, GetNumGroupMembers() do
    local name, rank = GetRaidRosterInfo(i)
    if name and rank == 0 then
      PromoteToAssistant(name)
      count = count + 1
    end
  end
  self:Print("已提升 " .. count .. " 名成员为助理")
end

function TN:TeamDemoteAll()
  local count = 0
  for i = 1, GetNumGroupMembers() do
    local name, rank = GetRaidRosterInfo(i)
    if name and rank == 1 then
      DemoteAssistant(name)
      count = count + 1
    end
  end
  self:Print("已收回 " .. count .. " 名助理权限")
end

function TN:TeamSaveMembers()
  local teamDB = self.db and self.db.profile and self.db.profile.team
  if not teamDB then return end
  local saved = teamDB.savedMembers or {}
  if #saved > 0 then
    StaticPopupDialogs["TAONIAO_CONFIRM_OVERWRITE"] = {
      text = "已有保存的 " .. #saved .. " 名队友，是否覆盖？",
      button1 = "覆盖",
      button2 = "取消",
      OnAccept = function() TN:DoSaveMembers() end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("TAONIAO_CONFIRM_OVERWRITE")
    return
  end
  self:DoSaveMembers()
end

function TN:DoSaveMembers()
  local teamDB = self.db and self.db.profile and self.db.profile.team
  if not teamDB then return end
  local members = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local name = GetRaidRosterInfo(i)
      if name and name ~= UnitName("player") then
        members[#members + 1] = name
      end
    end
  elseif IsInGroup() then
    for i = 1, GetNumGroupMembers() - 1 do
      local name = UnitName("party" .. i)
      if name then members[#members + 1] = name end
    end
  end
  teamDB.savedMembers = members
  teamDB.savedAt = time and time() or nil
  self:Print("已保存 " .. #members .. " 名队友")
  -- 刷新团队助手页（清除缓存后重新渲染，避免 clearDetailMain 后 Show 不恢复）
  if self.detail and self.detail.teamFrame then
    self.detail.teamFrame.frame = nil
  end
  self:RenderDetailTeam()
end

function TN:TeamRestoreMembers()
  local teamDB = self.db and self.db.profile and self.db.profile.team
  if not teamDB then return end
  local members = teamDB.savedMembers or {}
  if #members == 0 then
    if UIErrorsFrame then
      UIErrorsFrame:AddMessage("|cffff4d4f没有保存的队伍成员|r", 1, 0.3, 0.3, 1, 3)
    end
    self:Print("|cffff4d4f没有保存的队伍成员，无法恢复。|r")
    return
  end
  -- 过期判定
  local expireMin = teamDB.restoreExpire or 30
  if expireMin > 0 and teamDB.savedAt and time then
    local elapsed = time() - teamDB.savedAt
    if elapsed > expireMin * 60 then
      local mins = math.floor(elapsed / 60)
      if UIErrorsFrame then
        UIErrorsFrame:AddMessage("|cffff4d4f保存的队伍已过期（" .. mins .. " 分钟前）|r", 1, 0.3, 0.3, 1, 4)
      end
      self:Print("|cffff4d4f保存的队伍已过期（" .. mins .. " 分钟前），已自动清除记忆。|r")
      teamDB.savedMembers = {}
      teamDB.savedAt = nil
      if self.detail and self.detail.teamFrame then
        self.detail.teamFrame.frame = nil
      end
      self:RenderDetailTeam()
      return
    end
  end
  local invited = 0
  for _, name in ipairs(members) do
    InviteUnit(name)
    invited = invited + 1
  end
  self:Print("正在邀请 " .. invited .. " 名记忆队友")
end

function TN:TeamClearSaved()
  local teamDB = self.db and self.db.profile and self.db.profile.team
  if not teamDB then return end
  local members = teamDB.savedMembers or {}
  if #members == 0 then
    self:Print("|cffff4d4f没有保存的队伍成员。|r")
    return
  end
  StaticPopupDialogs["TAONIAO_CONFIRM_CLEAR_TEAM"] = {
    text = "|cffff4d4f确定要清除 " .. #members .. " 名记忆队友吗？|r|n此操作不可撤销。",
    button1 = "清除",
    button2 = "取消",
    OnAccept = function()
      local tDB = TN.db and TN.db.profile and TN.db.profile.team
      if tDB then
        tDB.savedMembers = {}
        tDB.savedAt = nil
      end
      if TN.detail and TN.detail.teamFrame then
        TN.detail.teamFrame.frame = nil
      end
      TN:RenderDetailTeam()
      TN:Print("|cffff4d4f已清除所有记忆队友。|r")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("TAONIAO_CONFIRM_CLEAR_TEAM")
end

function TN:TeamDisband()
  if not IsInGroup() then return end
  local teamDB = self.db and self.db.profile and self.db.profile.team
  -- 检查是否已保存队伍
  local saved = teamDB and (teamDB.savedMembers or {})
  if #saved == 0 then
    StaticPopupDialogs["TAONIAO_CONFIRM_DISBAND_NOSAVE"] = {
      text = "|cffff4d4f尚未保存当前队伍成员！|r|n解散后将无法快速恢复，是否继续？",
      button1 = "继续解散",
      button2 = "取消",
      OnAccept = function() TN:DoDisband() end,
      timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("TAONIAO_CONFIRM_DISBAND_NOSAVE")
    return
  end
  -- 权限检查：团队需要队长，小队需要队长
  local inRaid = IsInRaid()
  local isLeader = inRaid and (UnitIsGroupLeader("player") or IsRaidLeader())
    or (not inRaid and UnitIsGroupLeader("player"))
  if not isLeader then
    if UIErrorsFrame then
      UIErrorsFrame:AddMessage("|cffff4d4f你不是队长，无法解散队伍|r", 1, 0.3, 0.3, 1, 3)
    end
    self:Print("|cffff4d4f你不是队长，无法解散队伍。|r")
    return
  end
  StaticPopupDialogs["TAONIAO_CONFIRM_DISBAND"] = {
    text = "确认解散当前队伍？",
    button1 = "解散",
    button2 = "取消",
    OnAccept = function() TN:DoDisband() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopup_Show("TAONIAO_CONFIRM_DISBAND")
end

function TN:DoDisband()
  local teamDB = self.db and self.db.profile and self.db.profile.team
  if IsInGroup() then
    local msg = teamDB and (teamDB.disbandMessage or "")
    msg = msg:match("^%s*$") and "" or msg
    if msg ~= "" then
      local channel = IsInRaid() and "RAID" or "PARTY"
      SendChatMessage(msg, channel)
    end
  end
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local name = GetRaidRosterInfo(i)
      if name and name ~= UnitName("player") then
        UninviteUnit(name)
      end
    end
  else
    for i = 1, MAX_PARTY_MEMBERS do
      local name = UnitName("party" .. i)
      if name then UninviteUnit(name) end
    end
  end
  self:Print("队伍已解散")
end

-- ── 团队自动化事件处理 ──
function TN:OnTeamEvent(event, ...)
  -- 防重入：GROUP_ROSTER_UPDATE 内的操作可能再次触发同类事件
  if self._teamEventRunning then return end
  self._teamEventRunning = true

  local args = { ... }
  local ok, err
  ok, err = pcall(function()
    local teamDB = self.db and self.db.profile and self.db.profile.team
    if not teamDB then return end

    if event == "CHAT_MSG_WHISPER" and teamDB.autoInvite then
      local msg, sender = args[1], args[2]
      local keywords = teamDB.inviteKeyword or "加 1 进组"
      for kw in keywords:gmatch("%S+") do
        if msg:lower():find(kw:lower()) then
          if not IsInGroup() or (IsInGroup() and GetNumGroupMembers() < (IsInRaid() and 40 or 5)) then
            InviteUnit(sender)
          end
          break
        end
      end
    elseif event == "GROUP_ROSTER_UPDATE" then
      if teamDB.autoConvertRaid and IsInGroup() and not IsInRaid() and GetNumGroupMembers() >= 5 then
        ConvertToRaid()
      end
      if teamDB.autoPromote and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
          local name, rank = GetRaidRosterInfo(i)
          if name and rank == 0 then
            PromoteToAssistant(name)
          end
        end
      end
      if teamDB.autoFreeLoot and IsInGroup() then
        SetLootMethod("free")
      end
    end
  end)

  if not ok then
    self:Print("团队事件处理出错: " .. tostring(err))
  end
  self._teamEventRunning = false
end
