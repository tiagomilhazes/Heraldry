--[[
	Heraldry_UnitFrames - Settings.lua
	One page for the whole module, "Unit frames". One tab per frame (Target,
	Target of target, Focus; party and raid later), each with its own row of
	tabs for the settings, plus a Font tab (the module's font, for every frame).
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames

local function field(name)
	return function() return UF.db[name] end, function(v)
		UF.db[name] = v
		UF:Layout()
	end
end

local function smallField(prefix, name)
	return function() return UF.db[prefix .. name] end, function(v)
		UF.db[prefix .. name] = v
		local s = UF.small[prefix]
		if s and s.frame then s:Layout() end
	end
end

local selectedText = "name"
local function pctFormat(v) return math.floor(v * 100 + 0.5) .. "%" end

--[[ Target ]]

local target = {
	size = function(page)
			page:Section("Size")
			local get, set = field("width")
			page:Slider({ label = "Width", min = 140, max = 420, step = 2, get = get, set = set })
			get, set = field("healthHeight")
			page:Slider({ label = "Life bar height", min = 8, max = 40, step = 1, get = get, set = set })
			get, set = field("showPower")
			page:Toggle({ label = "Show the power bar", get = get, set = set })
			get, set = field("powerHeight")
			page:Slider({ label = "Power bar height", min = 3, max = 20, step = 1, get = get, set = set })
	end,
	text = function(page)
			page:Dropdown({
				label = "Text",
				desc = "Every option below applies to this text.",
				values = function()
					local t = {}
					for _, it in ipairs(UF.TEXTS) do t[#t + 1] = { value = it.key, text = it.label } end
					return t
				end,
				get = function() return selectedText end,
				set = function(v) selectedText = v end,
			})
			local function sel(suffix)
				return function() return UF.db[selectedText .. suffix] end, function(v)
					UF.db[selectedText .. suffix] = v
					UF:Layout()
				end
			end
			page:Section("Look")
			local get, set = sel("Show")
			page:Toggle({ label = "Show", get = get, set = set })
			get, set = sel("Size")
			page:Slider({ label = "Size", min = 6, max = 30, step = 1, get = get, set = set })
			page:Section("Position")
			get, set = sel("X")
			page:Slider({ label = "Offset X", desc = "Right is positive.", min = -100, max = 100, step = 1, get = get, set = set })
			get, set = sel("Y")
			page:Slider({ label = "Offset Y", desc = "Up is positive.", min = -50, max = 50, step = 1, get = get, set = set })
			page:Button({
				label = "Reset this text",
				text = "Reset",
				onClick = function()
					for _, suffix in ipairs({ "Show", "Size", "X", "Y" }) do UF.db[selectedText .. suffix] = nil end
					UF:Layout()
					page:Refresh()
				end,
			})
	end,
	look = function(page)
			page:Section("Style")
			local get, set = field("style")
			page:Dropdown({
				label = "Style",
				desc = "Plaque: a heraldic plaque whose metal and jewels show what the target is. Minimal: a dark glass panel. The plaque's size follows the bar heights (Size tab).",
				values = function()
					return { { value = "plaque", text = "Plaque" }, { value = "minimal", text = "Minimal" } }
				end,
				get = function() return UF:Style() end, set = set,
			})
			page:Section("Colours")
			get, set = field("classColor")
			page:Toggle({ label = "Class colour for players", desc = "Off: players use the reaction colour, like NPCs.", get = get, set = set })
			page:Section("Minimal")
			get, set = field("showGem")
			page:Toggle({ label = "Show the gem", desc = "The level, and a halo for elite, rare and boss units.", get = get, set = set })
			get, set = field("gemSize")
			page:Slider({ label = "Gem size", min = 20, max = 60, step = 1, get = get, set = set })
			get, set = field("panelAlpha")
			page:Slider({ label = "Panel opacity", min = 0, max = 1, step = 0.05, format = pctFormat, get = get, set = set })
	end,
	behaviour = function(page)
			page:Section("Behaviour")
			local get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's target frame", get = get, set = set })
			page:Section("Casts")
			get, set = field("castInPower")
			page:Toggle({ label = "Show casts in the power row", desc = "While the target casts, its power bar turns into the cast bar. Needs the power bar (Size tab).", get = get, set = set })
	end,
}

--[[ Target of target and focus (Small.lua) ]]

local function small(prefix, extra)
	return {
		size = function(page)
			page:Section("Size")
			local get, set = smallField(prefix, "Width")
			page:Slider({ label = "Width", min = 80, max = 320, step = 2, get = get, set = set })
			get, set = smallField(prefix, "HealthHeight")
			page:Slider({ label = "Life bar height", min = 6, max = 30, step = 1, get = get, set = set })
			if extra.power then
				get, set = smallField(prefix, "ShowPower")
				page:Toggle({ label = "Show the power bar", get = get, set = set })
				get, set = smallField(prefix, "PowerHeight")
				page:Slider({ label = "Power bar height", min = 3, max = 16, step = 1, get = get, set = set })
			end
		end,
		text = function(page)
			page:Section("Text")
			local get, set = smallField(prefix, "NameSize")
			page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
			get, set = smallField(prefix, "PctSize")
			page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
		end,
		behaviour = function(page)
			page:Section("Behaviour")
			local get, set = smallField(prefix, "Show")
			page:Toggle({ label = "Show this frame", desc = "Takes effect after /reload.", get = get, set = set })
			if extra.dock then
				get, set = smallField(prefix, "Dock")
				page:Toggle({ label = "Attach to the target", desc = "It follows the target; you can still drag it in edit mode. Off: on its own.", get = get, set = set })
			end
			if extra.blizzard then
				get, set = smallField(prefix, "HideBlizzard")
				page:Toggle({ label = "Hide the game's focus frame", get = get, set = set })
			end
		end,
	}
end

--[[ Party (Party.lua) ]]

local function pf(name)
	return function() return UF.db["party" .. name] end, function(v)
		UF.db["party" .. name] = v
		UF:LayoutParty()
	end
end

local party = {
	size = function(page)
		page:Section("Each member")
		local get, set = pf("Width")
		page:Slider({ label = "Width", min = 80, max = 320, step = 2, get = get, set = set })
		get, set = pf("HealthHeight")
		page:Slider({ label = "Life bar height", min = 6, max = 40, step = 1, get = get, set = set })
		get, set = pf("ShowPower")
		page:Toggle({ label = "Show the power bar", get = get, set = set })
		get, set = pf("PowerHeight")
		page:Slider({ label = "Power bar height", min = 2, max = 16, step = 1, get = get, set = set })
		page:Section("Layout")
		get, set = pf("Direction")
		page:Dropdown({
			label = "Grow",
			values = function() return {
				{ value = "down", text = "Down (a column)" },
				{ value = "up", text = "Up (a column)" },
				{ value = "right", text = "Right (a row)" },
				{ value = "left", text = "Left (a row)" },
			} end,
			get = get, set = set,
		})
		get, set = pf("Spacing")
		page:Slider({ label = "Space between members (plaque)", desc = "From one life bar to the next; the medallions interlock below about 40.", min = 0, max = 80, step = 1, get = get, set = set })
		get, set = pf("CompactSpacing")
		page:Slider({ label = "Space between members (compact)", min = 0, max = 30, step = 1, get = get, set = set })
	end,
	text = function(page)
		page:Section("Text")
		local get, set = pf("NameSize")
		page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
		get, set = pf("PctSize")
		page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
	end,
	look = function(page)
		page:Section("Style")
		local get, set = pf("Style")
		page:Dropdown({
			label = "Style",
			desc = "Plaque: the target of target's plaque. Compact: slim rows with a class jewel.",
			values = function() return { { value = "plaque", text = "Plaque" }, { value = "compact", text = "Compact" } } end,
			get = get, set = set,
		})
		get, set = pf("LowLife")
		page:Slider({ label = "Low life (compact)", desc = "The rim turns red below this.", min = 0.1, max = 0.6, step = 0.05,
			format = pctFormat, get = get, set = set })
		get, set = pf("Emblems")
		page:Toggle({ label = "Class emblems in the medallions", desc = "Plaque style. The game's class icons for now; our own emblems will replace them.", get = get, set = set })
		get, set = pf("Leader")
		page:Toggle({ label = "Crown on the group leader", get = get, set = set })
		page:Text("Colours follow the target's rules: theme metal, jewel in the class colour, and the target's class colour option for the life bar.", 36)
	end,
	behaviour = function(page)
		page:Section("Who shows")
		local get, set = pf("Show")
		page:Toggle({ label = "Show the party frames", desc = "Takes effect after /reload.", get = get, set = set })
		get, set = pf("Player")
		page:Toggle({ label = "Show yourself in the party", desc = "Takes effect after /reload.", get = get, set = set })
		get, set = pf("InRaid")
		page:Toggle({ label = "Show in a raid", get = get, set = set })
		page:Section("Range")
		get, set = pf("Range")
		page:Toggle({ label = "Fade members out of range", get = get, set = set })
		get, set = pf("RangeAlpha")
		page:Slider({ label = "Faded to", min = 0.1, max = 0.9, step = 0.05, format = pctFormat, get = get, set = set })
		page:Section("Game frames")
		get, set = pf("HideBlizzard")
		page:Toggle({ label = "Hide the game's party frames", get = get, set = set })
		page:Section("Preview")
		page:Toggle({
			label = "Preview with made-up members",
			desc = "Also in General > Testing.",
			get = function() return UF.party.preview end,
			set = function(v) UF:SetPartyPreview(v) end,
		})
	end,
}

local tot = small("tot", { dock = true })
local focus = small("focus", { power = true, blizzard = true })

H:RegisterOptionsPage({
	key = "unitframes",
	label = "Unit frames",
	desc = "Target, target of target, focus and party.",
	group = "modules",
	order = 30,
	tabs = {
		{ key = "target", label = "Target", tabs = {
			{ key = "size", label = "Size", build = target.size },
			{ key = "text", label = "Text", build = target.text },
			{ key = "look", label = "Look", build = target.look },
			{ key = "behaviour", label = "Behaviour", build = target.behaviour },
		} },
		{ key = "tot", label = "Target of target", tabs = {
			{ key = "size", label = "Size", build = tot.size },
			{ key = "text", label = "Text", build = tot.text },
			{ key = "behaviour", label = "Behaviour", build = tot.behaviour },
		} },
		{ key = "focus", label = "Focus", tabs = {
			{ key = "size", label = "Size", build = focus.size },
			{ key = "text", label = "Text", build = focus.text },
			{ key = "behaviour", label = "Behaviour", build = focus.behaviour },
		} },
		{ key = "party", label = "Party", tabs = {
			{ key = "size", label = "Size", build = party.size },
			{ key = "text", label = "Text", build = party.text },
			{ key = "look", label = "Look", build = party.look },
			{ key = "behaviour", label = "Behaviour", build = party.behaviour },
		} },
		{ key = "font", label = "Font", build = function(page)
			page:Text("The font is the module's: it applies to every unit frame.", 20)
			page:FontSection(UF, function() UF:Layout() end)
		end },
	},
})
