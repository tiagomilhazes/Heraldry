--[[
	Heraldry - Core/Fonts.lua
	Typography for the whole interface, in one place: a heading font, a text
	font, the outline and a global text scale. Saved in the profile.
	Modules never pick fonts themselves: they call

	H.Fonts:Apply(fontString, "header" | "body", size [, module])

	and listen to FONTS_CHANGED. Fonts from LibSharedMedia (installed by
	other addons) are offered too.

	Three layers, nothing repeated:
	  1. core: font, outline and scale for the whole addon (this file);
	  2. module: may override font and outline (H:NewModule(name, { fonts = true })
	     adds fontOverride / font / fontOutline to its settings);
	  3. each text: its size (and position) is a setting of its module.
]]

local _, ns = ...
local H = ns.H

local F = {}
H.Fonts = F

local BUILTIN = {
	["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
	["Arial Narrow"] = "Fonts\\ARIALN.TTF",
	["Morpheus"] = "Fonts\\MORPHEUS.TTF",
	["Skurri"] = "Fonts\\SKURRI.TTF",
}
local FALLBACK = BUILTIN["Friz Quadrata TT"]

F.DEFAULTS = { header = "Friz Quadrata TT", body = "Arial Narrow", outline = "OUTLINE", scale = 1 }
F.OUTLINES = {
	{ value = "NONE", text = "None" },
	{ value = "SHADOW", text = "Shadow" },
	{ value = "OUTLINE", text = "Outline" },
	{ value = "THICKOUTLINE", text = "Thick outline" },
}

local function lsm()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every font name on offer, sorted.
function F:List()
	local seen, names = {}, {}
	for name in pairs(BUILTIN) do
		seen[name] = true
		names[#names + 1] = name
	end
	local media = lsm()
	if media then
		for _, name in ipairs(media:List("font")) do
			if not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

function F:Path(name)
	if BUILTIN[name] then return BUILTIN[name] end
	local media = lsm()
	return media and media:Fetch("font", name, true) or FALLBACK
end

local function saved()
	H.profile.fonts = H.profile.fonts or {}
	return H.profile.fonts
end

function F:Get(key)
	local v = saved()[key]
	if v == nil then v = self.DEFAULTS[key] end
	return v
end

-- A value equal to the default is not stored.
function F:Set(key, value)
	if value == self.DEFAULTS[key] then value = nil end
	saved()[key] = value
	H:Fire("FONTS_CHANGED")
end

function F:Apply(fs, kind, size, mod)
	local name, outline = self:Get(kind), self:Get("outline")
	local db = mod and mod.db
	if db and db.fontOverride then
		name = db.font or name
		outline = db.fontOutline or outline
	end
	local flags = (outline == "NONE" or outline == "SHADOW") and "" or outline
	size = math.max(6, size * self:Get("scale"))
	if not fs:SetFont(self:Path(name), size, flags) then
		fs:SetFont(FALLBACK, size, flags)
	end
	if outline == "SHADOW" then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

H:On("PROFILE_CHANGED", function() H:Fire("FONTS_CHANGED") end)
