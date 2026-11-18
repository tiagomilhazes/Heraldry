--[[
	Heraldry_ActionBars - Cast.lua
	The player's cast bar as one of the block's rails (top by default; the swing takes the other).
	While you cast, the rail dims and lights from the left; a channel starts
	lit and empties. Interrupted or failed: the rail flashes red. The spell's
	name and the time left sit under the block, in small text.

	"A bar of its own" puts the same rail on a separate holder with a mover.
	The game's cast bar goes to a hidden parent (option).
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars
local RL = AB.RailLight

local DEFAULTS = {
	castShow = true,
	castPlace = "top",         -- "top" / "bottom": that rail of the block lights up; "bar": a bar of its own
	castDock = true,           -- the separate bar sits on top of the block
	castGap = 24,
	castMatch = true,
	castWidth = 520,
	castHeight = 14,
	castDim = 0.3,
	castSpark = true,
	castNameShow = true,
	castNameSize = 12,
	castTimeShow = true,
	castTimeSize = 11,
	castTextY = 3,             -- gap between the rail and the text
	castHideBlizzard = true,
}
for k, v in pairs(DEFAULTS) do AB.defaults[k] = v end

local hidden = CreateFrame("Frame")
hidden:Hide()

local function plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

-- the cast under way: name, start, finish (seconds), channel, guid;
-- failed: the time it was interrupted or failed, and the word to show
local cast, failed = nil, nil
local preview = false
local f

local function build()
	if f then return f end
	f = RL.New("HeraldryCastBar", "ActionBars.cast", "Cast bar", { "BOTTOM", 0, 180 },
		function() return AB.db.castShow and AB.db.castPlace == "bar" end)
	f.name = f:CreateFontString(nil, "OVERLAY")
	f.time = f:CreateFontString(nil, "OVERLAY")
	for _, fs in ipairs({ f.name, f.time }) do
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	end
	return f
end

function AB:LayoutCast()
	if not AB.bars[1] then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() AB:LayoutCast() end, "actionbars-cast")
		return
	end
	local db = self.db
	build()
	f:SetShown(db.castShow)
	if not db.castShow then return end

	local onRail = RL.Layout(f, {
		rail = RL.BlockRail(db.castPlace),
		flip = db.castPlace == "bottom",
		width = db.castMatch and RL.BlockWidth() or db.castWidth,
		height = db.castHeight,
		dim = db.castDim,
	})

	-- texts: outside the block (above the top rail, under the bottom rail or the bar)
	H.Fonts:Apply(f.name, "body", db.castNameSize, self)
	H.Fonts:Apply(f.time, "body", db.castTimeSize, self)
	f.name:ClearAllPoints()
	f.time:ClearAllPoints()
	if onRail and db.castPlace == "top" then
		f.name:SetPoint("BOTTOM", f, "TOP", 0, db.castTextY)
		f.time:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -f.h, db.castTextY)
	else
		f.name:SetPoint("TOP", f, "BOTTOM", 0, -db.castTextY)
		f.time:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -f.h, -db.castTextY)
	end

	local key = self:IsJoined() and "ActionBars.bar2" or "ActionBars.bar1"
	if not onRail and db.castDock and H.Movers.byKey[key] then
		local y = self:Get(1, "padY") + (self:Get(1, "rails") and self:Get(1, "railSize") / 2 or 0) + db.castGap
		H.Movers:Dock("ActionBars.cast", key, "BOTTOM", "TOP", 0, y, true)
	else
		H.Movers:Undock("ActionBars.cast")
	end
	H.Movers:Apply(f.mover)
	self:PaintCast()
end

local FADE = 0.6

function AB:PaintCast()
	if not f or not f.W then return end
	local db = self.db
	local now = GetTime()
	local W = f.W

	if cast and now >= cast.finish then cast = nil end   -- STOP may come a moment later
	if cast then
		local p = (now - cast.start) / (cast.finish - cast.start)
		p = math.max(0, math.min(1, p))
		local lit = cast.channel and (1 - p) or p
		RL.Light(f, f.left, W * lit, false)
		RL.Light(f, f.right, 0, true)
		RL.Spark(f, f.sparkL, W * lit, db.castSpark)
		RL.Spark(f, f.sparkR, 0, false)
		RL.Warn(f, false)
		f.name:SetText(db.castNameShow and cast.name or "")
		f.time:SetText(db.castTimeShow and ("%.1f"):format(math.max(0, cast.finish - now)) or "")
		f.name:SetTextColor(1, 0.92, 0.75)
		f.time:SetTextColor(0.85, 0.8, 0.7)
		f:SetAlpha(1)
		return true
	end

	-- interrupted or failed: the whole rail in red, fading out
	if failed then
		local a = 1 - (now - failed.time) / FADE
		if a > 0 then
			RL.Light(f, f.left, W, false)
			RL.Light(f, f.right, 0, true)
			RL.Spark(f, f.sparkL, 0, false)
			RL.Warn(f, nil, 1)
			f.name:SetText(db.castNameShow and failed.word or "")
			f.name:SetTextColor(1, 0.35, 0.3)
			f.time:SetText("")
			f:SetAlpha(a)
			return true
		end
		failed = nil
	end

	RL.Spark(f, f.sparkL, 0, false)
	RL.Warn(f, false)
	f:SetAlpha(0)
	return false
