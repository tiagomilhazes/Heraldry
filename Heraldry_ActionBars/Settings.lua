--[[
	Heraldry_ActionBars - Settings.lua
	One page: pick a bar, then set it up.
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars

local selected = 1

H:RegisterOptionsPage({
	key = "actionbars",
	label = "Action bars",
	desc = "Pick a bar, then set it up. Move the bars in edit mode.",
	group = "modules",
	order = 10,
	build = function(page)
		local UI = H.UI

		local function apply()
			local bar = AB.bars[selected]
			if bar then AB:LayoutBar(bar) end
			H:RefreshEditMode()
		end
		local function field(name)
			return function() return AB:Get(selected, name) end, function(v)
				AB:Set(selected, name, v)
				apply()
			end
		end

		page:Section("Bar")
		page:Dropdown({
			label = "Bar to set up",
			desc = "Every option below applies to this bar.",
			values = function()
				local t = {}
				for _, def in ipairs(AB.BARS) do
					if AB.bars[def.n] then
						local off = AB:IsBarEnabled(def.n) and "" or "  |cff888888(off)|r"
						t[#t + 1] = { value = def.n, text = def.label .. off }
					end
				end
				return t
			end,
			get = function() return selected end,
			set = function(v) selected = v end,
		})
		page:Toggle({
			label = "Show this bar",
			desc = "Action bars follow the game's own setting until you set them.",
			get = function() return AB:IsBarEnabled(selected) end,
			set = function(v)
				AB:Set(selected, "enabled", v)
				apply()
			end,
		})

		page:Section("Layout")
		local get, set = field("buttons")
		page:Slider({ label = "Buttons", desc = "How many buttons the bar shows, at most.", min = 1, max = 12, step = 1, get = get, set = set })
		get, set = field("perRow")
		page:Slider({ label = "Buttons per row", desc = "1 makes a vertical bar.", min = 1, max = 12, step = 1, get = get, set = set })
		get, set = field("size")
		page:Slider({ label = "Button size", desc = "In pixels.", min = 24, max = 64, step = 1, get = get, set = set })
		get, set = field("spacing")
		page:Slider({ label = "Spacing", desc = "Space between buttons, in pixels.", min = 0, max = 16, step = 1, get = get, set = set })

		page:Section("Visibility")
		local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
		get, set = field("alpha")
		page:Slider({ label = "Opacity", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
		get, set = field("mouseover")
		page:Toggle({ label = "Show on mouseover only", desc = "Fades the bar until the mouse is over it.", get = get, set = set })
		get, set = field("fadeAlpha")
		page:Slider({ label = "Faded opacity", desc = "Opacity while faded.", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })

		page:Section("Reset")
		page:Button({
			label = "Reset this bar",
			desc = "Options and position back to their defaults, in the active profile.",
			text = "Reset",
			kind = "danger",
			onClick = function()
				UI.Confirm(("Reset the %s?"):format(AB.defs[selected].label:lower()), "Reset", function()
					AB:ResetBar(selected)
					page:Refresh()
				end)
			end,
		})
	end,
})
