--[[
	Heraldry_Chat - Settings.lua
	Chat page. Tabs: Look | Size | Text | Behaviour | Font.
]]

local H = Heraldry
local CH = H.Modules.byName.Chat

local function field(name)
	return function() return CH.db[name] end, function(v)
		CH.db[name] = v
		CH:Layout()
	end
end

local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

H:RegisterOptionsPage({
	key = "chat",
	label = "Chat",
	desc = "The chat as a scroll that unrolls sideways. Click a rod to roll it up.",
	group = "modules",
	order = 60,
	tabs = {
		{ key = "look", label = "Look", build = function(page)
			page:Section("Style")
			page:Dropdown({
				label = "Style",
				desc = "Scroll: rods and paper, rolls up sideways. Panel: a flat dark panel with a thin rim.",
				values = function() return { { value = "scroll", text = "Scroll" }, { value = "panel", text = "Panel" } } end,
				get = function() return CH.db.style end,
				set = function(v)
					CH.db.style = v
					CH.rolled = v == "scroll" and CH.db.rolledUp
					CH:Layout()
				end,
			})
			page:Section("Paper")
			local get, set = field("paper")
			page:Dropdown({
				label = "Paper",
				desc = "Scroll style only. On light paper new lines are darkened to read as ink.",
				values = function() return {
					{ value = "dark", text = "Dark parchment" },
					{ value = "light", text = "Light parchment" },
					{ value = "glass", text = "Dark glass" },
				} end,
				get = get, set = set,
			})
			get, set = field("paperAlpha")
			page:Slider({ label = "Opacity", min = 0.2, max = 1, step = 0.05, format = pct, get = get, set = set })
			get, set = field("rodSize")
			page:Slider({ label = "Rod size", desc = "The rods use the theme's art and finish.", min = 14, max = 44, step = 1, get = get, set = set })
		end },

		{ key = "size", label = "Size", build = function(page)
			page:Section("Size")
			local get, set = field("width")
			page:Slider({ label = "Width", desc = "Open, rods included.", min = 240, max = 900, step = 2, get = get, set = set })
			get, set = field("height")
			page:Slider({ label = "Height", min = 100, max = 600, step = 2, get = get, set = set })
			get, set = field("margin")
			page:Slider({ label = "Text margin", desc = "Space between the text and the paper's edges.", min = 0, max = 30, step = 1, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Section("Messages")
			local get, set = field("textSize")
			page:Slider({ label = "Size", desc = "0 uses the size picked in the game's chat menu, per window.", min = 0, max = 24, step = 1,
				format = function(v) return v == 0 and "Game" or tostring(v) end, get = get, set = set })
			page:Section("Tabs")
			get, set = field("tabSize")
			page:Slider({ label = "Size", min = 8, max = 20, step = 1, get = get, set = set })
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Rolled up")
			local get, set = field("glow")
			page:Toggle({ label = "Rods glow when a message arrives", get = get, set = set })
			get, set = field("enterUnrolls")
			page:Toggle({ label = "Enter unrolls the scroll to type", desc = "It rolls up again when you are done.", get = get, set = set })
			page:Section("Game buttons")
			get, set = field("hideButtons")
			page:Toggle({ label = "Hide the game's chat buttons", desc = "Social, channels, chat menu, the scroll bar and the scroll buttons (the mouse wheel still scrolls). The tabs' right-click menu keeps the chat options.", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:Text("This module starts with no outline, which reads best on paper.", 20)
			page:FontSection(CH, function() CH:Layout() end)
		end },
	},
})
