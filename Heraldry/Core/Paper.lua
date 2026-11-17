--[[
	Heraldry - Core/Paper.lua
	The papers modules write on (chat, tooltips): dark parchment, light
	parchment and dark glass, plus the helpers every paper needs:

	  H.Paper:Apply(tex, kind, alpha)        paper picture (or glass colour) on a texture
	  H.Paper:Crop(tex, kind, w, h)          show the part with the area's shape, never stretched
	  H.Paper:Shades(list, kind, alpha)      soft dark edges (4 textures, left/right/top/bottom)
	  H.Paper:InkOf(r, g, b)                 any colour as ink for light paper: same hue,
	                                         dark and saturated; greys become brown ink
	  H.Paper:IsInk(kind)                    light paper: text is recoloured as ink
]]

local _, ns = ...
local H = ns.H

local P = {}
H.Paper = P

P.MEDIA = "Interface\\AddOns\\Heraldry\\Media\\Paper\\"

P.TYPES = {
	dark  = { label = "Dark parchment",  file = P.MEDIA .. "Dark",  size = { 512, 256 }, shade = 0.45 },
	light = { label = "Light parchment", file = P.MEDIA .. "Light", size = { 512, 512 }, shade = 0.30, ink = true,
		text = { 0.16, 0.11, 0.06 } },
	glass = { label = "Dark glass",      color = { 0.035, 0.03, 0.025 }, shade = 0.35 },
}
P.ORDER = { "dark", "light", "glass" }

function P:Get(kind) return self.TYPES[kind] or self.TYPES.dark end
function P:IsInk(kind) return self:Get(kind).ink == true end

function P:Apply(tex, kind, alpha)
	local art = self:Get(kind)
	if art.file then
		tex:SetTexture(art.file)
		tex:SetVertexColor(1, 1, 1)
	else
		local c = art.color
		tex:SetColorTexture(c[1], c[2], c[3], 1)
		tex:SetTexCoord(0, 1, 0, 1)
	end
	tex:SetAlpha(alpha or 1)
	return art
end

function P:Crop(tex, kind, w, h)
	local art = self:Get(kind)
	if not art.size or not (w and h and w > 0 and h > 0) then return end
	local a, p = art.size[1] / art.size[2], w / h
	if p >= a then tex:SetTexCoord(0, 1, 0, a / p) else tex:SetTexCoord(0, p / a, 0, 1) end
end

local function gradient(tex, orientation, from, to)
	tex:SetColorTexture(1, 1, 1, 1)
	local ok = pcall(function()
		tex:SetGradient(orientation, CreateColor(unpack(from)), CreateColor(unpack(to)))
	end)
	tex:SetShown(ok)
end

-- list = 4 textures of the same parent; they are anchored to its edges
function P:Shades(list, kind, alpha, size)
	local art = self:Get(kind)
	local dark, clear = { 0, 0, 0, (art.shade or 0.4) * (alpha or 1) }, { 0, 0, 0, 0 }
	size = size or 12
	for _, t in ipairs(list) do t:ClearAllPoints() end
	list[1]:SetPoint("TOPLEFT"); list[1]:SetPoint("BOTTOMLEFT"); list[1]:SetWidth(size)
	list[2]:SetPoint("TOPRIGHT"); list[2]:SetPoint("BOTTOMRIGHT"); list[2]:SetWidth(size)
	list[3]:SetPoint("TOPLEFT"); list[3]:SetPoint("TOPRIGHT"); list[3]:SetHeight(size)
	list[4]:SetPoint("BOTTOMLEFT"); list[4]:SetPoint("BOTTOMRIGHT"); list[4]:SetHeight(size)
	gradient(list[1], "HORIZONTAL", dark, clear)
	gradient(list[2], "HORIZONTAL", clear, dark)
	gradient(list[3], "VERTICAL", clear, dark)
	gradient(list[4], "VERTICAL", dark, clear)
end

local function hue2rgb(p, q, t)
	if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
	if t < 1 / 6 then return p + (q - p) * 6 * t end
	if t < 1 / 2 then return q end
	if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
	return p
end

function P:InkOf(r, g, b)
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local l = (mx + mn) / 2
	local d = mx - mn
	if d < 0.15 then return 0.16, 0.11, 0.06 end
	local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
	local h
	if mx == r then h = (g - b) / d + (g < b and 6 or 0)
	elseif mx == g then h = (b - r) / d + 2
	else h = (r - g) / d + 4 end
	h = h / 6
	if h > 0.12 and h < 0.2 then h = 0.1 end   -- yellows read as mud on parchment: amber instead
	s, l = math.max(s, 0.65), 0.3
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	return hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3)
end
