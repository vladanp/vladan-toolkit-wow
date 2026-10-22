local _, VT = ...
local m = VT:NewModule("XPTracker", "XP tracker",
	"XP card with XP per hour, projected level up time, and kills and quests to level. Hover for details, drag to move, right click to reset the session.")
m.section = "Leveling and buffs"

local WINDOW = 900 -- XP per hour covers the last 15 minutes, so breaks don't skew the projection for long
local W, BAR, PAD = 280, 10, 12
local EASE, SNAP = Enum.StatusBarInterpolation.ExponentialEaseOut, Enum.StatusBarInterpolation.Immediate
-- "%s dies, you gain %d experience." becomes a pattern that captures the XP number in any locale.
local KILL_PATTERN = COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.", "%%."):gsub("%%s", ".+"):gsub("%%d", "(%%d+)")
local GREY = "|cff8c8c8c%s|r"

local session, lastXP, lastMax, shownMax

local function ResetSession()
	session = { start = GetTime(), xp = 0, levels = 0, gains = {}, questXP = 0, quests = 0 }
end
ResetSession()

local function Short(n)
	return n >= 1000 and ("%.1fk"):format(n / 1000) or tostring(math.floor(n))
end

local function Duration(s)
	local h, min = math.floor(s / 3600), math.floor(s % 3600 / 60)
	return h > 0 and ("%dh %02dm"):format(h, min) or ("%dm"):format(math.max(min, 1))
end

local function Stats()
	local now, recent = GetTime(), 0
	for _, g in ipairs(session.gains) do
		if now - g[1] <= WINDOW then recent = recent + g[2] end
	end
	local s = { xp = UnitXP("player"), max = UnitXPMax("player"), rested = GetXPExhaustion() or 0 }
	s.left = s.max - s.xp
	s.rate = recent / math.max(math.min(WINDOW, now - session.start), 60) * 3600
	s.eta = s.rate > 0 and s.left / s.rate * 3600 or nil
	s.kills = session.killXP and math.ceil(s.left / session.killXP)
	s.avgQuest = session.quests > 0 and session.questXP / session.quests or nil
	s.quests = s.avgQuest and math.ceil(s.left / s.avgQuest)
	return s
end

-- Card: Forever's rounded tooltip panel and the game's own XP bar art.

local f = VT:CreateMovable("XPTracker", "TOP", 0, -60, "TooltipBackdropTemplate")
f:SetWidth(W)

local level = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
level:SetPoint("TOPLEFT", PAD, -PAD)
local percent = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
percent:SetPoint("TOPRIGHT", -PAD, -PAD)

local track = f:CreateTexture(nil, "ARTWORK")
track:SetAtlas("UI-HUD-ExperienceBar-Background")
track:SetPoint("TOPLEFT", PAD, -38)
track:SetPoint("TOPRIGHT", -PAD, -38)
track:SetHeight(BAR)

local function Bar(parent, atlas)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetAllPoints(track)
	b:SetStatusBarTexture(atlas)
	return b
end
local restedBar = Bar(f, "UI-HUD-ExperienceBar-Fill-Prediction") -- rested band past current XP, like the default bar
local bar = Bar(restedBar, "UI-HUD-ExperienceBar-Fill-Experience")

-- Floating "+245" that rises from the end of the fill on every gain.
local gain = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gain:SetTextColor(0.8, 0.65, 1)
gain:Hide()
local float = gain:CreateAnimationGroup()
local rise = float:CreateAnimation("Translation")
rise:SetOffset(0, 14)
rise:SetDuration(1.4)
rise:SetSmoothing("OUT")
local fade = float:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0)
fade:SetStartDelay(0.6)
fade:SetDuration(0.8)
float:SetScript("OnFinished", function() gain:Hide() end)

local function Stat(column, caption)
	local x = PAD + (column - 1) * (W - 2 * PAD) / 3
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	label:SetPoint("TOPLEFT", x, -60)
	label:SetText(caption)
	local value = f:CreateFontString(nil, "OVERLAY", "Game15Font_Shadow")
	value:SetPoint("TOPLEFT", x, -74)
	return value
end
local rate = Stat(1, "XP / HOUR")
local eta = Stat(2, "LEVEL UP IN")
local toGo = Stat(3, "XP TO GO")

local footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footer:SetPoint("TOPLEFT", PAD, -98)
footer:SetWidth(W - 2 * PAD)
footer:SetJustifyH("LEFT")
footer:SetTextColor(0.7, 0.7, 0.75)

