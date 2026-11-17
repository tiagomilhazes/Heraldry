--[[
	Heraldry_Orbs - Orbs.lua
	Life and power orbs, each inside the active theme's ring (orb.health and
	orb.power pieces, Core/Themes.lua).

	- The liquid is a vertical StatusBar cut to a circle: the game's protected
	  ("secret") life and power values in combat go straight into it, no maths
	  on them in Lua. Text that needs maths is wrapped in pcall and falls back
	  to the plain value.
	- Two liquid layers cross-fade and a bright line rides on the surface.
	- By default the orbs are docked to the ends of action bar 1 (the block),
	  so they move with it. Turn "Attach to the action bars" off to move them
	  on their own.
	- The life orb is a secure unit button for "player": left click targets
	  you, right click opens your menu, click casting works on it.
]]

local H = Heraldry
local Themes = H.Themes

local MEDIA = "Interface\\AddOns\\Heraldry_Orbs\\Media\\"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local Orbs = H:NewModule("Orbs", {
	label = "Orbs",
	defaults = {
		attach = true,          -- docked to action bar 1
		size = 104,             -- diameter of the glass, in pixels
		distance = 3,           -- how far the ring stays from the buttons
		offsetY = 0,            -- raise or lower the orbs
		showText = true,
		textFormat = "stacked", -- stacked | percent | current
		textSize = 1,
		hidePlayerFrame = true, -- the orbs already show life and power
		clickable = true,
	},
})

-- Life colour per class; power uses the game's power colours, mana is blue.
local LIFE = {
	DRUID = { 1.00, 0.49, 0.04 }, PALADIN = { 0.96, 0.55, 0.73 }, WARRIOR = { 0.78, 0.45, 0.26 },
	HUNTER = { 0.55, 0.78, 0.32 }, ROGUE = { 1.00, 0.86, 0.25 }, PRIEST = { 0.92, 0.92, 0.96 },
	SHAMAN = { 0.10, 0.45, 0.90 }, MAGE = { 0.35, 0.80, 0.95 }, WARLOCK = { 0.58, 0.40, 0.92 },
}
local MANA = { 0.12, 0.38, 1.00 }

local Abbr = AbbreviateNumbers or AbbreviateLargeNumbers or tostring
local INTERP = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local hidden = CreateFrame("Frame")
hidden:Hide()

--[[ Building ]]

local function liquidBar(parent, file)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetAllPoints()
	b:SetOrientation("VERTICAL")
	b:SetStatusBarTexture(MEDIA .. file)
	b:SetMinMaxValues(0, 1)
	b:SetValue(1)
	local mask = b:CreateMaskTexture()
	mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(b)
	b:GetStatusBarTexture():AddMaskTexture(mask)
	b.mask = mask
	return b
end

local function pulse(region, from, to, duration)
	local g = region:CreateAnimationGroup()
	local a1 = g:CreateAnimation("Alpha")
	a1:SetFromAlpha(from); a1:SetToAlpha(to); a1:SetDuration(duration); a1:SetSmoothing("IN_OUT"); a1:SetOrder(1)
	local a2 = g:CreateAnimation("Alpha")
	a2:SetFromAlpha(to); a2:SetToAlpha(from); a2:SetDuration(duration); a2:SetSmoothing("IN_OUT"); a2:SetOrder(2)
	g:SetLooping("REPEAT")
	return g
end

