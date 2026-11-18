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

local SHOT_WINDOW = 0.5   -- seconds at the end of a ranged swing where moving holds the shot

local DEFAULTS = {
	swingShow = true,
	swingPlace = "bottom",     -- "top" / "bottom": that rail of the block lights up; "bar": a bar of its own
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

local RL = AB.RailLight
local f

local function build()
	if f then return f end
	f = RL.New("HeraldrySwingBar", "ActionBars.swing", "Swing bar", { "BOTTOM", 0, 150 },
		function() return AB.db.swingShow and AB.db.swingPlace == "bar" end)
	return f
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

	local onRail = RL.Layout(f, {
		rail = RL.BlockRail(db.swingPlace),
		flip = db.swingPlace == "bottom",
		width = db.swingMatch and RL.BlockWidth() or db.swingWidth,
		height = db.swingHeight,
		dim = db.swingDim,
	})

	-- the separate bar sits on top of the block (movable from there)
	local key = self:IsJoined() and "ActionBars.bar2" or "ActionBars.bar1"
	if not onRail and db.swingDock and H.Movers.byKey[key] then
		local y = self:Get(1, "padY") + (self:Get(1, "rails") and self:Get(1, "railSize") / 2 or 0) + db.swingGap
		H.Movers:Dock("ActionBars.swing", key, "BOTTOM", "TOP", 0, y, true)
	else
		H.Movers:Undock("ActionBars.swing")
	end
	H.Movers:Apply(f.mover)
	self:PaintSwing()
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
	local sp = self.db.swingSpark
	RL.Light(f, f.left, main and W * main or 0, false)
	RL.Light(f, f.right, off and W * off or 0, true)
	RL.Spark(f, f.sparkL, main and W * main or 0, sp and main)
	RL.Spark(f, f.sparkR, off and W * (1 - off) or 0, sp and off)

	-- ranged: the end window in red
	local r = swings[SWING.Ranged]
	if m == "ranged" and self.db.swingShotWindow and r.duration and r.duration > SHOT_WINDOW then
		RL.Warn(f, W * SHOT_WINDOW / r.duration)
	else
		RL.Warn(f, false)
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

-- Blizzard_SwingTimer's frames: the known names, else any top-level frame
-- whose name says swing (the client's naming is not documented).
local moved = {}
local function blizzardFrames()
	local list = {}
	for name, obj in pairs(_G) do
		if type(name) == "string" and type(obj) == "table" and name:lower():find("swing")
			and not name:find("^Heraldry") and not name:find("^ERB_") and not name:find("^EllesmereUI")
			and type(obj.GetObjectType) == "function" then
			local ok, parent = pcall(obj.GetParent, obj)
			if ok and (parent == UIParent or moved[obj]) then list[#list + 1] = obj end
		end
	end
	-- frames with no telling name: found by their label ("Main Hand"...)
	local labels = {}
	for _, key in ipairs({ "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_RANGED" }) do
		if type(_G[key]) == "string" then labels[_G[key]] = true end
	end
	labels["Main Hand"], labels["Off Hand"], labels["Ranged"] = true, true, true
	local seen = {}
	for _, o in ipairs(list) do seen[o] = true end
	local f = EnumerateFrames()
	while f do
		if f:IsObjectType("StatusBar") and not f:IsForbidden() then
			local found = false
			local regions = { f:GetRegions() }
			local par = f:GetParent()
			if par and par ~= UIParent then
				for _, r in ipairs({ par:GetRegions() }) do regions[#regions + 1] = r end
			end
			for _, r in ipairs(regions) do
				if r:IsObjectType("FontString") then
					local ok, t = pcall(r.GetText, r)
					-- text can be secret (unit names on nameplates...): never index with it
					if ok and type(t) == "string" and not (issecretvalue and issecretvalue(t)) and labels[t] then
						found = true
						break
					end
				end
			end
			if found then
				-- the top-level frame holding it
				local top = f
				while top:GetParent() and top:GetParent() ~= UIParent and top:GetParent() ~= hidden do top = top:GetParent() end
				local name = top:GetName() or ""
				if not seen[top] and not name:find("^Heraldry") and (top:GetParent() == UIParent or moved[top]) then
					seen[top] = true
					list[#list + 1] = top
				end
			end
		end
		f = EnumerateFrames(f)
	end
	return list
end

function AB:SwingBlizzard()
	local hide = self.db.swingHideBlizzard
	for _, fr in ipairs(blizzardFrames()) do
		if hide and not moved[fr] then
			moved[fr] = fr:GetParent()
			pcall(fr.SetParent, fr, hidden)
			H:Debug("Swing bar: hid the game's " .. tostring(fr:GetName()))
		elseif not hide and moved[fr] then
			pcall(fr.SetParent, fr, moved[fr])
			moved[fr] = nil
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
	-- the game may build its bars a moment later
	C_Timer.After(3, function() H:RunOutOfCombat(function() AB:SwingBlizzard() end, "actionbars-swing-blizz") end)
end)

H.previews = H.previews or {}
H.previews[#H.previews + 1] = {
	key = "swing",
	label = "Swing bar",
	desc = "Made-up swings, main hand and off hand, so you can see the swing bar out of combat.",
	get = function() return S.preview end,
	set = function(v) AB:SetSwingPreview(v) end,
}
