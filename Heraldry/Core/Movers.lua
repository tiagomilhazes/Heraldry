--[[
	Heraldry - Core/Movers.lua
	Every frame a module puts on screen is registered as a mover. Its position
	and scale live in the active profile (profile.layout[key]).

	H:RegisterMover(frame, "Test.square", {
		label    = "Test square",
		default  = { "TOP", 0, -140 },   -- point, x, y (screen units); the frame's
		                                 -- point is anchored to the same point of the screen
		scalable = true,                 -- mouse wheel changes its scale in edit mode;
		                                 -- false: the module sets the frame's scale itself
		isShown  = function() end,       -- optional: false hides its box in edit mode
	})
	H.Movers:Reset(key)   H.Movers:ResetAll()

	Docking: a module can pin one mover to another (bar 2 on top of bar 1,
	the orbs at the ends of the block). A docked frame follows its target,
	ignores its own saved position and has no box in edit mode. Docking is
	decided by the module from its own settings, so it is not saved here.
	H.Movers:Dock(key, targetKey, point, relPoint, x, y)   (x, y in screen units)
	H.Movers:Undock(key)

	A saved position is { point, x, y, scale }. The point is picked from the
	part of the screen the frame sits in (a frame near the top right corner is
	anchored TOPRIGHT), so positions survive resolution and UI scale changes.
	Positions are applied out of combat only (frames may be protected).
]]

local _, ns = ...
local H = ns.H

local Movers = { list = {}, byKey = {} }
H.Movers = Movers

local function round(v)
	return math.floor(v + 0.5)
end

-- Frame scale relative to the screen (UIParent).
local function ratio(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Saved position, or the default.
function Movers:Get(m)
	local pos = H.profile.layout[m.key]
	if pos then return pos[1], pos[2], pos[3], pos[4] or 1 end
	local d = m.default
	return d[1], d[2], d[3], d[4] or 1
end

function Movers:Apply(m)
	H:RunOutOfCombat(function()
		local p, x, y, s = self:Get(m)
		local f = m.frame
		-- Not scalable: the module owns the frame's scale (e.g. button size).
		if m.scalable then f:SetScale(s) end
		local r = ratio(f)
		f:ClearAllPoints()
		local d = m.dock
		local target = d and self.byKey[d.target]
		if target then
			f:SetPoint(d.point, target.frame, d.relPoint, d.x / r, d.y / r)
		else
			f:SetPoint(p, UIParent, p, x / r, y / r)
		end
	end, "mover:" .. m.key)
end

function Movers:Dock(key, targetKey, point, relPoint, x, y)
	local m = self.byKey[key]
	if not m or not self.byKey[targetKey] then return end
	m.dock = { target = targetKey, point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
	self:Apply(m)
end

function Movers:Undock(key)
	local m = self.byKey[key]
	if not m or not m.dock then return end
	m.dock = nil
	self:Apply(m)
end

-- Whether a mover gets a box in edit mode.
function Movers:IsMovable(m)
	return not m.dock and (not m.isShown or m.isShown())
end

function Movers:ApplyAll()
	for _, m in ipairs(self.list) do self:Apply(m) end
end

-- Anchor for a rectangle given in screen units: point, x, y.
function Movers:AnchorFor(left, bottom, w, h)
	local W, SH = UIParent:GetWidth(), UIParent:GetHeight()
	local cx, cy = left + w / 2, bottom + h / 2
	local hp, x
	if cx < W / 3 then
		hp, x = "LEFT", left
	elseif cx > W * 2 / 3 then
		hp, x = "RIGHT", left + w - W
	else
		hp, x = "", cx - W / 2
	end
	local vp, y
	if cy < SH / 3 then
		vp, y = "BOTTOM", bottom
	elseif cy > SH * 2 / 3 then
		vp, y = "TOP", bottom + h - SH
	else
		vp, y = "", cy - SH / 2
	end
	local p = vp .. hp
	if p == "" then p = "CENTER" end
	return p, round(x), round(y)
end

-- Saves a position from a rectangle in screen units and applies it.
function Movers:SaveRect(m, left, bottom, w, h, scale)
	local p, x, y = self:AnchorFor(left, bottom, w, h)
	H.profile.layout[m.key] = { p, x, y, scale }
	self:Apply(m)
end

function Movers:SetScale(m, scale)
	local p, x, y = self:Get(m)
	H.profile.layout[m.key] = { p, x, y, scale }
	self:Apply(m)
end

function Movers:Reset(key)
	local m = self.byKey[key]
	if not m then return end
	H.profile.layout[key] = nil
	self:Apply(m)
end

function Movers:ResetAll()
	wipe(H.profile.layout)
	self:ApplyAll()
end

-- Frame rectangle in screen units, or nil when it has no size yet.
function Movers:RectOf(m)
	local f = m.frame
	local l, b, w, h = f:GetRect()
	if not l then return nil end
	local r = ratio(f)
	return l * r, b * r, w * r, h * r
end

function H:RegisterMover(frame, key, opts)
	assert(frame and type(key) == "string" and not Movers.byKey[key], "RegisterMover: missing frame or duplicate key")
	opts = opts or {}
	local m = {
		frame = frame,
		key = key,
		label = opts.label or key,
		default = opts.default or { "CENTER", 0, 0 },
		scalable = opts.scalable ~= false,
		isShown = opts.isShown,
	}
	Movers.list[#Movers.list + 1] = m
	Movers.byKey[key] = m
	Movers:Apply(m)
	H:Fire("MOVER_ADDED", m)
	return m
end

H:On("PROFILE_CHANGED", function() Movers:ApplyAll() end)
