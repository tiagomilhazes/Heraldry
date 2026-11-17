--[[
	Heraldry_UnitFrames - Small.lua
	Target of target and focus: smaller versions of the target's plaque
	(same art, same finish and jewel rules, see TargetPlaque.lua), with the
	life bar (and, for the focus, the power row, where its casts show too).
	No level ring: these frames are glanced at, not read.

	Each frame has its own settings, stored with a prefix in the module's
	profile ("tot..." and "focus...").
	  totDock    the target of target sits at the right of the target's plaque
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames
local Themes = H.Themes

local FLAT = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local INTERP = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local hidden = CreateFrame("Frame")
hidden:Hide()

-- defaults, merged into the module's (Target.lua owns the module)
local DEFAULTS = {
	totShow = true, totDock = true, totWidth = 140, totHealthHeight = 14,
	totNameSize = 10, totPctSize = 9,
	focusShow = true, focusWidth = 190, focusHealthHeight = 16, focusPowerHeight = 6, focusShowPower = true,
	focusNameSize = 11, focusPctSize = 10, focusHideBlizzard = true,
}
for k, v in pairs(DEFAULTS) do UF.defaults[k] = v end

UF.small = {}

local function bar(parent)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetStatusBarTexture(FLAT)
	b:SetMinMaxValues(0, 1)
	b:SetValue(1)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0, 0, 0, 0.6)
	return b
end

local function text(parent, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetJustifyH(justify)
	fs:SetWordWrap(false)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

local function percentOf(unit)
	if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
		local ok, p = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
		if ok and p then return p end
	end
	local ok, p = pcall(function()
		local m = UnitHealthMax(unit)
		return m > 0 and UnitHealth(unit) / m * 100 or 0
	end)
	if ok then return p end
end

--[[ One small frame ]]

local Small = {}
Small.__index = Small

function Small:Get(name) return UF.db[self.prefix .. name] end

function Small:Create()
	local unit = self.unit
	local f = CreateFrame("Button", self.globalName, UIParent, "SecureUnitButtonTemplate")
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(10)
	f:RegisterForClicks("AnyUp")
	f:SetAttribute("unit", unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "togglemenu")
	f:SetScript("OnEnter", function(btn)
		GameTooltip_SetDefaultAnchor(GameTooltip, btn)
		GameTooltip:SetUnit(unit)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[f] = true

	f.health = bar(f)
	f.power = bar(f)
	local plaque = CreateFrame("Frame", nil, f)
	plaque:SetAllPoints()
	f.plaque = plaque
	f.slices = { plaque:CreateTexture(nil, "ARTWORK"), plaque:CreateTexture(nil, "ARTWORK"), plaque:CreateTexture(nil, "ARTWORK") }
	f.jewels = {}
	for i = 1, 2 do
		local j = plaque:CreateTexture(nil, "OVERLAY")
		local m = plaque:CreateMaskTexture()
		m:SetTexture(MASK)
		m:SetAllPoints(j)
		j:AddMaskTexture(m)
		f.jewels[i] = j
	end
	local texts = CreateFrame("Frame", nil, f)
	texts:SetAllPoints()
	f.texts = texts
	f.name = text(texts, "LEFT")
	f.pct = text(texts, "RIGHT")
	self.frame = f
	RegisterUnitWatch(f)
end

-- Same geometry as the target's plaque, scaled from this frame's bars.
function Small:Layout()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() self:Layout() end, "uf-small-" .. self.prefix)
		return
	end
	local f, P = self.frame, UF.PLAQUE
	local width, hh = self:Get("Width"), self:Get("HealthHeight")
	local power = self:Get("ShowPower") and self:Get("PowerHeight") or nil
	local barsH = hh + (power and (2 + power) or 0)
	f:SetSize(width, barsH)

	local base = f:GetFrameLevel()
	f.health:SetFrameLevel(base + 1)
	f.power:SetFrameLevel(base + 1)
	f.plaque:SetFrameLevel(base + 3)
	f.texts:SetFrameLevel(base + 7)

	f.health:ClearAllPoints()
	f.health:SetPoint("TOPLEFT")
	f.health:SetPoint("TOPRIGHT")
	f.health:SetHeight(hh)
	f.power:SetShown(power ~= nil)
	if power then
		f.power:ClearAllPoints()
		f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
		f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
		f.power:SetHeight(power)
	end

	-- plaque in 3 slices, jewels recoloured
	local W, Ht = P.size[1], P.size[2]
	local sl, st, sr, sb = P.slot[1], P.slot[2], P.slot[3], P.slot[4]
	local k = barsH / (sb - st)
	self.k = k
	local a, b = P.split[1], P.split[2]
	local L, M, R = f.slices[1], f.slices[2], f.slices[3]
	for _, t in ipairs(f.slices) do
		t:SetTexture(P.file)
		t:ClearAllPoints()
	end
	L:SetTexCoord(0, a / W, 0, 1)
	M:SetTexCoord(a / W, b / W, 0, 1)
	R:SetTexCoord(b / W, 1, 0, 1)
	L:SetSize(a * k, Ht * k)
	R:SetSize((W - b) * k, Ht * k)
	L:SetPoint("TOPLEFT", f, "TOPLEFT", -sl * k, st * k)
	R:SetPoint("TOPRIGHT", f, "TOPRIGHT", (W - sr) * k, st * k)
	M:SetPoint("TOPLEFT", L, "TOPRIGHT")
	M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")
	for i, g in ipairs(P.gems) do
		local j = f.jewels[i]
		local x, y, rad = g[1], g[2], g[3]
		j:SetTexture(P.file)
		j:SetTexCoord((x - rad) / W, (x + rad) / W, (y - rad) / Ht, (y + rad) / Ht)
		j:SetSize(2 * rad * k, 2 * rad * k)
		j:ClearAllPoints()
		if i == 1 then
			j:SetPoint("CENTER", f, "TOPLEFT", (x - sl) * k, -(y - st) * k)
		else
			j:SetPoint("CENTER", f, "TOPRIGHT", (x - sr) * k, -(y - st) * k)
		end
	end

	-- texts in the life bar
	H.Fonts:Apply(f.name, "header", self:Get("NameSize"), UF)
	H.Fonts:Apply(f.pct, "body", self:Get("PctSize"), UF)
	f.pct:ClearAllPoints()
	f.pct:SetPoint("RIGHT", f.health, "RIGHT", -6, 0)
	f.name:ClearAllPoints()
	f.name:SetPoint("LEFT", f.health, "LEFT", 6, 0)
	f.name:SetPoint("RIGHT", f.health, "RIGHT", -6 - self:Get("PctSize") * 2.8, 0)

	if self.OnLayout then self:OnLayout() end
	H.Movers:Apply(f.mover)
	self:Update()
end

function Small:Update()
	local f, unit = self.frame, self.unit
	if not f or not UnitExists(unit) then return end
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	UF.util.setBar(f.health, cur, max)
	f.health:SetStatusBarColor(UF:HealthColor(unit))
	if UnitIsDeadOrGhost(unit) then
		f.pct:SetText(DEAD or "Dead")
	elseif not pcall(function() f.pct:SetFormattedText("%d%%", percentOf(unit)) end) then
		f.pct:SetText("")
	end
	f.name:SetText(UnitName(unit) or "")
	if f.power:IsShown() then
		local ptype, token = UnitPowerType(unit)
		UF.util.setBar(f.power, UnitPower(unit, ptype), UnitPowerMax(unit, ptype))
		local c = (PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])) or { r = 0.3, g = 0.5, b = 1 }
		f.power:SetStatusBarColor(c.r, c.g, c.b)
	end
	-- finish and jewels, as on the target
	local kind = UF:Kind(unit)
	local desat, cr, cg, cb = UF:Finish(kind)
	for _, t in ipairs(f.slices) do
		t:SetDesaturation(desat)
		t:SetVertexColor(cr, cg, cb)
	end
	local r, g, b = UF:JewelColor(kind, unit)
	for _, j in ipairs(f.jewels) do
		j:SetDesaturation(1)
		j:SetVertexColor(r, g, b)
	end
