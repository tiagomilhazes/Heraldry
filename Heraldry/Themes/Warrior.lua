--[[
	Heraldry - Themes/Warrior.lua
	WARRIOR  Warlord: blackened riveted orcish iron with curved spikes, short
	         bone tusks and crimson strips; a battle axe and horned helm on the
	         orbs, an orc skull mask crest, a blood garnet gem. Canva kit from the
	         shared recipe (project doc "arte-classes-prompts"); the power orb is
	         an edit of the life orb. Battle Stance keeps this theme.
	Stance variants (base = "WARRIOR"): Defensive (tower shield) and Berserker
	(horned skull and crossed axes) give only both orbs and the crest.
	Numbers measured on the files (see the contract in Core/Themes.lua).
]]

local W = Heraldry.Themes.MEDIA .. "Warrior\\"

-- the ring's four gems sit about 146 px from the hole's centre on the warlord orbs
local function sockets(cx, cy, R)
	R = R or 146
	return { { cx, cy - R, 20 }, { cx + R, cy, 20 }, { cx, cy + R, 20 }, { cx - R, cy, 20 } }
end

Heraldry:RegisterTheme("WARRIOR", {
	label = "Warrior: Warlord",
	class = "WARRIOR",
	accent = { 0.62, 0.20, 0.16 },   -- dried blood
	finish = "none",
	pieces = {
		["button.frame"]     = { file = W .. "ButtonFrame",     size = { 256, 256 },  hole = { 26, 25, 230, 229 } },
		["button.frameSlim"] = { file = W .. "ButtonFrameSlim", size = { 256, 256 },  hole = { 26, 25, 230, 229 } },
		["bar.plate"]        = { file = W .. "Plate",           size = { 1024, 128 } },
		["block.plate"]      = { file = W .. "PlateDouble",     size = { 1024, 256 } },
		["bar.rail"]         = { file = W .. "Rail",            size = { 512, 128 },  band = { 8, 120 } },
		["orb.health"]       = { file = W .. "OrbHealth",       size = { 512, 512 },  hole = { 275.6, 289.2, 105.2 }, reach = 219,
		                         sockets = sockets(276, 289) },
		["orb.power"]        = { file = W .. "OrbPower",        size = { 512, 512 },  hole = { 243.7, 286.6, 105.3 }, reach = 231,
		                         sockets = sockets(244, 287) },
		["bar.cap"]          = { file = W .. "Cap",             size = { 256, 256 },  join = { 160, 128, 120 } },
		["frame.gem"]        = { file = W .. "Gem",             size = { 64, 64 } },
		["scroll.rod"]       = { cap = W .. "RodCap", mid = W .. "RodMid", size = { 256, 128 }, capW = 200, midW = 512, shaft = 0.41 },
		["scroll.rodV"]      = { cap = W .. "RodCapV", mid = W .. "RodMidV", size = { 128, 256 }, capH = 200, midH = 512, shaft = 0.41 },
		["minimap.frame"]    = { file = W .. "Minimap", size = 1024, window = { 247, 274, 774, 793 },
		                         sockets = { { 833, 307 }, { 876, 491 }, { 855, 690 } }, socketSize = 125,
		                         plate = { 262, 815, 795, 985 }, mask = W .. "MinimapMask", art = { 2, 0, 1024, 994 } },
	},
})

local function stance(key, label, dir, h, p)
	local M = Heraldry.Themes.MEDIA .. dir .. "\\"
	Heraldry:RegisterTheme(key, {
		label = label,
		base = "WARRIOR",
		pieces = {
			["orb.health"] = { file = M .. "OrbHealth", size = { 512, 512 }, hole = h.hole, reach = h.reach, sockets = h.sockets or sockets(h.hole[1], h.hole[2]) },
			["orb.power"]  = { file = M .. "OrbPower",  size = { 512, 512 }, hole = p.hole, reach = p.reach, sockets = p.sockets or sockets(p.hole[1], p.hole[2]) },
			["bar.cap"]    = { file = M .. "Cap",       size = { 256, 256 }, join = { 160, 128, 120 } },
		},
	})
end

stance("WARRIOR_DEFENSIVE", "Warrior: Defensive", "WarriorDefensive",
	{ hole = { 264.4, 288.1, 105.6 }, reach = 221 },
	{ hole = { 255.6, 282.6, 107.8 }, reach = 235, sockets = sockets(256, 283, 150) })

stance("WARRIOR_BERSERKER", "Warrior: Berserker", "WarriorBerserker",
	{ hole = { 281.0, 287.7, 106.4 }, reach = 221 },
	{ hole = { 235.1, 283.3, 113.3 }, reach = 230,
	  sockets = { { 234, 138, 20 }, { 375, 283, 20 }, { 234, 429, 20 }, { 97, 283, 20 } } })
