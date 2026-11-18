--[[
	Heraldry_DataBar - Settings.lua
	Data bar page. Tabs: Bar | Rail | Blocks | Text | Behaviour | Font.
	The Blocks tab picks one block and shows its place, order and own options.
]]

local H = Heraldry
local DB = H.Modules.byName.DataBar

local function field(name)
	return function() return DB.db[name] end, function(v)
		DB.db[name] = v
		DB:Layout()
	end
end

local function colour(name)
	return function() local c = DB.db[name] return c[1], c[2], c[3] end,
		function(r, g, b)
			DB.db[name] = { r, g, b }
			DB:Layout()
		end
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

local PLACES = function() return {
	{ value = "left", text = "Left" }, { value = "center", text = "Centre" },
	{ value = "right", text = "Right" }, { value = "off", text = "Hidden" },
} end

local function list(...)
	local t, args = {}, { ... }
	for i = 1, #args, 2 do t[#t + 1] = { value = args[i], text = args[i + 1] } end
	return function() return t end
end

local selected = "xp"

-- the options of one block, below its place and order
local BLOCK_OPTIONS = {
	micro = function(page)
		local get, set = field("microScale")
		page:Slider({ label = "Size", desc = "Against the bar's height.", min = 0.5, max = 1.5, step = 0.05, format = pct, get = get, set = set })
	end,
	xp = function(page)
		local get, set = field("xpFormat")
		page:Dropdown({ label = "Experience as", values = list("percent", "Percentage (59%)", "numbers", "Numbers (1,234 / 5,000)",
			"both", "Both", "left", "What's left (3,766 to go)"), get = get, set = set })
		get, set = field("xpLevel")
		page:Toggle({ label = "Show the level", get = get, set = set })
		get, set = field("xpRested")
		page:Toggle({ label = "Show rested experience", get = get, set = set })
		page:Text("At the level cap this block shows the watched reputation.", 20)
	end,
	gold = function(page)
		local get, set = field("goldFormat")
		page:Dropdown({ label = "Format", values = list("full", "Gold, silver, copper", "icons", "With coin icons",
			"gold", "Gold only", "short", "Short (1.2k g)"), get = get, set = set })
	end,
	bags = function(page)
		local get, set = field("bagsFormat")
		page:Dropdown({ label = "Show", values = list("free", "Free / total", "used", "Used / total", "freeOnly", "Free only"), get = get, set = set })
		get, set = field("bagsWarn")
		page:Slider({ label = "Red at", desc = "Free slots left.", min = 0, max = 20, step = 1, get = get, set = set })
	end,
	durability = function(page)
		local get, set = field("durabilityWarn")
		page:Slider({ label = "Red at", min = 0.05, max = 0.6, step = 0.05, format = pct, get = get, set = set })
	end,
	perf = function(page)
		local get, set = field("perfFps")
		page:Toggle({ label = "Frames per second", get = get, set = set })
		get, set = field("perfLatency")
		page:Dropdown({ label = "Latency", values = list("max", "The higher of home and world", "home", "Home", "world", "World", "off", "Hidden"), get = get, set = set })
	end,
	clock = function(page)
		page:Text("The minimap shows the time too: show it here only if you hide it there.", 20)
		local get, set = field("clock24")
		page:Toggle({ label = "24-hour clock", get = get, set = set })
		get, set = field("clockServer")
		page:Toggle({ label = "Server time", desc = "Off: your computer's time.", get = get, set = set })
		get, set = field("clockSeconds")
		page:Toggle({ label = "Seconds", get = get, set = set })
	end,
	zone = function(page)
		local get, set = field("zoneSub")
		page:Toggle({ label = "Show the subzone", get = get, set = set })
	end,
	coords = function(page)
		local get, set = field("coordsDecimals")
		page:Slider({ label = "Decimals", min = 0, max = 2, step = 1, get = get, set = set })
	end,
}

