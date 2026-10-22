local _, VT = ...
local m = VT:NewModule("LowSupplies", "Low supplies warning",
	"Warns when your gear is about to break or items on your auto buy list (/vt buy) run low. Right click the warning to dismiss it, drag to move.")
m.section = "Loot and vendors"
m:Option({ key = "Durability", title = "Warn when gear is below", default = 25, min = 10, max = 50, step = 5,
	format = VT.format.percent100, desc = "Durability of your most damaged item." })
m:Option({ key = "Supplies", title = "Warn when supplies are below", default = 25, min = 10, max = 90, step = 5,
	format = VT.format.percent100, desc = "Share of the amount on your auto buy list (/vt buy)." })
m:Option({ key = "Sound", title = "Sound", default = true, desc = "Play a warning sound when something new runs low." })

local REPAIR_ICON = 136241 -- blacksmith hammer
local PAD = 10

local f = VT:CreateMovable("LowSupplies", "TOP", 0, -150, "TooltipBackdropTemplate")
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetText("LOW SUPPLIES")
local list = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
list:SetPoint("TOPLEFT", PAD, -PAD - 16)
list:SetJustifyH("LEFT")
list:SetSpacing(4)

-- Warnings are keyed ("durability" or an item ID). A right click dismisses the current ones;
-- a new warning shows again, and a dismissed one can warn again once it has recovered.
local active, dismissed = {}, {}

local function Refresh()
	local lines, keys = {}, {}
	if m:IsEnabled() then
		local lowest
		for slot = 1, 19 do
			local current, max = GetInventoryItemDurability(slot)
			if current and max and max > 0 and (not lowest or current / max < lowest) then
				lowest = current / max
			end
		end
		if lowest and lowest * 100 < m:Get("Durability") then
			keys.durability = true
			local color = lowest < 0.1 and "ff4040" or "ffa040"
			table.insert(lines, ("|T%d:16|t  Gear durability  |cff%s%d%%|r"):format(REPAIR_ICON, color, lowest * 100))
		end
		local ids = {}
		for id in pairs(VladanToolkitCharDB.buy or {}) do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local want, have = VladanToolkitCharDB.buy[id], C_Item.GetItemCount(id)
			if have < want * m:Get("Supplies") / 100 then
				keys[id] = true
				local name = C_Item.GetItemNameByID(id) or ("item " .. id)
				local icon = C_Item.GetItemIconByID(id) or 134400 -- question mark
				table.insert(lines, ("|T%d:16|t  %s  |cffff4040%d|r / %d"):format(icon, name, have, want))
			end
		end
	end

	local new, visible = false, false
	for key in pairs(keys) do
		if not active[key] then new = true end
		if not dismissed[key] then visible = true end
	end
	for key in pairs(dismissed) do
		if not keys[key] then dismissed[key] = nil end
	end
	active = keys
	if new and m:Get("Sound") then PlaySound(SOUNDKIT.RAID_WARNING) end
	if not visible then return f:Hide() end

	list:SetText(table.concat(lines, "\n"))
	f:SetSize(math.max(list:GetStringWidth(), title:GetStringWidth()) + 2 * PAD, list:GetStringHeight() + 16 + 2 * PAD)
	f:Show()
end

f:SetScript("OnMouseUp", function(_, button)
	if button == "RightButton" then
		for key in pairs(active) do dismissed[key] = true end
		f:Hide()
	end
end)

m.OnToggle = Refresh
for _, event in ipairs({ "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
	m:On(event, Refresh)
end
