--[[
	Heraldry_ActionBars - Art.lua
	Theme art on the bars: a frame around each button, and for a bar a plate
	behind it, rails along its top and bottom and crests at both ends.

	Everything is drawn with the active theme's pieces (Core/Themes.lua), so a
	new theme only brings files and numbers. Missing pieces fall back to the
	Standard theme; a missing button frame falls back to a simple 1px border.

	Runs from LayoutBar, so always out of combat.
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars
local Themes = H.Themes

-- One screen pixel, in the units of a frame.
local function pixel(frame)
	local _, ph = GetPhysicalScreenSize()
	return 768 / ph / frame:GetEffectiveScale()
end

--[[ Button frames ]]

local function setGameArt(b, shown)
	b.hdHideArt = not shown
	local n = b.NormalTexture or (b.GetNormalTexture and b:GetNormalTexture())
	if n then n:SetAlpha(shown and 1 or 0) end
	local icon = b.icon or b.Icon
	if icon then
		if shown then icon:SetTexCoord(0, 1, 0, 1) else icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	end
end

local function buttonArt(b)
	if b.hdArt then return b.hdArt end
	local f = CreateFrame("Frame", nil, b)
	f:SetAllPoints(b)
	f:SetFrameLevel(b:GetFrameLevel() + 4)
	f.tex = f:CreateTexture(nil, "OVERLAY")
	f.edges = {}
	for i = 1, 4 do
		local t = f:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(0, 0, 0, 1)
		f.edges[i] = t
	end
	-- The game puts its border art back on some updates: keep it hidden.
	local n = b.NormalTexture
	if n then
		local function hide(t) if b.hdHideArt then t:SetAlpha(0) end end
		hooksecurefunc(n, "SetAtlas", hide)
		if n.SetTexture then hooksecurefunc(n, "SetTexture", hide) end
	end
	b.hdArt = f
	return f
end

-- Thin border in the theme's metal (black without a theme accent).
local function simpleBorder(f, b)
	local px = pixel(b) * 2
	local e = f.edges
	local r, g, bl = Themes:Accent()
	for i = 1, 4 do e[i]:SetColorTexture(r or 0, g or 0, bl or 0, 1) end
	e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(px)
	e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(px)
	e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(px)
	e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(px)
	for i = 1, 4 do e[i]:Show() end
end

-- style: "ornate" | "slim" | "simple" | "game"
function AB:StyleButton(b, style, size)
	local f = buttonArt(b)
	if style == "game" then
		setGameArt(b, true)
		f:Hide()
		return
	end
	local piece = (style == "ornate" and Themes:Piece("button.frame")) or (style == "slim" and Themes:Piece("button.frameSlim"))
	setGameArt(b, false)
	f:Show()
	if not piece then
		f.tex:Hide()
		simpleBorder(f, b)
		return
	end
	for i = 1, 4 do f.edges[i]:Hide() end
	-- Scale the art so its hole matches the button exactly.
	local h = piece.hole
	local kx, ky = size / (h[3] - h[1]), size / (h[4] - h[2])
	local t = f.tex
	t:SetTexture(piece.file)
	t:SetTexCoord(0, 1, 0, 1)
	Themes:Paint(t)
	t:ClearAllPoints()
	t:SetSize(piece.size[1] * kx, piece.size[2] * ky)
	t:SetPoint("TOPLEFT", b, "TOPLEFT", -h[1] * kx, h[2] * ky)
	t:Show()
end

--[[ Plate, rails and crests ]]

local function barArt(bar)
	if bar.hdArt then return bar.hdArt end
	bar.hdArt = {
		plate = bar:CreateTexture(nil, "BACKGROUND", nil, -6),
		railTop = bar:CreateTexture(nil, "BACKGROUND", nil, 2),
		railBottom = bar:CreateTexture(nil, "BACKGROUND", nil, 2),
		capLeft = bar:CreateTexture(nil, "BACKGROUND", nil, 4),
		capRight = bar:CreateTexture(nil, "BACKGROUND", nil, 4),
	}
	return bar.hdArt
end

-- width: total length; ext: how far it runs past each end of the plate.
local function rail(t, piece, plate, width, height, top, ext)
	local band = piece.band
	local tileW = height * piece.size[1] / (band[2] - band[1])
	local t1, t2 = band[1] / piece.size[2], band[2] / piece.size[2]
	t:SetTexture(piece.file, "REPEAT", "CLAMP")
	Themes:Paint(t)
	if top then
		t:SetTexCoord(0, width / tileW, t1, t2)
	else
		t:SetTexCoord(0, width / tileW, t2, t1)   -- flipped: the bottom rail mirrors the top
	end
	t:ClearAllPoints()
	local edge = top and "TOP" or "BOTTOM"
	t:SetPoint("LEFT", plate, edge .. "LEFT", -ext, 0)
	t:SetPoint("RIGHT", plate, edge .. "RIGHT", ext, 0)
	t:SetHeight(height)
	t:Show()
end

function AB:ApplyBarArt(bar)
	local n = bar.n
	local art = barArt(bar)
	local scale = bar:GetScale()

	-- Buttons
	local style = self:Get(n, "frame")
	for _, b in ipairs(bar.buttons) do
		if b:GetParent() == bar then self:StyleButton(b, style, bar.base) end
	end

	-- Plate. While joined, bar 1 draws one plate up to the top of bar 2
	-- (the block) and bar 2 draws none.
	local joined = self:IsJoined()
	local block = joined and n == 1
	local plate = self:Get(n, "plate") and not (joined and n == 2)
		and Themes:Piece(block and "block.plate" or "bar.plate")
	if not plate then
		for _, t in pairs(art) do t:Hide() end
		return
	end
	local pad = self:Get(n, "pad") / scale
	local p = art.plate
	p:ClearAllPoints()
	if block then
		p:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -pad, -pad)
		p:SetPoint("RIGHT", bar, "RIGHT", pad, 0)
		p:SetPoint("TOP", self.bars[2], "TOP", 0, pad)
	else
		p:SetPoint("TOPLEFT", bar, "TOPLEFT", -pad, pad)
		p:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pad, -pad)
	end
	if plate.file then
		p:SetTexture(plate.file)
		p:SetTexCoord(0, 1, 0, 1)
		Themes:Paint(p)
	else
		p:SetDesaturation(0)
		p:SetVertexColor(1, 1, 1)
		p:SetColorTexture(unpack(plate.color))
	end
	p:Show()
	local width = bar:GetWidth() + 2 * pad
	local height = bar:GetHeight() + 2 * pad   -- one row: crests never grow with the block

	-- Rails, running past the plate (under the orbs)
	local railPiece = self:Get(n, "rails") and Themes:Piece("bar.rail")
	if railPiece then
		local rh = self:Get(n, "railSize") / scale
		local ext = self:Get(n, "railExtend") / scale
		rail(art.railTop, railPiece, p, width + 2 * ext, rh, true, ext)
		rail(art.railBottom, railPiece, p, width + 2 * ext, rh, false, ext)
	else
		art.railTop:Hide()
		art.railBottom:Hide()
	end

	-- Crests: only on bars wider than tall (a tall plate would make them huge).
	local cap = self:Get(n, "caps") and width > height and Themes:Piece("bar.cap")
	if cap then
		local j = cap.join
		local k = height / j[3]
		for _, side in ipairs({ "Left", "Right" }) do
			local t = art["cap" .. side]
			t:SetTexture(cap.file)
			Themes:Paint(t)
			t:ClearAllPoints()
			t:SetSize(cap.size[1] * k, cap.size[2] * k)
			if side == "Left" then
				t:SetTexCoord(0, 1, 0, 1)
				t:SetPoint("TOPLEFT", p, "LEFT", -j[1] * k, j[2] * k)
			else
				t:SetTexCoord(1, 0, 0, 1)   -- mirrored
				t:SetPoint("TOPRIGHT", p, "RIGHT", j[1] * k, j[2] * k)
			end
			t:Show()
		end
	else
		art.capLeft:Hide()
		art.capRight:Hide()
	end
end
