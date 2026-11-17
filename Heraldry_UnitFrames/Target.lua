--[[
	Heraldry_UnitFrames - Target.lua
	The target frame, in two styles:
	  Heraldic (default)  one art family for every target (TargetArt.lua): the
	                      ornament on the left says what the target is (hostile,
	                      friendly, elite, rare, boss, or the player's class),
	                      the level sits on its gem, rails hug the bars.
	  Minimal             dark glass panel, a rim in the theme's metal colour and
	                      the theme's gem (level 2 of the visual hierarchy).
	The bars keep their size and place whatever the target: only the ornament
	changes around them.

	- The frame is a secure unit button for "target", shown and hidden by the
	  game (RegisterUnitWatch): left click targets, right click opens the
	  unit's menu, click casting works on it.
	- Life and power are StatusBars: the game's protected ("secret") values in
	  combat go straight into them. Text that needs maths is wrapped in pcall
	  and falls back to the plain value.
	- Minimal: the gem (theme piece frame.gem) carries the level, and a halo
	  behind it shows elite (gold), rare (silver) and boss (red) units.
	- Art changes between targets are texture changes only, so they also
	  happen in combat; sizes and places are set out of combat.
	- The game's target frame is hidden (option).
]]

local H = Heraldry
local Themes = H.Themes

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local UNIT = "target"

local UF = H:NewModule("UnitFrames", {
	label = "Unit frames",
	fonts = true,
	defaults = {
		style = "heraldic",      -- heraldic | minimal
		rails = "class",         -- class | neutral (players: the class rod's rails, or the hostile rails)
		bothEnds = true,         -- the ornament on both ends of the bars (the level is on the left one)
		capOverlap = 8,          -- how far the ornaments reach over the ends of the bars (negative: a gap)
		width = 240,
		healthHeight = 18,
		powerHeight = 8,
		showPower = true,
		gemSize = 34,
		showGem = true,
		-- texts: show, size, offset (x, y) of each one; see UF.TEXTS
		nameShow = true,    nameSize = 13,    nameX = 0,    nameY = 0,
		hpValueShow = true, hpValueSize = 11, hpValueX = 0, hpValueY = 0,
		hpPctShow = true,   hpPctSize = 11,   hpPctX = 0,   hpPctY = 0,
		powerShow = false,  powerSize = 9,    powerX = 0,   powerY = 0,
		levelShow = true,   levelSize = 12,   levelX = 0,   levelY = 0,
		classColor = true,
		panelAlpha = 0.82,
		hideBlizzard = true,
	},
})

-- Class rods: ornament scale and rail thickness per pixel of bar height.
local ROD_K = 0.5625 / 28   -- x the rod's scale (0.8): 0.45 at 28 px of bars
local ROD_RAIL = 0.3

-- The frame's texts, in the order the Text tab lists them.
UF.TEXTS = {
	{ key = "name",    label = "Name" },
	{ key = "hpValue", label = "Life value" },
	{ key = "hpPct",   label = "Life percentage" },
	{ key = "power",   label = "Power value" },
	{ key = "level",   label = "Level" },
}

local Abbr = AbbreviateNumbers or AbbreviateLargeNumbers or tostring
local INTERP = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

-- halo colour per classification; normal units have none
local HALO = {
	elite     = { 1.00, 0.80, 0.30 },
	rareelite = { 0.82, 0.88, 1.00 },
	rare      = { 0.82, 0.88, 1.00 },
	worldboss = { 0.95, 0.22, 0.15 },
}

local hidden = CreateFrame("Frame")
hidden:Hide()

--[[ Building ]]

local function bar(parent)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetStatusBarTexture(FLAT)
	b:SetMinMaxValues(0, 1)
	b:SetValue(1)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0, 0, 0, 0.6)
	-- glass sheen over the fill
	b.sheen = b:CreateTexture(nil, "OVERLAY")
	b.sheen:SetTexture(FLAT)
	b.sheen:SetPoint("TOPLEFT")
	b.sheen:SetPoint("TOPRIGHT")
	b.sheen:SetHeight(1)
	b.sheen:SetVertexColor(1, 1, 1, 0.18)
	b.text = b:CreateFontString(nil, "OVERLAY")
	b.text:SetPoint("RIGHT", -4, 0)
	b.text:SetShadowColor(0, 0, 0, 1)
	b.text:SetShadowOffset(1, -1)
	return b
end

local function line(parent)
	local t = parent:CreateTexture(nil, "BORDER")
	t:SetTexture(FLAT)
	return t
end

function UF:Create()
	local f = CreateFrame("Button", "HeraldryTargetFrame", UIParent, "SecureUnitButtonTemplate")
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(10)
	f:RegisterForClicks("AnyUp")
	f:SetAttribute("unit", UNIT)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "togglemenu")
	f:SetScript("OnEnter", function(btn)
		GameTooltip_SetDefaultAnchor(GameTooltip, btn)
		GameTooltip:SetUnit(UNIT)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[f] = true

	-- panel: dark glass, a faint light at the top, the rim
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetTexture(FLAT)
	f.light = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.light:SetTexture(FLAT)
	f.light:SetPoint("TOPLEFT")
	f.light:SetPoint("TOPRIGHT")
	f.light:SetHeight(14)
	if f.light.SetGradient and CreateColor then
		f.light:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.05))
	else
		f.light:SetVertexColor(1, 1, 1, 0.03)
	end
	f.rim = { line(f), line(f), line(f), line(f) }
	local r = f.rim
	r[1]:SetPoint("TOPLEFT"); r[1]:SetPoint("TOPRIGHT"); r[1]:SetHeight(1)
	r[2]:SetPoint("BOTTOMLEFT"); r[2]:SetPoint("BOTTOMRIGHT"); r[2]:SetHeight(1)
	r[3]:SetPoint("TOPLEFT"); r[3]:SetPoint("BOTTOMLEFT"); r[3]:SetWidth(1)
	r[4]:SetPoint("TOPRIGHT"); r[4]:SetPoint("BOTTOMRIGHT"); r[4]:SetWidth(1)

	f.name = f:CreateFontString(nil, "OVERLAY")
	f.name:SetJustifyH("LEFT")
	f.name:SetWordWrap(false)
	f.name:SetShadowColor(0, 0, 0, 1)
	f.name:SetShadowOffset(1, -1)

	f.health = bar(f)
	f.power = bar(f)
	f.health.pct = f.health:CreateFontString(nil, "OVERLAY")
	f.health.pct:SetShadowColor(0, 0, 0, 1)
	f.health.pct:SetShadowOffset(1, -1)

	-- gem on the left edge, above everything
	local g = CreateFrame("Frame", nil, f)
	g:SetFrameLevel(f:GetFrameLevel() + 5)
	f.gemFrame = g
	f.halo = g:CreateTexture(nil, "BACKGROUND")
	f.halo:SetTexture(MASK)
	f.halo:SetPoint("CENTER")
	f.gem = g:CreateTexture(nil, "ARTWORK")
	f.gem:SetAllPoints()
	f.gemBack = g:CreateTexture(nil, "BORDER")   -- Standard theme: plain disc
	f.gemBack:SetTexture(MASK)
	f.gemBack:SetAllPoints()
	f.level = g:CreateFontString(nil, "OVERLAY")
	f.level:SetPoint("CENTER", 0, 0)
	f.level:SetShadowColor(0, 0, 0, 1)
	f.level:SetShadowOffset(1, -1)

	-- Heraldic: rails under the bars, the ornament and its level above them
	local rails = CreateFrame("Frame", nil, f)
	rails:SetAllPoints()
	rails:SetFrameLevel(f:GetFrameLevel())
	f.railTop = rails:CreateTexture(nil, "ARTWORK")
	f.railBottom = rails:CreateTexture(nil, "ARTWORK")
	f.rails = rails
	local cap = CreateFrame("Frame", nil, f)
	cap:SetFrameLevel(f:GetFrameLevel() + 6)
	cap:SetAllPoints()
	-- each end: the ornament, and a strip where it fades into the rails
	f.ends = {}
	for i = 1, 2 do
		f.ends[i] = { main = cap:CreateTexture(nil, "ARTWORK"), fade = cap:CreateTexture(nil, "ARTWORK") }
	end
	f.capLevel = cap:CreateFontString(nil, "OVERLAY")
	f.capLevel:SetShadowColor(0, 0, 0, 1)
	f.capLevel:SetShadowOffset(1, -1)
	f.capFrame = cap

	self.frame = f
	RegisterUnitWatch(f)
	return f
