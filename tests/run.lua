-- Offline checks: loads the real addon files with small WoW stubs. From the repo root:
--   npx -y -p fengari-node-cli@0.1.0 fengari tests/run.lua
-- fengari runs Lua 5.3 (the game runs 5.1), so this covers logic, not every game quirk.

local now, tickers, timers, errors, failed = 1000, {}, {}, {}, 0

local function Check(label, ok)
	if not ok then failed = failed + 1 end
	print((ok and "ok    " or "FAIL  ") .. label)
end

local function Advance(seconds) -- moves the clock, firing tickers on the way
	local target = now + seconds
	while true do
		local due
		for _, t in ipairs(tickers) do
			if t.due <= target and (not due or t.due < due.due) then due = t end
		end
		if not due then break end
		now, due.due = due.due, due.due + due.interval
		due.fn()
	end
	now = target
end

local function Upvalue(fn, name)
	for i = 1, 255 do
		local n, v = debug.getupvalue(fn, i)
		if n == nil then return end
		if n == name then return v end
	end
end

-- Widgets: any Capitalized method works and returns the widget; Create* returns a new widget.
local function Widget()
	local w = { shown = false, scripts = {} }
	return setmetatable(w, { __index = function(_, k)
		if not k:find("^%u") then return nil end
		if k == "Instructions" then local i = Widget(); rawset(w, k, i); return i end
		if k:find("^Create") then return Widget end
		if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
		if k == "Hide" then return function(self) self.shown = false end end
		if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
		if k == "IsShown" then return function(self) return self.shown end end
		if k == "SetScript" or k == "HookScript" then return function(self, s, fn) self.scripts[s] = fn end end
		if k == "SetText" then return function(self, v) self.text = v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end end
		if k == "GetText" then return function(self) return self.text or "" end end
		if k == "GetStringWidth" or k == "GetStringHeight" or k == "GetWidth" then return function() return 100 end end
		if k == "IsProtected" or k == "IsMouseOver" or k == "GetChildren" or k == "GetPoint" then return function() end end
		return function(self) return self end
	end })
end

-- Game stubs
GetTime = function() return now end
time = function() return 1700000000 end
date = function() return "12:00" end
securecallfunction = function(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then table.insert(errors, err) end
end
CreateFrame = function() return Widget() end
UIParent, Minimap, MinimapCluster = Widget(), Widget(), Widget()
Minimap.ZoomIn, Minimap.ZoomOut = Widget(), Widget()
MinimapCompassTexture, MinimapCompassTextureUnderlay, GameTimeFrame, AddonCompartmentFrame = Widget(), Widget(), Widget(), Widget()
MinimapCluster.Tracking = Widget()
local roundRestored = 0
MinimapCluster.UpdateMinimapConfig = function() roundRestored = roundRestored + 1 end
UISpecialFrames, SlashCmdList = {}, {}
InCombatLockdown = function() return false end
hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); fn(...) end end
C_Timer = {
	NewTicker = function(interval, fn) table.insert(tickers, { interval = interval, fn = fn, due = now + interval }) end,
	NewTimer = function() return { Cancel = function() end } end,
	After = function(_, fn) table.insert(timers, fn) end,
}
GameTooltip, GameTooltip_Hide = Widget(), function() end
issecretvalue = function() return false end
Enum = { StatusBarInterpolation = {}, TooltipDataType = {} }
COMBATLOG_XPGAIN_FIRSTPERSON, ITEM_LEVEL = "%s dies, you gain %d experience.", "Item Level %d"
TooltipDataProcessor = { AddTooltipPostCall = function() end }
ChatFrameUtil = { AddMessageEventFilter = function() end }
LinkUtil = { RegisterLinkHandler = function() end }
SOUNDKIT = {}
PlaySound, BreakUpLargeNumbers, Screenshot = function() end, tostring, function() end
Ambiguate = function(s) return (s:gsub("%-.*", "")) end
UnitName = function() return "Me" end
GetPlayerInfoByGUID = function() end
local xp, xpMax = 900, 1000
UnitXP, UnitXPMax = function() return xp end, function() return xpMax end
UnitLevel, GetMaxPlayerLevel, GetXPExhaustion = function() return 10 end, function() return 60 end, function() return 0 end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitAffectingCombat, UnitIsDeadOrGhost = function() return false end, function() return false end
GetInventoryItemDurability = function() end
local bagCount = 3
C_Item = { GetItemCount = function() return bagCount end, GetItemNameByID = function() return "Water" end }
LE_GAME_ERR_OUT_OF_RAGE = 10
local errorShown = {}
UIErrorsFrame = { SetMessageTypeEnabled = function(_, t, on) if t then errorShown[t] = on end end } -- Blizzard ignores nil too
local looted = 0
GetNumLootItems, LootSlot = function() return 2 end, function() looted = looted + 1 end

