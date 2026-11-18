--[[
	Heraldry_Auras - Rows.lua
	Step 2 of the auras: the rows of icons.
	  - buffs: a small row at the top of the screen, by the minimap (mover
	    "Auras.buffs"); right click cancels, in combat too
	  - serious debuffs (crowd control: stuns, fears, roots...) as big icons over
	    the life orb (mover "Auras.debuffs"); optionally every other debuff too

	Built on the client's own aura containers (Blizzard_AuraContainer): the game
	picks the auras, places the icons and writes the time left, so secret
	values never reach our code. Buttons are styled once, in their creation
	window (later the game refuses most calls on them while auras are secret);
	size is the holder's scale, so it can change at any time. The game's own
	buff and debuff frames are hidden while the rows are on.
]]

local H = Heraldry
local AU = H.Modules.byName.Auras
local Themes = H.Themes

local DEFAULTS = {
	buffsShow = true,
	buffsPerRow = 12,
	buffsScale = 0.9,
	buffsTime = true,
	debuffsShow = true,
	debuffsAll = false,        -- every debuff, not only crowd control
	debuffsPerRow = 6,
	debuffsScale = 1.4,
	debuffsTime = true,
	debuffsGrow = "right",     -- "right" / "left" (a row), "up" / "down" (a column)
	rowsTimeSize = 10,
	hideBlizzardAuras = true,
}
for k, v in pairs(DEFAULTS) do AU.defaults[k] = v end

local ICON, GAP, TEXT_ROOM = 30, 4, 12

local function flow(c, m, ...)
	local f = c[m]
	if f then pcall(f, c, ...) end
end

-- the time left as "10" / "2m" / "3h", written by the game (rule formatter)
local timeFormatter
function AU.TimeFormatter()
	if timeFormatter ~= nil then return timeFormatter or nil end
	timeFormatter = false
	pcall(function()
		local Up = Enum.NumericRuleFormatRounding.Up
		local f = C_StringUtil.CreateNumericRuleFormatter()
		f:SetBreakpoints({
			{ threshold = 0, format = "%d", step = 1, rounding = Up },
			{ threshold = 90, format = "%dm", step = 60, rounding = Up, components = { { div = 60 } } },
			{ threshold = 5401, format = "%dh", step = 3600, rounding = Up, components = { { div = 3600 } } },
		})
		timeFormatter = f
	end)
	return timeFormatter or nil
end

--[[ Buttons ]]

-- styles one engine aura button; runs in its creation window
local function initializer(kind)
	return function(button)
		local db = AU.db
		button:SetSize(ICON, ICON)
		local rim = button:CreateTexture(nil, "BACKGROUND")
		rim:SetPoint("TOPLEFT", -2, 2)
		rim:SetPoint("BOTTOMRIGHT", 2, -2)
		if kind == "debuffs" then
			rim:SetColorTexture(0.75, 0.1, 0.08, 1)
		else
			local r, g, b = Themes:Accent()
			if not r then r, g, b = 0.85, 0.66, 0.3 end
			rim:SetColorTexture(r, g, b, 1)
		end
		local back = button:CreateTexture(nil, "BACKGROUND", nil, 1)
		back:SetPoint("TOPLEFT", -1, 1)
		back:SetPoint("BOTTOMRIGHT", 1, -1)
		back:SetColorTexture(0.04, 0.03, 0.02, 1)
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		cd:SetAllPoints()
		cd:SetDrawEdge(false)
		cd:SetReverse(true)
		cd:SetSwipeColor(0, 0, 0, 0.55)
		if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
		local text = CreateFrame("Frame", nil, button)
		text:SetAllPoints()
		text:SetFrameLevel(cd:GetFrameLevel() + 2)
		text:EnableMouse(false)
		local stack = text:CreateFontString(nil, "OVERLAY")
		local time = text:CreateFontString(nil, "OVERLAY")
		-- fonts first: registering a font string makes the game write to it
		H.Fonts:Apply(stack, "body", 11, AU)
		H.Fonts:Apply(time, "body", db.rowsTimeSize, AU)
		for _, fs in ipairs({ stack, time }) do
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		end
		stack:SetPoint("BOTTOMRIGHT", -1, 2)
		if kind == "debuffs" then
			time:SetPoint("BOTTOM", button, "BOTTOM", 1, 2)   -- inside: rows and columns pack alike
		else
			time:SetPoint("TOP", button, "BOTTOM", 0, -1)
		end

		button:SetIcon(icon)
		button:SetDurationCooldown(cd)
		pcall(button.SetApplicationCount, button, stack, {})
		local showTime = kind == "debuffs" and db.debuffsTime or kind == "buffs" and db.buffsTime
		if showTime then
			local fmt = AU.TimeFormatter()
			if not pcall(button.SetDurationText, button, time, { textFormatter = fmt }) then
				pcall(button.SetDurationText, button, time, {})
			end
		end
		if kind == "buffs" and button.SetCancelAuraButtons then
			pcall(button.SetCancelAuraButtons, button, "RightButtonUp")
		elseif button.SetMouseClickEnabled then
			pcall(button.SetMouseClickEnabled, button, false)
		end
	end
