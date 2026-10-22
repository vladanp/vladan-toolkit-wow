local addonName, VT = ...
VT.modules = {}

local handlers = {} -- event -> { { module, fn }, ... }
local frame = CreateFrame("Frame")
local category

local Module = {}
Module.__index = Module

-- Handlers only run while the module is ticked in /vt, so toggles apply instantly.
function Module:On(event, fn)
	handlers[event] = handlers[event] or {}
	table.insert(handlers[event], { module = self, fn = fn })
	frame:RegisterEvent(event)
end

function VT:NewModule(key, title, desc, default)
	local m = setmetatable({ key = key, title = title, desc = desc, default = default ~= false }, Module)
	table.insert(self.modules, m)
	return m
end

local function Init()
	VladanToolkitDB = VladanToolkitDB or {}
	category = Settings.RegisterVerticalLayoutCategory("Vladan Toolkit")
	for _, m in ipairs(VT.modules) do
		if VladanToolkitDB[m.key] == nil then
			VladanToolkitDB[m.key] = m.default
		end
		local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. m.key, m.key,
			VladanToolkitDB, Settings.VarType.Boolean, m.title, m.default)
		Settings.CreateCheckbox(category, setting, m.desc)
	end
	Settings.RegisterAddOnCategory(category)
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == addonName then
		Init()
	end
	for _, h in ipairs(handlers[event] or {}) do
		if VladanToolkitDB and VladanToolkitDB[h.module.key] then
			h.fn(...)
		end
	end
end)
frame:RegisterEvent("ADDON_LOADED")

function VladanToolkit_Open()
	Settings.OpenToCategory(category:GetID())
end

SLASH_VLADANTOOLKIT1 = "/vt"
SlashCmdList.VLADANTOOLKIT = VladanToolkit_Open
