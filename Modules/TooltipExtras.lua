local _, VT = ...
local m = VT:NewModule("TooltipExtras", "Tooltip extras",
	"Adds item level, stack size and IDs to tooltips. Forever already shows sell prices and Already known.")
m.section = "Interface"
m:Option({ key = "ItemLevel", title = "Item level", default = true,
	desc = "Item level on gear, when the tooltip doesn't already show it." })
m:Option({ key = "Stack", title = "Stack size", default = true, desc = "How many of an item fit in one bag slot." })
m:Option({ key = "IDs", title = "IDs", default = true, desc = "Item, spell and NPC IDs, handy for guides and databases." })

local ITEM_LEVEL_PREFIX = ITEM_LEVEL:match("^(.-)%%d") -- "Item Level "

local function Ours(tooltip)
	return m:IsEnabled() and (tooltip == GameTooltip or tooltip == ItemRefTooltip)
end

local function Detail(tooltip, label, value)
	tooltip:AddDoubleLine(label, value, 0.55, 0.55, 0.6, 0.8, 0.8, 0.85)
end

local function HasLine(data, prefix)
	for _, line in ipairs(data.lines or {}) do
		if line.leftText and not issecretvalue(line.leftText) and line.leftText:find(prefix, 1, true) == 1 then
			return true
		end
	end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
	if not Ours(tooltip) or not data or not data.id then return end
	local _, link = tooltip:GetItem()
	if m:Get("ItemLevel") and link and C_Item.IsEquippableItem(link) and not HasLine(data, ITEM_LEVEL_PREFIX) then
		local level = C_Item.GetDetailedItemLevelInfo(link)
		if level then tooltip:AddLine(ITEM_LEVEL:format(level), 1, 0.82, 0) end
	end
	local stack = select(8, C_Item.GetItemInfo(data.id))
	if m:Get("Stack") and stack and stack > 1 then
		Detail(tooltip, "Stacks to", stack)
	end
	if m:Get("IDs") then
		Detail(tooltip, "Item ID", data.id)
	end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
	if Ours(tooltip) and m:Get("IDs") and data and data.id then
		Detail(tooltip, "Spell ID", data.id)
	end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
	local guid = data and data.guid
	if not Ours(tooltip) or not m:Get("IDs") or not guid or issecretvalue(guid) then return end
	local kind, _, _, _, _, npcID = strsplit("-", guid)
	if (kind == "Creature" or kind == "Vehicle") and npcID then
		Detail(tooltip, "NPC ID", npcID)
	end
end)
