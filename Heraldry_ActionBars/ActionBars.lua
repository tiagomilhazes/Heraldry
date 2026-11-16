--[[
	Heraldry_ActionBars - ActionBars.lua
	Action bars 1 to 8.

	The game's own action buttons are reused, so casting, keybinds, macros,
	paging (stances, forms, stealth), cooldowns and flyouts stay the game's.
	They are moved into our own secure bars, which the game never repositions,
	and the game's bar frames are hidden.

	Everything that touches the buttons or bars runs out of combat only.
	Fading only changes opacity, which is allowed in combat.

	Settings are flat, one set per bar: bar<N>_enabled, bar<N>_buttons, ...
]]

local H = Heraldry

local BASE = 45   -- the game's action button size, before our bar scale

local BARS = {
	{ n = 1, frames = { "MainActionBar", "MainMenuBar" }, prefix = "ActionButton",              pos = { "BOTTOM", 0, 48 },   perRow = 12 },
	{ n = 2, frames = { "MultiBarBottomLeft" },           prefix = "MultiBarBottomLeftButton",  pos = { "BOTTOM", 0, 94 },   perRow = 12 },
	{ n = 3, frames = { "MultiBarBottomRight" },          prefix = "MultiBarBottomRightButton", pos = { "BOTTOM", 0, 140 },  perRow = 12 },
	{ n = 4, frames = { "MultiBarRight" },                prefix = "MultiBarRightButton",       pos = { "RIGHT", -6, 0 },    perRow = 1 },
	{ n = 5, frames = { "MultiBarLeft" },                 prefix = "MultiBarLeftButton",        pos = { "RIGHT", -52, 0 },   perRow = 1 },
	{ n = 6, frames = { "MultiBar5" },                    prefix = "MultiBar5Button",           pos = { "CENTER", 0, -120 }, perRow = 12 },
	{ n = 7, frames = { "MultiBar6" },                    prefix = "MultiBar6Button",           pos = { "CENTER", 0, -166 }, perRow = 12 },
	{ n = 8, frames = { "MultiBar7" },                    prefix = "MultiBar7Button",           pos = { "CENTER", 0, -212 }, perRow = 12 },
}

-- Flat defaults for every bar. "enabled" has no default on purpose: until it
-- is set, a bar follows whether the game was showing it.
local defaults = {}
for _, def in ipairs(BARS) do
	local k = "bar" .. def.n .. "_"
	defaults[k .. "buttons"] = 12
	defaults[k .. "perRow"] = def.perRow
	defaults[k .. "size"] = 40
	defaults[k .. "spacing"] = 4
	defaults[k .. "alpha"] = 1
	defaults[k .. "mouseover"] = false
	defaults[k .. "fadeAlpha"] = 0
end

local AB = H:NewModule("ActionBars", { label = "Action bars", defaults = defaults })
AB.BARS = BARS
AB.bars = {}   -- n -> bar frame

local hidden = CreateFrame("Frame")
hidden:Hide()

function AB:Get(n, field)
	return self.db["bar" .. n .. "_" .. field]
end

function AB:Set(n, field, value)
	self.db["bar" .. n .. "_" .. field] = value
end

function AB:IsBarEnabled(n)
	local v = self:Get(n, "enabled")
	if v == nil then
		local bar = self.bars[n]
		return bar and bar.gameShown or false
	end
	return v
end

--[[ Fading (opacity is allowed in combat) ]]

local function fadeUpdate(bar, elapsed)
	bar.tick = (bar.tick or 0) + elapsed
	if bar.tick < 0.05 then return end
	local dt = bar.tick
	bar.tick = 0
	local n = bar.n
	local target = AB:Get(n, "alpha")
	if AB:Get(n, "mouseover") then
		local over = bar:IsMouseOver(4, -4, -4, 4)
			or (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:IsMouseOver())
			or GetCursorInfo() ~= nil      -- dragging a spell: show the bar
			or H.editMode
		if not over then target = AB:Get(n, "fadeAlpha") end
	end
	local a = bar:GetAlpha()
	if math.abs(a - target) < 0.01 then
		if a ~= target then bar:SetAlpha(target) end
		return
	end
	bar:SetAlpha(a + (target - a) * math.min(1, dt * 10))
end

--[[ Layout ]]

