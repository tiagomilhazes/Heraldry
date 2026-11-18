--[[
	Heraldry_UnitFrames - Party.lua
	The party, one row per member:

	  style "cartouche" (default)
	      one piece of art (Media/Party/Frame.tga, made in Canva in the lion's
	      style): a square window on the left for the class symbol, two slots for
	      life and mana, and a gem socket on the right whose gem takes the colour
	      of the member's debuff (magic, curse, disease, poison), dark when none.
	      The bars sit behind the frame; only the middle stretches with the width.
	  style "compact"
	      slim rows with a small class jewel and a percentage; the rim turns red
	      when life is low

	  - secure unit buttons: click targets, right-click opens the menu,
	    registered for click-casting
	  - dead, ghost and offline members are greyed with the state written;
	    members out of range fade (when the game lets us read the range)
	  - the group leader carries a small crown
	  - all members sit in one container (a mover, "Party"), in a column or a
	    row; the player can be shown too
	  - hidden in a raid unless asked; the game's party frames are hidden
	  - preview: made-up members, to set it all up without a group

	Built on Small.lua (bars, texts, secure button); its plaque is not used here.
	Settings are stored with the prefix "party" in the module's profile.
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames
local Small = UF.Small
local Themes = H.Themes

local FLAT = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local LEADER = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local SYMBOLS = "Interface\\AddOns\\Heraldry_UnitFrames\\Media\\Party\\Class\\"

-- The cartouche (pixels of the 1024 x 512 file; the art fills the top 301 rows)
UF.CARTOUCHE = {
	file = "Interface\\AddOns\\Heraldry_UnitFrames\\Media\\Party\\Frame",
	size = { 1024, 512 }, art = { 940, 301 },
	window = { 11, 55, 197, 242 },      -- the class symbol, set into the frame
	life = { 242, 93, 732, 168 },       -- slot of the life bar
	power = { 241, 182, 732, 212 },     -- slot of the power bar
	gem = { 832, 146, 46 },             -- centre and radius of the gem
	split = { 356, 616 },               -- only these columns stretch
}

local hidden = CreateFrame("Frame")
hidden:Hide()

local DEFAULTS = {
	partyShow = true,
	partyStyle = "cartouche",     -- "cartouche" | "compact"
	partyHeight = 56,             -- cartouche: height of the whole frame (the art scales with it)
	partyLifeFill = 1,            -- cartouche: share of the life slot the bar fills
	partyPowerFill = 1,           -- cartouche: share of the mana slot the bar fills
	partyMuted = true,            -- bar colours toned down to sit with the metal
	partyWidth = 210, partyHealthHeight = 16, partyPowerHeight = 5, partyShowPower = true,
	partyNameSize = 11, partyPctSize = 10,
	partyDirection = "down",      -- "down" | "up" | "right" | "left"
	partySpacing = 6,
	partyPlayer = false,
	partyRange = true, partyRangeAlpha = 0.45,
	partyLeader = true,
	partyDebuff = true,           -- the jewel shows the debuff's colour
	partyDispelOnly = false,      -- only debuffs you can remove
	partyLowLife = 0.35,          -- compact: red rim below this
	partyHideBlizzard = true,
	partyInRaid = false,
}
for k, v in pairs(DEFAULTS) do UF.defaults[k] = v end

-- made-up members for the preview
local PREVIEW = {
	{ name = "Julian", class = "PALADIN", life = 0.85, power = 0.7, leader = true },
	{ name = "Mara",   class = "MAGE",    life = 0.25, power = 0.4, debuff = "Magic" },
	{ name = "Rok",    class = "HUNTER",  life = 1.0,  power = 0.9, debuff = "Poison" },
	{ name = "Elia",   class = "PRIEST",  life = 0.6,  power = 0.55 },
	{ name = "Tom",    class = "WARRIOR", life = 0,    power = 0,   dead = true },
}

local DEBUFF = {
	Magic   = { 0.20, 0.60, 1.00 },
	Curse   = { 0.60, 0.00, 1.00 },
	Disease = { 0.60, 0.40, 0.00 },
	Poison  = { 0.00, 0.60, 0.00 },
}

local function classRGB(class)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
	return 0.8, 0.8, 0.8
end

-- a colour toned down towards painted metal: less bright, less saturated
local function mute(r, g, b)
	local grey = (r + g + b) / 3
	local function m(c) return (c + (grey - c) * 0.3) * 0.72 end
	return m(r), m(g), m(b)
end

local function accent()
	local r, g, b = Themes:Accent()
	if not r then r, g, b = 0.42, 0.34, 0.19 end
	return r, g, b
end

-- the colour of the member's debuff, or nil (aura data can be secret in combat: then nil)
local function debuffColor(unit, dispelOnly)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	local found
	pcall(function()
		local filter = dispelOnly and "HARMFUL|RAID" or "HARMFUL"
		for i = 1, 40 do
			local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
			if not aura then break end
			local t = aura.dispelName
			if t and DEBUFF[t] then
				found = DEBUFF[t]
				break
			end
		end
	end)
	return found
end

local function rimAround(list, region, pad)
	for _, t in ipairs(list) do t:ClearAllPoints() end
	list[1]:SetPoint("TOPLEFT", region, "TOPLEFT", -pad, pad); list[1]:SetPoint("TOPRIGHT", region, "TOPRIGHT", pad, pad); list[1]:SetHeight(1)
	list[2]:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", -pad, -pad); list[2]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", pad, -pad); list[2]:SetHeight(1)
	list[3]:SetPoint("TOPLEFT", region, "TOPLEFT", -pad, pad); list[3]:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", -pad, -pad); list[3]:SetWidth(1)
	list[4]:SetPoint("TOPRIGHT", region, "TOPRIGHT", pad, pad); list[4]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", pad, -pad); list[4]:SetWidth(1)
end

--[[ One member ]]

local Member = setmetatable({}, { __index = Small })
Member.__index = Member

function Member:Get(name) return UF.db["party" .. name] end
function Member:Compact() return UF.db.partyStyle == "compact" end

function Member:Create()
	Small.Create(self)
	local f = self.frame
	f:SetParent(UF.party.container)
	local art = f.texts
	f.leader = art:CreateTexture(nil, "OVERLAY", nil, 2)
	f.leader:SetTexture(LEADER)
	-- compact: a thin metal rim around the bars and a class jewel
	f.rim = {}
	for i = 1, 4 do f.rim[i] = art:CreateTexture(nil, "BORDER") end
	f.dot = art:CreateTexture(nil, "ARTWORK", nil, 1)
	f.dot:SetTexture(FLAT)
	local m = art:CreateMaskTexture()
	m:SetTexture(MASK)
	m:SetAllPoints(f.dot)
	f.dot:AddMaskTexture(m)
	f.dotRim = art:CreateTexture(nil, "ARTWORK", nil, 0)
	f.dotRim:SetTexture(FLAT)
	local m2 = art:CreateMaskTexture()
	m2:SetTexture(MASK)
	m2:SetAllPoints(f.dotRim)
	f.dotRim:AddMaskTexture(m2)
	-- cartouche: dark slots behind the bars, and the class symbol in its window
	f.slotBg = { f:CreateTexture(nil, "BACKGROUND"), f:CreateTexture(nil, "BACKGROUND") }
	for _, t in ipairs(f.slotBg) do t:SetColorTexture(0.03, 0.025, 0.02, 0.95) end
	f.symHolder = CreateFrame("Frame", nil, f)
	f.symbolBg = f.symHolder:CreateTexture(nil, "BACKGROUND")
	f.symbolBg:SetColorTexture(0, 0, 0, 0)
	f.symbol = f.symHolder:CreateTexture(nil, "ARTWORK")
	if self.unit == "player" then
		-- the player is there anyway: show it only in a group
		UnregisterUnitWatch(f)
		RegisterStateDriver(f, "visibility", "[group] show; hide")
	end
end

-- how far the art reaches past the button: left, top, right, bottom
function Member:Reach()
	if self:Compact() then
		local j = self:DotSize()
		return j + 6, 1, 1, 1
	end
	return 0, 0, 0, 0   -- the cartouche is the button
end

function Member:DotSize()
	return math.max(8, self.frame:GetHeight() * 0.6)
end

function Member:Layout()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() self:Layout() end, "uf-party-" .. self.unit)
		return
	end
	Small.Layout(self)
	local f = self.frame
	local compact = self:Compact()
	local ar, ag, ab = accent()
	local base = f:GetFrameLevel()
	f.symHolder:SetFrameLevel(base + 2)

	f.plaque:SetShown(not compact)
	f.symHolder:SetShown(not compact)
	for _, t in ipairs(f.slotBg) do t:SetShown(not compact) end
	for _, t in ipairs(f.rim) do t:SetShown(compact) end
	f.dot:SetShown(compact)
	f.dotRim:SetShown(compact)

	if compact then
		rimAround(f.rim, f, 1)
		local j = self:DotSize()
		f.dot:SetSize(j, j)
		f.dot:ClearAllPoints()
		f.dot:SetPoint("RIGHT", f, "LEFT", -4, 0)
		f.dotRim:SetSize(j + 3, j + 3)
		f.dotRim:ClearAllPoints()
		f.dotRim:SetPoint("CENTER", f.dot)
		f.dotRim:SetVertexColor(ar, ag, ab)
	else
		self:LayoutCartouche()
	end

	-- the crown sits on the top of the life bar's left end (compact) or the window (cartouche)
	local cs = math.max(10, f.health:GetHeight() * (compact and 0.8 or 1.2))
	f.leader:SetSize(cs, cs)
	f.leader:ClearAllPoints()
	if compact then
		f.leader:SetPoint("CENTER", f.health, "TOPLEFT", 6, 1)
	else
		f.leader:SetPoint("CENTER", f.symbol, "TOPLEFT", 2, -2)
	end
	self:Update()
