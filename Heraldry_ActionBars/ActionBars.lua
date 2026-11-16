--[[
	Heraldry_ActionBars - ActionBars.lua
	Action bars 1 to 8, the stance bar and the pet bar.

	The game's own action buttons are reused, so casting, keybinds, macros,
	paging (stances, forms, stealth), cooldowns and flyouts stay the game's.
	They are moved into our own secure bars, which the game never repositions,
	and the game's bar frames are hidden.

	Everything that touches the buttons or bars runs out of combat only.
	Fading only changes opacity, which is allowed in combat.

	Settings are flat, one set per bar: bar<N>_enabled, bar<N>_buttons, ...
	(N is 1-8, "stance" or "pet").
]]

local H = Heraldry

local BASE = 45   -- the game's action button size, before our bar scale

-- Shown unless switched off; hidden in pet battles and while the game shows
-- its vehicle or override bar.
local DRIVER = "[petbattle][vehicleui][overridebar] hide; show"

local BARS = {
	{ n = 1, frames = { "MainActionBar", "MainMenuBar" }, prefix = "ActionButton",              pos = { "BOTTOM", 0, 48 },   perRow = 12 },
	{ n = 2, frames = { "MultiBarBottomLeft" },           prefix = "MultiBarBottomLeftButton",  pos = { "BOTTOM", 0, 94 },   perRow = 12 },
	{ n = 3, frames = { "MultiBarBottomRight" },          prefix = "MultiBarBottomRightButton", pos = { "BOTTOM", 0, 140 },  perRow = 12 },
	{ n = 4, frames = { "MultiBarRight" },                prefix = "MultiBarRightButton",       pos = { "RIGHT", -6, 0 },    perRow = 1 },
	{ n = 5, frames = { "MultiBarLeft" },                 prefix = "MultiBarLeftButton",        pos = { "RIGHT", -52, 0 },   perRow = 1 },
	{ n = 6, frames = { "MultiBar5" },                    prefix = "MultiBar5Button",           pos = { "CENTER", 0, -120 }, perRow = 12 },
	{ n = 7, frames = { "MultiBar6" },                    prefix = "MultiBar6Button",           pos = { "CENTER", 0, -166 }, perRow = 12 },
	{ n = 8, frames = { "MultiBar7" },                    prefix = "MultiBar7Button",           pos = { "CENTER", 0, -212 }, perRow = 12 },
	-- The game shows as many stance buttons as you have stances (Paladin auras).
	{ n = "stance", label = "Stance bar", frames = { "StanceBar", "StanceBarFrame" }, prefix = "StanceButton",
	  count = 10, size = 32, perRow = 10, pos = { "BOTTOM", -170, 186 }, on = true,
	  shown = function() return GetNumShapeshiftForms and GetNumShapeshiftForms() or 10 end },
	-- Only while you have a pet.
	{ n = "pet", label = "Pet bar", frames = { "PetActionBar", "PetActionBarFrame" }, prefix = "PetActionButton",
	  count = 10, size = 32, perRow = 10, pos = { "BOTTOM", 170, 186 }, on = true,
	  driver = "[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide" },
}
for _, def in ipairs(BARS) do
	def.label = def.label or ("Action bar " .. def.n)
	def.count = def.count or 12
end

-- Flat defaults for every bar. "enabled" has no default on purpose: until it
-- is set, a bar follows whether the game was showing it.
local defaults = {}
for _, def in ipairs(BARS) do
	local k = "bar" .. def.n .. "_"
	defaults[k .. "buttons"] = def.count
	defaults[k .. "perRow"] = def.perRow
	defaults[k .. "size"] = def.size or 40
	defaults[k .. "spacing"] = 4
	defaults[k .. "alpha"] = 1
	defaults[k .. "mouseover"] = false
	defaults[k .. "fadeAlpha"] = 0
	-- Look (Art.lua): theme frames on every button, the plate only on bar 1.
	defaults[k .. "frame"] = "slim"
	defaults[k .. "plate"] = def.n == 1
	defaults[k .. "rails"] = true
	defaults[k .. "caps"] = true
	defaults[k .. "pad"] = 6
	defaults[k .. "railSize"] = 10
end

local AB = H:NewModule("ActionBars", { label = "Action bars", defaults = defaults })
AB.BARS = BARS
AB.bars = {}   -- n -> bar frame
AB.defs = {}   -- n -> definition
for _, def in ipairs(BARS) do AB.defs[def.n] = def end

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
		if self.defs[n].on then return true end
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
	local def = self.defs[n]
	local base = bar.base
	local count = math.min(self:Get(n, "buttons"), #bar.buttons)
	if def.shown then count = math.min(count, def.shown()) end   -- e.g. stances you know
	local slots = math.max(1, count)
	local perRow = math.max(1, math.min(self:Get(n, "perRow"), slots))
	local scale = self:Get(n, "size") / base
	local gap = self:Get(n, "spacing") / scale
	local cols, rows = perRow, math.ceil(slots / perRow)

	bar:SetScale(scale)
	bar:SetSize(cols * base + (cols - 1) * gap, rows * base + (rows - 1) * gap)

	bar.layingOut = true
	for i, b in ipairs(bar.buttons) do
		if i <= count then
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			b:SetParent(bar)
			b:SetScale(1)
			b:SetSize(base, base)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (base + gap), -row * (base + gap))
		else
			b:SetParent(hidden)
		end
	end
	bar.layingOut = false

	local driver = self:IsBarEnabled(n) and (def.driver or DRIVER) or "hide"
	if bar.driver ~= driver then
		UnregisterStateDriver(bar, "visibility")
		RegisterStateDriver(bar, "visibility", driver)
		bar.driver = driver
	end

	if self.ApplyBarArt then self:ApplyBarArt(bar) end

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
		for i = 1, def.count do
			local b = _G[def.prefix .. i]
			if b then buttons[#buttons + 1] = b end
		end
		local game = gameFrame(def)
		if #buttons > 0 then
			local bar = CreateFrame("Frame", "HeraldryActionBar" .. def.n, UIParent, "SecureHandlerStateTemplate")
			bar.n = def.n
			bar.buttons = buttons
			-- Stance and pet buttons are smaller than action buttons.
			bar.base = BASE
			if type(def.n) == "string" then
				local w = math.floor(buttons[1]:GetWidth() + 0.5)
				if w >= 10 then bar.base = w end
			end
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
				label = def.label,
				default = def.pos,
				scalable = false,
				isShown = function() return AB:IsBarEnabled(def.n) end,
			})
			H:Debug(("%s: %d buttons of %d px, game showed it: %s"):format(def.label, #buttons, bar.base, tostring(bar.gameShown)))
		else
			H:Debug(def.label .. ": not in this client")
		end
	end
end

function AB:OnEnable()
	self:Build()
	self:LayoutAll()
	H:RegisterEvent("UI_SCALE_CHANGED", function() AB:LayoutAll() end)
	H:On("THEME_CHANGED", function() AB:LayoutAll() end)
	-- Learning a stance (aura) changes how many stance buttons there are.
	H:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
		if AB.bars.stance then AB:LayoutBar(AB.bars.stance) end
	end)
	H:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		C_Timer.After(0.5, function() AB:LayoutAll() end)
	end)
end

function AB:OnProfileChanged()
	self:LayoutAll()
end
