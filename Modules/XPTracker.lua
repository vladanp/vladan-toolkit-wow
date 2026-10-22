local _, VT = ...
local m = VT:NewModule("XPTracker", "XP tracker",
	"XP bar with XP per hour, projected level-up time, and kills/quests to level. Hover for details, drag to move, right-click to reset the session.")

local WINDOW = 900 -- XP/h covers the last 15 minutes, so breaks don't skew the projection for long
local W, BAR = 250, 10
-- "%s dies, you gain %d experience." -> pattern capturing the XP number (locale-safe).
local KILL_PATTERN = COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.", "%%."):gsub("%%s", ".+"):gsub("%%d", "(%%d+)")

local session, lastXP, lastMax

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

-- Panel ----------------------------------------------------------------------

local f = VT:CreateMovable("XPTracker", "TOP", 0, -60, "BackdropTemplate")
f:SetSize(W, 72)
VT:StylePanel(f)

local level = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
level:SetPoint("TOPLEFT", 8, -8)
local percent = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
percent:SetPoint("TOPRIGHT", -8, -8)

local rested = CreateFrame("StatusBar", nil, f) -- rested XP shows as a lighter band past current XP
rested:SetPoint("TOPLEFT", 8, -26)
rested:SetPoint("TOPRIGHT", -8, -26)
rested:SetHeight(BAR)
rested:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
rested:SetStatusBarColor(0.3, 0.55, 1, 0.45)
local track = rested:CreateTexture(nil, "BACKGROUND")
track:SetAllPoints()
track:SetColorTexture(0, 0, 0, 0.6)

local bar = CreateFrame("StatusBar", nil, rested)
bar:SetAllPoints()
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetStatusBarColor(0.62, 0.3, 0.95)
for i = 1, 9 do -- 10% ticks
	local tick = bar:CreateTexture(nil, "OVERLAY")
	tick:SetColorTexture(0, 0, 0, 0.7)
	tick:SetSize(1, BAR)
	tick:SetPoint("LEFT", (W - 16) * i / 10, 0)
end

local rate = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rate:SetPoint("TOPLEFT", 8, -42)
local eta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
eta:SetPoint("TOPRIGHT", -8, -42)
local extra = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
extra:SetPoint("TOPLEFT", 8, -57)
extra:SetTextColor(0.65, 0.65, 0.7)

local function Refresh()
	if not m:IsEnabled() or UnitLevel("player") >= GetMaxPlayerLevel() or UnitXPMax("player") == 0 then
		return f:Hide()
	end
	local s = Stats()
	level:SetText("Level " .. UnitLevel("player"))
	percent:SetText(("%.1f%%"):format(s.xp / s.max * 100)
		.. (s.rested > 0 and ("  |cff4d8cffrested %d%%|r"):format(s.rested / s.max * 100) or ""))
	rested:SetMinMaxValues(0, s.max)
	rested:SetValue(math.min(s.xp + s.rested, s.max))
	bar:SetMinMaxValues(0, s.max)
	bar:SetValue(s.xp)
	rate:SetText("|cffffd100" .. Short(s.rate) .. "|r XP/h")
	eta:SetText(s.eta and ("Level up in |cffffd100%s|r  (%s)"):format(Duration(s.eta), date("%H:%M", time() + s.eta))
		or "Level up in  —")
	local parts = { BreakUpLargeNumbers(s.left) .. " XP to go" }
	if s.kills then table.insert(parts, "~" .. s.kills .. " kills") end
	if s.quests then table.insert(parts, "~" .. s.quests .. " quests") end
	extra:SetText(table.concat(parts, "  ·  "))
	f:Show()
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
	Line("XP/hour (last 15 min)", BreakUpLargeNumbers(math.floor(s.rate)))
	Line("Projected level up", s.eta and (Duration(s.eta) .. ", around " .. date("%H:%M", time() + s.eta)) or "—")
	if s.kills then
		Line("Kills to level", ("%d  (last kill %s XP)"):format(s.kills, BreakUpLargeNumbers(session.killXP)))
	end
	if s.quests then
		Line("Quests to level", ("%d  (avg %s XP)"):format(s.quests, BreakUpLargeNumbers(math.floor(s.avgQuest))))
	end
	GameTooltip:AddLine(" ")
	Line("This session", ("+%s XP, %d level%s, %s"):format(BreakUpLargeNumbers(session.xp), session.levels,
		session.levels == 1 and "" or "s", Duration(GetTime() - session.start)))
	GameTooltip:AddLine("Drag to move  ·  Right-click to reset session", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)
f:SetScript("OnMouseUp", function(_, button)
	if button == "RightButton" then
		ResetSession()
		Refresh()
	end
end)

-- Tracking -------------------------------------------------------------------

m.OnToggle = function()
	lastXP, lastMax = UnitXP("player"), UnitXPMax("player") -- don't count XP earned while disabled
	Refresh()
end

m:On("PLAYER_XP_UPDATE", function()
	local xp, max = UnitXP("player"), UnitXPMax("player")
	local gain = lastXP and (xp >= lastXP and xp - lastXP or lastMax - lastXP + xp) or 0 -- wrapped = level up
	if gain > 0 then
		local now = GetTime()
		session.xp = session.xp + gain
		table.insert(session.gains, { now, gain })
		while now - session.gains[1][1] > WINDOW do
			table.remove(session.gains, 1)
		end
	end
	lastXP, lastMax = xp, max
	Refresh()
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

C_Timer.NewTicker(10, Refresh) -- keeps XP/h and the projection current while idle
