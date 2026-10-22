local _, VT = ...
local m = VT:NewModule("ChatLinks", "Copyable chat links",
	"Web links in chat become clickable. Click one to put it in the chat box, then press Ctrl+C.")
m.section = "Social"

local LINK = "|cff66bbff|Hvtkurl:%1|h[%1]|h|r"

-- Blizzard only runs chat filters on messages addons may read (not secret ones).
local function Linkify(_, _, msg, ...)
	if not m:IsEnabled() then return false end
	local new, n = msg:gsub("(https?://[^%s|]+)", LINK)
	if n == 0 then
		new, n = msg:gsub("(www%.[%w%-]+%.[^%s|]+)", LINK)
	end
	if n == 0 then return false end
	return false, new, ...
end

for _, event in ipairs({ "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM",
	"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
	"GUILD", "OFFICER", "CHANNEL" }) do
	ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_" .. event, Linkify)
end

LinkUtil.RegisterLinkHandler("vtkurl", function(link)
	ChatFrameUtil.OpenChat(link:sub(#"vtkurl:" + 1))
	local editBox = ChatFrameUtil.GetActiveWindow()
	if editBox then editBox:HighlightText() end
end)
