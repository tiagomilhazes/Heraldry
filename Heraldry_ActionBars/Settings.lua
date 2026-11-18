--[[
	Heraldry_ActionBars - Settings.lua
	Tabs: Block | Bars | Look | Visibility | Text | Swing | Cast | Font.
	Bars, Look and Visibility work on one bar, picked at the top of each of
	them (the same choice in all three). Block, Text and Font are for every bar.
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars

local selected = 1

local function apply()
	AB:LayoutAll()   -- bars 1 and 2 share the block's plate: lay out everything
end

-- get/set for a setting of the selected bar
local function field(name)
	return function() return AB:Get(selected, name) end, function(v)
		AB:Set(selected, name, v)
		apply()
	end
end

-- get/set for a setting shared by every bar
local function global(name)
	return function() return AB.db[name] end, function(v)
		AB.db[name] = v
		apply()
	end
end

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

-- The bar picker at the top of the per-bar tabs.
local function barPicker(page)
	page:Section("Bar")
	page:Dropdown({
		label = "Bar to set up",
		desc = "Every option on this tab applies to this bar.",
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
end

local ANCHORS = {
	{ value = "TOPLEFT", text = "Top left" }, { value = "TOP", text = "Top" }, { value = "TOPRIGHT", text = "Top right" },
	{ value = "LEFT", text = "Left" }, { value = "CENTER", text = "Centre" }, { value = "RIGHT", text = "Right" },
	{ value = "BOTTOMLEFT", text = "Bottom left" }, { value = "BOTTOM", text = "Bottom" }, { value = "BOTTOMRIGHT", text = "Bottom right" },
}

H:RegisterOptionsPage({
	key = "actionbars",
	label = "Action bars",
	desc = "Move the bars in edit mode. Bars 1 and 2 form the block.",
	group = "modules",
	order = 10,
	tabs = {
		{ key = "block", label = "Block", build = function(page)
			page:Section("Block")
			local get, set = global("join")
			page:Toggle({ label = "Join bars 1 and 2", desc = "Bar 2 sits on top of bar 1, one plate around both, they move together.", get = get, set = set })
			get, set = global("joinGap")
			page:Slider({ label = "Gap between bars 1 and 2", min = 0, max = 20, step = 1, get = get, set = set })
		end },

		{ key = "bars", label = "Bars", build = function(page)
			barPicker(page)
			local get, set = field("enabled")
			page:Toggle({
				label = "Show this bar",
				desc = "Action bars follow the game's own setting until you set them.",
				get = function() return AB:IsBarEnabled(selected) end,
				set = set,
			})
			get, set = field("hotkeys")
			page:Toggle({ label = "Show keybinds on this bar", desc = "Off for a bar you only use with the mouse.", get = get, set = set })

			page:Section("Layout")
			get, set = field("buttons")
			page:Slider({ label = "Buttons", desc = "How many buttons the bar shows, at most.", min = 1, max = 12, step = 1, get = get, set = set })
			get, set = field("perRow")
			page:Slider({ label = "Buttons per row", desc = "1 makes a vertical bar.", min = 1, max = 12, step = 1, get = get, set = set })
			get, set = field("size")
			page:Slider({ label = "Button size", desc = "In pixels.", min = 24, max = 64, step = 1, get = get, set = set })
			get, set = field("spacing")
			page:Slider({ label = "Spacing", desc = "Space between buttons, in pixels.", min = 0, max = 16, step = 1, get = get, set = set })

			page:Section("Reset")
			page:Button({
				label = "Reset this bar",
				desc = "Every option of this bar and its position back to the defaults, in the active profile.",
				text = "Reset",
				kind = "danger",
				onClick = function()
					H.UI.Confirm(("Reset the %s?"):format(AB.defs[selected].label:lower()), "Reset", function()
						AB:ResetBar(selected)
						page:Refresh()
					end)
				end,
			})
		end },

		{ key = "look", label = "Look", build = function(page)
			barPicker(page)
			page:Section("Buttons")
			local get, set = field("frame")
			page:Dropdown({
				label = "Button frames",
				desc = "Theme frames come from the active theme (Theme page).",
				values = function()
					return {
						{ value = "simple", text = "Simple border" },
						{ value = "slim", text = "Theme frame, slim" },
						{ value = "ornate", text = "Theme frame, ornate" },
						{ value = "game", text = "Game default" },
					}
				end,
				get = get, set = set,
			})

			page:Section("Plate")
			get, set = field("plate")
			page:Toggle({ label = "Plate behind the bar", desc = "With bars 1 and 2 joined, bar 1's plate covers both.", get = get, set = set })
			get, set = field("pad")
			page:Slider({ label = "Margin, sides", desc = "Space between the buttons and the ends of the plate.", min = 0, max = 24, step = 1, get = get, set = set })
			get, set = field("padY")
			page:Slider({ label = "Margin, top and bottom", desc = "Space between the buttons and the rails.", min = 0, max = 24, step = 1, get = get, set = set })
			get, set = field("railExtend")
			page:Slider({ label = "Plate and rails past the bar", desc = "How far they run past each end, under the orbs.", min = 0, max = 120, step = 2, get = get, set = set })

			page:Section("Rails and crests")
			get, set = field("rails")
			page:Toggle({ label = "Rails", desc = "Strips along the top and bottom of the plate.", get = get, set = set })
			get, set = field("railSize")
			page:Slider({ label = "Rail thickness", min = 4, max = 30, step = 1, get = get, set = set })
			get, set = field("caps")
			page:Toggle({ label = "End crests", desc = "Only on bars wider than tall. The orbs take their place on the block.", get = get, set = set })
		end },

		{ key = "visibility", label = "Visibility", build = function(page)
			barPicker(page)
			page:Section("Opacity")
			local get, set = field("alpha")
			page:Slider({ label = "Opacity", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
			get, set = field("mouseover")
			page:Toggle({ label = "Show on mouseover only", desc = "Fades the bar until the mouse is over it.", get = get, set = set })
			get, set = field("fadeAlpha")
			page:Slider({ label = "Faded opacity", desc = "Opacity while faded.", min = 0, max = 1, step = 0.05, format = pct, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Text("These apply to every bar. Keybinds can be hidden per bar on the Bars tab.")
			for _, t in ipairs(AB.TEXTS) do
				local k = t.key
				page:Section(t.label)
				local get, set = global(k .. "Show")
				page:Toggle({ label = "Show", get = get, set = set })
				if k == "hotkey" then
					get, set = global("hotkeyShort")
					page:Toggle({ label = "Short keybinds", desc = "s-Z becomes SZ, Mouse Button 4 becomes M4.", get = get, set = set })
				end
				get, set = global(k .. "Size")
				page:Slider({ label = "Size", desc = "Share of the button, so it follows the button size.", min = 0.12, max = 0.6, step = 0.01, format = pct, get = get, set = set })
				get, set = global(k .. "Pos")
				page:Dropdown({ label = "Position", values = function() return ANCHORS end, get = get, set = set })
				get, set = global(k .. "X")
				page:Slider({ label = "Offset, sideways", min = -20, max = 20, step = 1, get = get, set = set })
				get, set = global(k .. "Y")
				page:Slider({ label = "Offset, up and down", min = -20, max = 20, step = 1, get = get, set = set })
			end
		end },

		{ key = "swing", label = "Swing", build = function(page)
			if not AB.LayoutSwing then
				page:Text("This client has no swing timer.")
				return
			end
			local function sw(name)
				return function() return AB.db[name] end, function(v)
					AB.db[name] = v
					AB:LayoutSwing()
					AB:SwingBlizzard()
				end
			end
			page:Text("The theme's rail lights up as your swing builds. Main hand from the left; with two weapons the off hand comes from the right, and when they meet in the middle your hands are in sync.")
			page:Section("Swing bar")
			local get, set = sw("swingShow")
			page:Toggle({ label = "Show the swing bar", get = get, set = set })
			get, set = sw("swingPlace")
			page:Dropdown({
				label = "Where",
				desc = "On one of the block's rails: that rail dims and lights up, nothing is added (keep the swing and the cast on different rails). A bar of its own: a separate rail you can place and size.",
				values = function() return { { value = "top", text = "The block's top rail" }, { value = "bottom", text = "The block's bottom rail" }, { value = "bar", text = "A bar of its own" } } end,
				get = get, set = set,
			})
			get, set = sw("swingHideIdle")
			page:Toggle({ label = "Hide when idle", desc = "Fades out when nothing is swinging and auto attack is off.", get = get, set = set })
			get, set = sw("swingHideBlizzard")
			page:Toggle({ label = "Hide the game's swing bars", get = get, set = set })
			page:Section("A bar of its own")
			get, set = sw("swingDock")
			page:Toggle({ label = "On top of the block", desc = "Sits on top of the block and follows it; you can still drag it in edit mode. Off: on its own.", get = get, set = set })
			get, set = sw("swingGap")
			page:Slider({ label = "Gap above the block", min = -10, max = 30, step = 1, get = get, set = set })
			get, set = sw("swingMatch")
			page:Toggle({ label = "As long as the block", desc = "The same length as the block's rails.", get = get, set = set })
			get, set = sw("swingWidth")
			page:Slider({ label = "Length", desc = "When not as long as the block.", min = 100, max = 1200, step = 10, get = get, set = set })
			get, set = sw("swingHeight")
			page:Slider({ label = "Thickness", min = 6, max = 40, step = 1, get = get, set = set })
			page:Section("Look")
			get, set = sw("swingDim")
			page:Slider({ label = "Unlit rail brightness", min = 0, max = 0.8, step = 0.05, format = pct, get = get, set = set })
			get, set = sw("swingSpark")
			page:Toggle({ label = "Spark at the edge", get = get, set = set })
			get, set = sw("swingOffHand")
			page:Toggle({ label = "Off hand from the right", desc = "With two weapons. Off: only the main hand.", get = get, set = set })
			get, set = sw("swingRanged")
			page:Toggle({ label = "Ranged swings", desc = "Auto shot and wands light the rail too.", get = get, set = set })
			get, set = sw("swingShotWindow")
			page:Toggle({ label = "Red end on ranged", desc = "The last half second of a shot, where moving holds it.", get = get, set = set })
		end },

		{ key = "cast", label = "Cast", build = function(page)
			local function cs(name)
				return function() return AB.db[name] end, function(v)
					AB.db[name] = v
					AB:LayoutCast()
					AB:CastBlizzard()
				end
			end
			page:Text("Your cast bar is one of the block's rails (the top one by default): it lights from the left as you cast, a channel empties, an interrupted cast flashes red. The spell and the time left show outside the block.")
			page:Section("Cast bar")
			local get, set = cs("castShow")
			page:Toggle({ label = "Show the cast bar", get = get, set = set })
			get, set = cs("castPlace")
			page:Dropdown({
				label = "Where",
				desc = "On one of the block's rails: that rail lights up and the text sits outside the block (keep the swing and the cast on different rails). A bar of its own: a separate rail you can place and size.",
				values = function() return { { value = "top", text = "The block's top rail" }, { value = "bottom", text = "The block's bottom rail" }, { value = "bar", text = "A bar of its own" } } end,
				get = get, set = set,
			})
			get, set = cs("castHideBlizzard")
			page:Toggle({ label = "Hide the game's cast bar", get = get, set = set })
			page:Section("Text")
			get, set = cs("castNameShow")
			page:Toggle({ label = "Spell name", get = get, set = set })
			get, set = cs("castNameSize")
			page:Slider({ label = "Spell name size", min = 8, max = 24, step = 1, get = get, set = set })
			get, set = cs("castTimeShow")
			page:Toggle({ label = "Time left", get = get, set = set })
			get, set = cs("castTimeSize")
			page:Slider({ label = "Time size", min = 8, max = 24, step = 1, get = get, set = set })
			get, set = cs("castTextY")
			page:Slider({ label = "Gap between the rail and the text", min = -30, max = 30, step = 1, get = get, set = set })
			page:Section("Look")
			get, set = cs("castDim")
			page:Slider({ label = "Unlit rail brightness", min = 0, max = 0.8, step = 0.05, format = pct, get = get, set = set })
			get, set = cs("castSpark")
			page:Toggle({ label = "Spark at the edge", get = get, set = set })
			page:Section("A bar of its own")
			get, set = cs("castDock")
			page:Toggle({ label = "On top of the block", desc = "Follows the block; you can still drag it in edit mode.", get = get, set = set })
			get, set = cs("castGap")
			page:Slider({ label = "Gap above the block", min = -10, max = 80, step = 1, get = get, set = set })
			get, set = cs("castMatch")
			page:Toggle({ label = "As long as the block", get = get, set = set })
			get, set = cs("castWidth")
			page:Slider({ label = "Length", min = 100, max = 1200, step = 10, get = get, set = set })
			get, set = cs("castHeight")
			page:Slider({ label = "Thickness", min = 6, max = 40, step = 1, get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:FontSection(AB, apply)
		end },
	},
})
