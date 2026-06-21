--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/DetailPhase.lua
-- 详情页 · 位面助手：5 行配置行（角色名/密语/启用/测试）+ 底部提示。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local setShown = Theme.setShown
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local createRoundedBlock = Widgets.createRoundedBlock
local DetailWidgets = TN.DetailWidgets
local DETAIL_CONTENT_WIDTH = Theme.Layout.DETAIL_CONTENT_WIDTH
local createDetailInput = DetailWidgets.createDetailInput
local createDetailBox = DetailWidgets.createDetailBox
local createDetailHeader = DetailWidgets.createDetailHeader
local createDetailButton = DetailWidgets.createDetailButton
local clearDetailMain = DetailWidgets.clearDetailMain
local addDetailFrame = DetailWidgets.addDetailFrame

-- Base64 编码/解码
local bytetoB64 = {
  [0]="a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p",
  "q","r","s","t","u","v","w","x","y","z","A","B","C","D","E","F",
  "G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V",
  "W","X","Y","Z","0","1","2","3","4","5","6","7","8","9","(",")"
}
local B64tobyte = {}
for k, v in pairs(bytetoB64) do B64tobyte[v] = k end

local function encodeB64(str)
  local bytes = { str:byte(1, #str) }
  local out, bf, bl = {}, 0, 0
  for i = 1, #bytes do
    bf = bf + bytes[i] * 2^bl
    bl = bl + 8
    while bl >= 6 do
      out[#out+1] = bytetoB64[bf % 64]
      bf = math.floor(bf / 64)
      bl = bl - 6
    end
  end
  if bl > 0 then out[#out+1] = bytetoB64[bf % 64] end
  return table.concat(out)
end

local function decodeB64(str)
  local out, bf, bl = {}, 0, 0
  for i = 1, #str do
    local ch = B64tobyte[str:sub(i,i)]
    if ch then
      bf = bf + ch * 2^bl
      bl = bl + 6
      while bl >= 8 do
        out[#out+1] = bf % 256
        bf = math.floor(bf / 256)
        bl = bl - 8
      end
    end
  end
  if #out == 0 then return "" end
  return string.char(unpack(out))
end

local function createPhaseRow(parent, phaseDB, y)
  local isEnabled = phaseDB.enabled

  local row = CreateFrame("Button", nil, parent)
  row:SetPoint("TOPLEFT", 14, y)
  row:SetPoint("TOPRIGHT", -14, y)
  row:SetHeight(36)

  row.bg = createTexture(row, "BACKGROUND", C.cell)
  row.bg:SetAllPoints()

  row.icon = createIcon(row, "portal", 16, isEnabled and C.cyan or C.text3)
  row.icon:SetPoint("LEFT", 10, 0)

  row.nameLabel = createFont(row, 13, isEnabled and C.text or C.text3, "", "medium")
  row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  row.nameLabel:SetWidth(58)
  row.nameLabel:SetJustifyH("LEFT")
  row.nameLabel:SetText(phaseDB.name)

  row.helperInput = createDetailInput(row, 260, phaseDB.helper or "")
  row.helperInput:SetPoint("LEFT", row.nameLabel, "RIGHT", 10, 0)
  row.helperInput:SetHeight(26)
  row.helperInput.bg:SetVertexColor(1, 1, 1, 0.06)
  row.helperInput.placeholder:SetText("位面角色名")
  row.helperInput:SetScript("OnEnter", function() end)
  row.helperInput:SetScript("OnLeave", function() end)
  row.helperInput:SetText(phaseDB.helper or "")
  setShown(row.helperInput.placeholder, (phaseDB.helper or "") == "")

  row.msgLabel = createFont(row, 11, C.text3, "", "regular")
  row.msgLabel:SetPoint("LEFT", row.helperInput, "RIGHT", 12, 0)
  row.msgLabel:SetText("密语:")

  row.msgInput = createDetailInput(row, 160, phaseDB.message or "")
  row.msgInput:SetPoint("LEFT", row.msgLabel, "RIGHT", 6, 0)
  row.msgInput:SetHeight(26)
  row.msgInput.bg:SetVertexColor(1, 1, 1, 0.06)
  row.msgInput.placeholder:SetText("消息")
  row.msgInput:SetScript("OnEnter", function() end)
  row.msgInput:SetScript("OnLeave", function() end)
  row.msgInput:SetText(phaseDB.message or "")
  setShown(row.msgInput.placeholder, (phaseDB.message or "") == "")

  row.toggle = CreateFrame("Button", nil, row)
  row.toggle:SetSize(28, 28)
  row.toggle:SetPoint("RIGHT", -6, 0)
  row.dot = createRoundedBlock(row.toggle, "ARTWORK", isEnabled and C.cyan or C.text3)
  row.dot:SetSize(10, 10)
  row.dot:SetPoint("CENTER")
  row.toggle.dotTex = row.dot

  local function isConfigured()
    local h = (phaseDB.helper or ""):match("^%s*(.-)%s*$")
    local m = (phaseDB.message or ""):match("^%s*(.-)%s*$")
    return h ~= "" and m ~= ""
  end

  local function refreshRow()
    local configured = isConfigured()
    if phaseDB.enabled and not configured then
      phaseDB.enabled = false
    end
    local on = phaseDB.enabled
    row.icon:SetVertexColor(rgba(on and C.cyan or C.text3))
    setColor(row.nameLabel, on and C.text or C.text3)
    row.dot:SetVertexColor(rgba(on and C.cyan or C.text3))
    row.dot:SetAlpha(configured and 1 or 0.35)
    row.testBtn.bg:SetVertexColor(1, 1, 1, configured and 0.035 or 0.015)
    setColor(row.testBtn.label, configured and C.text2 or C.text3)
  end

  local function missingText()
    local h = (phaseDB.helper or ""):match("^%s*(.-)%s*$")
    local m = (phaseDB.message or ""):match("^%s*(.-)%s*$")
    local list = {}
    if h == "" then table.insert(list, "位面角色名") end
    if m == "" then table.insert(list, "密语消息") end
    return "尚未配置：" .. table.concat(list, "、") .. "，填写完整后才能启用"
  end

  local function flashInput(input)
    if not input then return end
    input.bg:SetVertexColor(rgba(C.red))
    input.bg:SetAlpha(0.6)
    C_Timer.After(0.18, function()
      input.bg:SetVertexColor(1, 1, 1, 0.06)
    end)
  end

  row.testBtn = CreateFrame("Button", nil, row)
  row.testBtn:SetSize(48, 26)
  row.testBtn:SetPoint("LEFT", row.msgInput, "RIGHT", 8, 0)
  row.testBtn.bg = createTexture(row.testBtn, "BACKGROUND", C.cell)
  row.testBtn.bg:SetAllPoints()
  row.testBtn.label = createFont(row.testBtn, 12, C.text2, "", "regular")
  row.testBtn.label:SetPoint("CENTER")
  row.testBtn.label:SetText("测试")
  row.testBtn:SetScript("OnEnter", function(self)
    local configured = isConfigured()
    self.bg:SetVertexColor(configured and 0.20 or 1, configured and 0.78 or 1, configured and 0.91 or 1, configured and 0.12 or 0.05)
    if configured then setColor(self.label, C.cyan) end
  end)
  row.testBtn:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
    setColor(self.label, isConfigured() and C.text2 or C.text3)
  end)
  row.testBtn:SetScript("OnClick", function()
    if not isConfigured() then
      local h = (phaseDB.helper or ""):match("^%s*(.-)%s*$")
      local m = (phaseDB.message or ""):match("^%s*(.-)%s*$")
      if h == "" then flashInput(row.helperInput) end
      if m == "" then flashInput(row.msgInput) end
      GameTooltip:SetOwner(row.testBtn, "ANCHOR_TOP")
      GameTooltip:SetText(missingText(), C.yellow[1], C.yellow[2], C.yellow[3], C.yellow[4], true)
      GameTooltip:Show()
      return
    end
    SendChatMessage(phaseDB.message, "WHISPER", nil, phaseDB.helper)
    TN:Print("已向 " .. phaseDB.helper .. " 发送测试密语：" .. phaseDB.message)
  end)

  row.refresh = refreshRow
  row.helperInput:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    setShown(self.placeholder, text == "")
    phaseDB.helper = text
    refreshRow()
  end)
  row.msgInput:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    setShown(self.placeholder, text == "")
    phaseDB.message = text
    refreshRow()
  end)

  local function doToggle()
    row.helperInput:ClearFocus()
    row.msgInput:ClearFocus()
    if not isConfigured() then
      local h = (phaseDB.helper or ""):match("^%s*(.-)%s*$")
      local m = (phaseDB.message or ""):match("^%s*(.-)%s*$")
      if h == "" then flashInput(row.helperInput) end
      if m == "" then flashInput(row.msgInput) end
      GameTooltip:SetOwner(row.toggle, "ANCHOR_RIGHT")
      GameTooltip:SetText(missingText(), C.yellow[1], C.yellow[2], C.yellow[3], C.yellow[4], true)
      GameTooltip:Show()
      return
    end
    GameTooltip:Hide()
    phaseDB.enabled = not phaseDB.enabled
    refreshRow()
  end

  row.toggle:SetScript("OnEnter", function()
    GameTooltip:SetOwner(row.toggle, "ANCHOR_RIGHT")
    if not isConfigured() then
      GameTooltip:SetText(missingText(), C.yellow[1], C.yellow[2], C.yellow[3], C.yellow[4], true)
    else
      GameTooltip:SetText(phaseDB.enabled and "已启用（点击禁用）" or "已禁用（点击启用）", C.text[1], C.text[2], C.text[3], C.text[4], true)
    end
    GameTooltip:Show()
  end)
  row.toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row.toggle:SetScript("OnClick", doToggle)

  row:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(rgba(C.cellHi))
  end)
  row:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
  end)

  row:SetScript("OnClick", doToggle)

  refreshRow()

  return row