end

-- The cartouche: three slices of the art over the bars; the button is the whole frame.
function Member:LayoutCartouche()
	local f, C = self.frame, UF.CARTOUCHE
	local FW, FH = C.size[1], C.size[2]
	local AW, AH = C.art[1], C.art[2]
	local k = self:Get("Height") / AH
	local a, b = C.split[1], C.split[2]
	local minW = (a + (AW - b)) * k
	local W = math.max(self:Get("Width"), minW)
	f:SetSize(W, AH * k)

	local L, M, R = f.slices[1], f.slices[2], f.slices[3]
	for _, t in ipairs(f.slices) do
		t:SetTexture(C.file)
		t:ClearAllPoints()
	end
	local v = AH / FH
	L:SetTexCoord(0, a / FW, 0, v)
	M:SetTexCoord(a / FW, b / FW, 0, v)
	R:SetTexCoord(b / FW, AW / FW, 0, v)
	L:SetSize(a * k, AH * k)
	R:SetSize((AW - b) * k, AH * k)
	L:SetPoint("TOPLEFT")
	R:SetPoint("TOPRIGHT")
	M:SetPoint("TOPLEFT", L, "TOPRIGHT")
	M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")

	-- each slot gets a dark ground (a pixel larger, so no gap shows at the rims);
	-- the bar fills the share of its height set in the options, centred
	local function slot(bar, bg, s, fill)
		local top, bottom = s[2] * k - 1, s[4] * k + 1
		bg:ClearAllPoints()
		bg:SetPoint("TOPLEFT", f, "TOPLEFT", s[1] * k - 1, -top)
		bg:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -(AW - s[3]) * k + 1, -bottom)
		local h = (bottom - top) * fill
		local mid = (top + bottom) / 2
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", f, "TOPLEFT", s[1] * k - 1, -(mid - h / 2))
		bar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -(AW - s[3]) * k + 1, -(mid + h / 2))
	end
	slot(f.health, f.slotBg[1], C.life, self:Get("LifeFill"))
	f.power:Show()
	slot(f.power, f.slotBg[2], C.power, self:Get("PowerFill"))
	f.health.bg:SetColorTexture(0, 0, 0, 0)
	f.power.bg:SetColorTexture(0, 0, 0, 0)

	-- the class symbol fills the window
	local w = C.window
	f.symbol:ClearAllPoints()
	f.symbol:SetPoint("TOPLEFT", f, "TOPLEFT", w[1] * k, -w[2] * k)
	f.symbol:SetSize((w[3] - w[1]) * k, (w[4] - w[2]) * k)
	f.symbolBg:ClearAllPoints()
	f.symbolBg:SetAllPoints(f.symbol)

	-- the gem, drawn again on top to recolour it (debuff)
	local g = C.gem
	local gem = f.jewels[1]
	gem:SetTexture(C.file)
	gem:SetTexCoord((g[1] - g[3]) / FW, (g[1] + g[3]) / FW, (g[2] - g[3]) / FH, (g[2] + g[3]) / FH)
	gem:SetSize(2 * g[3] * k, 2 * g[3] * k)
	gem:ClearAllPoints()
	gem:SetPoint("CENTER", f, "TOPRIGHT", -(AW - g[1]) * k, -g[2] * k)
	f.jewels[2]:Hide()
	gem:SetShown(self:Get("Debuff"))

	-- texts inside the life bar
	f.name:ClearAllPoints()
	f.name:SetPoint("LEFT", f.health, "LEFT", 4, 0)
	f.name:SetPoint("RIGHT", f.health, "RIGHT", -4 - self:Get("PctSize") * 2.8, 0)
	f.pct:ClearAllPoints()
	f.pct:SetPoint("RIGHT", f.health, "RIGHT", -4, 0)
