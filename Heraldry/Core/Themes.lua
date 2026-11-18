--[[
	Heraldry - Core/Themes.lua
	Themes: the art set of the interface. The active theme is per character
	(HeraldryDB.chars[...].theme): "auto" follows the class, falling back to
	Standard when the class has no theme yet. A theme can also be tied to a form
	(chars[...].formThemes[formSpellID] = key): it wins while the player is in
	that form (Shadowform, a druid form, a warrior stance).

	The geometry contract
	A theme is a set of pieces. Each piece has a type, and the type says what
	numbers the piece must give, so a module can place any theme's art the
	same way. Sizes are in pixels of the texture file.

	  button.frame / button.frameSlim   frame drawn around an action button
	      file, size = { w, h }, hole = { left, top, right, bottom }
	      The hole is where the icon shows: the art is scaled so the hole
	      matches the button exactly, and the rest spills outside.
	  bar.plate / block.plate           backdrop behind one bar / behind bars 1 and 2 joined
	      file + size, or color = { r, g, b, a }
	  bar.rail                          strip along the top and bottom of a plate,
	                                    repeated sideways (file must be power of 2 wide)
	      file, size = { w, h }, band = { top, bottom }   (opaque rows)
	  bar.cap                           crest at the left end of a plate (mirrored on the right)
	      file, size = { w, h }, join = { x, y, h }
	      (x, y) is the middle of the edge that meets the plate, h is how tall
	      the plate is there: the crest is scaled so h matches the plate.

	  orb.health / orb.power            ring around the life / power orb
	      file, size = { w, h }, hole = { cx, cy, r }, reach
	      hole: centre and radius of the glass; reach: how far the ring goes
	      from that centre towards the bars (it tucks against the plate)
	      sockets (optional): { {x, y, r}, ... } the gems set in the ring, in the
	      order top, right, bottom, left (Heraldry_Auras puts auras in them)

	  frame.gem                         gem on the edge of a unit frame (the target's level)
	      file, size = { w, h }
	      Drawn square and centred; tinted for elite, rare and boss units.

	  scroll.rod                        rod on the top and bottom of a scroll (quest tracker)
	      cap, capR, mid, size = { w, h }, capW, midW, shaft
	      cap: the left end (the right end is capR, or cap mirrored); size is the
	      cap file; capW: how many pixels of it are the end piece; mid: the shaft,
	      tiled sideways when midW (its width in pixels) is given, else stretched;
	      shaft: the share of the rod's height that is the plain shaft (0-1).

	  scroll.rodV                       the same rod standing up (scrolls that unroll sideways: chat)
	      cap, capB, mid, size = { w, h }, capH, midH, shaft
	      cap: the top end (the bottom end is capB, or cap flipped); capH: how many
	      pixels of its height are the end piece; mid tiled up and down when midH
	      is given; shaft: the share of the rod's width that is the plain shaft.

	  minimap.frame                     frame around the minimap (square file)
	      file, size (one side), window = { l, t, r, b } (the map's opening),
	      sockets = { {x, y}, x3 } (day/night, addons, mail; top to bottom),
	      socketSize, plate = { l, t, r, b } (zone and clock), mask (the window's
	      shape on a square as wide as it), art = { l, t, r, b } (where the art is)

	A theme can also give:
	  accent = { r, g, b }               metal colour for thin lines (button borders)
	  finish = "bronze"                  default finish (see FINISHES): tones the art down
	                                     so it sits in the game; the player can change it

	A piece that is missing or breaks the contract is dropped (with a debug
	message), and the Standard theme's piece is used instead, if it has one.

	H:RegisterTheme(key, { label, class, pieces = { [type] = piece } })
	H.Themes:Piece(type)   piece of the active theme, or Standard's, or nil
	H.Themes:Set(key)      "auto", "STANDARD", "PALADIN", ...
	H.Themes:Paint(tex)    applies the finish to a texture showing theme art
	H.Themes:Accent()      r, g, b of the accent, with the finish applied
	Fires THEME_CHANGED (activeKey).
]]

local _, ns = ...
local H = ns.H

local Themes = { byKey = {}, list = {} }
H.Themes = Themes

Themes.MEDIA = "Interface\\AddOns\\Heraldry\\Media\\Themes\\"

local function isNum(v) return type(v) == "number" end
local function nums(t, n)
	if type(t) ~= "table" then return false end
	for i = 1, n do
		if not isNum(t[i]) then return false end
	end
	return true
end

-- type -> check(piece) -> true or an error string
local TYPES = {
	["button.frame"] = function(p)
		return p.file and nums(p.size, 2) and nums(p.hole, 4) and p.hole[3] > p.hole[1] and p.hole[4] > p.hole[2]
			or "needs file, size {w,h} and hole {l,t,r,b}"
	end,
	["bar.plate"] = function(p)
		return (p.file and nums(p.size, 2)) or nums(p.color, 4) or "needs file + size {w,h}, or color {r,g,b,a}"
	end,
	["bar.rail"] = function(p)
		return p.file and nums(p.size, 2) and nums(p.band, 2) and p.band[2] > p.band[1]
			or "needs file, size {w,h} and band {top,bottom}"
	end,
	["bar.cap"] = function(p)
		return p.file and nums(p.size, 2) and nums(p.join, 3) and p.join[3] > 0
			or "needs file, size {w,h} and join {x,y,h}"
	end,
}
TYPES["button.frameSlim"] = TYPES["button.frame"]
TYPES["block.plate"] = TYPES["bar.plate"]
TYPES["orb.health"] = function(p)
	return p.file and nums(p.size, 2) and nums(p.hole, 3) and p.hole[3] > 0 and isNum(p.reach)
		or "needs file, size {w,h}, hole {cx,cy,r} and reach"
end
TYPES["orb.power"] = TYPES["orb.health"]
TYPES["frame.gem"] = function(p)
	return p.file and nums(p.size, 2) or "needs file and size {w,h}"
end

TYPES["scroll.rod"] = function(p)
	return p.cap and p.mid and nums(p.size, 2) and isNum(p.capW) and isNum(p.shaft) and p.shaft > 0 and p.shaft <= 1
		or "needs cap, mid, size {w,h}, capW and shaft"
end

TYPES["minimap.frame"] = function(p)
	return p.file and isNum(p.size) and nums(p.window, 4) and type(p.sockets) == "table" and #p.sockets >= 3
		and isNum(p.socketSize) and nums(p.plate, 4) and p.mask and nums(p.art, 4)
		or "needs file, size, window, 3 sockets, socketSize, plate, mask and art"
end

TYPES["scroll.rodV"] = function(p)
	return p.cap and p.mid and nums(p.size, 2) and isNum(p.capH) and isNum(p.shaft) and p.shaft > 0 and p.shaft <= 1
		or "needs cap, mid, size {w,h}, capH and shaft"
end

-- desaturation (0-1), colour multiplied over the art
Themes.FINISHES = {
	none   = { label = "None (original colours)", desat = 0,    color = { 1, 1, 1 } },
	aged   = { label = "Aged",                    desat = 0.45, color = { 0.78, 0.70, 0.55 } },
	bronze = { label = "Bronze",                  desat = 0.60, color = { 0.62, 0.52, 0.40 } },
	iron   = { label = "Iron",                    desat = 0.80, color = { 0.62, 0.60, 0.56 } },
}
Themes.FINISH_ORDER = { "none", "aged", "bronze", "iron" }

function H:RegisterTheme(key, def)
	assert(type(key) == "string" and type(def) == "table", "RegisterTheme: key and definition required")
	local pieces = {}
	for kind, piece in pairs(def.pieces or {}) do
		local check = TYPES[kind]
		local ok = check and check(piece)
		if ok == true then
			pieces[kind] = piece
		else
			-- H.global may not exist yet: keep the message for READY.
			Themes.problems = Themes.problems or {}
			table.insert(Themes.problems, ("Theme %s: piece %s dropped (%s)"):format(key, kind, check and ok or "unknown type"))
		end
	end
	-- a variant (def.base) takes every piece, accent and finish it does not give from its base theme
	local theme = { key = key, label = def.label or key, class = def.class, pieces = pieces,
		accent = def.accent, finish = def.finish, base = def.base }
	if not Themes.byKey[key] then Themes.list[#Themes.list + 1] = theme end
	Themes.byKey[key] = theme
	return theme
end

-- the form the player is in (shapeshift, stance, Shadowform): its spell ID, or nil
function Themes:CurrentForm()
	local i = GetShapeshiftForm and GetShapeshiftForm() or 0
	if not i or i <= 0 then return nil end
	local _, _, _, spellID = GetShapeshiftFormInfo(i)
	return spellID
end

-- the player's forms: { { id = spellID, name = ... }, ... }
function Themes:Forms()
	local list = {}
	for i = 1, (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) do
		local icon, _, _, spellID = GetShapeshiftFormInfo(i)
		if spellID then
			local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID)) or ("Form " .. i)
			list[#list + 1] = { id = spellID, name = name, icon = icon }
		end
	end
	return list
end

-- form themes a class starts with (until the player sets their own)
Themes.FORM_DEFAULTS = {
	PRIEST = { [15473] = "PRIEST_SHADOW" },   -- Shadowform
	DRUID = {
		[5487] = "DRUID_BEAR", [9634] = "DRUID_BEAR",   -- Bear Form, Dire Bear Form
		[768] = "DRUID_CAT",                            -- Cat Form
		[24858] = "DRUID_MOONKIN",                      -- Moonkin Form
	},
}

-- the character's form -> theme table (or the class's defaults)
function Themes:FormThemes()
	if not H.char then return nil end
	if H.char.formThemes then return H.char.formThemes end
	local _, class = UnitClass("player")
	return self.FORM_DEFAULTS[class]
end

-- a theme chosen for a form wins while the player is in it (per character)
function Themes:SetFormTheme(spellID, key)
	if not H.char.formThemes then
		H.char.formThemes = {}
		for k, v in pairs(self:FormThemes() or {}) do H.char.formThemes[k] = v end
	end
	H.char.formThemes[spellID] = key
	self:CheckForm()
end

-- fires THEME_CHANGED when the active theme moved (form in or out)
function Themes:CheckForm()
	if not H.char then return end
	local key = self:ActiveKey()
	if self.lastKey and key ~= self.lastKey then
		self.lastKey = key
		H:Debug("Theme by form ->", key)
		H:Fire("THEME_CHANGED", key)
	end
	self.lastKey = key
end

function Themes:ActiveKey()
	local map = self:FormThemes()
	local form = map and self:CurrentForm()
	local byForm = form and map[form]
	if byForm and self.byKey[byForm] then return byForm end
	local choice = H.char and H.char.theme or "auto"
	if choice == "auto" then
		local _, class = UnitClass("player")
		for _, t in ipairs(self.list) do
			if t.class == class then return t.key end
		end
		return "STANDARD"
	end
	return self.byKey[choice] and choice or "STANDARD"
end

function Themes:Active()
	return self.byKey[self:ActiveKey()]
end

-- a field of a theme, looked up through its bases
function Themes:Field(t, name)
	local depth = 0
	while t and depth < 5 do
		if t[name] ~= nil then return t[name] end
		t = t.base and self.byKey[t.base]
		depth = depth + 1
	end
end

function Themes:Piece(kind)
	local t = self:Active()
	local depth = 0
	while t and depth < 5 do
		local p = t.pieces[kind]
		if p then return p end
		t = t.base and self.byKey[t.base]
		depth = depth + 1
	end
	local std = self.byKey.STANDARD
	return std and std.pieces[kind]
end

-- Finish key in use: the character's choice, or the theme's default.
function Themes:FinishKey()
	local choice = H.char and H.char.finish
	if choice and self.FINISHES[choice] then return choice end
	local fin = self:Field(self:Active(), "finish") or "none"
	return self.FINISHES[fin] and fin or "none"
end

function Themes:SetFinish(key)
	H.char.finish = key   -- nil: back to the theme's default
	H:Fire("THEME_CHANGED", self:ActiveKey())
end

function Themes:Paint(tex)
	local f = self.FINISHES[self:FinishKey()]
	tex:SetDesaturation(f.desat)
	tex:SetVertexColor(f.color[1], f.color[2], f.color[3])
end

function Themes:Accent()
	local a = self:Field(self:Active(), "accent")
	if not a then return nil end
	local f = self.FINISHES[self:FinishKey()]
	-- the same toning as the art: towards grey, then multiplied
	local grey = (a[1] + a[2] + a[3]) / 3
	local function tone(c, i) return (c + (grey - c) * f.desat) * f.color[i] end
	return tone(a[1], 1), tone(a[2], 2), tone(a[3], 3)
end

function Themes:Set(key)
	H.char.theme = key
	local active = self:ActiveKey()
	H:Debug("Theme:", key, "->", active)
	self.lastKey = active
	H:Fire("THEME_CHANGED", active)
end

-- entering or leaving a form can change the theme
H:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() Themes:CheckForm() end)
H:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function() Themes:CheckForm() end)

H:On("READY", function()
	Themes.lastKey = Themes:ActiveKey()
	for _, msg in ipairs(Themes.problems or {}) do H:Debug(msg) end
end)
