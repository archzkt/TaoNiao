--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/Stat.lua
-- HUD 统计单元：4 个数据格 + 危险指数徽章（含打分构成 tooltip）。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local Widgets = TN.Widgets
local applyRoundedCorners = Widgets.applyRoundedCorners
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local Layout = Theme.Layout
local HUD_STAT_TOP = Layout.HUD_STAT_TOP
local HUD_STAT_HEIGHT = Layout.HUD_STAT_HEIGHT

function TN:ThreatTone(pct)
  return Theme.threatTone(pct)
end

function TN:CreateStat(parent, index, icon, label, key)
  local w = 62
  local cell = CreateFrame("Button", nil, parent)
  cell:SetSize(w, HUD_STAT_HEIGHT)
  cell:SetPoint("TOPLEFT", 12 + (index - 1) * (w + 6), HUD_STAT_TOP)
  local col = Theme.STAT_COLOR[key] or C.cyan

  if key == "threat" then
    -- 危险指数：圆角徽章，仅居中显示状态文字，无图标/标题
    cell.rc = applyRoundedCorners(cell, 4, C.cell)
    cell.value = createFont(cell, 14, col, "", "badge")
    cell.value:SetPoint("CENTER", 0, 0)
    cell.value:SetJustifyH("CENTER")
    cell:SetScript("OnEnter", function(self)
      for _, tex in pairs(self.rc) do tex:SetVertexColor(rgba(C.cellHi)) end
      local stats = TN:GetStats()
      local b = stats.threatBreakdown
      if b then
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local tone = TN:ThreatTone(stats.threat)
        GameTooltip:SetText(("危险指数 %d  %s"):format(stats.threat, tone), C.cyan[1], C.cyan[2], C.cyan[3], C.cyan[4], true)
        GameTooltip:AddLine(("活跃敌方：%d"):format(b.enemies), 0.92, 0.95, 0.97)
        GameTooltip:AddLine(("附近队友：%d  附近散人：%d"):format(b.nearbyMates, b.nearbyFriendlies), 0.62, 0.70, 0.76)
        GameTooltip:AddLine(("友方缓释：%.0f%%"):format((1 - b.mitigation) * 100), 0.62, 0.70, 0.76)
        if b.counter then
          local info = TN.classInfo[b.counter]
          GameTooltip:AddLine(("硬克制（%s）：+30%%"):format(info and info.name or b.counter), 1.0, 0.54, 0.24)
        end
        if b.guild then
          GameTooltip:AddLine(("敌对公会（%s）：总战绩加权"):format(b.guild), 1.0, 0.78, 0.24)
        end
        if stats.high > 0 then
          GameTooltip:AddLine(("死刑命中：%d"):format(stats.high), 1.0, 0.30, 0.31)
        end
        GameTooltip:Show()
      end
    end)
    cell:SetScript("OnLeave", function(self)
      for _, tex in pairs(self.rc) do tex:SetVertexColor(rgba(C.cell)) end
      GameTooltip:Hide()
    end)
  else
    cell.rc = applyRoundedCorners(cell, 4, C.cell)
    cell.icon = createIcon(cell, icon, 11, col)
    cell.icon:SetPoint("TOPLEFT", 4, -8)
    cell.label = createFont(cell, 11, C.text2, "", "medium")
    cell.label:SetPoint("TOPLEFT", 18, -8)
    cell.label:SetWidth(w - 15)
    cell.label:SetText(label)
    cell.value = createFont(cell, 18, col, "", "number")
    cell.value:SetPoint("BOTTOM", 0, 3)
    cell.value:SetJustifyH("CENTER")
    cell:SetScript("OnEnter", function(self)
      for _, tex in pairs(self.rc) do tex:SetVertexColor(rgba(C.cellHi)) end
    end)
    cell:SetScript("OnLeave", function(self)
      for _, tex in pairs(self.rc) do tex:SetVertexColor(rgba(C.cell)) end
    end)
  end

  cell.index = index
  cell.key = key
  return cell
end
