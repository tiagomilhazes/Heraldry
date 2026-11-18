--[[
	Heraldry_DataBar - DataBar.lua
	A thin flat bar along the top (or bottom) edge of the screen (prototype D1,
	level 3 of the visual hierarchy: flat, dark, a thin rim). Its inner edge is
	the theme's rail, lit by experience (gold) with the rested part in blue; at
	the level cap (or always, option) it follows the watched reputation.

	Three slots, left / centre / right, hold blocks; each block has a place, an
	order and options of its own (settings "<block>Place", "<block>Order", ...):
	  micro       the game's micro menu buttons, scaled to the bar
	  xp          level and experience (or the watched reputation)
	  gold        money
	  bags        bag slots; click opens the bags
	  durability  the most worn item
	  perf        frames per second and latency
	  clock       the time (off by default: the minimap shows it)
	  zone        the zone / subzone
	  coords      the player's map coordinates
	  friends     friends online; click opens the friends list
	  guild       guild members online; click opens the guild
	The game's experience/reputation bars and bag buttons are hidden (option).
]]

local H = Heraldry
local Themes = H.Themes

local DB = H:NewModule("DataBar", {
	label = "Data bar",
	fonts = true,
	defaults = {
		-- bar
		edge = "top",            -- top | bottom
		height = 30,
		widthMode = "full",      -- full | fixed
		width = 1200,
		offsetY = 0,
		background = "flat",     -- flat | dark | light | glass (papers)
		bgAlpha = 0.85,
		bgColor = { 0.035, 0.03, 0.025 },
		rim = true,              -- thin line on the inner edge (when the rail is off)
		rimOuter = false,        -- a thin line on the outer edge too
		strata = "MEDIUM",
		-- rail
		rail = true,
		railSize = 8,
		railPlace = "inner",     -- inner | outer
		railDim = 0.3,
		xpColor = { 1.00, 0.92, 0.75 },
		restColor = { 0.40, 0.55, 0.95 },
		repColor = { 0.45, 0.85, 0.45 },
		railRep = "cap",         -- cap (only at the level cap) | always | never
		-- text
		textSize = 15,
		gap = 22,
		pad = 12,
		labels = true,           -- "Bags", "Armour"... before the values
		labelColor = { 0.85, 0.80, 0.70 },
		valueColors = true,      -- green/yellow/red for bags, durability, latency
		separator = "·",
		-- behaviour
		hideBlizzard = true,
		fade = false,            -- fade out when the mouse is away
		fadeAlpha = 0.25,
		hideCombat = false,
		tooltips = true,
		-- blocks
		microPlace = "left",      microOrder = 1,  microScale = 1,
		xpPlace = "center",       xpOrder = 1,     xpFormat = "percent", xpLevel = true, xpRested = true,
		goldPlace = "right",      goldOrder = 1,   goldFormat = "full",
		bagsPlace = "right",      bagsOrder = 2,   bagsFormat = "free", bagsWarn = 4,
		durabilityPlace = "right", durabilityOrder = 3, durabilityWarn = 0.3,
		perfPlace = "right",      perfOrder = 4,   perfFps = true, perfLatency = "max",
		clockPlace = "off",       clockOrder = 5,  clock24 = true, clockServer = false, clockSeconds = false,
		zonePlace = "off",        zoneOrder = 2,   zoneSub = true,
		coordsPlace = "off",      coordsOrder = 3, coordsDecimals = 1,
		friendsPlace = "off",     friendsOrder = 6,
		guildPlace = "off",       guildOrder = 7,
	},
})

DB.BLOCKS = {
	{ key = "micro", label = "Micro menu" },
	{ key = "xp", label = "Level and experience" },
	{ key = "gold", label = "Gold" },
	{ key = "bags", label = "Bags" },
	{ key = "durability", label = "Durability" },
	{ key = "perf", label = "FPS and latency" },
	{ key = "clock", label = "Clock" },
	{ key = "zone", label = "Zone" },
	{ key = "coords", label = "Coordinates" },
	{ key = "friends", label = "Friends online" },
	{ key = "guild", label = "Guild online" },
}

local hidden = CreateFrame("Frame")
hidden:Hide()

--[[ Values ]]

