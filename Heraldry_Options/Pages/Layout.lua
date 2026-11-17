--[[
	Heraldry_Options - Pages/Layout.lua
	Edit mode and positions.
]]

local H = Heraldry
local UI = H.UI

local function editSettings()
	H.global.editMode = H.global.editMode or { grid = true, gridSize = 32 }
	return H.global.editMode
end

H:RegisterOptionsPage({
	key = "layout",
	label = "Layout",
	desc = "Move and scale everything on screen. Positions are saved in the active profile.",
	group = "core",
	order = 5,
	tabs = {
		{ key = "editmode", label = "Edit mode", build = function(page)
			page:Section("Edit mode")
			page:Button({
				label = "Open edit mode",
				desc = "Also with /hui edit. Not available in combat.",
				text = "Edit mode",
				onClick = function()
					H.Panel:Hide()
					H:SetEditMode(true)
				end,
			})
			page:Toggle({
				label = "Show grid",
				desc = "Lines to line things up while in edit mode.",
				get = function() return editSettings().grid end,
				set = function(v)
					editSettings().grid = v
					H:RefreshGrid()
				end,
			})
			page:Slider({
				label = "Grid size",
				desc = "Space between grid lines.",
				min = 16, max = 64, step = 4,
				get = function() return editSettings().gridSize end,
				set = function(v)
					editSettings().gridSize = v
					H:RefreshGrid()
				end,
			})
		end },
		{ key = "positions", label = "Positions", build = function(page)
			page:Section("Centre horizontally")
			local any = false
			for _, m in ipairs(H.Movers.list) do
				if not m.dock then
					any = true
					page:Button({
						label = m.label,
						desc = "Middle of the screen, at the same height.",
						text = "Centre",
						onClick = function()
							H.Movers:CenterX(m.key)
							if H.editMode then H:RefreshEditMode() end
							H:Print(m.label .. ": centred.")
						end,
					})
				end
			end
			if not any then page:Text("No frame to centre yet.") end
			page:Section("Positions")
			page:Button({
				label = "Reset all positions",
				desc = "Every frame back to its default place, in the active profile.",
				text = "Reset",
				kind = "danger",
				onClick = function()
					UI.Confirm(("Put every frame back to its default place\nin the profile '%s'?"):format(H.char.profile), "Reset", function()
						H.Movers:ResetAll()
						H:Print("All positions reset.")
					end)
				end,
			})
		end },
	},
})
