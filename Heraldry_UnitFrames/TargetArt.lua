--[[
	Heraldry_UnitFrames - TargetArt.lua
	Art of the "Heraldic" target frame. One family for every target: an
	ornament (cap) on the left with a gem that carries the level, and two
	rails hugging the bars.

	  Hostile / Friendly / Elite   NPCs (by reaction; elite art for elite,
	                               rare and boss, tinted for rare and boss)
	  MAGE, PALADIN, ...           players, by class

	The bars never change size or place between targets: only the ornament
	changes around them. NPC ornaments come with their own rails (rail.top and
	rail.bottom, rows of both the cap's right edge and the rail texture): the
	gap between them is fitted to the bars, so rails and ornament always join.
	Class rods have one band only and are sized from the bars.
	Numbers are pixels of the texture files.

	  cap   file, size {w, h}
	        crop   only columns 0..crop are drawn (the rest would run under the bars)
	        fade   optional: the last "fade" columns before crop melt into the rails
	               (for ornaments whose art ends in a straight cut)
	        rows   {top, bottom} of the ornament (its visible height)
	        gem    {x, y}: centre of the gem; it sits on the middle of the bars
	        scale  optional, evens out families of different weight
	  rail  file, size {w, h}  (w must be a power of 2: it repeats sideways)
	        top    {first, last} rows of the band drawn above the bars
	        bottom {first, last} rows of the band below; missing: top band, flipped
]]

local UF = Heraldry.Modules.byName.UnitFrames
local M = "Interface\\AddOns\\Heraldry_UnitFrames\\Media\\Target\\"

local function npc(name, crop, fade, rows, gem, top, bottom)
	return {
		cap = { file = M .. name .. "_Cap", size = { 256, 256 }, crop = crop, fade = fade, rows = rows, gem = gem },
		rail = { file = M .. name .. "_Rail", size = { 512, 256 }, top = top, bottom = bottom },
	}
end

-- Class rods: the head ends at "crop" (the plain shaft after it is cut off).
local function rod(name, crop, gemX, band)
	return {
		cap = { file = M .. name .. "_Cap", size = { 256, 128 }, crop = crop, rows = { 0, 128 }, gem = { gemX, 64 }, scale = 0.8 },
		rail = { file = M .. name .. "_Rail", size = { 512, 128 }, top = band },
	}
end

UF.ART = {
	Hostile  = npc("Hostile",  256, 0,  { 5, 192 },  { 172, 128 }, { 66, 102 }, { 154, 190 }),
	Friendly = npc("Friendly", 256, 0,  { 19, 218 }, { 218, 128 }, { 69, 101 }, { 155, 187 }),
	Elite    = npc("Elite",    256, 0,  { 19, 237 }, { 128, 128 }, { 76, 111 }, { 144, 177 }),

	MAGE    = rod("Mage",    206, 31,  { 29, 97 }),
	PALADIN = rod("Paladin", 247, 105, { 36, 91 }),
	WARRIOR = rod("Warrior", 189, 90,  { 42, 85 }),
	DRUID   = rod("Druid",   199, 159, { 21, 99 }),
	ROGUE   = rod("Rogue",   184, 95,  { 25, 102 }),
	PRIEST  = rod("Priest",  173, 26,  { 25, 95 }),
	HUNTER  = rod("Hunter",  245, 67,  { 21, 108 }),
	SHAMAN  = rod("Shaman",  174, 95,  { 38, 89 }),
	WARLOCK = rod("Warlock", 256, 31,  { 36, 92 }),
}

-- Tints of the elite ornament: desaturation, colour.
UF.ART_TINT = {
	rare = { 1, { 0.92, 0.95, 1.00 } },
	boss = { 0.5, { 1.00, 0.42, 0.36 } },
}