end

--[[ Values ]]

local function setBar(b, cur, max)
	b:SetMinMaxValues(0, max)
	if not (INTERP and pcall(b.SetValue, b, cur, INTERP)) then b:SetValue(cur) end
end

-- Percentage that may be secret: the game's own percent first, then maths.
local function percent(cur, max)
	if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
		local ok, p = pcall(UnitHealthPercent, UNIT, true, CurveConstants.ScaleTo100)
		if ok and p then return p end
	end
	local ok, p = pcall(function() return max > 0 and cur / max * 100 or 0 end)
	if ok then return p end
end

-- Plain value (may be secret: the game's own abbreviation, else as is).
local function setValue(fs, v)
	if not pcall(function() fs:SetText(Abbr(v)) end) then pcall(fs.SetText, fs, v) end
end

local function setPercent(fs, cur, max, isHealth)
	local ok = pcall(function()
		local p = isHealth and percent(cur, max) or (max > 0 and cur / max * 100 or 0)
		fs:SetFormattedText("%d%%", p)
	end)
	if not ok then fs:SetText("") end
end

local function classColor(unit)
	local _, class = UnitClass(unit)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
end

function UF:HealthColor()
	if not UnitIsConnected(UNIT) or UnitIsDeadOrGhost(UNIT) then return 0.45, 0.45, 0.45 end
	if UnitIsPlayer(UNIT) and self.db.classColor then
		local r, g, b = classColor(UNIT)
		if r then return r, g, b end
	end
	if UnitIsTapDenied and UnitIsTapDenied(UNIT) then return 0.5, 0.5, 0.5 end
	local reaction = UnitReaction(UNIT, "player")
	local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if c then return c.r, c.g, c.b end
	return 0.2, 0.75, 0.2
end

function UF:UpdateHealth()
	local f = self.frame
	if not f or not UnitExists(UNIT) then return end
	local cur, max = UnitHealth(UNIT), UnitHealthMax(UNIT)
	setBar(f.health, cur, max)
	f.health:SetStatusBarColor(self:HealthColor())
	local state = UnitIsDeadOrGhost(UNIT) and (DEAD or "Dead")
		or (not UnitIsConnected(UNIT) and (PLAYER_OFFLINE or "Offline"))
	if state then
		f.health.text:SetText(state)
		f.health.pct:SetText("")
	else
		setValue(f.health.text, cur)
		setPercent(f.health.pct, cur, max, true)
	end
end

function UF:UpdatePower()
	local f = self.frame
	if not f or not UnitExists(UNIT) or not self.db.showPower then return end
	local ptype, token = UnitPowerType(UNIT)
	local cur, max = UnitPower(UNIT, ptype), UnitPowerMax(UNIT, ptype)
	setBar(f.power, cur, max)
	local c = (PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])) or { r = 0.3, g = 0.5, b = 1 }
	f.power:SetStatusBarColor(c.r, c.g, c.b)
	setValue(f.power.text, cur)
