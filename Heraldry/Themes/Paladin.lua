--[[
	Heraldry - Themes/Paladin.lua
	Gold and rose: lion crest, runed gold rail, rose-gold plate.
	Numbers measured on the files (see the contract in Core/Themes.lua).
]]

local P = Heraldry.Themes.MEDIA .. "Paladin\\"

Heraldry:RegisterTheme("PALADIN", {
	label = "Paladin",
	class = "PALADIN",
	accent = { 0.89, 0.71, 0.31 },   -- the gold of the rails
	finish = "bronze",
	pieces = {
		["button.frame"]     = { file = P .. "ButtonFrame",     size = { 256, 256 },  hole = { 43, 40, 213, 216 } },
		["button.frameSlim"] = { file = P .. "ButtonFrameSlim", size = { 256, 256 },  hole = { 26, 36, 229, 227 } },
		["bar.plate"]        = { file = P .. "Plate",           size = { 1024, 128 } },
		["block.plate"]      = { file = P .. "PlateDouble",     size = { 1024, 256 } },
		["bar.rail"]         = { file = P .. "Rail",            size = { 512, 128 },  band = { 8, 120 } },
		["orb.health"]       = { file = P .. "OrbHealth",       size = { 512, 512 },  hole = { 296.4, 287.7, 135.1 }, reach = 209,
		                         sockets = { { 298, 115, 17 }, { 462, 286, 16 }, { 299, 446, 16 }, { 135, 289, 16 } } },
		["orb.power"]        = { file = P .. "OrbPower",        size = { 512, 512 },  hole = { 215.9, 258.6, 127.1 }, reach = 214,
		                         sockets = { { 214, 93, 22 }, { 419, 301, 22 }, { 216, 430, 22 }, { 49, 261, 22 } } },
		["bar.cap"]          = { file = P .. "Cap",             size = { 256, 256 },  join = { 256, 194, 94 } },
		["frame.gem"]        = { file = P .. "Gem",             size = { 64, 64 } },
		["scroll.rod"]       = { cap = P .. "RodCap", mid = P .. "RodMid", size = { 256, 128 }, capW = 234, midW = 512, shaft = 0.391 },
		["scroll.rodV"]      = { cap = P .. "RodCapV", mid = P .. "RodMidV", size = { 128, 256 }, capH = 234, midH = 512, shaft = 0.391 },
	},
})
