--[[
	Heraldry_Minimap - Minimap.lua
	The minimap in the TimelessUI Paladin minimap frame (prototype M1): the
	lion and hammer on the top left corner, three sockets on the right and a
	plate at the bottom. Like the target's plaque, every part has a fixed
	place in the frame, measured once (FRAME below), so nothing moves when the
	frame is resized.

	  top socket      the game's day/night and calendar button (GameTimeFrame)
	  middle socket   a button that shows or hides the addons' minimap buttons,
	                  gathered in a panel next to the frame
	  bottom socket   the new mail icon (shown by the game when there is mail)
	  plate           zone name, and the clock under it

	The game's minimap is taken out of its cluster and set in our frame; the
	rest of the cluster (border, zone text, zoom buttons) is hidden. The map is
	cut to the frame's window with a mask, and the mouse wheel zooms.
]]

local H = Heraldry
local Themes = H.Themes
local M = "Interface\\AddOns\\Heraldry_Minimap\\Media\\"

local MM = H:NewModule("Minimap", {
	label = "Minimap",
	fonts = true,
	defaults = {
		size = 230,             -- width of the whole frame
		zoneShow = true,  zoneSize = 12, zoneX = 0, zoneY = 6,
		clockShow = true, clockSize = 10, clockX = 0, clockY = -7,
		clock24 = true,
		wheelZoom = true,
		addonColumns = 4,
		addonSize = 26,
	},
})

-- Geometry of Media\Frame.tga (pixels of the 1024 x 1024 file).
MM.FRAME = {
	file = M .. "Frame",
	size = 1024,
	window = { 196, 217, 847, 755 },          -- the map's opening
	sockets = { { 890, 184 }, { 897, 477 }, { 882, 807 } },
	socketSize = 104,                         -- what fits inside a socket
	plate = { 200, 768, 806, 860 },           -- the zone plate
	mask = M .. "Mask",                       -- the window's shape, for the map
	art = { 17, 89, 999, 905 },               -- where the art is: the frame is cut to it
}

-- the theme's frame (piece "minimap.frame"), or this one
function MM:Frame()
	return H.Themes:Piece("minimap.frame") or self.FRAME
end

MM.TEXTS = {
	{ key = "zone",  label = "Zone" },
	{ key = "clock", label = "Clock" },
}

local hidden = CreateFrame("Frame")
hidden:Hide()

-- PvP colour of the zone text, as the game uses it.
local ZONE_COLOR = {
	sanctuary = { 0.41, 0.80, 0.94 },
	arena     = { 1.00, 0.10, 0.10 },
	friendly  = { 0.10, 1.00, 0.10 },
	hostile   = { 1.00, 0.10, 0.10 },
	contested = { 1.00, 0.70, 0.00 },
	combat    = { 1.00, 0.10, 0.10 },
}

local function text(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetWordWrap(false)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

-- Blizzard parts, looked up by every name they have had.
local function find(...)
	for i = 1, select("#", ...) do
		local path = select(i, ...)
		local obj = _G
		for part in path:gmatch("[^%.]+") do
			obj = obj and obj[part]
		end
		if obj then return obj end
	end
end

--[[ Building ]]

function MM:Create()
	local f = CreateFrame("Frame", "HeraldryMinimap", UIParent)
	f:SetFrameStrata("LOW")
	f:SetFrameLevel(5)

	-- the map sits under the frame's art
	local holder = CreateFrame("Frame", nil, f)
	holder:SetFrameLevel(f:GetFrameLevel() + 1)
	f.holder = holder

	local art = CreateFrame("Frame", nil, f)
	art:SetAllPoints()
	art:SetFrameLevel(f:GetFrameLevel() + 10)
	f.art = art
	f.tex = art:CreateTexture(nil, "ARTWORK")
	f.tex:SetTexture(self:Frame().file)
	f.tex:SetAllPoints()

	-- sockets: holders for the game's buttons and ours
	f.sockets = {}
	for i = 1, 3 do
		local s = CreateFrame("Frame", nil, f)
		s:SetFrameLevel(f:GetFrameLevel() + 12)
		-- the game's buttons tell their parent to re-lay itself out (they live
		-- in layout frames in the cluster): our sockets accept and ignore that
		s.Layout = function() end
		s.MarkDirty = function() end
		s.MarkClean = function() end
		f.sockets[i] = s
	end

	local texts = CreateFrame("Frame", nil, f)
	texts:SetAllPoints()
	texts:SetFrameLevel(f:GetFrameLevel() + 14)
	f.zone = text(texts)
	f.clock = text(texts)

	self.frame = f
	self:CreateAddonButton()
	return f
end

-- Take the game's minimap out of its cluster and into our frame.
function MM:TakeMinimap()
	local ok, err = pcall(self.TakeMinimapSteps, self)
	if not ok then H:Error("Minimap: " .. tostring(err)) end