end

function UF:UpdateName()
	local f = self.frame
	if not f or not UnitExists(UNIT) then return end
	f.name:SetText(UnitName(UNIT) or "")
end

-- "rare", "boss", "elite" or nil
local function rank()
	local level = UnitLevel(UNIT)
	local c = UnitClassification(UNIT)
	if c == "worldboss" or (level and level < 0 and c ~= "rare" and c ~= "rareelite") then return "boss" end
	if c == "rare" or c == "rareelite" then return "rare" end
	if c == "elite" then return "elite" end
end

local function levelText(fs)
	local level = UnitLevel(UNIT)
	if level and level > 0 then
		fs:SetText(level)
		local c = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
			or (GetQuestDifficultyColor and GetQuestDifficultyColor(level))
		if c then fs:SetTextColor(c.r, c.g, c.b) else fs:SetTextColor(1, 0.85, 0.3) end
	else
		fs:SetText("??")
		fs:SetTextColor(1, 0.25, 0.2)
	end
end

function UF:UpdateLevel()
	local f = self.frame
	if not f or not UnitExists(UNIT) then return end
	if self.db.style == "heraldic" then
		levelText(f.capLevel)
		self:UpdateArt()
		return
	end
	levelText(f.level)
	local r = rank()
	local halo = HALO[r == "boss" and "worldboss" or r]
	if halo then
		f.halo:SetVertexColor(halo[1], halo[2], halo[3], 0.95)
		f.halo:Show()
	else
		f.halo:Hide()
	end