end

-- bar colours toned down to sit with the metal (option)
function Member:ToneBars()
	if not self:Get("Muted") then return end
	local f = self.frame
	for _, bar in ipairs({ f.health, f.power }) do
		local r, g, b = bar:GetStatusBarColor()
		if type(r) == "number" then bar:SetStatusBarColor(mute(r, g, b)) end
	end
end

function Member:SetClass(class, off)
	local f = self.frame
	if self:Compact() then
		local r, g, b = classRGB(class)
		f.dot:SetVertexColor(r, g, b)
		return
	end
	if class then f.symbol:SetTexture(SYMBOLS .. class) end
	-- the symbol is set into the frame (recess and shadow baked into the art) and
	-- carries its class colour in the art, so no finish on it; greyed when off
	f.symbol:SetDesaturation(off and 1 or 0)
	f.symbol:SetVertexColor(1, 1, 1)
	f.symbol:SetAlpha(off and 0.6 or 1)
end

-- the gem takes the debuff's colour; without one it stays a dark stone
function Member:SetDebuff(color)
	if self:Compact() then return end
	local gem = self.frame.jewels[1]
	if not self:Get("Debuff") then
		gem:Hide()
		return
	end
	gem:Show()
	gem:SetDesaturation(1)
	if color then
		gem:SetVertexColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3)
	else
		gem:SetVertexColor(0.32, 0.29, 0.25)
	end
