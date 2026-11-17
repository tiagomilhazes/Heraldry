--[[
	Heraldry - Core/EditMode.lua
	Edit mode: a box over every mover.

	Drag a box to move it. When you let go it snaps to the screen edges and
	centre and to the other boxes; gold guide lines show where while you drag
	(hold Alt to place freely). The box itself follows the mouse with the
	game's own movement, so dragging is smooth. Arrow keys nudge the selected box by
	1 (Shift: 10). Right click puts it back at its default place. The mouse wheel
	changes its scale. Escape or "Done" closes edit mode, and so does combat.

	H:SetEditMode(on)  H:ToggleEditMode()  H.editMode (bool)
	Grid settings: HeraldryDB.global.editMode = { grid = true, gridSize = 32 }
]]

local _, ns = ...
local H = ns.H
local Movers = H.Movers

local SNAP = 8
local ACCENT = { 0.910, 0.690, 0.294 }

local overlays = {}
local selected
local dragging            -- the box being dragged, if any
local SYNC_EVERY = 0.2    -- idle boxes follow their frame 5 times a second
local bar, grid, keys

local function settings()
	H.global.editMode = H.global.editMode or { grid = true, gridSize = 32 }
	return H.global.editMode
end

--[[ Snapping ]]

-- Moves lo (a left or bottom edge) so that one of its edges or its centre
-- lands on the closest target, if one is within SNAP.
-- Returns the new edge and the line it snapped to (nil when none was close).
local function snap(lo, size, targets)
	local bestD, line
	for _, t in ipairs(targets) do
		for _, e in ipairs({ 0, size / 2, size }) do
			local d = t - (lo + e)
			if math.abs(d) <= SNAP and (not bestD or math.abs(d) < math.abs(bestD)) then
				bestD, line = d, t
			end
		end
	end
	if bestD then return lo + bestD, line end
	return lo
end

-- Gold lines showing where a dragged box will snap.
local guideX, guideY
local function guides(x, y)
	if not guideX then
		-- On their own frame above the boxes (UIParent's own textures draw
		-- under every frame).
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetAllPoints(UIParent)
		f:SetFrameStrata("FULLSCREEN")
		guideX = f:CreateTexture(nil, "OVERLAY")
		guideY = f:CreateTexture(nil, "OVERLAY")
		for _, t in ipairs({ guideX, guideY }) do
			t:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
		end
	end
	if x then
		guideX:ClearAllPoints()
		guideX:SetPoint("TOP", UIParent, "TOPLEFT", x, 0)
		guideX:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, 0)
		guideX:SetWidth(1)
		guideX:Show()
	else
		guideX:Hide()
	end
	if y then
		guideY:ClearAllPoints()
		guideY:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, y)
		guideY:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, y)
		guideY:SetHeight(1)
		guideY:Show()
	else
		guideY:Hide()
	end
end

-- Where a box at (l, b) would land once snapped; also the guide lines.
local function snapped(o, l, b)
	if IsAltKeyDown() then return l, b end
	local sl, lx = snap(l, o.w, o.xs)
	local sb, ly = snap(b, o.h, o.ys)
	return sl, sb, lx, ly
end

local function snapTargets(except)
	local W, SH = UIParent:GetWidth(), UIParent:GetHeight()
	local xs, ys = { 0, W / 2, W }, { 0, SH / 2, SH }
	for _, o in pairs(overlays) do
		if o ~= except and o:IsShown() then
			local l, b, w, h = o:GetRect()
			if l then
				xs[#xs + 1], xs[#xs + 2], xs[#xs + 3] = l, l + w / 2, l + w
				ys[#ys + 1], ys[#ys + 2], ys[#ys + 3] = b, b + h / 2, b + h
			end
		end
	end
	return xs, ys
end

--[[ Boxes ]]

local function paint(o)
	local on = o == selected
	o.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], on and 0.45 or 0.22)
	for i = 1, 4 do o.edges[i]:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], on and 1 or 0.7) end
	local _, _, _, s = Movers:Get(o.mover)
	o.text:SetText(o.mover.label .. (math.abs(s - 1) > 0.001 and ("\n" .. math.floor(s * 100 + 0.5) .. "%") or ""))
end

local function selectBox(o)
	local old = selected
	selected = o
	if old then paint(old) end
	if o then paint(o) end
end

-- Places the box at a rectangle given in screen units.
local function place(o, l, b, w, h)
	o:ClearAllPoints()
	o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
	o:SetSize(math.max(w, 16), math.max(h, 16))
end

-- Follows the frame while not being dragged (size or position may change).
local function sync(o)
	if o.dragging then return end
	local l, b, w, h = Movers:RectOf(o.mover)
	if l then place(o, l, b, w, h) end
end

local function save(o)
	local l, b, w, h = o:GetRect()
	local _, _, _, s = Movers:Get(o.mover)
	Movers:SaveRect(o.mover, l, b, w, h, s)