end

local function newSmall(prefix, unit, globalName, label, default)
	local s = setmetatable({ prefix = prefix, unit = unit, globalName = globalName, label = label, default = default }, Small)
	UF.small[prefix] = s
	return s
end

--[[ Target of target ]]

local tot = newSmall("tot", "targettarget", "HeraldryTargetTargetFrame", "Target of target", { "BOTTOM", 220, 230 })

-- life bar only
function tot:Get(name)
	if name == "ShowPower" then return false end
	return UF.db["tot" .. name]
end

-- Docked at the right of the target's plaque, clear of both lion medallions.
function tot:OnLayout()
	local P = UF.PLAQUE
	local key = "UnitFrames.targettarget"
	if self:Get("Dock") and UF.frame and UF.frame.mover then
		local tf = UF.frame
		local tk = tf:GetHeight() / (P.slot[4] - P.slot[2])
		local gap = (P.size[1] - P.slot[3]) * tk + P.slot[1] * self.k + 4
		H.Movers:Dock(key, "UnitFrames.target", "LEFT", "RIGHT", gap, 0)
	else
		H.Movers:Undock(key)
	end
end

--[[ Focus ]]

local focus = newSmall("focus", "focus", "HeraldryFocusFrame", "Focus", { "LEFT", 320, 60 })

function focus:OnLayout()
	local ff = FocusFrame
	if not ff then return end
	if UF.db.focusHideBlizzard then
		self.ffParent = self.ffParent or ff:GetParent()
		ff:SetParent(hidden)
	elseif self.ffParent then
		ff:SetParent(self.ffParent)
	end
end

--[[ Lifecycle: called from Target.lua's OnEnable ]]

function UF:EnableSmall()
	for prefix, s in pairs(self.small) do
		if s:Get("Show") then
			s:Create()
			s.frame.mover = H:RegisterMover(s.frame, "UnitFrames." .. s.unit, {
				label = s.label, default = s.default, scalable = true,
			})
		end
	end
	-- the target of target has no events of its own: poll it, lightly
	if tot.frame then
		local t = 0
		tot.frame:HookScript("OnUpdate", function(_, elapsed)
			t = t + elapsed
			if t > 0.2 then
				t = 0
				tot:Update()
			end
		end)
	end
	if focus.frame then
		local ev = CreateFrame("Frame")
		ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
		for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
			"UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED" }) do
			pcall(ev.RegisterUnitEvent, ev, e, "focus")
		end
		ev:SetScript("OnEvent", function() focus:Update() end)
	end
	self:LayoutSmall()
end

function UF:LayoutSmall()
	for _, s in pairs(self.small) do
		if s.frame then s:Layout() end
	end
end