end

--[[ Heraldic art ]]

-- Which art the current target gets, and its tint ("rare", "boss" or nil).
function UF:ArtKey()
	if UnitIsPlayer(UNIT) then
		local _, class = UnitClass(UNIT)
		if class and self.ART[class] then return class end
	end
	local r = rank()
	if r then return "Elite", (r ~= "elite") and r or nil end
	local reaction = UnitReaction(UNIT, "player")
	if reaction and reaction <= 3 then return "Hostile" end
	return "Friendly"
end

-- desaturation and colour: the rare/boss tint, or the theme's finish
local function tone(tint)
	local t = tint and UF.ART_TINT[tint]
	if t then return t[1], t[2][1], t[2][2], t[2][3] end
	local f = Themes.FINISHES[Themes:FinishKey()]
	return f.desat, f.color[1], f.color[2], f.color[3]
end

-- Texture work only: safe in combat.
function UF:UpdateArt()
	local f, db = self.frame, self.db
	if not f or db.style ~= "heraldic" or not UnitExists(UNIT) then return end
	local key, tint = self:ArtKey()
	local art = self.ART[key]
	local railArt = art
	if db.rails == "neutral" and not (key == "Hostile" or key == "Friendly" or key == "Elite") then
		railArt = self.ART.Hostile
	end

	-- Scale. NPC ornaments come with their own rails: the art's gap between
	-- the rails is fitted to the bars, so the rails and the ornament always
	-- join exactly, at any bar height. Class rods have no rails of their own:
	-- they are sized from the bars.
	local barsH = db.healthHeight + (db.showPower and (2 + db.powerHeight) or 0)
	local c = art.cap
	local joined = art.rail.bottom ~= nil
	local k, topT, botT, mid
	if joined then
		local rt, rb = art.rail.top, art.rail.bottom
		k = barsH / (rb[1] - rt[2] - 1)
		topT, botT = (rt[2] - rt[1] + 1) * k, (rb[2] - rb[1] + 1) * k
		mid = (rt[2] + 1 + rb[1]) / 2
	else
		k = ROD_K * barsH * (c.scale or 1)
		topT, botT = ROD_RAIL * barsH, ROD_RAIL * barsH
		mid = c.gem[2]
	end

	-- ornaments: the middle of their rails on the middle of the bars
	local fade = c.fade or 0
	local solid = c.crop - fade
	local h = c.size[2] * k
	local y = (mid - c.size[2] / 2) * k
	local overlap = db.capOverlap
	local desat, cr, cg, cb = tone(tint)
	for i, e in ipairs(f.ends) do
		local shown = i == 1 or db.bothEnds
		e.main:SetShown(shown)
		e.fade:SetShown(shown and fade > 0)
		if shown then
			local left = i == 1
			local u0, u1 = 0, solid / c.size[1]
			local f0, f1 = solid / c.size[1], c.crop / c.size[1]
			if not left then u0, u1, f0, f1 = u1, u0, f1, f0 end   -- mirrored
			e.main:SetTexture(c.file)
			e.main:SetTexCoord(u0, u1, 0, 1)
			e.main:SetSize(solid * k, h)
			e.main:SetDesaturation(desat)
			e.main:SetVertexColor(cr, cg, cb)
			e.main:ClearAllPoints()
			e.fade:ClearAllPoints()
			if left then
				e.main:SetPoint("LEFT", f, "LEFT", overlap - c.crop * k, y)
			else
				e.main:SetPoint("RIGHT", f, "RIGHT", c.crop * k - overlap, y)
			end
			if fade > 0 then
				e.fade:SetTexture(c.file)
				e.fade:SetTexCoord(f0, f1, 0, 1)
				e.fade:SetSize(fade * k, h)
				e.fade:SetDesaturation(desat)
				if left then
					e.fade:SetPoint("LEFT", e.main, "RIGHT")
				else
					e.fade:SetPoint("RIGHT", e.main, "LEFT")
				end
				local solidC, clearC = { cr, cg, cb, 1 }, { cr, cg, cb, 0 }
				local a, b = solidC, clearC
				if not left then a, b = clearC, solidC end
				if CreateColor and e.fade.SetGradient and not pcall(e.fade.SetGradient, e.fade, "HORIZONTAL",
					CreateColor(a[1], a[2], a[3], a[4]), CreateColor(b[1], b[2], b[3], b[4])) then
					if e.fade.SetGradientAlpha then
						e.fade:SetGradientAlpha("HORIZONTAL", a[1], a[2], a[3], a[4], b[1], b[2], b[3], b[4])
					end
				end
			end
		end
	end
	f.capLevel:ClearAllPoints()
	f.capLevel:SetPoint("CENTER", f, "LEFT", overlap - c.crop * k + c.gem[1] * k + db.levelX, db.levelY)

	-- rails: above and below the bars, from one ornament to the other
	local r = railArt.rail
	local inner = overlap - 2
	local function band(tex, rows, flip, top, thick)
		-- the ornament's own rails keep the art's proportions; borrowed ones are squeezed to fit
		local tileW = (joined and railArt == art) and r.size[1] * k or thick * r.size[1] / (rows[2] - rows[1] + 1)
		local t1, t2 = rows[1] / r.size[2], (rows[2] + 1) / r.size[2]
		if flip then t1, t2 = t2, t1 end
		local len = db.width - inner - (db.bothEnds and inner or 0)
		tex:SetTexture(r.file, "REPEAT", "CLAMP")
		tex:SetTexCoord(0, len / tileW, t1, t2)
		tex:ClearAllPoints()
		local edge, side = top and "TOP" or "BOTTOM", top and "BOTTOM" or "TOP"
		tex:SetPoint(side .. "LEFT", f, edge .. "LEFT", inner, 0)
		tex:SetPoint(side .. "RIGHT", f, edge .. "RIGHT", db.bothEnds and -inner or 0, 0)
		tex:SetHeight(thick)
		Themes:Paint(tex)
	end
	band(f.railTop, r.top, false, true, topT)
	band(f.railBottom, r.bottom or r.top, not r.bottom, false, botT)
