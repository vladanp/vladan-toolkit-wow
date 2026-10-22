local _, VT = ...

-- Uses Forever's own "Sell All Junk" (sold on the server in one go, so no throttling).
local junk = VT:NewModule("SellJunk", "Sell junk", "Sell all grey items when you open a vendor.")
junk.section = "Loot and vendors"
junk:On("MERCHANT_SHOW", function()
	local n = C_MerchantFrame.GetNumJunkItems()
	if n > 0 and C_MerchantFrame.IsSellAllJunkEnabled() then
		C_MerchantFrame.SellAllJunkItems()
		VT:Print("Sold " .. n .. " junk item(s).")
	end
end)

local repair = VT:NewModule("AutoRepair", "Auto repair", "Repair all gear at vendors that can repair.")
repair.section = "Loot and vendors"
repair:On("MERCHANT_SHOW", function()
	if not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost == 0 then return end
	if cost > GetMoney() then
		VT:Print("Not enough money to repair (" .. GetMoneyString(cost, true) .. ").")
		return
	end
	RepairAllItems()
	VT:Print("Repaired for " .. GetMoneyString(cost, true) .. ".")
end)