end

function Member:Fake()
	return UF.party.preview and PREVIEW[self.slot]
end

function Member:Update()
	local f = self.frame
	if not f then return end
	local p = self:Fake()
	if p then return self:UpdatePreview(p) end
	local unit = self.unit
	if not UnitExists(unit) then return end
	Small.Update(self)

	local offline = not UnitIsConnected(unit)
	if offline then
		f.pct:SetText(PLAYER_OFFLINE or "Offline")
	elseif UnitIsGhost(unit) then
		f.pct:SetText("Ghost")
	end
	local off = offline or UnitIsDeadOrGhost(unit)
	f.name:SetAlpha(off and 0.6 or 1)
	f.leader:SetShown(self:Get("Leader") and UnitIsGroupLeader(unit) or false)
	self:SetClass(select(2, UnitClass(unit)), off)
	self:ToneBars()
	self:UpdateDebuff()
	self:UpdateRange()
	if self:Compact() then self:UpdateRim(unit) else self:SetRimColor(false) end
end

function Member:UpdateDebuff()
	if self:Compact() then return end
	if not self:Get("Debuff") then return self:SetDebuff(nil) end
	self:SetDebuff(debuffColor(self.unit, self:Get("DispelOnly")))
end

function Member:UpdatePreview(p)
	local f = self.frame
	f.health:SetMinMaxValues(0, 1)
	f.health:SetValue(p.life)
	local r, g, b = classRGB(p.class)
	if p.dead then
		f.health:SetStatusBarColor(0.45, 0.45, 0.45)
		f.pct:SetText(DEAD or "Dead")
	else
		if UF.db.classColor then f.health:SetStatusBarColor(r, g, b) else f.health:SetStatusBarColor(0.2, 0.75, 0.2) end
		f.pct:SetFormattedText("%d%%", p.life * 100)
	end
	f.name:SetText(p.name)
	f.name:SetAlpha(p.dead and 0.6 or 1)
	if f.power:IsShown() then
		f.power:SetMinMaxValues(0, 1)
		f.power:SetValue(p.power)
		f.power:SetStatusBarColor(0.25, 0.45, 0.95)
	end
	f.leader:SetShown(self:Get("Leader") and p.leader or false)
	local desat, cr, cg, cb = UF:Finish("player")
	for _, t in ipairs(f.slices) do
		t:SetDesaturation(desat)
		t:SetVertexColor(cr, cg, cb)
	end
	self:SetClass(p.class, p.dead)
	self:ToneBars()
	self:SetDebuff(p.debuff and DEBUFF[p.debuff])
	f:SetAlpha(1)
	self:SetRimColor(self:Compact() and not p.dead and p.life < self:Get("LowLife"))
