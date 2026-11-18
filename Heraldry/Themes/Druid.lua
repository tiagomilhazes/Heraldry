--[[
	Heraldry - Themes/Druid.lua
	DRUID  Ancient Grove: carved dark oak bound with bronze oak leaves; stag
	       antlers on the life orb, the World Tree on the mana orb, a bear paw
	       crest, amber gems. Generated in Canva from the shared recipe (project
	       doc "arte-classes-prompts"); the mana orb is an edit of the life orb.
	Form variants (bear, cat, moonkin) come later and inherit from this theme.
	Numbers measured on the files (see the contract in Core/Themes.lua).
]]

local D = Heraldry.Themes.MEDIA .. "Druid\\"

Heraldry:RegisterTheme("DRUID", {
	label = "Druid: Ancient Grove",
	class = "DRUID",
	accent = { 0.78, 0.58, 0.30 },   -- bronze
	finish = "none",
	pieces = {
		["button.frame"]     = { file = D .. "ButtonFrame",     size = { 256, 256 },  hole = { 47, 51, 209, 204 } },
		["button.frameSlim"] = { file = D .. "ButtonFrameSlim", size = { 256, 256 },  hole = { 28, 33, 228, 225 } },
		["bar.plate"]        = { file = D .. "Plate",           size = { 1024, 128 } },
		["block.plate"]      = { file = D .. "PlateDouble",     size = { 1024, 256 } },
		["bar.rail"]         = { file = D .. "Rail",            size = { 512, 128 },  band = { 8, 120 } },
		["orb.health"]       = { file = D .. "OrbHealth",       size = { 512, 512 },  hole = { 292.5, 301.8, 126.5 }, reach = 201,
		                         sockets = { { 293, 123, 14 }, { 465, 300, 14 }, { 293, 478, 14 }, { 117, 300, 14 } } },
		["orb.power"]        = { file = D .. "OrbPower",        size = { 512, 512 },  hole = { 241.1, 303.8, 125.2 }, reach = 201,
		                         sockets = { { 240, 128, 14 }, { 410, 303, 13 }, { 241, 478, 14 }, { 69, 303, 13 } } },
		["bar.cap"]          = { file = D .. "Cap",             size = { 256, 256 },  join = { 150, 128, 110 } },
		["frame.gem"]        = { file = D .. "Gem",             size = { 64, 64 } },
		["scroll.rod"]       = { cap = D .. "RodCap", mid = D .. "RodMid", size = { 256, 128 }, capW = 245, midW = 512, shaft = 0.51 },
		["scroll.rodV"]      = { cap = D .. "RodCapV", mid = D .. "RodMidV", size = { 128, 256 }, capH = 245, midH = 512, shaft = 0.51 },
		["minimap.frame"]    = { file = D .. "Minimap", size = 1024, window = { 153, 222, 875, 867 },
		                         sockets = { { 934, 205 }, { 932, 541 }, { 933, 886 } }, socketSize = 100,
		                         plate = { 287, 869, 742, 942 }, mask = D .. "MinimapMask", art = { 0, 0, 1024, 985 } },
	},
})
