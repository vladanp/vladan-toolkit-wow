local _, VT = ...
local m = VT:NewModule("LFGScanner", "LFG chat scanner",
	"Collects LFG and LFM posts from chat channels into one window, grouped by dungeon. Open it with /vt lfg.")
m.section = "Social"
m:Option({ key = "Expire", title = "Keep posts for", default = 15, min = 5, max = 30, step = 5, format = VT.format.minutes,
	desc = "Posts older than this drop off the list." })
m:Option({ key = "Sound", title = "Sound for new matches", default = true,
	desc = "While a filter is set, play a sound when someone new posts a match." })
m:Option({ key = "ChatAlert", title = "Chat line for new matches", default = true,
	desc = "While a filter is set and the window is closed, print new matches in chat." })

local W, ROW, ROWS, TOP = 440, 32, 10, 46

-- Dungeons in level order, with the words people use for them in chat.
-- ponytail: English keywords; Forever's nine new dungeons and raids are named from launch guides,
-- so check them on live. Posts that match nothing are listed under "Other".
local DUNGEONS = {
	{ "Ragefire Chasm", "rfc", "ragefire" },
	{ "Wailing Caverns", "wc", "wailing" },
	{ "The Deadmines", "dm", "deadmines", "vc" },
	{ "Hall of Thanes", "thanes", "hall of thanes" },
	{ "Shadowfang Keep", "sfk", "shadowfang" },
	{ "Ruins of Lordaeron", "lordaeron", "ruins" },
	{ "Blackfathom Deeps", "bfd", "blackfathom" },
	{ "The Stockade", "stocks", "stockade" },
	{ "Gnomeregan", "gnomer", "gnomeregan" },
	{ "Excavation Site", "excavation", "excav" },
	{ "Razorfen Kraul", "rfk", "kraul" },
	{ "City of Dalaran", "dalaran", "dala" },
	{ "Scarlet Monastery", "sm", "scarlet", "gy", "graveyard", "lib", "library", "arm", "armory", "cath", "cathedral" },
	{ "The Drowned City", "drowned" },
	{ "Razorfen Downs", "rfd", "downs" },
	{ "Uldaman", "ulda", "uldaman" },
	{ "Krol'dok Stronghold", "krol'dok", "kroldok", "krol" },
	{ "Zul'Farrak", "zf", "zul'farrak", "zulfarrak" },
	{ "Maraudon", "mara", "maraudon" },
	{ "Alcaz Island Prison", "alcaz" },
	{ "Sunken Temple", "st", "sunken", "atal" },
	{ "Blackrock Depths", "brd" },
	{ "Lower Blackrock Spire", "lbrs" },
	{ "Upper Blackrock Spire", "ubrs" },
	{ "Dire Maul", "dire maul", "dme", "dmw", "dmn", "dm east", "dm west", "dm north", "tribute" },
	{ "Blackmaw Hold", "blackmaw" },
	{ "Stratholme", "strat", "stratholme" },
	{ "Scholomance", "scholo", "scholomance" },
	{ "Shaper's Terrace", "shaper", "shapers", "terrace" },
	{ "Barrow Deeps (raid)", "barrow" },
	{ "Hyjal Summit (raid)", "hyjal" },
	{ "Molten Core (raid)", "mc", "molten" },
	{ "Onyxia's Lair (raid)", "ony", "onyxia" },
}

local ROLES = {
	{ "%f[%w]tanks?%f[%W]", "|A:roleicon-tiny-tank:14:14|a" },
	{ "%f[%w]heal[ersz]*%f[%W]", "|A:roleicon-tiny-healer:14:14|a" },
	{ "%f[%w]dps%f[%W]", "|A:roleicon-tiny-dps:14:14|a" },
}

local posts = {} -- keyed by sender; a new post from the same person replaces the old one

local function Word(text, word)
	return text:find("%f[%w]" .. word .. "%f[%W]") ~= nil
end

