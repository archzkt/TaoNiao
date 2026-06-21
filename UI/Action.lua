--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- UI/Action.lua
-- HUD 操作按钮：通报/位面/团队/设置（C.cell 底 + hover 青色）。
-- 从 UI.lua 原样迁入（行为不变）。

local TN = TaoNiao
local Theme = TN.Theme
local C = Theme.C
local rgba = Theme.rgba
local setColor = Theme.setColor
local Widgets = TN.Widgets
local createTexture = Widgets.createTexture
local createIcon = Widgets.createIcon
local createFont = Widgets.createFont
local HUD_ACTION_TOP = Theme.Layout.HUD_ACTION_TOP

function TN:CreateAction(parent, index, icon, label, onClick, tooltip)
  local w = 75
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(w, 28)
  btn:SetPoint("TOPLEFT", 12 + (index - 1) * (w + 6), HUD_ACTION_TOP)
  btn.bg = createTexture(btn, "BACKGROUND", C.cell)
  btn.bg:SetAllPoints()
  btn.icon = createIcon(btn, icon, 13, C.cyan)
  btn.icon:SetPoint("LEFT", 11, 0)
  btn.text = createFont(btn, 12, C.text, "", "medium")
  btn.text:SetPoint("LEFT", 30, 0)
  btn.text:SetText(label)
  btn.index = index
  btn:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(0.20, 0.78, 0.91, 0.12)
    self.icon:SetVertexColor(rgba(C.cyan))
    setColor(self.text, C.cyan)
    local tip = self._tooltip or tooltip
    if tip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(tip, rgba(C.cyan))
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(rgba(C.cell))
    self.icon:SetVertexColor(rgba(C.cyan))
    setColor(self.text, C.text)
    if self._tooltip or tooltip then GameTooltip:Hide() end
  end)
  btn:SetScript("OnClick", onClick)
  return btn
end
