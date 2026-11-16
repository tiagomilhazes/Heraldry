--[[
	Heraldry - Core/Init.lua
	Namespace, version, chat output and debug output.
	Everything else hangs off the H table (also global as Heraldry).
]]

local ADDON, ns = ...

local H = {}
ns.H = H
_G.Heraldry = H

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

H.name = ADDON
H.version = GetMeta(ADDON, "Version") or "dev"
H.color = "E8B04B"

local PREFIX = "|cff" .. H.color .. "Heraldry|r: "
local DEBUG_PREFIX = "|cff" .. H.color .. "Heraldry|r |cff888888[debug]|r "

local function join(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

function H:Print(...)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. join(...))
end

function H:Error(...)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffff5555" .. join(...) .. "|r")
end

-- Only prints when debug mode is on (/hui debug).
function H:Debug(...)
	if self.global and self.global.debug then
		DEFAULT_CHAT_FRAME:AddMessage(DEBUG_PREFIX .. join(...))
	end
end
