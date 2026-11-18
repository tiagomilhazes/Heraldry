--[[
	Heraldry_UnitFrames - Party.lua
	The party, one row per member:

	  style "emblem" (default)
	      [class symbol in the theme's button frame] [life + power, thin metal rim] (o)
	      The class symbols (Media/Class/<CLASS>.tga) are gold emblems made in
	      Canva in the lion's style (Paladin hammer, Warrior sword, Hunter bow,
	      Rogue hood, Priest cross, Shaman totem, Mage flame, Warlock grimoire,
	      Druid paw), cut to the inner disc; they take the theme's finish.
	      The jewel on the right shows the colour of the member's debuff (magic,
	      curse, disease, poison) and stays dark when there is none.
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
local SYMBOLS = "Interface\\AddOns\\Heraldry_UnitFrames\\Media\\Class\\"

local hidden = CreateFrame("Frame")
hidden:Hide()

local DEFAULTS = {
	partyShow = true,
	partyStyle = "emblem",        -- "emblem" | "compact"
	partyWidth = 170, partyHealthHeight = 16, partyPowerHeight = 5, partyShowPower = true,
	partyNameSize = 11, partyPctSize = 10,
	partySymbolSize = 40,         -- the class symbol's box
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
	f.plaque:Hide()   -- this frame has its own art
	local art = f.texts
	f.leader = art:CreateTexture(nil, "OVERLAY", nil, 2)
	f.leader:SetTexture(LEADER)
	-- thin metal rim around the bars
	f.rim = {}
	for i = 1, 4 do f.rim[i] = art:CreateTexture(nil, "BORDER") end
	-- class symbol in a straight frame (the theme's button frame)
	f.symbolBg = art:CreateTexture(nil, "BACKGROUND")
	f.symbolBg:SetColorTexture(0.04, 0.035, 0.03, 0.9)
	f.symbol = art:CreateTexture(nil, "ARTWORK", nil, 0)
	f.symbolFrame = art:CreateTexture(nil, "OVERLAY", nil, 0)
	f.symbolRim = {}
	for i = 1, 4 do f.symbolRim[i] = art:CreateTexture(nil, "OVERLAY", nil, 1) end
	-- the jewel: debuff colour (emblem style) or class colour (compact)
	f.jewelRim = art:CreateTexture(nil, "ARTWORK", nil, 0)
	f.jewelRim:SetTexture(FLAT)
	local m2 = art:CreateMaskTexture()
	m2:SetTexture(MASK)
	m2:SetAllPoints(f.jewelRim)
	f.jewelRim:AddMaskTexture(m2)
	f.jewel = art:CreateTexture(nil, "ARTWORK", nil, 1)
	f.jewel:SetTexture(FLAT)
	local m = art:CreateMaskTexture()
	m:SetTexture(MASK)
	m:SetAllPoints(f.jewel)
	f.jewel:AddMaskTexture(m)
	if self.unit == "player" then
		-- the player is there anyway: show it only in a group
		UnregisterUnitWatch(f)
		RegisterStateDriver(f, "visibility", "[group] show; hide")
	end
end

function Member:JewelSize()
	return math.max(8, self.frame:GetHeight() * (self:Compact() and 0.6 or 0.75))
end

-- how far the art reaches past the bars: left, top, right, bottom
function Member:Reach()
	local h = self.frame:GetHeight()
	local j = self:JewelSize()
	if self:Compact() then return j + 6, 1, 1, 1 end
	local s = math.max(self:Get("SymbolSize"), h)
	local v = math.max((s - h) / 2, 0) + 2
	return s + 8, v, j + 6, v
end

function Member:Layout()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() self:Layout() end, "uf-party-" .. self.unit)
		return
	end
	Small.Layout(self)
	local f = self.frame
	f.plaque:Hide()
	local compact = self:Compact()
	local h = f:GetHeight()
	local ar, ag, ab = accent()

	rimAround(f.rim, f, 1)

	-- the jewel: on the right (debuff), or on the left (compact: class)
	local j = self:JewelSize()
	f.jewel:SetSize(j, j)
	f.jewelRim:SetSize(j + 3, j + 3)
	f.jewel:ClearAllPoints()
	if compact then
		f.jewel:SetPoint("RIGHT", f, "LEFT", -4, 0)
	else
		f.jewel:SetPoint("LEFT", f, "RIGHT", 4, 0)
	end
	f.jewelRim:ClearAllPoints()
	f.jewelRim:SetPoint("CENTER", f.jewel)
	f.jewelRim:SetVertexColor(ar, ag, ab)
	f.jewel:Show()
	f.jewelRim:Show()

	-- the class symbol, in a straight frame
	for _, t in ipairs({ f.symbol, f.symbolBg, f.symbolFrame }) do t:SetShown(not compact) end
	for _, t in ipairs(f.symbolRim) do t:Hide() end
	if not compact then
		local s = math.max(self:Get("SymbolSize"), h)
		f.symbol:SetSize(s, s)
		f.symbol:ClearAllPoints()
		f.symbol:SetPoint("RIGHT", f, "LEFT", -6, 0)
		f.symbolBg:ClearAllPoints()
		f.symbolBg:SetAllPoints(f.symbol)
		local piece = Themes:Piece("button.frame")
		if piece then
			-- the frame's hole fits the symbol's box
			local hole = piece.hole
			local k = s / (hole[3] - hole[1])
			f.symbolFrame:SetTexture(piece.file)
			f.symbolFrame:SetSize(piece.size[1] * k, piece.size[2] * k)
			f.symbolFrame:ClearAllPoints()
			f.symbolFrame:SetPoint("TOPLEFT", f.symbol, "TOPLEFT", -hole[1] * k, hole[2] * k)
			Themes:Paint(f.symbolFrame)
		else
			f.symbolFrame:Hide()
			rimAround(f.symbolRim, f.symbol, 1)
			for _, t in ipairs(f.symbolRim) do
				t:SetColorTexture(ar, ag, ab, 0.9)
				t:Show()
			end
		end
	end

	-- the crown sits on the top left corner of the life bar
	local cs = math.max(10, f.health:GetHeight() * 0.8)
	f.leader:SetSize(cs, cs)
	f.leader:ClearAllPoints()
	f.leader:SetPoint("CENTER", f.health, "TOPLEFT", 6, 1)
	self:Update()
end

function Member:SetClass(class, off)
	local f = self.frame
	if self:Compact() then
		local r, g, b = classRGB(class)
		f.jewel:SetVertexColor(r, g, b)
		return
	end
	if class then f.symbol:SetTexture(SYMBOLS .. class) end
	-- the symbols are gold: they take the theme's finish, like the frame around them
	Themes:Paint(f.symbol)
	if off then f.symbol:SetDesaturation(1) end
	f.symbol:SetAlpha(off and 0.6 or 1)
end

function Member:SetDebuff(color)
	if self:Compact() then return end
	local f = self.frame
	local show = self:Get("Debuff")
	f.jewel:SetShown(show)
	f.jewelRim:SetShown(show)
	if not show then return end
	if color then
		f.jewel:SetVertexColor(color[1], color[2], color[3])
	else
		f.jewel:SetVertexColor(0.09, 0.08, 0.07)   -- an empty socket
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
	f.plaque:Hide()

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
	self:SetClass(p.class, p.dead)
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