end

--[[ Rows ]]

local rows = {}

-- the holder (mover, scale) and the container inside it, made once
local function makeRow(kind, label, default, anchor, growthH, growthV, groups)
	if rows[kind] then return rows[kind] end
	if not (C_AddOns and C_AddOns.IsAddOnLoaded) then return end
	if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer") end
	local holder = CreateFrame("Frame", "HeraldryAuras" .. kind, UIParent)
	holder:SetSize(ICON * 6, ICON + TEXT_ROOM)
	local ok, c = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not ok or not c then
		H:Debug("Auras: this client has no aura containers; rows off")
		return
	end
	-- a row growing up leaves room under it for the time text
	local room = kind == "debuffs" and 0 or TEXT_ROOM
	c:SetPoint(anchor, holder, anchor, 0, anchor:find("BOTTOM") and room or 0)
	c:SetSize(1, 1)
	flow(c, c.SetFlowLayoutAnchorPoint and "SetFlowLayoutAnchorPoint" or "SetAuraLayoutAnchorPoint", anchor)
	local FD = AnchorUtil and AnchorUtil.FlowDirection
	if FD then
		flow(c, c.SetFlowLayoutGrowthDirection and "SetFlowLayoutGrowthDirection" or "SetAuraLayoutGrowthDirection", FD[growthH], FD[growthV])
	end
	local init = initializer(kind)
	for _, g in ipairs(groups) do
		local okG, err = pcall(c.AddAuraGroup, c, g.key, g.filter, {
			maxFrameCount = g.max,
			initializeFrame = init,
			layout = {
				elementWidth = ICON, elementHeight = ICON,
				elementSpacing = GAP, lineSpacing = GAP + room,
				groupSpacing = 0, groupLineSpacing = GAP + room,
			},
		})
		if not okG then H:Debug("Auras: group " .. g.key .. " refused: " .. tostring(err)) end
	end
	c:SetUnit("player")
	c:UpdateAllAuras()
	local row = { holder = holder, container = c, kind = kind, room = room }
	row.mover = H:RegisterMover(holder, "Auras." .. kind, {
		label = label,
		default = default,
		scalable = false,
		isShown = function() return AU.db[kind .. "Show"] end,
	})
	rows[kind] = row
	return row
end

local function groupCap(c, key, cap)
	if c.SetAuraGroupEnabled then
		if cap > 0 then pcall(c.SetAuraGroupEnabled, c, key, true) end
		pcall(c.SetAuraGroupMaxFrameCount, c, key, cap)
		if cap <= 0 then pcall(c.SetAuraGroupEnabled, c, key, false) end
	elseif c.SetAuraGroupMaxFrameCount then
		pcall(c.SetAuraGroupMaxFrameCount, c, key, cap)
	end
end

local function lineSize(c, perRow)
	local f = c.SetFlowLayoutMaximumLineSize or c.SetAuraLayoutRowWidth
	if f then pcall(f, c, perRow * (ICON + GAP)) end