local function Refresh()
	if not m:IsEnabled() or UnitLevel("player") >= GetMaxPlayerLevel() or UnitXPMax("player") == 0 then
		return f:Hide()
	end
	local s, lvl = Stats(), UnitLevel("player")
	level:SetText("Level " .. lvl)
	percent:SetText(("%.1f%%"):format(s.xp / s.max * 100))

	bar:SetStatusBarTexture(s.rested > 0 and "UI-HUD-ExperienceBar-Fill-Rested" or "UI-HUD-ExperienceBar-Fill-Experience")
	local motion = s.max == shownMax and EASE or SNAP -- snap after a level up instead of sliding backwards
	shownMax = s.max
	restedBar:SetMinMaxValues(0, s.max)
	restedBar:SetValue(math.min(s.xp + s.rested, s.max), motion)
	bar:SetMinMaxValues(0, s.max)
	bar:SetValue(s.xp, motion)

	rate:SetText(s.rate > 0 and Short(s.rate) or GREY:format("no XP yet"))
	eta:SetText(s.eta and Duration(s.eta) or GREY:format("unknown"))
	toGo:SetText(Short(s.left))

	local parts = {}
	if s.eta then table.insert(parts, ("Level %d around |cffffffff%s|r"):format(lvl + 1, date("%H:%M", time() + s.eta))) end
	if s.rested > 0 then table.insert(parts, ("|cff4d8cff%d%% rested|r"):format(s.rested / s.max * 100)) end
	if s.kills then table.insert(parts, "~" .. s.kills .. " kills") end
	if s.quests then table.insert(parts, "~" .. s.quests .. " quests") end
	footer:SetText(table.concat(parts, "   ·   "))
	f:SetHeight(#parts > 0 and 98 + footer:GetStringHeight() + PAD or 98)
	f:Show()
end

local function ShowGain(amount)
	gain:SetText("+" .. BreakUpLargeNumbers(amount))
	gain:ClearAllPoints()
	local x = bar:GetWidth() * UnitXP("player") / UnitXPMax("player")
	gain:SetPoint("BOTTOM", bar, "BOTTOMLEFT", math.min(math.max(x, 20), bar:GetWidth() - 20), BAR + 2)
	gain:Show()
	float:Restart()
end

f:SetScript("OnEnter", function(self)
	local s = Stats()
	local function Line(left, right) GameTooltip:AddDoubleLine(left, right, nil, nil, nil, 1, 1, 1) end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("XP tracker")
	Line("Experience", BreakUpLargeNumbers(s.xp) .. " / " .. BreakUpLargeNumbers(s.max))
	Line("To level", BreakUpLargeNumbers(s.left))
	if s.rested > 0 then
		Line("Rested", ("%s  (%d%% of a level)"):format(BreakUpLargeNumbers(s.rested), s.rested / s.max * 100))
	end
	Line("XP per hour (last 15 min)", BreakUpLargeNumbers(math.floor(s.rate)))
	Line("Projected level up", s.eta and (Duration(s.eta) .. ", around " .. date("%H:%M", time() + s.eta)) or "not enough data yet")
	if s.kills then
		Line("Kills to level", ("%d  (last kill %s XP)"):format(s.kills, BreakUpLargeNumbers(session.killXP)))
	end
	if s.quests then
		Line("Quests to level", ("%d  (average %s XP)"):format(s.quests, BreakUpLargeNumbers(math.floor(s.avgQuest))))
	end
	GameTooltip:AddLine(" ")
	Line("This session", ("+%s XP, %d level%s, %s"):format(BreakUpLargeNumbers(session.xp), session.levels,
		session.levels == 1 and "" or "s", Duration(GetTime() - session.start)))
	GameTooltip:AddLine("Drag to move   ·   Right click to reset the session", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)
f:SetScript("OnMouseUp", function(_, button)
	if button == "RightButton" then
		ResetSession()
		VT:Print("XP session reset.")
		Refresh()
	end
end)

-- Tracking

m.OnToggle = function()
	lastXP, lastMax = UnitXP("player"), UnitXPMax("player") -- don't count XP earned while disabled
	Refresh()
end

m:On("PLAYER_XP_UPDATE", function()
	local xp, max = UnitXP("player"), UnitXPMax("player")
	local amount = lastXP and (xp >= lastXP and xp - lastXP or lastMax - lastXP + xp) or 0 -- wrapped means level up
	lastXP, lastMax = xp, max
	if amount > 0 then
		local now = GetTime()
		session.xp = session.xp + amount
		table.insert(session.gains, { now, amount })
		while now - session.gains[1][1] > WINDOW do
			table.remove(session.gains, 1)
		end
	end
	Refresh()
	if amount > 0 and f:IsShown() then ShowGain(amount) end
end)

m:On("PLAYER_LEVEL_UP", function()
	session.levels = session.levels + 1
end)

m:On("QUEST_TURNED_IN", function(_, xpReward)
	if xpReward and xpReward > 0 then
		session.questXP = session.questXP + xpReward
		session.quests = session.quests + 1
		Refresh()
	end
end)

m:On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
	if issecretvalue(msg) then return end
	session.killXP = tonumber(msg:match(KILL_PATTERN)) or session.killXP
	Refresh()
end)

C_Timer.NewTicker(10, Refresh) -- keeps XP per hour and the projection current while idle
