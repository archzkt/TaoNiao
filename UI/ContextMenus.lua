--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/ContextMenus.lua
-- 右键菜单与编辑弹窗：敌人/战绩右键"见之必杀"、KOS 编辑罪名/删除、KOS 编辑弹窗。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createFont = Widgets.createFont
local createPopupPanel = Widgets.createPopupPanel
local DetailWidgets = TN.DetailWidgets
local createDetailInput = DetailWidgets.createDetailInput
local createDetailButton = DetailWidgets.createDetailButton

-- 敌人右键 → 见之必杀（加入死刑名单）
function TN:AddEnemyToKOS(enemy)
  if not enemy then return end
  local rows = self:GetDetailKOSData()
  local name = enemy.name
  for _, row in ipairs(rows) do
    if row.name == name then
      self:Print(name .. " 已在见之必杀中。")
      return
    end
  end
  local classFile = enemy.classFile or "UNKNOWN"
  local classInfo = self.classInfo[classFile] or self.classInfo.UNKNOWN
  table.insert(rows, {
    name = name,
    cls = classInfo.name,
    lv = enemy.level or "??",
    guild = enemy.guild or "",
    crime = "见之必杀",
    win = 0, loss = 0,
    last = date and date("%H:%M") or "00:00",
    zone = GetZoneText and (GetZoneText() or "未知区域") or "未知区域",
    tone = C.red,
  })
  self:Print("|cffff4d4f见之必杀|r " .. name .. " |cffff4d4f已加入见之必杀！|r")
  self:UpdateDetailHighRisk()
end

-- 详情页玩家行右键 → 加入死刑名单
function TN:AddRecordToKOS(data)
  local name = data.foe or data.name
  local classFile = TN.CLASS_FILE_BY_NAME[data.cls] or "UNKNOWN"
  self:AddEnemyToKOS({ name = name, classFile = classFile, level = data.lv })
end