end

local function onUpdate(o, elapsed)
	if not o.dragging then
		-- Nothing else moves while a box is dragged; otherwise a light refresh.
		if dragging then return end
		o.syncWait = (o.syncWait or 0) - elapsed
		if o.syncWait > 0 then return end
		o.syncWait = SYNC_EVERY
		sync(o)
		return
	end
	-- The game moves the box (StartMoving); the frame follows it, unsnapped.
	local l, b = o:GetLeft(), o:GetBottom()
	if not l then return end
	local rx, ry = math.floor(l + 0.5), math.floor(b + 0.5)
	if rx == o.lastX and ry == o.lastY and IsAltKeyDown() == o.lastAlt then return end
	o.lastX, o.lastY, o.lastAlt = rx, ry, IsAltKeyDown()
	Movers:Preview(o.mover, l, b, o.w, o.h)
	local _, _, gx, gy = snapped(o, l, b)
	guides(gx, gy)
end

local function createOverlay(m)
	local o = CreateFrame("Button", nil, UIParent)
	o.mover = m
	o:SetFrameStrata("DIALOG")
	o:SetClampedToScreen(true)
	o:SetMovable(true)
	o:EnableMouse(true)
	o:EnableMouseWheel(true)
	o:RegisterForClicks("RightButtonUp", "MiddleButtonUp")
	o.bg = o:CreateTexture(nil, "BACKGROUND")
	o.bg:SetAllPoints()
	o.edges = {}
	for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = o:CreateTexture(nil, "BORDER")
		t:SetPoint(pts[1])
		t:SetPoint(pts[2])
		if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
		o.edges[i] = t
	end
	o.text = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	o.text:SetPoint("CENTER")

	o:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		selectBox(self)
		local _, _, w, h = self:GetRect()
		self.w, self.h = w, h
		self:StartMoving()
		self.lastX, self.lastY = nil, nil
		-- The other boxes don't move during the drag: snap targets once.
		self.xs, self.ys = snapTargets(self)
		self.dragging = true
		dragging = self
	end)
	o:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.dragging then
			self:StopMovingOrSizing()
			self.dragging = false
			dragging = nil
			guides(nil, nil)
			local l, b = snapped(self, self:GetLeft(), self:GetBottom())
			place(self, l, b, self.w, self.h)
			save(self)
		end
	end)
	o:SetScript("OnClick", function(self, button)
		if button == "MiddleButton" then
			H:CenterSelected(self)
			return
		end
		Movers:Reset(self.mover.key)
		selectBox(self)
		H:Print(self.mover.label .. ": back to its default place.")
	end)
	o:SetScript("OnMouseWheel", function(self, delta)
		if not self.mover.scalable then return end
		local _, _, _, s = Movers:Get(self.mover)
		s = math.max(0.5, math.min(2, math.floor((s + delta * 0.05) * 100 + 0.5) / 100))
		Movers:SetScale(self.mover, s)
		selectBox(self)
	end)
	o:SetScript("OnUpdate", onUpdate)
	overlays[m.key] = o
	sync(o)
	paint(o)
	return o
end

--[[ Grid ]]

local function buildGrid()
	if grid then
		for _, t in ipairs(grid.lines) do t:Hide() end
	else
		grid = CreateFrame("Frame", nil, UIParent)
		grid:SetAllPoints(UIParent)
		grid:SetFrameStrata("BACKGROUND")
		grid.lines = {}
	end
	local size = settings().gridSize or 32
	local W, SH = UIParent:GetWidth(), UIParent:GetHeight()
	local n = 0
	local function line(vertical, offset, center)
		n = n + 1
		local t = grid.lines[n]
		if not t then
			t = grid:CreateTexture(nil, "BACKGROUND")
			grid.lines[n] = t
		end
		t:ClearAllPoints()
		if vertical then
			t:SetPoint("TOP", grid, "TOP", offset, 0)
			t:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
			t:SetWidth(1)
		else
			t:SetPoint("LEFT", grid, "LEFT", 0, offset)
			t:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
			t:SetHeight(1)
		end
		if center then
			t:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.5)
		else
			t:SetColorTexture(1, 1, 1, 0.08)
		end
		t:Show()
	end
	line(true, 0, true)
	line(false, 0, true)
	for i = 1, math.floor(W / 2 / size) do
		line(true, i * size)
		line(true, -i * size)
	end
	for i = 1, math.floor(SH / 2 / size) do
		line(false, i * size)
		line(false, -i * size)
	end
end

function H:RefreshGrid()
	if not self.editMode then return end
	if settings().grid then
		buildGrid()
		grid:Show()
	elseif grid then
		grid:Hide()
	end
end

