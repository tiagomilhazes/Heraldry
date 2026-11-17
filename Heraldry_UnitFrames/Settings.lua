--[[
	Heraldry_UnitFrames - Settings.lua
	Target page. Tabs: Size | Text | Look | Behaviour | Font.
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames

local function field(name)
	return function() return UF.db[name] end, function(v)
		UF.db[name] = v
		UF:Layout()
	end
end

local function pctFormat(v) return math.floor(v * 100 + 0.5) .. "%" end

H:RegisterOptionsPage({
	key = "target",
	label = "Target",
	desc = "The target frame. Select yourself to see it while you set it up.",
	group = "modules",
	order = 30,
	tabs = {
		{ key = "size", label = "Size", build = function(page)
			page:Section("Size")
			local get, set = field("width")
			page:Slider({ label = "Width", min = 140, max = 420, step = 2, get = get, set = set })
			get, set = field("healthHeight")
			page:Slider({ label = "Life bar height", min = 8, max = 40, step = 1, get = get, set = set })
			get, set = field("showPower")
			page:Toggle({ label = "Show the power bar", get = get, set = set })
			get, set = field("powerHeight")
			page:Slider({ label = "Power bar height", min = 3, max = 20, step = 1, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Section("Name")
			local get, set = field("nameSize")
			page:Slider({ label = "Name size", min = 8, max = 22, step = 1, get = get, set = set })
			page:Section("Values")
			get, set = field("healthText")
			page:Dropdown({
				label = "Life",
				values = function()
					return {
						{ value = "both", text = "Value and percentage" },
						{ value = "percent", text = "Percentage" },
						{ value = "current", text = "Value" },
						{ value = "none", text = "None" },
					}
				end,
				get = get, set = set,
			})
			get, set = field("powerText")
			page:Toggle({ label = "Show the power value", get = get, set = set })
			get, set = field("valueSize")
			page:Slider({ label = "Value size", min = 7, max = 18, step = 1, get = get, set = set })
		end },

		{ key = "look", label = "Look", build = function(page)
			page:Section("Style")
			local get, set = field("style")
			page:Dropdown({
				label = "Style",
				desc = "Heraldic: an ornament that shows what the target is (class, hostile, friendly, elite, rare, boss). Minimal: a dark glass panel.",
				values = function()
					return { { value = "heraldic", text = "Heraldic" }, { value = "minimal", text = "Minimal" } }
				end,
				get = get, set = set,
			})
			page:Section("Heraldic")
			get, set = field("rails")
			page:Dropdown({
				label = "Rails on players",
				desc = "Class: the rails of the class's rod. Neutral: the dark iron rails of hostile targets, for a calmer frame.",
				values = function()
					return { { value = "class", text = "Class" }, { value = "neutral", text = "Neutral" } }
				end,
				get = get, set = set,
			})
			get, set = field("bothEnds")
			page:Toggle({ label = "Ornament on both ends", desc = "The level stays on the left ornament.", get = get, set = set })
			get, set = field("capSize")
			page:Slider({ label = "Ornament size", min = 40, max = 140, step = 2, get = get, set = set })
			get, set = field("capOverlap")
			page:Slider({ label = "Ornament overlap", desc = "How far the ornaments reach over the ends of the bars. Negative leaves a gap.", min = -20, max = 40, step = 1, get = get, set = set })
			get, set = field("railSize")
			page:Slider({ label = "Rail thickness", min = 3, max = 20, step = 1, get = get, set = set })
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
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Behaviour")
			local get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's target frame", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:FontSection(UF, function() UF:Layout() end)
		end },
	},
})
