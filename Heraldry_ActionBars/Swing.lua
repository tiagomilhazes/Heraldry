--[[
	Heraldry_ActionBars - Swing.lua
	The swing timer as the theme's rail (prototype S1): the rail is drawn dim
	and lights up as the swing builds.
	  - one weapon: the main hand lights the rail from the left
	  - dual wield: the main hand lights from the left, the off hand from the
	    right; when both meet in the middle together your hands are in sync
	  - ranged (auto shot, wand): lights from the left; the last stretch is red,
	    the window where moving holds the shot

	Data: the client's own swing timer (PLAYER_SWING(duration, type), WoW
	Forever only); without it the bar is never built. The game's own swing
	bars (Blizzard_SwingTimer) go to a hidden parent.

	The frame is a plain (not secure) child of bar 1, so it hides with the bars
	in vehicles and pet battles; it ignores bar 1's scale and fading. An
	OnUpdate runs only while a swing is building (two texture widths).
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars
local Themes = H.Themes

if not (Enum and Enum.PlayerSwingType) then return end
local SWING = Enum.PlayerSwingType

local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SHOT_WINDOW = 0.5   -- seconds at the end of a ranged swing where moving holds the shot

local DEFAULTS = {
	swingShow = true,
	swingHideIdle = true,      -- fade out when nothing swings
	swingDock = true,          -- sits on top of the block (movable from there)
	swingGap = 2,
	swingMatch = true,         -- as long as the block's rails
	swingWidth = 520,
	swingHeight = 14,
	swingOffHand = true,       -- dual wield: the off hand lights from the right
	swingRanged = true,
	swingShotWindow = true,
	swingSpark = true,
	swingDim = 0.3,            -- brightness of the unlit rail
	swingHideBlizzard = true,
}
for k, v in pairs(DEFAULTS) do AB.defaults[k] = v end

local hidden = CreateFrame("Frame")
hidden:Hide()

-- state per swing type: start, duration
local swings = { [SWING.MainHand] = {}, [SWING.OffHand] = {}, [SWING.Ranged] = {} }
local S = { meleeOn = false, repeatOn = false, lastActive = 0, preview = false }

local function plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function running(s, now)
	return s.start and now < s.start + s.duration
end

-- 0..1 of the swing done, or nil when it is not running
local function progress(s, now)
	if not running(s, now) then return nil end
	return (now - s.start) / s.duration
end

--[[ Frame ]]

local f

local function build()
	if f then return f end
	f = CreateFrame("Frame", "HeraldrySwingBar", AB.bars[1] or UIParent)
	f:SetIgnoreParentScale(true)
	f:SetIgnoreParentAlpha(true)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(20)
	f.dim = f:CreateTexture(nil, "BACKGROUND")
	f.mh = f:CreateTexture(nil, "ARTWORK")
	f.oh = f:CreateTexture(nil, "ARTWORK")
	f.shot = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.shot:SetColorTexture(1, 0.15, 0.1, 0.45)
	f.shot:SetBlendMode("ADD")
	f.sparkL = f:CreateTexture(nil, "OVERLAY")
	f.sparkR = f:CreateTexture(nil, "OVERLAY")
	for _, t in ipairs({ f.sparkL, f.sparkR }) do
		t:SetTexture(SPARK)
		t:SetBlendMode("ADD")
	end
	f:SetAlpha(0)
	f.mover = H:RegisterMover(f, "ActionBars.swing", {
		label = "Swing bar",
		default = { "BOTTOM", 0, 150 },
		scalable = true,
		isShown = function() return AB.db.swingShow end,
	})
	return f
end

-- rail texture coordinates: tiles of the theme's rail, `tileW` pixels long
local function railGeometry()
	local piece = Themes:Piece("bar.rail")
	if not piece then return nil, 1, 0, 1 end   -- a theme without rails (Standard): a plain bar
	local h = AB.db.swingHeight
	local band = piece.band
	return piece, h * piece.size[1] / (band[2] - band[1]), band[1] / piece.size[2], band[2] / piece.size[2]
end

local function paint(t, piece, bright)
	if not piece then
		-- plain bar in the theme's metal (or the brand gold)
		local r, g, b = Themes:Accent()
		if not r then r, g, b = 0.91, 0.69, 0.29 end
		t:SetDesaturation(0)
		t:SetVertexColor(1, 1, 1)
		t:SetColorTexture(r * bright, g * bright, b * bright, 1)
		return
	end
	t:SetTexture(piece.file, "REPEAT", "CLAMP")
	Themes:Paint(t)
	if bright < 1 then
		local r, g, b = t:GetVertexColor()
		t:SetVertexColor(r * bright, g * bright, b * bright)
	end
end

-- width of the block's rails, in UIParent pixels
local function blockWidth()
	local bar = AB.bars[1]
	local plate = bar and bar.hdArt and bar.hdArt.plate
	if plate and plate:IsShown() then
		local w = plate:GetWidth()
		if w and w > 0 then return w * bar:GetScale() end
	end
end

function AB:LayoutSwing()
	if not AB.bars[1] then return end
	if InCombatLockdown() then
		H:RunOutOfCombat(function() AB:LayoutSwing() end, "actionbars-swing")
		return
	end
	local db = self.db
	build()
	f:SetShown(db.swingShow)
	if not db.swingShow then return end

	local W = db.swingMatch and blockWidth() or db.swingWidth
	local h = db.swingHeight
	f:SetSize(W, h)
	local piece, tileW, t1, t2 = railGeometry()
	f.tileW, f.t1, f.t2, f.W, f.flat = tileW, t1, t2, W, not piece

	paint(f.dim, piece, db.swingDim)
	f.dim:SetTexCoord(0, piece and W / tileW or 1, t1, t2)
	f.dim:SetAllPoints(f)
	paint(f.mh, piece, 1)
	paint(f.oh, piece, 1)
	f.mh:ClearAllPoints()
	f.mh:SetPoint("TOPLEFT")
	f.mh:SetPoint("BOTTOMLEFT")
	f.oh:ClearAllPoints()
	f.oh:SetPoint("TOPRIGHT")
	f.oh:SetPoint("BOTTOMRIGHT")
	for _, t in ipairs({ f.sparkL, f.sparkR }) do t:SetSize(h * 0.9, h * 2.2) end

	-- on top of the block: the bottom of the swing rail meets the block's top rail
	local key = self:IsJoined() and "ActionBars.bar2" or "ActionBars.bar1"
	if db.swingDock and H.Movers.byKey[key] then
		local y = self:Get(1, "padY") + (self:Get(1, "rails") and self:Get(1, "railSize") / 2 or 0) + db.swingGap
		H.Movers:Dock("ActionBars.swing", key, "BOTTOM", "TOP", 0, y, true)
	else
		H.Movers:Undock("ActionBars.swing")
	end
	H.Movers:Apply(f.mover)
	self:PaintSwing()
end

-- light one side: `w` pixels from the left (main) or the right (off)
local function light(t, w, fromRight)
	if w < 0.5 then t:Hide() return end
	t:SetWidth(w)
	if f.flat then
		t:SetTexCoord(0, 1, 0, 1)
	elseif fromRight then
		t:SetTexCoord((f.W - w) / f.tileW, f.W / f.tileW, f.t1, f.t2)
	else
		t:SetTexCoord(0, w / f.tileW, f.t1, f.t2)
	end
	t:Show()
end

local function spark(t, x, shown)
	if not shown or not AB.db.swingSpark then t:Hide() return end
	t:ClearAllPoints()
	t:SetPoint("CENTER", f, "LEFT", x, 0)
	t:Show()
end

-- what to draw: "ranged", "dual" or "single"
local function mode(now)
	local db = AB.db
	if db.swingRanged and running(swings[SWING.Ranged], now) and not running(swings[SWING.MainHand], now) then
		return "ranged"
	end
	if db.swingOffHand and running(swings[SWING.OffHand], now) then return "dual" end
	return "single"
end

function AB:PaintSwing()
	if not f or not f.W then return end
	local now = GetTime()
	local W = f.W
	local m = mode(now)
	local main = progress(swings[m == "ranged" and SWING.Ranged or SWING.MainHand], now)
	local off = m == "dual" and progress(swings[SWING.OffHand], now)
	light(f.mh, main and W * main or 0, false)
	light(f.oh, off and W * off or 0, true)
	spark(f.sparkL, main and W * main or 0, main)
	spark(f.sparkR, off and W * (1 - off) or 0, off)

	-- ranged: the end window in red
	local r = swings[SWING.Ranged]
	if m == "ranged" and self.db.swingShotWindow and r.duration and r.duration > SHOT_WINDOW then
		f.shot:ClearAllPoints()
		f.shot:SetPoint("TOPRIGHT")
		f.shot:SetPoint("BOTTOMRIGHT")
		f.shot:SetWidth(W * SHOT_WINDOW / r.duration)
		f.shot:Show()
	else
		f.shot:Hide()
	end

	local active = main or off or S.meleeOn or S.repeatOn
	if active then S.lastActive = now end
	local alpha = 1
	if self.db.swingHideIdle and not active then
		alpha = math.max(0, 1 - (now - S.lastActive) / 0.6)   -- fade out
	end
	f:SetAlpha(alpha)
	-- keep ticking while something builds or the fade is under way
	return main or off or (alpha > 0 and alpha < 1)
end

local function onUpdate()
	if not AB:PaintSwing() then f:SetScript("OnUpdate", nil) end
end

local function wake()
	if f and AB.db.swingShow then f:SetScript("OnUpdate", onUpdate) end
end

--[[ Preview: made-up swings, main hand 2.6 s, off hand 1.9 s ]]

local function previewLoop()
	if not S.preview then return end
	local now = GetTime()
	local mh, oh = swings[SWING.MainHand], swings[SWING.OffHand]
	if not running(mh, now) then mh.start, mh.duration = now, 2.6 end
	if not running(oh, now) then oh.start, oh.duration = now, 1.9 end
	wake()
	C_Timer.After(0.1, previewLoop)
end

function AB:SetSwingPreview(on)
	S.preview = on
	S.meleeOn = on
	if on then previewLoop() else
		for _, s in pairs(swings) do s.start = nil end
		wake()
	end
end

--[[ The game's own swing bars ]]

local moved = {}
function AB:SwingBlizzard()
	local hide = self.db.swingHideBlizzard
	for _, name in ipairs({ "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame", "SwingTimerFrame" }) do
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

--[[ Events ]]

local function onSwing(duration, swingType)
	if not (plain(duration) and plain(swingType)) then return end
	local s = swings[swingType]
	if not s or not duration or duration <= 0 then return end
	s.start, s.duration = GetTime(), duration
	wake()
end

-- after the bars (the block's width is known once its plate is anchored)
hooksecurefunc(AB, "LayoutAll", function()
	AB:LayoutSwing()
	C_Timer.After(0.1, function() AB:LayoutSwing() end)
end)

H:RegisterEvent("PLAYER_SWING", function(_, duration, swingType) onSwing(duration, swingType) end)
H:RegisterEvent("PLAYER_ENTER_COMBAT", function() S.meleeOn = true wake() end)
H:RegisterEvent("PLAYER_LEAVE_COMBAT", function() S.meleeOn = S.preview wake() end)
H:RegisterEvent("START_AUTOREPEAT_SPELL", function() S.repeatOn = true wake() end)
H:RegisterEvent("STOP_AUTOREPEAT_SPELL", function() S.repeatOn = false wake() end)
H:RegisterEvent("PLAYER_DEAD", function()
	for _, s in pairs(swings) do s.start = nil end
	S.meleeOn, S.repeatOn = false, false
	wake()
end)
H:RegisterEvent("ADDON_LOADED", function(_, name)
	if name == "Blizzard_SwingTimer" then H:RunOutOfCombat(function() AB:SwingBlizzard() end, "actionbars-swing-blizz") end
end)
H:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	H:RunOutOfCombat(function() AB:SwingBlizzard() end, "actionbars-swing-blizz")
end)

H.previews = H.previews or {}
H.previews[#H.previews + 1] = {
	label = "Swing bar",
	desc = "Made-up swings, main hand and off hand, so you can see the swing bar out of combat.",
	get = function() return S.preview end,
	set = function(v) AB:SetSwingPreview(v) end,
}
