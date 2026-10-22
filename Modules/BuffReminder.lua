local _, VT = ...
local m = VT:NewModule("BuffReminder", "Missing buff reminder",
	"Out of combat, shows pulsing icons for your class buffs that are missing. Click an icon to cast it on yourself, drag the title to move.")
m.section = "Leveling and buffs"

-- Each group is satisfied by any buff in it (so a raid version or another player's cast counts).
-- ponytail: English spell names (enUS client), and only the spells you know are suggested.
-- Rogue poisons / shaman weapon buffs aren't checked yet.
local BUFFS = {
	MAGE = { { "Arcane Intellect", "Arcane Brilliance" }, { "Mage Armor", "Ice Armor", "Frost Armor" } },
	PRIEST = { { "Power Word: Fortitude", "Prayer of Fortitude" }, { "Inner Fire" } },
	DRUID = { { "Mark of the Wild", "Gift of the Wild" } },
	WARLOCK = { { "Demon Armor", "Demon Skin" } },
	SHAMAN = { { "Lightning Shield" } },
	HUNTER = { { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack",
		"Aspect of the Wild", "Aspect of the Beast" } },
	PALADIN = { { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation",
		"Blessing of Light", "Blessing of Sanctuary", "Greater Blessing of Might", "Greater Blessing of Wisdom",
		"Greater Blessing of Kings", "Greater Blessing of Salvation", "Greater Blessing of Light",
		"Greater Blessing of Sanctuary" } },
}

local SIZE, GAP = 40, 16

local f = VT:CreateMovable("BuffReminder", "CENTER", 0, 180)
f:SetHeight(SIZE + 44)
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOP")
title:SetText("MISSING BUFFS")

local icons = {}

local function Icon(i)
	if icons[i] then return icons[i] end
	-- Secure button so a click casts the buff. Secure frames can't be changed in combat,
	-- which is fine because the reminder only updates out of combat.
	local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown") -- fires on press or release, whichever the ActionButtonUseKeyDown setting picks
	b:SetAttribute("type", "spell")
	b:SetAttribute("unit", "player")
	b:SetSize(SIZE, SIZE)
	b:SetPoint("TOPLEFT", (i - 1) * (SIZE + GAP), -16)

	local glow = b:CreateTexture(nil, "BACKGROUND") -- red frame that pulses
	glow:SetPoint("TOPLEFT", -2, 2)
	glow:SetPoint("BOTTOMRIGHT", 2, -2)
	glow:SetColorTexture(1, 0.2, 0.1)
	local pulse = glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.2)
	fade:SetDuration(0.7)
	fade:SetSmoothing("IN_OUT")
	pulse:Play()

	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -4)
	b.label:SetWidth(SIZE + GAP)

	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetSpellByID(self.spellID)
		GameTooltip:AddLine("Click to cast on yourself", 0.3, 1, 0.3)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	icons[i] = b
	return b
end

local function Refresh()
	-- Secure icons are locked in combat (the frame is already hidden then), and auras can be secret in combat.
	if InCombatLockdown() then return end
	if not m:IsEnabled() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then
		return f:Hide()
	end
	local missing = {}
	for _, group in ipairs(BUFFS[select(2, UnitClass("player"))] or {}) do
		local known, active
		for _, name in ipairs(group) do
			local info = not known and C_Spell.GetSpellInfo(name)
			if info and C_SpellBook.IsSpellKnown(info.spellID) then
				known = info
			end
			active = active or C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL") ~= nil
		end
		if known and not active then
			table.insert(missing, known)
		end
	end
	for i, info in ipairs(missing) do
		local b = Icon(i)
		b.spellID = info.spellID
		b:SetAttribute("spell", info.name) -- by name, so it casts the highest rank you know
		b.icon:SetTexture(info.iconID)
		b.label:SetText(info.name)
		b:Show()
	end
	for i = #missing + 1, #icons do
		icons[i]:Hide()
	end
	f:SetWidth(math.max(#missing * (SIZE + GAP) - GAP, 1))
	f:SetShown(#missing > 0)
end

m.OnToggle = Refresh
-- Fires just before combat lockdown starts, so the secure icons can still be hidden here.
m:On("PLAYER_REGEN_DISABLED", function() f:Hide() end)
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
	m:On(event, Refresh)
end
m:On("UNIT_AURA", function(unit)
	if unit == "player" then Refresh() end
end)