end

function MM:TakeMinimapSteps()
	local f, mm = self.frame, Minimap
	if not mm then return end
	mm:SetParent(f.holder)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", f.holder, "CENTER")
	mm:SetMaskTexture(self:Frame().mask)
	mm:SetFrameLevel(f.holder:GetFrameLevel())
	-- the game sometimes puts it back: keep it in our holder
	if not self.hookedMinimap then
		self.hookedMinimap = true
		hooksecurefunc(mm, "SetParent", function(_, parent)
			if parent ~= f.holder and not MM.restoring then
				C_Timer.After(0, function() mm:SetParent(f.holder) end)
			end
		end)
	end

	for _, fn in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetScale" }) do
		hooksecurefunc(mm, fn, function()
			if not MM.fitting then C_Timer.After(0, function() MM:FitMap() end) end
		end)
	end

	-- the cluster's own dressing goes away
	for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
		"MinimapZoneTextButton", "MiniMapWorldMapButton", "MinimapCompassTexture", "MinimapBackdrop",
		"MinimapNorthTag", "MinimapCluster.BorderTop", "MinimapCluster.ZoneTextButton",
		"Minimap.ZoomIn", "Minimap.ZoomOut", "Minimap.ZoomHitArea" }) do
		local obj = find(name)
		if obj and obj ~= mm and obj.SetParent then obj:SetParent(hidden) end
	end

	-- day/night and calendar, and the mail icon, into the sockets
	local day = find("GameTimeFrame", "MinimapCluster.GameTimeFrame")
	if day then self:Socket(1, day) end
	-- the mail icon: the game's own frame for it (its parent re-lays it out,
	-- see the sockets' Layout above)
	local mail = find("MiniMapMailFrame", "MinimapCluster.IndicatorFrame.MailFrame", "MinimapCluster.MailFrame")
	if mail then self:Socket(3, mail) end
	H:Debug("Minimap: day/night", day and (day:GetName() or "found") or "missing", "- mail", mail and (mail:GetName() or "found") or "missing")

	if MinimapCluster then MinimapCluster:SetParent(hidden) end

	-- zoom with the mouse wheel
	mm:EnableMouseWheel(true)
	mm:SetScript("OnMouseWheel", function(map, delta)
		if not MM.db.wheelZoom then return end
		local z = map:GetZoom() + (delta > 0 and 1 or -1)
		if z >= 0 and z <= map:GetZoomLevels() - 1 then map:SetZoom(z) end
	end)
end

-- Put a frame in a socket, sized to fit; the game may move it back.
function MM:Socket(i, obj)
	local s = self.frame.sockets[i]
	s.content = obj
	obj:SetParent(s)
	obj:ClearAllPoints()
	obj:SetPoint("CENTER", s, "CENTER")
	if not obj.heraldryHooked then
		obj.heraldryHooked = true
		hooksecurefunc(obj, "SetPoint", function(o)
			if o.heraldryMoving then return end
			o.heraldryMoving = true
			o:ClearAllPoints()
			o:SetPoint("CENTER", s, "CENTER")
			o.heraldryMoving = nil
		end)
	end
end

--[[ Addon buttons ]]

-- Minimap buttons that addons add (LibDBIcon and the like): anything left
-- on the minimap that is a button and not one of the game's.
local GAME = { MinimapPing = true, MiniMapTrackingButton = true, MiniMapTracking = true }

local function addonLike(child)
	local name = child:GetName()
	local game = GAME[name or ""] or (name and (name:find("Queue") or name:find("LFG") or name:find("Battlefield")
		or name:find("Tracking") or name:find("^Heraldry") or name:find("^GameTime") or name:find("^MiniMapMail")))
	if game then return false end
	return (name and name:find("^LibDBIcon10_")) or child.icon or child.Icon or (name and name:find("Minimap")) and true or false
end

