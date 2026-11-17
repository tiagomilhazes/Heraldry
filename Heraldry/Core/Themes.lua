--[[
	Heraldry - Core/Themes.lua
	Themes: the art set of the interface. The active theme is per character
	(HeraldryDB.chars[...].theme): "auto" follows the class, falling back to
	Standard when the class has no theme yet.

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

	  frame.gem                         gem on the edge of a unit frame (the target's level)
	      file, size = { w, h }
	      Drawn square and centred; tinted for elite, rare and boss units.

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
	local theme = { key = key, label = def.label or key, class = def.class, pieces = pieces,
		accent = def.accent, finish = def.finish }
	if not Themes.byKey[key] then Themes.list[#Themes.list + 1] = theme end
	Themes.byKey[key] = theme
	return theme
end

function Themes:ActiveKey()
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

function Themes:Piece(kind)
	local t = self:Active()
	local p = t and t.pieces[kind]
	if p then return p end
	local std = self.byKey.STANDARD
	return std and std.pieces[kind]
end

-- Finish key in use: the character's choice, or the theme's default.
function Themes:FinishKey()
	local choice = H.char and H.char.finish
	if choice and self.FINISHES[choice] then return choice end
	local t = self:Active()
	return t and self.FINISHES[t.finish or "none"] and t.finish or "none"
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
	local t = self:Active()
	local a = t and t.accent
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
	H:Fire("THEME_CHANGED", active)
end

H:On("READY", function()
	for _, msg in ipairs(Themes.problems or {}) do H:Debug(msg) end
end)
