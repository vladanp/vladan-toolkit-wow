local _, VT = ...
local m = VT:NewModule("ErrorFilter", "Error spam filter",
	"Hides the red error spam in the middle of the screen, like Not enough rage or Out of range. Other errors still show.")
m.section = "Interface"
m:Option({ key = "Resources", title = "Not enough rage, energy or mana", default = true,
	desc = "Errors when you lack the resource for an ability." })
m:Option({ key = "Cooldowns", title = "Not ready yet", default = true,
	desc = "Errors when an ability or item is still on cooldown." })
m:Option({ key = "Range", title = "Range, facing and target", default = true,
	desc = "Out of range, facing the wrong way, not in line of sight and no target." })
m:Option({ key = "CombatOnly", title = "Only during combat", default = false,
	desc = "Show these errors again out of combat." })

-- Error types per group, as the game names them (LE_GAME_ERR_<name>); Blizzard skips names a build lacks (nil).
local GROUPS = {
	Resources = { "OUT_OF_RAGE", "OUT_OF_ENERGY", "OUT_OF_MANA", "OUT_OF_FOCUS", "OUT_OF_COMBO_POINTS", "OUT_OF_HEALTH",
		"OUT_OF_POWER_DISPLAY" },
	Cooldowns = { "ABILITY_COOLDOWN", "SPELL_COOLDOWN", "ITEM_COOLDOWN" },
	Range = { "OUT_OF_RANGE", "SPELL_OUT_OF_RANGE", "BADATTACKFACING", "BADATTACKPOS", "GENERIC_NO_TARGET",
		"INVALID_ATTACK_TARGET", "SPELL_FAILED_LINE_OF_SIGHT", "SPELL_FAILED_UNIT_NOT_INFRONT" },
}

-- Uses the error frame's own on/off switch per message type. Forever shows all of these by default,
-- so turning a group off puts them back exactly as the game had them.
local touched -- leave the error frame alone entirely until the filter has been used
local function Apply(inCombat)
	local active = m:IsEnabled() and (not m:Get("CombatOnly") or inCombat)
	if not active and not touched then return end
	touched = true
	for group, names in pairs(GROUPS) do
		local hide = active and m:Get(group)
		for _, name in ipairs(names) do
			UIErrorsFrame:SetMessageTypeEnabled(_G["LE_GAME_ERR_" .. name], not hide)
		end
	end
end

m.OnToggle = function()
	Apply(UnitAffectingCombat("player"))
end
m:On("PLAYER_REGEN_DISABLED", function() Apply(true) end)
m:On("PLAYER_REGEN_ENABLED", function() Apply(false) end)
