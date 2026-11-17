--[[
	Heraldry_UnitFrames - Target.lua
	The target frame, in two styles:
	  Plaque (default)  one fixed plaque (TargetPlaque.lua): the bars fill its
	                    slot, the level sits on the left jewel. What the target
	                    is shows as the metal's finish (iron hostile, bronze
	                    friendly, gold elite and players, silver rare, red boss)
	                    and the jewels' colour (reaction, or the player's class).
	                    The plaque never changes shape, so texts never move.
	  Minimal           dark glass panel, a rim in the theme's metal colour and
	                    the theme's gem (level 2 of the visual hierarchy).

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
		style = "plaque",        -- plaque | minimal
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
		castNameShow = true, castNameSize = 10, castNameX = 0, castNameY = 0,
		castTimeShow = true, castTimeSize = 10, castTimeX = 0, castTimeY = 0,
		castInPower = true,      -- the target's casts take the power row (Cast.lua)
		classColor = true,
		panelAlpha = 0.82,
		hideBlizzard = true,
	},
})

-- The frame's texts, in the order the Text tab lists them.
UF.TEXTS = {
	{ key = "name",    label = "Name" },
	{ key = "hpValue", label = "Life value" },
	{ key = "hpPct",   label = "Life percentage" },
	{ key = "power",   label = "Power value" },
	{ key = "level",   label = "Level" },
	{ key = "castName", label = "Cast: spell name" },
	{ key = "castTime", label = "Cast: time left" },
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

	-- Plaque: the art under the bars, the jewels (and the level) above them
	local plaque = CreateFrame("Frame", nil, f)
	plaque:SetAllPoints()
	f.plaque = plaque
	f.slices = { plaque:CreateTexture(nil, "ARTWORK"), plaque:CreateTexture(nil, "ARTWORK"), plaque:CreateTexture(nil, "ARTWORK") }
	-- the level's ring, part of the left medallion
	f.levelBack = plaque:CreateTexture(nil, "ARTWORK", nil, 2)
	f.levelBack:SetTexture(MASK)
	f.levelBack:SetVertexColor(0.07, 0.055, 0.04, 1)
	f.levelRing = plaque:CreateTexture(nil, "OVERLAY")
	local jewels = CreateFrame("Frame", nil, f)
	jewels:SetAllPoints()
	f.jewelFrame = jewels
	f.jewels = {}
	for i = 1, 2 do
		local j = jewels:CreateTexture(nil, "ARTWORK")
		local m = jewels:CreateMaskTexture()
		m:SetTexture(MASK)
		m:SetAllPoints(j)
		j:AddMaskTexture(m)
		f.jewels[i] = j
	end
	-- texts sit above the plaque (the bars are behind it)
	f.textFrame = CreateFrame("Frame", nil, f)
	f.textFrame:SetAllPoints()
	f.capLevel = jewels:CreateFontString(nil, "OVERLAY")
	f.capLevel:SetShadowColor(0, 0, 0, 1)
	f.capLevel:SetShadowOffset(1, -1)

	self.frame = f
	self:CreateCast()
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

UF.util = {}

local function classColor(unit)
	local _, class = UnitClass(unit)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
end

UF.util.setBar = setBar
UF.util.setValue = setValue

function UF:HealthColor(unit)
	local UNIT = unit or UNIT
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
local function rank(unit)
	local level = UnitLevel(unit or UNIT)
	local c = UnitClassification(unit or UNIT)
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
	if self:Style() == "plaque" then
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

--[[ Plaque ]]

-- "plaque" or "minimal" (profiles saved with the retired "heraldic" style get the plaque)
function UF:Style()
	return self.db.style == "minimal" and "minimal" or "plaque"
end

-- What the target is: "player", "boss", "rare", "elite", "hostile" or "friendly".
function UF:Kind(unit)
	unit = unit or UNIT
	if UnitIsPlayer(unit) then return "player" end
	local r = rank(unit)
	if r then return r end
	local reaction = UnitReaction(unit, "player")
	if reaction and reaction <= 3 then return "hostile" end
	return "friendly"
end

-- Colour of the jewels.
function UF:JewelColor(kind, unit)
	unit = unit or UNIT
	if kind == "player" then
		local r, g, b = classColor(unit)
		if r then return r, g, b end
	end
	if kind == "friendly" and UnitReaction(unit, "player") == 4 then return unpack(self.JEWEL.neutral) end
	return unpack(self.JEWEL[kind])
end

-- Finish of the plaque for a kind of target, on top of the theme's finish
-- (Theme page), so the plaque sits in the same tone as the action bar block.
-- "theme" kinds take the theme's finish as is; the others keep their own
-- metal (iron, silver, ...) at the theme finish's brightness.
function UF:Finish(kind)
	local tf = Themes.FINISHES[Themes:FinishKey()]
	local key = self.KIND_FINISH[kind]
	if key == "theme" then
		return tf.desat, tf.color[1], tf.color[2], tf.color[3]
	end
	local f = self.FINISH[key]
	local light = 0.5 + 0.5 * (tf.color[1] + tf.color[2] + tf.color[3]) / 3
	return math.max(f[1], tf.desat), f[2][1] * light, f[2][2] * light, f[2][3] * light
end

-- Finish and jewels for the current target. Texture work only: safe in combat.
function UF:UpdateArt()
	local f = self.frame
	if not f or self:Style() ~= "plaque" or not UnitExists(UNIT) then return end
	local kind = self:Kind()
	local desat, cr, cg, cb = self:Finish(kind)
	for _, t in ipairs(f.slices) do
		t:SetDesaturation(desat)
		t:SetVertexColor(cr, cg, cb)
	end
	f.levelRing:SetDesaturation(desat)
	f.levelRing:SetVertexColor(cr, cg, cb)
	local r, g, b = self:JewelColor(kind)
	for _, j in ipairs(f.jewels) do
		j:SetDesaturation(1)
		j:SetVertexColor(r, g, b)
	end
end

-- Sizes and places of the plaque: they depend on the bars only, so they are
-- set by Layout (out of combat) and never change between targets.
function UF:LayoutPlaque(barsH)
	local f, db, P = self.frame, self.db, self.PLAQUE
	local W, H = P.size[1], P.size[2]
	local sl, st, sr, sb = P.slot[1], P.slot[2], P.slot[3], P.slot[4]
	local k = barsH / (sb - st)
	local a, b = P.split[1], P.split[2]
	local L, M, R = f.slices[1], f.slices[2], f.slices[3]
	for _, t in ipairs(f.slices) do
		t:SetTexture(P.file)
		t:ClearAllPoints()
	end
	L:SetTexCoord(0, a / W, 0, 1)
	M:SetTexCoord(a / W, b / W, 0, 1)
	R:SetTexCoord(b / W, 1, 0, 1)
	L:SetSize(a * k, H * k)
	R:SetSize((W - b) * k, H * k)
	L:SetPoint("TOPLEFT", f, "TOPLEFT", -sl * k, st * k)
	R:SetPoint("TOPRIGHT", f, "TOPRIGHT", (W - sr) * k, st * k)
	M:SetPoint("TOPLEFT", L, "TOPRIGHT")
	M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")

	-- jewels: the plaque's own gems, recoloured (desaturated, then tinted)
	for i, g in ipairs(P.gems) do
		local j = f.jewels[i]
		local x, y, rad = g[1], g[2], g[3]
		j:SetTexture(P.file)
		j:SetTexCoord((x - rad) / W, (x + rad) / W, (y - rad) / H, (y + rad) / H)
		j:SetSize(2 * rad * k, 2 * rad * k)
		j:ClearAllPoints()
		if i == 1 then
			j:SetPoint("CENTER", f, "TOPLEFT", (x - sl) * k, -(y - st) * k)
		else
			j:SetPoint("CENTER", f, "TOPRIGHT", (x - sr) * k, -(y - st) * k)
		end
	end
	-- the level's ring
	local lv = P.level
	local ring, back = f.levelRing, f.levelBack
	ring:SetTexture(lv.file)
	ring:SetSize(lv.size * k, lv.size * k)
	ring:ClearAllPoints()
	ring:SetPoint("CENTER", f, "TOPLEFT", (lv.x - sl) * k, -(lv.y - st) * k)
	back:SetSize(lv.size * lv.hole * k, lv.size * lv.hole * k)
	back:ClearAllPoints()
	back:SetPoint("CENTER", ring)
	ring:SetShown(db.levelShow)
	back:SetShown(db.levelShow)
	f.capLevel:ClearAllPoints()
	f.capLevel:SetPoint("CENTER", ring, "CENTER", db.levelX, db.levelY)
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
	local heraldic = self:Style() == "plaque"
	local pad, gap = 6, 3

	-- parts of each style
	for _, t in ipairs({ f.bg, f.light, unpack(f.rim) }) do t:SetShown(not heraldic) end
	f.plaque:SetShown(heraldic)
	f.jewelFrame:SetShown(heraldic)

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

	-- stacking: the bars, the plaque over them (its slot is cut out), the
	-- jewels, then the texts
	local base = f:GetFrameLevel()
	f.health:SetFrameLevel(base + 1)
	f.power:SetFrameLevel(base + 1)
	f.plaque:SetFrameLevel(base + 3)
	f.jewelFrame:SetFrameLevel(base + 6)
	f.gemFrame:SetFrameLevel(base + 6)
	f.textFrame:SetFrameLevel(base + 7)
	f.health.text:SetParent(heraldic and f.textFrame or f.health)
	f.health.pct:SetParent(heraldic and f.textFrame or f.health)
	f.power.text:SetParent(heraldic and f.textFrame or f.power)
	for _, fs in ipairs({ f.health.text, f.health.pct, f.power.text }) do fs:SetDrawLayer("OVERLAY") end

	f.name:ClearAllPoints()
	f.name:SetParent(heraldic and f.textFrame or f)   -- inside the life bar, or above it
	f.name:SetDrawLayer("OVERLAY")
	f.health:ClearAllPoints()
	if heraldic then
		-- the frame (and its click area) is the plaque's slot, filled by the bars
		f:SetSize(db.width, barsH)
		f.health:SetPoint("TOPLEFT", 0, 0)
		f.health:SetPoint("TOPRIGHT", 0, 0)
		f.name:SetPoint("LEFT", f.health, "LEFT", 8 + db.nameX, db.nameY)
		f.name:SetHeight(nameH)
		f.gemFrame:Hide()
		self:LayoutPlaque(barsH)
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
	local inset = heraldic and -8 or -4
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
	self:LayoutCast(inset)

	H.Movers:Apply(f.mover)
	H:RefreshEditMode()
	self:UpdateBlizzard()
	self:UpdateAll()
	if self.LayoutSmall then self:LayoutSmall() end   -- the target of target follows the plaque
	if self.LayoutParty then self:LayoutParty() end
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

	self:EnableCast()
	H:On("THEME_CHANGED", function() UF:Layout() end)
	H:On("FONTS_CHANGED", function() UF:Layout() end)
	self:Layout()
	self:EnableSmall()
	self:EnableParty()
end

function UF:OnProfileChanged()
	self:Layout()
end
