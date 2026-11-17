--[[
	Heraldry_UnitFrames - Cast.lua
	The target's casts, inside the target frame: while the target casts or
	channels, the power row becomes the cast bar (spell name on the left, time
	left on the right). When the cast ends, the power bar comes back.

	  gold   interruptible
	  grey   not interruptible
	  red    interrupted or failed (shown for a moment)

	Secret values: in combat the game may hide the cast's times from Lua. The
	bar is then driven by the game's own timer (StatusBar:SetTimerDuration with
	UnitCastingDuration / UnitChannelDuration) when the client has them;
	otherwise by GetTime() maths in pcall. The time text is best effort: it
	stays empty if neither way can read the time. Whether a cast can be
	interrupted also comes from the INTERRUPTIBLE / NOT_INTERRUPTIBLE events,
	which carry no secret.
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames
local UNIT = "target"
local FLAT = "Interface\\Buttons\\WHITE8X8"

local COLOR = {
	open   = { 0.91, 0.69, 0.29 },
	locked = { 0.50, 0.50, 0.53 },
	failed = { 0.85, 0.18, 0.12 },
}
local HOLD = 0.5   -- seconds an interrupted / failed cast stays on screen

local DIR = Enum and Enum.StatusBarTimerDirection
local INTERP = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate

function UF:CreateCast()
	local f = self.frame
	local c = CreateFrame("StatusBar", nil, f)
	c:SetStatusBarTexture(FLAT)
	c:SetMinMaxValues(0, 1)
	c:Hide()
	c.bg = c:CreateTexture(nil, "BACKGROUND")
	c.bg:SetAllPoints()
	c.bg:SetColorTexture(0.05, 0.04, 0.03, 0.9)
	c.spark = c:CreateTexture(nil, "OVERLAY")
	c.spark:SetTexture(FLAT)
	c.spark:SetVertexColor(1, 0.97, 0.85, 0.9)
	c.spark:SetWidth(2)
	c.spark:SetPoint("TOP", c:GetStatusBarTexture(), "TOPRIGHT")
	c.spark:SetPoint("BOTTOM", c:GetStatusBarTexture(), "BOTTOMRIGHT")
	local parent = f.textFrame or f
	c.name = parent:CreateFontString(nil, "OVERLAY")
	c.name:SetJustifyH("LEFT")
	c.name:SetWordWrap(false)
	c.time = parent:CreateFontString(nil, "OVERLAY")
	for _, fs in ipairs({ c.name, c.time }) do
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
		fs:Hide()
	end
	f.cast = c
end

-- Same place as the power bar; texts on the text layer, above the plaque.
function UF:LayoutCast(inset)
	local f, db = self.frame, self.db
	local c = f.cast
	c:ClearAllPoints()
	c:SetAllPoints(f.power)
	c:SetFrameLevel(f.power:GetFrameLevel())
	H.Fonts:Apply(c.name, "body", db.castNameSize, self)
	H.Fonts:Apply(c.time, "body", db.castTimeSize, self)
	c.name:ClearAllPoints()
	c.name:SetPoint("LEFT", c, "LEFT", 8 + db.castNameX, db.castNameY)
	c.name:SetPoint("RIGHT", c, "RIGHT", inset - db.castTimeSize * 2.6 - 6, db.castNameY)
	c.time:ClearAllPoints()
	c.time:SetPoint("RIGHT", c, "RIGHT", inset + db.castTimeX, db.castTimeY)
	self:CheckCast()
end

-- What the target is casting: name, start and end (ms), not interruptible, channel.
local function castInfo()
	local name, _, _, s, e, _, _, locked = UnitCastingInfo(UNIT)
	if name then return name, s, e, locked, false end
	local cname, _, _, cs, ce, _, clocked = UnitChannelInfo(UNIT)
	if cname then return cname, cs, ce, clocked, true end
end

local function setShown(on)
	local f, db = UF.frame, UF.db
	local c = f.cast
	c:SetShown(on)
	c.name:SetShown(on and db.castNameShow)
	c.time:SetShown(on and db.castTimeShow)
	-- the power row comes back when the cast is gone
	f.power:SetShown(db.showPower and not on)
	f.power.text:SetShown(db.powerShow and db.showPower and not on)
end

function UF:SetCastColor(key)
	local col = COLOR[key]
	self.frame.cast:SetStatusBarColor(col[1], col[2], col[3])
end

-- The time text: maths in pcall, then the game's duration object.
local function updateTime(c)
	local ok = pcall(function()
		local left = (c.endMS - GetTime() * 1000) / 1000
		if left < 0 then left = 0 end
		c.time:SetFormattedText("%.1f", left)
	end)
	if ok then return end
	if c.duration and c.duration.GetRemainingDuration then
		ok = pcall(function() c.time:SetFormattedText("%.1f", c.duration:GetRemainingDuration()) end)
	end
	if not ok then c.time:SetText("") end
end

local function onUpdate(c)
	if c.holdUntil then
		if GetTime() >= c.holdUntil then
			c.holdUntil = nil
			UF:CheckCast()
		end
		return
	end
	if not c.timer then
		-- no game timer: drive the bar ourselves
		local ok = pcall(function()
			local now = GetTime() * 1000
			local v = (now - c.startMS) / (c.endMS - c.startMS)
			if c.channel then v = 1 - v end
			c:SetValue(v)
		end)
		if not ok then c:SetValue(c.channel and 1 or 0) end
	end
	updateTime(c)
end

-- Start, refresh or stop the cast bar from the target's current cast.
function UF:CheckCast()
	local f, db = self.frame, self.db
	if not f or not f.cast then return end
	local c = f.cast
	if c.holdUntil then return end
	if not db.castInPower or not db.showPower or not UnitExists(UNIT) then
		setShown(false)
		c:SetScript("OnUpdate", nil)
		return
	end
	local name, s, e, locked, channel = castInfo()
	if not name then
		setShown(false)
		c:SetScript("OnUpdate", nil)
		return
	end
	c.startMS, c.endMS, c.channel = s, e, channel
	pcall(c.name.SetText, c.name, name)

	-- the game's own timer, when this client has it
	c.timer, c.duration = false, nil
	if c.ClearTimerDuration then pcall(c.ClearTimerDuration, c) end
	c:SetMinMaxValues(0, 1)
	local get = channel and UnitChannelDuration or UnitCastingDuration
	if get and c.SetTimerDuration then
		local ok, d = pcall(get, UNIT)
		if ok and d then
			local dir = DIR and (channel and DIR.RemainingTime or DIR.ElapsedTime)
			c.timer = pcall(c.SetTimerDuration, c, d, INTERP, dir)
			c.duration = d
		end
	end

	local ok, isLocked = pcall(function() return locked and true or false end)
	self:SetCastColor((ok and isLocked) and "locked" or "open")
	setShown(true)
	c:SetScript("OnUpdate", onUpdate)
	onUpdate(c)
end

-- Interrupted or failed: red, full, for a moment.
function UF:CastFailed(text)
	local c = self.frame.cast
	if not c:IsShown() then return end
	self:SetCastColor("failed")
	if c.ClearTimerDuration then pcall(c.ClearTimerDuration, c) end
	c:SetMinMaxValues(0, 1)
	c:SetValue(1)
	c.timer = true   -- keep onUpdate off the bar
	c.name:SetText(text)
	c.time:SetText("")
	c.holdUntil = GetTime() + HOLD
end

function UF:EnableCast()
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
		pcall(ev.RegisterUnitEvent, ev, e, UNIT)
	end
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:SetScript("OnEvent", function(_, e)
		local c = UF.frame and UF.frame.cast
		if not c then return end
		if e == "PLAYER_TARGET_CHANGED" then
			c.holdUntil = nil
			UF:CheckCast()
		elseif e == "UNIT_SPELLCAST_INTERRUPTED" then
			UF:CastFailed(INTERRUPTED or "Interrupted")
		elseif e == "UNIT_SPELLCAST_FAILED" then
			UF:CastFailed(FAILED or "Failed")
		elseif e == "UNIT_SPELLCAST_INTERRUPTIBLE" then
			UF:SetCastColor("open")
		elseif e == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
			UF:SetCastColor("locked")
		else
			UF:CheckCast()
		end
	end)
end