-- Settings: Blizzard saves missing defaults, and after a change calls back with (owner, setting, value).
local settings = {}
MinimalSliderWithSteppersMixin = { Label = {} }
local function Initializer() return { SetParentInitializer = function() end } end
local function Layout() return { AddInitializer = function() end } end
Settings = {
	VarType = {},
	RegisterVerticalLayoutCategory = function() return { GetID = function() end }, Layout() end,
	RegisterVerticalLayoutSubcategory = function() return {}, Layout() end,
	RegisterAddOnSetting = function(_, variable, key, tbl, _, _, default)
		if tbl[key] == nil then tbl[key] = default end
		settings[key] = { tbl = tbl }
		return settings[key]
	end,
	CreateCheckbox = Initializer,
	CreateSlider = Initializer,
	CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
	SetOnValueChangedCallback = function(variable, fn) settings[variable:gsub("^VladanToolkit_", "")].callback = fn end,
	RegisterAddOnCategory = function() end,
}
CreateSettingsListSectionHeaderInitializer, CreateSettingsButtonInitializer = Initializer, Initializer
local function Click(key, value)
	local s = settings[key]
	s.tbl[key] = value
	if s.callback then s.callback(1, s, value) end
end

-- Load the addon in TOC order
local VT, events = {}, nil
for line in ([[Core.lua
Modules/FastLoot.lua Modules/Merchant.lua Modules/AutoBuy.lua Modules/XPTracker.lua Modules/OpenMail.lua
Modules/LowSupplies.lua Modules/BuffReminder.lua Modules/Screenshots.lua Modules/ChatLinks.lua Modules/LFGScanner.lua
Modules/Minimap.lua Modules/ErrorFilter.lua Modules/TooltipExtras.lua]]):gmatch("%S+") do
	local chunk = assert(loadfile(line))
	local created = CreateFrame
	if line == "Core.lua" then CreateFrame = function() events = Widget(); CreateFrame = created; return events end end
	chunk("VladanToolkit", VT)
end
local function Fire(event, ...) events.scripts.OnEvent(events, event, ...) end
local handlers = Upvalue(events.scripts.OnEvent, "handlers")
VladanToolkitDB = { SquareMinimap = true }
Fire("ADDON_LOADED", "VladanToolkit")
Fire("PLAYER_LOGIN")

-- Settings reach modules as true/false
local restored = roundRestored
Click("SquareMinimap", false)
Check("unticking Square minimap restores the round minimap", roundRestored > restored)
VladanToolkitLFGFrame:Show()
Click("LFGScanner", false)
Check("unticking the LFG scanner closes its window", not VladanToolkitLFGFrame:IsShown())
Click("LFGScanner", true)
VladanToolkitLFGFrame:Hide()
Check("error filter hides rage errors by default", errorShown[LE_GAME_ERR_OUT_OF_RAGE] == false)
Click("ErrorFilterResources", false)
Check("an option change applies at once", errorShown[LE_GAME_ERR_OUT_OF_RAGE] == true)

