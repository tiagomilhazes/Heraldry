--[[
	Heraldry_Chat - Text.lua
	What the chat writes, and the input line's memory:

	  - channel names: full ("[2. Trade - City]"), short ("[T]"), number ("[2]")
	    or hidden; every channel's short name can be changed
	  - "Name says:" can become "Name:"
	  - timestamps: the game's own setting (one place), shown faded
	  - old lines fade out after a time, or never
	  - input history: Up and Down bring back what you typed (without Alt),
	    and the last lines are kept for the next session (per character)

	Lines are rewritten as they arrive (Chat.lua's AddMessage wrapper calls
	FormatLine). Lines the game marks as secret are left as they are.
]]

local H = Heraldry
local CH = H.Modules.byName.Chat

local DEFAULTS = {
	channelStyle = "short",   -- "full" | "short" | "number" | "none"
	dropSays = true,
	nameBrackets = false,     -- [Name] -> Name (channels keep theirs)
	plainBody = true,         -- the message in plain ink, the channel and name in the channel's colour
	timeDim = true,
	fade = true,
	fadeTime = 120,
	arrowHistory = true,
	historySize = 50,
	historySave = true,
}
for k, v in pairs(DEFAULTS) do CH.defaults[k] = v end

-- Chat types (named in the line) and the usual numbered channels.
-- abbr_<key> in the settings replaces the short name.
CH.CHANNELS = {
	{ key = "GUILD",           label = "Guild",              name = "Guild",            short = "G", type = "GUILD" },
	{ key = "OFFICER",         label = "Officer",            name = "Officer",          short = "O", type = "OFFICER" },
	{ key = "PARTY",           label = "Party",              name = "Party",            short = "P", type = "PARTY" },
	{ key = "PARTY_LEADER",    label = "Party leader",       name = "Party Leader",     short = "PL", type = "PARTY_LEADER" },
	{ key = "RAID",            label = "Raid",               name = "Raid",             short = "R", type = "RAID" },
	{ key = "RAID_LEADER",     label = "Raid leader",        name = "Raid Leader",      short = "RL", type = "RAID_LEADER" },
	{ key = "RAID_WARNING",    label = "Raid warning",       name = "Raid Warning",     short = "RW", type = "RAID_WARNING" },
	{ key = "INSTANCE",        label = "Instance",           name = "Instance",         short = "I", type = "INSTANCE_CHAT" },
	{ key = "INSTANCE_LEADER", label = "Instance leader",    name = "Instance Leader",  short = "IL", type = "INSTANCE_CHAT_LEADER" },
	{ key = "General",         label = "General",            numbered = true,           short = "Gen" },
	{ key = "Trade",           label = "Trade",              numbered = true,           short = "T" },
	{ key = "LocalDefense",    label = "Local defense",      numbered = true,           short = "LD" },
	{ key = "LookingForGroup", label = "Looking for group",  numbered = true,           short = "LFG" },
	{ key = "WorldDefense",    label = "World defense",      numbered = true,           short = "WD" },
	{ key = "GuildRecruitment", label = "Guild recruitment", numbered = true,           short = "GR" },
	{ key = "Services",        label = "Services",           numbered = true,           short = "S" },
}

-- Colours only (no tag in the line to shorten)
CH.SPEECH = {
	{ label = "Say",            type = "SAY" },
	{ label = "Yell",           type = "YELL" },
	{ label = "Whisper (from)", type = "WHISPER" },
	{ label = "Whisper (to)",   type = "WHISPER_INFORM" },
	{ label = "Emote",          type = "EMOTE" },
}

local function norm(s) return (s:gsub("%s", ""):lower()) end

local byName, byNumbered = {}, {}
for _, c in ipairs(CH.CHANNELS) do
	if c.numbered then byNumbered[norm(c.key)] = c else byName[c.name] = c end
end

function CH:ShortName(c)
	local custom = self.db["abbr_" .. c.key]
	if type(custom) == "string" and custom ~= "" then return custom end
	return c.short
end