end

-- the debuff row's direction: a row to the right or left, a column up or down
local GROW = {
	right = { anchor = "BOTTOMLEFT", h = "Right", v = "Up" },
	left = { anchor = "BOTTOMRIGHT", h = "Left", v = "Up" },
	up = { anchor = "BOTTOMLEFT", h = "Right", v = "Up", column = true },
	down = { anchor = "TOPLEFT", h = "Right", v = "Down", column = true },
}
AU.GROW = GROW

function AU:GrowDebuffs(row)
	local db = self.db
	local g = GROW[db.debuffsGrow] or GROW.right
	local c, n, step = row.container, db.debuffsPerRow, ICON + GAP
	row.holder:SetSize(g.column and step or n * step, g.column and n * step or step)
	c:ClearAllPoints()
	c:SetPoint(g.anchor, row.holder, g.anchor)
	flow(c, c.SetFlowLayoutAnchorPoint and "SetFlowLayoutAnchorPoint" or "SetAuraLayoutAnchorPoint", g.anchor)
	local FD, AX = AnchorUtil and AnchorUtil.FlowDirection, AnchorUtil and AnchorUtil.FlowLayoutAxis
	if FD then
		flow(c, c.SetFlowLayoutGrowthDirection and "SetFlowLayoutGrowthDirection" or "SetAuraLayoutGrowthDirection", FD[g.h], FD[g.v])
	end
	if AX and c.SetFlowLayoutAxis then pcall(c.SetFlowLayoutAxis, c, g.column and AX.Vertical or AX.Horizontal) end
	lineSize(c, n)
	if row.preview then row.preview() end
end

function AU:LayoutRows()
	if InCombatLockdown() then
		H:RunOutOfCombat(function() AU:LayoutRows() end, "auras-rows")
		return
	end
	local db = self.db
	local buffs = makeRow("buffs", "Buffs", { "TOPRIGHT", -250, -12 }, "TOPRIGHT", "Left", "Down", {
		{ key = "all", filter = "HELPFUL", max = 40 },
	})
	local debuffs = makeRow("debuffs", "Serious debuffs", { "BOTTOM", -330, 260 }, "BOTTOMLEFT", "Right", "Up", {
		{ key = "cc", filter = "HARMFUL|CROWD_CONTROL", max = 8 },
		{ key = "rest", filter = "HARMFUL|!CROWD_CONTROL", max = 16 },
	})
	if buffs then
		buffs.holder:SetShown(db.buffsShow)
		buffs.holder:SetScale(db.buffsScale)
		buffs.holder:SetSize(db.buffsPerRow * (ICON + GAP), ICON + TEXT_ROOM)
		lineSize(buffs.container, db.buffsPerRow)
		groupCap(buffs.container, "all", db.buffsShow and 40 or 0)
		-- by the minimap, on its left (still movable from there)
		if H.Movers.byKey["Minimap.frame"] then
			H.Movers:Dock("Auras.buffs", "Minimap.frame", "TOPRIGHT", "TOPLEFT", -8, -4, true)
		end
		H.Movers:Apply(buffs.mover)
	end
	if debuffs then
		debuffs.holder:SetShown(db.debuffsShow)
		debuffs.holder:SetScale(db.debuffsScale)
		self:GrowDebuffs(debuffs)
		groupCap(debuffs.container, "cc", db.debuffsShow and 8 or 0)
		groupCap(debuffs.container, "rest", (db.debuffsShow and db.debuffsAll) and 16 or 0)
		-- over the life orb (still movable from there)
		if H.Movers.byKey["Orbs.health"] then
			H.Movers:Dock("Auras.debuffs", "Orbs.health", "BOTTOM", "TOP", 0, 14, true)
		end
		H.Movers:Apply(debuffs.mover)
	end
	self:RowsBlizzard()
	H:RefreshEditMode()
end

