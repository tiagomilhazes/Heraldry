--[[
	Heraldry - Core/Events.lua
	Game events and internal messages.

	H:RegisterEvent(event, fn)     fn(event, ...)
	H:UnregisterEvent(event, fn)
	H:On(message, fn)              fn(message, ...)
	H:Off(message, fn)
	H:Fire(message, ...)

	Handlers run in registration order. An error in one handler is reported
	(BugSack picks it up) and does not stop the others.
	Lists are copied on change, so a handler can safely unregister itself.
]]

local _, ns = ...
local H = ns.H

local frame = CreateFrame("Frame")
local events, messages = {}, {}

-- Returns true when this was the first handler for the key.
local function add(map, key, fn)
	local old = map[key]
	if old then
		for i = 1, #old do
			if old[i] == fn then return false end
		end
	end
	local new = {}
	if old then
		for i = 1, #old do new[i] = old[i] end
	end
	new[#new + 1] = fn
	map[key] = new
	return old == nil
end

-- Returns true when no handlers are left for the key.
local function remove(map, key, fn)
	local old = map[key]
	if not old then return false end
	local new = {}
	for i = 1, #old do
		if old[i] ~= fn then new[#new + 1] = old[i] end
	end
	map[key] = #new > 0 and new or nil
	return map[key] == nil
end

local function dispatch(list, ...)
	local handler = geterrorhandler()
	for i = 1, #list do
		xpcall(list[i], handler, ...)
	end
end

function H:RegisterEvent(event, fn)
	if add(events, event, fn) then
		-- Some events may not exist in the Forever client: don't break on them.
		if not pcall(frame.RegisterEvent, frame, event) then
			remove(events, event, fn)
			self:Debug("Event not available in this client:", event)
			return false
		end
	end
	return true
end

function H:UnregisterEvent(event, fn)
	if remove(events, event, fn) then
		frame:UnregisterEvent(event)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = events[event]
	if list then dispatch(list, event, ...) end
end)

function H:On(message, fn)
	add(messages, message, fn)
end

function H:Off(message, fn)
	remove(messages, message, fn)
end

function H:Fire(message, ...)
	self:Debug("Message:", message, ...)
	local list = messages[message]
	if list then dispatch(list, message, ...) end
end