end

function UF:UpdateAll()
	if not self.frame or not UnitExists(UNIT) then return end
	self:UpdateName()
	self:UpdateLevel()
	self:UpdateHealth()
	self:UpdatePower()
end

--[[ Layout ]]

function UF:Layout()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() UF:Layout() end, "uf-target-layout")
		return
	end
	local f, db = self.frame, self.db
	local heraldic = db.style == "heraldic"
	local pad, gap = 6, 3

	-- parts of each style
	for _, t in ipairs({ f.bg, f.light, unpack(f.rim) }) do t:SetShown(not heraldic) end
	f.rails:SetShown(heraldic)
	f.capFrame:SetShown(heraldic)

	-- text
	H.Fonts:Apply(f.name, "header", db.nameSize, self)
	H.Fonts:Apply(f.health.text, "body", db.hpValueSize, self)
	H.Fonts:Apply(f.health.pct, "body", db.hpPctSize, self)
	H.Fonts:Apply(f.power.text, "body", db.powerSize, self)
	H.Fonts:Apply(f.level, "header", db.levelSize, self)
	H.Fonts:Apply(f.capLevel, "header", db.levelSize, self)
	f.name:SetShown(db.nameShow)
	f.health.text:SetShown(db.hpValueShow)
	f.health.pct:SetShown(db.hpPctShow)
	f.power.text:SetShown(db.powerShow)
	f.level:SetShown(db.levelShow)
	f.capLevel:SetShown(db.levelShow)
	local nameH = math.ceil(db.nameSize * 1.2)
	local barsH = db.healthHeight + (db.showPower and (2 + db.powerHeight) or 0)

	-- stacking: rails, then the bars, then the ornaments over the bars' ends
	local base = f:GetFrameLevel()
	f.rails:SetFrameLevel(base + 1)
	f.health:SetFrameLevel(base + 2)
	f.power:SetFrameLevel(base + 2)
	f.capFrame:SetFrameLevel(base + 6)
	f.gemFrame:SetFrameLevel(base + 6)

	f.name:ClearAllPoints()
	f.name:SetParent(heraldic and f.health or f)   -- inside the life bar, or above it
	f.name:SetDrawLayer("OVERLAY")
	f.health:ClearAllPoints()
	if heraldic then
		-- the frame (and its click area) is the bars; rails and ornaments sit
		-- around it and change with the target without resizing it in combat
		f:SetSize(db.width, barsH)
		f.health:SetPoint("TOPLEFT", 0, 0)
		f.health:SetPoint("TOPRIGHT", 0, 0)
		-- name inside the life bar, clear of the ornament
		f.name:SetPoint("LEFT", f.health, "LEFT", 12 + db.nameX, db.nameY)
		f.name:SetHeight(nameH)
		f.gemFrame:Hide()
	else
		local G = db.gemSize
		local left = db.showGem and (G / 2 + 6) or pad
		f.bg:SetVertexColor(0.02, 0.02, 0.028, db.panelAlpha)
		local ar, ag, ab = Themes:Accent()
		for _, t in ipairs(f.rim) do
			if ar then t:SetVertexColor(ar, ag, ab, 0.9) else t:SetVertexColor(0.35, 0.35, 0.38, 0.9) end
		end
		f.name:SetPoint("TOPLEFT", left + db.nameX, -pad + 1 + db.nameY)
		f.name:SetPoint("TOPRIGHT", -pad + db.nameX, -pad + 1 + db.nameY)
		f.name:SetHeight(nameH)
		f.health:SetPoint("TOPLEFT", left, -(pad + nameH + gap))
		f.health:SetPoint("TOPRIGHT", -pad, -(pad + nameH + gap))
		f:SetSize(db.width, pad + nameH + gap + barsH + pad)

		-- gem: centred on the left edge
		local g = f.gemFrame
		g:SetShown(db.showGem)
		g:ClearAllPoints()
		g:SetPoint("CENTER", f, "LEFT", 0, 0)
		g:SetSize(G, G)
		f.halo:SetSize(G * 1.22, G * 1.22)
		local piece = Themes:Piece("frame.gem")
		if piece then
			f.gem:SetTexture(piece.file)
			Themes:Paint(f.gem)
			f.gem:Show()
			f.gemBack:Hide()
		else
			f.gem:Hide()
			f.gemBack:Show()
			f.gemBack:SetVertexColor(0.06, 0.06, 0.07, 1)
		end
	end
	f.health:SetHeight(db.healthHeight)
	-- values on the right of the bars: percentage outermost, then the value
	local inset = (heraldic and db.bothEnds) and -14 or -4
	local pct, val = f.health.pct, f.health.text
	pct:ClearAllPoints()
	pct:SetPoint("RIGHT", f.health, "RIGHT", inset + db.hpPctX, db.hpPctY)
	val:ClearAllPoints()
	if db.hpPctShow then
		val:SetPoint("RIGHT", pct, "LEFT", -6 + db.hpValueX - db.hpPctX, db.hpValueY - db.hpPctY)
	else
		val:SetPoint("RIGHT", f.health, "RIGHT", inset + db.hpValueX, db.hpValueY)
	end
	f.power.text:ClearAllPoints()
	f.power.text:SetPoint("RIGHT", f.power, "RIGHT", inset + db.powerX, db.powerY)
	f.level:ClearAllPoints()
	f.level:SetPoint("CENTER", f.gemFrame, "CENTER", db.levelX, db.levelY)
	-- in the bar, the name stops before the room the values need
	if heraldic then
		local room = (db.hpValueShow and db.hpValueSize * 3.2 or 0) + (db.hpPctShow and db.hpPctSize * 2.8 or 0)
		f.name:SetPoint("RIGHT", f.health, "RIGHT", inset - room - 6 + db.nameX, db.nameY)
	end

	f.power:SetShown(db.showPower)
	if db.showPower then
		f.power:ClearAllPoints()
		f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
		f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
		f.power:SetHeight(db.powerHeight)
	end

	H.Movers:Apply(f.mover)
	H:RefreshEditMode()
	self:UpdateBlizzard()
	self:UpdateAll()
