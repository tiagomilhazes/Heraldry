--[[
	Heraldry - Core/Modules.lua
	Module system.

	A module is its own addon (Heraldry_<Name>) with, in its .toc:
		## Dependencies: Heraldry
		## X-Heraldry-Module: 1
		## X-Heraldry-Label: Action bars

	In its code:
		local Bars = Heraldry:NewModule("ActionBars", { defaults = { size = 36 } })
		function Bars:OnInitialize() end      -- profile ready, no frames yet
		function Bars:OnEnable() end          -- build frames (never in combat)
		function Bars:OnProfileChanged() end  -- re-read self.db and re-apply
		Bars.db.size                          -- active profile value, or the default
		Bars.db.size = 40                     -- saved in the active profile
		Bars:ResetSettings()

	Settings are flat (strings, numbers, booleans). A value equal to its
	default is not stored, so changing a default later reaches every profile.

	On or off is decided only by the game's addon list: the Modules page just
	turns the module's addon on or off for the next reload.
]]

local _, ns = ...
local H = ns.H

local M = { list = {}, byName = {} }
H.Modules = M

local Module = {}
Module.__index = Module

local function settingsOf(mod, create)
	local all = H.profile.modules
	local t = all[mod.name]
	if not t and create then
		t = {}
		all[mod.name] = t
	end
	return t
end

local function makeDB(mod)
	return setmetatable({}, {
		__index = function(_, k)
			local t = settingsOf(mod)
			local v = t and t[k]
			if v == nil then v = mod.defaults[k] end
			return v
		end,
		__newindex = function(_, k, v)
			if v == mod.defaults[k] then v = nil end
			local t = settingsOf(mod, v ~= nil)
			if t then t[k] = v end
		end,
	})
end

-- Runs mod[method] if it exists. Returns false only when it raised an error.
local function call(mod, method, ...)
	local fn = mod[method]
	if not fn then return true end
	return xpcall(fn, geterrorhandler(), mod, ...)
end

function M:Start(mod)
	if mod.started then return end
	mod.started = true
	call(mod, "OnInitialize")
	H:RunOutOfCombat(function()
		if call(mod, "OnEnable") then
			mod.enabled = true
			H:Debug("Module enabled:", mod.name)
		end
	end, "enable:" .. mod.name)
end

function H:NewModule(name, opts)
	assert(type(name) == "string" and not M.byName[name], "NewModule: missing or duplicate name")
	opts = opts or {}
	-- fonts = true: the module can override the core's font and outline.
	if opts.fonts then
		opts.defaults = opts.defaults or {}
		opts.defaults.fontOverride = false
		opts.defaults.font = false          -- false: the core's font
		opts.defaults.fontOutline = false   -- false: the core's outline
	end
	local mod = setmetatable({
		name = name,
		label = opts.label or name,
		defaults = opts.defaults or {},
	}, Module)
	mod.db = makeDB(mod)
	M.byName[name] = mod
	M.list[#M.list + 1] = mod
	-- Loaded after login (load on demand): start once its files have run.
	if H.ready then
		C_Timer.After(0, function() M:Start(mod) end)
	end
	return mod
end

function Module:ResetSettings()
	H.profile.modules[self.name] = nil
	if self.enabled then call(self, "OnProfileChanged") end
end

H:On("READY", function()
	for _, mod in ipairs(M.list) do M:Start(mod) end
end)

H:On("PROFILE_CHANGED", function()
	for _, mod in ipairs(M.list) do
		if mod.enabled then call(mod, "OnProfileChanged") end
	end
end)

--[[ Installed modules, loaded or not ]]

-- Enable state: 0 off, 1 on for some characters, 2 on for all.
-- Read without a character: on WoW Forever the per-character read always
-- answers 2, whatever the real state is.
local function stateOf(addon)
	return C_AddOns.GetAddOnEnableState(addon) or 0
end

function M:IsAddonEnabled(addon)
	return stateOf(addon) > 0
end

-- Turns a module addon on or off for every character (applies after a reload).
function M:SetAddonEnabled(addon, on)
	local before = stateOf(addon)
	if on then
		C_AddOns.EnableAddOn(addon)
	else
		C_AddOns.DisableAddOn(addon)
	end
	local after = stateOf(addon)
	H:Debug(("Module %s -> %s. State %s -> %s"):format(addon, on and "on" or "off", tostring(before), tostring(after)))
	if (after > 0) ~= on then
		H:Error(("Couldn't turn %s %s. Use the AddOns list in the game menu."):format(addon, on and "on" or "off"))
	end
end

-- { addon, label, desc, loaded } for every addon that declares X-Heraldry-Module.
function M:Catalog()
	local t = {}
	for i = 1, C_AddOns.GetNumAddOns() do
		local addon, _, notes = C_AddOns.GetAddOnInfo(i)
		if C_AddOns.GetAddOnMetadata(addon, "X-Heraldry-Module") then
			t[#t + 1] = {
				addon = addon,
				label = C_AddOns.GetAddOnMetadata(addon, "X-Heraldry-Label") or addon,
				desc = notes,
				loaded = C_AddOns.IsAddOnLoaded(addon),
			}
		end
	end
	table.sort(t, function(a, b) return a.label < b.label end)
	return t
end
