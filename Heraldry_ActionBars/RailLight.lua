--[[
	Heraldry_ActionBars - RailLight.lua
	A rail that lights up: shared by the swing bar (the block's top rail) and
	the player's cast bar (the bottom rail).

	The art sits right over one of the block's rails, with the rail's tiles
	lined up, or on a separate holder frame of its own (with a mover). It has a
	dim copy of the rail, two lit pieces (from the left and from the right), an
	overlay for warnings (red) and two sparks. It is a plain child of bar 1, so
	it hides with the bars in vehicles and pet battles; bar 1's scale is undone
	and its fading ignored.
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars
local Themes = H.Themes

local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

local RL = {}
AB.RailLight = RL

-- name: global frame name; key/label: the mover of the separate bar;
-- isShown: whether the separate bar gets a box in edit mode
function RL.New(name, key, label, default, isShown)
	local f = CreateFrame("Frame", name, AB.bars[1] or UIParent)
	f:SetIgnoreParentAlpha(true)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(20)
	f.dim = f:CreateTexture(nil, "BACKGROUND")
	f.left = f:CreateTexture(nil, "ARTWORK")
	f.right = f:CreateTexture(nil, "ARTWORK")
	f.warn = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.warn:SetColorTexture(1, 0.15, 0.1, 0.45)
	f.warn:SetBlendMode("ADD")
	f.sparkL = f:CreateTexture(nil, "OVERLAY")
	f.sparkR = f:CreateTexture(nil, "OVERLAY")
	for _, t in ipairs({ f.sparkL, f.sparkR }) do
		t:SetTexture(SPARK)
		t:SetBlendMode("ADD")
	end
	f:SetAlpha(0)
	f.holder = CreateFrame("Frame", name .. "Holder", UIParent)
	f.holder:SetSize(10, 10)
	f.mover = H:RegisterMover(f.holder, key, { label = label, default = default, scalable = true, isShown = isShown })
	return f
end

-- texture coordinates: tiles of the theme's rail, `tileW` pixels long
local function geometry(h)
	local piece = Themes:Piece("bar.rail")
	if not piece then return nil, 1, 0, 1 end   -- a theme without rails (Standard): a plain bar
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
function RL.BlockWidth()
	local bar = AB.bars[1]
	local plate = bar and bar.hdArt and bar.hdArt.plate
	if plate and plate:IsShown() then
		local w = plate:GetWidth()
		if w and w > 0 then return w * bar:GetScale() end
	end
end

-- o.rail: the block's rail texture to sit on (nil: the separate bar of size
-- o.width x o.height); o.flip: the rail is drawn upside down (bottom rail);
-- o.dim: brightness of the unlit rail. Returns whether it sits on the rail.
function RL.Layout(f, o)
	local bar1 = AB.bars[1]
	f:SetScale(1 / bar1:GetScale())   -- measured in UIParent pixels
	local onRail = o.rail and o.rail:IsShown()
	local W, h
	f:ClearAllPoints()
	if onRail then
		f:SetAllPoints(o.rail)
		W, h = o.rail:GetWidth() * bar1:GetScale(), o.rail:GetHeight() * bar1:GetScale()
	else
		W, h = o.width, o.height
		f.holder:SetSize(W, h)
		f:SetAllPoints(f.holder)
	end
	local piece, tileW, t1, t2 = geometry(h)
	if onRail and o.flip then t1, t2 = t2, t1 end
	f.W, f.h, f.tileW, f.t1, f.t2, f.flat = W, h, tileW, t1, t2, not piece

	paint(f.dim, piece, o.dim)
	f.dim:SetTexCoord(0, piece and W / tileW or 1, t1, t2)
	f.dim:SetAllPoints(f)
	paint(f.left, piece, 1)
	paint(f.right, piece, 1)
	f.left:ClearAllPoints()
	f.left:SetPoint("TOPLEFT")
	f.left:SetPoint("BOTTOMLEFT")
	f.right:ClearAllPoints()
	f.right:SetPoint("TOPRIGHT")
	f.right:SetPoint("BOTTOMRIGHT")
	for _, t in ipairs({ f.sparkL, f.sparkR }) do t:SetSize(h * 0.9, h * 2.2) end
	return onRail
end

-- light `w` pixels of the rail, from the left or from the right
function RL.Light(f, t, w, fromRight)
	if w < 0.5 then t:Hide() return end
	t:SetWidth(math.min(w, f.W))
	w = math.min(w, f.W)
	if f.flat then
		t:SetTexCoord(0, 1, 0, 1)
	elseif fromRight then
		t:SetTexCoord((f.W - w) / f.tileW, f.W / f.tileW, f.t1, f.t2)
	else
		t:SetTexCoord(0, w / f.tileW, f.t1, f.t2)
	end
	t:Show()
end

-- a spark `x` pixels from the left edge
function RL.Spark(f, t, x, shown)
	if not shown then t:Hide() return end
	t:ClearAllPoints()
	t:SetPoint("CENTER", f, "LEFT", x, 0)
	t:Show()
end

-- the red overlay over the last `w` pixels (or the whole rail with w = nil)
function RL.Warn(f, w, alpha)
	if w == false then f.warn:Hide() return end
	f.warn:ClearAllPoints()
	f.warn:SetPoint("TOPRIGHT")
	f.warn:SetPoint("BOTTOMRIGHT")
	f.warn:SetWidth(w or f.W)
	f.warn:SetAlpha(alpha or 1)
	f.warn:Show()
end
