--[[
	Heraldry_UnitFrames - Settings.lua
	One page for the whole module, "Unit frames". The frame picker at the top
	of every tab (Target, Target of target, Focus; party and raid later)
	chooses which frame the tab sets up. Tabs: Size | Text | Look | Behaviour |
	Font (the font is the module's, for every frame).
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames

local function field(name)
	return function() return UF.db[name] end, function(v)
		UF.db[name] = v
		UF:Layout()
	end
end

local function smallField(prefix, name)
	return function() return UF.db[prefix .. name] end, function(v)
		UF.db[prefix .. name] = v
		local s = UF.small[prefix]
		if s and s.frame then s:Layout() end
	end
end

local selectedText = "name"
local unit = "target"

local FRAMES = {
	{ value = "target", text = "Target" },
	{ value = "tot",    text = "Target of target" },
	{ value = "focus",  text = "Focus" },
}

local function pctFormat(v) return math.floor(v * 100 + 0.5) .. "%" end

-- The frame picker, at the top of every tab; picking builds the tabs again.
local function picker(page)
	page:Section("Frame")
	page:Dropdown({
		label = "Frame to set up",
		desc = "Every option on this tab applies to this frame.",
		values = function() return FRAMES end,
		get = function() return unit end,
		set = function(v)
			if v == unit then return end
			unit = v
			C_Timer.After(0, function() H.Panel:Rebuild("unitframes") end)
		end,
	})
end

--[[ Target ]]

local target = {
	size = function(page)
			page:Section("Size")
			local get, set = field("width")
			page:Slider({ label = "Width", min = 140, max = 420, step = 2, get = get, set = set })
			get, set = field("healthHeight")
			page:Slider({ label = "Life bar height", min = 8, max = 40, step = 1, get = get, set = set })
			get, set = field("showPower")
			page:Toggle({ label = "Show the power bar", get = get, set = set })
			get, set = field("powerHeight")
			page:Slider({ label = "Power bar height", min = 3, max = 20, step = 1, get = get, set = set })
	end,
	text = function(page)
			page:Dropdown({
				label = "Text",
				desc = "Every option below applies to this text.",
				values = function()
					local t = {}
					for _, it in ipairs(UF.TEXTS) do t[#t + 1] = { value = it.key, text = it.label } end
					return t
				end,
				get = function() return selectedText end,
				set = function(v) selectedText = v end,
			})
			local function sel(suffix)
				return function() return UF.db[selectedText .. suffix] end, function(v)
					UF.db[selectedText .. suffix] = v
					UF:Layout()
				end
			end
			page:Section("Look")
			local get, set = sel("Show")
			page:Toggle({ label = "Show", get = get, set = set })
			get, set = sel("Size")
			page:Slider({ label = "Size", min = 6, max = 30, step = 1, get = get, set = set })
			page:Section("Position")
			get, set = sel("X")
			page:Slider({ label = "Offset X", desc = "Right is positive.", min = -100, max = 100, step = 1, get = get, set = set })
			get, set = sel("Y")
			page:Slider({ label = "Offset Y", desc = "Up is positive.", min = -50, max = 50, step = 1, get = get, set = set })
			page:Button({
				label = "Reset this text",
				text = "Reset",
				onClick = function()
					for _, suffix in ipairs({ "Show", "Size", "X", "Y" }) do UF.db[selectedText .. suffix] = nil end
					UF:Layout()
					page:Refresh()
				end,
			})
	end,
	look = function(page)
			page:Section("Style")
			local get, set = field("style")
			page:Dropdown({
				label = "Style",
				desc = "Plaque: a heraldic plaque whose metal and jewels show what the target is. Minimal: a dark glass panel. The plaque's size follows the bar heights (Size tab).",
				values = function()
					return { { value = "plaque", text = "Plaque" }, { value = "minimal", text = "Minimal" } }
				end,
				get = function() return UF:Style() end, set = set,
			})
			page:Section("Colours")
			get, set = field("classColor")
			page:Toggle({ label = "Class colour for players", desc = "Off: players use the reaction colour, like NPCs.", get = get, set = set })
			page:Section("Minimal")
			get, set = field("showGem")
			page:Toggle({ label = "Show the gem", desc = "The level, and a halo for elite, rare and boss units.", get = get, set = set })
			get, set = field("gemSize")
			page:Slider({ label = "Gem size", min = 20, max = 60, step = 1, get = get, set = set })
			get, set = field("panelAlpha")
			page:Slider({ label = "Panel opacity", min = 0, max = 1, step = 0.05, format = pctFormat, get = get, set = set })
	end,
	behaviour = function(page)
			page:Section("Behaviour")
			local get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's target frame", get = get, set = set })
			page:Section("Casts")
			get, set = field("castInPower")
			page:Toggle({ label = "Show casts in the power row", desc = "While the target casts, its power bar turns into the cast bar. Needs the power bar (Size tab).", get = get, set = set })
	end,
}

--[[ Target of target and focus (Small.lua) ]]

local function small(prefix, extra)
	return {
		size = function(page)
			page:Section("Size")
			local get, set = smallField(prefix, "Width")
			page:Slider({ label = "Width", min = 80, max = 320, step = 2, get = get, set = set })
			get, set = smallField(prefix, "HealthHeight")
			page:Slider({ label = "Life bar height", min = 6, max = 30, step = 1, get = get, set = set })
			if extra.power then
				get, set = smallField(prefix, "ShowPower")
				page:Toggle({ label = "Show the power bar", get = get, set = set })
				get, set = smallField(prefix, "PowerHeight")
				page:Slider({ label = "Power bar height", min = 3, max = 16, step = 1, get = get, set = set })
			end
		end,
		text = function(page)
			page:Section("Text")
			local get, set = smallField(prefix, "NameSize")
			page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
			get, set = smallField(prefix, "PctSize")
			page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
		end,
		look = function(page)
			page:Section("Look")
			page:Text("This frame follows the target's plaque: the same metal and jewel colours for each kind of unit, and the target's class colour option.", 36)
		end,
		behaviour = function(page)
			page:Section("Behaviour")
			local get, set = smallField(prefix, "Show")
			page:Toggle({ label = "Show this frame", desc = "Takes effect after /reload.", get = get, set = set })
			if extra.dock then
				get, set = smallField(prefix, "Dock")
				page:Toggle({ label = "Attach to the target", desc = "It follows the target; you can still drag it in edit mode. Off: on its own.", get = get, set = set })
			end
			if extra.blizzard then
				get, set = smallField(prefix, "HideBlizzard")
				page:Toggle({ label = "Hide the game's focus frame", get = get, set = set })
			end
		end,
	}
end

local BUILD = {
	target = target,
	tot = small("tot", { dock = true }),
	focus = small("focus", { power = true, blizzard = true }),
}

local function tab(key)
	return function(page)
		picker(page)
		BUILD[unit][key](page)
	end
end

H:RegisterOptionsPage({
	key = "unitframes",
	label = "Unit frames",
	desc = "Target, target of target and focus. Pick the frame at the top of each tab.",
	group = "modules",
	order = 30,
	tabs = {
		{ key = "size", label = "Size", build = tab("size") },
		{ key = "text", label = "Text", build = tab("text") },
		{ key = "look", label = "Look", build = tab("look") },
		{ key = "behaviour", label = "Behaviour", build = tab("behaviour") },
		{ key = "font", label = "Font", build = function(page)
			page:Text("The font is the module's: it applies to every unit frame.", 20)
			page:FontSection(UF, function() UF:Layout() end)
		end },
	},
})
