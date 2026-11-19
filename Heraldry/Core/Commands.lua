--[[
	Heraldry - Core/Commands.lua
	Slash commands: /hui and /heraldry.
]]

local _, ns = ...
local H = ns.H
local P = H.Profiles

local W = "|cffffffff"
local G = "|cff888888"

local function report(ok, msg, success)
	if ok then
		if success then H:Print(success) end
	else
		H:Error(msg)
	end
end

local function split(s)
	local first, rest = (s or ""):match("^%s*(%S*)%s*(.-)%s*$")
	return (first or ""):lower(), rest or ""
end

local function help()
	H:Print("commands:")
	print(W .. "/hui|r " .. G .. "- open or close the settings|r")
	print(W .. "/hui edit|r " .. G .. "- move things around (edit mode)|r")
	print(W .. "/hui status|r " .. G .. "- version, character, profile|r")
	print(W .. "/hui debug|r " .. G .. "- toggle debug messages|r")
	print(W .. "/hui profile list|r")
	print(W .. "/hui profile new <name>|r")
	print(W .. "/hui profile use <name>|r")
	print(W .. "/hui profile copy <name>|r " .. G .. "- copy <name>'s settings into the active profile|r")
	print(W .. "/hui profile rename <new name>|r " .. G .. "- rename the active profile|r")
	print(W .. "/hui profile delete <name>|r")
	print(W .. "/hui profile reset|r " .. G .. "- reset the active profile|r")
	-- commands added by modules: only when the module is loaded
	local cmds = H.commands or {}
	if cmds.grab then print(W .. "/hui grab|r " .. G .. "- put the button under the mouse into the minimap's addon panel|r") end
	if cmds.copy then print(W .. "/hui copy|r " .. G .. "- the chat's last lines in a box you can copy from|r") end
	print(W .. "/hui spec|r " .. G .. "- show profiles per spec|r")
	print(W .. "/hui spec on/off|r")
	print(W .. "/hui spec <number> <profile>|r " .. G .. "(or 'none')|r")
end

local function status()
	local c = H.char
	H:Print("v" .. H.version)
	print(G .. "Character:|r " .. H.charKey)
	print(G .. "Profile:|r " .. c.profile)
	print(G .. "Theme:|r " .. c.theme)
	local spec = P:CurrentSpec()
	print(G .. "Spec:|r " .. (spec and (spec .. " - " .. P:SpecName(spec)) or "none (not available)"))
	print(G .. "Profiles per spec:|r " .. (c.useSpecProfiles and "on" or "off"))
	print(G .. "Debug:|r " .. (H.global.debug and "on" or "off"))
end

local function profileCmd(rest)
	local sub, arg = split(rest)

	if sub == "" or sub == "list" then
		local active = P:GetActive()
		H:Print("profiles:")
		for _, n in ipairs(P:List()) do
			local others = P:UsedBy(n)
			print((n == active and "|cff00ff00> " or "  ") .. n .. "|r"
				.. (others > 0 and (G .. "  (" .. others .. " other character(s))|r") or ""))
		end
	elseif sub == "new" then
		local ok, r = P:Create(arg)
		report(ok, r, ok and ("Created profile '%s'. Use it with " .. W .. "/hui profile use %s|r"):format(r, r))
	elseif sub == "use" then
		local ok, r = P:Use(arg)
		report(ok, r, ok and ("Active profile: '%s'."):format(r))
	elseif sub == "copy" then
		local ok, r = P:CopyFrom(arg)
		report(ok, r, ok and ("Copied '%s' into '%s'."):format(r, P:GetActive()))
	elseif sub == "rename" then
		local ok, r = P:Rename(P:GetActive(), arg)
		report(ok, r, ok and ("Active profile renamed to '%s'."):format(r))
	elseif sub == "delete" then
		local ok, r = P:Delete(arg)
		report(ok, r, ok and ("Deleted profile '%s'."):format(r))
	elseif sub == "reset" then
		local ok, r = P:Reset()
		report(ok, r, ok and ("Profile '%s' reset."):format(r))
	else
		H:Error("Unknown profile command: " .. sub)
		help()
	end
end

local function specCmd(rest)
	local first, arg = split(rest)
	local c = H.char

	if first == "" then
		H:Print("profiles per spec are " .. (c.useSpecProfiles and "on" or "off") .. ":")
		local any = false
		for spec = 1, 4 do
			if c.specProfiles[spec] then
				any = true
				print("  " .. spec .. " - " .. P:SpecName(spec) .. ": " .. c.specProfiles[spec])
			end
		end
		if not any then print(G .. "  none set|r") end
	elseif first == "on" or first == "off" then
		P:SetSpecProfilesEnabled(first == "on")
		H:Print("Profiles per spec: " .. first)
	else
		local name = arg
		if name:lower() == "none" then name = nil end
		local ok, r = P:SetSpecProfile(first, name)
		report(ok, r, ok and (r and ("Spec %s uses '%s'."):format(first, r) or ("Spec %s cleared."):format(first)))
	end
end

SLASH_HERALDRY1 = "/hui"
SLASH_HERALDRY2 = "/heraldry"
SlashCmdList.HERALDRY = function(msg)
	if not H.ready then
		H:Error("Not ready yet.")
		return
	end
	local cmd, rest = split(msg)
	if cmd == "" or cmd == "config" or cmd == "options" then
		H:ToggleOptions()
	elseif cmd == "help" then
		help()
	elseif cmd == "edit" or cmd == "move" then
		if H.Panel then H.Panel:Hide() end
		H:ToggleEditMode()
	elseif cmd == "status" or cmd == "version" then
		status()
	elseif cmd == "debug" then
		H.global.debug = not H.global.debug
		H:Print("Debug " .. (H.global.debug and "on" or "off"))
	elseif cmd == "profile" or cmd == "profiles" then
		profileCmd(rest)
	elseif cmd == "spec" then
		specCmd(rest)
	elseif H.commands and H.commands[cmd] then
		H.commands[cmd](rest)   -- added by modules
	else
		H:Error("Unknown command: " .. cmd)
		help()
	end
end
