--[[
	Heraldry_Auras - Auras.lua
	Auras set into the orbs' sockets (prototype P2):
	  - power orb: the four gems hold the auras you choose (per character; a
	    paladin starts with his seals). An active one shows its icon in the gem,
	    darkening as it runs out; an inactive one leaves the plain gem.
	  - life orb: each gem stands for a debuff type (top magic, right curse,
	    bottom poison, left disease) and lights in its colour while you have one;
	    it pulses when you can remove it.

	The sockets come from the theme (orb.health / orb.power `sockets`); a theme
	without them gets four points around the orb.

	Aura data can be secret in combat: presence is asked by name (the game does
	the matching), the icon goes straight into SetTexture and the time left into
	a Cooldown from the game's duration object. Anything else is read in pcall.
]]

local H = Heraldry
local Themes = H.Themes

local AU = H:NewModule("Auras", {
	label = "Auras",
	fonts = true,
	defaults = {
		socketsShow = true,       -- power orb: chosen auras
		socketScale = 1.7,        -- icon size against the gem
		socketDrain = true,       -- darkens as the aura runs out
		socketInactive = false,   -- inactive chosen auras stay, faded
		debuffSockets = true,     -- life orb: debuff types
		debuffPulse = true,       -- pulse when you can remove it
		socketTime = true,        -- time left under the power orb's gems
		debuffTime = true,        -- time left under the life orb's gems
		socketTimeSize = 11,      -- size of the time left on the power orb's gems
		debuffTimeSize = 11,      -- and on the life orb's
	},
})

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SLOTS = 4

-- what the life orb's gems stand for, in the sockets' order (top, right, bottom, left)
AU.DEBUFF_TYPES = { "Magic", "Curse", "Poison", "Disease" }
AU.DEBUFF_COLORS = {
	Magic   = { 0.25, 0.55, 1.00 },
	Curse   = { 0.65, 0.10, 1.00 },
	Poison  = { 0.10, 0.75, 0.15 },
	Disease = { 0.70, 0.45, 0.05 },
}

-- what a new character puts in the power orb's gems
AU.CLASS_DEFAULTS = {
	PALADIN = { "Seal of Righteousness", "Seal of Command", "Seal of Wisdom", "Seal of Light" },
	PRIEST = { "Inner Fire", "Power Word: Fortitude", "Divine Spirit", "Shadow Protection" },
}
-- themes that change the defaults (a shadow priest keeps other auras up)
AU.THEME_DEFAULTS = {
	PRIEST_SHADOW = { "Shadowform", "Vampiric Embrace", "Inner Fire", "Power Word: Fortitude" },
}

local preview = false

local function plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

--[[ The chosen auras (per character) ]]

function AU:Chosen()
	local c = H.char
	if not c.auraSockets then
		local _, class = UnitClass("player")
		local d = self.THEME_DEFAULTS[H.Themes:ActiveKey()] or self.CLASS_DEFAULTS[class] or {}
		c.auraSockets = { d[1] or "", d[2] or "", d[3] or "", d[4] or "" }
	end
	return c.auraSockets
end

function AU:SetChosen(i, name)
	self:Chosen()[i] = name or ""
	self:Update()
end

--[[ Sockets ]]

