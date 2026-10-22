local _, VT = ...
local m = VT:NewModule("XPTracker", "XP tracker",
	"Shows XP per hour, time to level and kills to level (this session). Drag to move.")

local f = VT:CreateTextFrame("XPTracker", "TOP", 0, -60)
local start, gained, lastXP, lastMax, killXP = GetTime(), 0, nil, nil, nil
-- "%s dies, you gain %d experience." -> pattern capturing the XP number (locale-safe).
local KILL_PATTERN = COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.", "%%."):gsub("%%s", ".+"):gsub("%%d", "(%%d+)")

local function Refresh()
	if not m:IsEnabled() or UnitLevel("player") >= GetMaxPlayerLevel() then
		return f:Hide()
	end
	local xp, max = UnitXP("player"), UnitXPMax("player")
	if lastXP then
		gained = gained + (xp >= lastXP and xp - lastXP or lastMax - lastXP + xp) -- wrapped = level up
	end
	lastXP, lastMax = xp, max
	local perHour = gained / math.max(GetTime() - start, 1) * 3600
	local left = max - xp
	local parts = { ("%.1fk XP/h"):format(perHour / 1000) }
	if perHour > 0 then
		table.insert(parts, "level in " .. SecondsToTime(left / perHour * 3600, true))
	end
	if killXP then
		table.insert(parts, math.ceil(left / killXP) .. " kills")
	end
	f.text:SetText(table.concat(parts, "  |  "))
	f:Show()
end

m.OnToggle = Refresh
m:On("PLAYER_XP_UPDATE", Refresh)
m:On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
	if issecretvalue(msg) then return end
	killXP = tonumber(msg:match(KILL_PATTERN)) or killXP
	Refresh()
end)
C_Timer.NewTicker(10, Refresh) -- keeps XP/h honest while idle
