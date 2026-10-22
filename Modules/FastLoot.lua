local _, VT = ...
local m = VT:NewModule("FastLoot", "Faster auto loot", "Grab all loot instantly when auto loot is on.")
m.section = "Loot and vendors"

local last = 0
-- autoLoot already accounts for the auto loot setting, its modifier key and the gamepad toggle.
m:On("LOOT_READY", function(autoLoot)
	-- LOOT_READY can fire twice for one corpse.
	if not autoLoot or GetTime() - last < 0.3 then return end
	last = GetTime()
	for i = GetNumLootItems(), 1, -1 do
		LootSlot(i)
	end
end)
