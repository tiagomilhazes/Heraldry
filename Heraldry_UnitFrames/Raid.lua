--[[
	Heraldry_UnitFrames - Raid.lua
	The raid, groups side by side in rows ("Groups per row", default 4), in two
	styles:

	  style "banner" (default, prototype R3)
	      each row of groups is one parchment sheet hanging from the theme's rod.
	      Click the rod to roll the row up (the members hide, the rod and a strip
	      "Groups 1-4 · 18" stay) and again to open it. The toggle is a secure
	      snippet, so it works in combat too (instantly; there is no animation).
	      A rolled row's rod pulses red when one of its members dies.
	  style "tiles" (prototype R2)
	      every group in one framed panel, members as tiles: life in the class
	      colour, the name and the percentage on it, the rim lit by a debuff.

	Members are the game's secure group headers (one per group, its buttons
	made by the game as the roster changes); we only dress the buttons. Click:
	target, right click: menu; registered for click-casting. Dead, ghost and
	offline members show it; out of range ones fade. Shown only in a raid
	(container state driver); the game's raid frames are hidden. Preview: made-up
	members without a raid. Settings use the prefix "raid".
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames
local Themes = H.Themes

local FLAT = "Interface\\Buttons\\WHITE8X8"
local GROUPS, PER_GROUP = 8, 5

local hidden = CreateFrame("Frame")
hidden:Hide()

local DEFAULTS = {
	raidShow = true,
	raidStyle = "banner",        -- "banner" | "tiles"
	raidWidth = 120,
	raidHeight = 30,
	raidSpacing = 4,
	raidGroupSpacing = 14,
	raidGroupsPerRow = 4,
	raidRodSize = 16,
	raidPaper = "dark",
	raidPower = true,
	raidPowerHeight = 4,
	raidNameSize = 11,
	raidPctShow = true,
	raidPctSize = 10,
	raidMuted = true,
	raidDebuff = true,
	raidDispelOnly = true,
	raidRange = true,
	raidRangeAlpha = 0.4,
	raidWarn = true,
	raidShowEmpty = false,
	raidHideBlizzard = true,
}
for k, v in pairs(DEFAULTS) do UF.defaults[k] = v end

local DEBUFF = {
	Magic   = { 0.20, 0.60, 1.00 },
	Curse   = { 0.60, 0.00, 1.00 },
	Disease = { 0.60, 0.40, 0.00 },
	Poison  = { 0.00, 0.60, 0.00 },
}

local R = { groups = {}, rows = {}, buttons = {}, byUnit = {}, fakes = {} }
UF.raid = R

local function db() return UF.db end

local function classRGB(class)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
	return 0.7, 0.7, 0.7
end

local function mute(r, g, b, f)
	local grey = (r + g + b) / 3
	local function m(c) return (c + (grey - c) * 0.3) * (f or 0.72) end
	return m(r), m(g), m(b)
end

local function accent()
	local r, g, b = Themes:Accent()
	if not r then r, g, b = 0.85, 0.66, 0.3 end
	return r, g, b
end

--[[ A member: dresses any frame (the game's secure buttons, or a preview frame) ]]

local function dress(b)
	if b.hDressed then return end
	b.hDressed = true
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.04, 0.03, 0.025, 0.85)
	b.life = CreateFrame("StatusBar", nil, b)
	b.life:SetStatusBarTexture(FLAT)
	b.power = CreateFrame("StatusBar", nil, b)
	b.power:SetStatusBarTexture(FLAT)
	b.power:SetStatusBarColor(0.2, 0.32, 0.8)
	b.rim = {}
	for i = 1, 4 do
		local t = b:CreateTexture(nil, "OVERLAY", nil, 2)
		t:SetColorTexture(1, 1, 1, 1)
		b.rim[i] = t
	end
	local top = CreateFrame("Frame", nil, b)
	top:SetAllPoints()
	top:SetFrameLevel(b.life:GetFrameLevel() + 3)
	b.name = top:CreateFontString(nil, "OVERLAY")
	b.pct = top:CreateFontString(nil, "OVERLAY")
	for _, fs in ipairs({ b.name, b.pct }) do
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
		fs:SetWordWrap(false)
	end
	b.gem = top:CreateTexture(nil, "OVERLAY")
	b.gem:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	b.gem:Hide()
end

local function rimAround(b, pad)
	local L = b.rim
	for _, t in ipairs(L) do t:ClearAllPoints() end
	L[1]:SetPoint("TOPLEFT", -pad, pad); L[1]:SetPoint("TOPRIGHT", pad, pad); L[1]:SetHeight(1)
	L[2]:SetPoint("BOTTOMLEFT", -pad, -pad); L[2]:SetPoint("BOTTOMRIGHT", pad, -pad); L[2]:SetHeight(1)
	L[3]:SetPoint("TOPLEFT", -pad, pad); L[3]:SetPoint("BOTTOMLEFT", -pad, -pad); L[3]:SetWidth(1)
	L[4]:SetPoint("TOPRIGHT", pad, pad); L[4]:SetPoint("BOTTOMRIGHT", pad, -pad); L[4]:SetWidth(1)
end

-- places a member's parts for the current style and size
local function layoutMember(b)
	local d = db()
	dress(b)
	local tiles = d.raidStyle == "tiles"
	local ph = d.raidPower and d.raidPowerHeight or 0
	b.life:ClearAllPoints()
	b.life:SetPoint("TOPLEFT", 1, -1)
	b.life:SetPoint("BOTTOMRIGHT", -1, ph + 1)
	b.power:ClearAllPoints()
	b.power:SetPoint("BOTTOMLEFT", 1, 1)
	b.power:SetPoint("BOTTOMRIGHT", -1, 1)
	b.power:SetHeight(math.max(ph, 0.01))
	b.power:SetShown(d.raidPower)
	H.Fonts:Apply(b.name, "body", d.raidNameSize, UF)
	H.Fonts:Apply(b.pct, "body", d.raidPctSize, UF)
	b.name:ClearAllPoints()
	b.pct:ClearAllPoints()
	if tiles then
		b.name:SetPoint("CENTER", b, "CENTER", 0, d.raidPctShow and 4 or 0)
		b.name:SetWidth(d.raidWidth - 6)
		b.pct:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
	else
		b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -3)
		b.name:SetWidth(d.raidWidth - 22)
		b.name:SetJustifyH("LEFT")
		b.pct:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1)
	end
	b.name:SetJustifyH(tiles and "CENTER" or "LEFT")
	b.pct:SetShown(d.raidPctShow)
	local gs = math.max(8, math.floor(d.raidHeight * 0.32))
	b.gem:SetSize(gs, gs)
	b.gem:ClearAllPoints()
	b.gem:SetPoint("RIGHT", b, "RIGHT", -5, ph / 2)
	rimAround(b, 0)
	local r, g, bl = accent()
	for _, t in ipairs(b.rim) do t:SetVertexColor(r * 0.55, g * 0.55, bl * 0.55) end
end

-- the debuff colour of a unit (nil when none, or when the game hides it)
local function debuffColor(unit)
	local found
	pcall(function()
		local filter = db().raidDispelOnly and "HARMFUL|RAID" or "HARMFUL"
		for i = 1, 40 do
			local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
			if not aura then break end
			local t = aura.dispelName
			if t and not (issecretvalue and issecretvalue(t)) and DEBUFF[t] then
				found = DEBUFF[t]
				break
			end
		end
	end)
	return found
end

local function showDebuff(b, c)
	local tiles = db().raidStyle == "tiles"
	if tiles then
		local r, g, bl = accent()
		for _, t in ipairs(b.rim) do
			if c then t:SetVertexColor(c[1], c[2], c[3]) else t:SetVertexColor(r * 0.55, g * 0.55, bl * 0.55) end
		end
		b.gem:Hide()
	else
		if c then b.gem:SetVertexColor(c[1], c[2], c[3]) end
		b.gem:SetShown(c ~= nil)
	end
end

-- paints a member from its unit, or from made-up data (p)
local function paint(b, unit, p)
	local d = db()
	local name, class, dead, off, cur, max, pw, pwMax
	if p then
		name, class, dead, off = p.name, p.class, p.life == 0, false
		cur, max, pw, pwMax = p.life, 1, 0.7, 1
	else
		name = UnitName(unit)
		local _, c = UnitClass(unit)
		class = c
		dead = UnitIsDeadOrGhost(unit)
		off = not UnitIsConnected(unit)
		cur, max = UnitHealth(unit), UnitHealthMax(unit)
		pw, pwMax = UnitPower(unit), UnitPowerMax(unit)
	end
	local r, g, bl = classRGB(class)
	local fr, fg, fb = r, g, bl
	if d.raidMuted then fr, fg, fb = mute(r, g, bl, d.raidStyle == "tiles" and 0.6 or 0.72) end
	b.life:SetStatusBarColor(fr, fg, fb)
	pcall(b.life.SetMinMaxValues, b.life, 0, max)
	pcall(b.life.SetValue, b.life, cur)
	pcall(b.power.SetMinMaxValues, b.power, 0, pwMax)
	pcall(b.power.SetValue, b.power, pw)
	b.name:SetText(name or "")
	if d.raidStyle == "tiles" then b.name:SetTextColor(r, g, bl) else b.name:SetTextColor(0.96, 0.92, 0.84) end
	b.pct:SetTextColor(0.86, 0.82, 0.74)
	if dead or off then
		b.life:SetValue(0)
		b.pct:SetText(off and "Offline" or "Dead")
		b.name:SetTextColor(0.55, 0.52, 0.5)
	elseif p then
		b.pct:SetText(p.life < 1 and ("%d%%"):format(p.life * 100) or "")
	else
		local ok = pcall(function()
			if UnitHealthPercent and CurveConstants then
				b.pct:SetFormattedText("%d%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
			else
				local v = cur / max * 100
				b.pct:SetText(v < 99.5 and ("%d%%"):format(v) or "")
			end
		end)
		if not ok then b.pct:SetText("") end
	end
	b.hDead = dead
	if d.raidDebuff then
		showDebuff(b, p and p.debuff and DEBUFF[p.debuff] or (not p and debuffColor(unit)))
	else
		showDebuff(b, nil)
	end
end

--[[ Groups and rows ]]

-- Groups sit side by side in rows ("Groups per row", default 4: a 40-man raid
-- is two rows, a 20-man one). In the banner style each row hangs from one rod
-- on one sheet of paper; clicking the rod rolls the whole row up (the sheet is
-- a protected frame holding the row's group headers, toggled by a secure
-- snippet, so it works in combat too).
local ROD_SNIPPET = [[
	local s = self:GetFrameRef("sheet")
	if s:IsShown() then s:Hide() else s:Show() end
]]

local function rodTexture(rod)
	rod.M = rod:CreateTexture(nil, "ARTWORK", nil, 0)
	rod.L = rod:CreateTexture(nil, "ARTWORK", nil, 1)
	rod.R = rod:CreateTexture(nil, "ARTWORK", nil, 1)
	rod.glow = rod:CreateTexture(nil, "OVERLAY")
	rod.glow:SetAllPoints()
	rod.glow:SetColorTexture(1, 0.12, 0.08, 0.5)
	rod.glow:SetBlendMode("ADD")
	rod.glow:Hide()
	rod.pulse = rod.glow:CreateAnimationGroup()
	rod.pulse:SetLooping("BOUNCE")
	local a = rod.pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.15)
	a:SetDuration(0.5)
end

-- the rod's cap width for a rod height (the paper tucks under the caps)
local function capWidth(h)
	local piece = Themes:Piece("scroll.rod")
	return piece and piece.capW * h / piece.size[2] or h * 0.9
end

-- the theme's scroll rod, the same as the quest scroll's (caps at the ends)
local function skinRod(rod, h, w)
	local piece = Themes:Piece("scroll.rod")
	rod:SetSize(w, h)
	if not piece then
		rod.M:SetColorTexture(accent())
		rod.M:ClearAllPoints()
		rod.M:SetPoint("LEFT")
		rod.M:SetPoint("RIGHT")
		rod.M:SetHeight(math.max(2, h * 0.4))
		rod.M:SetTexCoord(0, 1, 0, 1)
		rod.L:Hide()
		rod.R:Hide()
		return
	end
	local capW = capWidth(h)
	local cap = piece.capW / piece.size[1]
	rod.L:SetTexture(piece.cap)
	rod.L:SetTexCoord(0, cap, 0, 1)
	if piece.capR then
		rod.R:SetTexture(piece.capR)
		rod.R:SetTexCoord(1 - cap, 1, 0, 1)
	else
		rod.R:SetTexture(piece.cap)
		rod.R:SetTexCoord(cap, 0, 0, 1)
	end
	if piece.midW then rod.M:SetTexture(piece.mid, "REPEAT", "CLAMP") else rod.M:SetTexture(piece.mid) end
	for _, t in ipairs({ rod.L, rod.R, rod.M }) do Themes:Paint(t) t:Show() end
	rod.L:SetSize(capW, h)
	rod.R:SetSize(capW, h)
	rod.L:ClearAllPoints(); rod.L:SetPoint("LEFT")
	rod.R:ClearAllPoints(); rod.R:SetPoint("RIGHT")
	rod.M:ClearAllPoints()
	rod.M:SetPoint("TOPLEFT", rod.L, "TOPRIGHT", -2, 0)
	rod.M:SetPoint("BOTTOMRIGHT", rod.R, "BOTTOMLEFT", 2, 0)
	if piece.midW then
		local mw = w - 2 * capW + 4
		rod.M:SetTexCoord(0, mw > 0 and mw / (piece.midW * h / piece.size[2]) or 1, 0, 1)
	else
		rod.M:SetTexCoord(0, 1, 0, 1)
	end
end

local function initString()
	local d = db()
	return ([[
		self:SetWidth(%d)
		self:SetHeight(%d)
		self:SetAttribute("*type1", "target")
		self:SetAttribute("*type2", "togglemenu")
		self:GetParent():CallMethod("Dress", self:GetName())
	]]):format(math.floor(d.raidWidth + 0.5), math.floor(d.raidHeight + 0.5))
end

local function makeRow(r)
	local c = R.container
	local row = { index = r, groups = {} }
	-- the sheet holds the row's groups and its paper: hiding it rolls the row up
	local sheet = CreateFrame("Frame", nil, c, "SecureHandlerBaseTemplate")
	row.paper = sheet:CreateTexture(nil, "BACKGROUND", nil, -2)
	row.paper:SetAllPoints()
	row.edge = {}
	for i = 1, 4 do row.edge[i] = sheet:CreateTexture(nil, "BACKGROUND", nil, -1) end

	local rod = CreateFrame("Button", nil, c, "SecureHandlerClickTemplate")
	rod:RegisterForClicks("AnyUp")
	rod:SetFrameRef("sheet", sheet)
	rod:SetAttribute("_onclick", ROD_SNIPPET)
	rod:HookScript("PostClick", function()
		H.char.raidRolled = H.char.raidRolled or {}
		H.char.raidRolled[r] = not sheet:IsShown() or nil
		R:PaintRolled(row)
	end)
	rodTexture(rod)
	rod:SetFrameLevel(sheet:GetFrameLevel() + 10)
	-- shown under the rod while rolled up
	row.strip = CreateFrame("Frame", nil, rod)
	row.strip.paper = row.strip:CreateTexture(nil, "BACKGROUND")
	row.strip.paper:SetAllPoints()
	row.strip.text = row.strip:CreateFontString(nil, "OVERLAY")
	row.strip.text:SetPoint("CENTER", 0, 1)
	row.strip:Hide()

	row.sheet, row.rod = sheet, rod
	R.rows[r] = row
	return row
end

local function makeGroup(g)
	local G = { index = g }
	local h = CreateFrame("Frame", "HeraldryRaidGroup" .. g, R.container, "SecureGroupHeaderTemplate")
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	h:SetAttribute("showRaid", true)
	h:SetAttribute("groupFilter", tostring(g))
	h:SetAttribute("point", "TOP")
	h:SetAttribute("unitsPerColumn", PER_GROUP)
	h:SetAttribute("maxColumns", 1)
	h:SetAttribute("initialConfigFunction", initString())
	-- the game calls this for each button it makes (also in combat)
	h.Dress = function(header, name)
		local b = _G[name]
		if not b then return end
		layoutMember(b)
		R.buttons[#R.buttons + 1] = b
		b:HookScript("OnAttributeChanged", function(self, key, value)
			if key == "unit" then
				for u, btn in pairs(R.byUnit) do if btn == self then R.byUnit[u] = nil end end
				if value then R.byUnit[value] = self end
				R:UpdateButton(self)
			end
		end)
		local unit = b:GetAttribute("unit")
		if unit then R.byUnit[unit] = b end
		ClickCastFrames = ClickCastFrames or {}
		ClickCastFrames[b] = true
	end
	-- tiles style: a small group number over the column
	G.number = h:CreateFontString(nil, "OVERLAY")
	G.header = h
	h.G = G
	h:Show()
	R.groups[g] = G
	return G
end

-- the members of a group (real buttons in use, or preview ones)
local function members(G)
	local list = {}
	for i = 1, select("#", G.header:GetChildren()) do
		local b = select(i, G.header:GetChildren())
		if b.hDressed and b:IsShown() then list[#list + 1] = b end
	end
	return list
end

function R:PaintRolled(row)
	local rolled = not row.sheet:IsShown()
	local banner = db().raidStyle == "banner"
	row.strip:SetShown(banner and rolled and row.rod:IsShown())
	if banner and rolled then
		local n, used = 0, {}
		for _, G in ipairs(row.groups) do
			local m = #members(G)
			if m > 0 or db().raidShowEmpty then used[#used + 1] = G.index end
			n = n + m
		end
		local first, last = used[1] or row.groups[1].index, used[#used] or row.groups[#row.groups].index
		local label = first == last and ("Group %d"):format(first) or ("Groups %d–%d"):format(first, last)
		row.strip.text:SetText(("%s · %d"):format(label, n))
	end
	self:UpdateWarn(row)
end

-- a rolled row's rod pulses when a member in it is dead
function R:UpdateWarn(row)
	local warn = false
	if db().raidWarn and db().raidStyle == "banner" and not row.sheet:IsShown() then
		for _, G in ipairs(row.groups) do
			for _, b in ipairs(members(G)) do
				if b.hDead then warn = true end
			end
		end
	end
	row.rod.glow:SetShown(warn)
	if warn then
		if not row.rod.pulse:IsPlaying() then row.rod.pulse:Play() end
	else
		row.rod.pulse:Stop()
	end
end

--[[ Layout ]]

function UF:LayoutRaid()
	if not R.container then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() UF:LayoutRaid() end, "uf-raid-layout")
		return
	end
	local d = self.db
	local banner = d.raidStyle == "banner"
	local w, hgt, sp, gs = d.raidWidth, d.raidHeight, d.raidSpacing, d.raidGroupSpacing
	local rodH = banner and d.raidRodSize or 0
	local pad = banner and 8 or 6
	local top = banner and rodH / 2 + pad or 18          -- above the members: under the rod, or the group number
	local inset = banner and math.floor(capWidth(rodH) * 0.7) or 0
	local membersH = PER_GROUP * hgt + (PER_GROUP - 1) * sp
	local perRow = math.max(1, math.min(GROUPS, d.raidGroupsPerRow))
	local nRows = math.ceil(GROUPS / perRow)
	local rowH = (banner and rodH / 2 or 0) + top + membersH + pad
	local rowGap = banner and gs or 8
	local maxW = 0

	for _, row in pairs(R.rows) do
		row.groups = {}
		row.sheet:Hide()
		row.rod:Hide()
	end
	for r = 1, nRows do
		local row = R.rows[r] or makeRow(r)
		local first = (r - 1) * perRow + 1
		local count = math.min(perRow, GROUPS - first + 1)
		local sheetW = count * w + (count - 1) * gs + 2 * pad
		local y = -(r - 1) * (rowH + rowGap)
		local sheet, rod = row.sheet, row.rod
		maxW = math.max(maxW, sheetW + 2 * inset)

		rod:ClearAllPoints()
		rod:SetPoint("TOPLEFT", R.container, "TOPLEFT", 0, y)
		sheet:ClearAllPoints()
		if banner then
			skinRod(rod, rodH, sheetW + 2 * inset)
			sheet:SetPoint("TOPLEFT", rod, "TOPLEFT", inset, -rodH / 2)
			sheet:SetSize(sheetW, top + membersH + pad)
			row.strip:ClearAllPoints()
			row.strip:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, 0)
			row.strip:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", 0, 0)
			row.strip:SetHeight(rodH / 2 + 16)
			H.Paper:Apply(row.strip.paper, d.raidPaper, 0.95)
			H.Fonts:Apply(row.strip.text, "body", 10, UF)
			row.strip.text:ClearAllPoints()
			row.strip.text:SetPoint("BOTTOM", 0, 3)
			local ink = H.Paper:IsInk(d.raidPaper)
			row.strip.text:SetTextColor(ink and 0.2 or 0.9, ink and 0.13 or 0.78, ink and 0.06 or 0.55)
			H.Paper:Apply(row.paper, d.raidPaper, 0.96)
			H.Paper:Crop(row.paper, d.raidPaper, sheetW, top + membersH + pad)
			H.Paper:Shades(row.edge, d.raidPaper, 0.9, 6)
		else
			sheet:SetPoint("TOPLEFT", R.container, "TOPLEFT", 0, y)
			sheet:SetSize(sheetW, rowH)
		end
		row.paper:SetShown(banner)
		for _, t in ipairs(row.edge) do t:SetShown(banner) end

		for i = 1, count do
			local g = first + i - 1
			local G = R.groups[g] or makeGroup(g)
			local h = G.header
			G.row = row
			row.groups[i] = G
			h:SetParent(sheet)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", sheet, "TOPLEFT", pad + (i - 1) * (w + gs), -top)
			h:SetAttribute("yOffset", -sp)
			h:SetAttribute("initialConfigFunction", initString())
			for j = 1, select("#", h:GetChildren()) do
				local b = select(j, h:GetChildren())
				if b.hDressed then
					b:SetSize(w, hgt)
					layoutMember(b)
				end
			end
			-- tiles: the group number over the column
			G.number:ClearAllPoints()
			G.number:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 1, 3)
			H.Fonts:Apply(G.number, "header", 11, UF)
			G.number:SetTextColor(accent())
			G.number:SetText(g)
		end
	end
	R.nRows = nRows

	-- the container and the tiles' panel
	R.container:SetSize(maxW, nRows * rowH + (nRows - 1) * rowGap)
	R.panel:SetShown(not banner)
	if not banner then
		H.Paper:Apply(R.panel.bg, "glass", 0.9)
		local r, g, b = accent()
		for _, t in ipairs(R.panel.rim) do t:SetColorTexture(r, g, b, 1) end
		local gem = Themes:Piece("frame.gem")
		R.panel.gem:SetShown(gem ~= nil)
		if gem then
			R.panel.gem:SetTexture(gem.file)
			Themes:Paint(R.panel.gem)
		end
	end
	self:LayoutRaidPreview()
	R:UpdateGroups()
	H.Movers:Apply(R.container.mover)
	R:UpdateAll()
end

--[[ Updates ]]

-- which groups have members: empty ones hide (unless set), a row with none
-- hides whole, rolled rows keep only their rod. Groups are fixed slots, so
-- nothing moves when one empties.
function R:UpdateGroups()
	if not self.container or not self.nRows then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() R:UpdateGroups() end, "uf-raid-groups")
		return
	end
	local d = db()
	local banner = d.raidStyle == "banner"
	local used = {}
	if self.preview then
		for g = 1, 5 do used[g] = true end
	elseif IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local _, _, sub = GetRaidRosterInfo(i)
			if sub then used[sub] = true end
		end
	end
	for r = 1, self.nRows do
		local row = self.rows[r]
		local any = false
		for _, G in ipairs(row.groups) do
			local on = used[G.index] or d.raidShowEmpty
			any = any or on
			G.header:SetShown(on)
			G.number:SetShown(not banner)
		end
		local rolled = banner and H.char.raidRolled and H.char.raidRolled[r]
		row.rod:SetShown(banner and any)
		row.sheet:SetShown(any and not rolled)
		self:PaintRolled(row)
	end
end

function R:UpdateButton(b)
	local unit = b:GetAttribute("unit")
	if not unit or not UnitExists(unit) then return end
	paint(b, unit)
	b:SetAlpha(1)
end

function R:UpdateAll()
	for unit, b in pairs(self.byUnit) do self:UpdateButton(b) end
	for r = 1, self.nRows or 0 do self:PaintRolled(self.rows[r]) end
end

function R:UpdateRange()
	local d = db()
	for unit, b in pairs(self.byUnit) do
		local a = 1
		if d.raidRange then
			local ok, inRange, checked = pcall(UnitInRange, unit)
			if ok and checked and not (issecretvalue and (issecretvalue(inRange) or issecretvalue(checked))) and not inRange then
				a = d.raidRangeAlpha
			end
		end
		b:SetAlpha(a)
	end
end

--[[ The game's raid frames ]]

function UF:RaidBlizzard()
	local hide = self.db.raidHideBlizzard and self.db.raidShow
	for _, fr in ipairs({ _G.CompactRaidFrameManager, _G.CompactRaidFrameContainer }) do
		if fr then
			if hide then
				fr.hParent = fr.hParent or fr:GetParent()
				pcall(fr.SetParent, fr, hidden)
			elseif fr.hParent then
				pcall(fr.SetParent, fr, fr.hParent)
			end
		end
	end
end

--[[ Preview: made-up members, without a raid ]]

local CLASSES = { "PALADIN", "MAGE", "HUNTER", "PRIEST", "WARRIOR", "ROGUE", "DRUID", "SHAMAN", "WARLOCK" }
local NAMES = { "Julian", "Mara", "Rok", "Elia", "Tom", "Ana", "Theron", "Kael", "Lyra", "Bram", "Sela", "Orin",
	"Vex", "Nia", "Dorn", "Faye", "Grim", "Hale", "Ivo", "Juno", "Kira", "Lux", "Moss", "Nox", "Pyre" }
local LIFE = { 1, 0.85, 0.55, 1, 0.3, 0.75, 0, 0.9, 0.55, 1, 0.08, 0.9, 1, 0.55, 0.55, 0.3, 0.75, 0.55, 0.3, 0.75, 0.55, 1, 0.08, 0.55, 1 }
local DEB = { [1] = "Magic", [9] = "Poison", [13] = "Magic", [21] = "Curse", [25] = "Disease" }

function UF:LayoutRaidPreview()
	local d = self.db
	for i, b in ipairs(R.fakes) do b:Hide() end
	if not R.preview then return end
	local n = 0
	for g = 1, 5 do
		local G = R.groups[g]
		for i = 1, PER_GROUP do
			n = n + 1
			local b = R.fakes[n]
			if not b then
				b = CreateFrame("Frame", nil, G.header)
				R.fakes[n] = b
			end
			b:SetParent(G.header)
			b:SetSize(d.raidWidth, d.raidHeight)
			b:ClearAllPoints()
			b:SetPoint("TOP", G.header, "TOP", 0, -(i - 1) * (d.raidHeight + d.raidSpacing))
			layoutMember(b)
			paint(b, nil, { name = NAMES[n], class = CLASSES[(n * 7) % #CLASSES + 1], life = LIFE[n], debuff = DEB[n] })
			b.hFakeDead = LIFE[n] == 0
			b:Show()
		end
		-- the header has no buttons of its own here: give it the members' size
		G.header:SetSize(d.raidWidth, PER_GROUP * d.raidHeight + (PER_GROUP - 1) * d.raidSpacing)
	end
end

function UF:SetRaidPreview(on)
	if not R.container then return end
	if InCombatLockdown() then
		H:Error("The raid preview can't change in combat.")
		return
	end
	R.preview = on and true or false
	if on then
		UnregisterStateDriver(R.container, "visibility")
		R.container:Show()
	else
		RegisterStateDriver(R.container, "visibility", "[group:raid] show; hide")
	end
	self:LayoutRaid()
end

H.previews = H.previews or {}
table.insert(H.previews, {
	key = "raid",
	label = "Raid preview",
	desc = "Made-up members in five groups, to set up the raid frames without a raid.",
	get = function() return R.preview end,
	set = function(v) UF:SetRaidPreview(v) end,
})

--[[ Lifecycle: called from Target.lua's OnEnable ]]

function UF:EnableRaid()
	if not self.db.raidShow then return end
	local c = CreateFrame("Frame", "HeraldryRaidFrame", UIParent, "SecureHandlerStateTemplate")
	c:SetFrameStrata("LOW")
	c:SetSize(200, 200)
	R.container = c
	c.mover = H:RegisterMover(c, "UnitFrames.raid", {
		label = "Raid", default = { "TOPLEFT", 30, -220 }, scalable = true,
	})
	RegisterStateDriver(c, "visibility", "[group:raid] show; hide")

	-- the tiles' panel: dark glass, a rim in the theme metal, the theme gem on top
	local p = CreateFrame("Frame", nil, c)
	p:SetPoint("TOPLEFT", -6, 6)
	p:SetPoint("BOTTOMRIGHT", 6, -6)
	p:SetFrameLevel(math.max(c:GetFrameLevel() - 1, 0))
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetAllPoints()
	p.rim = {}
	for i = 1, 4 do p.rim[i] = p:CreateTexture(nil, "BORDER") end
	p.rim[1]:SetPoint("TOPLEFT"); p.rim[1]:SetPoint("TOPRIGHT"); p.rim[1]:SetHeight(2)
	p.rim[2]:SetPoint("BOTTOMLEFT"); p.rim[2]:SetPoint("BOTTOMRIGHT"); p.rim[2]:SetHeight(2)
	p.rim[3]:SetPoint("TOPLEFT"); p.rim[3]:SetPoint("BOTTOMLEFT"); p.rim[3]:SetWidth(2)
	p.rim[4]:SetPoint("TOPRIGHT"); p.rim[4]:SetPoint("BOTTOMRIGHT"); p.rim[4]:SetWidth(2)
	p.gem = p:CreateTexture(nil, "OVERLAY")
	p.gem:SetSize(28, 28)
	p.gem:SetPoint("CENTER", p, "TOP", 0, 0)
	R.panel = p

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "UNIT_HEALTH", "UNIT_MAXHEALTH",
		"UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_AURA" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, e, unit)
		if unit then
			local b = R.byUnit[unit]
			if b then
				R:UpdateButton(b)
				if e == "UNIT_HEALTH" or e == "UNIT_FLAGS" then
					local G = b:GetParent().G
					if G and G.row then R:UpdateWarn(G.row) end
				end
			end
		else
			R:UpdateGroups()
			R:UpdateAll()
		end
	end)
	-- range has no event: a light poll
	local t = 0
	c:HookScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		if t < 0.4 then return end
		t = 0
		R:UpdateRange()
	end)

	self:LayoutRaid()
	self:RaidBlizzard()
end
