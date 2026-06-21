--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/ForceZone.lua
-- 势力区：通报栏 + 附近敌方/友方 双列 + 职业分布芯片。

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
local applyRoundedCorners = Widgets.applyRoundedCorners
local Layout = Theme.Layout
local LIST_DEFAULT_WIDTH = Layout.LIST_DEFAULT_WIDTH
local HUD_FORCE_HEIGHT = Layout.HUD_FORCE_HEIGHT

function TN:CreateForceZone(parent)
  local zone = CreateFrame("Frame", nil, parent)
  zone:SetSize(LIST_DEFAULT_WIDTH - 24, HUD_FORCE_HEIGHT)

  -- 背景卡片：9-slice 圆角（radius=4，轻微圆角）
  zone.rc = applyRoundedCorners(zone, 4, C.cell)

  -- 共享通报栏（顶部全宽）
  zone.announceBar = CreateFrame("Frame", nil, zone)
  zone.announceBar:SetPoint("TOPLEFT")
  zone.announceBar:SetPoint("TOPRIGHT")
  zone.announceBar:SetHeight(24)
  zone.announceIcon = createIcon(zone.announceBar, "megaphone", 11, C.cyan)
  zone.announceIcon:SetPoint("LEFT", 6, 0)
  zone.announceLabel = createFont(zone.announceBar, 11, C.text2, "", "medium")
  zone.announceLabel:SetPoint("LEFT", zone.announceIcon, "RIGHT", 4, 0)
  zone.announceLabel:SetText("势力通报")
  -- 通报栏底部分隔线
  zone.announceLine = createTexture(zone, "ARTWORK", C.lineSoft)
  zone.announceLine:SetPoint("TOPLEFT", zone.announceBar, "BOTTOMLEFT", 0, -1)
  zone.announceLine:SetPoint("TOPRIGHT", zone.announceBar, "BOTTOMRIGHT", 0, -1)
  zone.announceLine:SetHeight(1)

  -- 快速通报按钮：队/团/公
  local channelNames = { PARTY = "小队", RAID = "团队", GUILD = "公会", CHANNEL = "本地防务" }
  local function createQuickBtn(parent, text, channel, color)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(22, 20)
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0, 0, 0, 0)
    btn:SetBackdropBorderColor(color[1], color[2], color[3], 0.65)
    btn.text = createFont(btn, 10, C.text, "", "bold")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    setColor(btn.text, color)
    btn:SetScript("OnEnter", function(self)
      self:SetBackdropColor(color[1], color[2], color[3], 0.22)
      self:SetBackdropBorderColor(color[1], color[2], color[3], 0.9)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText("通报至" .. (channelNames[channel] or channel), rgba(color))
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
      self:SetBackdropColor(0, 0, 0, 0)
      self:SetBackdropBorderColor(color[1], color[2], color[3], 0.65)
      GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
      btn:SetBackdropColor(color[1], color[2], color[3], 0.4)
      C_Timer.After(0.12, function()
        if btn and not btn:IsMouseOver() then
          btn:SetBackdropColor(0, 0, 0, 0)
        end
      end)
      TN:QuickAnnounce(channel)
    end)
    btn:Hide()
    return btn
  end
  zone.quickParty = createQuickBtn(zone.announceBar, "队", "PARTY", { 0.42, 0.73, 1.00, 1 })
  zone.quickParty:SetPoint("LEFT", zone.announceLabel, "RIGHT", 10, 0)
  zone.quickRaid = createQuickBtn(zone.announceBar, "团", "RAID", C.orange)
  zone.quickRaid:SetPoint("LEFT", zone.quickParty, "RIGHT", 4, 0)
  zone.quickGuild = createQuickBtn(zone.announceBar, "公", "GUILD", C.green)
  zone.quickGuild:SetPoint("LEFT", zone.quickRaid, "RIGHT", 4, 0)
  zone.quickLocal = createQuickBtn(zone.announceBar, "本", "CHANNEL", C.yellow)
  zone.quickLocal:SetPoint("LEFT", zone.quickGuild, "RIGHT", 4, 0)

  -- 中分隔线
  zone.vsep = createTexture(zone, "ARTWORK", C.lineSoft)
  zone.vsep:SetWidth(1)

  -- 敌方列（左半）
  zone.enemyCol = CreateFrame("Frame", nil, zone)
  zone.enemyCol:SetPoint("TOPLEFT")
  zone.enemyCol:SetPoint("BOTTOMLEFT")
  zone.enemyIcon = createIcon(zone.enemyCol, "crosshair", 11, C.red)
  zone.enemyIcon:SetPoint("TOPLEFT", 6, -7)
  zone.enemyLabel = createFont(zone.enemyCol, 11, C.text, "", "medium")
  zone.enemyLabel:SetPoint("LEFT", zone.enemyIcon, "RIGHT", 5, 0)
  zone.enemyLabel:SetText("附近敌方")
  zone.enemyTotal = createFont(zone.enemyCol, 17, C.red, "", "number")
  zone.enemyTotal:SetPoint("TOPRIGHT", -5, -5)
  zone.enemyTotal:SetJustifyH("RIGHT")
  zone.enemyTotal:SetText("00")
  zone.enemyChips = CreateFrame("Frame", nil, zone.enemyCol)
  zone.enemyChips:SetPoint("TOPLEFT", 6, -30)
  zone.enemyChips:SetPoint("BOTTOMLEFT", 0, 3)
  zone.enemyEmpty = createFont(zone.enemyChips, 11, C.text3, "", "regular")
  zone.enemyEmpty:SetPoint("LEFT", 0, 0)
  zone.enemyEmpty:SetText("—")
  zone.enemyChips.empty = zone.enemyEmpty

  -- 友方列（右半）
  zone.friendCol = CreateFrame("Frame", nil, zone)
  zone.friendIcon = createIcon(zone.friendCol, "users", 11, C.blue)
  zone.friendIcon:SetPoint("TOPLEFT", 6, -7)
  zone.friendLabel = createFont(zone.friendCol, 11, C.text, "", "medium")
  zone.friendLabel:SetPoint("LEFT", zone.friendIcon, "RIGHT", 5, 0)
  zone.friendLabel:SetText("附近友方")
  zone.friendTotal = createFont(zone.friendCol, 17, C.blue, "", "number")
  zone.friendTotal:SetPoint("TOPRIGHT", -5, -5)
  zone.friendTotal:SetJustifyH("RIGHT")
  zone.friendTotal:SetText("01")
  zone.friendChips = CreateFrame("Frame", nil, zone.friendCol)
  zone.friendChips:SetPoint("TOPLEFT", 6, -24)
  zone.friendChips:SetPoint("BOTTOMLEFT", 0, 3)
  zone.friendEmpty = createFont(zone.friendChips, 11, C.text3, "", "regular")
  zone.friendEmpty:SetPoint("LEFT", 0, 0)
  zone.friendEmpty:SetText("—")
  zone.friendChips.empty = zone.friendEmpty

  -- chip 池（动态创建/销毁）
  zone.enemyChipPool = {}
  zone.friendChipPool = {}

  return zone
