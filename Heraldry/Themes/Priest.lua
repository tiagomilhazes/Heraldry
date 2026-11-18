--[[
	Heraldry - Themes/Priest.lua
	Two priest themes, both generated in Canva from the same recipe (project doc
	"arte-classes-prompts"):
	  PRIEST         Holy Light: white marble and pale gold; sun halo and a
	                 praying angel on the life orb, a holy tome and candle on the mana orb
	                 (no glow: it bled into the orb)
	  PRIEST_SHADOW  Shadow: obsidian and dark silver; a hooded figure in void
	                 tendrils on the life orb, a void crystal on the mana orb
	"auto" picks Holy Light for a priest; Shadow is chosen on the Theme page.
	Numbers measured on the files (see the contract in Core/Themes.lua).
]]

local M = Heraldry.Themes.MEDIA

local P = M .. "Priest\\"
Heraldry:RegisterTheme("PRIEST", {
	label = "Priest: Holy Light",
	class = "PRIEST",
	accent = { 0.92, 0.78, 0.42 },   -- pale gold
	finish = "none",
	pieces = {
		["button.frame"]     = { file = P .. "ButtonFrame",     size = { 256, 256 },  hole = { 53, 52, 203, 202 } },
		["button.frameSlim"] = { file = P .. "ButtonFrameSlim", size = { 256, 256 },  hole = { 18, 28, 237, 238 } },
		["bar.plate"]        = { file = P .. "Plate",           size = { 1024, 128 } },
		["block.plate"]      = { file = P .. "PlateDouble",     size = { 1024, 256 } },
		["bar.rail"]         = { file = P .. "Rail",            size = { 512, 128 },  band = { 8, 120 } },
		["orb.health"]       = { file = P .. "OrbHealth",       size = { 512, 512 },  hole = { 289.5, 287.5, 128.7 }, reach = 212,
		                         sockets = { { 288, 112, 21 }, { 461, 291, 21 }, { 288, 462, 22 }, { 131, 292, 21 } } },
		["orb.power"]        = { file = P .. "OrbPower",        size = { 512, 512 },  hole = { 224.7, 281.7, 131.5 }, reach = 220,
		                         sockets = { { 223, 104, 21 }, { 398, 285, 22 }, { 222, 459, 22 }, { 61, 285, 22 } } },
		["bar.cap"]          = { file = P .. "Cap",             size = { 256, 256 },  join = { 150, 128, 110 } },
		["frame.gem"]        = { file = P .. "Gem",             size = { 64, 64 } },
		["scroll.rod"]       = { cap = P .. "RodCap", mid = P .. "RodMid", size = { 256, 128 }, capW = 167, midW = 512, shaft = 0.263 },
		["scroll.rodV"]      = { cap = P .. "RodCapV", mid = P .. "RodMidV", size = { 128, 256 }, capH = 167, midH = 512, shaft = 0.263 },
		["minimap.frame"]    = { file = P .. "Minimap", size = 1024, window = { 195, 231, 872, 845 },
		                         sockets = { { 958, 328 }, { 959, 523 }, { 959, 717 } }, socketSize = 70,
		                         plate = { 198, 866, 865, 951 }, mask = P .. "MinimapMask", art = { 0, 0, 1024, 978 } },
	},
})

local S = M .. "PriestShadow\\"
Heraldry:RegisterTheme("PRIEST_SHADOW", {
	label = "Priest: Shadow",
	accent = { 0.70, 0.66, 0.82 },   -- dark silver with a violet cast
	finish = "none",
	pieces = {
		["button.frame"]     = { file = S .. "ButtonFrame",     size = { 256, 256 },  hole = { 48, 50, 208, 206 } },
		["button.frameSlim"] = { file = S .. "ButtonFrameSlim", size = { 256, 256 },  hole = { 34, 36, 222, 221 } },
		["bar.plate"]        = { file = S .. "Plate",           size = { 1024, 128 } },
		["block.plate"]      = { file = S .. "PlateDouble",     size = { 1024, 256 } },
		["bar.rail"]         = { file = S .. "Rail",            size = { 512, 128 },  band = { 8, 120 } },
		["orb.health"]       = { file = S .. "OrbHealth",       size = { 512, 512 },  hole = { 268.5, 259.6, 127.0 }, reach = 221,
		                         sockets = { { 270, 85, 23 }, { 442, 256, 23 }, { 270, 431, 23 }, { 98, 256, 23 } } },
		["orb.power"]        = { file = S .. "OrbPower",        size = { 512, 512 },  hole = { 227.0, 290.3, 118.9 }, reach = 209,
		                         sockets = { { 226, 142, 14 }, { 374, 292, 15 }, { 226, 441, 15 }, { 80, 292, 15 } } },
		["bar.cap"]          = { file = S .. "Cap",             size = { 256, 256 },  join = { 150, 128, 110 } },
		["frame.gem"]        = { file = S .. "Gem",             size = { 64, 64 } },
		["scroll.rod"]       = { cap = S .. "RodCap", mid = S .. "RodMid", size = { 256, 128 }, capW = 256, midW = 512, shaft = 0.589 },
		["scroll.rodV"]      = { cap = S .. "RodCapV", mid = S .. "RodMidV", size = { 128, 256 }, capH = 256, midH = 512, shaft = 0.589 },
		["minimap.frame"]    = { file = S .. "Minimap", size = 1024, window = { 178, 196, 788, 888 },
		                         sockets = { { 828, 166 }, { 829, 496 }, { 830, 944 } }, socketSize = 82,
		                         plate = { 253, 918, 695, 994 }, mask = S .. "MinimapMask", art = { 0, 1, 906, 1024 } },
	},
})