local function createOrb(kind)
	local o = CreateFrame("Frame", "HeraldryOrb" .. kind, UIParent)
	o.kind = kind
	o:SetFrameStrata("MEDIUM")
	o:SetFrameLevel(20)

	-- empty part of the sphere
	o.void = o:CreateTexture(nil, "BACKGROUND")
	o.void:SetAllPoints()
	o.void:SetColorTexture(0.03, 0.025, 0.025, 1)
	local vm = o:CreateMaskTexture()
	vm:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	vm:SetAllPoints(o)
	o.void:AddMaskTexture(vm)

	-- liquid: two layers slowly cross-fading
	o.fill = liquidBar(o, "Liquid1")
	o.fill:SetFrameLevel(o:GetFrameLevel() + 1)
	o.fill2 = liquidBar(o, "Liquid2")
	o.fill2:SetFrameLevel(o:GetFrameLevel() + 2)
	o.flow = pulse(o.fill2, 0, 0.85, 3.5)

	-- bright line on the surface of the liquid
	o.surface = o.fill2:CreateTexture(nil, "OVERLAY")
	o.surface:SetTexture(MEDIA .. "Surface")
	o.surface:SetPoint("CENTER", o.fill:GetStatusBarTexture(), "TOP", 0, 0)
	o.surface:SetBlendMode("ADD")
	o.surface:AddMaskTexture(o.fill2.mask)
	o.shimmer = pulse(o.surface, 0.55, 1, 1.6)

	-- glass, then the theme's ring on top
	local top = CreateFrame("Frame", nil, o)
	top:SetAllPoints()
	top:SetFrameLevel(o:GetFrameLevel() + 4)
	o.glass = top:CreateTexture(nil, "ARTWORK")
	o.glass:SetTexture(MEDIA .. "Glass")
	o.glass:SetAllPoints()
	o.ring = top:CreateTexture(nil, "OVERLAY")

	-- text
	local tf = CreateFrame("Frame", nil, o)
	tf:SetAllPoints()
	tf:SetFrameLevel(o:GetFrameLevel() + 6)
	o.textFrame = tf
	o.text = tf:CreateFontString(nil, "OVERLAY")
	o.sub = tf:CreateFontString(nil, "OVERLAY")
	for _, fs in ipairs({ o.text, o.sub }) do
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
		fs:SetJustifyH("CENTER")
	end
	o.text:SetPoint("CENTER")
	o.sub:SetPoint("TOP", o.text, "BOTTOM", 0, -1)
	return o
end

--[[ Values ]]

local function setBars(o, cur, max)
	for _, b in ipairs({ o.fill, o.fill2 }) do
		b:SetMinMaxValues(0, max)
		if not (INTERP and pcall(b.SetValue, b, cur, INTERP)) then b:SetValue(cur) end
	end
end

-- Percentage of a value that may be secret; nil when it can't be computed.
local function pct(cur, max)
	local ok, p = pcall(function() return max > 0 and cur / max * 100 or 0 end)
	if ok then return p end
end

function Orbs:SetText(o, cur, max)
	o.textFrame:SetShown(self.db.showText)
	if not self.db.showText then return end
	o.sub:SetText("")
	local fmt = self.db.textFormat
	local ok = pcall(function()
		if fmt == "percent" then
			o.text:SetFormattedText("%d%%", pct(cur, max))
		elseif fmt == "current" then
			o.text:SetText(Abbr(cur))
		else
			o.text:SetText(Abbr(cur))
			o.sub:SetFormattedText("%d%%", pct(cur, max))
		end
	end)
	-- In combat the maths may fail on secret values: show the plain value.
	if not ok and not pcall(o.text.SetText, o.text, Abbr(cur)) then
		pcall(o.text.SetText, o.text, cur)
	end
end

local function color(o, r, g, b)
	for _, bar in ipairs({ o.fill, o.fill2 }) do bar:SetStatusBarColor(r, g, b) end
	o.surface:SetVertexColor(math.min(1, r * 0.6 + 0.5), math.min(1, g * 0.6 + 0.5), math.min(1, b * 0.6 + 0.5), 1)
end

function Orbs:UpdateHealth()
	local o = self.health
	if not o then return end
	local cur, max = UnitHealth("player"), UnitHealthMax("player")
	setBars(o, cur, max)
	self:SetText(o, cur, max)
end

function Orbs:UpdatePower()
	local o = self.power
	if not o then return end
	local ptype, token = UnitPowerType("player")
	local cur, max = UnitPower("player", ptype), UnitPowerMax("player", ptype)
	setBars(o, cur, max)
	if ptype == 0 then
		color(o, MANA[1], MANA[2], MANA[3])
	else
		local c = (PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])) or { r = 1, g = 0.8, b = 0.2 }
		color(o, c.r, c.g, c.b)
	end
	self:SetText(o, cur, max)
end

--[[ Layout ]]

