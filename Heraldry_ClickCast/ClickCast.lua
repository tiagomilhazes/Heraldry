--[[
	Heraldry_ClickCast - ClickCast.lua
	Click casting on unit frames, step 1.

	A binding is a mouse button (1-5) with modifiers and an action. Spells are
	kept by name, so a click always casts the highest rank you know (learn a
	new rank and the binding uses it); type "Name(Rank 3)" to pin a rank.
	A spell binding can also have a spell for enemies (the same click hurts
	instead of heals) and one for when the unit is dead (the same click
	resurrects); then the click is a macro with conditions on the frame's unit,
	worked out by the game, so it holds in combat.

	Bindings are per character (spells are a class's own). They go on every
	frame in ClickCastFrames (ours register there, as do other addons' frames,
	Clique-style). Attributes can't change in combat: changes wait for the end
	of the fight. With Clique loaded this module steps aside.
]]

local H = Heraldry

local CC = H:NewModule("ClickCast", {
	label = "Click casting",
	defaults = {
		enabled = true,
	},
})

CC.ACTIONS = {
	{ value = "spell", text = "Cast a spell" },
	{ value = "macro", text = "Run a macro text" },
	{ value = "item", text = "Use an item" },
	{ value = "target", text = "Target the unit" },
	{ value = "menu", text = "Open the unit's menu" },
	{ value = "focus", text = "Focus the unit" },
	{ value = "assist", text = "Assist the unit" },
}
local TYPE = { spell = "spell", macro = "macro", item = "item", target = "target", menu = "togglemenu", focus = "focus", assist = "assist" }

CC.BUTTONS = { "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5" }
local BUTTON_NAME = { "Left", "Right", "Middle", "Button 4", "Button 5" }

--[[ Bindings (per character) ]]

-- { mods = "shift-" (alt-ctrl-shift- order), button = 1..5, action, value, harm, dead }
function CC:Bindings()
	local c = H.char
	c.clickcast = c.clickcast or {}
	return c.clickcast
end

function CC:Label(b)
	local m = b.mods or ""
	local parts = {}
	if m:find("alt%-") then parts[#parts + 1] = "Alt" end
	if m:find("ctrl%-") then parts[#parts + 1] = "Ctrl" end
	if m:find("shift%-") then parts[#parts + 1] = "Shift" end
	parts[#parts + 1] = BUTTON_NAME[b.button] or ("Button " .. b.button)
	return table.concat(parts, "-")
end

-- the modifier prefix held right now
function CC:CurrentMods()
	local m = ""
	if IsAltKeyDown() then m = m .. "alt-" end
	if IsControlKeyDown() then m = m .. "ctrl-" end
	if IsShiftKeyDown() then m = m .. "shift-" end
	return m
end

function CC:Find(mods, button)
	for i, b in ipairs(self:Bindings()) do
		if b.mods == mods and b.button == button then return i, b end
	end
end

-- add or replace the binding of this combination
function CC:Set(b)
	local i = self:Find(b.mods, b.button)
	local list = self:Bindings()
	if i then list[i] = b else list[#list + 1] = b end
	table.sort(list, function(x, y)
		if x.button ~= y.button then return x.button < y.button end
		return #x.mods < #y.mods or (#x.mods == #y.mods and x.mods < y.mods)
	end)
	self:ApplyAll()
end

function CC:Remove(mods, button)
	local i = self:Find(mods, button)
	if i then table.remove(self:Bindings(), i) end
	self:ApplyAll()
end

--[[ Applying to frames ]]

local frames = {}      -- frame -> true, every frame we bind
local set = {}         -- frame -> { attribute names we set }

local function clear(f)
	for _, name in ipairs(set[f] or {}) do f:SetAttribute(name, nil) end
	set[f] = {}
end

local function put(f, name, value)
	f:SetAttribute(name, value)
	local list = set[f]
	list[#list + 1] = name
end

-- the macro for a spell binding with an enemy and/or dead alternative
local function macroFor(unit, b)
	local parts = {}
	if b.dead and b.dead ~= "" then parts[#parts + 1] = ("[@%s,dead,help] %s"):format(unit, b.dead) end
	if b.harm and b.harm ~= "" then parts[#parts + 1] = ("[@%s,harm] %s"):format(unit, b.harm) end
	parts[#parts + 1] = ("[@%s] %s"):format(unit, b.value)
	return "/cast " .. table.concat(parts, "; ")
end

function CC:Apply(f)
	if not f or type(f) ~= "table" or not f.SetAttribute then return end
	if f.IsForbidden and f:IsForbidden() then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() CC:ApplyAll() end, "clickcast-apply")
		return
	end
	set[f] = set[f] or {}
	clear(f)
	if not self.db.enabled or self.away then return end
	if f.RegisterForClicks then f:RegisterForClicks("AnyUp") end
	local unit = f:GetAttribute("unit")
	for _, b in ipairs(self:Bindings()) do
		local n = b.button
		local t = TYPE[b.action]
		if t then
			local spellish = b.action == "spell" and ((b.harm and b.harm ~= "") or (b.dead and b.dead ~= ""))
			if spellish and unit then
				put(f, b.mods .. "type" .. n, "macro")
				put(f, b.mods .. "macrotext" .. n, macroFor(unit, b))
			else
				put(f, b.mods .. "type" .. n, t)
				if t == "spell" then put(f, b.mods .. "spell" .. n, b.value)
				elseif t == "macro" then put(f, b.mods .. "macrotext" .. n, b.value)
				elseif t == "item" then put(f, b.mods .. "item" .. n, b.value) end
			end
		end
	end
end

function CC:ApplyAll()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() CC:ApplyAll() end, "clickcast-apply")
		return
	end
	for f in pairs(frames) do self:Apply(f) end
end

function CC:Register(f)
	if not f or frames[f] then return end
	frames[f] = true
	self:Apply(f)
end

--[[ Wiring ]]

function CC:OnEnable()
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Clique") then
		self.away = true
		H:Print("Click casting: Clique is loaded, so Heraldry's click casting stays off.")
		return
	end
	-- every frame registered now or later (the Clique convention)
	_G.ClickCastFrames = _G.ClickCastFrames or {}
	local reg = _G.ClickCastFrames
	local known = {}
	for f in pairs(reg) do known[#known + 1] = f end
	setmetatable(reg, {
		__newindex = function(t, f, v)
			rawset(t, f, v)
			if v then CC:Register(f) end
		end,
	})
	-- entries already in the table don't pass through __newindex: move them
	for _, f in ipairs(known) do
		rawset(reg, f, nil)
		reg[f] = true
	end
end

function CC:OnProfileChanged()
	self:ApplyAll()
end