end

-- out of range: faded, when the game answers (its answer may be secret in combat)
function Member:UpdateRange()
	local f = self.frame
	if not self:Get("Range") or self.unit == "player" or not UnitInRange then
		f:SetAlpha(1)
		return
	end
	local ok, inRange, checked = pcall(function()
		local a, b = UnitInRange(self.unit)
		return a and true or false, b and true or false
	end)
	if ok and checked and not inRange then
		f:SetAlpha(self:Get("RangeAlpha"))
	else
		f:SetAlpha(1)
	end
end

function Member:SetRimColor(low)
	local r, g, b
	if low then r, g, b = 0.85, 0.15, 0.1 else r, g, b = accent() end
	for _, t in ipairs(self.frame.rim) do t:SetColorTexture(r, g, b, 0.9) end
end

-- compact: red rim when life is low (the sum may be secret in combat: then it stays metal)
function Member:UpdateRim(unit)
	local low = false
	pcall(function()
		local m = UnitHealthMax(unit)
		low = not UnitIsDeadOrGhost(unit) and m > 0 and UnitHealth(unit) / m < self:Get("LowLife")
	end)
	self:SetRimColor(low)
end

--[[ The party: container and members ]]

local P = { members = {} }
UF.party = P

function UF:PartyUnits()
	local list = {}
	if self.db.partyPlayer then list[#list + 1] = "player" end
	for i = 1, 4 do list[#list + 1] = "party" .. i end
	return list
end

function UF:LayoutParty()
	if not P.container then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() UF:LayoutParty() end, "uf-party")
		return
	end
	local db = self.db
	local c = P.container
	for i, m in ipairs(P.members) do m.frame:SetFrameLevel(c:GetFrameLevel() + 2 + (i - 1) * 12) end
	for _, m in ipairs(P.members) do m:Layout() end
	local first = P.members[1]
	if not first then return end
	local w, h = first.frame:GetSize()
	local l, t, r, b = first:Reach()
	local cellW, cellH = w + l + r, h + t + b
	local gap = db.partySpacing
	local dir = db.partyDirection
	local n = #P.members
	if dir == "right" or dir == "left" then
		c:SetSize(n * cellW + (n - 1) * gap, cellH)
	else
		c:SetSize(cellW, n * cellH + (n - 1) * gap)
	end
	for i, m in ipairs(P.members) do
		local mf = m.frame
		local o = i - 1
		mf:ClearAllPoints()
		if dir == "down" then
			mf:SetPoint("TOPLEFT", c, "TOPLEFT", l, -t - o * (cellH + gap))
		elseif dir == "up" then
			mf:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", l, b + o * (cellH + gap))
		elseif dir == "right" then
			mf:SetPoint("TOPLEFT", c, "TOPLEFT", l + o * (cellW + gap), -t)
		else
			mf:SetPoint("TOPRIGHT", c, "TOPRIGHT", -r - o * (cellW + gap), -t)
		end
	end
	RegisterStateDriver(c, "visibility", (P.preview or db.partyInRaid) and "show" or "[group:raid] hide; show")
	self:PartyBlizzard()
	H.Movers:Apply(c.mover)
end

function UF:PartyBlizzard()
	local hide = self.db.partyHideBlizzard
	local frames = { PartyFrame, CompactPartyFrame }
	for i = 1, 4 do frames[#frames + 1] = _G["PartyMemberFrame" .. i] end
	for _, fr in pairs(frames) do
		if fr then
			if hide then
				fr.hParent = fr.hParent or fr:GetParent()
				fr:SetParent(hidden)
			elseif fr.hParent then
				fr:SetParent(fr.hParent)
			end
		end
	end
end

function UF:UpdateParty()
	for _, m in ipairs(P.members) do m:Update() end
end

--[[ Preview: made-up members, without a group ]]

function UF:SetPartyPreview(on)
	if not P.container then return end
	if InCombatLockdown() then
		H:Error("The party preview can't change in combat.")
		return
	end
	P.preview = on and true or false
	for _, m in ipairs(P.members) do
		local f = m.frame
		if on then
			UnregisterUnitWatch(f)
			UnregisterStateDriver(f, "visibility")
			f:Show()
		elseif m.unit == "player" then
			RegisterStateDriver(f, "visibility", "[group] show; hide")
		else
			RegisterUnitWatch(f)
		end
	end
	self:LayoutParty()
end

-- shown in General > Testing
H.previews = H.previews or {}
table.insert(H.previews, {
	label = "Party preview",
	desc = "Made-up members, to set up the party frames without a group.",
	get = function() return P.preview end,
	set = function(v) UF:SetPartyPreview(v) end,
})

--[[ Lifecycle: called from Target.lua's OnEnable ]]

function UF:EnableParty()
	if not self.db.partyShow then return end
	local c = CreateFrame("Frame", "HeraldryPartyFrame", UIParent, "SecureHandlerStateTemplate")
	c:SetFrameStrata("LOW")
	P.container = c
	c.mover = H:RegisterMover(c, "UnitFrames.party", {
		label = "Party", default = { "LEFT", 30, 120 }, scalable = true,
	})
	for i, unit in ipairs(self:PartyUnits()) do
		local name = unit == "player" and "HeraldryPartyPlayer" or ("HeraldryParty" .. unit:sub(-1))
		local m = setmetatable({ prefix = "party", unit = unit, globalName = name, slot = i }, Member)
		m:Create()
		P.members[#P.members + 1] = m
	end

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD" }) do
		ev:RegisterEvent(e)
	end
	local units = {}
	for _, m in ipairs(P.members) do units[#units + 1] = m.unit end
	for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
		"UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_AURA" }) do
		pcall(ev.RegisterUnitEvent, ev, e, unpack(units))
	end
	ev:SetScript("OnEvent", function(_, e, unit)
		if P.preview then return end
		if unit then
			for _, m in ipairs(P.members) do
				if m.unit == unit then
					if e == "UNIT_AURA" then m:UpdateDebuff() else m:Update() end
				end
			end
		else
			UF:UpdateParty()
		end
	end)
	-- range has no event: a light poll
	local t = 0
	c:HookScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		if t > 0.5 then
			t = 0
			if not P.preview then
				for _, m in ipairs(P.members) do
					if m.frame:IsShown() then m:UpdateRange() end
				end
			end
		end
	end)
	self:LayoutParty()
end