function TN:ShowEnemyContextMenu(enemy)
  if not enemy then return end
  TN:HideEnemyContextMenu()
  GameTooltip:Hide()

  local name = enemy.name
  local classInfo = self.classInfo[enemy.classFile or "UNKNOWN"] or self.classInfo.UNKNOWN
  local cc = classInfo.color
  local rows = TN:GetDetailKOSData()
  local alreadyKOS = false
  for _, row in ipairs(rows) do
    if row.name == name then alreadyKOS = true; break end
  end

  local menuWidth = 128
  local menuHeight = 76
  local menu = createPopupPanel("TaoNiaoContextMenu", menuWidth, menuHeight)

  -- 标题：玩家名 + 职业色
  local titleBg = createTexture(menu, "BACKGROUND", { cc[1], cc[2], cc[3], 0.08 })
  titleBg:SetPoint("TOPLEFT", 2, -2)
  titleBg:SetPoint("TOPRIGHT", -2, -22)
  local title = createFont(menu, 11, C.text, "OUTLINE", "bold")
  title:SetPoint("TOPLEFT", 8, -4)
  title:SetPoint("TOPRIGHT", -8, -4)
  title:SetJustifyH("CENTER")
  title:SetText(name)
  Theme.setColor(title, cc)

  -- 见之必杀行
  local item = CreateFrame("Button", nil, menu)
  item:SetSize(menuWidth - 8, 24)
  item:SetPoint("TOPLEFT", 4, -24)
  item.bg = createTexture(item, "BACKGROUND", { 1, 1, 1, 0.05 })
  item.bg:SetAllPoints()
  item.label = createFont(item, 11, alreadyKOS and C.text3 or C.red, "OUTLINE", "medium")
  item.label:SetPoint("CENTER")
  item.label:SetWidth(menuWidth - 16)
  item.label:SetJustifyH("CENTER")
  item.label:SetText(alreadyKOS and "已在见之必杀" or "见之必杀")
  item:SetScript("OnEnter", function(self)
    if not alreadyKOS then
      self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
      Theme.setColor(self.label, C.text)
    end
  end)
  item:SetScript("OnLeave", function(self)
    if not alreadyKOS then
      self.bg:SetVertexColor(1, 1, 1, 0.03)
      Theme.setColor(self.label, C.red)
    end
  end)
  if not alreadyKOS then
    item:SetScript("OnClick", function()
      TN:HideEnemyContextMenu()
      TN:AddEnemyToKOS(enemy)
    end)
  else
    item:EnableMouse(false)
  end

  -- 快捷通报行
  local btnRow = CreateFrame("Frame", nil, menu)
  btnRow:SetSize(menuWidth - 8, 26)
  btnRow:SetPoint("TOPLEFT", 4, -50)
  local btnRowBg = createTexture(btnRow, "BACKGROUND", { 1, 1, 1, 0.03 })
  btnRowBg:SetAllPoints()

  local btnW = 28
  local btnGap = 4
  local function addQuickBtn(text, channel, color, x)
    local btn = CreateFrame("Button", nil, btnRow, "BackdropTemplate")
    btn:SetSize(btnW, 18)
    btn:SetPoint("LEFT", x, 0)
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(color[1], color[2], color[3], 0.08)
    btn:SetBackdropBorderColor(color[1], color[2], color[3], 0.45)
    btn.text = createFont(btn, 10, C.text, "", "bold")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    Theme.setColor(btn.text, color)
    btn:SetScript("OnEnter", function(self)
      self:SetBackdropColor(color[1], color[2], color[3], 0.22)
      self:SetBackdropBorderColor(color[1], color[2], color[3], 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
      self:SetBackdropColor(color[1], color[2], color[3], 0.08)
      self:SetBackdropBorderColor(color[1], color[2], color[3], 0.45)
    end)
    btn:SetScript("OnClick", function()
      TN:HideEnemyContextMenu()
      if alreadyKOS then
        TN:AnnounceKOSEnemy(enemy, channel)
      else
        TN:AnnounceEnemyTo(enemy, channel)
      end
    end)
  end
  local rowW = menuWidth - 8
  local startX = (rowW - btnW * 3 - btnGap * 2) / 2
  addQuickBtn("队", "PARTY", { 0.42, 0.73, 1.00, 1 }, startX)
  addQuickBtn("团", "RAID", C.orange, startX + btnW + btnGap)
  addQuickBtn("公", "GUILD", C.green, startX + (btnW + btnGap) * 2)

  local cursorX, cursorY = GetCursorPosition()
  local scale = menu:GetEffectiveScale() or 1
  menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)

  TN.contextMenu = menu
  menu:Show()

  -- 点击空白处关闭
  local closeFrame = CreateFrame("Frame", nil, UIParent)
  closeFrame:SetAllPoints()
  closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  closeFrame:SetFrameLevel(menu:GetFrameLevel() - 1)
  closeFrame:EnableMouse(true)
  closeFrame:SetScript("OnMouseDown", function() TN:HideEnemyContextMenu() end)
  TN.contextMenuCloseFrame = closeFrame
  closeFrame:Show()
end

function TN:HideEnemyContextMenu()
  if self.contextMenu then
    self.contextMenu:Hide()
    self.contextMenu = nil
  end
  if self.contextMenuCloseFrame then
    self.contextMenuCloseFrame:Hide()
    self.contextMenuCloseFrame = nil
  end
  GameTooltip:Hide()
end