-- the text inside the brackets for a channel link, or nil to leave it alone
function CH:ChannelTag(label)
	local style = self.db.channelStyle
	if style == "full" then return nil end
	local num, name = label:match("^(%d+)%. (.+)$")
	if num then
		local base = name:match("^(.-) %- ") or name
		local c = byNumbered[norm(base)]
		if style == "number" then return num end
		return c and self:ShortName(c) or base
	end
	local c = byName[label]
	return c and self:ShortName(c) or nil
end

local function readable(text)
	return type(text) == "string" and not (issecretvalue and issecretvalue(text))
end

function CH:FormatLine(text)
	if not readable(text) then return nil end
	local db = self.db

	-- channel names
	if db.channelStyle ~= "full" then
		text = text:gsub("|Hchannel:([^|]+)|h%[([^%]]+)%]|h(%s?)", function(link, label, space)
			if db.channelStyle == "none" then return "" end
			local tag = CH:ChannelTag(label)
			if not tag then return nil end
			return "|Hchannel:" .. link .. "|h[" .. tag .. "]|h" .. space
		end)
	end

	-- "Name says: hi" -> "Name: hi" (only near the start, never inside the message)
	if db.dropSays then
		local at = text:find(" says: ", 1, true)
		if at and at < 120 then
			text = text:sub(1, at - 1) .. ": " .. text:sub(at + 7)
		end
	end

	-- player names without brackets: brackets belong to channels
	if not db.nameBrackets then
		text = text:gsub("(|H[B]?N?player:[^|]*|h)%[(.-)%]|h", "%1%2|h")
	end

	-- channel and name keep the line's colour; the message itself is written in plain ink
	if db.plainBody then
		local _, linkEnd = text:find("|H[B]?N?player:[^|]*|h.-|h")
		if linkEnd then
			local colon = text:find(": ", linkEnd + 1, true)
			if colon and colon - linkEnd < 40 then
				local c = self:Paper().text or { 0.86, 0.81, 0.71 }
				local hex = ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
				text = text:sub(1, colon + 1) .. "|cff" .. hex .. text:sub(colon + 2) .. "|r"
			end
		end
	end

	-- the game's timestamp, faded
	if db.timeDim then
		local c = self:Paper().text and { 0.45, 0.38, 0.28 } or { 0.55, 0.52, 0.47 }
		local hex = ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
		text = text:gsub("^(%d+:%d+[:%d]*%s?[AaPp]?[Mm]?) ", "|cff" .. hex .. "%1|r ", 1)
	end
	return text
end

