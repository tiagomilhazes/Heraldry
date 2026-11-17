--[[
	Heraldry_Options - Pages/Fonts.lua
	Typography for every module. Saved in the profile.
	Tabs: Fonts | Scale. Each tab shows a preview of what it changes.
]]

local H = Heraldry
local F = H.Fonts

local function fonts()
	local t = {}
	for _, name in ipairs(F:List()) do t[#t + 1] = { value = name, text = name } end
	return t
end

-- Two preview lines that follow the settings.
local function preview(page)
	page:Section("Preview")
	local head = page:Text("Theron Duskvow  ·  352 / 390", 30)
	local body = page:Text("F1  SZ  M4  x20  Seal of Righteousness", 26)
	page:OnRefresh(function()
		F:Apply(head, "header", 18)
		F:Apply(body, "body", 13)
		head:SetTextColor(0.93, 0.90, 0.84)
		body:SetTextColor(0.93, 0.90, 0.84)
	end)
end

H:RegisterOptionsPage({
	key = "fonts",
	label = "Fonts",
	desc = "Fonts used by every module. Modules choose sizes, and can override the font. Saved in the profile.",
	group = "core",
	order = 4,
	tabs = {
		{ key = "fonts", label = "Fonts", build = function(page)
			page:Section("Fonts")
			page:Dropdown({
				label = "Headings",
				desc = "Names, titles, big numbers (orbs).",
				values = fonts,
				get = function() return F:Get("header") end,
				set = function(v) F:Set("header", v) end,
			})
			page:Dropdown({
				label = "Text",
				desc = "Small text: keybinds, counts, details.",
				values = fonts,
				get = function() return F:Get("body") end,
				set = function(v) F:Set("body", v) end,
			})
			page:Dropdown({
				label = "Outline",
				values = function() return F.OUTLINES end,
				get = function() return F:Get("outline") end,
				set = function(v) F:Set("outline", v) end,
			})
			preview(page)
		end },

		{ key = "scale", label = "Scale", build = function(page)
			page:Section("Scale")
			page:Slider({
				label = "Text scale",
				desc = "Makes all text bigger or smaller, everywhere.",
				min = 0.7, max = 1.5, step = 0.05,
				format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
				get = function() return F:Get("scale") end,
				set = function(v) F:Set("scale", v) end,
			})
			preview(page)
		end },
	},
})
