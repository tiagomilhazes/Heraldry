--[[
	Heraldry_Options - Style.lua
	Colors, font and drawing helpers for the settings panel.
	Neutral dark look with a gold accent, the same for every theme.
]]

local H = Heraldry

local UI = {}
H.UI = UI

UI.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

UI.colors = {
	bg           = { 0.055, 0.050, 0.045, 0.97 },
	sidebar      = { 0.035, 0.032, 0.030, 1 },
	header       = { 0.075, 0.068, 0.060, 1 },
	menu         = { 0.090, 0.085, 0.075, 1 },
	input        = { 0.030, 0.028, 0.026, 1 },
	row          = { 1, 1, 1, 0.025 },
	rowHover     = { 1, 1, 1, 0.07 },
	navSelected  = { 1, 1, 1, 0.05 },
	border       = { 1, 1, 1, 0.08 },
	borderStrong = { 1, 1, 1, 0.16 },
	text         = { 0.93, 0.90, 0.84, 1 },
	dim          = { 0.62, 0.60, 0.56, 1 },
	faint        = { 0.42, 0.40, 0.37, 1 },
	accent       = { 0.910, 0.690, 0.294, 1 },   -- E8B04B
	accentDim    = { 0.400, 0.300, 0.130, 1 },
	danger       = { 0.880, 0.360, 0.320, 1 },
	control      = { 0.110, 0.100, 0.090, 1 },
	controlHover = { 0.160, 0.145, 0.125, 1 },
}

function UI.Tex(parent, color, layer)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(unpack(color))
	return t
end

-- Solid texture covering the whole parent.
function UI.Fill(parent, color, layer)
	local t = UI.Tex(parent, color, layer)
	t:SetAllPoints()
	return t
end

-- 1px border made of four textures. border:SetColor(r, g, b, a)
function UI.Border(frame, color, size)
	size = size or 1
	local b = {}
	local function edge(p1, p2, w, h)
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) else t:SetHeight(h) end
		b[#b + 1] = t
	end
	edge("TOPLEFT", "TOPRIGHT", nil, size)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, size)
	edge("TOPLEFT", "BOTTOMLEFT", size, nil)
	edge("TOPRIGHT", "BOTTOMRIGHT", size, nil)
	function b:SetColor(r, g, bl, a)
		for i = 1, 4 do self[i]:SetColorTexture(r, g, bl, a) end
	end
	b:SetColor(unpack(color or UI.colors.border))
	return b
end

function UI.Text(parent, size, color, layer, justify)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(UI.FONT, size or 12, "")
	fs:SetTextColor(unpack(color or UI.colors.text))
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- kind = nil | "danger"
function UI.Button(parent, text, width, kind)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 100, 24)
	b.bg = UI.Fill(b, UI.colors.control)
	b.border = UI.Border(b, UI.colors.borderStrong)
	b.label = UI.Text(b, 12, kind == "danger" and UI.colors.danger or UI.colors.text, nil, "CENTER")
	b.label:SetPoint("CENTER")
	b.label:SetText(text or "")
	b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(UI.colors.controlHover)) end)
	b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(UI.colors.control)) end)
	return b
end