--[[ Colours: the game's own chat colours (one place), changed from our page ]]

-- the game's chat type of a channel entry; numbered channels by their current number
function CH:ChatType(c)
	if c.type then return c.type end
	if not GetChannelList then return nil end
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local id, name = list[i], list[i + 1]
		if type(name) == "string" and norm(name:match("^(.-) %- ") or name) == norm(c.key) then
			return "CHANNEL" .. id
		end
	end
end

function CH:InkPaper() return self.ink and self.ink ~= 1 end

function CH:GetColor(chatType)
	if self:InkPaper() then
		local c = self:InkFor(chatType)
		if c then return c[1], c[2], c[3] end
	end
	local info = chatType and ChatTypeInfo and ChatTypeInfo[chatType]
	if info then return info.r, info.g, info.b end
	return 1, 1, 1
end

-- light paper: our ink colour; other papers: the game's own colour
function CH:SetColor(chatType, r, g, b)
	if not chatType then return end
	if self:InkPaper() then
		self.db["ink_" .. self:InkKey(chatType)] = { r, g, b }
		return
	end
	if ChangeChatColor then ChangeChatColor(chatType, r, g, b) end
	local info = ChatTypeInfo and ChatTypeInfo[chatType]
	if info then info.r, info.g, info.b = r, g, b end
end

--[[ Ink: on light paper every chat type has an ink colour of its own, picked to read
     on parchment and to keep the types apart (the game's colours are pastel, made for
     a dark background). Each can be changed on the Channels tab (ink_<key>). ]]

CH.INK = {
	SAY              = { 0.16, 0.11, 0.06 },   -- near-black brown
	EMOTE            = { 0.52, 0.30, 0.06 },   -- burnt orange
	TEXT_EMOTE       = { 0.52, 0.30, 0.06 },
	YELL             = { 0.66, 0.07, 0.04 },   -- red
	WHISPER          = { 0.56, 0.08, 0.46 },   -- plum
	WHISPER_INFORM   = { 0.40, 0.08, 0.34 },
	BN_WHISPER       = { 0.05, 0.36, 0.52 },
	BN_WHISPER_INFORM = { 0.05, 0.28, 0.42 },
	GUILD            = { 0.08, 0.42, 0.06 },   -- green
	OFFICER          = { 0.04, 0.30, 0.14 },
	PARTY            = { 0.10, 0.24, 0.62 },   -- blue
	PARTY_LEADER     = { 0.06, 0.18, 0.52 },
	RAID             = { 0.70, 0.32, 0.00 },   -- orange
	RAID_LEADER      = { 0.62, 0.24, 0.00 },
	RAID_WARNING     = { 0.72, 0.10, 0.00 },
	INSTANCE_CHAT    = { 0.70, 0.32, 0.00 },
	INSTANCE_CHAT_LEADER = { 0.62, 0.24, 0.00 },
	MONSTER_SAY      = { 0.42, 0.30, 0.06 },   -- ochre
	MONSTER_YELL     = { 0.60, 0.10, 0.04 },
	MONSTER_EMOTE    = { 0.50, 0.32, 0.08 },
	MONSTER_WHISPER  = { 0.50, 0.12, 0.42 },
	SYSTEM           = { 0.36, 0.30, 0.04 },   -- olive
	CHANNEL          = { 0.52, 0.18, 0.14 },   -- brick, every numbered channel unless set
	LOOT             = { 0.06, 0.34, 0.30 },
	MONEY            = { 0.06, 0.34, 0.30 },
	SKILL            = { 0.10, 0.22, 0.50 },
	COMBAT_XP_GAIN   = { 0.30, 0.20, 0.50 },
	COMBAT_FACTION_CHANGE = { 0.20, 0.25, 0.50 },
	ACHIEVEMENT      = { 0.42, 0.34, 0.02 },
}

-- chat type of a line, from the id the game passes after the colour
local typeById
local function chatTypeOf(id)
	if type(id) ~= "number" or not ChatTypeInfo then return nil end
	if not typeById or typeById[id] == nil then
		typeById = typeById or {}
		for k, v in pairs(ChatTypeInfo) do
			if type(v) == "table" and v.id then typeById[v.id] = k end
		end
		if typeById[id] == nil then typeById[id] = false end
	end
	return typeById[id] or nil
end

-- numbered channel "CHANNEL4" -> our entry (Trade, General...), refreshed when channels change
local channelEntry = {}
function CH:RefreshChannels()
	wipe(channelEntry)
	for _, c in ipairs(self.CHANNELS) do
		if c.numbered then
			local t = self:ChatType(c)
			if t then channelEntry[t] = c end
		end
	end
end

-- the key an ink colour is saved under: the chat type, or the channel's name
function CH:InkKey(chatType)
	local c = chatType and channelEntry[chatType]
	return c and c.key or chatType
end

function CH:InkFor(chatType)
	if not chatType then return nil end
	local key = self:InkKey(chatType)
	local own = self.db["ink_" .. key]
	if type(own) == "table" then return own end
	if self.INK[key] then return self.INK[key] end
	if chatType:find("^CHANNEL%d") then return self.INK.CHANNEL end
	return self.INK[chatType]
end

-- any colour made into ink: same hue, dark and saturated; pale greys become brown ink
local function hue2rgb(p, q, t)
	if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
	if t < 1 / 6 then return p + (q - p) * 6 * t end
	if t < 1 / 2 then return q end
	if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
	return p
end

function CH:InkOf(r, g, b)
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local l = (mx + mn) / 2
	local d = mx - mn
	if d < 0.15 then return 0.16, 0.11, 0.06 end
	local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
	local h
	if mx == r then h = (g - b) / d + (g < b and 6 or 0)
	elseif mx == g then h = (b - r) / d + 2
	else h = (r - g) / d + 4 end
	h = h / 6
	if h > 0.12 and h < 0.2 then h = 0.1 end   -- yellows read as mud on parchment: amber instead
	s, l = math.max(s, 0.65), 0.3
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	return hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3)
end

function CH:InkLine(text, r, g, b, id)
	local c = self:InkFor(chatTypeOf(id))
	if c then
		r, g, b = c[1], c[2], c[3]
	elseif type(r) == "number" and type(g) == "number" and type(b) == "number" then
		r, g, b = self:InkOf(r, g, b)
	else
		r, g, b = 0.16, 0.11, 0.06
	end
	-- colours written in the text (names, links), when the text can be read
	if readable(text) then
		text = text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, rr, gg, bb)
			local nr, ng, nb = CH:InkOf(tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255)
			return ("|c%s%02x%02x%02x"):format(a, math.floor(nr * 255), math.floor(ng * 255), math.floor(nb * 255))
		end)
	end
	return text, r, g, b
