--[[
	Heraldry_Quests - Settings.lua
	Quests page. Tabs: Look | Text | Behaviour | Font.
]]

local H = Heraldry
local Q = H.Modules.byName.Quests

local function field(name)
	return function() return Q.db[name] end, function(v)
		Q.db[name] = v
		Q:Layout()
	end
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

H:RegisterOptionsPage({
	key = "quests",
	label = "Quests",
	desc = "The quest tracker as a parchment scroll. Click the top rod to roll it up.",
	group = "modules",
	order = 50,
	tabs = {
		{ key = "look", label = "Look", build = function(page)
			page:Section("Paper")
			local get, set = field("paper")
			page:Dropdown({
				label = "Paper",
				desc = "Light paper is written in ink; dark paper in gold and parchment colours.",
				values = function() return { { value = "light", text = "Light" }, { value = "dark", text = "Dark" } } end,
				get = get, set = set,
			})
			get, set = field("paperAlpha")
			page:Slider({ label = "Paper opacity", min = 0.3, max = 1, step = 0.05, format = pct, get = get, set = set })
			page:Section("Size")
			get, set = field("width")
			page:Slider({ label = "Width", desc = "Rods included.", min = 180, max = 480, step = 2, get = get, set = set })
			get, set = field("maxHeight")
			page:Slider({ label = "Maximum height", desc = "Quests past this height are not shown.", min = 120, max = 900, step = 10, get = get, set = set })
			get, set = field("rodSize")
			page:Slider({ label = "Rod size", desc = "The rods use the theme's art and finish.", min = 16, max = 48, step = 1, get = get, set = set })
			get, set = field("margin")
			page:Slider({ label = "Text margin", desc = "Space between the text and the paper's edges.", min = 0, max = 30, step = 1, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Section("Header")
			local get, set = field("headerShow")
			page:Toggle({ label = "Show \"Quests\" at the top", get = get, set = set })
			get, set = field("headerSize")
			page:Slider({ label = "Size", min = 8, max = 24, step = 1, get = get, set = set })
			page:Section("Quest titles")
			get, set = field("titleSize")
			page:Slider({ label = "Size", min = 8, max = 22, step = 1, get = get, set = set })
			get, set = field("showLevel")
			page:Toggle({ label = "Show the quest level", get = get, set = set })
			get, set = field("difficultyColor")
			page:Toggle({ label = "Colour titles by difficulty", desc = "On light paper the colours are darkened to read as ink.", get = get, set = set })
			page:Section("Objectives")
			get, set = field("objectiveSize")
			page:Slider({ label = "Size", min = 7, max = 20, step = 1, get = get, set = set })
			get, set = field("hideDone")
			page:Toggle({ label = "Hide finished objectives", get = get, set = set })
			page:Section("Spacing")
			get, set = field("questSpacing")
			page:Slider({ label = "Space between quests", min = 0, max = 24, step = 1, get = get, set = set })
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Quests")
			local get, set = field("source")
			page:Dropdown({
				label = "Quests on the scroll",
				values = function() return { { value = "watched", text = "Tracked quests" }, { value = "all", text = "Every quest in the log" } } end,
				get = get, set = set,
			})
			page:Section("Behaviour")
			get, set = field("combatRollUp")
			page:Toggle({ label = "Roll up in combat", desc = "Unrolls again when the fight ends.", get = get, set = set })
			page:Toggle({
				label = "Hide the game's quest tracker",
				get = function() return Q.db.hideBlizzard end,
				set = function(v)
					Q.db.hideBlizzard = v
					Q:ApplyBlizzard()
				end,
			})
			page:Text("When Questie's own tracker is on, this scroll steps aside and Questie's tracker is used.", 30)
		end },

		{ key = "font", label = "Font", build = function(page)
			page:Text("This module starts with no outline, because ink on paper reads better without one.", 20)
			page:FontSection(Q, function() Q:Layout() end)
		end },
	},
})
