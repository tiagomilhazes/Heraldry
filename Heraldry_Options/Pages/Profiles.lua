--[[
	Heraldry_Options - Pages/Profiles.lua
]]

local H = Heraldry
local UI = H.UI
local P = H.Profiles

-- Profile list for dropdowns, with how many other characters use each one.
local function names(exclude)
	local t = {}
	for _, n in ipairs(P:List()) do
		if n ~= exclude then
			local others = P:UsedBy(n)
			t[#t + 1] = {
				value = n,
				text = others > 0 and ("%s  |cff888888(%d other)|r"):format(n, others) or n,
			}
		end
	end
	return t
end

local function feedback(ok, msg, success)
	if ok then H:Print(success) else H:Error(msg) end
end

H:RegisterOptionsPage({
	key = "profiles",
	label = "Profiles",
	desc = "Profiles hold positions, sizes and options. Characters can share a profile.",
	group = "core",
	order = 2,
	tabs = {
		{ key = "active", label = "Active profile", build = function(page)
			page:Section("Active profile")
			page:Dropdown({
				label = "Profile in use",
				desc = "Switching applies right away.",
				values = function() return names() end,
				get = function() return P:GetActive() end,
				set = function(v)
					local ok, r = P:Use(v)
					feedback(ok, r, ok and ("Active profile: '%s'."):format(r))
				end,
			})
			page:Input({
				label = "New profile",
				desc = "Creates an empty profile and switches to it.",
				placeholder = "Profile name",
				button = "Create",
				onSubmit = function(text)
					local ok, r = P:Create(text)
					if not ok then
						H:Error(r)
						return false
					end
					local used, err = P:Use(r)
					feedback(used, err, ("Created profile '%s'."):format(r))
					return true
				end,
			})
			page:Input({
				label = "Rename",
				desc = "New name for the active profile.",
				placeholder = "New name",
				button = "Rename",
				onSubmit = function(text)
					local ok, r = P:Rename(P:GetActive(), text)
					feedback(ok, r, ok and ("Renamed to '%s'."):format(r))
					return ok
				end,
			})
		end },
		{ key = "manage", label = "Manage", build = function(page)
			page:Section("Manage")
			page:Dropdown({
				label = "Copy settings from",
				desc = "Replaces the active profile's settings.",
				placeholder = "Choose a profile",
				values = function() return names(P:GetActive()) end,
				set = function(v)
					UI.Confirm(("Replace all settings of '%s'\nwith the settings of '%s'?"):format(P:GetActive(), v), "Copy", function()
						local ok, r = P:CopyFrom(v)
						feedback(ok, r, ok and ("Copied '%s' into '%s'."):format(r, P:GetActive()))
						page:Refresh()
					end)
				end,
			})
			page:Button({
				label = "Reset active profile",
				desc = "Puts every setting back to its default.",
				text = "Reset",
				kind = "danger",
				onClick = function()
					UI.Confirm(("Reset the profile '%s'?\nThis can't be undone."):format(P:GetActive()), "Reset", function()
						local ok, r = P:Reset()
						feedback(ok, r, ok and ("Profile '%s' reset."):format(r))
						page:Refresh()
					end)
				end,
			})
			page:Dropdown({
				label = "Delete a profile",
				desc = "The active profile can't be deleted.",
				placeholder = "Choose a profile",
				values = function() return names(P:GetActive()) end,
				set = function(v)
					UI.Confirm(("Delete the profile '%s'?\nThis can't be undone."):format(v), "Delete", function()
						local ok, r = P:Delete(v)
						feedback(ok, r, ok and ("Deleted profile '%s'."):format(r))
						page:Refresh()
					end)
				end,
			})

			-- Only on clients with specializations (WoW Forever has none).
			if P:CurrentSpec() and GetNumSpecializations then
				page:Section("Specializations")
				page:Toggle({
					label = "Switch profile by specialization",
					desc = "Uses the profile chosen below for each spec.",
					get = function() return H.char.useSpecProfiles end,
					set = function(v) P:SetSpecProfilesEnabled(v) end,
				})
				for spec = 1, GetNumSpecializations() do
					page:Dropdown({
						label = P:SpecName(spec),
						values = function()
							local t = names()
							table.insert(t, 1, { value = false, text = "|cff888888None|r" })
							return t
						end,
						get = function() return H.char.specProfiles[spec] or false end,
						set = function(v)
							local ok, r = P:SetSpecProfile(spec, v or nil)
							if not ok then H:Error(r) end
						end,
					})
				end
			end
		end },
	},
})
