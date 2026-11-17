--[[
	Heraldry_Minimap - Settings.lua
	Minimap page. Tabs: Size | Text | Addons | Behaviour | Font.
]]

local H = Heraldry
local MM = H.Modules.byName.Minimap

local function field(name)
	return function() return MM.db[name] end, function(v)
		MM.db[name] = v
		MM:Layout()
	end
end

local selectedText = "zone"

H:RegisterOptionsPage({
	key = "minimap",
	label = "Minimap",
	desc = "The minimap in the heraldic frame. Its parts keep their place at any size.",
	group = "modules",
	order = 40,
	tabs = {
		{ key = "size", label = "Size", build = function(page)
			page:Section("Size")
			local get, set = field("size")
			page:Slider({ label = "Size", desc = "Width of the whole frame. The mouse wheel in edit mode scales it too.", min = 140, max = 420, step = 2, get = get, set = set })
		end },

		{ key = "text", label = "Text", build = function(page)
			page:Dropdown({
				label = "Text",
				desc = "Every option below applies to this text. Both sit on the plate under the map.",
				values = function()
					local t = {}
					for _, it in ipairs(MM.TEXTS) do t[#t + 1] = { value = it.key, text = it.label } end
					return t
				end,
				get = function() return selectedText end,
				set = function(v) selectedText = v end,
			})
			local function sel(suffix)
				return function() return MM.db[selectedText .. suffix] end, function(v)
					MM.db[selectedText .. suffix] = v
					MM:Layout()
				end
			end
			page:Section("Look")
			local get, set = sel("Show")
			page:Toggle({ label = "Show", get = get, set = set })
			get, set = sel("Size")
			page:Slider({ label = "Size", min = 6, max = 24, step = 1, get = get, set = set })
			page:Section("Position")
			get, set = sel("X")
			page:Slider({ label = "Offset X", desc = "From the middle of the plate. Right is positive.", min = -150, max = 150, step = 1, get = get, set = set })
			get, set = sel("Y")
			page:Slider({ label = "Offset Y", desc = "Up is positive.", min = -60, max = 60, step = 1, get = get, set = set })
			page:Button({
				label = "Reset this text",
				text = "Reset",
				onClick = function()
					for _, suffix in ipairs({ "Show", "Size", "X", "Y" }) do MM.db[selectedText .. suffix] = nil end
					MM:Layout()
					page:Refresh()
				end,
			})
			page:Section("Clock")
			get, set = field("clock24")
			page:Toggle({ label = "24-hour clock", get = get, set = set })
		end },

		{ key = "addons", label = "Addons", build = function(page)
			page:Section("Addon buttons")
			page:Text("The middle socket shows or hides the addons' minimap buttons, gathered in a panel next to the frame.", 36)
			local get, set = field("addonColumns")
			page:Slider({ label = "Buttons per row", min = 1, max = 10, step = 1, get = get, set = set })
			get, set = field("addonSize")
			page:Slider({ label = "Button size", min = 16, max = 40, step = 1, get = get, set = set })
		end },

		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Behaviour")
			local get, set = field("wheelZoom")
			page:Toggle({ label = "Zoom with the mouse wheel", get = get, set = set })
		end },

		{ key = "font", label = "Font", build = function(page)
			page:FontSection(MM, function() MM:Layout() end)
		end },
	},
})
