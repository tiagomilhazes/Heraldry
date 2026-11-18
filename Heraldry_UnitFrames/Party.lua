--[[
	Heraldry_UnitFrames - Party.lua
	The party: one frame per member, built on Small.lua's plaque (style
	"plaque", prototype PF2: the target of target's plaque, stacked) or as a
	slim row with a class jewel (style "compact", PF3: percentages, a red rim
	when life is low).

	  - secure unit buttons: click targets, right-click opens the menu,
	    registered for click-casting
	  - dead, ghost and offline members are greyed with the state written;
	    members out of range fade (when the game lets us read the range)
	  - the group leader carries a small crown
	  - all members sit in one container (a mover, "Party"), in a column or a
	    row, growing the way you choose; the player can be shown too
	  - hidden in a raid unless asked; the game's party frames are hidden
	  - preview: four made-up members, to set it all up without a group

	Settings are stored with the prefix "party" in the module's profile.
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames
local Small = UF.Small

local FLAT = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- the lion faces in the plaque (pixels of the file): centre and radius of the inner circle
local FACES = { { 115, 128 }, { 907, 128 } }
local FACE_R = 54
local LEADER = "Interface\\GroupFrame\\UI-Group-LeaderIcon"

local hidden = CreateFrame("Frame")
hidden:Hide()

local DEFAULTS = {
	partyShow = true,
	partyStyle = "plaque",        -- "plaque" | "compact"
	partyWidth = 170, partyHealthHeight = 16, partyPowerHeight = 5, partyShowPower = true,
	partyNameSize = 11, partyPctSize = 10,
	partyDirection = "down",      -- "down" | "up" | "right" | "left"
	partySpacing = 22,            -- plaque: from one life bar to the next; the medallions interlock
	partyCompactSpacing = 4,      -- compact: between rows
	partyEmblems = true,          -- class emblems in the medallions
	partyPlayer = false,
	partyRange = true, partyRangeAlpha = 0.45,
	partyLeader = true,
	partyLowLife = 0.35,          -- compact: red rim below this
	partyHideBlizzard = true,
	partyInRaid = false,
}
for k, v in pairs(DEFAULTS) do UF.defaults[k] = v end

-- made-up members for the preview
local PREVIEW = {
	{ name = "Julian", class = "PALADIN", life = 0.85, power = 0.7, leader = true },
	{ name = "Mara",   class = "MAGE",    life = 0.25, power = 0.4 },
	{ name = "Rok",    class = "HUNTER",  life = 1.0,  power = 0.9 },
	{ name = "Elia",   class = "PRIEST",  life = 0.6,  power = 0.55 },
	{ name = "Tom",    class = "WARRIOR", life = 0,    power = 0,   dead = true },
}

local function classRGB(class)
	local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
	if c then return c.r, c.g, c.b end
	return 0.8, 0.8, 0.8
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
	-- extras: crown, compact rim and jewel
	f.leader = f.texts:CreateTexture(nil, "OVERLAY")
	f.leader:SetTexture(LEADER)
	f.rim = {}
	for i = 1, 4 do f.rim[i] = f.texts:CreateTexture(nil, "BORDER") end
	f.diamond = f.texts:CreateTexture(nil, "ARTWORK")
	f.diamond:SetTexture(FLAT)
	f.diamondRim = f.texts:CreateTexture(nil, "BORDER")
	f.diamondRim:SetTexture(FLAT)
	-- class emblems over the lions (the game's class icons until our own emblems exist)
	f.emblems = {}
	for i = 1, 2 do
		local e = f.plaque:CreateTexture(nil, "OVERLAY", nil, -1)
		local m = f.plaque:CreateMaskTexture()
		m:SetTexture(MASK)
		m:SetAllPoints(e)
		e:AddMaskTexture(m)
		f.emblems[i] = e
	end
	if self.unit == "player" then
		-- the player is there anyway: show it only in a group
		UnregisterUnitWatch(f)
		RegisterStateDriver(f, "visibility", "[group] show; hide")
	end
end

function Member:Layout()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() self:Layout() end, "uf-party-" .. self.unit)
		return
	end
	Small.Layout(self)
	local f = self.frame
	local compact = self:Compact()
	f.plaque:SetShown(not compact)
	for _, t in ipairs(f.rim) do t:SetShown(compact) end
	f.diamond:SetShown(compact)
	f.diamondRim:SetShown(compact)

	-- compact: a 1px rim around the bars and a jewel on the left
	local d = f.health:GetHeight() * 0.62
	if compact then
		local r = f.rim
		for _, t in ipairs(r) do t:ClearAllPoints() end
		r[1]:SetPoint("TOPLEFT", -1, 1); r[1]:SetPoint("TOPRIGHT", 1, 1); r[1]:SetHeight(1)
		r[2]:SetPoint("BOTTOMLEFT", -1, -1); r[2]:SetPoint("BOTTOMRIGHT", 1, -1); r[2]:SetHeight(1)
		r[3]:SetPoint("TOPLEFT", -1, 1); r[3]:SetPoint("BOTTOMLEFT", -1, -1); r[3]:SetWidth(1)
		r[4]:SetPoint("TOPRIGHT", 1, 1); r[4]:SetPoint("BOTTOMRIGHT", 1, -1); r[4]:SetWidth(1)
		f.diamond:SetSize(d, d)
		f.diamond:ClearAllPoints()
		f.diamond:SetPoint("CENTER", f.health, "LEFT", -d, 0)
		f.diamond:SetRotation(math.pi / 4)
		f.diamondRim:SetSize(d + 3, d + 3)
		f.diamondRim:ClearAllPoints()
		f.diamondRim:SetPoint("CENTER", f.diamond)
		f.diamondRim:SetRotation(math.pi / 4)
		local ar, ag, ab = H.Themes:Accent()
		f.diamondRim:SetVertexColor(ar or 0.85, ag or 0.7, ab or 0.37)
	end

	-- emblems on the lion faces
	if not compact then
		local P, k = UF.PLAQUE, self.k
		for i, c in ipairs(FACES) do
			local e = f.emblems[i]
			e:SetSize(2 * FACE_R * k, 2 * FACE_R * k)
			e:ClearAllPoints()
			if i == 1 then
				e:SetPoint("CENTER", f, "TOPLEFT", (c[1] - P.slot[1]) * k, -(c[2] - P.slot[2]) * k)
			else
				e:SetPoint("CENTER", f, "TOPRIGHT", (c[1] - P.slot[3]) * k, -(c[2] - P.slot[2]) * k)
			end
		end
	end

	-- the crown sits on the top left corner of the life bar
	local cs = math.max(10, f.health:GetHeight() * 0.8)
	f.leader:SetSize(cs, cs)
	f.leader:ClearAllPoints()
	f.leader:SetPoint("CENTER", f.health, "TOPLEFT", compact and 4 or 10, 2)
	self:Update()
end

function Member:SetEmblem(class)
	local f = self.frame
	local show = self:Get("Emblems") and not self:Compact() and class ~= nil
	for _, e in ipairs(f.emblems) do
		e:SetShown(show)
		if show then
			local atlas = "classicon-" .. class:lower()
			if not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) and e:SetAtlas(atlas) ~= false) then
				local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
				e:SetTexture(CIRCLES)
				if c then e:SetTexCoord(c[1], c[2], c[3], c[4]) end
			end
		end
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
	if not UnitExists(self.unit) then return end
	Small.Update(self)
	local unit = self.unit

	if not UnitIsConnected(unit) then
		f.pct:SetText(PLAYER_OFFLINE or "Offline")
	elseif UnitIsGhost(unit) then
		f.pct:SetText("Ghost")
	end
	local off = not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit)
	f.name:SetAlpha(off and 0.6 or 1)

	f.leader:SetShown(self:Get("Leader") and UnitIsGroupLeader(unit) or false)
	self:SetEmblem(select(2, UnitClass(unit)))
	self:UpdateRange()

	if self:Compact() then
		local r, g, b = classRGB(select(2, UnitClass(unit)))
		f.diamond:SetVertexColor(r, g, b)
		self:UpdateRim(unit)
	end
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
	local desat, cr, cg, cb = UF:Finish("player")
	for _, t in ipairs(f.slices) do
		t:SetDesaturation(desat)
		t:SetVertexColor(cr, cg, cb)
	end
	for _, j in ipairs(f.jewels) do
		j:SetDesaturation(1)
		j:SetVertexColor(r, g, b)
	end
	f.diamond:SetVertexColor(r, g, b)
	f.leader:SetShown(self:Get("Leader") and p.leader or false)
	self:SetEmblem(p.class)
	f:SetAlpha(1)
	self:SetRimColor(not p.dead and p.life < self:Get("LowLife"))
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
	local f = self.frame
	local r, g, b
	if low then
		r, g, b = 0.85, 0.15, 0.1
	else
		r, g, b = H.Themes:Accent()
		if not r then r, g, b = 0.42, 0.34, 0.19 end
	end
	for _, t in ipairs(f.rim) do t:SetColorTexture(r, g, b, 0.9) end
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

