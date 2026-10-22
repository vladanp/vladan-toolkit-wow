local _, VT = ...
local m = VT:NewModule("Screenshots", "Auto screenshots", "Takes a screenshot when you level up or kill a dungeon or raid boss.")
m.section = "Leveling and buffs"
m:Option({ key = "LevelUp", title = "On level up", default = true, desc = "Take a screenshot when you reach a new level." })
m:Option({ key = "BossKill", title = "On boss kills", default = true, desc = "Take a screenshot when a dungeon or raid boss dies." })

-- A short delay lets the level up glow or the boss loot show in the picture.
local function Capture()
	C_Timer.After(1, Screenshot)
end

m:On("PLAYER_LEVEL_UP", function()
	if m:Get("LevelUp") then Capture() end
end)

m:On("ENCOUNTER_END", function(_, _, _, _, success)
	if m:Get("BossKill") and success == 1 then Capture() end
end)