-- Size, ring and text of one orb. Returns how far the ring reaches towards
-- the bars, in screen units (for docking).
function Orbs:Style(o, piece)
	local D = self.db.size
	o:SetSize(D, D)
	local reach = D / 2
	if piece then
		local h = piece.hole
		local k = D / (2 * h[3])
		o.ring:SetTexture(piece.file)
		Themes:Paint(o.ring)
		o.ring:ClearAllPoints()
		o.ring:SetSize(piece.size[1] * k, piece.size[2] * k)
		o.ring:SetPoint("CENTER", o, "CENTER", (piece.size[1] / 2 - h[1]) * k, (h[2] - piece.size[2] / 2) * k)
		o.ring:Show()
		reach = piece.reach * k
	else
		o.ring:Hide()
	end
	o.surface:SetSize(D, D / 11)
	-- Font, outline and global scale come from the core (Fonts page).
	local size = math.max(8, D * 0.15 * self.db.textSize)
	H.Fonts:Apply(o.text, "header", size)
	H.Fonts:Apply(o.sub, "header", size * 0.62)
	return reach
end

function Orbs:Layout()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() Orbs:Layout() end, "orbs-layout")
		return
	end
	local hReach = self:Style(self.health, Themes:Piece("orb.health"))
	local pReach = self:Style(self.power, Themes:Piece("orb.power"))

	local _, class = UnitClass("player")
	local life = LIFE[class] or { 0.8, 0.1, 0.1 }
	color(self.health, life[1], life[2], life[3])

	-- Docked to the ends of action bar 1, or free.
	local bar1 = H.Movers.byKey["ActionBars.bar1"]
	local dock = self.db.attach and bar1
	local y = self.db.size * 0.45 + self.db.offsetY
	local d = self.db.distance
	for _, pair in ipairs({ { self.health, -hReach - d, "BOTTOMLEFT" }, { self.power, pReach + d, "BOTTOMRIGHT" } }) do
		local o, x, rel = pair[1], pair[2], pair[3]
		o.mover.dock = dock and { target = "ActionBars.bar1", point = "CENTER", relPoint = rel, x = x, y = y } or nil
		H.Movers:Apply(o.mover)
	end
	H:RefreshEditMode()

	self.click:SetShown(self.db.clickable)
	self:UpdatePlayerFrame()
	self:UpdateHealth()
	self:UpdatePower()
end

--[[ Clicks on the life orb ]]

function Orbs:CreateClick()
	local b = CreateFrame("Button", "HeraldryOrbHealthClick", UIParent, "SecureUnitButtonTemplate")
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(40)
	b:SetAllPoints(self.health)
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("unit", "player")
	b:SetAttribute("*type1", "target")
	b:SetAttribute("*type2", "togglemenu")
	b:SetScript("OnEnter", function(btn)
		GameTooltip_SetDefaultAnchor(GameTooltip, btn)
		GameTooltip:SetUnit("player")
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(MEDIA .. "Glass")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.45)
	hl:SetAllPoints()
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[b] = true
	self.click = b
end

-- The game's player frame only repeats what the orbs show.
function Orbs:UpdatePlayerFrame()
	local pf = PlayerFrame
	if not pf then return end
	H:RunOutOfCombat(function()
		if Orbs.db.hidePlayerFrame then
			if not Orbs.pfParent then Orbs.pfParent = pf:GetParent() end
			pf:SetParent(hidden)
		elseif Orbs.pfParent then
			pf:SetParent(Orbs.pfParent)
		end
	end, "orbs-playerframe")
end

--[[ Lifecycle ]]

function Orbs:OnEnable()
	self.health = createOrb("Health")
	self.power = createOrb("Power")
	self:CreateClick()
	self.health.mover = H:RegisterMover(self.health, "Orbs.health", {
		label = "Life orb", default = { "BOTTOM", -330, 40 }, scalable = false,
	})
	self.power.mover = H:RegisterMover(self.power, "Orbs.power", {
		label = "Power orb", default = { "BOTTOM", 330, 40 }, scalable = false,
	})
	for _, o in ipairs({ self.health, self.power }) do
		o.flow:Play()
		o.shimmer:Play()
	end

	local ev = CreateFrame("Frame")
	ev:RegisterUnitEvent("UNIT_HEALTH", "player")
	ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:SetScript("OnEvent", function(_, event)
		if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
			Orbs:UpdateHealth()
		elseif event == "PLAYER_ENTERING_WORLD" then
			Orbs:UpdateHealth()
			Orbs:UpdatePower()
		else
			Orbs:UpdatePower()
		end
	end)

	H:On("THEME_CHANGED", function() Orbs:Layout() end)
	H:On("FONTS_CHANGED", function() Orbs:Layout() end)
	self:Layout()
end

function Orbs:OnProfileChanged()
	self:Layout()
end
