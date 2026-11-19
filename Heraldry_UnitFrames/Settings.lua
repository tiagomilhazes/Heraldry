--[[
	Heraldry_UnitFrames - Settings.lua
	One page for the whole module, "Unit frames". One tab per frame (Target,
	Target of target, Focus, Party, Raid), each with its own row of
	tabs for the settings, plus a Font tab (the module's font, for every frame).
]]

local H = Heraldry
local UF = H.Modules.byName.UnitFrames

local function field(name)
	return function() return UF.db[name] end, function(v)
		UF.db[name] = v
		UF:Layout()
	end
end

local function smallField(prefix, name)
	return function() return UF.db[prefix .. name] end, function(v)
		UF.db[prefix .. name] = v
		local s = UF.small[prefix]
		if s and s.frame then s:Layout() end
	end
end

local selectedText = "name"
local function pctFormat(v) return math.floor(v * 100 + 0.5) .. "%" end

--[[ Target ]]

local target = {
	size = function(page)
			page:Section("Size")
			local get, set = field("width")
			page:Slider({ label = "Width", min = 140, max = 420, step = 2, get = get, set = set })
			get, set = field("healthHeight")
			page:Slider({ label = "Life bar height", min = 8, max = 40, step = 1, get = get, set = set })
			get, set = field("showPower")
			page:Toggle({ label = "Show the power bar", get = get, set = set })
			get, set = field("powerHeight")
			page:Slider({ label = "Power bar height", min = 3, max = 20, step = 1, get = get, set = set })
	end,
	text = function(page)
			page:Dropdown({
				label = "Text",
				desc = "Every option below applies to this text.",
				values = function()
					local t = {}
					for _, it in ipairs(UF.TEXTS) do t[#t + 1] = { value = it.key, text = it.label } end
					return t
				end,
				get = function() return selectedText end,
				set = function(v) selectedText = v end,
			})
			local function sel(suffix)
				return function() return UF.db[selectedText .. suffix] end, function(v)
					UF.db[selectedText .. suffix] = v
					UF:Layout()
				end
			end
			page:Section("Look")
			local get, set = sel("Show")
			page:Toggle({ label = "Show", get = get, set = set })
			get, set = sel("Size")
			page:Slider({ label = "Size", min = 6, max = 30, step = 1, get = get, set = set })
			page:Section("Position")
			get, set = sel("X")
			page:Slider({ label = "Offset X", desc = "Right is positive.", min = -100, max = 100, step = 1, get = get, set = set })
			get, set = sel("Y")
			page:Slider({ label = "Offset Y", desc = "Up is positive.", min = -50, max = 50, step = 1, get = get, set = set })
			page:Button({
				label = "Reset this text",
				text = "Reset",
				onClick = function()
					for _, suffix in ipairs({ "Show", "Size", "X", "Y" }) do UF.db[selectedText .. suffix] = nil end
					UF:Layout()
					page:Refresh()
				end,
			})
	end,
	look = function(page)
			page:Section("Style")
			local get, set = field("style")
			page:Dropdown({
				label = "Style",
				desc = "Plaque: a heraldic plaque whose metal and jewels show what the target is. Minimal: a dark glass panel. The plaque's size follows the bar heights (Size tab).",
				values = function()
					return { { value = "plaque", text = "Plaque" }, { value = "minimal", text = "Minimal" } }
				end,
				get = function() return UF:Style() end, set = set,
			})
			page:Section("Colours")
			get, set = field("classColor")
			page:Toggle({ label = "Class colour for players", desc = "Off: players use the reaction colour, like NPCs.", get = get, set = set })
			get, set = field("emblem")
			page:Dropdown({
				label = "Class emblem for players",
				desc = "Plaque: players get their class emblem in the medallions instead of the lions. Coloured: the party frames' enamelled symbols. Metal: the same symbols in the plaque's metal.",
				values = function()
					return { { value = "colour", text = "Coloured" }, { value = "metal", text = "Metal" }, { value = "off", text = "Off (lions)" } }
				end,
				get = get, set = set,
			})
			page:Section("Minimal")
			get, set = field("showGem")
			page:Toggle({ label = "Show the gem", desc = "The level, and a halo for elite, rare and boss units.", get = get, set = set })
			get, set = field("gemSize")
			page:Slider({ label = "Gem size", min = 20, max = 60, step = 1, get = get, set = set })
			get, set = field("panelAlpha")
			page:Slider({ label = "Panel opacity", min = 0, max = 1, step = 0.05, format = pctFormat, get = get, set = set })
	end,
	behaviour = function(page)
			page:Section("Behaviour")
			local get, set = field("hideBlizzard")
			page:Toggle({ label = "Hide the game's target frame", get = get, set = set })
			page:Section("Casts")
			get, set = field("castInPower")
			page:Toggle({ label = "Show casts in the power row", desc = "While the target casts, its power bar turns into the cast bar. Needs the power bar (Size tab).", get = get, set = set })
	end,
}

--[[ Target of target and focus (Small.lua) ]]

local function small(prefix, extra)
	return {
		size = function(page)
			page:Section("Size")
			local get, set = smallField(prefix, "Width")
			page:Slider({ label = "Width", min = 80, max = 320, step = 2, get = get, set = set })
			get, set = smallField(prefix, "HealthHeight")
			page:Slider({ label = "Life bar height", min = 6, max = 30, step = 1, get = get, set = set })
			if extra.power then
				get, set = smallField(prefix, "ShowPower")
				page:Toggle({ label = "Show the power bar", get = get, set = set })
				get, set = smallField(prefix, "PowerHeight")
				page:Slider({ label = "Power bar height", min = 3, max = 16, step = 1, get = get, set = set })
			end
		end,
		text = function(page)
			page:Section("Text")
			local get, set = smallField(prefix, "NameSize")
			page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
			get, set = smallField(prefix, "PctSize")
			page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
		end,
		behaviour = function(page)
			page:Section("Behaviour")
			local get, set = smallField(prefix, "Show")
			page:Toggle({ label = "Show this frame", desc = "Takes effect after /reload.", get = get, set = set })
			if extra.dock then
				get, set = smallField(prefix, "Dock")
				page:Toggle({ label = "Attach to the target", desc = "It follows the target; you can still drag it in edit mode. Off: on its own.", get = get, set = set })
			end
			if extra.blizzard then
				get, set = smallField(prefix, "HideBlizzard")
				page:Toggle({ label = "Hide the game's focus frame", get = get, set = set })
			end
		end,
	}
end

--[[ Party (Party.lua) ]]

local function pf(name)
	return function() return UF.db["party" .. name] end, function(v)
		UF.db["party" .. name] = v
		UF:LayoutParty()
	end
end

local party = {
	size = function(page)
		page:Section("Each member")
		local get, set = pf("Width")
		page:Slider({ label = "Width", desc = "Cartouche and banner: only the bar block stretches.", min = 80, max = 400, step = 2, get = get, set = set })
		get, set = pf("Height")
		page:Slider({ label = "Height (cartouche, banner)", desc = "Height of the bar block; the symbol and the rest of the art follow.", min = 30, max = 120, step = 1, get = get, set = set })
		get, set = pf("LifeFill")
		page:Slider({ label = "Life bar thickness (cartouche)", desc = "Share of its slot the bar fills.", min = 0.3, max = 1, step = 0.05, format = pctFormat, get = get, set = set })
		get, set = pf("PowerFill")
		page:Slider({ label = "Mana bar thickness (cartouche)", min = 0.2, max = 1, step = 0.05, format = pctFormat, get = get, set = set })
		page:Section("Compact style")
		get, set = pf("HealthHeight")
		page:Slider({ label = "Life bar height", min = 6, max = 40, step = 1, get = get, set = set })
		get, set = pf("ShowPower")
		page:Toggle({ label = "Show the power bar", get = get, set = set })
		get, set = pf("PowerHeight")
		page:Slider({ label = "Power bar height", min = 2, max = 16, step = 1, get = get, set = set })
		page:Section("Layout")
		get, set = pf("Direction")
		page:Dropdown({
			label = "Grow",
			values = function() return {
				{ value = "down", text = "Down (a column)" },
				{ value = "up", text = "Up (a column)" },
				{ value = "right", text = "Right (a row)" },
				{ value = "left", text = "Left (a row)" },
			} end,
			get = get, set = set,
		})
		get, set = pf("Spacing")
		page:Slider({ label = "Space between members", min = 0, max = 40, step = 1, get = get, set = set })

	end,
	text = function(page)
		page:Section("Text")
		local get, set = pf("NameSize")
		page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
		get, set = pf("PctSize")
		page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
	end,
	look = function(page)
		page:Section("Style")
		local get, set = pf("Style")
		page:Dropdown({
			label = "Style",
			desc = "Cartouche: one framed piece with the class symbol, life, mana and a debuff gem. Banner: the same piece with the symbol on top, narrower for a party in a row. Compact: slim rows with a class jewel.",
			values = function() return { { value = "cartouche", text = "Cartouche" }, { value = "banner", text = "Banner (for a row)" }, { value = "compact", text = "Compact" } } end,
			get = get, set = set,
		})
		get, set = pf("Muted")
		page:Toggle({ label = "Toned-down bar colours", desc = "Class and power colours darkened to sit with the metal. Off: the game's bright colours.", get = get, set = set })
		get, set = pf("LowLife")
		page:Slider({ label = "Low life (compact)", desc = "The rim turns red below this.", min = 0.1, max = 0.6, step = 0.05,
			format = pctFormat, get = get, set = set })
		page:Section("Debuff jewel")
		get, set = pf("Debuff")
		page:Toggle({ label = "Show the debuff's colour", desc = "Cartouche: the gem takes the colour of magic, curse, disease or poison.", get = get, set = set })
		get, set = pf("DispelOnly")
		page:Toggle({ label = "Only debuffs you can remove", get = get, set = set })
		page:Section("Other")
		get, set = pf("Leader")
		page:Toggle({ label = "Crown on the group leader", get = get, set = set })
		page:Text("The life bar follows the target's class colour option; the rims use the theme's metal.", 20)
	end,
	behaviour = function(page)
		page:Section("Who shows")
		local get, set = pf("Show")
		page:Toggle({ label = "Show the party frames", desc = "Takes effect after /reload.", get = get, set = set })
		get, set = pf("Player")
		page:Toggle({ label = "Show yourself in the party", desc = "Takes effect after /reload.", get = get, set = set })
		get, set = pf("InRaid")
		page:Toggle({ label = "Show in a raid", get = get, set = set })
		page:Section("Range")
		get, set = pf("Range")
		page:Toggle({ label = "Fade members out of range", get = get, set = set })
		get, set = pf("RangeAlpha")
		page:Slider({ label = "Faded to", min = 0.1, max = 0.9, step = 0.05, format = pctFormat, get = get, set = set })
		page:Section("Game frames")
		get, set = pf("HideBlizzard")
		page:Toggle({ label = "Hide the game's party frames", get = get, set = set })
		page:Preview("party")
	end,
}

--[[ Raid (Raid.lua) ]]

local function rf(name)
	return function() return UF.db["raid" .. name] end, function(v)
		UF.db["raid" .. name] = v
		UF:LayoutRaid()
	end
end

local raid = {
	size = function(page)
		page:Section("Each member")
		local get, set = rf("Width")
		page:Slider({ label = "Width", min = 50, max = 220, step = 2, get = get, set = set })
		get, set = rf("Height")
		page:Slider({ label = "Height", min = 16, max = 60, step = 1, get = get, set = set })
		get, set = rf("Spacing")
		page:Slider({ label = "Space between members", min = 0, max = 20, step = 1, get = get, set = set })
		get, set = rf("Power")
		page:Toggle({ label = "Show the power bar", get = get, set = set })
		get, set = rf("PowerHeight")
		page:Slider({ label = "Power bar height", min = 2, max = 12, step = 1, get = get, set = set })
		page:Section("Groups")
		get, set = rf("GroupsPerRow")
		page:Slider({ label = "Groups per row", desc = "Banners: each row hangs from one rod and rolls up as one. 4 fits 20 and 40 raids; 3 suits 25.", min = 1, max = 8, step = 1, get = get, set = set })
		get, set = rf("GroupSpacing")
		page:Slider({ label = "Space between groups", min = 0, max = 60, step = 1, get = get, set = set })
		get, set = rf("RodSize")
		page:Slider({ label = "Rod size (banners)", min = 10, max = 30, step = 1, get = get, set = set })
	end,
	text = function(page)
		page:Section("Text")
		local get, set = rf("NameSize")
		page:Slider({ label = "Name size", min = 6, max = 20, step = 1, get = get, set = set })
		get, set = rf("PctShow")
		page:Toggle({ label = "Show the life percentage", desc = "Also shows Dead and Offline.", get = get, set = set })
		get, set = rf("PctSize")
		page:Slider({ label = "Percentage size", min = 6, max = 20, step = 1, get = get, set = set })
	end,
	look = function(page)
		page:Section("Style")
		local get, set = rf("Style")
		page:Dropdown({
			label = "Style",
			desc = "Banners: each row of groups is one parchment sheet hanging from the theme's rod; click the rod to roll the row up. Tiles: every group in one framed panel.",
			values = function() return { { value = "banner", text = "Banners (roll up)" }, { value = "tiles", text = "Tiles" } } end,
			get = get, set = set,
		})
		get, set = rf("Paper")
		page:Dropdown({
			label = "Paper (banners)",
			values = function()
				local list = {}
				for _, k in ipairs(H.Paper.ORDER) do list[#list + 1] = { value = k, text = H.Paper:Get(k).label } end
				return list
			end,
			get = get, set = set,
		})
		get, set = rf("Muted")
		page:Toggle({ label = "Toned-down class colours", get = get, set = set })
		page:Section("Debuffs")
		get, set = rf("Debuff")
		page:Toggle({ label = "Show the debuff's colour", desc = "Banners: a small jewel on the member. Tiles: the tile's rim.", get = get, set = set })
		get, set = rf("DispelOnly")
		page:Toggle({ label = "Only debuffs you can remove", get = get, set = set })
	end,
	behaviour = function(page)
		page:Section("Who shows")
		local get, set = rf("Show")
		page:Toggle({ label = "Show the raid frames", desc = "Takes effect after /reload.", get = get, set = set })
		get, set = rf("ShowEmpty")
		page:Toggle({ label = "Show empty groups", get = get, set = set })
		page:Section("Rolled-up groups")
		get, set = rf("Warn")
		page:Toggle({ label = "Rod glows red when a member dies", desc = "Only for rolled-up groups.", get = get, set = set })
		page:Button({ label = "Open every group", text = "Open all", onClick = function()
			if InCombatLockdown() then H:Error("Can't change the raid in combat.") return end
			H.char.raidRolled = nil
			UF:LayoutRaid()
		end })
		page:Section("Range")
		get, set = rf("Range")
		page:Toggle({ label = "Fade members out of range", get = get, set = set })
		get, set = rf("RangeAlpha")
		page:Slider({ label = "Faded to", min = 0.1, max = 0.9, step = 0.05, format = pctFormat, get = get, set = set })
		page:Section("Game frames")
		get, set = rf("HideBlizzard")
		page:Toggle({ label = "Hide the game's raid frames", get = get, set = function(v) set(v) UF:RaidBlizzard() end })
		page:Preview("raid")
	end,
}

--[[ Indicators (Indicators.lua): one editor for raid and party ]]

local IND = UF.Ind
local selected = 1
local POINT_LABEL = {
	TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right", LEFT = "Left", CENTER = "Centre",
	RIGHT = "Right", BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right",
}

local function sel()
	local n = #IND:List()
	if selected > n then selected = n end
	if selected < 1 then selected = 1 end
	return selected
end

local function indField(key)
	return function() return IND:Get(sel(), key) end, function(v) IND:Set(sel(), key, v) end
end

local function rebuild() H.Panel:Rebuild("unitframes") end

-- the editor block: a member drawn large with the indicators on it and the
-- 9 points to click, and the list of indicators beside it
local function editor(page)
	local UI, C = H.UI, H.UI.colors
	local list = IND:List()
	local ROW = 28
	local rows = math.max(#list, 5)
	local blockH = math.max(230, 34 + rows * ROW + 40)
	local f = CreateFrame("Frame", nil, page.frame)
	page:Place(f, blockH, 12)

	-- left: the stage
	local stage = CreateFrame("Frame", nil, f)
	stage:SetPoint("TOPLEFT")
	stage:SetPoint("BOTTOMLEFT")
	stage:SetWidth(math.floor(page.width * 0.5))
	UI.Fill(stage, { 0, 0, 0, 0.35 })
	UI.Border(stage, C.border)
	local hint = UI.Text(stage, 11, C.faint, nil, "CENTER")
	hint:SetPoint("BOTTOM", 0, 10)
	hint:SetText("Click a point to move the selected indicator there")

	local W, Hh = UF.db.raidWidth, UF.db.raidHeight
	local scale = math.min(2.2, (stage:GetWidth() - 60) / W, (blockH - 70) / Hh)
	local m = CreateFrame("Frame", nil, stage)
	m:SetSize(W, Hh)
	m:SetScale(scale)
	m:SetPoint("CENTER", stage, "CENTER", 0, 10 / scale)
	local bg = m:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.04, 0.03, 0.025, 0.95)
	local life = m:CreateTexture(nil, "BORDER")
	life:SetPoint("TOPLEFT", 1, -1)
	life:SetPoint("BOTTOMLEFT", 1, UF.db.raidPowerHeight + 1)
	life:SetWidth((W - 2) * 0.72)
	life:SetColorTexture(0.62, 0.45, 0.24)
	local power = m:CreateTexture(nil, "BORDER")
	power:SetPoint("BOTTOMLEFT", 1, 1)
	power:SetPoint("BOTTOMRIGHT", -1, 1)
	power:SetHeight(UF.db.raidPowerHeight)
	power:SetColorTexture(0.2, 0.32, 0.8)
	local name = m:CreateFontString(nil, "OVERLAY")
	H.Fonts:Apply(name, "body", UF.db.raidNameSize, UF)
	name:SetPoint("LEFT", 5, 2)
	name:SetText("Julian")
	name:SetTextColor(0.96, 0.92, 0.84)
	IND:Attach(m, m, "editor")

	-- the 9 points
	local dots = {}
	local holder = CreateFrame("Frame", nil, m)
	holder:SetAllPoints()
	holder:SetFrameLevel(m.hInd:GetFrameLevel() + 20)
	for _, p in ipairs(IND.POINTS) do
		local d = CreateFrame("Button", nil, holder)
		local s = 7
		d:SetSize(s, s)
		d:SetPoint(p, holder, p, (p:find("LEFT") and -s / 2) or (p:find("RIGHT") and s / 2) or 0,
			(p:find("TOP") and s / 2) or (p:find("BOTTOM") and -s / 2) or 0)
		d.fill = d:CreateTexture(nil, "OVERLAY")
		d.fill:SetAllPoints()
		d.fill:SetColorTexture(1, 1, 1, 1)
		d:SetScript("OnClick", function()
			if #IND:List() == 0 then return end
			IND:Set(sel(), "point", p)
			page:Refresh()
		end)
		d:SetScript("OnEnter", function(self) self.hover = true page:Refresh() end)
		d:SetScript("OnLeave", function(self) self.hover = false page:Refresh() end)
		dots[p] = d
	end

	-- right: the list
	local side = CreateFrame("Frame", nil, f)
	side:SetPoint("TOPLEFT", stage, "TOPRIGHT", 14, 0)
	side:SetPoint("BOTTOMRIGHT")
	local head = UI.Text(side, 12, C.dim)
	head:SetPoint("TOPLEFT", 2, -4)
	head:SetText("Indicators")
	local rowsF = {}
	for i = 1, #list do
		local r = CreateFrame("Button", nil, side)
		r:SetHeight(ROW - 2)
		r:SetPoint("TOPLEFT", 0, -22 - (i - 1) * ROW)
		r:SetPoint("TOPRIGHT", 0, -22 - (i - 1) * ROW)
		r.bg = UI.Fill(r, C.row)
		r.mark = UI.Tex(r, C.accent, "ARTWORK")
		r.mark:SetPoint("TOPLEFT")
		r.mark:SetPoint("BOTTOMLEFT")
		r.mark:SetWidth(3)
		r.swatch = r:CreateTexture(nil, "ARTWORK")
		r.swatch:SetSize(14, 14)
		r.swatch:SetPoint("LEFT", 10, 0)
		r.text = UI.Text(r, 12, C.text)
		r.text:SetPoint("LEFT", r.swatch, "RIGHT", 8, 0)
		r.text:SetPoint("RIGHT", -96, 0)
		r.text:SetWordWrap(false)
		r.where = UI.Text(r, 11, C.dim, nil, "RIGHT")
		r.where:SetPoint("RIGHT", -10, 0)
		r:SetScript("OnClick", function() selected = i page:Refresh() end)
		r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(C.rowHover)) end)
		r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(C.row)) end)
		rowsF[i] = r
	end
	if #list == 0 then
		local none = UI.Text(side, 12, C.faint)
		none:SetPoint("TOPLEFT", 2, -30)
		none:SetText("No indicators yet. Add one, or take your class's.")
	end

	-- the buttons under the list
	local function btn(text, w, x, onClick, kind)
		local b = UI.Button(side, text, w, kind)
		b:SetPoint("BOTTOMLEFT", x, 0)
		b:SetScript("OnClick", onClick)
		return b
	end
	btn("Add", 60, 0, function() selected = IND:Add() rebuild() end)
	btn("Remove", 70, 66, function()
		if #IND:List() == 0 then return end
		IND:Remove(sel())
		rebuild()
	end, "danger")
	btn("Up", 40, 142, function() selected = IND:Move(sel(), -1) page:Refresh() end)
	btn("Down", 50, 188, function() selected = IND:Move(sel(), 1) page:Refresh() end)
	local reset = UI.Button(side, "Class defaults", 110)
	reset:SetPoint("BOTTOMRIGHT", 0, 0)
	reset:SetScript("OnClick", function()
		UI.Confirm("Replace your indicators with your class's?", "Replace", function()
			IND:ResetToClass()
			selected = 1
			rebuild()
		end)
	end)

	page:OnRefresh(function()
		local L = IND:List()
		local s = sel()
		for i, r in ipairs(rowsF) do
			local d = L[i]
			if d then
				local look = IND:Get(i, "look")
				local icon = look == "icon" and IND:SpellIcon(i)
				if icon then
					r.swatch:SetTexture(icon)
					r.swatch:SetVertexColor(1, 1, 1)
				else
					local c = IND:Get(i, "color")
					r.swatch:SetColorTexture(c[1], c[2], c[3])
				end
				local first = IND:Spells(i).list[1]
				local more = #IND:Spells(i).list - 1
				local label = first and tostring(first) .. (more > 0 and (" +" .. more) or "") or "(no spell yet)"
				if IND:Get(i, "missing") then label = label .. "  (missing)" end
				r.text:SetText(label)
				r.text:SetTextColor(unpack(IND:Get(i, "enabled") and C.text or C.faint))
				r.where:SetText(POINT_LABEL[IND:Get(i, "point")] or "")
				r.mark:SetShown(i == s)
				r.where:SetTextColor(unpack(i == s and C.accent or C.dim))
			end
		end
		local p = IND:Get(s, "point")
		for key, d in pairs(dots) do
			local on = #L > 0 and key == p
			if on then d.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
			elseif d.hover then d.fill:SetColorTexture(1, 1, 1, 0.9)
			else d.fill:SetColorTexture(1, 1, 1, 0.3) end
		end
		IND:Fake(m, 2)
	end)
