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
	{ key = "GUILD",           label = "Guild",              name = "Guild",            short = "G" },
	{ key = "OFFICER",         label = "Officer",            name = "Officer",          short = "O" },
	{ key = "PARTY",           label = "Party",              name = "Party",            short = "P" },
	{ key = "PARTY_LEADER",    label = "Party leader",       name = "Party Leader",     short = "PL" },
	{ key = "RAID",            label = "Raid",               name = "Raid",             short = "R" },
	{ key = "RAID_LEADER",     label = "Raid leader",        name = "Raid Leader",      short = "RL" },
	{ key = "RAID_WARNING",    label = "Raid warning",       name = "Raid Warning",     short = "RW" },
	{ key = "INSTANCE",        label = "Instance",           name = "Instance",         short = "I" },
	{ key = "INSTANCE_LEADER", label = "Instance leader",    name = "Instance Leader",  short = "IL" },
	{ key = "General",         label = "General",            numbered = true,           short = "Gen" },
	{ key = "Trade",           label = "Trade",              numbered = true,           short = "T" },
	{ key = "LocalDefense",    label = "Local defense",      numbered = true,           short = "LD" },
	{ key = "LookingForGroup", label = "Looking for group",  numbered = true,           short = "LFG" },
	{ key = "WorldDefense",    label = "World defense",      numbered = true,           short = "WD" },
	{ key = "GuildRecruitment", label = "Guild recruitment", numbered = true,           short = "GR" },
	{ key = "Services",        label = "Services",           numbered = true,           short = "S" },
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

	-- the game's timestamp, faded
	if db.timeDim then
		local c = self:Paper().text and { 0.45, 0.38, 0.28 } or { 0.55, 0.52, 0.47 }
		local hex = ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
		text = text:gsub("^(%d+:%d+[:%d]*%s?[AaPp]?[Mm]?) ", "|cff" .. hex .. "%1|r ", 1)
	end
	return text
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