-- Returns "LFM" (group wants players), "LFG" (player wants a group) or nil, plus role icons.
local function Classify(text)
	if Word(text, "wt[sb]") or text:find("boost") or text:find("selling") then return end
	local roles = ""
	for _, r in ipairs(ROLES) do
		if text:find(r[1]) then roles = roles .. r[2] end
	end
	if Word(text, "lf%d*m") or Word(text, "lf") or (Word(text, "need") and roles ~= "") then
		return "LFM", roles
	elseif Word(text, "lfg") or text:find("looking for group") then
		return "LFG", roles
	end
end

-- The longest matching keyword wins, so "dm east" beats "dm".
local function Dungeon(text)
	local best, bestLength = nil, 0
	for i, d in ipairs(DUNGEONS) do
		for k = 2, #d do
			if #d[k] > bestLength and Word(text, d[k]) then
				best, bestLength = i, #d[k]
			end
		end
	end
	return best
end

local function Filter()
	return (VladanToolkitDB.LFGFilter or ""):lower()
end

local function Matches(p)
	local filter = Filter()
	return filter == "" or p.lower:find(filter, 1, true) ~= nil
		or (p.dungeon and DUNGEONS[p.dungeon][1]:lower():find(filter, 1, true) ~= nil)
end

-- Window

local f = VT:CreateMovable("LFGScanner", "CENTER", 0, 60, "TooltipBackdropTemplate")
f:SetSize(W, TOP + ROWS * ROW + 12)
f:SetFrameStrata("HIGH")
VladanToolkitLFGFrame = f
table.insert(UISpecialFrames, "VladanToolkitLFGFrame") -- Escape closes it

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -14)
title:SetText("Looking for group")
local count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
count:SetPoint("LEFT", title, "RIGHT", 8, -1)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
search:SetSize(150, 20)
search:SetPoint("TOPRIGHT", -34, -12)
search.Instructions:SetText("Filter: dungeon or word")

local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
empty:SetPoint("CENTER", 0, -10)
empty:SetWidth(W - 60)
empty:SetText("No group posts yet.\nThey show up here as people post LFG or LFM in chat channels.")

local offset, rows, Render = 0, {}

local function Age(p)
	local s = GetTime() - p.time
	return s < 60 and "now" or ("%dm"):format(math.floor(s / 60))
end

local function ShowTooltip(row)
	local p = row.post
	if not p then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(p.name)
	GameTooltip:AddLine(p.text, 1, 1, 1, true)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Click to whisper   ·   Shift click to invite", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

for i = 1, ROWS do
	local row = CreateFrame("Button", nil, f)
	row:SetSize(W - 24, ROW)
	row:SetPoint("TOPLEFT", 12, -TOP - (i - 1) * ROW)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.06)

	row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.header:SetPoint("BOTTOMLEFT", 0, 6)
	row.line = row:CreateTexture(nil, "ARTWORK")
	row.line:SetColorTexture(1, 0.82, 0, 0.25)
	row.line:SetHeight(1)
	row.line:SetPoint("BOTTOMLEFT", 0, 3)
	row.line:SetPoint("BOTTOMRIGHT", 0, 3)

	row.who = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.who:SetPoint("TOPLEFT", 8, -2)
	row.age = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.age:SetPoint("TOPRIGHT", -4, -3)
	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.text:SetPoint("TOPLEFT", 8, -17)
	row.text:SetWidth(W - 40)
	row.text:SetWordWrap(false)
	row.text:SetJustifyH("LEFT")
	row.text:SetTextColor(0.7, 0.7, 0.75)

	row:SetScript("OnEnter", ShowTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetScript("OnClick", function(self)
		if not self.post then return end
		if IsShiftKeyDown() then
			C_PartyInfo.InviteUnit(self.post.sender)
		else
			ChatFrameUtil.SendTell(self.post.sender)
		end
	end)
	rows[i] = row
end

f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function(_, delta)
	offset = offset - delta * 3
	Render()
end)

