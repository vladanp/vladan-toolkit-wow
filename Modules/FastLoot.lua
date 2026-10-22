local _, VT = ...
local m = VT:NewModule("FastLoot", "Faster auto loot", "Grab all loot instantly when auto loot is on.")

local last = 0
m:On("LOOT_READY", function()
	-- LOOT_READY can fire twice for one corpse.
	if GetTime() - last < 0.3 then return end
	if C_CVar.GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
		last = GetTime()
		for i = GetNumLootItems(), 1, -1 do
			LootSlot(i)
		end
	end
end)