-- Centre a box (or the selected one) horizontally on the screen.
function H:CenterSelected(o)
	o = o or selected
	if not o then
		H:Print("Select a frame first (click it), then centre it.")
		return
	end
	selectBox(o)
	Movers:CenterX(o.mover.key)
	sync(o)
end

--[[ Toolbar and keys ]]

local function buildBar()
	bar = CreateFrame("Frame", "HeraldryEditModeBar", UIParent)
	bar:SetSize(560, 64)
	bar:SetPoint("TOP", 0, -40)
	bar:SetFrameStrata("FULLSCREEN_DIALOG")
	bar:EnableMouse(true)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.055, 0.050, 0.045, 0.95)
	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("|cffE8B04BHeraldry|r edit mode")
	local help = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	help:SetText("Drag to move. Alt: no snapping. Arrows: nudge (Shift: 10). Wheel: scale. Right click: reset. Middle click or C: centre.")
	help:SetTextColor(0.62, 0.60, 0.56)

	local done = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	done:SetSize(70, 22)
	done:SetPoint("TOPRIGHT", -12, -10)
	done:SetText("Done")
	done:SetScript("OnClick", function() H:SetEditMode(false) end)

	local gridBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	gridBtn:SetSize(70, 22)
	gridBtn:SetPoint("RIGHT", done, "LEFT", -6, 0)
	gridBtn:SetText("Grid")
	gridBtn:SetScript("OnClick", function()
		settings().grid = not settings().grid
		H:RefreshGrid()
	end)

	local centerBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	centerBtn:SetSize(70, 22)
	centerBtn:SetPoint("RIGHT", gridBtn, "LEFT", -6, 0)
	centerBtn:SetText("Centre")
	centerBtn:SetScript("OnClick", function() H:CenterSelected() end)
	centerBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Centre horizontally")
		GameTooltip:AddLine("Puts the selected frame in the middle of the screen, at the same height.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	centerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Escape closes it (and with it, edit mode).
	tinsert(UISpecialFrames, "HeraldryEditModeBar")
	bar:SetScript("OnHide", function() if H.editMode then H:SetEditMode(false) end end)

	keys = CreateFrame("Frame", nil, UIParent)
	keys:SetScript("OnKeyDown", function(self, key)
		local step = IsShiftKeyDown() and 10 or 1
		local dx, dy = 0, 0
		if key == "LEFT" then dx = -step
		elseif key == "RIGHT" then dx = step
		elseif key == "UP" then dy = step
		elseif key == "DOWN" then dy = -step
		end
		if selected and key == "C" then
			self:SetPropagateKeyboardInput(false)
			H:CenterSelected()
		elseif selected and (dx ~= 0 or dy ~= 0) then
			self:SetPropagateKeyboardInput(false)
			local l, b, w, h = selected:GetRect()
			place(selected, l + dx, b + dy, w, h)
			save(selected)
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
end

--[[ On / off ]]

function H:SetEditMode(on)
	on = on and true or false
	if on == (self.editMode or false) then return end
	if on and InCombatLockdown() then
		self:Error("Edit mode isn't available in combat.")
		return
	end
	self.editMode = on
	if on then
		if not bar then buildBar() end
		for _, m in ipairs(Movers.list) do
			local o = overlays[m.key] or createOverlay(m)
			sync(o)
			paint(o)
			o:SetShown(Movers:IsMovable(m))
		end
		bar:Show()
		keys:EnableKeyboard(true)
		keys:Show()
		self:RefreshGrid()
		if #Movers.list == 0 then self:Print("Nothing to move yet: no module has registered a frame.") end
	else
		for _, o in pairs(overlays) do
			if o.dragging then o:StopMovingOrSizing() end
			o.dragging = false
			o:Hide()
		end
		dragging = nil
		guides(nil, nil)
		selectBox(nil)
		keys:EnableKeyboard(false)
		keys:Hide()
		if grid then grid:Hide() end
		bar:Hide()
	end
	self:Debug("Edit mode", on and "on" or "off")
	self:Fire("EDIT_MODE", on)
end

-- Re-checks which boxes should show (a module turned something on or off).
function H:RefreshEditMode()
	if not self.editMode then return end
	for _, m in ipairs(Movers.list) do
		local o = overlays[m.key]
		if o then o:SetShown(Movers:IsMovable(m)) end
	end
end

function H:ToggleEditMode()
	self:SetEditMode(not self.editMode)
end

-- A mover registered while edit mode is open gets its box right away.
H:On("MOVER_ADDED", function(_, m)
	if H.editMode then createOverlay(m):SetShown(Movers:IsMovable(m)) end
end)

H:On("PROFILE_CHANGED", function()
	if H.editMode then
		for _, o in pairs(overlays) do paint(o) end
	end
end)

H:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	if H.editMode then
		H:SetEditMode(false)
		H:Print("Edit mode closed: you entered combat.")
	end
end)