function Render()
	-- Drop old posts, then build the list: a header per dungeon, newest posts first under it.
	local now, list = GetTime(), {}
	for sender, p in pairs(posts) do
		if now - p.time > m:Get("Expire") * 60 then
			posts[sender] = nil
		elseif Matches(p) then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		local da, db = a.dungeon or #DUNGEONS + 1, b.dungeon or #DUNGEONS + 1
		if da ~= db then return da < db end
		return a.time > b.time
	end)
	local entries, header = {}, nil
	for _, p in ipairs(list) do
		if not header or header.dungeon ~= p.dungeon then
			header = { dungeon = p.dungeon, n = 0 }
			table.insert(entries, header)
		end
		header.n = header.n + 1
		table.insert(entries, p)
	end

	offset = math.max(0, math.min(offset, #entries - ROWS))
	count:SetText(#list == 1 and "1 post" or #list .. " posts")
	empty:SetShown(#list == 0)
	for i, row in ipairs(rows) do
		local e = entries[i + offset]
		local isHeader = e and e.n ~= nil
		row.post = e and not isHeader and e or nil
		row.header:SetShown(isHeader)
		row.line:SetShown(isHeader)
		row.who:SetShown(row.post ~= nil)
		row.age:SetShown(row.post ~= nil)
		row.text:SetShown(row.post ~= nil)
		if isHeader then
			local name = e.dungeon and DUNGEONS[e.dungeon][1] or "Other"
			row.header:SetText(name .. "  |cff8c8c8c" .. e.n .. "|r")
		elseif row.post then
			local p = row.post
			local tag = p.kind == "LFM" and "|cff40ff40LFM|r" or "|cff4da6ffLFG|r"
			row.who:SetText(tag .. "  " .. p.name .. "  " .. p.roles)
			row.age:SetText(Age(p))
			row.text:SetText(p.text)
		end
		row:SetShown(e ~= nil)
	end
end

search:HookScript("OnTextChanged", function(self)
	VladanToolkitDB.LFGFilter = self:GetText()
	offset = 0
	Render()
end)

f:SetScript("OnShow", function()
	search:SetText(VladanToolkitDB.LFGFilter or "")
	Render()
end)

C_Timer.NewTicker(15, function()
	if f:IsShown() then Render() end -- keeps ages and expiry current
end)

VT.commands.lfg = function()
	if not m:IsEnabled() then
		VT:Print("The LFG chat scanner is off. Turn it on in /vt.")
	end
	f:SetShown(not f:IsShown())
end

m.OnToggle = function(_, enabled)
	if not enabled then f:Hide() end
end

-- Scanning

m:On("CHAT_MSG_CHANNEL", function(text, sender, _, _, _, _, _, _, _, _, _, guid)
	if issecretvalue(text) or issecretvalue(sender) then return end
	local lower = text:lower()
	local kind, roles = Classify(lower)
	if not kind or Ambiguate(sender, "short") == UnitName("player") then return end

	local name = Ambiguate(sender, "short")
	if guid and not issecretvalue(guid) then
		local _, class = GetPlayerInfoByGUID(guid)
		local color = class and C_ClassColor.GetClassColor(class)
		if color then name = color:WrapTextInColorCode(name) end
	end
	local isNew = posts[sender] == nil
	local p = { sender = sender, name = name, text = text, lower = lower, kind = kind, roles = roles,
		dungeon = Dungeon(lower), time = GetTime() }
	posts[sender] = p

	-- With a filter set, a new matching poster can play a sound and print a line while the window is closed.
	if isNew and Filter() ~= "" and Matches(p) then
		if m:Get("Sound") then PlaySound(SOUNDKIT.TELL_MESSAGE) end
		if m:Get("ChatAlert") and not f:IsShown() then
			VT:Notify(("%s %s for %s  (/vt lfg)"):format(kind, name, p.dungeon and DUNGEONS[p.dungeon][1] or "a group"))
		end
	end
	if f:IsShown() then Render() end
end)
