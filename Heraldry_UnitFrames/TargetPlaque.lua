--[[
	Heraldry_UnitFrames - TargetPlaque.lua
	Art of the "Plaque" target frame: one fixed plaque (from the TimelessUI
	Paladin kit) whose slot holds the bars. The slot's inside is cut out of
	the texture, so the bars sit behind the plaque and its rims and jewels
	frame them. Numbers are pixels of the file.

	  slot    {left, top, right, bottom} of the cut-out slot: the bars fill it,
	          so the bar heights set the plaque's scale
	  split   {a, b}: columns a..b are stretched for the frame's width, the
	          ends (lion medallions, jewels) keep their shape
	  gems    {x, y, radius} of the left and right jewels; they are drawn again
	          on top, desaturated and tinted, to recolour them
	  level   the ring (TimelessUI Paladin PortraitRing) that holds the level,
	          set into the left medallion; it takes the plaque's finish

	What the target is shows only as colour, never as a different shape:
	  FINISH       { desaturation, { r, g, b } } of the metal
	  KIND_FINISH  finish per kind of target
	  JEWEL        jewel colour per kind (players: their class colour)
]]

local UF = Heraldry.Modules.byName.UnitFrames

UF.PLAQUE = {
	file = "Interface\\AddOns\\Heraldry_UnitFrames\\Media\\Target\\Plaque",
	size = { 1024, 256 },
	slot = { 208, 84, 814, 174 },
	split = { 300, 724 },
	gems = { { 195, 130, 18 }, { 827, 130, 18 } },
	-- the level's ring, set into the left medallion (above its jewel)
	level = {
		file = "Interface\\AddOns\\Heraldry_UnitFrames\\Media\\Target\\LevelRing",
		x = 186, y = 58, size = 96,   -- centre and size in plaque pixels
		hole = 0.58,                  -- dark disc behind the number, as a share of the size
	},
}

UF.FINISH = {
	gold   = { 0,    { 1.00, 1.00, 1.00 } },
	iron   = { 1,    { 0.66, 0.67, 0.72 } },
	bronze = { 0.55, { 0.88, 0.68, 0.48 } },
	silver = { 1,    { 1.00, 1.00, 1.00 } },
	blood  = { 0.6,  { 1.00, 0.42, 0.36 } },
}

UF.KIND_FINISH = {
	hostile = "iron", friendly = "bronze", elite = "gold",
	rare = "silver", boss = "blood", player = "gold",
}

UF.JEWEL = {
	hostile  = { 0.90, 0.16, 0.12 },
	friendly = { 0.22, 0.88, 0.32 },
	neutral  = { 0.98, 0.82, 0.22 },
	elite    = { 1.00, 0.62, 0.15 },
	rare     = { 0.85, 0.90, 1.00 },
	boss     = { 1.00, 0.18, 0.12 },
	player   = { 0.85, 0.85, 0.85 },
}