function AB:LayoutBar(bar)
	if InCombatLockdown() then
		H:RunOutOfCombat(function() AB:LayoutAll() end, "actionbars-layout")
		return
	end
	local n = bar.n
	local count = math.max(1, math.min(self:Get(n, "buttons"), #bar.buttons))
	local perRow = math.max(1, math.min(self:Get(n, "perRow"), count))
	local scale = self:Get(n, "size") / BASE
	local gap = self:Get(n, "spacing") / scale
	local cols, rows = perRow, math.ceil(count / perRow)

	bar:SetScale(scale)
	bar:SetSize(cols * BASE + (cols - 1) * gap, rows * BASE + (rows - 1) * gap)

	bar.layingOut = true
	for i, b in ipairs(bar.buttons) do
		if i <= count then
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			b:SetParent(bar)
			b:SetScale(1)
			b:SetSize(BASE, BASE)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (BASE + gap), -row * (BASE + gap))
		else
			b:SetParent(hidden)
		end
	end
	bar.layingOut = false

	-- Hidden in pet battles and while the game shows its vehicle or override bar.
	local driver = self:IsBarEnabled(n) and "[petbattle][vehicleui][overridebar] hide; show" or "hide"
	if bar.driver ~= driver then
		UnregisterStateDriver(bar, "visibility")
		RegisterStateDriver(bar, "visibility", driver)
		bar.driver = driver
	end

	-- The scale changed: put the bar back at its saved place.
	if bar.mover then H.Movers:Apply(bar.mover) end
end

function AB:LayoutAll()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() AB:LayoutAll() end, "actionbars-layout")
		return
	end
	for _, bar in pairs(self.bars) do self:LayoutBar(bar) end
	H:RefreshEditMode()
end

-- Back to defaults for one bar, in the active profile (position included).
function AB:ResetBar(n)
	local prefix = "bar" .. n .. "_"
	local saved = H.profile.modules[self.name]
	if saved then
		for k in pairs(saved) do
			if k:sub(1, #prefix) == prefix then saved[k] = nil end
		end
	end
	H.Movers:Reset("ActionBars.bar" .. n)
	if self.bars[n] then self:LayoutBar(self.bars[n]) end
	H:RefreshEditMode()
end

--[[ Build ]]

local function gameFrame(def)
	for _, name in ipairs(def.frames) do
		if _G[name] then return _G[name] end
	end
end

function AB:Build()
	for _, def in ipairs(BARS) do
		local buttons = {}
		for i = 1, 12 do
			local b = _G[def.prefix .. i]
			if b then buttons[#buttons + 1] = b end
		end
		local game = gameFrame(def)
		if #buttons > 0 then
			local bar = CreateFrame("Frame", "HeraldryActionBar" .. def.n, UIParent, "SecureHandlerStateTemplate")
			bar.n = def.n
			bar.buttons = buttons
			bar.gameShown = game and game:IsShown() or false
			bar:SetFrameStrata("MEDIUM")
			bar:SetFrameLevel(5)
			bar:SetScript("OnUpdate", fadeUpdate)
			self.bars[def.n] = bar

			-- If the game ever re-anchors a button, put it back (out of combat).
			for _, b in ipairs(buttons) do
				hooksecurefunc(b, "SetPoint", function()
					if not bar.layingOut then
						H:RunOutOfCombat(function() AB:LayoutAll() end, "actionbars-layout")
					end
				end)
			end

			-- The game's bar frame goes to a hidden parent (safer than Hide()).
			for _, name in ipairs(def.frames) do
				local f = _G[name]
				if f then pcall(f.SetParent, f, hidden) end
			end

			bar.mover = H:RegisterMover(bar, "ActionBars.bar" .. def.n, {
				label = "Action bar " .. def.n,
				default = def.pos,
				scalable = false,
				isShown = function() return AB:IsBarEnabled(def.n) end,
			})
			H:Debug(("Action bar %d: %d buttons, game showed it: %s"):format(def.n, #buttons, tostring(bar.gameShown)))
		else
			H:Debug("Action bar " .. def.n .. ": not in this client")
		end
	end
end

function AB:OnEnable()
	self:Build()
	self:LayoutAll()
	H:RegisterEvent("UI_SCALE_CHANGED", function() AB:LayoutAll() end)
	H:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		C_Timer.After(0.5, function() AB:LayoutAll() end)
	end)
end

function AB:OnProfileChanged()
	self:LayoutAll()
end
