--[[
	Heraldry_UnitFrames - Target.lua
	The target frame, level 2 of the visual hierarchy: dark glass panel, a
	thin rim in the theme's metal colour, one gem.

	- The frame is a secure unit button for "target", shown and hidden by the
	  game (RegisterUnitWatch): left click targets, right click opens the
	  unit's menu, click casting works on it.
	- Life and power are StatusBars: the game's protected ("secret") values in
	  combat go straight into them. Text that needs maths is wrapped in pcall
	  and falls back to the plain value.
	- The gem (theme piece frame.gem) carries the level. A halo behind it
	  shows elite (gold), rare (silver) and boss (red) units.
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
		width = 260,
		healthHeight = 18,
		powerHeight = 8,
		showPower = true,
		gemSize = 34,
		showGem = true,
		healthText = "both",     -- both | percent | current | none
		powerText = false,
		nameSize = 13,
		valueSize = 11,
		classColor = true,
		panelAlpha = 0.82,
		hideBlizzard = true,
	},
})

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

local function setValueText(fs, mode, cur, max, isHealth)
	if mode == "none" then fs:SetText("") return end
	local ok = pcall(function()
		local p = isHealth and percent(cur, max) or (max > 0 and cur / max * 100 or 0)
		if mode == "percent" then
			fs:SetFormattedText("%d%%", p)
		elseif mode == "current" then
			fs:SetText(Abbr(cur))
		else
			fs:SetFormattedText("%s  |cffbbbbbb%d%%|r", Abbr(cur), p)
		end
	end)
	if not ok and not pcall(fs.SetText, fs, Abbr(cur)) then
		pcall(fs.SetText, fs, cur)
	end
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
	if UnitIsDeadOrGhost(UNIT) then
		f.health.text:SetText(DEAD or "Dead")
	elseif not UnitIsConnected(UNIT) then
		f.health.text:SetText(PLAYER_OFFLINE or "Offline")
	else
		setValueText(f.health.text, self.db.healthText, cur, max, true)
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
	setValueText(f.power.text, self.db.powerText and "current" or "none", cur, max, false)
end

function UF:UpdateName()
	local f = self.frame
	if not f or not UnitExists(UNIT) then return end
	f.name:SetText(UnitName(UNIT) or "")
end

function UF:UpdateLevel()
	local f = self.frame
	if not f or not UnitExists(UNIT) then return end
	local level = UnitLevel(UNIT)
	local class = UnitClassification(UNIT)
	if level and level > 0 then
		f.level:SetText(level)
		local c = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
			or (GetQuestDifficultyColor and GetQuestDifficultyColor(level))
		if c then f.level:SetTextColor(c.r, c.g, c.b) else f.level:SetTextColor(1, 0.85, 0.3) end
	else
		f.level:SetText("??")
		f.level:SetTextColor(1, 0.25, 0.2)
		if class ~= "rareelite" and class ~= "rare" then class = "worldboss" end
	end
	local halo = HALO[class]
	if halo then
		f.halo:SetVertexColor(halo[1], halo[2], halo[3], 0.95)
		f.halo:Show()
	else
		f.halo:Hide()
	end
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
	local pad, gap = 6, 3
	local gemOn = db.showGem
	local G = db.gemSize
	local left = gemOn and (G / 2 + 6) or pad

	-- panel
	f.bg:SetVertexColor(0.02, 0.02, 0.028, db.panelAlpha)
	local ar, ag, ab = Themes:Accent()
	for _, t in ipairs(f.rim) do
		if ar then t:SetVertexColor(ar, ag, ab, 0.9) else t:SetVertexColor(0.35, 0.35, 0.38, 0.9) end
	end

	-- text
	H.Fonts:Apply(f.name, "header", db.nameSize, self)
	H.Fonts:Apply(f.health.text, "body", db.valueSize, self)
	H.Fonts:Apply(f.power.text, "body", math.max(7, db.valueSize - 2), self)
	H.Fonts:Apply(f.level, "header", math.max(8, G * 0.36), self)
	local nameH = math.ceil(db.nameSize * 1.2)

	-- rows
	f.name:ClearAllPoints()
	f.name:SetPoint("TOPLEFT", left, -pad + 1)
	f.name:SetPoint("TOPRIGHT", -pad, -pad + 1)
	f.name:SetHeight(nameH)

	f.health:ClearAllPoints()
	f.health:SetPoint("TOPLEFT", left, -(pad + nameH + gap))
	f.health:SetPoint("TOPRIGHT", -pad, -(pad + nameH + gap))
	f.health:SetHeight(db.healthHeight)

	local h = pad + nameH + gap + db.healthHeight
	f.power:SetShown(db.showPower)
	if db.showPower then
		f.power:ClearAllPoints()
		f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
		f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
		f.power:SetHeight(db.powerHeight)
		h = h + 2 + db.powerHeight
	end
	f:SetSize(db.width, h + pad)

	-- gem: centred on the left edge
	local g = f.gemFrame
	g:SetShown(gemOn)
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