end

local function onUpdate()
	if not AB:PaintCast() then f:SetScript("OnUpdate", nil) end
end

local function wake()
	if f and AB.db.castShow then f:SetScript("OnUpdate", onUpdate) end
end

--[[ Reading the cast ]]

local function readCast(channel, guid)
	local name, startMS, endMS, castGUID, _
	if channel then
		name, _, _, startMS, endMS = UnitChannelInfo("player")
	else
		name, _, _, startMS, endMS, _, castGUID = UnitCastingInfo("player")
	end
	if not (plain(name) and plain(startMS) and plain(endMS)) or not name then
		cast = nil
		return
	end
	cast = {
		name = name,
		start = startMS / 1000,
		finish = endMS / 1000,
		channel = channel,
		guid = guid or castGUID,
	}
	failed = nil
	wake()
end

local function mine(unit) return unit == "player" end

H:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit, guid) if mine(unit) then readCast(false, guid) end end)
H:RegisterEvent("UNIT_SPELLCAST_DELAYED", function(_, unit) if mine(unit) and cast and not cast.channel then readCast(false, cast.guid) end end)
H:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit) if mine(unit) then readCast(true) end end)
H:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", function(_, unit) if mine(unit) then readCast(true) end end)
H:RegisterEvent("UNIT_SPELLCAST_STOP", function(_, unit, guid)
	if mine(unit) and cast and not cast.channel and (not plain(guid) or not cast.guid or guid == cast.guid) then
		cast = nil
		wake()
	end
end)
H:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit)
	if mine(unit) and cast and cast.channel then
		cast = nil
		wake()
	end
end)
-- FAILED also comes when you press another spell mid-cast: only the cast's own counts
local function stopped(word)
	return function(_, unit, guid)
		if not mine(unit) or not cast then return end
		if plain(guid) and cast.guid and guid ~= cast.guid then return end
		cast = nil
		failed = { time = GetTime(), word = word }
		wake()
	end
end
H:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", stopped("Interrupted"))
H:RegisterEvent("UNIT_SPELLCAST_FAILED", stopped("Failed"))

--[[ The game's cast bar ]]

local moved = {}
function AB:CastBlizzard()
	local hide = self.db.castHideBlizzard
	for _, name in ipairs({ "PlayerCastingBarFrame", "CastingBarFrame" }) do
		local fr = _G[name]
		if fr then
			if hide and not moved[fr] then
				moved[fr] = fr:GetParent()
				pcall(fr.SetParent, fr, hidden)
			elseif not hide and moved[fr] then
				pcall(fr.SetParent, fr, moved[fr])
				moved[fr] = nil
			end
		end
	end
end

H:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	H:RunOutOfCombat(function() AB:CastBlizzard() end, "actionbars-cast-blizz")
end)

hooksecurefunc(AB, "LayoutAll", function()
	AB:LayoutCast()
	C_Timer.After(0.1, function() AB:LayoutCast() end)
end)
H:On("FONTS_CHANGED", function() AB:LayoutCast() end)

--[[ Preview: a cast, a channel, an interrupted cast, over and over ]]

local SAMPLES = {
	{ name = "Holy Light", length = 2.5 },
	{ name = "Hand of Healing", length = 3, channel = true },
	{ name = "Flash of Light", length = 1.5, interrupt = 0.9 },
}
local step = 0
local function previewLoop()
	if not preview then return end
	step = step % #SAMPLES + 1
	local s = SAMPLES[step]
	local now = GetTime()
	cast = { name = s.name, start = now, finish = now + s.length, channel = s.channel }
	failed = nil
	wake()
	if s.interrupt then
		C_Timer.After(s.interrupt, function()
			if not preview then return end
			cast = nil
			failed = { time = GetTime(), word = "Interrupted" }
			wake()
		end)
	end
	C_Timer.After((s.interrupt or s.length) + 1, previewLoop)
end

H.previews = H.previews or {}
H.previews[#H.previews + 1] = {
	label = "Cast bar",
	desc = "Made-up casts (a cast, a channel, an interrupted cast) on your cast bar.",
	get = function() return preview end,
	set = function(v)
		preview = v
		if v then previewLoop() else
			cast, failed = nil, nil
			wake()
		end
	end,
}
