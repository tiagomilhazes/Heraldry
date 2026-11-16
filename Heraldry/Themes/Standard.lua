--[[
	Heraldry - Themes/Standard.lua
	The neutral theme, used when a class has no theme and for any piece a
	theme lacks. No class art: a dark plate, no rails, no crests, and buttons
	fall back to the simple 1px border.
]]

Heraldry:RegisterTheme("STANDARD", {
	label = "Standard",
	pieces = {
		["bar.plate"] = { color = { 0.04, 0.04, 0.04, 0.55 } },
		["block.plate"] = { color = { 0.04, 0.04, 0.04, 0.55 } },
	},
})
