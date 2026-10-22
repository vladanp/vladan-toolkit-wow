local _, VT = ...
local m = VT:NewModule("AutoBuy", "Auto buy reagents",
	"At vendors, tops up the items on this character's list. Edit it with /vt buy.")

local USAGE = "/vt buy <shift click item or item ID> <count>   (count 0 removes, /vt buy alone lists)"

m:On("MERCHANT_SHOW", function()
	local list = VladanToolkitCharDB.buy or {}
	for i = 1, GetMerchantNumItems() do
		local id = GetMerchantItemID(i)
		local info = id and list[id] and C_MerchantFrame.GetItemInfo(i)
		local need = info and list[id] - C_Item.GetItemCount(id) or 0
		if need > 0 and info.isPurchasable and not info.hasExtendedCost then
			-- Quantity is in items; vendors sell in units of stackCount, at most maxStack per call.
			local step = math.max(info.stackCount, 1)
			local qty = math.ceil(need / step) * step
			local max = math.max(GetMerchantItemMaxStack(i), step)
			VT:Print("Buying " .. qty .. " x " .. (info.name or id))
			while qty > 0 do
				local n = math.min(qty, max)
				BuyMerchantItem(i, n)
				qty = qty - n
			end
		end
	end
end)

VT.commands.buy = function(args)
	VladanToolkitCharDB.buy = VladanToolkitCharDB.buy or {}
	local list = VladanToolkitCharDB.buy
	local id = tonumber(args:match("item:(%d+)") or args:match("^(%d+)"))
	local count = tonumber(args:match("%s(%d+)$"))
	if not id then
		if next(list) == nil then VT:Print("Buy list is empty. " .. USAGE) end
		for itemID, n in pairs(list) do
			VT:Print(n .. " x " .. (C_Item.GetItemNameByID(itemID) or ("item " .. itemID)))
		end
	elseif not count then
		VT:Print(USAGE)
	else
		list[id] = count > 0 and count or nil
		VT:Print((C_Item.GetItemNameByID(id) or ("item " .. id)) .. ": keep " .. count)
	end
end
