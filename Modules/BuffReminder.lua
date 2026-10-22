local _, VT = ...
local m = VT:NewModule("BuffReminder", "Missing-buff reminder",
	"Out of combat, shows your class buffs that are missing. Drag to move.")

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

local f = VT:CreateTextFrame("BuffReminder", "CENTER", 0, 180)

local function Refresh()
	-- Auras can be secret in combat, so only check out of it.
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
			table.insert(missing, "|T" .. known.iconID .. ":16|t " .. known.name)
		end
	end
	f.text:SetText("Missing: " .. table.concat(missing, ", "))
	f:SetShown(#missing > 0)
end

m.OnToggle = Refresh
m:On("PLAYER_REGEN_DISABLED", function() f:Hide() end)
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
	m:On(event, Refresh)
end
m:On("UNIT_AURA", function(unit)
	if unit == "player" then Refresh() end
end)