end

function TN:RenderDetailPhase()
  local detail = self.detail
  clearDetailMain(detail)
  local frame = addDetailFrame(detail, CreateFrame("Frame", nil, detail.main))
  frame:SetAllPoints()

  local card = createDetailBox(frame, 0.40)
  card:SetPoint("TOPLEFT", 22, -20)
  card:SetPoint("BOTTOMRIGHT", -22, 22)
  createDetailHeader(card, "portal", "位面助手")

  local phases = self.db.profile.phaseHelpers or {}
  local y = -50
  for i, phaseDB in ipairs(phases) do
    createPhaseRow(card, phaseDB, y)
    y = y - 36 - 14
  end

  local hint = createFont(card, 11, C.text3, "", "regular")
  hint:SetPoint("TOPLEFT", 16, y)
  hint:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetText("提示：助手若非哈霍兰本服玩家，需在名字后加服务器名（如：玩家-服务器）。建议在游戏内查询目标玩家后复制完整角色名粘贴使用。")

-- 分享配置
  y = y - 48
  local shareInput = CreateFrame("EditBox", nil, card)
  shareInput:SetMultiLine(true)
  shareInput:SetSize(DETAIL_CONTENT_WIDTH - 28, 60)
  shareInput:SetPoint("TOPLEFT", 14, y)
  shareInput:SetAutoFocus(false)
  shareInput:SetTextColor(rgba(C.text))
  shareInput:SetJustifyH("LEFT")
  shareInput:SetTextInsets(8, 8, 4, 4)
  shareInput.bg = createTexture(shareInput, "BACKGROUND", { 1, 1, 1, 0.05 })
  shareInput.bg:SetAllPoints()
  shareInput:SetFont(STANDARD_TEXT_FONT, 12, "")
  shareInput:SetText("\n\n\n ")  -- 预填充维持高度
  shareInput.placeholder = createFont(shareInput, 12, C.text3)
  shareInput.placeholder:SetPoint("TOPLEFT", 8, -4)
  shareInput.placeholder:SetText("点击下方按钮生成配置字符串")
  shareInput:SetHeight(60)
  y = y - 66
  local shareBtn = createDetailButton(card, "生成配置字符串", 130, function()
    local parts = {}
    for _, p in ipairs(self.db.profile.phaseHelpers or {}) do
      if p.helper ~= "" then parts[#parts + 1] = p.helper .. "=" .. (p.message or "") end
    end
    if #parts == 0 then return end
    local encoded = encodeB64(table.concat(parts, ","))
    local text = "[TaoNiao Phase: " .. (UnitName("player") or "") .. "] " .. encoded
    shareInput:SetText(text)
    shareInput:SetHeight(60)
    shareInput.placeholder:Hide()
  end)
  shareBtn:SetPoint("TOPLEFT", 14, y)

  frame:Show()
end

-- 聊天过滤器：检测 [TaoNiao Phase: xxx] 转为可点击超链接
local phaseFilter = function(_, event, msg, ...)
  local newMsg = msg:gsub("%[TaoNiao Phase: ([^%]]+)%] (%S+)", function(name, encoded)
    return "|Htaoniaophase:" .. encoded .. "|h|cff34c6e8[位面配置:" .. name .. "]|h|r"
  end)
  if newMsg ~= msg then return false, newMsg, ... end
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", phaseFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", phaseFilter)