end

local indicators = function(page)
	page:Text("Auras you keep up on others, shown where you want them on each member: heals over time, shields, buffs that are missing. The list is per character.", 30)
	editor(page)
	if #IND:List() == 0 then return end

	page:Section("Spells")
	page:Input({
		label = "Spells",
		desc = "Names or spell IDs, comma separated. Any of them lights the indicator.",
		placeholder = "Rejuvenation, 774",
		button = "Save",
		maxLetters = 600,
		get = function() return IND:Get(sel(), "spells") end,
		onSubmit = function(text) IND:Set(sel(), "spells", text) return true end,
	})
	local get, set = indField("enabled")
	page:Toggle({ label = "Show this indicator", get = get, set = set })
	get, set = indField("mine")
	page:Toggle({ label = "Only mine", desc = "Only auras you cast: not another druid's Rejuvenation.", get = get, set = set })
	get, set = indField("missing")
	page:Toggle({ label = "Show when missing", desc = "Lights when none of the spells is on the member: buffs to keep up.", get = get, set = set })

	page:Section("Look")
	get, set = indField("look")
	page:Dropdown({
		label = "Look",
		values = function() return {
			{ value = "icon", text = IND.LOOKS.icon }, { value = "square", text = IND.LOOKS.square },
			{ value = "bar", text = IND.LOOKS.bar }, { value = "text", text = IND.LOOKS.text },
		} end,
		get = get, set = set,
	})
	page:Color({
		label = "Colour", desc = "Of the square and the bar.",
		get = function() local c = IND:Get(sel(), "color") return c[1], c[2], c[3] end,
		set = function(r, g, b) IND:Set(sel(), "color", { r, g, b }) end,
	})
	get, set = indField("size")
	page:Slider({ label = "Size", desc = "The bar's thickness is a third of it.", min = 4, max = 40, step = 1, get = get, set = set })
	get, set = indField("length")
	page:Slider({ label = "Bar length", min = 8, max = 200, step = 1, get = get, set = set })
	get, set = indField("drain")
	page:Toggle({ label = "Icon darkens as it runs out", get = get, set = set })

	page:Section("Place")
	page:Text("The point is chosen on the member above; these move it from there.", 20)
	get, set = indField("x")
	page:Slider({ label = "Offset X", desc = "Right is positive.", min = -60, max = 60, step = 1, get = get, set = set })
	get, set = indField("y")
	page:Slider({ label = "Offset Y", desc = "Up is positive.", min = -40, max = 40, step = 1, get = get, set = set })

	page:Section("Time and stacks")
	get, set = indField("time")
	page:Dropdown({
		label = "Time left",
		values = function() return {
			{ value = "inside", text = "Inside" }, { value = "below", text = "Below" },
			{ value = "above", text = "Above" }, { value = "none", text = "Hidden" },
		} end,
		get = get, set = set,
	})
	get, set = indField("timeSize")
	page:Slider({ label = "Text size", min = 6, max = 22, step = 1, get = get, set = set })
	get, set = indField("warn")
	page:Slider({ label = "Warn at", desc = "Turns red and pulses from this many seconds left: time to renew.", min = 0, max = 10, step = 1,
		format = function(v) return v == 0 and "Off" or (v .. " s") end, get = get, set = set })
	get, set = indField("stacks")
	page:Toggle({ label = "Stacks", desc = "In the corner, when the aura has more than one.", get = get, set = set })

	page:Section("Where")
	get, set = field("indRaid")
	page:Toggle({ label = "On the raid frames", get = get, set = function(v) set(v) IND:LayoutAll() end })
	get, set = field("indParty")
	page:Toggle({ label = "On the party frames", desc = "On the life bar of each member.", get = get, set = function(v) set(v) IND:LayoutAll() end })
