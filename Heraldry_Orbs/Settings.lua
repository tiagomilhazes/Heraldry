--[[
	Heraldry_Orbs - Settings.lua
]]

local H = Heraldry
local Orbs = H.Modules.byName.Orbs

H:RegisterOptionsPage({
	key = "orbs",
	label = "Orbs",
	desc = "Life and power orbs at the ends of the action bars.",
	group = "modules",
	order = 20,
	build = function(page)
		local function field(name)
			return function() return Orbs.db[name] end, function(v)
				Orbs.db[name] = v
				Orbs:Layout()
			end
		end

		page:Section("Place")
		local get, set = field("attach")
		page:Toggle({ label = "Attach to the action bars", desc = "The orbs sit at the ends of bar 1 and move with it. Off: move them in edit mode.", get = get, set = set })
		get, set = field("size")
		page:Slider({ label = "Size", desc = "Diameter of the glass, in pixels.", min = 48, max = 200, step = 2, get = get, set = set })
		get, set = field("distance")
		page:Slider({ label = "Distance from the bar", desc = "Gap between the ring and the buttons.", min = -40, max = 60, step = 1, get = get, set = set })
		get, set = field("offsetY")
		page:Slider({ label = "Height", desc = "Raise or lower the orbs.", min = -60, max = 60, step = 1, get = get, set = set })

		page:Section("Text")
		get, set = field("showText")
		page:Toggle({ label = "Show values", get = get, set = set })
		get, set = field("textFormat")
		page:Dropdown({
			label = "Format",
			values = function()
				return {
					{ value = "stacked", text = "Value and percentage" },
					{ value = "percent", text = "Percentage" },
					{ value = "current", text = "Value" },
				}
			end,
			get = get, set = set,
		})
		get, set = field("textSize")
		page:Slider({ label = "Text size", min = 0.5, max = 2, step = 0.05, format = function(v) return math.floor(v * 100 + 0.5) .. "%" end, get = get, set = set })

		page:FontSection(Orbs, function() Orbs:Layout() end)

		page:Section("Behaviour")
		get, set = field("clickable")
		page:Toggle({ label = "Click the life orb", desc = "Left click targets you, right click opens your menu.", get = get, set = set })
		get, set = field("hidePlayerFrame")
		page:Toggle({ label = "Hide the game's player frame", desc = "The orbs already show your life and power.", get = get, set = set })
	end,
})
