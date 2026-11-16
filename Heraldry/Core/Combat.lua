--[[
	Heraldry - Core/Combat.lua
	Work that touches protected frames can't run in combat.

	H:RunOutOfCombat(fn [, key])
		Runs fn now when out of combat (returns true), otherwise queues it
		until combat ends (returns false). Tasks with the same key replace
		each other, so ten layout changes in combat run once afterwards.
]]

local _, ns = ...
local H = ns.H

local queue, keyed = {}, {}

function H:RunOutOfCombat(fn, key)
	if not InCombatLockdown() then
		fn()
		return true
	end
	if key and keyed[key] then
		keyed[key].fn = fn
		return false
	end
	local task = { fn = fn, key = key }
	queue[#queue + 1] = task
	if key then keyed[key] = task end
	self:Debug("Queued until combat ends:", key or "task")
	return false
end

H:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if #queue == 0 then return end
	local list = queue
	queue, keyed = {}, {}
	H:Debug("Combat ended, running", #list, "queued task(s)")
	local handler = geterrorhandler()
	for i = 1, #list do
		xpcall(list[i].fn, handler)
	end
end)