-- LFG: which posts count, and old posts drop while the window is closed
local chat = handlers.CHAT_MSG_CHANNEL[1].fn
local posts = Upvalue(chat, "posts")
local dungeons = Upvalue(Upvalue(chat, "Dungeon"), "DUNGEONS")
local cases = {
	{ "LFM SM cath need healer", "Scarlet Monastery" },
	{ "need heals for lbrs", "Lower Blackrock Spire" },
	{ "LFG BRD dps", "Blackrock Depths" },
	{ "LF2M any dungeon", "Other" },
	{ "<Iron Wolves> is LF more members, all welcome", nil },
	{ "LF enchanter for crusader", nil },
	{ "lf blacksmith, need arm repair", nil },
	{ "WTS ony head", nil },
}
for i, c in ipairs(cases) do
	chat(c[1], "Case" .. i .. "-Realm")
	local p = posts["Case" .. i .. "-Realm"]
	local got = p and (p.dungeon and dungeons[p.dungeon][1] or "Other")
	Check(("LFG %q -> %s"):format(c[1], tostring(c[2])), got == c[2])
end
for i = 1, 2400 do -- 2 hours in a capital, a new poster every 3 seconds
	Advance(3)
	chat("LFM SM need tank", "Player" .. i .. "-Realm")
end
local kept = 0
for _ in pairs(posts) do kept = kept + 1 end
Check(("LFG keeps only recent posts while closed (%d kept)"):format(kept), kept <= 15 * 60 / 3 + 5)

-- XP: a level up in one gain counts the XP across both levels
local onXP = handlers.PLAYER_XP_UPDATE[1].fn
Upvalue(onXP, "session").xp = 0
xp, xpMax = 100, 1200
Fire("PLAYER_XP_UPDATE", "player")
Check("XP across a level up counts 200", Upvalue(onXP, "session").xp == 200)

-- Auto buy: /vt buy parsing and stack math
SlashCmdList.VLADANTOOLKIT("buy 159 50")
Check("/vt buy 159 50 saves the item", VladanToolkitCharDB.buy[159] == 50)
SlashCmdList.VLADANTOOLKIT("buy 159")
Check("/vt buy without a count changes nothing", VladanToolkitCharDB.buy[159] == 50)
local bought = {}
GetMerchantNumItems, GetMerchantItemID, GetMerchantItemMaxStack = function() return 1 end, function() return 159 end, function() return 20 end
BuyMerchantItem = function(_, n) table.insert(bought, n) end
C_MerchantFrame = {
	GetItemInfo = function() return { isPurchasable = true, hasExtendedCost = false, stackCount = 5, name = "Water" } end,
	GetNumJunkItems = function() error("junk API changed") end,
}
CanMerchantRepair = function() return false end
local before = #errors
Fire("MERCHANT_SHOW")
Check("auto buy tops 3 up to 50 in stacks of 5, at most 20 per buy", table.concat(bought, ",") == "20,20,10")
Check("a failing module (sell junk) does not stop the others", #errors == before + 1)
SlashCmdList.VLADANTOOLKIT("buy |cffffffff|Hitem:159::::::::|h[Water]|h|r 0")
Check("/vt buy <link> 0 removes the item", VladanToolkitCharDB.buy[159] == nil)

-- Fast loot follows the game's own auto loot decision
Fire("LOOT_READY", false)
Check("fast loot leaves manual loot alone", looted == 0)
Fire("LOOT_READY", true)
Fire("LOOT_READY", true)
Check("fast loot takes every slot once", looted == 2)

-- Screenshots
local shots = #timers
Fire("PLAYER_LEVEL_UP", 11)
Fire("ENCOUNTER_END", 1, "Boss", 1, 5, 0)
Check("screenshot on level up, none on a wipe", #timers == shots + 1 and timers[#timers] == Screenshot)
Fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
Check("screenshot on a boss kill", #timers == shots + 2)
Click("ScreenshotsBossKill", false)
Fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
Check("no boss screenshot when that option is off", #timers == shots + 2)

Check("no unexpected Lua errors", #errors == before + 1)
for _, e in ipairs(errors) do print("      error: " .. tostring(e)) end
if failed > 0 then error(failed .. " check(s) failed") end
print("all checks passed")
