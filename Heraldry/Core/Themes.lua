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
	  bar.plate                         backdrop behind a bar
	      file + size, or color = { r, g, b, a }
	  bar.rail                          strip along the top and bottom of a plate,
	                                    repeated sideways (file must be power of 2 wide)
	      file, size = { w, h }, band = { top, bottom }   (opaque rows)
	  bar.cap                           crest at the left end of a plate (mirrored on the right)
	      file, size = { w, h }, join = { x, y, h }
	      (x, y) is the middle of the edge that meets the plate, h is how tall
	      the plate is there: the crest is scaled so h matches the plate.

	A piece that is missing or breaks the contract is dropped (with a debug
	message), and the Standard theme's piece is used instead, if it has one.

	H:RegisterTheme(key, { label, class, pieces = { [type] = piece } })
	H.Themes:Piece(type)   piece of the active theme, or Standard's, or nil
	H.Themes:Set(key)      "auto", "STANDARD", "PALADIN", ...
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
	local theme = { key = key, label = def.label or key, class = def.class, pieces = pieces }
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

function Themes:Set(key)
	H.char.theme = key
	local active = self:ActiveKey()
	H:Debug("Theme:", key, "->", active)
	H:Fire("THEME_CHANGED", active)
end

H:On("READY", function()
	for _, msg in ipairs(Themes.problems or {}) do H:Debug(msg) end
end)
