--[[
	Heraldry - Core/Options.lua
	Registry of settings pages. The panel itself lives in the Heraldry_Options
	addon, which only loads the first time the panel is opened.

	H:RegisterOptionsPage({
		key   = "profiles",
		label = "Profiles",
		desc  = "Shown under the page title.",
		group = "core" | "modules",
		order = 10,
		build = function(page) ... end,   -- runs once, the first time the page is shown
	})
	H:OpenOptions([key])  H:ToggleOptions()
]]

local _, ns = ...
local H = ns.H

local O = { pages = {} }
H.Options = O

local OPTIONS_ADDON = "Heraldry_Options"

function H:RegisterOptionsPage(def)
	assert(type(def) == "table" and def.key and def.label and def.build, "RegisterOptionsPage: key, label and build are required")
	O.pages[def.key] = def
end

local function loadPanel()
	if H.Panel then return true end
	local loaded, reason = C_AddOns.LoadAddOn(OPTIONS_ADDON)
	if not loaded or not H.Panel then
		H:Error(("Couldn't open the settings: %s is %s."):format(OPTIONS_ADDON, tostring(reason or "missing"):lower()))
		return false
	end
	return true
end

function H:OpenOptions(key)
	if not self.ready then return end
	if loadPanel() then H.Panel:Show(key) end
end

function H:ToggleOptions()
	if H.Panel and H.Panel:IsShown() then
		H.Panel:Hide()
	else
		self:OpenOptions()
	end
end

-- Keep an open panel in sync with changes made elsewhere (slash commands, spec swap).
H:On("PROFILE_CHANGED", function()
	if H.Panel and H.Panel:IsShown() then H.Panel:Refresh() end
end)

-- Addon compartment (the addons button by the minimap).
function Heraldry_OnCompartmentClick()
	H:ToggleOptions()
end
