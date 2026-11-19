--[[
	Heraldry - Core/Database.lua
	SavedVariables, migrations and the character entry.

	HeraldryDB = {
		version   = 1,
		global    = { debug, editMode, options, minimapGrab },   -- account-wide
		profiles  = { ["Default"] = <profile> },
		overrides = { [CLASS] = { ["*"] = {...}, [spec] = {...} } },   -- reserved for C3, unused
		chars     = { ["Name-Realm"] = { profile, theme, finish, formThemes, auraSockets,
		                                 indicators, clickcast, raidRolled, chat history,
		                                 useSpecProfiles, specProfiles } },
	}
	<profile> = { modules = {}, layout = {}, preset = "altar", fonts (made on first use) }

	H.sv      the whole HeraldryDB
	H.global  HeraldryDB.global
	H.char    this character's entry
	H.profile the active profile table

	Boot: ADDON_LOADED -> DB_LOADED message, PLAYER_LOGIN -> READY message.
]]

local ADDON, ns = ...
local H = ns.H

local DB_VERSION = 1
H.DEFAULT_PROFILE = "Default"

-- Deep copy of plain data (no cycles, no frames).
function H.CopyTable(src)
	if type(src) ~= "table" then return src end
	local t = {}
	for k, v in pairs(src) do t[k] = H.CopyTable(v) end
	return t
end

function H.NewProfileData()
	return { modules = {}, layout = {}, preset = "altar" }
end

-- [n] = function(sv) end: upgrades a database from version n-1 to n.
local migrations = {}

local function initDB()
	local sv = HeraldryDB
	if type(sv) ~= "table" then
		sv = {}
		HeraldryDB = sv
	end

	sv.version = sv.version or DB_VERSION
	if sv.version > DB_VERSION then
		H:Error(("Saved settings come from a newer version (db %d, this is %d). Some options may be lost."):format(sv.version, DB_VERSION))
	end
	for v = sv.version + 1, DB_VERSION do
		if migrations[v] then migrations[v](sv) end
		sv.version = v
	end

	sv.global = sv.global or {}
	sv.profiles = sv.profiles or {}
	sv.overrides = sv.overrides or {}
	sv.chars = sv.chars or {}
	if not next(sv.profiles) then
		sv.profiles[H.DEFAULT_PROFILE] = H.NewProfileData()
	end

	H.sv, H.global = sv, sv.global
end

local function initChar()
	local sv = H.sv
	local key = UnitName("player") .. "-" .. (GetRealmName() or "?")
	local c = sv.chars[key]
	if not c then
		c = {}
		sv.chars[key] = c
	end

	c.theme = c.theme or "auto"
	c.specProfiles = c.specProfiles or {}
	if c.useSpecProfiles == nil then c.useSpecProfiles = false end

	-- The profile may have been deleted or renamed on another character.
	if not (c.profile and sv.profiles[c.profile]) then
		c.profile = sv.profiles[H.DEFAULT_PROFILE] and H.DEFAULT_PROFILE or next(sv.profiles)
	end
	for spec, name in pairs(c.specProfiles) do
		if not sv.profiles[name] then c.specProfiles[spec] = nil end
	end

	H.charKey, H.char = key, c
	H.profile = sv.profiles[c.profile]
end

local function onAddonLoaded(event, name)
	if name ~= ADDON then return end
	H:UnregisterEvent(event, onAddonLoaded)
	initDB()
	H:Fire("DB_LOADED")
end

local function onLogin(event)
	H:UnregisterEvent(event, onLogin)
	initChar()
	H.Profiles:ApplySpec()
	H.ready = true
	H:Fire("READY")
	H:Print(("v%s loaded. Type |cffffffff/hui|r for settings, |cffffffff/hui help|r for commands."):format(H.version))
end

H:RegisterEvent("ADDON_LOADED", onAddonLoaded)
H:RegisterEvent("PLAYER_LOGIN", onLogin)
