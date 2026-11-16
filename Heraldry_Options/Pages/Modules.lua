--[[
	Heraldry_Options - Pages/Modules.lua
	Turns module addons on or off. Changes apply after a reload.
]]

local H = Heraldry
local M = H.Modules

local PENDING = "|cff" .. H.color .. "%s|r"

H:RegisterOptionsPage({
	key = "modules",
	label = "Modules",
	desc = "Turn modules on or off. Changes apply after a reload.",
	group = "core",
	order = 4,
	build = function(page)
		local catalog = M:Catalog()
		if #catalog == 0 then
			page:Text("No Heraldry modules are installed.")
			return
		end
		page:Section("Installed modules")
		for _, m in ipairs(catalog) do
			page:Toggle({
				label = m.label,
				desc = function()
					local on = M:IsAddonEnabled(m.addon)
					if on and not m.loaded then return PENDING:format("Turns on after a reload.") end
					if not on and m.loaded then return PENDING:format("Turns off after a reload.") end
					return m.desc or ""
				end,
				get = function() return M:IsAddonEnabled(m.addon) end,
				set = function(v) M:SetAddonEnabled(m.addon, v) end,
			})
		end
	end,
})
