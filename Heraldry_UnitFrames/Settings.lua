--[[
	Heraldry_UnitFrames - Settings.lua
	Target page. Tabs: Size | Text | Look | Behaviour | Font.
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames

local function field(name)
	return function() return UF.db[name] end, function(v)
		UF.db[name] = v
		UF:Layout()
	end
end

local selectedText = "name"

local function pctFormat(v) return math.floor(v * 100 + 0.5) .. "%" end

H:RegisterOptionsPage({
	key = "target",
	label = "Target",
	desc = "The target frame. Select yourself to see it while you set it up.",
	group = "modules",
	order = 30,
	tabs = {
		{ key = "size", label = "Size", build = function(page)
			page:Section("Size")
			local get, set = field("width")
			page:Slider({ label = "Width", min = 140, max = 420, step = 2, get = get, set = set })
			get, set = field("healthHeight")
			page:Slider({ label = "Life bar height", min = 8, max = 40, step = 1, get = get, set = set })
			get, set = field("showPower")
			page:Toggle({ label = "Show the power bar", get = get, set = set })
			get, set = field("powerHeight")
			page:Slider({ label = "Power bar height", min = 3, max = 20, step = 1, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
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
		end },

		{ key = "look", label = "Look", build = function(page)
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
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Behaviour")
			local get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's target frame", get = get, set = set })
			page:Section("Casts")
			get, set = field("castInPower")
			page:Toggle({ label = "Show casts in the power row", desc = "While the target casts, its power bar turns into the cast bar. Needs the power bar (Size tab).", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:FontSection(UF, function() UF:Layout() end)
		end },
	},
})

--[[ Target of target and focus (Small.lua) ]]

local function smallField(prefix, name)
	return function() return UF.db[prefix .. name] end, function(v)
		UF.db[prefix .. name] = v
		local s = UF.small[prefix]
		if s and s.frame then s:Layout() end
	end
end

local function smallPage(prefix, key, label, order, extra)
	H:RegisterOptionsPage({
		key = key,
		label = label,
		desc = "A smaller plaque, with the same metal and jewel colours as the target.",
		group = "modules",
		order = order,
		tabs = {
			{ key = "size", label = "Size", build = function(page)
				page:Section("Size")
				local get, set = smallField(prefix, "Width")
				page:Slider({ label = "Width", min = 80, max = 320, step = 2, get = get, set = set })
				get, set = smallField(prefix, "HealthHeight")
				page:Slider({ label = "Life bar height", min = 6, max = 30, step = 1, get = get, set = set })
				if extra and extra.power then
					get, set = smallField(prefix, "ShowPower")
					page:Toggle({ label = "Show the power bar", get = get, set = set })
					get, set = smallField(prefix, "PowerHeight")
					page:Slider({ label = "Power bar height", min = 3, max = 16, step = 1, get = get, set = set })
				end
			end },
			{ key = "text", label = "Text", build = function(page)
				page:Section("Text")
				local get, set = smallField(prefix, "NameSize")
				page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
				get, set = smallField(prefix, "PctSize")
				page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
			end },
			{ key = "behaviour", label = "Behaviour", build = function(page)
				page:Section("Behaviour")
				local get, set = smallField(prefix, "Show")
				page:Toggle({ label = "Show this frame", desc = "Takes effect after /reload.", get = get, set = set })
				if extra and extra.dock then
					get, set = smallField(prefix, "Dock")
					page:Toggle({ label = "Attach to the target", desc = "Off: move it on its own in edit mode.", get = get, set = set })
				end
				if extra and extra.blizzard then
					get, set = smallField(prefix, "HideBlizzard")
					page:Toggle({ label = "Hide the game's focus frame", get = get, set = set })
				end
			end },
		},
	})
end

smallPage("tot", "targettarget", "Target of target", 31, { dock = true })
smallPage("focus", "focus", "Focus", 32, { power = true, blizzard = true })