end

--[[ Applied with the layout: fading and the input lines ]]

function CH:ApplyText()
	local db = self.db
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local cf = _G["ChatFrame" .. i]
		if cf then
			if cf.SetFading then cf:SetFading(db.fade) end
			if cf.SetTimeVisible then cf:SetTimeVisible(db.fadeTime) end
		end
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if eb then self:SetupHistory(eb) end
	end
	self:RefreshChannels()
	if not self.channelEvents then
		self.channelEvents = CreateFrame("Frame")
		for _, e in ipairs({ "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
			pcall(self.channelEvents.RegisterEvent, self.channelEvents, e)
		end
		self.channelEvents:SetScript("OnEvent", function() C_Timer.After(0.5, function() CH:RefreshChannels() end) end)
	end
end

function CH:ResetInk()
	for k in pairs(self.INK) do self.db["ink_" .. k] = nil end
	for _, c in ipairs(self.CHANNELS) do self.db["ink_" .. (c.type or c.key)] = nil end
end

--[[ Input history ]]

function CH:History()
	H.char.chatHistory = H.char.chatHistory or {}
	return H.char.chatHistory
end

function CH:Remember(line)
	if not self.db.historySave or type(line) ~= "string" or line == "" then return end
	local list = self:History()
	for i = #list, 1, -1 do
		if list[i] == line then table.remove(list, i) end
	end
	list[#list + 1] = line
	while #list > self.db.historySize do table.remove(list, 1) end
end

function CH:SetupHistory(eb)
	local db = self.db
	-- plain Up/Down walk the history; with the game's default you have to hold Alt
	eb:SetAltArrowKeyMode(not db.arrowHistory)
	if eb.SetHistoryLines then eb:SetHistoryLines(db.historySize) end
	if eb.hHistory then return end
	eb.hHistory = true
	hooksecurefunc(eb, "AddHistoryLine", function(_, line)
		if not CH.restoring then CH:Remember(line) end
	end)
	-- last session's lines, oldest first so Up brings the newest
	if db.historySave then
		self.restoring = true
		for _, line in ipairs(self:History()) do eb:AddHistoryLine(line) end
		self.restoring = false
	end
end

function CH:ClearHistory()
	wipe(self:History())
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if eb and eb.ClearHistory then eb:ClearHistory() end
	end
end

--[[ Timestamps: the game's setting, written from our page ]]

CH.TIMESTAMPS = {
	{ value = "none",          text = "None" },
	{ value = "%H:%M ",        text = "15:27" },
	{ value = "%H:%M:%S ",     text = "15:27:32" },
	{ value = "%I:%M ",        text = "03:27" },
	{ value = "%I:%M:%S ",     text = "03:27:32" },
	{ value = "%I:%M %p ",     text = "03:27 PM" },
	{ value = "%I:%M:%S %p ",  text = "03:27:32 PM" },
}

function CH:Timestamp()
	return GetCVar and GetCVar("showTimestamps") or "none"
end

function CH:SetTimestamp(v)
	if not SetCVar then return end
	SetCVar("showTimestamps", v)
	CHAT_TIMESTAMP_FORMAT = (v ~= "none") and v or nil
end