local function plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
local function hex(c) return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
local function num(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

local function maxLevel()
	return GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL or 60
end

-- the watched reputation: name, standing label, share (0-1), value, max
local function reputation()
	local name, standing, lo, hi, value
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local d = C_Reputation.GetWatchedFactionData()
		if d then name, standing, lo, hi, value = d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding end
	elseif GetWatchedFactionInfo then
		name, standing, lo, hi, value = GetWatchedFactionInfo()
	end
	if name and hi and lo and hi > lo then
		return name, _G["FACTION_STANDING_LABEL" .. (standing or 4)] or "", (value - lo) / (hi - lo), value - lo, hi - lo
	end
end

-- experience: share, rested share, cur, max, rested
local function experience()
	if UnitLevel("player") >= maxLevel() or (IsXPUserDisabled and IsXPUserDisabled()) then return nil end
	local cur, max = UnitXP("player"), UnitXPMax("player")
	if not (plain(cur) and plain(max)) or max <= 0 then return nil end
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	return cur / max, math.min(1 - cur / max, (rested or 0) / max), cur, max, rested or 0
end

-- what the rail shows: share, rested share, colours
function DB:RailProgress()
	local db = self.db
	local p, r = experience()
	if p and db.railRep ~= "always" then return p, r, db.xpColor, db.restColor end
	if db.railRep ~= "never" then
		local _, _, rp = reputation()
		if rp then return rp, 0, db.repColor end
	end
	if p then return p, r, db.xpColor, db.restColor end
	return 0, 0, db.xpColor
end

local function label(text)
	if not DB.db.labels then return "" end
	return ("|cff%s%s|r "):format(hex(DB.db.labelColor), text)
end

-- green / yellow / red for a share where higher is better
local function grade(p)
	if not DB.db.valueColors then return "ffffff" end
	if p >= 0.5 then return "9ccf7a" elseif p >= 0.2 then return "e8c35a" end
	return "e2604f"
end

local TEXT = {}

TEXT.xp = function(db)
	local sep = " " .. db.separator .. " "
	local p, r, cur, max = experience()
	if not p then
		local name, standing, rp = reputation()
		if name then return ("%s%s%s %d%%"):format(name, sep, standing, math.floor(rp * 100)) end
		return ("Level %d"):format(UnitLevel("player"))
	end
	local parts = {}
	if db.xpLevel then parts[#parts + 1] = ("Level %d"):format(UnitLevel("player")) end
	if db.xpFormat == "numbers" then
		parts[#parts + 1] = ("%s / %s"):format(num(cur), num(max))
	elseif db.xpFormat == "left" then
		parts[#parts + 1] = ("%s to go"):format(num(max - cur))
	elseif db.xpFormat == "both" then
		parts[#parts + 1] = ("%d%% (%s / %s)"):format(math.floor(p * 100), num(cur), num(max))
	else
		parts[#parts + 1] = ("%d%%"):format(math.floor(p * 100))
	end
	if db.xpRested and r > 0 then parts[#parts + 1] = ("|cff%srested %d%%|r"):format(hex(db.restColor), math.floor(r * 100)) end
	return table.concat(parts, sep)
end

TEXT.gold = function(db)
	local c = GetMoney()
	local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	local G, S, C = "|cffffd34a", "|cffd8d8d8", "|cffe0a070"
	if db.goldFormat == "short" then
		if g >= 1000 then return ("%s%.1fk g|r"):format(G, g / 1000) end
		if g > 0 then return ("%s%dg|r"):format(G, g) end
		return ("%s%ds|r"):format(S, s)
	elseif db.goldFormat == "gold" then
		return ("%s%sg|r"):format(G, num(g))
	elseif db.goldFormat == "icons" and GetCoinTextureString then
		return GetCoinTextureString(c, db.textSize)
	end
	local t = {}
	if g > 0 then t[#t + 1] = ("%s%sg|r"):format(G, num(g)) end
	if g > 0 or s > 0 then t[#t + 1] = ("%s%ds|r"):format(S, s) end
	t[#t + 1] = ("%s%dc|r"):format(C, k)
	return table.concat(t, " ")
end

local function bagSlots()
	local free, total = 0, 0
	for b = 0, NUM_BAG_SLOTS or 4 do
		local f = (C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots)(b)
		local t = (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(b)
		free, total = free + (f or 0), total + (t or 0)
	end
	return free, total
end

TEXT.bags = function(db)
	local free, total = bagSlots()
	local col = (db.valueColors and free <= db.bagsWarn) and "e2604f" or grade(total > 0 and free / total or 1)
	local v
	if db.bagsFormat == "used" then v = ("|cff%s%d|r/%d"):format(col, total - free, total)
	elseif db.bagsFormat == "freeOnly" then v = ("|cff%s%d|r"):format(col, free)
	else v = ("|cff%s%d|r/%d"):format(col, free, total) end
	return label("Bags") .. v
end

local function durability()
	local low
	for slot = 1, 18 do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then
			local p = cur / max
			if not low or p < low then low = p end
		end
	end
	return low
end

TEXT.durability = function(db)
	local d = durability()
	if not d then return label("Armour") .. "—" end
	local col = db.valueColors and (d <= db.durabilityWarn and "e2604f" or grade(d)) or "ffffff"
	return label("Armour") .. ("|cff%s%d%%|r"):format(col, math.floor(d * 100))
end

TEXT.perf = function(db)
	local t = {}
	if db.perfFps then t[#t + 1] = ("%d fps"):format(GetFramerate() or 0) end
	if db.perfLatency ~= "off" then
		local _, _, home, world = GetNetStats()
		local ms = db.perfLatency == "home" and home or db.perfLatency == "world" and world or math.max(home or 0, world or 0)
		ms = ms or 0
		local col = db.valueColors and (ms < 120 and "9ccf7a" or ms < 300 and "e8c35a" or "e2604f") or "ffffff"
		t[#t + 1] = ("|cff%s%d ms|r"):format(col, ms)
	end
	return table.concat(t, "  ")
end

TEXT.clock = function(db)
	local h, m, s
	if db.clockServer and GetGameTime then
		h, m = GetGameTime()
		s = 0
	else
		h, m, s = tonumber(date("%H")), tonumber(date("%M")), tonumber(date("%S"))
	end
	local sec = db.clockSeconds and (":%02d"):format(s) or ""
	if db.clock24 then return ("%02d:%02d%s"):format(h, m, sec) end
	return ("%d:%02d%s %s"):format((h - 1) % 12 + 1, m, sec, h < 12 and "am" or "pm")
end

TEXT.zone = function(db)
	local zone = GetRealZoneText and GetRealZoneText() or GetZoneText() or ""
	local sub = GetSubZoneText and GetSubZoneText() or ""
	if db.zoneSub and sub ~= "" and sub ~= zone then return zone .. " " .. db.separator .. " " .. sub end
	return zone
end

TEXT.coords = function(db)
	local ok, x, y = pcall(function()
		local map = C_Map.GetBestMapForUnit("player")
		local pos = map and C_Map.GetPlayerMapPosition(map, "player")
		if pos then return pos:GetXY() end
	end)
	if not ok or not x then return "—" end
	local f = "%." .. db.coordsDecimals .. "f"
	return (f .. ", " .. f):format(x * 100, y * 100)
end

TEXT.friends = function(db)
	local n = 0
	pcall(function()
		if C_FriendList and C_FriendList.GetNumOnlineFriends then n = C_FriendList.GetNumOnlineFriends() or 0
		elseif GetNumFriends then n = select(2, GetNumFriends()) or 0 end
	end)
	return label("Friends") .. n
end

TEXT.guild = function(db)
	if not IsInGuild() then return label("Guild") .. "—" end
	local _, online = GetNumGuildMembers()
	return label("Guild") .. (online or 0)
end

--[[ Building ]]

local function block(key)
	local b = CreateFrame("Button", nil, DB.frame)
	b.key = key
	b.text = b:CreateFontString(nil, "OVERLAY")
	b.text:SetPoint("CENTER")
	b.text:SetShadowColor(0, 0, 0, 1)
	b.text:SetShadowOffset(1, -1)
	b:SetHeight(1)
	b:RegisterForClicks("AnyUp")
	b:SetScript("OnEnter", function(self) if DB.db.tooltips then DB:Tip(self) end end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

function DB:Create()
	local f = CreateFrame("Frame", "HeraldryDataBar", UIParent)
	self.frame = f
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.line = f:CreateTexture(nil, "BORDER")
	f.outer = f:CreateTexture(nil, "BORDER")
	f.dim = f:CreateTexture(nil, "ARTWORK", nil, 0)
	f.lit = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.rest = f:CreateTexture(nil, "ARTWORK", nil, 1)

	self.blocks = {}
	for _, d in ipairs(self.BLOCKS) do self.blocks[d.key] = block(d.key) end
	local B = self.blocks
	B.bags:SetScript("OnClick", function() if ToggleAllBags then ToggleAllBags() end end)
	B.clock:SetScript("OnClick", function() if ToggleCalendar then pcall(ToggleCalendar) end end)
	B.friends:SetScript("OnClick", function() if ToggleFriendsFrame then pcall(ToggleFriendsFrame, 1) end end)
	B.guild:SetScript("OnClick", function()
		if ToggleGuildFrame then pcall(ToggleGuildFrame) elseif ToggleFriendsFrame then pcall(ToggleFriendsFrame, 3) end
	end)
	B.zone:SetScript("OnClick", function() if ToggleWorldMap then pcall(ToggleWorldMap) end end)
	B.coords:SetScript("OnClick", function() if ToggleWorldMap then pcall(ToggleWorldMap) end end)

	-- fading when the mouse is away
	f:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t or 0) + elapsed
		if self.t < 0.1 then return end
		self.t = 0
		local db = DB.db
		local want = (db.fade and not self:IsMouseOver()) and db.fadeAlpha or 1
		-- in combat: invisible (alpha only: the micro menu inside must not be hidden in combat)
		if db.hideCombat and DB.inCombat then want = 0 end
		local a = self:GetAlpha()
		if math.abs(a - want) > 0.01 then self:SetAlpha(a + (want - a) * 0.5) end
	end)
	return f
end

--[[ The micro menu: the game's own buttons, moved into the bar ]]

local function microContainer()
	return _G.MicroMenuContainer or _G.MicroMenu or _G.MicroButtonAndBagsBar
end

function DB:TakeMicro()
	local m = microContainer()
	local b = self.blocks.micro
	local on = self.db.microPlace ~= "off"
	if not m then
		b.width = 0
		return
	end
	if on then
		self.microParent = self.microParent or m:GetParent()
		m:SetParent(b)
		m:ClearAllPoints()
		m:SetPoint("LEFT", b, "LEFT", 0, 0)
		local h = m:GetHeight()
		local s = (h and h > 0 and (self.db.height - 2) / h or 0.6) * self.db.microScale
		m:SetScale(s)
		b.width = (m:GetWidth() or 200) * s
		if not self.hookedMicro then
			self.hookedMicro = true
			-- the game (Edit Mode, vehicles) puts it back: keep it here
			hooksecurefunc(m, "SetPoint", function(self)
				if DB.placing or DB.db.microPlace == "off" then return end
				DB.placing = true
				self:ClearAllPoints()
				self:SetPoint("LEFT", DB.blocks.micro, "LEFT", 0, 0)
				DB.placing = false
			end)
		end
	elseif self.microParent then
		m:SetParent(self.microParent)
		m:SetScale(1)
		b.width = 0
	end
end

--[[ The game's bars ]]

function DB:Blizzard()
	local hide = self.db.hideBlizzard
	self.moved = self.moved or {}
	-- Edit Mode's own status bar containers call their parent: they stay where
	-- they are and only go invisible (alpha 0, no mouse)
	for _, fr in ipairs({ _G.StatusTrackingBarManager, _G.MainStatusTrackingBarContainer, _G.SecondaryStatusTrackingBarContainer }) do
		if fr then
			if not fr.hHooked then
				fr.hHooked = true
				hooksecurefunc(fr, "SetAlpha", function(self, a)
					if DB.db.hideBlizzard and a > 0 and not self.hSetting then
						self.hSetting = true
						self:SetAlpha(0)
						self.hSetting = false
					end
				end)
			end
			fr.hSetting = true
			fr:SetAlpha(hide and 0 or 1)
			fr.hSetting = false
			pcall(fr.EnableMouse, fr, not hide)
		end
	end
	local list = {
		_G.MainMenuExpBar, _G.ReputationWatchBar, _G.MainMenuBarMaxLevelBar, _G.BagsBar,
		-- the bag buttons themselves (this client keeps them loose, not in BagsBar)
		_G.MainMenuBarBackpackButton, _G.KeyRingButton, _G.BagBarExpandToggle, _G.CharacterReagentBag0Slot,
	}
	for i = 0, 3 do list[#list + 1] = _G["CharacterBag" .. i .. "Slot"] end
	for _, fr in ipairs(list) do
		if fr then
			if hide and not self.moved[fr] then
				self.moved[fr] = fr:GetParent() or UIParent
				pcall(fr.SetParent, fr, hidden)
			elseif not hide and self.moved[fr] then
				pcall(fr.SetParent, fr, self.moved[fr])
				self.moved[fr] = nil
			end
		end
	end
end

--[[ Layout ]]

function DB:Layout()
	local f, db = self.frame, self.db
	if not f then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() DB:Layout() end, "databar-layout")
		return
	end
	local top = db.edge ~= "bottom"
	f:SetFrameStrata(db.strata)
	f:SetFrameLevel(2)
	f:ClearAllPoints()
	local y = top and -db.offsetY or db.offsetY
	if db.widthMode == "fixed" then
		f:SetPoint(top and "TOP" or "BOTTOM", UIParent, top and "TOP" or "BOTTOM", 0, y)
		f:SetWidth(db.width)
	else
		f:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", UIParent, top and "TOPLEFT" or "BOTTOMLEFT", 0, y)
		f:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", UIParent, top and "TOPRIGHT" or "BOTTOMRIGHT", 0, y)
	end
	f:SetHeight(db.height)

	-- background: flat colour, or one of the papers
	if db.background == "flat" then
		local c = db.bgColor
		f.bg:SetTexCoord(0, 1, 0, 1)
		f.bg:SetColorTexture(c[1], c[2], c[3], 1)
		f.bg:SetAlpha(db.bgAlpha)
	else
		H.Paper:Apply(f.bg, db.background, db.bgAlpha)
		local w = f:GetWidth()
		H.Paper:Crop(f.bg, db.background, (w and w > 0) and w or 1920, db.height)
	end

	-- the rail: on the inner edge (towards the screen's middle) or the outer one
	local piece = db.rail and Themes:Piece("bar.rail")
	local inner = db.railPlace ~= "outer"
	local bottomSide = (top and inner) or (not top and not inner)
	local edge = bottomSide and "BOTTOM" or "TOP"
	self.railEdge, self.railFlip = edge, not bottomSide
	local rh = db.railSize
	local oy = bottomSide and -rh / 2 or rh / 2
	for _, t in ipairs({ f.dim, f.lit, f.rest, f.line, f.outer }) do t:ClearAllPoints() end
	f.dim:SetPoint(edge .. "LEFT", f, edge .. "LEFT", 0, oy)
	f.dim:SetPoint(edge .. "RIGHT", f, edge .. "RIGHT", 0, oy)
	f.dim:SetHeight(rh)
	self.railPiece = piece
	if piece then
		for _, t in ipairs({ f.dim, f.lit, f.rest }) do
			t:SetTexture(piece.file, "REPEAT", "CLAMP")
			Themes:Paint(t)
		end
		f.dim:SetVertexColor(db.railDim, db.railDim * 0.9, db.railDim * 0.75)
		f.dim:SetDesaturation(0.6)
	else
		local r, g, b = Themes:Accent()
		f.dim:SetColorTexture((r or 0.8) * db.railDim, (g or 0.65) * db.railDim, (b or 0.3) * db.railDim, 1)
	end
	f.dim:SetShown(db.rail)

	-- thin lines in the theme's metal
	local r, g, b = Themes:Accent()
	r, g, b = r or 0.8, g or 0.65, b or 0.3
	local innerEdge = top and "BOTTOM" or "TOP"
	f.line:SetPoint(innerEdge .. "LEFT")
	f.line:SetPoint(innerEdge .. "RIGHT")
	f.line:SetHeight(1)
	f.line:SetColorTexture(r, g, b, 0.6)
	f.line:SetShown(db.rim and not (db.rail and inner))
	local outerEdge = top and "TOP" or "BOTTOM"
	f.outer:SetPoint(outerEdge .. "LEFT")
	f.outer:SetPoint(outerEdge .. "RIGHT")
	f.outer:SetHeight(1)
	f.outer:SetColorTexture(r, g, b, 0.6)
	f.outer:SetShown(db.rimOuter and not (db.rail and not inner))

	for _, bl in pairs(self.blocks) do
		H.Fonts:Apply(bl.text, "body", db.textSize, self)
		bl:SetHeight(db.height)
	end
	self:TakeMicro()
	self:Update()
	self:Blizzard()
	self:UpdateVisibility()
end

function DB:UpdateVisibility()
	-- the fade loop (OnUpdate) applies combat and mouseover alpha
end

-- places the blocks in their slots, by order
function DB:Arrange()
	local f, db = self.frame, self.db
	local slots = { left = {}, center = {}, right = {} }
	for _, d in ipairs(self.BLOCKS) do
		local bl = self.blocks[d.key]
		local place = db[d.key .. "Place"]
		bl:SetShown(slots[place] ~= nil)
		if slots[place] then table.insert(slots[place], bl) end
	end
	for _, list in pairs(slots) do
		table.sort(list, function(a, b) return (db[a.key .. "Order"] or 0) < (db[b.key .. "Order"] or 0) end)
	end
	local gap, pad = db.gap, db.pad
	local function width(bl)
		if bl.key == "micro" then return bl.width or 0 end
		return math.max(bl.text:GetStringWidth(), 1)
	end
	local x = pad
	for _, bl in ipairs(slots.left) do
		local w = width(bl)
		bl:ClearAllPoints()
		bl:SetPoint("LEFT", f, "LEFT", x, 0)
		bl:SetWidth(w)
		x = x + w + gap
	end
	x = pad
	for i = #slots.right, 1, -1 do
		local bl = slots.right[i]
		local w = width(bl)
		bl:ClearAllPoints()
		bl:SetPoint("RIGHT", f, "RIGHT", -x, 0)
		bl:SetWidth(w)
		x = x + w + gap
	end
	local total = 0
	for i, bl in ipairs(slots.center) do total = total + width(bl) + (i > 1 and gap or 0) end
	x = -total / 2
	for _, bl in ipairs(slots.center) do
		local w = width(bl)
		bl:ClearAllPoints()
		bl:SetPoint("LEFT", f, "CENTER", x, 0)
		bl:SetWidth(w)
		x = x + w + gap
	end
end

--[[ Updates ]]

function DB:UpdateRail()
	local f = self.frame
	if not f then return end
	if not self.db.rail then
		f.lit:Hide()
		f.rest:Hide()
		return
	end
	local p, r, litC, restC = self:RailProgress()
	local W = f:GetWidth()
	if not W or W <= 0 then return end
	local piece, rh = self.railPiece, self.db.railSize
	local edge, flip = self.railEdge, self.railFlip
	local oy = edge == "BOTTOM" and -rh / 2 or rh / 2
	local tileW, t1, t2
	if piece then
		tileW = piece.size[1] * rh / (piece.band[2] - piece.band[1])
		t1, t2 = piece.band[1] / piece.size[2], piece.band[2] / piece.size[2]
		if flip then f.dim:SetTexCoord(0, W / tileW, t2, t1) else f.dim:SetTexCoord(0, W / tileW, t1, t2) end
	end
	local function place(t, x0, x1, c)
		local w = (x1 - x0) * W
		t:ClearAllPoints()
		if not c or w < 1 then t:Hide() return end
		t:SetPoint(edge .. "LEFT", f, edge .. "LEFT", x0 * W, oy)
		t:SetSize(w, rh)
		if piece then
			local u0, u1 = x0 * W / tileW, x1 * W / tileW
			if flip then t:SetTexCoord(u0, u1, t2, t1) else t:SetTexCoord(u0, u1, t1, t2) end
			t:SetVertexColor(math.min(1, c[1] * 1.15), math.min(1, c[2] * 1.15), math.min(1, c[3] * 1.15))
			t:SetDesaturation(0.5)
		else
			t:SetColorTexture(c[1], c[2], c[3], 1)
		end
		t:Show()
	end
	place(f.lit, 0, p, litC)
	place(f.rest, p, p + (r or 0), restC)
end

function DB:Update()
	local B, db = self.blocks, self.db
	if not B then return end
	for key, fn in pairs(TEXT) do
		if db[key .. "Place"] ~= "off" then B[key].text:SetText(fn(db)) end
	end
	self:UpdateRail()
	self:Arrange()
end

-- the blocks that change by themselves (time, fps, position)
function DB:Tick()
	local B, db = self.blocks, self.db
	if not B then return end
	local changed = false
	for _, key in ipairs({ "perf", "clock", "coords", "zone" }) do
		if db[key .. "Place"] ~= "off" then
			local t = TEXT[key](db)
			if t ~= B[key].text:GetText() then
				B[key].text:SetText(t)
				changed = true
			end
		end
	end
	if changed then self:Arrange() end
end

-- block tooltips
function DB:Tip(b)
	local top = self.db.edge ~= "bottom"
	GameTooltip:SetOwner(b, top and "ANCHOR_BOTTOM" or "ANCHOR_TOP")
	GameTooltip:ClearLines()
	local k = b.key
	if k == "xp" then
		local p, r, cur, max, rested = experience()
		GameTooltip:AddLine(("Level %d"):format(UnitLevel("player")), 1, 0.82, 0.3)
		if p then
			GameTooltip:AddDoubleLine("Experience", ("%s / %s"):format(num(cur), num(max)), 1, 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine("To level", num(max - cur), 1, 1, 1, 1, 1, 1)
			if rested > 0 then GameTooltip:AddDoubleLine("Rested", num(rested), 0.5, 0.65, 1, 0.5, 0.65, 1) end
		end
		local name, standing, _, v, m = reputation()
		if name then GameTooltip:AddDoubleLine(name, ("%s  %s / %s"):format(standing, num(v), num(m)), 0.5, 0.9, 0.5, 1, 1, 1) end
	elseif k == "bags" then
		local free, total = bagSlots()
		GameTooltip:AddLine("Bags", 1, 0.82, 0.3)
		GameTooltip:AddDoubleLine("Free", free .. " / " .. total, 1, 1, 1, 1, 1, 1)
		GameTooltip:AddLine("Click to open the bags.", 0.7, 0.7, 0.7)
	elseif k == "durability" then
		GameTooltip:AddLine("Durability", 1, 0.82, 0.3)
		for slot = 1, 18 do
			local cur, max = GetInventoryItemDurability(slot)
			if cur and max and max > 0 and cur < max then
				GameTooltip:AddDoubleLine(GetInventoryItemLink("player", slot) or ("Slot " .. slot), math.floor(cur / max * 100) .. "%", 1, 1, 1, 1, 1, 1)
			end
		end
	elseif k == "perf" then
		local _, _, home, world = GetNetStats()
		GameTooltip:AddLine("Performance", 1, 0.82, 0.3)
		GameTooltip:AddDoubleLine("Frame rate", ("%d fps"):format(GetFramerate() or 0), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("Latency (home)", (home or 0) .. " ms", 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("Latency (world)", (world or 0) .. " ms", 1, 1, 1, 1, 1, 1)
	elseif k == "gold" then
		GameTooltip:AddLine("Gold", 1, 0.82, 0.3)
		GameTooltip:AddLine(GetCoinTextureString and GetCoinTextureString(GetMoney()) or TEXT.gold(self.db), 1, 1, 1)
	elseif k == "clock" then
		GameTooltip:AddLine("Time", 1, 0.82, 0.3)
		local h, m = GetGameTime()
		GameTooltip:AddDoubleLine("Server", ("%02d:%02d"):format(h, m), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("Local", date("%H:%M"), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddLine("Click for the calendar.", 0.7, 0.7, 0.7)
	elseif k == "friends" then
		GameTooltip:AddLine("Friends", 1, 0.82, 0.3)
		GameTooltip:AddLine("Click to open the friends list.", 0.7, 0.7, 0.7)
	elseif k == "guild" then
		GameTooltip:AddLine(GetGuildInfo and GetGuildInfo("player") or "Guild", 1, 0.82, 0.3)
		GameTooltip:AddLine("Click to open the guild.", 0.7, 0.7, 0.7)
	elseif k == "zone" or k == "coords" then
		GameTooltip:AddLine(TEXT.zone(self.db), 1, 0.82, 0.3)
		GameTooltip:AddLine("Click for the world map.", 0.7, 0.7, 0.7)
	else
		return
	end
	GameTooltip:Show()
end

--[[ Lifecycle ]]

function DB:OnEnable()
	self:Create()
	self:Layout()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "UPDATE_FACTION",
		"PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD",
		"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, e)
		if e == "PLAYER_ENTERING_WORLD" then
			DB:Layout()
			C_Timer.After(2, function() DB:Layout() end)
		elseif e == "PLAYER_REGEN_DISABLED" then
			DB.inCombat = true
			DB:UpdateVisibility()
		elseif e == "PLAYER_REGEN_ENABLED" then
			DB.inCombat = false
			DB:UpdateVisibility()
		else
			DB:Update()
		end
	end)
	C_Timer.NewTicker(1, function() DB:Tick() end)
	self.frame:SetScript("OnSizeChanged", function() DB:UpdateRail() end)
	H:On("THEME_CHANGED", function() DB:Layout() end)
	H:On("FONTS_CHANGED", function() DB:Layout() end)
end

function DB:OnProfileChanged()
	self:Layout()
end
