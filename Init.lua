--[[ TaoNiao - 掏鸟开放世界PVP助手 ]]
-- 魔兽世界永久60 · 哈霍兰 · 華公子
-- Copyright (c) 2024-2025 wwzkt <1029071011@qq.com>

-- 唯一的 AceAddon 实例创建点。所有模块文件引用全局 TaoNiao（别名 TN）追加方法/数据。
-- 加载顺序由 TaoNiao.toc 严格控制：libs → Init → Config → Core → UI

local ADDON_NAME = ...

local AceAddon = LibStub("AceAddon-3.0")

-- 创建插件对象，混入 Console/Event/Timer 能力
TaoNiao = AceAddon:NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local TN = TaoNiao

-- 版本/元信息
TN.version = "0.3.0"
TN.addonName = ADDON_NAME
