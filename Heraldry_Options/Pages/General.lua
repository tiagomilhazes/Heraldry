--[[
	Heraldry_Options - Pages/General.lua
]]

local H = Heraldry

H:RegisterOptionsPage({
	key = "general",
	label = "General",
	desc = "Core settings and testing tools.",
	group = "core",
	order = 1,
	tabs = {
		{ key = "character", label = "Character", build = function(page)
			page:Section("Character")
			page:Text(function()
				return ("Character: |cffffffff%s|r\nProfile: |cffffffff%s|r\nTheme: |cffffffff%s|r"):format(
					H.charKey, H.char.profile, H.char.theme)
			end, 54)
		end },
		{ key = "panel", label = "Panel", build = function(page)
			page:Section("Panel")
			page:Slider({
				label = "Panel scale",
				desc = "Size of this window. Applied when you let go of the slider.",
				min = 0.7, max = 1.3, step = 0.05,
				format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
				get = function() return H.global.options.scale or 1 end,
				set = function(v) H.global.options.scale = v end,
				onRelease = function(v) H.Panel:SetScale(v) end,
			})
		end },
		{ key = "testing", label = "Testing", build = function(page)
			page:Section("Testing")
			page:Toggle({
				label = "Debug messages",
				desc = "Print internal messages to chat.",
				get = function() return H.global.debug end,
				set = function(v) H.global.debug = v end,
			})
			page:Section("Interface")
			page:Button({
				label = "Reload interface",
				desc = "Needed after turning modules on or off.",
				text = "Reload",
				onClick = ReloadUI,
			})
		end },
	},
})
