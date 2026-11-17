--[[
	Heraldry - Themes/Standard.lua
	The neutral theme, used when a class has no theme and for any piece a
	theme lacks. No class art: a dark plate, no rails, no crests, and buttons
	fall back to the simple 1px border. Scrolls get a plain wooden rod.
]]

local S = Heraldry.Themes.MEDIA .. "Standard\\"

Heraldry:RegisterTheme("STANDARD", {
	label = "Standard",
	pieces = {
		["bar.plate"] = { color = { 0.04, 0.04, 0.04, 0.55 } },
		["block.plate"] = { color = { 0.04, 0.04, 0.04, 0.55 } },
		-- plain wood and gold rod (TimelessUI Chat/Scroll_Rod*)
		["scroll.rod"] = { cap = S .. "RodCap", capR = S .. "RodCapR", mid = S .. "RodMid", size = { 256, 128 }, capW = 234, shaft = 0.5 },
	},
})