H:RegisterOptionsPage({
	key = "databar",
	label = "Data bar",
	desc = "A thin bar along the edge of the screen: micro menu, experience on the theme's rail, gold, bags, durability, FPS and more.",
	group = "modules",
	order = 42,
	tabs = {
		{ key = "bar", label = "Bar", build = function(page)
			page:Section("Place")
			local get, set = field("edge")
			page:Dropdown({ label = "Edge of the screen", values = list("top", "Top", "bottom", "Bottom"), get = get, set = set })
			get, set = field("offsetY")
			page:Slider({ label = "Distance from the edge", min = 0, max = 200, step = 1, get = get, set = set })
			get, set = field("widthMode")
			page:Dropdown({ label = "Width", values = list("full", "End to end", "fixed", "Fixed, centred"), get = get, set = set })
			get, set = field("width")
			page:Slider({ label = "Fixed width", min = 300, max = 3000, step = 10, get = get, set = set })
			get, set = field("height")
			page:Slider({ label = "Height", min = 14, max = 60, step = 1, get = get, set = set })
			get, set = field("strata")
			page:Dropdown({ label = "Layer", desc = "Which frames it draws over.", values = list("BACKGROUND", "Background", "LOW", "Low",
				"MEDIUM", "Medium", "HIGH", "High"), get = get, set = set })
			page:Section("Background")
			get, set = field("background")
			page:Dropdown({ label = "Background", values = function()
				local t = { { value = "flat", text = "Flat colour" } }
				for _, k in ipairs(H.Paper.ORDER) do t[#t + 1] = { value = k, text = H.Paper.TYPES[k].label } end
				return t
			end, get = get, set = set })
			local cg, cs = colour("bgColor")
			page:Color({ label = "Colour", desc = "For the flat background.", get = cg, set = cs })
			get, set = field("bgAlpha")
			page:Slider({ label = "Opacity", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
			page:Section("Rim")
			get, set = field("rim")
			page:Toggle({ label = "Thin line on the inner edge", desc = "In the theme's metal; the rail takes its place when it is on that edge.", get = get, set = set })
			get, set = field("rimOuter")
			page:Toggle({ label = "Thin line on the outer edge", get = get, set = set })
		end },

		{ key = "rail", label = "Rail", build = function(page)
			page:Section("Rail")
			local get, set = field("rail")
			page:Toggle({ label = "Show the rail", desc = "The theme's rail, lit by experience and rested experience, or by the watched reputation.", get = get, set = set })
			get, set = field("railPlace")
			page:Dropdown({ label = "Edge", values = list("inner", "Inner edge (towards the screen)", "outer", "Outer edge (against the screen's edge)"), get = get, set = set })
			get, set = field("railSize")
			page:Slider({ label = "Thickness", min = 2, max = 24, step = 1, get = get, set = set })
			get, set = field("railDim")
			page:Slider({ label = "Unlit part", desc = "How bright the empty part of the rail is.", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
			get, set = field("railRep")
			page:Dropdown({ label = "Reputation", values = list("cap", "At the level cap", "always", "Always (instead of experience)", "never", "Never"), get = get, set = set })
			page:Section("Colours")
			local cg, cs = colour("xpColor")
			page:Color({ label = "Experience", get = cg, set = cs })
			cg, cs = colour("restColor")
			page:Color({ label = "Rested", get = cg, set = cs })
			cg, cs = colour("repColor")
			page:Color({ label = "Reputation", get = cg, set = cs })
		end },

		{ key = "blocks", label = "Blocks", build = function(page)
			page:Text("Pick a block: each goes left, in the centre or right (or is hidden); blocks in the same place go by their order.", 30)
			page:Dropdown({
				label = "Block",
				values = function()
					local t = {}
					for _, d in ipairs(DB.BLOCKS) do
						local place = DB.db[d.key .. "Place"]
						t[#t + 1] = { value = d.key, text = d.label .. (place == "off" and "  |cff888888(hidden)|r" or "") }
					end
					return t
				end,
				get = function() return selected end,
				set = function(v) selected = v H.Panel:Rebuild("databar") end,
			})
			local label
			for _, d in ipairs(DB.BLOCKS) do if d.key == selected then label = d.label end end
			page:Section(label or selected)
			local get, set = field(selected .. "Place")
			page:Dropdown({ label = "Place", values = PLACES, get = get, set = set })
			get, set = field(selected .. "Order")
			page:Slider({ label = "Order", min = 1, max = 12, step = 1, get = get, set = set })
			if BLOCK_OPTIONS[selected] then BLOCK_OPTIONS[selected](page) end
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Section("Text")
			local get, set = field("textSize")
			page:Slider({ label = "Size", min = 7, max = 30, step = 1, get = get, set = set })
			get, set = field("gap")
			page:Slider({ label = "Space between blocks", min = 0, max = 80, step = 1, get = get, set = set })
			get, set = field("pad")
			page:Slider({ label = "Space at the ends", min = 0, max = 80, step = 1, get = get, set = set })
			get, set = field("separator")
			page:Dropdown({ label = "Separator", values = list("·", "·  (dot)", "|", "|  (bar)", "-", "-  (dash)", "/", "/  (slash)"), get = get, set = set })
			page:Section("Labels and colours")
			get, set = field("labels")
			page:Toggle({ label = "Labels", desc = "\"Bags\", \"Armour\", \"Friends\"... before the values.", get = get, set = set })
			local cg, cs = colour("labelColor")
			page:Color({ label = "Label colour", get = cg, set = cs })
			get, set = field("valueColors")
			page:Toggle({ label = "Coloured values", desc = "Green, yellow and red for bags, durability and latency.", get = get, set = set })
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Showing")
			local get, set = field("fade")
			page:Toggle({ label = "Fade out when the mouse is away", get = get, set = set })
			get, set = field("fadeAlpha")
			page:Slider({ label = "Faded to", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
			get, set = field("hideCombat")
			page:Toggle({ label = "Hide in combat", get = get, set = set })
			get, set = field("tooltips")
			page:Toggle({ label = "Tooltips on the blocks", get = get, set = set })
			page:Section("Game bars")
			get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's experience, reputation and bag bars", desc = "Showing them again takes effect after /reload.", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:FontSection(DB, function() DB:Layout() end)
		end },
	},
})