-- one socket: an accent disc as the rim, the icon cut round, a cooldown for the
-- time left, and a glow for the debuff colours
local function newSocket(parent)
	local s = CreateFrame("Frame", nil, parent)
	s:SetFrameLevel(parent:GetFrameLevel() + 30)
	s.rim = s:CreateTexture(nil, "BACKGROUND")
	s.rim:SetTexture(MASK)
	s.icon = s:CreateTexture(nil, "ARTWORK")
	local m = s:CreateMaskTexture()
	m:SetTexture(MASK)
	m:SetAllPoints(s.icon)
	s.icon:AddMaskTexture(m)
	s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
	s.cd:SetAllPoints(s.icon)
	s.cd:SetSwipeTexture(MASK)
	s.cd:SetSwipeColor(0, 0, 0, 0.7)
	s.cd:SetDrawEdge(false)
	s.cd:SetReverse(true)
	if s.cd.SetHideCountdownNumbers then s.cd:SetHideCountdownNumbers(true) end
	s.glow = s:CreateTexture(nil, "OVERLAY")
	s.glow:SetTexture(MASK)
	s.glow:SetBlendMode("ADD")
	-- time left, in the middle of the gem (on a frame above the cooldown swipe)
	s.textFrame = CreateFrame("Frame", nil, s)
	s.textFrame:SetAllPoints()
	s.textFrame:SetFrameLevel(s.cd:GetFrameLevel() + 2)
	s.time = s.textFrame:CreateFontString(nil, "OVERLAY")
	s.time:SetShadowColor(0, 0, 0, 1)
	s.time:SetShadowOffset(1, -1)
	s.pulse = s.glow:CreateAnimationGroup()
	s.pulse:SetLooping("BOUNCE")
	local a = s.pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.25)
	a:SetDuration(0.55)
	s:Hide()
	return s
end

-- centre and radius of each gem, in the orb's units, for an orb piece
local function gems(orbFrame, piece, size)
	local list = {}
	if piece and piece.sockets then
		local h = piece.hole
		local k = size / (2 * h[3])
		for i, g in ipairs(piece.sockets) do
			list[i] = { (g[1] - h[1]) * k, (h[2] - g[2]) * k, g[3] * k }
		end
	else
		-- no gems in the art: four points just outside the glass
		local r = size / 2 + size * 0.06
		local pts = { { 0, r }, { r, 0 }, { 0, -r }, { -r, 0 } }
		for i, p in ipairs(pts) do list[i] = { p[1], p[2], size * 0.07 } end
	end
	return list
end

function AU:Layout()
	local Orbs = H.Modules.byName.Orbs
	local hp, pw = _G.HeraldryOrbHealth, _G.HeraldryOrbPower
	if not (Orbs and Orbs.db and hp and pw) then return end
	local size = Orbs.db.size
	self.sockets = self.sockets or { power = {}, life = {} }
	for _, side in ipairs({ { "power", pw, "orb.power" }, { "life", hp, "orb.health" } }) do
		local key, orb, ptype = side[1], side[2], side[3]
		local list = gems(orb, Themes:Piece(ptype), size)
		for i = 1, SLOTS do
			local s = self.sockets[key][i] or newSocket(orb)
			self.sockets[key][i] = s
			local g = list[i]
			local r = g[3] * (key == "power" and self.db.socketScale or 1.15)
			s:ClearAllPoints()
			s:SetPoint("CENTER", orb, "CENTER", g[1], g[2])
			s:SetSize(2 * r, 2 * r)
			s.rim:SetSize(2 * r + 3, 2 * r + 3)
			s.rim:SetPoint("CENTER")
			s.icon:SetSize(2 * r, 2 * r)
			s.icon:SetPoint("CENTER")
			s.glow:SetSize(2 * r * 1.6, 2 * r * 1.6)
			s.glow:SetPoint("CENTER")
			H.Fonts:Apply(s.time, "body", key == "power" and self.db.socketTimeSize or self.db.debuffTimeSize, self)
			s.time:ClearAllPoints()
			s.time:SetPoint("CENTER", s, "CENTER", 1, 0)
			local ar, ag, ab = Themes:Accent()
			if not ar then ar, ag, ab = 0.85, 0.66, 0.3 end
			s.rim:SetVertexColor(ar, ag, ab)
		end
	end
	self:Update()
end

--[[ Reading auras ]]

-- the player's aura with this name (or spell ID), or nil
local function findAura(name)
	if not name or name == "" then return nil end
	local aura
	pcall(function()
		local id = tonumber(name)
		if id and C_UnitAuras.GetPlayerAuraBySpellID then
			aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
		elseif C_UnitAuras.GetAuraDataBySpellName then
			aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
		end
	end)
	return aura
end

