--[[
	Heraldry_Tooltips - Settings.lua
	Tooltips page. Tabs: Look | Position | Text | Behaviour | Font.
]]

local H = Heraldry
local TT = H.Modules.byName.Tooltips

local function field(name)
	return function() return TT.db[name] end, function(v)
		TT.db[name] = v
		TT:Layout()
	end
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

H:RegisterOptionsPage({
	key = "tooltips",
	label = "Tooltips",
	desc = "The game's tooltips on paper, with a thin rim in the theme's metal.",
	group = "modules",
	order = 70,
	tabs = {
		{ key = "look", label = "Look", build = function(page)
			page:Section("Paper")
			local get, set = field("paper")
			page:Dropdown({
				label = "Paper",
				desc = "On light parchment every line is recoloured as ink.",
				values = function()
					local t = {}
					for _, k in ipairs(H.Paper.ORDER) do t[#t + 1] = { value = k, text = H.Paper.TYPES[k].label } end
					return t
				end,
				get = get, set = set,
			})
			get, set = field("paperAlpha")
			page:Slider({ label = "Opacity", min = 0.3, max = 1, step = 0.05, format = pct, get = get, set = set })
			page:Section("Rim")
			get, set = field("qualityRim")
			page:Toggle({ label = "Rim in the item's quality colour", desc = "Uncommon and better. Other tooltips use the theme's metal.", get = get, set = set })
			page:Section("Health bar")
			get, set = field("healthBar")
			page:Toggle({ label = "Show the health bar", desc = "A thin strip under unit tooltips.", get = get, set = set })
			get, set = field("barHeight")
			page:Slider({ label = "Height", min = 2, max = 10, step = 1, get = get, set = set })
		end },

		{ key = "position", label = "Position", build = function(page)
			page:Section("Where tooltips show")
			local get, set = field("anchor")
			page:Dropdown({
				label = "Place",
				desc = "Fixed: move it in edit mode (\"Tooltips\"). Tooltips placed by their own window keep that place.",
				values = function() return {
					{ value = "game", text = "Where the game puts them" },
					{ value = "fixed", text = "Fixed place" },
					{ value = "cursor", text = "Next to the cursor" },
				} end,
				get = get, set = set,
			})
			page:Section("Next to the cursor")
			get, set = field("cursorX")
			page:Slider({ label = "Offset X", min = -60, max = 60, step = 1, get = get, set = set })
			get, set = field("cursorY")
			page:Slider({ label = "Offset Y", min = -60, max = 60, step = 1, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Section("Sizes")
			local get, set = field("headerSize")
			page:Slider({ label = "Title", desc = "First line: the unit's or item's name.", min = 8, max = 24, step = 1, get = get, set = set })
			get, set = field("textSize")
			page:Slider({ label = "Lines", min = 7, max = 20, step = 1, get = get, set = set })
			get, set = field("smallSize")
			page:Slider({ label = "Small lines", min = 6, max = 18, step = 1, get = get, set = set })
			page:Section("Colours")
			get, set = field("classNames")
			page:Toggle({ label = "Player names in their class colour", get = get, set = set })
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Combat")
			local get, set = field("hideCombat")
			page:Toggle({ label = "Hide unit tooltips in combat", desc = "Items and spells still show.", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:Text("This module starts with no outline, which reads best on paper.", 20)
			page:FontSection(TT, function() TT:Layout() end)
		end },
	},
})