-- how far a member's art reaches past its bars (the plaque's medallions)
local function overhang(m)
	if m:Compact() then
		local d = m.frame.health:GetHeight() * 0.62
		return d * 1.6 + 2, 1, 1, 1
	end
	local PL = UF.PLAQUE
	local k = m.k or 1
	return PL.slot[1] * k, PL.slot[2] * k, (PL.size[1] - PL.slot[3]) * k, (PL.size[2] - PL.slot[4]) * k
end

function UF:LayoutParty()
	if not P.container then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() UF:LayoutParty() end, "uf-party")
		return
	end
	local db = self.db
	-- each member above the one before, so the medallions overlap in order
	for i, m in ipairs(P.members) do m.frame:SetFrameLevel(P.container:GetFrameLevel() + 2 + (i - 1) * 12) end
	for _, m in ipairs(P.members) do m:Layout() end
	local first = P.members[1]
	if not first then return end
	local f = first.frame
	local w, h = f:GetSize()
	local l, t, r, b = overhang(first)
	-- the gap is from one member's bars to the next: with the plaque the
	-- medallions reach further than that and interlock, like links of a chain
	local gap = first:Compact() and db.partyCompactSpacing or db.partySpacing
	local dir = db.partyDirection
	local n = #P.members
	local c = P.container
	if dir == "right" or dir == "left" then
		c:SetSize(n * w + (n - 1) * gap + l + r, h + t + b)
	else
		c:SetSize(w + l + r, n * h + (n - 1) * gap + t + b)
	end
	for i, m in ipairs(P.members) do
		local mf = m.frame
		local o = i - 1
		mf:ClearAllPoints()
		if dir == "down" then
			mf:SetPoint("TOPLEFT", c, "TOPLEFT", l, -t - o * (h + gap))
		elseif dir == "up" then
			mf:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", l, b + o * (h + gap))
		elseif dir == "right" then
			mf:SetPoint("TOPLEFT", c, "TOPLEFT", l + o * (w + gap), -t)
		else
			mf:SetPoint("TOPRIGHT", c, "TOPRIGHT", -r - o * (w + gap), -t)
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
	if InCombatLockdown() then
		H:Error("The party preview can't change in combat.")
		return
	end
	P.preview = on and true or false
	for i, m in ipairs(P.members) do
		local f = m.frame
		if on then
			UnregisterUnitWatch(f)
			UnregisterStateDriver(f, "visibility")
			f:Show()
		else
			if m.unit == "player" then
				RegisterStateDriver(f, "visibility", "[group] show; hide")
			else
				RegisterUnitWatch(f)
			end
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
		"UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" }) do
		pcall(ev.RegisterUnitEvent, ev, e, unpack(units))
	end
	ev:SetScript("OnEvent", function(_, e, unit)
		if unit then
			for _, m in ipairs(P.members) do
				if m.unit == unit then m:Update() end
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
