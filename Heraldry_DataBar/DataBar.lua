--[[
	Heraldry_DataBar - DataBar.lua
	A thin flat bar along the top (or bottom) edge of the screen, end to end
	(prototype D1, level 3 of the visual hierarchy: flat, dark, a thin rim).
	Its inner edge is the theme's rail, lit by experience (gold) with the rested
	part in blue; at the level cap it follows the watched reputation instead.

	Three slots, left / centre / right, hold blocks; each block has a place and
	an order (settings "<block>Place", "<block>Order"):
	  micro       the game's micro menu buttons, scaled to the bar
	  xp          level and experience (or the watched reputation)
	  gold        money
	  bags        free and total bag slots; click opens the bags
	  durability  the most worn item, coloured
	  perf        frames per second and latency
	  clock       the time (off by default: the minimap shows it)
	The game's experience/reputation bars and bag bar are hidden (option).
]]

local H = Heraldry
local Themes = H.Themes

local DB = H:NewModule("DataBar", {
	label = "Data bar",
	fonts = true,
	defaults = {
		edge = "top",            -- top | bottom
		height = 22,
		bgAlpha = 0.85,
		rail = true,
		railSize = 6,
		textSize = 11,
		gap = 18,
		hideBlizzard = true,
		microPlace = "left",      microOrder = 1,
		xpPlace = "center",       xpOrder = 1,
		goldPlace = "right",      goldOrder = 1,
		bagsPlace = "right",      bagsOrder = 2,
		durabilityPlace = "right", durabilityOrder = 3,
		perfPlace = "right",      perfOrder = 4,
		clockPlace = "off",       clockOrder = 5,
		clock24 = true,
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
}

local hidden = CreateFrame("Frame")
hidden:Hide()

local XP_GOLD = { 0.90, 0.72, 0.30 }
local RESTED = { 0.40, 0.55, 0.95 }

--[[ Values ]]

local function plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function maxLevel()
	local m = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL or 60
	return m
end

-- share of the bar lit (0-1), the rested share after it, and the text
function DB:Progress()
	local level = UnitLevel("player")
	if level < maxLevel() and not (IsXPUserDisabled and IsXPUserDisabled()) then
		local cur, max = UnitXP("player"), UnitXPMax("player")
		if not (plain(cur) and plain(max)) or max <= 0 then return 0, 0, ("Level %d"):format(level) end
		local rested = GetXPExhaustion and GetXPExhaustion() or 0
		local p = cur / max
		local r = math.min(1 - p, (rested or 0) / max)
		local text = ("Level %d  ·  %d%%"):format(level, math.floor(p * 100))
		if r > 0 then text = text .. ("  ·  rested %d%%"):format(math.floor(r * 100)) end
		return p, r, text, cur, max, rested
	end
	-- at the cap: the watched reputation
	local name, standing, lo, hi, value
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local d = C_Reputation.GetWatchedFactionData()
		if d then name, standing, lo, hi, value = d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding end
	elseif GetWatchedFactionInfo then
		name, standing, lo, hi, value = GetWatchedFactionInfo()
	end
	if name and hi and lo and hi > lo then
		local p = (value - lo) / (hi - lo)
		local label = _G["FACTION_STANDING_LABEL" .. (standing or 4)] or ""
		return p, 0, ("%s  ·  %s %d%%"):format(name, label, math.floor(p * 100))
	end
	return 0, 0, ("Level %d"):format(level)
end

local function money()
	local c = GetMoney()
	local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	if g > 0 then return ("|cffffd34a%sg|r |cffd8d8d8%ds|r"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, s) end
	if s > 0 then return ("|cffd8d8d8%ds|r |cffe0a070%dc|r"):format(s, k) end
	return ("|cffe0a070%dc|r"):format(k)
end

local function bags()
	local free, total = 0, 0
	local n = NUM_BAG_SLOTS or 4
	for b = 0, n do
		local f = (C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots)(b)
		local t = (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(b)
		free, total = free + (f or 0), total + (t or 0)
	end
	return free, total
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

local function colourFor(p)
	if p >= 0.5 then return "9ccf7a" elseif p >= 0.2 then return "e8c35a" end
	return "e2604f"
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
	b:SetScript("OnEnter", function(self) if self.tip then DB:Tip(self) end end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

function DB:Create()
	local f = CreateFrame("Frame", "HeraldryDataBar", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(2)
	self.frame = f
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.line = f:CreateTexture(nil, "BORDER")
	f.dim = f:CreateTexture(nil, "ARTWORK", nil, 0)
	f.lit = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.rest = f:CreateTexture(nil, "ARTWORK", nil, 1)

	self.blocks = {}
	for _, d in ipairs(self.BLOCKS) do self.blocks[d.key] = block(d.key) end
	local B = self.blocks
	B.xp.tip = "xp"
	B.bags:SetScript("OnClick", function() if ToggleAllBags then ToggleAllBags() end end)
	B.bags.tip = "bags"
	B.durability.tip = "durability"
	B.perf.tip = "perf"
	B.clock:SetScript("OnClick", function() if ToggleCalendar then pcall(ToggleCalendar) end end)
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
		local s = h and h > 0 and (self.db.height - 2) / h or 0.6
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
	local list = {
		_G.StatusTrackingBarManager, _G.MainStatusTrackingBarContainer, _G.SecondaryStatusTrackingBarContainer,
		_G.MainMenuExpBar, _G.ReputationWatchBar, _G.MainMenuBarMaxLevelBar, _G.BagsBar,
	}
	-- with the micro menu in our bar, the bag buttons go too (our block opens the bags)
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
	f:ClearAllPoints()
	f:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", UIParent, top and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
	f:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", UIParent, top and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
	f:SetHeight(db.height)
	f.bg:SetColorTexture(0.035, 0.03, 0.025, db.bgAlpha)

	-- the inner edge: the theme's rail (dim, lit by progress), or a thin line
	local piece = db.rail and Themes:Piece("bar.rail")
	local rh = db.railSize
	for _, t in ipairs({ f.dim, f.lit, f.rest, f.line }) do t:ClearAllPoints() end
	local edge = top and "BOTTOM" or "TOP"
	f.dim:SetPoint(edge .. "LEFT", f, edge .. "LEFT", 0, top and -rh / 2 or rh / 2)
	f.dim:SetPoint(edge .. "RIGHT", f, edge .. "RIGHT", 0, top and -rh / 2 or rh / 2)
	f.dim:SetHeight(rh)
	self.railPiece = piece
	if piece then
		for _, t in ipairs({ f.dim, f.lit, f.rest }) do
			t:SetTexture(piece.file, "REPEAT", "CLAMP")
			Themes:Paint(t)
		end
		f.dim:SetVertexColor(0.3, 0.27, 0.22)
		f.dim:SetDesaturation(0.6)
	else
		local r, g, b = Themes:Accent()
		f.dim:SetColorTexture((r or 0.8) * 0.3, (g or 0.65) * 0.3, (b or 0.3) * 0.3, 1)
		f.lit:SetColorTexture(XP_GOLD[1], XP_GOLD[2], XP_GOLD[3], 1)
		f.rest:SetColorTexture(RESTED[1], RESTED[2], RESTED[3], 1)
	end
	f.line:SetPoint(edge .. "LEFT")
	f.line:SetPoint(edge .. "RIGHT")
	f.line:SetHeight(1)
	local r, g, b = Themes:Accent()
	f.line:SetColorTexture(r or 0.8, g or 0.65, b or 0.3, 0.6)
	f.line:SetShown(not piece)
	f.dim:SetShown(db.rail)

	-- blocks
	for key, bl in pairs(self.blocks) do
		H.Fonts:Apply(bl.text, "body", db.textSize, self)
		bl:SetHeight(db.height)
	end
	self:TakeMicro()
	self:Update()
	self:Arrange()
	self:Blizzard()
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
	local gap, pad = db.gap, 10
	local function width(bl)
		if bl.key == "micro" then return bl.width or 0 end
		return math.max(bl.text:GetStringWidth(), 1)
	end
	-- left: from the left edge
	local x = pad
	for _, bl in ipairs(slots.left) do
		local w = width(bl)
		bl:ClearAllPoints()
		bl:SetPoint("LEFT", f, "LEFT", x, 0)
		bl:SetWidth(w)
		x = x + w + gap
	end
	-- right: from the right edge
	x = pad
	for i = #slots.right, 1, -1 do
		local bl = slots.right[i]
		local w = width(bl)
		bl:ClearAllPoints()
		bl:SetPoint("RIGHT", f, "RIGHT", -x, 0)
		bl:SetWidth(w)
		x = x + w + gap
	end
	-- centre: the group centred on the screen
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
	if not f or not self.db.rail then
		if f then f.lit:Hide() f.rest:Hide() end
		return
	end
	local p, r = self:Progress()
	local W = f:GetWidth()
	if not W or W <= 0 then return end
	local piece, rh = self.railPiece, self.db.railSize
	local top = self.db.edge ~= "bottom"
	local edge = top and "BOTTOM" or "TOP"
	local oy = top and -rh / 2 or rh / 2
	local function place(t, x0, x1, light)
		local w = (x1 - x0) * W
		t:ClearAllPoints()
		if w < 1 then t:Hide() return end
		t:SetPoint(edge .. "LEFT", f, edge .. "LEFT", x0 * W, oy)
		t:SetSize(w, rh)
		if piece then
			-- tiles lined up with the dim rail under it
			local tileW = piece.size[1] * rh / ((piece.band[2] - piece.band[1]))
			local t1, t2 = piece.band[1] / piece.size[2], piece.band[2] / piece.size[2]
			local u0, u1 = x0 * W / tileW, x1 * W / tileW
			if top then t:SetTexCoord(u0, u1, t1, t2) else t:SetTexCoord(u0, u1, t2, t1) end
			t:SetVertexColor(light[1] * 1.15, light[2] * 1.15, light[3] * 1.15)
			t:SetDesaturation(0.5)
		end
		t:Show()
	end
	place(f.lit, 0, p, piece and { 1, 0.92, 0.75 } or XP_GOLD)
	place(f.rest, p, p + r, RESTED)
	if piece then
		local tileW = piece.size[1] * rh / ((piece.band[2] - piece.band[1]))
		local t1, t2 = piece.band[1] / piece.size[2], piece.band[2] / piece.size[2]
		if top then f.dim:SetTexCoord(0, W / tileW, t1, t2) else f.dim:SetTexCoord(0, W / tileW, t2, t1) end
	end
end

function DB:Update()
	local B = self.blocks
	if not B then return end
	local _, _, xpText = self:Progress()
	B.xp.text:SetText(xpText)
	B.gold.text:SetText(money())
	local free, total = bags()
	B.bags.text:SetFormattedText("Bags |cff%s%d|r/%d", colourFor(total > 0 and free / total or 1), free, total)
	local d = durability()
	if d then
		B.durability.text:SetFormattedText("Armour |cff%s%d%%|r", colourFor(d), math.floor(d * 100))
	else
		B.durability.text:SetText("Armour —")
	end
	self:UpdatePerf()
	self:UpdateClock()
	self:UpdateRail()
end

function DB:UpdatePerf()
	local fps = GetFramerate() or 0
	local _, _, home, world = GetNetStats()
	local ms = math.max(home or 0, world or 0)
	self.blocks.perf.text:SetFormattedText("%d fps  |cff%s%d ms|r", fps, ms < 120 and "9ccf7a" or ms < 300 and "e8c35a" or "e2604f", ms)
end

function DB:UpdateClock()
	local h, m = tonumber(date("%H")), tonumber(date("%M"))
	if self.db.clock24 then
		self.blocks.clock.text:SetFormattedText("%02d:%02d", h, m)
	else
		self.blocks.clock.text:SetFormattedText("%d:%02d %s", (h - 1) % 12 + 1, m, h < 12 and "am" or "pm")
	end
end

-- block tooltips
function DB:Tip(b)
	local top = self.db.edge ~= "bottom"
	GameTooltip:SetOwner(b, top and "ANCHOR_BOTTOM" or "ANCHOR_TOP")
	GameTooltip:ClearLines()
	if b.tip == "xp" then
		local p, r, text, cur, max, rested = self:Progress()
		GameTooltip:AddLine(text, 1, 0.82, 0.3)
		if cur and max then
			GameTooltip:AddDoubleLine("Experience", ("%s / %s"):format(BreakUpLargeNumbers(cur), BreakUpLargeNumbers(max)), 1, 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine("To level", BreakUpLargeNumbers(max - cur), 1, 1, 1, 1, 1, 1)
			if rested and rested > 0 then GameTooltip:AddDoubleLine("Rested", BreakUpLargeNumbers(rested), 0.5, 0.65, 1, 0.5, 0.65, 1) end
		end
	elseif b.tip == "bags" then
		local free, total = bags()
		GameTooltip:AddLine("Bags", 1, 0.82, 0.3)
		GameTooltip:AddDoubleLine("Free", free .. " / " .. total, 1, 1, 1, 1, 1, 1)
		GameTooltip:AddLine("Click to open the bags.", 0.7, 0.7, 0.7)
	elseif b.tip == "durability" then
		GameTooltip:AddLine("Durability", 1, 0.82, 0.3)
		for slot = 1, 18 do
			local cur, max = GetInventoryItemDurability(slot)
			if cur and max and max > 0 and cur < max then
				local link = GetInventoryItemLink("player", slot)
				GameTooltip:AddDoubleLine(link or ("Slot " .. slot), math.floor(cur / max * 100) .. "%", 1, 1, 1, 1, 1, 1)
			end
		end
	elseif b.tip == "perf" then
		local _, _, home, world = GetNetStats()
		GameTooltip:AddLine("Performance", 1, 0.82, 0.3)
		GameTooltip:AddDoubleLine("Frame rate", ("%d fps"):format(GetFramerate() or 0), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("Latency (home)", (home or 0) .. " ms", 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("Latency (world)", (world or 0) .. " ms", 1, 1, 1, 1, 1, 1)
	end
	GameTooltip:Show()
end

--[[ Lifecycle ]]

function DB:OnEnable()
	self:Create()
	self:Layout()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "UPDATE_FACTION",
		"PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, e)
		if e == "PLAYER_ENTERING_WORLD" then
			DB:Layout()
			C_Timer.After(2, function() DB:Layout() end)
		else
			DB:Update()
			DB:Arrange()
		end
	end)
	C_Timer.NewTicker(1, function()
		DB:UpdatePerf()
		DB:UpdateClock()
	end)
	-- the width of the screen (UI scale, resolution) changes the lit share
	self.frame:SetScript("OnSizeChanged", function() DB:UpdateRail() end)
	H:On("THEME_CHANGED", function() DB:Layout() end)
	H:On("FONTS_CHANGED", function() DB:Layout() end)
end

function DB:OnProfileChanged()
	self:Layout()
end
