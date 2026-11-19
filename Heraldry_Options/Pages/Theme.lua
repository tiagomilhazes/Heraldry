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
	tabs = {
		{ key = "theme", label = "Theme", build = function(page)
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
		end },
		{ key = "forms", label = "Forms", build = function(page)
			page:Section("Theme by form", "While you are in a form (Shadowform, a druid form, a warrior stance), its theme replaces the one above. A change in combat shows when combat ends.")
			local forms = Themes:Forms()
			if #forms == 0 then
				page:Text("Your character has no forms yet.", 20)
				return
			end
			for _, form in ipairs(forms) do
				page:Dropdown({
					label = form.name,
					values = function()
						local t = { { value = false, text = "Same as the theme above" } }
						for _, theme in ipairs(Themes.list) do t[#t + 1] = { value = theme.key, text = theme.label } end
						return t
					end,
					get = function() local m = Themes:FormThemes() return m and m[form.id] or false end,
					set = function(v) Themes:SetFormTheme(form.id, v or nil) end,
				})
			end
		end },
		{ key = "finish", label = "Finish", build = function(page)
			page:Section("Finish")
			page:Dropdown({
				label = "Finish",
				desc = "Tones the art so it sits in the game. Per character.",
				values = function()
					local def = Themes:Field(Themes:Active(), "finish") or "none"   -- variants take it from their base
					local t = { { value = false, text = ("Theme default (%s)"):format(Themes.FINISHES[def].label) } }
					for _, k in ipairs(Themes.FINISH_ORDER) do
						t[#t + 1] = { value = k, text = Themes.FINISHES[k].label }
					end
					return t
				end,
				get = function() return H.char.finish or false end,
				set = function(v) Themes:SetFinish(v or nil) end,
			})
		end },
	},
})
