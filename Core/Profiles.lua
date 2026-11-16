--[[
	Heraldry - Core/Profiles.lua
	Profile management. Every function that can fail returns ok, message.

	Profile names are unique ignoring case and are matched ignoring case.
	Changing the active profile fires PROFILE_CHANGED (name).
	The active profile table is changed in place on copy/reset, so
	H.profile stays the same table.
]]

local _, ns = ...
local H = ns.H

local P = {}
H.Profiles = P

local MAX_NAME = 32

local function clean(name)
	if type(name) ~= "string" then return nil, "Profile name can't be empty." end
	name = strtrim(name)
	if name == "" then return nil, "Profile name can't be empty." end
	if #name > MAX_NAME then
		return nil, ("Profile name can't be longer than %d characters."):format(MAX_NAME)
	end
	return name
end

local function combatBlock()
	if InCombatLockdown() then return "Profiles can't be changed in combat." end
end

local function fill(dst, src)
	wipe(dst)
	for k, v in pairs(H.CopyTable(src)) do dst[k] = v end
end

local function activate(name, reason)
	H.char.profile = name
	H.profile = H.sv.profiles[name]
	H:Debug("Active profile:", name, reason and ("(" .. reason .. ")") or "")
	H:Fire("PROFILE_CHANGED", name)
end

-- Existing profile name for a name typed in any case, or nil.
function P:Resolve(name)
	if type(name) ~= "string" then return nil end
	name = strtrim(name)
	if H.sv.profiles[name] then return name end
	local lower = name:lower()
	for n in pairs(H.sv.profiles) do
		if n:lower() == lower then return n end
	end
end

function P:List()
	local t = {}
	for n in pairs(H.sv.profiles) do t[#t + 1] = n end
	table.sort(t)
	return t
end

function P:GetActive()
	return H.char.profile
end

-- Characters (other than this one) using a profile.
function P:UsedBy(name)
	local n = 0
	for key, c in pairs(H.sv.chars) do
		if key ~= H.charKey and c.profile == name then n = n + 1 end
	end
	return n
end

function P:Create(name)
	local n, err = clean(name)
	if not n then return false, err end
	if self:Resolve(n) then return false, ("A profile named '%s' already exists."):format(n) end
	H.sv.profiles[n] = H.NewProfileData()
	return true, n
end

function P:Use(name)
	local err = combatBlock()
	if err then return false, err end
	local n = self:Resolve(name)
	if not n then return false, ("No profile named '%s'."):format(tostring(name)) end
	if n ~= H.char.profile then activate(n, "manual") end
	return true, n
end

-- Copies the settings of another profile into the active one.
function P:CopyFrom(name)
	local err = combatBlock()
	if err then return false, err end
	local n = self:Resolve(name)
	if not n then return false, ("No profile named '%s'."):format(tostring(name)) end
	if n == H.char.profile then return false, "Can't copy a profile into itself." end
	fill(H.profile, H.sv.profiles[n])
	H:Fire("PROFILE_CHANGED", H.char.profile)
	return true, n
end

function P:Reset()
	local err = combatBlock()
	if err then return false, err end
	fill(H.profile, H.NewProfileData())
	H:Fire("PROFILE_CHANGED", H.char.profile)
	return true, H.char.profile
end

function P:Rename(oldName, newName)
	local old = self:Resolve(oldName)
	if not old then return false, ("No profile named '%s'."):format(tostring(oldName)) end
	local n, err = clean(newName)
	if not n then return false, err end
	local clash = self:Resolve(n)
	if clash and clash ~= old then return false, ("A profile named '%s' already exists."):format(n) end
	if n == old then return true, n end

	local sv = H.sv
	sv.profiles[n], sv.profiles[old] = sv.profiles[old], nil
	for _, c in pairs(sv.chars) do
		if c.profile == old then c.profile = n end
		if c.specProfiles then
			for spec, p in pairs(c.specProfiles) do
				if p == old then c.specProfiles[spec] = n end
			end
		end
	end
	H:Fire("PROFILE_RENAMED", old, n)
	return true, n
end

function P:Delete(name)
	local n = self:Resolve(name)
	if not n then return false, ("No profile named '%s'."):format(tostring(name)) end
	if n == H.char.profile then return false, "Can't delete the active profile. Switch to another one first." end

	local sv = H.sv
	sv.profiles[n] = nil
	-- Other characters fall back to Default on their next login.
	for _, c in pairs(sv.chars) do
		if c.profile == n then c.profile = nil end
		if c.specProfiles then
			for spec, p in pairs(c.specProfiles) do
				if p == n then c.specProfiles[spec] = nil end
			end
		end
	end
	return true, n
end

--[[ Profiles per specialization ]]

-- Current spec index, or nil when the client has no specializations.
function P:CurrentSpec()
	if GetSpecialization then
		local s = GetSpecialization()
		if s and s > 0 then return s end
	end
end

function P:SpecName(spec)
	if GetSpecializationInfo then
		local _, name = GetSpecializationInfo(spec)
		if name then return name end
	end
	return "Spec " .. spec
end

function P:SetSpecProfilesEnabled(on)
	H.char.useSpecProfiles = on and true or false
	if on then self:ApplySpec() end
end

-- name = nil clears the spec's profile.
function P:SetSpecProfile(spec, name)
	spec = tonumber(spec)
	if not spec or spec < 1 or spec > 4 then return false, "Spec must be a number from 1 to 4." end
	if name == nil then
		H.char.specProfiles[spec] = nil
		return true
	end
	local n = self:Resolve(name)
	if not n then return false, ("No profile named '%s'."):format(tostring(name)) end
	H.char.specProfiles[spec] = n
	if spec == self:CurrentSpec() then self:ApplySpec() end
	return true, n
end

-- Switches to the current spec's profile, when that feature is on.
function P:ApplySpec()
	if not H.char.useSpecProfiles then return end
	local spec = self:CurrentSpec()
	if not spec then return end
	local target = H.char.specProfiles[spec]
	if not (target and H.sv.profiles[target]) or target == H.char.profile then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() P:ApplySpec() end, "specProfile")
		return
	end
	activate(target, "spec " .. spec)
end

H:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
	if unit == "player" and H.ready then P:ApplySpec() end
end)