end


-- The game's target frame shows the same thing.
function UF:UpdateBlizzard()
	local tf = TargetFrame
	if not tf then return end
	H:RunOutOfCombat(function()
		if UF.db.hideBlizzard then
			if not UF.tfParent then UF.tfParent = tf:GetParent() end
			tf:SetParent(hidden)
		elseif UF.tfParent then
			tf:SetParent(UF.tfParent)
		end
	end, "uf-blizzard-target")
end

--[[ Lifecycle ]]

function UF:OnEnable()
	local f = self:Create()
	f.mover = H:RegisterMover(f, "UnitFrames.target", {
		label = "Target", default = { "BOTTOM", 0, 230 }, scalable = true,
	})

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
		"UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION" }) do
		pcall(ev.RegisterUnitEvent, ev, e, UNIT)
	end
	ev:SetScript("OnEvent", function(_, e)
		if e == "UNIT_HEALTH" or e == "UNIT_MAXHEALTH" or e == "UNIT_CONNECTION" then
			UF:UpdateHealth()
		elseif e == "UNIT_POWER_UPDATE" or e == "UNIT_MAXPOWER" or e == "UNIT_DISPLAYPOWER" then
			UF:UpdatePower()
		elseif e == "UNIT_NAME_UPDATE" then
			UF:UpdateName()
		elseif e == "UNIT_LEVEL" or e == "UNIT_CLASSIFICATION_CHANGED" then
			UF:UpdateLevel()
		elseif e == "UNIT_FACTION" then
			UF:UpdateHealth()
			UF:UpdateArt()
		else
			UF:UpdateAll()
		end
	end)

	H:On("THEME_CHANGED", function() UF:Layout() end)
	H:On("FONTS_CHANGED", function() UF:Layout() end)
	self:Layout()
end

function UF:OnProfileChanged()
	self:Layout()
end