local function spellIcon(name)
	local icon
	pcall(function()
		local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(tonumber(name) or name)
		icon = info and info.iconID
	end)
	return icon
end

--[[ Time left ]]

-- plain seconds as "12s" / "3m" / "1h"
local function short(t)
	if t >= 3600 then return ("%dh"):format(math.ceil(t / 3600)) end
	if t >= 60 then return ("%dm"):format(math.ceil(t / 60)) end
	return ("%ds"):format(math.ceil(t))
end

-- sockets whose time is counted here (plain numbers); a ticker runs while any
local counted = {}
local ticker
local function tick()
	local now, any = GetTime(), false
	for s, exp in pairs(counted) do
		local left = exp - now
		if left > 0 then   -- a socket that hides stops its own count (stopTime)
			s.time:SetText(short(left))
			any = true
		else
			s.time:SetText("")
			counted[s] = nil
		end
	end
	if not any and ticker then
		ticker:Cancel()
		ticker = nil
	end
end
local function count(s, exp)
	counted[s] = exp
	if not ticker then ticker = C_Timer.NewTicker(0.25, tick) end
	tick()
end

local function stopTime(s)
	counted[s] = nil
	if s.binding then pcall(s.binding.SetEnabled, s.binding, false) end
	s.time:SetText("")
end

-- the aura's duration object (the game's own; works with secret values)
local function durationObject(aura)
	local d
	pcall(function()
		if C_UnitAuras.GetAuraDuration then d = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID) end
	end)
	return d
end

-- seconds, rounded, written by the game (for secret values): needs a formatter
local secondsFormatter
local function formatter()
	if secondsFormatter ~= nil then return secondsFormatter or nil end
	secondsFormatter = false
	pcall(function()
		local Nearest = Enum.NumericRuleFormatRounding.Nearest
		local f = C_StringUtil.CreateNumericRuleFormatter()
		f:SetBreakpoints({ { threshold = 0, format = "%.0f", rounding = Nearest } })
		secondsFormatter = f
	end)
	return secondsFormatter or nil
end

-- the time left of `aura` as the darkening swipe (drain) and as text (text):
-- plain numbers when they can be read ("12s", "3m"); else the game writes the
-- seconds from the aura's duration object
local function setTime(s, aura, drain, text)
	s.cd:Clear()
	stopTime(s)
	if not aura then return end
	local d = durationObject(aura)
	if drain and d and s.cd.SetCooldownFromDurationObject then pcall(s.cd.SetCooldownFromDurationObject, s.cd, d) end
	local done = false
	pcall(function()
		local exp, dur = aura.expirationTime, aura.duration
		if plain(exp) and plain(dur) and dur > 0 then
			if drain and not d then s.cd:SetCooldown(exp - dur, dur) end
			if text then count(s, exp) end
			done = true
		end
	end)
	if done or not text or not d then return end
	local fmt = AU.TimeFormatter and AU.TimeFormatter() or formatter()
	if fmt and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
		pcall(function()
			s.binding = s.binding or C_DurationUtil.CreateDurationTextBinding()
			s.binding:SetFontString(s.time)
			s.binding:SetDuration(d)
			s.binding:SetFormatter(fmt)
			if s.binding.SetUpdateInterval then s.binding:SetUpdateInterval(0.25) end
			if s.binding.SetExpiredText then s.binding:SetExpiredText("") end
			if s.binding.SetZeroDurationText then s.binding:SetZeroDurationText("") end
			s.binding:SetEnabled(true)
		end)
	end
end

