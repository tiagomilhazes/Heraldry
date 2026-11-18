--[[
	Heraldry_DataBar - Settings.lua
	Data bar page. Tabs: Bar | Blocks | Text | Behaviour | Font.
]]

local H = Heraldry
local DB = H.Modules.byName.DataBar

local function field(name)
	return function() return DB.db[name] end, function(v)
		DB.db[name] = v
		DB:Layout()
	end
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

local PLACES = function() return {
	{ value = "left", text = "Left" }, { value = "center", text = "Centre" },
	{ value = "right", text = "Right" }, { value = "off", text = "Hidden" },
} end

H:RegisterOptionsPage({
	key = "databar",
	label = "Data bar",
	desc = "A thin bar along the top of the screen: micro menu, experience on the theme's rail, gold, bags, durability, FPS and latency.",
	group = "modules",
	order = 42,
	tabs = {
		{ key = "bar", label = "Bar", build = function(page)
			page:Section("Bar")
			local get, set = field("edge")
			page:Dropdown({
				label = "Edge of the screen",
				values = function() return { { value = "top", text = "Top" }, { value = "bottom", text = "Bottom" } } end,
				get = get, set = set,
			})
			get, set = field("height")
			page:Slider({ label = "Height", min = 14, max = 40, step = 1, get = get, set = set })
			get, set = field("bgAlpha")
			page:Slider({ label = "Background opacity", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
			page:Section("Experience rail")
			get, set = field("rail")
			page:Toggle({ label = "Show the rail", desc = "The theme's rail along the inner edge, lit by experience (gold) and rested experience (blue); at the level cap, by the watched reputation.", get = get, set = set })
			get, set = field("railSize")
			page:Slider({ label = "Rail thickness", min = 2, max = 16, step = 1, get = get, set = set })
		end },

		{ key = "blocks", label = "Blocks", build = function(page)
			page:Text("Each block goes left, in the centre or right, or is hidden. Blocks in the same place are ordered by their number.", 30)
			for _, d in ipairs(DB.BLOCKS) do
				page:Section(d.label)
				local get, set = field(d.key .. "Place")
				page:Dropdown({ label = "Place", values = PLACES, get = get, set = set })
				get, set = field(d.key .. "Order")
				page:Slider({ label = "Order", min = 1, max = 9, step = 1, get = get, set = set })
				if d.key == "clock" then
					page:Text("The minimap shows the time too: show it here only if you hide it there.", 20)
					get, set = field("clock24")
					page:Toggle({ label = "24-hour clock", get = get, set = set })
				end
			end
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Section("Text")
			local get, set = field("textSize")
			page:Slider({ label = "Size", min = 7, max = 20, step = 1, get = get, set = set })
			get, set = field("gap")
			page:Slider({ label = "Space between blocks", min = 4, max = 60, step = 1, get = get, set = set })
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Game bars")
			local get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's experience, reputation and bag bars", desc = "Showing them again takes effect after /reload.", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:FontSection(DB, function() DB:Layout() end)
		end },
	},
})