end

-- 芯片对象池：buildChip 创建空壳（仅一次），updateChip 填充职业数据，复用避免 CreateFrame 抖动。
local function buildChip(parent)
  local chip = CreateFrame("Frame", nil, parent)
  chip:SetSize(36, 20)
  chip.glyph = CreateFrame("Frame", nil, chip)
  chip.glyph:SetSize(16, 16)
  chip.glyph:SetPoint("LEFT", 0, 0)
  -- 4 条 1px 独立纹理边框：规避 Backdrop edge 亚像素采样导致的左右/上下不对称
  -- 用 SetColorTexture 纯色（非纹理文件），彻底规避方向性纹理采样，四边绝对均匀
  local function edge(w, h, p1, p2)
    local t = chip.glyph:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 1)
    if w then t:SetWidth(w) end
    if h then t:SetHeight(h) end
    t:SetPoint(p1[1], unpack(p1, 2))
    t:SetPoint(p2[1], unpack(p2, 2))
    return t
  end
  local E = {}
  chip.glyph.edges = E
  E.top    = edge(nil, 1, { "TOPLEFT" },    { "TOPRIGHT" })
  E.bottom = edge(nil, 1, { "BOTTOMLEFT" }, { "BOTTOMRIGHT" })
  E.left   = edge(1, nil, { "TOPLEFT" },    { "BOTTOMLEFT" })
  E.right  = edge(1, nil, { "TOPRIGHT" },   { "BOTTOMRIGHT" })
  chip.glyph.SetEdgeColor = function(_, r, g, b, a)
    E.top:SetVertexColor(r, g, b, a)
    E.bottom:SetVertexColor(r, g, b, a)
    E.left:SetVertexColor(r, g, b, a)
    E.right:SetVertexColor(r, g, b, a)
  end
  chip.glyph:SetEdgeColor(rgba(C.lineSoft))
  chip.glyph.char = createFont(chip.glyph, 10, C.text, "", "bold")
  chip.glyph.char:SetPoint("CENTER")
  chip.glyph.char:SetWidth(16)
  chip.glyph.char:SetJustifyH("CENTER")
  chip.count = createFont(chip, 10, C.text, "", "number")
  chip.count:SetPoint("LEFT", chip.glyph, "RIGHT", 8, 0)
  return chip
