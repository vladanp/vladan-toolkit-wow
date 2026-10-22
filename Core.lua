local addonName, VT = ...
VT.modules = {}
VT.commands = {} -- "/vt <name> <args>" calls VT.commands.<name>(args)

local handlers = {} -- event name to a list of { module, fn }
local frame = CreateFrame("Frame")
local category

-- Replies to commands; always shown.
function VT:Print(...)
	print("|cff33ff99Vladan Toolkit:|r", ...)
end

-- Automatic messages (sold junk, repairs, alerts); the "Chat messages" setting can turn these off.
function VT:Notify(...)
	if VladanToolkitDB.ChatMessages then VT:Print(...) end
end

-- Slider label formats.
VT.format = {
	percent = function(v) return ("%d%%"):format(v * 100 + 0.5) end, -- for 0 to 1 values
	percent100 = function(v) return v .. "%" end, -- for 0 to 100 values
	minutes = function(v) return v .. " min" end,
	seconds = function(v) return v .. " sec" end,
	pixels = function(v) return v .. " px" end,
}

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

-- An extra setting shown indented under the module's checkbox, greyed out while the module is off.
-- { key, title, desc, default, onChange }: a boolean default makes a checkbox, a number default a
-- slider (also min, max, step, format). { title, button, desc, onClick } makes a button.
function Module:Option(o)
	table.insert(self.options, o)
end

function Module:Get(key)
	return VladanToolkitDB[self.key .. key]
end

function VT:NewModule(key, title, desc, default)
	local m = setmetatable({ key = key, title = title, desc = desc, default = default ~= false, options = {} }, Module)
	table.insert(self.modules, m)
	return m
end

-- Hidden, draggable frame whose position is saved per key (restored in Init).
local movables = {}

local function Place(key, f)
	local pos = VladanToolkitDB[key .. "Pos"] or f.home
	f:ClearAllPoints()
	f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

-- Frames holding secure buttons (click to cast) can't be moved or scaled in combat.
local function Locked(f)
	return InCombatLockdown() and f:IsProtected()
end

function VT:CreateMovable(key, point, x, y, template)
	local f = CreateFrame("Frame", nil, UIParent, template)
	f.home = { point, point, x, y }
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if not VladanToolkitDB.LockFrames then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, px, py = self:GetPoint()
		VladanToolkitDB[key .. "Pos"] = { p, rp, px, py }
	end)
	f:SetPoint(point, x, y)
	f:Hide()
	movables[key] = f
	return f
end

local function ApplyScale()
	for _, f in pairs(movables) do
		if not Locked(f) then f:SetScale(VladanToolkitDB.FrameScale) end
	end
end

local function ResetPositions()
	for key, f in pairs(movables) do
		if not Locked(f) then
			VladanToolkitDB[key .. "Pos"] = nil
			Place(key, f)
		end
	end
	VT:Print("Windows moved back to their starting spots.")
end

-- Settings on the main page.
local GENERAL = {
	{ key = "LockFrames", title = "Lock windows", default = false,
		desc = "Stops the XP card, buff reminder and LFG window from being dragged." },
	{ key = "ChatMessages", title = "Chat messages", default = true,
		desc = "Show automatic toolkit messages in chat, like what was sold, repair costs and LFG alerts." },
	{ key = "FrameScale", title = "Window scale", default = 1, min = 0.6, max = 1.6, step = 0.05,
		format = VT.format.percent, onChange = ApplyScale,
		desc = "Size of all toolkit windows: the XP card, buff reminder and LFG window." },
	{ title = "Window positions", button = "Reset", onClick = ResetPositions,
		desc = "Moves all toolkit windows back to where they started." },
}

-- Registers one setting (checkbox, slider or button) on a settings page and returns its initializer.
local function AddSetting(page, layout, dbKey, o)
	if o.onClick then
		local init = CreateSettingsButtonInitializer(o.title, o.button, o.onClick, o.desc, true)
		layout:AddInitializer(init)
		return init
	end
	if VladanToolkitDB[dbKey] == nil then
		VladanToolkitDB[dbKey] = o.default
	end
	local variable = addonName .. "_" .. dbKey
	local isNumber = type(o.default) == "number"
	local setting = Settings.RegisterAddOnSetting(page, variable, dbKey, VladanToolkitDB,
		isNumber and Settings.VarType.Number or Settings.VarType.Boolean, o.title, o.default)
	local init
	if isNumber then
		local slider = Settings.CreateSliderOptions(o.min, o.max, o.step)
		slider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, o.format)
		init = Settings.CreateSlider(page, setting, slider, o.desc)
	else
		init = Settings.CreateCheckbox(page, setting, o.desc)
	end
	if o.onChange then
		Settings.SetOnValueChangedCallback(variable, function(_, value) o.onChange(value) end)
	end
	return init
end

local function Init()
	VladanToolkitDB = VladanToolkitDB or {}
	VladanToolkitCharDB = VladanToolkitCharDB or {}

	-- Main page: general settings. Each module section gets its own page in the sidebar.
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory("Vladan Toolkit")
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"))
	for _, o in ipairs(GENERAL) do
		AddSetting(category, layout, o.key, o)
	end

	local pages = {}
	for _, m in ipairs(VT.modules) do
		local section = m.section or "Other"
		pages[section] = pages[section] or { Settings.RegisterVerticalLayoutSubcategory(category, section) }
		local page, pageLayout = pages[section][1], pages[section][2]
		local toggle = AddSetting(page, pageLayout, m.key, { title = m.title, desc = m.desc, default = m.default,
			onChange = m.OnToggle and function(value) m:OnToggle(value) end })
		for _, o in ipairs(m.options) do
			local init = AddSetting(page, pageLayout, o.key and m.key .. o.key, o)
			init:SetParentInitializer(toggle, function() return m:IsEnabled() end)
		end
	end
	Settings.RegisterAddOnCategory(category)

	for key, f in pairs(movables) do
		Place(key, f)
	end
	ApplyScale()
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
