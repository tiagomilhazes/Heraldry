--[[
	Heraldry_Options - Pages/Theme.lua
	Picks the art set for this character.
]]

local H = Heraldry
local Themes = H.Themes

H:RegisterOptionsPage({
	key = "theme",
	label = "Theme",
	desc = "The art used by every module. Saved per character, not in the profile.",
	group = "core",
	order = 3,
	build = function(page)
		page:Section("Theme")
		page:Dropdown({
			label = "Theme",
			desc = "Automatic uses your class's theme, or Standard if it has none yet.",
			values = function()
				local _, class = UnitClass("player")
				local t = { { value = "auto", text = ("Automatic (%s)"):format(Themes.byKey[Themes:ActiveKey()] and H.char.theme == "auto" and Themes:Active().label or "your class") } }
				for _, theme in ipairs(Themes.list) do
					t[#t + 1] = { value = theme.key, text = theme.label .. (theme.class == class and "  |cff888888(your class)|r" or "") }
				end
				return t
			end,
			get = function() return H.char.theme end,
			set = function(v) Themes:Set(v) end,
		})
		page:Text(function()
			return ("Active now: |cffffffff%s|r"):format(Themes:Active().label)
		end, 20)
		page:Dropdown({
			label = "Finish",
			desc = "Tones the art so it sits in the game. Per character.",
			values = function()
				local def = Themes:Active().finish or "none"
				local t = { { value = false, text = ("Theme default (%s)"):format(Themes.FINISHES[def].label) } }
				for _, k in ipairs(Themes.FINISH_ORDER) do
					t[#t + 1] = { value = k, text = Themes.FINISHES[k].label }
				end
				return t
			end,
			get = function() return H.char.finish or false end,
			set = function(v) Themes:SetFinish(v or nil) end,
		})
	end,
})