--[[ The game's buff and debuff frames ]]

local hooked = {}
function AU:RowsBlizzard()
	for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
		local fr = _G[name]
		if fr then
			local hide = self.db.hideBlizzardAuras and (name == "BuffFrame" and self.db.buffsShow or name == "DebuffFrame" and self.db.debuffsShow)
			if not hooked[fr] then
				hooked[fr] = true
				hooksecurefunc(fr, "Show", function(f)
					if f.heraldryHidden and not InCombatLockdown() then f:Hide() end
				end)
			end
			fr.heraldryHidden = hide and true or nil
			if hide then fr:Hide() else fr:Show() end
		end
	end
end

--[[ Preview: made-up debuffs in the debuff row (the game's containers only
     show real auras, so these are plain icons styled the same) ]]

local SAMPLE = {
	{ icon = 135963, time = 6 },    -- a stun
	{ icon = 136183, time = 8 },    -- a fear
	{ icon = 135848, time = 5 },    -- a root
}
local fakes, previewOn, ticker = {}, false, nil

local function fakeIcon(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(ICON, ICON)
	b.rim = b:CreateTexture(nil, "BACKGROUND")
	b.rim:SetPoint("TOPLEFT", -2, 2)
	b.rim:SetPoint("BOTTOMRIGHT", 2, -2)
	b.rim:SetColorTexture(0.75, 0.1, 0.08, 1)
	b.back = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.back:SetPoint("TOPLEFT", -1, 1)
	b.back:SetPoint("BOTTOMRIGHT", 1, -1)
	b.back:SetColorTexture(0.04, 0.03, 0.02, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints()
	b.cd:SetDrawEdge(false)
	b.cd:SetReverse(true)
	b.cd:SetSwipeColor(0, 0, 0, 0.55)
	if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
	local t = CreateFrame("Frame", nil, b)
	t:SetAllPoints()
	t:SetFrameLevel(b.cd:GetFrameLevel() + 2)
	b.time = t:CreateFontString(nil, "OVERLAY")
	b.time:SetShadowColor(0, 0, 0, 1)
	b.time:SetShadowOffset(1, -1)
	b.time:SetPoint("BOTTOM", b, "BOTTOM", 1, 2)
	return b
end

local function previewTick()
	local now = GetTime()
	for _, b in ipairs(fakes) do
		if b:IsShown() then
			local left = b.exp - now
			if left <= 0 then
				b.exp = now + b.length
				b.cd:SetCooldown(now, b.length)
				left = b.length
			end
			b.time:SetText(AU.db.debuffsTime and ("%d"):format(math.ceil(left)) or "")
		end
	end
end

function AU:SetDebuffPreview(on)
	previewOn = on
	local row = rows.debuffs
	if row then row.preview = previewOn and function() AU:SetDebuffPreview(true) end or nil end
	if on and row then
		local now = GetTime()
		for i, s in ipairs(SAMPLE) do
			local b = fakes[i] or fakeIcon(row.holder)
			fakes[i] = b
			b:ClearAllPoints()
			-- the row grows right from its bottom-left, like the real one
			local g = AU.GROW[AU.db.debuffsGrow] or AU.GROW.right
			local d = (i - 1) * (ICON + GAP)
			local x = g.column and 0 or (g.h == "Left" and -d or d)
			local y = g.column and (g.v == "Down" and -d or d) or 0
			b:SetPoint(g.anchor, row.holder, g.anchor, x, y)
			b.icon:SetTexture(s.icon)
			H.Fonts:Apply(b.time, "body", AU.db.rowsTimeSize, AU)
			b.length, b.exp = s.time, now + s.time
			b.cd:SetCooldown(now, s.time)
			b:Show()
		end
		if not ticker then ticker = C_Timer.NewTicker(0.2, previewTick) end
		previewTick()
	else
		for _, b in ipairs(fakes) do b:Hide() end
		if ticker then ticker:Cancel() ticker = nil end
	end
end

H.previews = H.previews or {}
H.previews[#H.previews + 1] = {
	label = "Serious debuffs",
	desc = "Made-up crowd control (a stun, a fear, a root) in the debuff row over the life orb.",
	get = function() return previewOn end,
	set = function(v) AU:SetDebuffPreview(v) end,
}