function TN:ShowDetailRecordContextMenu(data)
  if not data then return end
  TN:HideEnemyContextMenu()
  GameTooltip:Hide()

  local name = data.foe or data.name
  local classFile = TN.CLASS_FILE_BY_NAME[data.cls] or "UNKNOWN"
  local classInfo = TN.classInfo[classFile] or TN.classInfo.UNKNOWN
  local cc = classInfo.color
  local rows = TN:GetDetailKOSData()
  local alreadyKOS = false
  for _, row in ipairs(rows) do
    if row.name == name then alreadyKOS = true; break end
  end

  local menuWidth = 128
  local menuHeight = 52
  local menu = createPopupPanel("TaoNiaoDetailRecordMenu", menuWidth, menuHeight)

  -- 标题：玩家名 + 职业色
  local titleBg = createTexture(menu, "BACKGROUND", { cc[1], cc[2], cc[3], 0.08 })
  titleBg:SetPoint("TOPLEFT", 2, -2)
  titleBg:SetPoint("TOPRIGHT", -2, -22)
  local title = createFont(menu, 11, C.text, "OUTLINE", "bold")
  title:SetPoint("TOPLEFT", 8, -4)
  title:SetPoint("TOPRIGHT", -8, -4)
  title:SetJustifyH("CENTER")
  title:SetText(name)
  Theme.setColor(title, cc)

  -- 见之必杀行
  local item = CreateFrame("Button", nil, menu)
  item:SetSize(menuWidth - 8, 24)
  item:SetPoint("TOPLEFT", 4, -24)
  item.bg = createTexture(item, "BACKGROUND", { 1, 1, 1, 0.05 })
  item.bg:SetAllPoints()
  item.label = createFont(item, 11, alreadyKOS and C.text3 or C.red, "OUTLINE", "medium")
  item.label:SetPoint("CENTER")
  item.label:SetWidth(menuWidth - 16)
  item.label:SetJustifyH("CENTER")
  item.label:SetText(alreadyKOS and "已在见之必杀" or "见之必杀")
  item:SetScript("OnEnter", function(self)
    if not alreadyKOS then
      self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
      Theme.setColor(self.label, C.text)
    end
  end)
  item:SetScript("OnLeave", function(self)
    if not alreadyKOS then
      self.bg:SetVertexColor(1, 1, 1, 0.05)
      Theme.setColor(self.label, C.red)
    end
  end)
  if not alreadyKOS then
    item:SetScript("OnClick", function()
      TN:HideEnemyContextMenu()
      TN:AddRecordToKOS(data)
    end)
  else
    item:EnableMouse(false)
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = menu:GetEffectiveScale() or 1
  menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)

  TN.contextMenu = menu
  menu:Show()

  local closeFrame = CreateFrame("Frame", nil, UIParent)
  closeFrame:SetAllPoints()
  closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  closeFrame:SetFrameLevel(menu:GetFrameLevel() - 1)
  closeFrame:EnableMouse(true)
  closeFrame:SetScript("OnMouseDown", function() TN:HideEnemyContextMenu() end)
  TN.contextMenuCloseFrame = closeFrame
  closeFrame:Show()
end

-- 见之必杀右键菜单
function TN:ShowKOSContextMenu(index, data)
  if not index or not data then return end
  TN:HideKOSContextMenu()
  GameTooltip:Hide()

  local classFile = TN.CLASS_FILE_BY_NAME[data.cls] or data.cls or "UNKNOWN"
  local classInfo = TN.classInfo[classFile] or TN.classInfo.UNKNOWN
  local cc = classInfo.color

  local menuWidth = 128
  local menuHeight = 82
  local menu = createPopupPanel("TaoNiaoKOSMenu", menuWidth, menuHeight)

  -- 标题：玩家名 + 职业色
  local titleBg = createTexture(menu, "BACKGROUND", { cc[1], cc[2], cc[3], 0.08 })
  titleBg:SetPoint("TOPLEFT", 2, -2)
  titleBg:SetPoint("TOPRIGHT", -2, -22)
  local title = createFont(menu, 11, C.text, "OUTLINE", "bold")
  title:SetPoint("TOPLEFT", 8, -4)
  title:SetPoint("TOPRIGHT", -8, -4)
  title:SetJustifyH("CENTER")
  title:SetText(data.name or "")
  Theme.setColor(title, cc)

  -- 更新原因
  local editItem = CreateFrame("Button", nil, menu)
  editItem:SetSize(menuWidth - 8, 26)
  editItem:SetPoint("TOPLEFT", 4, -26)
  editItem.bg = createTexture(editItem, "BACKGROUND", { 1, 1, 1, 0.05 })
  editItem.bg:SetAllPoints()
  editItem.label = createFont(editItem, 11, C.text, "OUTLINE", "medium")
  editItem.label:SetPoint("CENTER")
  editItem.label:SetWidth(menuWidth - 16)
  editItem.label:SetJustifyH("CENTER")
  editItem.label:SetText("更新原因")
  editItem:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
    Theme.setColor(self.label, C.text)
  end)
  editItem:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0.05)
    Theme.setColor(self.label, C.text)
  end)
  editItem:SetScript("OnClick", function()
    TN:HideKOSContextMenu()
    TN:ShowKOSEditDialog(index, data)
  end)

  -- 移除
  local delItem = CreateFrame("Button", nil, menu)
  delItem:SetSize(menuWidth - 8, 26)
  delItem:SetPoint("TOPLEFT", 4, -52)
  delItem.bg = createTexture(delItem, "BACKGROUND", { 1, 1, 1, 0.03 })
  delItem.bg:SetAllPoints()
  delItem.label = createFont(delItem, 11, C.red, "OUTLINE", "medium")
  delItem.label:SetPoint("CENTER")
  delItem.label:SetWidth(menuWidth - 16)
  delItem.label:SetJustifyH("CENTER")
  delItem.label:SetText("移除")
  delItem:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.15)
    Theme.setColor(self.label, C.text)
  end)
  delItem:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0.03)
    Theme.setColor(self.label, C.red)
  end)
  delItem:SetScript("OnClick", function()
    TN:HideKOSContextMenu()
    TN:DeleteDetailKOS(index)
  end)

  local cursorX, cursorY = GetCursorPosition()
  local scale = menu:GetEffectiveScale() or 1
  menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)

  TN.kosContextMenu = menu
  menu:Show()

  if C_Timer and C_Timer.After then
    C_Timer.After(0.1, function()
      if TN.kosContextMenu then
        local closeFrame = CreateFrame("Frame", nil, UIParent)
        closeFrame:SetAllPoints()
        closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        closeFrame:SetFrameLevel(menu:GetFrameLevel() - 1)
        closeFrame:EnableMouse(true)
        closeFrame:SetScript("OnMouseDown", function() TN:HideKOSContextMenu() end)
        TN.kosContextMenuCloseFrame = closeFrame
        closeFrame:Show()
      end
    end)
  end
