--[[
	Heraldry_UnitFrames - Indicators.lua
	Healer indicators: chosen auras (Rejuvenation, Renew, a missing Mark of the
	Wild...) shown on the raid members, and on the party frames too (option).
	The list is per character (spells belong to a class) in H.char.indicators;
	a new character starts from its class's defaults.

	An indicator:
	  spells   "Rejuvenation" or several, comma separated: names or spell IDs
	  point    one of 9 points of the member (TOPLEFT ... BOTTOMRIGHT), x, y offset
	  look     "icon" | "square" (its colour) | "bar" (drains) | "text" (only the time)
	  size     icon/square size; bar: length and thickness
	  time     "inside" | "below" | "above" | "none", timeSize
	  stacks   the aura's stacks, in the corner
	  mine     only auras I cast
	  missing  show when none of the spells is on the member (buffs to keep up)
	  warn     seconds left from which the indicator turns red and pulses (0: off)
	  drain    icons darken as the aura runs out

	Engine: IND:Attach(host, anchor) once per member, IND:Layout(host),
	IND:Update(host, unit) on UNIT_AURA, IND:Fake(host, n) for previews.
	Aura names and IDs may be secret in combat on this client; then nothing can
	be matched, and the debug output says so once (/hui debug).
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames

local IND = {}
UF.Ind = IND

UF.defaults.indParty = true
UF.defaults.indRaid = true

IND.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
IND.LOOKS = { icon = "Icon", square = "Coloured square", bar = "Draining bar", text = "Time only" }

local FIELDS = {
	spells = "", point = "TOPRIGHT", x = 0, y = 0, look = "icon", size = 14, length = 40,
	color = { 0.3, 0.8, 0.35 }, time = "inside", timeSize = 9, stacks = true,
	mine = true, missing = false, warn = 3, drain = true, enabled = true,
}

local function ind(spells, point, more)
	local t = { spells = spells, point = point }
	for k, v in pairs(more or {}) do t[k] = v end
	return t
end

IND.CLASS_DEFAULTS = {
	DRUID = {
		ind("Rejuvenation", "TOPRIGHT", { look = "square", color = { 0.35, 0.85, 0.3 } }),
		ind("Regrowth", "RIGHT", { look = "square", color = { 0.15, 0.65, 0.55 } }),
		ind("Abolish Poison", "BOTTOMRIGHT", { size = 10, time = "none" }),
		ind("Mark of the Wild, Gift of the Wild", "TOPLEFT", { look = "square", size = 8, mine = false, missing = true, time = "none", color = { 0.8, 0.45, 0.9 } }),
	},
	PRIEST = {
		ind("Renew", "TOPRIGHT", { look = "square", color = { 0.95, 0.95, 0.75 } }),
		ind("Power Word: Shield", "RIGHT", { mine = false, time = "none" }),
		ind("Weakened Soul", "BOTTOMRIGHT", { look = "square", size = 8, mine = false, time = "none", warn = 0, color = { 0.85, 0.2, 0.2 } }),
		ind("Power Word: Fortitude, Prayer of Fortitude", "TOPLEFT", { look = "square", size = 8, mine = false, missing = true, time = "none", color = { 0.95, 0.95, 0.95 } }),
	},
	PALADIN = {
		ind("Blessing of Might, Blessing of Wisdom, Blessing of Kings, Blessing of Salvation, Blessing of Light, Blessing of Sanctuary, Greater Blessing of Might, Greater Blessing of Wisdom, Greater Blessing of Kings, Greater Blessing of Salvation, Greater Blessing of Light, Greater Blessing of Sanctuary",
			"TOPLEFT", { look = "square", size = 8, missing = true, time = "none", color = { 0.95, 0.75, 0.3 } }),
		ind("Blessing of Protection, Blessing of Freedom, Blessing of Sacrifice", "TOPRIGHT", { mine = false }),
	},
	SHAMAN = {
		ind("Ancestral Fortitude, Healing Way", "TOPRIGHT", { mine = false }),
	},
}

--[[ The list (per character) ]]

local function copy(t)
	local c = {}
	for k, v in pairs(t) do c[k] = type(v) == "table" and copy(v) or v end
	return c
end

function IND:List()
	if not H.char.indicators then
		local _, class = UnitClass("player")
		local list = {}
		for i, d in ipairs(self.CLASS_DEFAULTS[class] or {}) do list[i] = copy(d) end
		H.char.indicators = list
	end
	return H.char.indicators
end

-- a field of an indicator, with the default when not set
function IND:Get(i, key)
	local d = self:List()[i]
	if not d then return FIELDS[key] end
	local v = d[key]
	if v == nil then return FIELDS[key] end
	return v
end

function IND:Set(i, key, value)
	local d = self:List()[i]
	if not d then return end
	if key == "spells" then self.cache = nil end
	d[key] = value
	self:LayoutAll()
end

function IND:Add()
	local list = self:List()
	list[#list + 1] = { spells = "", point = "CENTER", look = "square" }
	self.cache = nil
	self:LayoutAll()
	return #list
end

function IND:Remove(i)
	table.remove(self:List(), i)
	self.cache = nil
	self:LayoutAll()
end

function IND:Move(i, delta)
	local list = self:List()
	local j = i + delta
	if not list[j] then return i end
	list[i], list[j] = list[j], list[i]
	self:LayoutAll()
	return j
end

function IND:ResetToClass()
	H.char.indicators = nil
	self.cache = nil
	self:LayoutAll()
end

-- the spells of indicator i as a set: lower-case names and spell IDs
function IND:Spells(i)
	self.cache = self.cache or {}
	local c = self.cache[i]
	if c then return c end
	c = { list = {} }
	for word in (self:Get(i, "spells") or ""):gmatch("[^,]+") do
		word = word:match("^%s*(.-)%s*$")
		if word ~= "" then
			local id = tonumber(word)
			c[id or word:lower()] = true
			c.list[#c.list + 1] = id or word
		end
	end
	self.cache[i] = c
	return c
end

-- the first spell's icon (for a missing buff, and in the editor's list)
function IND:SpellIcon(i)
	local first = self:Spells(i).list[1]
	if not first then return nil end
	local ok, tex = pcall(function()
		if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(first) end
		return GetSpellTexture and GetSpellTexture(first)
	end)
	return ok and tex or nil
end

--[[ Time ]]

local function plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function fmt(left)
	if left >= 3600 then return ("%dh"):format(math.ceil(left / 3600)) end
	if left >= 90 then return ("%dm"):format(math.ceil(left / 60)) end
	return ("%d"):format(math.ceil(left))
end

-- indicators counting down with plain numbers, ticked together
local counting = {}
local ticker

local function tick()
	local now = GetTime()
	local any = false
	for e, exp in pairs(counting) do
		local left = exp - now
		if left <= 0 or not e:IsVisible() then
			if left <= 0 then counting[e] = nil end
		else
			any = true
			if e.showTime then e.time:SetText(fmt(left)) end
			if e.look == "bar" and e.dur and e.dur > 0 then e.bar:SetValue(left / e.dur) end
			local warn = e.warn > 0 and left <= e.warn
			if warn ~= e.warning then
				e.warning = warn
				e.time:SetTextColor(warn and 1 or 1, warn and 0.3 or 0.96, warn and 0.25 or 0.85)
				if warn then e.pulse:Play() else e.pulse:Stop() e:SetAlpha(1) end
			end
		end
	end
	if not any and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function stopTime(e)
	counting[e] = nil
	if e.binding then pcall(e.binding.SetEnabled, e.binding, false) end
	e.time:SetText("")
	e.warning = false
	e.pulse:Stop()
	e:SetAlpha(1)
	e.time:SetTextColor(1, 0.96, 0.85)
end

-- seconds written by the game, for secret durations
local secondsFormatter
local function formatter()
	if secondsFormatter ~= nil then return secondsFormatter or nil end
	secondsFormatter = false
	pcall(function()
		local Up = Enum.NumericRuleFormatRounding.Up
		local f = C_StringUtil.CreateNumericRuleFormatter()
		f:SetBreakpoints({
			{ threshold = 0, format = "%d", step = 1, rounding = Up },
			{ threshold = 90, format = "%dm", step = 60, rounding = Up, components = { { div = 60 } } },
		})
		secondsFormatter = f
	end)
	return secondsFormatter or nil
end

local function setTime(e, unit, aura)
	stopTime(e)
	e.cd:Clear()
	if e.look == "bar" then e.bar:SetValue(1) end
	if not aura then return end
	local d
	if unit and aura.auraInstanceID and C_UnitAuras.GetAuraDuration then
		pcall(function() d = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID) end)
	end
	if e.drain and d and e.cd.SetCooldownFromDurationObject then pcall(e.cd.SetCooldownFromDurationObject, e.cd, d) end
	local done = false
	pcall(function()
		local exp, dur = aura.expirationTime, aura.duration
		if plain(exp) and plain(dur) and dur > 0 then
			if e.drain and not d then e.cd:SetCooldown(exp - dur, dur) end
			e.dur = dur
			counting[e] = exp
			if not ticker then ticker = C_Timer.NewTicker(0.2, tick) end
			done = true
		end
	end)
	if done then tick() return end
	if not e.showTime or not d then return end
	local f = formatter()
	if f and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
		pcall(function()
			e.binding = e.binding or C_DurationUtil.CreateDurationTextBinding()
			e.binding:SetFontString(e.time)
			e.binding:SetDuration(d)
			e.binding:SetFormatter(f)
			if e.binding.SetUpdateInterval then e.binding:SetUpdateInterval(0.25) end
			if e.binding.SetExpiredText then e.binding:SetExpiredText("") end
			e.binding:SetEnabled(true)
		end)
	end
end

--[[ One member ]]

local hosts = setmetatable({}, { __mode = "k" })

-- the pieces of one indicator on one member
local function newElement(holder)
	local e = CreateFrame("Frame", nil, holder)
	e.bg = e:CreateTexture(nil, "BACKGROUND")
	e.bg:SetPoint("TOPLEFT", -1, 1)
	e.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	e.bg:SetColorTexture(0, 0, 0, 0.85)
	e.icon = e:CreateTexture(nil, "ARTWORK")
	e.icon:SetAllPoints()
	e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	e.bar = CreateFrame("StatusBar", nil, e)
	e.bar:SetAllPoints()
	e.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	e.bar:SetMinMaxValues(0, 1)
	e.cd = CreateFrame("Cooldown", nil, e, "CooldownFrameTemplate")
	e.cd:SetAllPoints()
	e.cd:SetDrawEdge(false)
	e.cd:SetReverse(true)
	if e.cd.SetHideCountdownNumbers then e.cd:SetHideCountdownNumbers(true) end
	local top = CreateFrame("Frame", nil, e)
	top:SetAllPoints()
	top:SetFrameLevel(e.cd:GetFrameLevel() + 2)
	e.time = top:CreateFontString(nil, "OVERLAY")
	e.time:SetShadowColor(0, 0, 0, 1)
	e.time:SetShadowOffset(1, -1)
	e.count = top:CreateFontString(nil, "OVERLAY")
	e.count:SetShadowColor(0, 0, 0, 1)
	e.count:SetShadowOffset(1, -1)
	e.count:SetPoint("BOTTOMRIGHT", 2, -1)
	e.pulse = e:CreateAnimationGroup()
	e.pulse:SetLooping("BOUNCE")
	local a = e.pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.4)
	e.warning = false
	e:Hide()
	return e
end

-- once per member: `anchor` is the region the 9 points refer to
function IND:Attach(host, anchor, kind)
	if host.hInd then return host.hInd end
	local holder = CreateFrame("Frame", nil, host)
	holder:SetAllPoints(anchor or host)
	holder.elements = {}
	holder.kind = kind
	host.hInd = holder
	hosts[host] = true
	self:Layout(host)
	return holder
end

local function enabledFor(holder)
	if holder.kind == "party" then return UF.db.indParty end
	if holder.kind == "raid" then return UF.db.indRaid end
	return true
end

function IND:Layout(host)
	local holder = host.hInd
	if not holder then return end
	holder:SetFrameLevel(host:GetFrameLevel() + 12)
	holder:SetShown(enabledFor(holder))
	local list = self:List()
	for i = 1, math.max(#list, #holder.elements) do
		local e = holder.elements[i]
		if i > #list then
			if e then stopTime(e) e:Hide() end
		else
			e = e or newElement(holder)
			holder.elements[i] = e
			local look = self:Get(i, "look")
			local size = self:Get(i, "size")
			e.look, e.warn, e.drain = look, self:Get(i, "warn"), self:Get(i, "drain") and look == "icon"
			if look == "bar" then
				e:SetSize(self:Get(i, "length"), math.max(2, math.floor(size / 3)))
			elseif look == "text" then
				e:SetSize(size, size)
			else
				e:SetSize(size, size)
			end
			local p = self:Get(i, "point")
			e:ClearAllPoints()
			e:SetPoint(p, holder, p, self:Get(i, "x"), self:Get(i, "y"))
			local c = self:Get(i, "color")
			e.icon:SetShown(look == "icon")
			e.bar:SetShown(look == "bar")
			e.bar:SetStatusBarColor(c[1], c[2], c[3])
			e.bg:SetShown(look ~= "text")
			if look == "square" then
				e.bg:SetColorTexture(0, 0, 0, 0.9)
				e.icon:Show()
				e.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
				e.icon:SetVertexColor(c[1], c[2], c[3])
				e.icon:SetTexCoord(0, 1, 0, 1)
			else
				e.icon:SetVertexColor(1, 1, 1)
				e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				e.bg:SetColorTexture(0, 0, 0, look == "bar" and 0.7 or 0.85)
			end
			local where = self:Get(i, "time")
			if look == "text" and where == "none" then where = "inside" end
			e.showTime = where ~= "none" and not self:Get(i, "missing")
			H.Fonts:Apply(e.time, "body", self:Get(i, "timeSize"), UF)
			e.time:ClearAllPoints()
			if where == "below" then
				e.time:SetPoint("TOP", e, "BOTTOM", 0, -1)
			elseif where == "above" then
				e.time:SetPoint("BOTTOM", e, "TOP", 0, 1)
			else
				e.time:SetPoint("CENTER", e, "CENTER", 1, 0)
			end
			e.time:SetShown(e.showTime)
			H.Fonts:Apply(e.count, "body", math.max(7, self:Get(i, "timeSize") - 1), UF)
			e.count:SetShown(self:Get(i, "stacks"))
		end
	end
	if holder.fake then self:Fake(host, holder.fake) else self:Update(host, holder.unit) end
end

-- the auras on a unit, by lower-case name and spell ID; mine apart
local warnedSecret = false
local function scan(unit)
	local any, mine = {}, {}
	local secret = false
	local function read(filter, into)
		for n = 1, 40 do
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, n, filter)
			if not ok or not aura then break end
			local name, id = aura.name, aura.spellId
			if plain(name) then into[name:lower()] = into[name:lower()] or aura else secret = true end
			if plain(id) then into[id] = into[id] or aura end
		end
	end
	read("HELPFUL|PLAYER", mine)
	read("HELPFUL", any)
	read("HARMFUL", any)
	if secret and not warnedSecret then
		warnedSecret = true
		H:Debug("Raid indicators: aura names are secret here (in combat?); indicators can't match them.")
	end
	return any, mine, secret
end

local function find(set, auras)
	for _, key in ipairs(set.list) do
		local k = type(key) == "number" and key or key:lower()
		if auras[k] then return auras[k] end
	end
end

function IND:Update(host, unit)
	local holder = host.hInd
	if not holder then return end
	holder.unit, holder.fake = unit, nil
	if not holder:IsShown() then return end
	local list = self:List()
	local any, mine, blind
	if unit and UnitExists(unit) and #list > 0 then any, mine, blind = scan(unit) end
	for i = 1, #list do
		local e = holder.elements[i]
		if e then
			local aura
			if any and self:Get(i, "enabled") then
				aura = find(self:Spells(i), self:Get(i, "mine") and mine or any)
			end
			self:Show(e, i, aura, unit, nil, blind)
		end
	end
end

-- puts one indicator up (aura found), down, or up as a missing buff;
-- blind: some aura names were secret, so "not found" may not mean missing
function IND:Show(e, i, aura, unit, fake, blind)
	local missing = self:Get(i, "missing")
	local spells = self:Spells(i)
	if not self:Get(i, "enabled") or #spells.list == 0 and not fake then
		stopTime(e)
		e:Hide()
		return
	end
	if missing then
		stopTime(e)
		e:SetShown(aura == nil and not blind and (unit ~= nil or fake))
		if e.look == "icon" then e.icon:SetTexture(self:SpellIcon(i) or 134400) end
		e.count:SetText("")
		return
	end
	if not aura then
		stopTime(e)
		e:Hide()
		return
	end
	if e.look == "icon" then
		local ok = pcall(e.icon.SetTexture, e.icon, aura.icon)
		if not ok then e.icon:SetTexture(self:SpellIcon(i) or 134400) end
	end
	e.count:SetText("")
	pcall(function()
		local n = aura.applications
		if plain(n) and n > 1 then e.count:SetText(n) end
	end)
	e:Show()
	setTime(e, unit, aura)
end

-- made-up auras for the previews: n picks which member gets what
function IND:Fake(host, n)
	local holder = host.hInd
	if not holder then return end
	holder.fake = n
	if not holder:IsShown() then return end
	local now = GetTime()
	for i = 1, #self:List() do
		local e = holder.elements[i]
		if e then
			-- most members have the aura; a missing buff shows on the others
			local has = (n + i) % 3 ~= 0
			local aura
			if has then
				local dur = 12 + i * 3
				aura = { icon = self:SpellIcon(i) or 134400, duration = dur,
					expirationTime = now + dur * (((n * 7 + i * 3) % 10) + 1) / 10,
					applications = i == 1 and n % 2 == 0 and 2 or 0 }
			end
			self:Show(e, i, aura, nil, true)
		end
	end
end

function IND:LayoutAll()
	for host in pairs(hosts) do self:Layout(host) end
end

function IND:UpdateAll()
	for host in pairs(hosts) do
		local holder = host.hInd
		if holder.fake then self:Fake(host, holder.fake) else self:Update(host, holder.unit) end
	end
end