end

local tot = small("tot", { dock = true })
local focus = small("focus", { power = true, blizzard = true })

H:RegisterOptionsPage({
	key = "unitframes",
	label = "Unit frames",
	desc = "Target, target of target, focus, party and raid.",
	group = "modules",
	order = 30,
	tabs = {
		{ key = "target", label = "Target", tabs = {
			{ key = "size", label = "Size", build = target.size },
			{ key = "text", label = "Text", build = target.text },
			{ key = "look", label = "Look", build = target.look },
			{ key = "behaviour", label = "Behaviour", build = target.behaviour },
		} },
		{ key = "tot", label = "Target of target", tabs = {
			{ key = "size", label = "Size", build = tot.size },
			{ key = "text", label = "Text", build = tot.text },
			{ key = "behaviour", label = "Behaviour", build = tot.behaviour },
		} },
		{ key = "focus", label = "Focus", tabs = {
			{ key = "size", label = "Size", build = focus.size },
			{ key = "text", label = "Text", build = focus.text },
			{ key = "behaviour", label = "Behaviour", build = focus.behaviour },
		} },
		{ key = "party", label = "Party", tabs = {
			{ key = "size", label = "Size", build = party.size },
			{ key = "text", label = "Text", build = party.text },
			{ key = "look", label = "Look", build = party.look },
			{ key = "behaviour", label = "Behaviour", build = party.behaviour },
		} },
		{ key = "raid", label = "Raid", tabs = {
			{ key = "size", label = "Size", build = raid.size },
			{ key = "text", label = "Text", build = raid.text },
			{ key = "look", label = "Look", build = raid.look },
			{ key = "behaviour", label = "Behaviour", build = raid.behaviour },
		} },
		{ key = "indicators", label = "Indicators", build = indicators },
		{ key = "font", label = "Font", build = function(page)
			page:Text("The font is the module's: it applies to every unit frame.", 20)
			page:FontSection(UF, function() UF:Layout() end)
		end },
	},
})