end

function TN:HideKOSContextMenu()
  if self.kosContextMenu then
    self.kosContextMenu:Hide()
    self.kosContextMenu = nil
  end
  if self.kosContextMenuCloseFrame then
    self.kosContextMenuCloseFrame:Hide()
    self.kosContextMenuCloseFrame = nil
  end
  GameTooltip:Hide()
end

-- 编辑罪名弹窗
function TN:ShowKOSEditDialog(index, data)
  if not index or not data then return end
  TN:HideKOSEditDialog()

  local dialogWidth = 360
  local dialogHeight = 140
  local dialog = createPopupPanel("TaoNiaoKOSEdit", dialogWidth, dialogHeight)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  dialog.title = createFont(dialog, 14, C.red, "OUTLINE", "bold")
  dialog.title:SetPoint("TOPLEFT", 16, -14)
  dialog.title:SetText("更新原因 · " .. (data.name or ""))

  dialog.crimeInput = createDetailInput(dialog, dialogWidth - 32, "输入原因")
  dialog.crimeInput:SetPoint("TOPLEFT", 16, -42)
  dialog.crimeInput:SetText(data.crime or "")
  dialog.crimeInput.bg:SetVertexColor(1, 1, 1, 0.08)
  dialog.crimeInput:SetScript("OnEditFocusLost", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0.08)
  end)

  dialog.confirm = createDetailButton(dialog, "确定", 68, function()
    local crime = dialog.crimeInput:GetText() or ""
    if crime ~= "" then
      data.crime = crime
    end
    TN:HideKOSEditDialog()
    TN:UpdateDetailHighRisk()
  end)
  dialog.confirm:SetPoint("BOTTOMRIGHT", -16, 14)

  dialog.cancel = createDetailButton(dialog, "取消", 68, function()
    TN:HideKOSEditDialog()
  end)
  dialog.confirm.bg:SetVertexColor(1, 1, 1, 0.08)
  dialog.cancel.bg:SetVertexColor(1, 1, 1, 0.08)
  dialog.cancel:SetPoint("RIGHT", dialog.confirm, "LEFT", -8, 0)

  TN.kosEditDialog = dialog
  dialog:Show()

  if C_Timer and C_Timer.After then
    C_Timer.After(0.15, function()
      if TN.kosEditDialog then
        local closeFrame = CreateFrame("Frame", nil, UIParent)
        closeFrame:SetAllPoints()
        closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        closeFrame:SetFrameLevel(dialog:GetFrameLevel() - 1)
        closeFrame:EnableMouse(true)
        closeFrame:SetScript("OnMouseDown", function() TN:HideKOSEditDialog() end)
        TN.kosEditDialogCloseFrame = closeFrame
        closeFrame:Show()
      end
    end)
  end
end

function TN:HideKOSEditDialog()
  if self.kosEditDialog then
    self.kosEditDialog:Hide()
    self.kosEditDialog = nil
  end
  if self.kosEditDialogCloseFrame then
    self.kosEditDialogCloseFrame:Hide()
    self.kosEditDialogCloseFrame = nil
  end
end

