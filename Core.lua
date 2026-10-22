local addonName, VT = ...
VT.modules = {}
VT.commands = {} -- "/vt <name> <args>" -> fn(args)

local handlers = {} -- event -> { { module, fn }, ... }
local frame = CreateFrame("Frame")
local category

function VT:Print(...)
	print("|cff33ff99Vladan Toolkit:|r", ...)
end

local Module = {}
Module.__index = Module

function Module:IsEnabled()
	return VladanToolkitDB ~= nil and VladanToolkitDB[self.key] == true
end

-- Handlers only run while the module is ticked in /vt, so toggles apply instantly.
-- Modules that show UI also define m:OnToggle(enabled) to show/hide it.
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

-- Draggable one-line text display; its position is saved per key (restored in Init).
local textFrames = {}
function VT:CreateTextFrame(key, point, x, y)
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(220, 20)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.text:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, px, py = self:GetPoint()
		VladanToolkitDB[key .. "Pos"] = { p, rp, px, py }
	end)
	f:SetPoint(point, x, y)
	f:Hide()
	textFrames[key] = f
	return f
end

local function Init()
	VladanToolkitDB = VladanToolkitDB or {}
	VladanToolkitCharDB = VladanToolkitCharDB or {}
	for key, f in pairs(textFrames) do
		local pos = VladanToolkitDB[key .. "Pos"]
		if pos then
			f:ClearAllPoints()
			f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
		end
	end
	category = Settings.RegisterVerticalLayoutCategory("Vladan Toolkit")
	for _, m in ipairs(VT.modules) do
		if VladanToolkitDB[m.key] == nil then
			VladanToolkitDB[m.key] = m.default
		end
		local variable = addonName .. "_" .. m.key
		local setting = Settings.RegisterAddOnSetting(category, variable, m.key,
			VladanToolkitDB, Settings.VarType.Boolean, m.title, m.default)
		Settings.CreateCheckbox(category, setting, m.desc)
		if m.OnToggle then
			Settings.SetOnValueChangedCallback(variable, function(_, value) m:OnToggle(value) end)
		end
	end
	Settings.RegisterAddOnCategory(category)
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == addonName then
		Init()
	elseif event == "PLAYER_LOGIN" then
		for _, m in ipairs(VT.modules) do
			if m.OnToggle then m:OnToggle(m:IsEnabled()) end
		end
	end
	for _, h in ipairs(handlers[event] or {}) do
		if h.module:IsEnabled() then
			h.fn(...)
		end
	end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

function VladanToolkit_Open()
	Settings.OpenToCategory(category:GetID())
end

SLASH_VLADANTOOLKIT1 = "/vt"
SlashCmdList.VLADANTOOLKIT = function(msg)
	local cmd, args = msg:match("^(%S*)%s*(.-)%s*$")
	if VT.commands[cmd:lower()] then
		VT.commands[cmd:lower()](args)
	else
		VladanToolkit_Open()
	end
end
