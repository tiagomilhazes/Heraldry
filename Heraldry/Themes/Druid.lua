--[[
	Heraldry - Themes/Druid.lua
	DRUID  Ancient Grove: carved dark oak bound with bronze oak leaves; stag
	       antlers on the life orb, the World Tree on the mana orb, a bear paw
	       crest, amber gems. Generated in Canva from the shared recipe (project
	       doc "arte-classes-prompts"); the mana orb is an edit of the life orb.
	Form variants (bear, cat, moonkin) below inherit from this theme.
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

--[[ Form variants: only the hero pieces (both orbs and the block's crest)
     change; everything else comes from the Ancient Grove (base = "DRUID").
     The life orb is an edit of the grove's, the power orb an edit of the
     form's life orb (the animal mirrored on the right), the crest an edit of
     the grove's. No class: "auto" still picks the grove; Themes.FORM_DEFAULTS
     puts each form in its variant. ]]

local function variant(key, label, dir, h, p)
	local M = Heraldry.Themes.MEDIA .. dir .. "\\"
	Heraldry:RegisterTheme(key, {
		label = label,
		base = "DRUID",
		pieces = {
			["orb.health"] = { file = M .. "OrbHealth", size = { 512, 512 }, hole = h.hole, reach = h.reach, sockets = h.sockets },
			["orb.power"]  = { file = M .. "OrbPower",  size = { 512, 512 }, hole = p.hole, reach = p.reach, sockets = p.sockets },
			["bar.cap"]    = { file = M .. "Cap",       size = { 256, 256 }, join = { 150, 128, 110 } },
		},
	})
end

variant("DRUID_BEAR", "Druid: Bear", "DruidBear",
	{ hole = { 287.2, 292.0, 131.5 }, reach = 210, sockets = { { 288, 106, 15 }, { 466, 290, 14 }, { 288, 475, 14 }, { 105, 290, 14 } } },
	{ hole = { 228.2, 289.3, 133.8 }, reach = 215, sockets = { { 228, 103, 15 }, { 411, 285, 14 }, { 229, 474, 15 }, { 45, 286, 14 } } })

variant("DRUID_CAT", "Druid: Cat", "DruidCat",
	{ hole = { 286.5, 279.3, 139.2 }, reach = 222, sockets = { { 288, 83, 16 }, { 476, 277, 15 }, { 287, 472, 15 }, { 93, 277, 15 } } },
	{ hole = { 220.9, 276.2, 139.2 }, reach = 219, sockets = { { 218, 82, 15 }, { 414, 276, 15 }, { 224, 467, 15 }, { 34, 274, 15 } } })

variant("DRUID_MOONKIN", "Druid: Moonkin", "DruidMoonkin",
	{ hole = { 286.5, 295.2, 130.5 }, reach = 208, sockets = { { 287, 111, 15 }, { 465, 293, 14 }, { 287, 476, 14 }, { 106, 294, 14 } } },
	{ hole = { 231.5, 290.1, 134.8 }, reach = 216, sockets = { { 241, 104, 15 }, { 417, 288, 14 }, { 234, 476, 14 }, { 47, 287, 15 } } })