-- 手动新增死刑名单（从弹窗）
function TN:AddManualKOS(name, cls, crime)
  local rows = self:GetDetailKOSData()
  for _, row in ipairs(rows) do
    if row.name == name then
      self:Print(name .. " 已在见之必杀中。")
      return
    end
  end
  local mu = (self.db.char.matchups or {})[name]
  local last = date and date("%H:%M") or "00:00"
  table.insert(rows, {
    name = name,
    cls = cls ~= "" and cls or "未知",
    lv = (mu and mu.lv) or "??",
    crime = crime,
    win = (mu and mu.win) or 0,
    loss = (mu and mu.loss) or 0,
    last = last,
    zone = GetZoneText and (GetZoneText() or "未知区域") or "未知区域",
    tone = C.red,
  })
  self:Print("|cffff4d4f" .. name .. " 已加入见之必杀|r")
  if self.UpdateDetailHighRisk then self:UpdateDetailHighRisk() end
end

-- 新增死刑名单弹窗（玩家名 + 职业 + 罪名）
function TN:ShowKOSAddDialog()
  TN:HideKOSAddDialog()
  local dialogWidth = 380
  local dialogHeight = 220
  local dialog = createPopupPanel("TaoNiaoKOSAdd", dialogWidth, dialogHeight)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  dialog.title = createFont(dialog, 14, C.red, "OUTLINE", "bold")
  dialog.title:SetPoint("TOPLEFT", 16, -14)
  dialog.title:SetText("新增死刑名单")

  local inputW = dialogWidth - 32
  local y = -42

  local nameLabel = createFont(dialog, 11, C.text3, "", "medium")
  nameLabel:SetPoint("TOPLEFT", 16, y)
  nameLabel:SetText("玩家名")
  y = y - 18
  dialog.nameInput = createDetailInput(dialog, inputW, "输入玩家名")
  dialog.nameInput:SetPoint("TOPLEFT", 16, y)
  dialog.nameInput:SetHeight(26)
  y = y - 34

  local clsLabel = createFont(dialog, 11, C.text3, "", "medium")
  clsLabel:SetPoint("TOPLEFT", 16, y)
  clsLabel:SetText("职业")
  y = y - 18
  dialog.clsInput = createDetailInput(dialog, inputW, "输入职业（如：盗贼、法师）")
  dialog.clsInput:SetPoint("TOPLEFT", 16, y)
  dialog.clsInput:SetHeight(26)
  y = y - 34

  local crimeLabel = createFont(dialog, 11, C.text3, "", "medium")
  crimeLabel:SetPoint("TOPLEFT", 16, y)
  crimeLabel:SetText("罪名")
  y = y - 18
  dialog.crimeInput = createDetailInput(dialog, inputW, "输入罪名")
  dialog.crimeInput:SetPoint("TOPLEFT", 16, y)
  dialog.crimeInput:SetHeight(26)

  dialog.confirm = createDetailButton(dialog, "确定", 68, function()
    local name = dialog.nameInput:GetText() or ""
    local cls = dialog.clsInput:GetText() or ""
    local crime = dialog.crimeInput:GetText() or ""
    if name == "" then
      if UIErrorsFrame then UIErrorsFrame:AddMessage("|cffff4d4f请输入玩家名|r", 1, 0.3, 0.3, 1, 3) end
      return
    end
    if crime == "" then crime = "见之必杀" end
    TN:AddManualKOS(name, cls, crime)
    TN:HideKOSAddDialog()
  end)
  dialog.confirm:SetPoint("BOTTOMRIGHT", -16, 14)
  dialog.cancel = createDetailButton(dialog, "取消", 68, function()
    TN:HideKOSAddDialog()
  end)
  dialog.cancel:SetPoint("RIGHT", dialog.confirm, "LEFT", -8, 0)

  TN.kosAddDialog = dialog
  dialog:Show()
  if dialog.nameInput.SetFocus then dialog.nameInput:SetFocus() end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.15, function()
      if TN.kosAddDialog then
        local closeFrame = CreateFrame("Frame", nil, UIParent)
        closeFrame:SetAllPoints()
        closeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        closeFrame:SetFrameLevel(dialog:GetFrameLevel() - 1)
        closeFrame:EnableMouse(true)
        closeFrame:SetScript("OnMouseDown", function() TN:HideKOSAddDialog() end)
        TN.kosAddDialogCloseFrame = closeFrame
        closeFrame:Show()
      end
    end)
  end
end

function TN:HideKOSAddDialog()
  if self.kosAddDialog then
    self.kosAddDialog:Hide()
    self.kosAddDialog = nil
  end
  if self.kosAddDialogCloseFrame then
    self.kosAddDialogCloseFrame:Hide()
    self.kosAddDialogCloseFrame = nil
  end
end