function MM:CollectAddonButtons()
	self.addonButtons = self.addonButtons or {}
	local seen = {}
	for _, b in ipairs(self.addonButtons) do seen[b] = true end
	local function add(b)
		if b and not seen[b] and b ~= self.frame and not b:IsForbidden() then
			self.addonButtons[#self.addonButtons + 1] = b
			seen[b] = true
		end
	end
	-- buttons left in the game's minimap cluster (we took the map out of it)
	if MinimapCluster then
		for _, child in ipairs({ MinimapCluster:GetChildren() }) do
			if child:IsObjectType("Button") and addonLike(child) then add(child) end
		end
	end
	-- LibDBIcon buttons wherever they are
	for name, obj in pairs(_G) do
		if type(name) == "string" and name:find("^LibDBIcon10_") and type(obj) == "table" and obj.GetObjectType then add(obj) end
	end
	-- buttons the player put there (/hui grab)
	for name in pairs(H.global.minimapGrab or {}) do
		local b = _G[name]
		if type(b) == "table" and b.GetObjectType then add(b) end
	end
	for _, child in ipairs({ Minimap:GetChildren() }) do
		local name = child:GetName()
		local isButton = child:IsObjectType("Button") or (name and name:find("^LibDBIcon10_"))
		local game = GAME[name or ""] or (name and (name:find("Queue") or name:find("LFG") or name:find("Battlefield") or name:find("Tracking")))
		if isButton and not seen[child] and not game and child ~= self.frame then
			if (name and name:find("^LibDBIcon10_")) or child.icon or child.Icon or (name and name:find("Minimap")) then
				self.addonButtons[#self.addonButtons + 1] = child
				seen[child] = true
			end
		end
	end
	return self.addonButtons
end

function MM:CreateAddonButton()
	local f = self.frame
	local b = CreateFrame("Button", nil, f.sockets[2])
	b:SetAllPoints()
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
	b.icon:SetPoint("CENTER")
	local mask = b:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	mask:SetAllPoints(b.icon)
	b.icon:AddMaskTexture(mask)
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	b:SetScript("OnClick", function() MM:ToggleAddons() end)
	b:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
		GameTooltip:SetText("Addons")
		GameTooltip:AddLine("Show or hide the addons' minimap buttons.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.addonButton = b

	-- the panel the buttons are gathered in (dark glass, level 3)
	local p = CreateFrame("Frame", "HeraldryMinimapAddons", f)
	p:SetFrameStrata("MEDIUM")
	p:Hide()
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetAllPoints()
	p.bg:SetColorTexture(0.03, 0.03, 0.035, 0.9)
	p.rim = {}
	for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = p:CreateTexture(nil, "BORDER")
		t:SetColorTexture(1, 1, 1, 1)
		t:SetPoint(pts[1])
		t:SetPoint(pts[2])
		if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
		p.rim[i] = t
	end
	f.addonPanel = p
end

-- Lay the gathered buttons out in the panel, to the left of the frame.
function MM:ArrangeAddons()
	local p, db = self.frame.addonPanel, self.db
	local list = self:CollectAddonButtons()
	local size, gap, cols = db.addonSize, 4, math.max(1, db.addonColumns)
	for i, b in ipairs(list) do
		b:SetParent(p)
		b:ClearAllPoints()
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 6 + col * (size + gap), -6 - row * (size + gap))
		b:SetSize(size, size)
		b:Show()
	end
	local n = #list
	local rows = math.max(1, math.ceil(n / cols))
	p:SetSize(12 + math.min(n, cols) * (size + gap) - gap, 12 + rows * (size + gap) - gap)
	if n == 0 then p:SetSize(140, 30) end
	p:ClearAllPoints()
	p:SetPoint("TOPRIGHT", self.frame.sockets[2], "TOPLEFT", -8, 0)
	local ar, ag, ab = Themes:Accent()
	for _, t in ipairs(p.rim) do
		if ar then t:SetVertexColor(ar, ag, ab, 0.9) else t:SetVertexColor(0.4, 0.4, 0.42, 0.9) end
	end
	if not p.empty then
		p.empty = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		p.empty:SetPoint("CENTER")
		p.empty:SetText("No addon buttons")
	end
	p.empty:SetShown(n == 0)
end

function MM:ToggleAddons()
	local p = self.frame.addonPanel
	if p:IsShown() then
		p:Hide()
	else
		self:ArrangeAddons()
		p:Show()
	end
end

-- /hui grab: the button under the mouse joins the panel (kept by name, every character)
H.commands = H.commands or {}
H.commands.grab = function()
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	local f = foci and foci[1]
	-- climb to the first named frame (the button, not its icon)
	while f and not f:GetName() and f:GetParent() do f = f:GetParent() end
	local name = f and f:GetName()
	if not name or f == UIParent or f == WorldFrame or name:find("^Heraldry") then
		H:Error("Point the mouse at an addon's button, then type /hui grab.")
		return
	end
	H.global.minimapGrab = H.global.minimapGrab or {}
	H.global.minimapGrab[name] = true
	H:Print(("'%s' now lives in the minimap's addon panel."):format(name))
	MM:ArrangeAddons()
	if not MM.frame.addonPanel:IsShown() then MM.frame.addonPanel:Hide() end
end

--[[ Texts ]]

function MM:UpdateZone()
	local f = self.frame
	if not f then return end
	f.zone:SetText(GetMinimapZoneText and GetMinimapZoneText() or GetZoneText() or "")
	local pvp = GetZonePVPInfo and GetZonePVPInfo()
	local c = ZONE_COLOR[pvp or ""] or { 1, 0.86, 0.5 }
	f.zone:SetTextColor(c[1], c[2], c[3])
end

function MM:UpdateClock()
	local f = self.frame
	if not f or not self.db.clockShow then return end
	f.clock:SetText(date(self.db.clock24 and "%H:%M" or "%I:%M %p"))
end

--[[ Layout ]]

-- The map fills the window; the game resizes and re-anchors it at times
-- (its edit mode, the cluster's layout), so it is put back every time.
function MM:FitMap()
	local mm, f = Minimap, self.frame
	if not mm or mm:GetParent() ~= f.holder or not self.mapSize then return end
	self.fitting = true
	mm:SetScale(1)
	mm:SetSize(self.mapSize, self.mapSize)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", f.holder, "CENTER")
	self.fitting = nil
	-- the map only redraws at its new size after a zoom change
	local z = mm:GetZoom()
	mm:SetZoom(z > 0 and z - 1 or z + 1)
	mm:SetZoom(z)
end


function MM:Layout()
	local f, db, F = self.frame, self.db, self:Frame()
	f.tex:SetTexture(F.file)
	if Minimap and Minimap:GetParent() == f.holder then pcall(Minimap.SetMaskTexture, Minimap, F.mask) end
	local size = db.size
	local k = size / F.size
	-- the frame is only as big as the art (the file has empty margins), so it can
	-- go right up to the screen's edges; every position below is from its corner
	local a = F.art
	local ox, oy = a[1], a[2]
	f:SetSize((a[3] - a[1]) * k, (a[4] - a[2]) * k)
	f.tex:SetTexCoord(a[1] / F.size, a[3] / F.size, a[2] / F.size, a[4] / F.size)
	Themes:Paint(f.tex)

	-- the map: a square as wide as the window, cut to it by the mask
	local w = F.window
	local ww, wh = (w[3] - w[1]) * k, (w[4] - w[2]) * k
	f.holder:ClearAllPoints()
	f.holder:SetPoint("TOPLEFT", f, "TOPLEFT", (w[1] - ox) * k, -(w[2] - oy) * k)
	f.holder:SetSize(ww, wh)
	self.mapSize = ww
	self:FitMap()

	-- sockets
	local s = F.socketSize * k
	for i, pos in ipairs(F.sockets) do
		local sock = f.sockets[i]
		sock:ClearAllPoints()
		sock:SetPoint("CENTER", f, "TOPLEFT", (pos[1] - ox) * k, -(pos[2] - oy) * k)
		sock:SetSize(s, s)
		local c = sock.content
		if c then
			local cw = c:GetWidth()
			if cw and cw > 0 then c:SetScale(s / cw * 0.9) end
		end
	end
	f.addonButton.icon:SetSize(s * 0.7, s * 0.7)

	-- texts on the plate: zone, and the clock under it
	local pl = F.plate
	local px, py = ((pl[1] + pl[3]) / 2 - ox) * k, -((pl[2] + pl[4]) / 2 - oy) * k
	H.Fonts:Apply(f.zone, "header", db.zoneSize, self)
	H.Fonts:Apply(f.clock, "body", db.clockSize, self)
	f.zone:ClearAllPoints()
	f.zone:SetPoint("CENTER", f, "TOPLEFT", px + db.zoneX, py + db.zoneY)
	f.zone:SetWidth((pl[3] - pl[1]) * k)
	f.clock:ClearAllPoints()
	f.clock:SetPoint("CENTER", f, "TOPLEFT", px + db.clockX, py + db.clockY)
	f.zone:SetShown(db.zoneShow)
	f.clock:SetShown(db.clockShow)

	if f.addonPanel:IsShown() then self:ArrangeAddons() end
	H.Movers:Apply(f.mover)
	self:UpdateZone()
	self:UpdateClock()
end

--[[ Lifecycle ]]

function MM:OnEnable()
	local f = self:Create()
	f.mover = H:RegisterMover(f, "Minimap.frame", {
		label = "Minimap", default = { "TOPRIGHT", -20, -20 }, scalable = true,
	})
	self:Layout()
	self:TakeMinimap()
	self:Layout()

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function() MM:UpdateZone() end)

	-- the clock ticks every few seconds
	local t = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		if t > 5 then
			t = 0
			MM:UpdateClock()
		end
	end)

	-- addons create their buttons late: gather them once they are there
	C_Timer.After(3, function()
		if Minimap and Minimap:GetParent() ~= MM.frame.holder then
			H:Print("Minimap: the game moved the map out of the frame (parent: " .. tostring(Minimap:GetParent() and Minimap:GetParent():GetName()) .. ").")
		end
		local p = MM.frame.addonPanel
		MM:ArrangeAddons()
		p:Hide()
	end)

	H:On("THEME_CHANGED", function() MM:Layout() end)
	H:On("FONTS_CHANGED", function() MM:Layout() end)
	self:Layout()
end

function MM:OnProfileChanged()
	self:Layout()
end
