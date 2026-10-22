local _, VT = ...
-- Forever already has mouse wheel zoom, zoom buttons on hover and coordinates (game settings),
-- so these only add what it lacks.

-- Square minimap

local square = VT:NewModule("SquareMinimap", "Square minimap", "A clean square minimap with a thin border instead of the round frame.")
square.section = "Minimap"

local border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
border:SetPoint("TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", 2, -2)
border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
border:SetBackdropBorderColor(0, 0, 0, 0.9)
border:Hide()

local squared
local function ApplySquare()
	if not square:IsEnabled() then return end
	Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
	MinimapCompassTexture:Hide()
	MinimapCompassTextureUnderlay:Hide()
	border:Show()
	squared = true
end
-- Blizzard puts the round mask back whenever the minimap mode changes, so square it again afterwards.
hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", ApplySquare)

square.OnToggle = function(_, enabled)
	if enabled then
		ApplySquare()
	elseif squared then
		squared = false
		border:Hide()
		MinimapCompassTexture:Show()
		MinimapCluster:UpdateMinimapConfig() -- restores the round mask and frame
	end
end

-- Other addons' minimap buttons (LibDBIcon) ask this to sit on the right edge.
function GetMinimapShape()
	return square:IsEnabled() and "SQUARE" or "ROUND"
end

-- Auto zoom out

local zoom = VT:NewModule("MinimapAutoZoom", "Auto zoom out", "Zooms the minimap back out 10 seconds after you zoom in.")
zoom.section = "Minimap"

local timer
hooksecurefunc(Minimap, "SetZoom", function(_, level)
	if timer then timer:Cancel() end
	if level > 0 and zoom:IsEnabled() then
		timer = C_Timer.NewTimer(10, function()
			Minimap:SetZoom(0)
			Minimap.ZoomIn:Enable() -- keep the hover zoom buttons in sync, like Blizzard's own zoom out
			Minimap.ZoomOut:Disable()
		end)
	end
end)

-- Buttons only on hover

local clean = VT:NewModule("MinimapHoverButtons", "Minimap buttons on hover",
	"Hides the clock, tracking and addon buttons around the minimap until your mouse is over it.")
clean.section = "Minimap"

local function Buttons()
	local list = {}
	for _, b in pairs({ GameTimeFrame, AddonCompartmentFrame, MinimapCluster.Tracking }) do
		table.insert(list, b)
	end
	for _, child in ipairs({ Minimap:GetChildren() }) do
		local name = child:GetName()
		if name and name:find("^LibDBIcon10_") then table.insert(list, child) end
	end
	return list
end

local visible
C_Timer.NewTicker(0.2, function()
	local show = not clean:IsEnabled() or MinimapCluster:IsMouseOver()
	if show ~= visible then
		visible = show
		for _, b in ipairs(Buttons()) do
			b:SetAlpha(show and 1 or 0)
		end
	end
end)