-- 超链接点击处理（hooksecurefunc 链式 hook，不覆盖其他 addon）
hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link, ...)
  local data = link:match("taoniaophase:(.+)")
  if data then
    local decoded = decodeB64(data)
    if decoded then TN:ShowPhaseImportConfirm("|Htaoniaophase:" .. data .. "|h", nil) end
  end
end)

-- 序列化/解析/导入
function TN:ParsePhaseConfig(data)
  local encoded = data:match("taoniaophase:(.+)")
  if not encoded then return nil end
  local raw = decodeB64(encoded)
  if not raw or raw == "" then return nil end
  local items = {}
  for item in raw:gmatch("[^,]+") do items[#items+1] = item end
  local config, defs = {}, {
    {name="位面 1", msg="1"},{name="位面 2", msg="2"},{name="位面 3", msg="3"},{name="位面 4", msg="4"},{name="位面 5", msg="5"},
  }
  for i = 1, 5 do
    config[i] = {name=defs[i].name, helper="", message=defs[i].msg, enabled=false}
    if items[i] then
      local h, m = items[i]:match("^([^=]*)=(.*)$")
      if h then config[i].helper = h; config[i].message = m ~= "" and m or defs[i].msg end
    end
  end
  return config
end

function TN:ShowPhaseImportConfirm(data, sender)
  local config = self:ParsePhaseConfig(data)
  if not config then return end
  local preview = ""
  for _, p in ipairs(config) do
    if p.helper ~= "" then preview = preview .. p.name .. "→" .. p.helper .. " " end
  end
  local title = sender and (sender .. " 发送了位面配置") or "导入位面配置"
  StaticPopupDialogs["TAONIAO_IMPORT_PHASE"] = {
    text = "|cff34c6e8" .. title .. "：|r\n" .. preview .. "\n\n是否导入并覆盖当前配置？",
    button1 = "导入", button2 = "取消",
    OnAccept = function()
      self.db.profile.phaseHelpers = config
      self:Print("|cff34c6e8位面配置已导入！|r")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopup_Show("TAONIAO_IMPORT_PHASE")
end
