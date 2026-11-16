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
		["bar.cap"]          = { file = P .. "Cap",             size = { 256, 256 },  join = { 256, 194, 94 } },
	},
})
