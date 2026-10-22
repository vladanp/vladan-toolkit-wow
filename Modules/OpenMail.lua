local _, VT = ...
local m = VT:NewModule("AutoOpenMail", "Auto open all mail",
	"Presses the mailbox's own Open All button when you open a mailbox (it skips COD and GM mail).")
m.section = "Loot and vendors"

local pending
m:On("MAIL_SHOW", function() pending = true end)
m:On("MAIL_CLOSED", function() pending = false end)
-- The inbox fills in after MAIL_SHOW, so wait for the first update that has mail.
m:On("MAIL_INBOX_UPDATE", function()
	if pending and GetInboxNumItems() > 0 and OpenAllMail:IsEnabled() then
		pending = false
		OpenAllMail:Click()
	end
end)