function AU:UpdatePower()
	local list = self.sockets and self.sockets.power
	if not list then return end
	local chosen = self:Chosen()
	for i, s in ipairs(list) do
		local name = chosen[i]
		local aura = (self.db.socketsShow and not preview) and findAura(name)
		if preview and name ~= "" then aura = { preview = true } end
		if aura then
			if aura.preview then
				s.icon:SetTexture(spellIcon(name) or 134400)
				local now = GetTime()
				setTime(s, { expirationTime = now + 30 - i * 6, duration = 30 }, self.db.socketDrain, self.db.socketTime)
			else
				local okIcon = pcall(s.icon.SetTexture, s.icon, aura.icon)
				if not okIcon then s.icon:SetTexture(spellIcon(name)) end
				setTime(s, aura, self.db.socketDrain, self.db.socketTime)
			end
			s.icon:SetDesaturation(0)
			s.icon:SetAlpha(1)
			s.rim:Show()
			s:Show()
		elseif self.db.socketsShow and self.db.socketInactive and name ~= "" and spellIcon(name) then
			s.icon:SetTexture(spellIcon(name))
			s.icon:SetDesaturation(1)
			s.icon:SetAlpha(0.45)
			setTime(s, nil)
			s.rim:Hide()
			s:Show()
		else
			setTime(s, nil)
			s:Hide()
		end
		s.glow:Hide()
	end
end

-- the player's debuffs by type (the first one of each), and which types he can remove
local function debuffTypes()
	local have, mine = {}, {}
	pcall(function()
		for _, filter in ipairs({ "HARMFUL", "HARMFUL|RAID" }) do
			for i = 1, 40 do
				local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
				if not aura then break end
				local t = aura.dispelName
				if plain(t) and AU.DEBUFF_COLORS[t] then
					if filter == "HARMFUL" then have[t] = have[t] or aura else mine[t] = true end
				end
			end
		end
	end)
	return have, mine
end

function AU:UpdateLife()
	local list = self.sockets and self.sockets.life
	if not list then return end
	local have, mine
	if preview then
		local now = GetTime()
		have = { Magic = { expirationTime = now + 12, duration = 15 }, Poison = { expirationTime = now + 21, duration = 30 } }
		mine = { Magic = true }
	elseif self.db.debuffSockets then
		have, mine = debuffTypes()
	else
		have, mine = {}, {}
	end
	for i, s in ipairs(list) do
		local t = self.DEBUFF_TYPES[i]
		s.icon:Hide()
		s.rim:Hide()
		if have[t] then
			setTime(s, have[t], false, self.db.debuffTime)
			local c = self.DEBUFF_COLORS[t]
			s.glow:SetVertexColor(c[1], c[2], c[3])
			s.glow:Show()
			if self.db.debuffPulse and mine[t] then
				if not s.pulse:IsPlaying() then s.pulse:Play() end
			else
				s.pulse:Stop()
				s.glow:SetAlpha(1)
			end
			s:Show()
		else
			setTime(s, nil)
			s.pulse:Stop()
			s:Hide()
		end
	end
end

function AU:Update()
	self:UpdatePower()
	self:UpdateLife()
end

function AU:SetPreview(on)
	preview = on
	self:Update()
end

--[[ Wiring ]]

function AU:OnEnable()
	self:Chosen()
	local Orbs = H.Modules.byName.Orbs
	if Orbs and Orbs.Layout then
		hooksecurefunc(Orbs, "Layout", function() AU:Layout() end)
	end
	H:RegisterEvent("UNIT_AURA", function(_, unit)
		if unit == "player" then AU:Update() end
	end)
	H:RegisterEvent("PLAYER_ENTERING_WORLD", function() AU:Update() end)
	H:On("THEME_CHANGED", function() AU:Layout() end)
	H:On("FONTS_CHANGED", function() AU:Layout() end)
	self:Layout()
	if self.LayoutRows then
		self:LayoutRows()
		-- the minimap and the orbs register their movers after this module
		C_Timer.After(0.5, function() AU:LayoutRows() end)
	end
end

function AU:OnProfileChanged()
	self:Layout()
	if self.LayoutRows then self:LayoutRows() end
end

H.previews = H.previews or {}
H.previews[#H.previews + 1] = {
	key = "sockets",
	label = "Orb sockets",
	desc = "Your chosen auras in the power orb's gems, and a magic (removable) and a poison debuff on the life orb.",
	get = function() return preview end,
	set = function(v) AU:SetPreview(v) end,
}