end

local function updateChip(chip, parent, classFile, count)
  local info = TN.classInfo[classFile]
  chip:SetParent(parent)
  -- 透明背景 + 职业色边框（4 条独立纹理，对称渲染）
  chip.glyph:SetEdgeColor(info.color[1], info.color[2], info.color[3], 1)
  chip.glyph.char:SetText(info.text)
  setColor(chip.glyph.char, info.color)
  chip.count:SetText(tostring(count))
  setColor(chip.count, info.color)
  chip.classFile = classFile
end

function TN:UpdateForceZone(stats)
  local zone = self.hud.forceZone
  if not zone then return end

  local chipPitch = 36 + 6
  local chipRowPitch = 20 + 4

  local colWidth = zone.enemyCol:GetWidth() or 138
  local chipsPerRow = math.max(1, math.floor((colWidth - 8) / chipPitch))

  -- 池化布局：复用已有芯片，仅在不足时新建，多余的隐藏
  local function layoutChips(pool, container, classCounts)
    local list = self:GetSortedClassCounts(classCounts)
    local n = #list
    if n > 0 then
      container.empty:Hide()
      for i = #pool + 1, n do
        pool[i] = buildChip(container)
      end
      for i, entry in ipairs(list) do
        local chip = pool[i]
        updateChip(chip, container, entry.classFile, entry.count)
        local row = math.floor((i - 1) / chipsPerRow)
        local col = (i - 1) % chipsPerRow
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", col * chipPitch, -(row * chipRowPitch))
        chip:Show()
      end
      for i = n + 1, #pool do
        pool[i]:Hide()
      end
      return math.ceil(n / chipsPerRow)
    else
      container.empty:Show()
      for i = 1, #pool do pool[i]:Hide() end
      return 0
    end
  end

  zone.enemyTotal:SetText(string.format("%02d", stats.enemyTotal or 0))
  local enemyRows = layoutChips(zone.enemyChipPool, zone.enemyChips, stats.enemyClassCounts)

  zone.friendTotal:SetText(string.format("%02d", stats.nearbyFriendlies or 0))
  local friendlyClassCounts = self:GetFriendlyClassCounts()
  local friendlyRows = layoutChips(zone.friendChipPool, zone.friendChips, friendlyClassCounts)

  -- 通报栏按钮始终可见
  setShown(zone.quickParty, true)
  setShown(zone.quickRaid, true)
  setShown(zone.quickGuild, true)
  setShown(zone.quickLocal, true)

  local announceH = 24 + 3   -- announceBar(24) + line + gap
  local colHeaderH = 24
  local maxRows = math.max(enemyRows, friendlyRows)
  local forceHeight = announceH + colHeaderH
  if maxRows > 0 then
    forceHeight = announceH + colHeaderH + maxRows * chipRowPitch + 4 + 6
  else
    forceHeight = announceH + colHeaderH + 14
  end

  zone:SetHeight(forceHeight)
  self.forceZoneHeight = forceHeight
end
