--[[
	Heraldry_Options - Panel.lua
	The settings window: sidebar with pages grouped as Heraldry / Modules,
	header with the page title, an optional row of tabs, scrolling content,
	footer with Reload.

	A page is either one page (build) or a set of tabs:
		tabs = { { key = "block", label = "Block", build = function(page) end }, ... }
	The last tab opened on each page is remembered.
	Drag it by any empty area. Escape closes it.
	Position, scale and the last page are saved in HeraldryDB.global.options.
]]

local H = Heraldry
local UI = H.UI
local C = UI.colors
local O = H.Options

local Panel = {}
H.Panel = Panel

local PANEL_W, PANEL_H = 980, 640
local SIDEBAR_W, HEADER_H, FOOTER_H, PAD = 210, 78, 46, 24
local TAB_H = 34
local CONTENT_W = PANEL_W - SIDEBAR_W - PAD * 2 - 12

local GROUPS = {
	core    = { label = "HERALDRY", order = 1 },
	modules = { label = "MODULES",  order = 2 },
}

H.global.options = H.global.options or {}
local settings = H.global.options

local frame, scroll, title, subtitle, tabBar
local navButtons, tabButtons = {}, {}
local current, currentPage

local function groupOf(def)
	return GROUPS[def.group] or GROUPS.modules
end

local function sortedPages()
	local list = {}
	for _, def in pairs(O.pages) do list[#list + 1] = def end
	table.sort(list, function(a, b)
		local ga, gb = groupOf(a).order, groupOf(b).order
		if ga ~= gb then return ga < gb end
		local oa, ob = a.order or 100, b.order or 100
		if oa ~= ob then return oa < ob end
		return a.label < b.label
	end)
	return list
end

local function savePosition()
	local p, _, rp, x, y = frame:GetPoint()
	settings.point = { p, rp, x, y }
end

local function buildNav(sidebar)
	local y = -92
	local lastGroup
	for _, def in ipairs(sortedPages()) do
		local g = groupOf(def)
		if g ~= lastGroup then
			if lastGroup then y = y - 18 end   -- breathing room between groups
			lastGroup = g
			local gt = UI.Text(sidebar, 11, C.faint)
			gt:SetPoint("TOPLEFT", 20, y - 6)
			gt:SetText(g.label)
			y = y - 28
		end
		local b = CreateFrame("Button", nil, sidebar)
		b:SetSize(SIDEBAR_W, 32)
		b:SetPoint("TOPLEFT", 0, y)
		b.key = def.key
		b.bg = UI.Fill(b, C.navSelected)
		b.bg:Hide()
		b.mark = UI.Tex(b, C.accent, "ARTWORK")
		b.mark:SetPoint("TOPLEFT")
		b.mark:SetPoint("BOTTOMLEFT")
		b.mark:SetWidth(3)
		b.mark:Hide()
		b.text = UI.Text(b, 13, C.dim)
		b.text:SetPoint("LEFT", 20, 0)
		b.text:SetText(def.label)
		b:SetScript("OnEnter", function(self)
			if current ~= self.key then self.text:SetTextColor(unpack(C.text)) end
		end)
		b:SetScript("OnLeave", function(self)
			if current ~= self.key then self.text:SetTextColor(unpack(C.dim)) end
		end)
		b:SetScript("OnClick", function(self) Panel:Select(self.key) end)
		navButtons[def.key] = b
		y = y - 32
	end
end

local function buildScrollBar()
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
	bar:SetWidth(4)
	UI.Fill(bar, { 1, 1, 1, 0.05 })
	local thumb = UI.Tex(bar, { 1, 1, 1, 0.25 }, "ARTWORK")
	thumb:SetWidth(4)

	local function update()
		local range = scroll:GetVerticalScrollRange()
		local h = scroll:GetHeight()
		if range <= 0 or h <= 0 then
			bar:Hide()
			return
		end
		bar:Show()
		local th = math.max(24, h * h / (h + range))
		thumb:SetHeight(th)
		thumb:SetPoint("TOP", bar, "TOP", 0, -(h - th) * (scroll:GetVerticalScroll() / range))
	end
	scroll:SetScript("OnScrollRangeChanged", update)
	scroll:SetScript("OnVerticalScroll", update)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = self:GetVerticalScroll() - delta * 48
		self:SetVerticalScroll(math.max(0, math.min(v, self:GetVerticalScrollRange())))
	end)
end

function Panel:Build()
	frame = CreateFrame("Frame", "HeraldryOptionsFrame", UIParent)
	frame:SetSize(PANEL_W, PANEL_H)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	local pt = settings.point
	if pt then
		frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
	else
		frame:SetPoint("CENTER")
	end
	frame:SetScale(settings.scale or 1)
	UI.Fill(frame, C.bg)
	UI.Border(frame, C.borderStrong)
	tinsert(UISpecialFrames, "HeraldryOptionsFrame")
	UI.root = frame

	-- Sidebar
	local sidebar = CreateFrame("Frame", nil, frame)
	sidebar:SetPoint("TOPLEFT", 1, -1)
	sidebar:SetPoint("BOTTOMLEFT", 1, 1)
	sidebar:SetWidth(SIDEBAR_W)
	UI.Fill(sidebar, C.sidebar)
	local sep = UI.Tex(sidebar, C.border, "ARTWORK")
	sep:SetPoint("TOPRIGHT")
	sep:SetPoint("BOTTOMRIGHT")
	sep:SetWidth(1)
	local logo = UI.Text(sidebar, 24, C.accent)
	logo:SetPoint("TOPLEFT", 20, -24)
	logo:SetText("Heraldry")
	local ver = UI.Text(sidebar, 11, C.faint)
	ver:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 1, -6)
	ver:SetText("v" .. H.version)
	buildNav(sidebar)

	-- Header
	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", SIDEBAR_W + 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER_H)
	UI.Fill(header, C.header)
	local hline = UI.Tex(header, C.border, "ARTWORK")
	hline:SetPoint("BOTTOMLEFT")
	hline:SetPoint("BOTTOMRIGHT")
	hline:SetHeight(1)
	title = UI.Text(header, 20, C.text)
	title:SetPoint("TOPLEFT", PAD, -20)
	subtitle = UI.Text(header, 12, C.dim)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local close = UI.Button(header, "X", 28)
	close:SetPoint("TOPRIGHT", -14, -14)
	close:SetScript("OnClick", function() frame:Hide() end)

	-- Footer
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetPoint("BOTTOMLEFT", SIDEBAR_W + 1, 1)
	footer:SetPoint("BOTTOMRIGHT", -1, 1)
	footer:SetHeight(FOOTER_H)
	local fline = UI.Tex(footer, C.border, "ARTWORK")
	fline:SetPoint("TOPLEFT")
	fline:SetPoint("TOPRIGHT")
	fline:SetHeight(1)
	local note = UI.Text(footer, 11, C.faint)
	note:SetPoint("LEFT", PAD, 0)
	note:SetText("Changes are saved as you make them.")
	local reload = UI.Button(footer, "Reload UI", 110)
	reload:SetPoint("RIGHT", -PAD, 0)
	reload:SetScript("OnClick", ReloadUI)

	-- Content
	scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", SIDEBAR_W + PAD, -(HEADER_H + PAD))
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + 12), FOOTER_H + 10)

	-- Tabs, under the header (shown only for pages that have them)
	tabBar = CreateFrame("Frame", nil, frame)
	tabBar:SetPoint("TOPLEFT", SIDEBAR_W + 1, -(HEADER_H + 1))
	tabBar:SetPoint("TOPRIGHT", -1, -(HEADER_H + 1))
	tabBar:SetHeight(TAB_H)
	UI.Fill(tabBar, C.sidebar)
	local tline = UI.Tex(tabBar, C.border, "ARTWORK")
	tline:SetPoint("BOTTOMLEFT")
	tline:SetPoint("BOTTOMRIGHT")
	tline:SetHeight(1)
	tabBar:Hide()
	scroll:EnableMouseWheel(true)
	buildScrollBar()
end

local function anchorScroll(withTabs)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", SIDEBAR_W + PAD, -(HEADER_H + (withTabs and TAB_H or 0) + PAD))
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + 12), FOOTER_H + 10)
end

local function tabButton(i)
	local b = tabButtons[i]
	if b then return b end
	b = CreateFrame("Button", nil, tabBar)
	b:SetHeight(TAB_H)
	b.text = UI.Text(b, 13, C.dim, nil, "CENTER")
	b.text:SetPoint("CENTER", 0, 1)
	b.line = UI.Tex(b, C.accent, "OVERLAY")
	b.line:SetPoint("BOTTOMLEFT", 10, 0)
	b.line:SetPoint("BOTTOMRIGHT", -10, 0)
	b.line:SetHeight(2)
	b:SetScript("OnEnter", function(self) if not self.on then self.text:SetTextColor(unpack(C.text)) end end)
	b:SetScript("OnLeave", function(self) if not self.on then self.text:SetTextColor(unpack(C.dim)) end end)
	b:SetScript("OnClick", function(self) Panel:Select(current, self.key) end)
	tabButtons[i] = b
	return b
end

local function showTabs(def, active)
	local x = PAD - 10
	for i, t in ipairs(def.tabs) do
		local b = tabButton(i)
		b.key = t.key
		b.on = t.key == active
		b.text:SetText(t.label)
		b.text:SetTextColor(unpack(b.on and C.text or C.dim))
		b.line:SetShown(b.on)
		b:SetWidth(b.text:GetStringWidth() + 28)
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", x, 0)
		x = x + b:GetWidth()
		b:Show()
	end
	for i = #def.tabs + 1, #tabButtons do tabButtons[i]:Hide() end
	tabBar:Show()
end

-- The page object for a page or one of its tabs, built the first time.
local function pageFor(def, tabKey)
	local holder, build = def, def.build
	if tabKey then
		def._tabs = def._tabs or {}
		holder = def._tabs
		for _, t in ipairs(def.tabs) do
			if t.key == tabKey then build = t.build end
		end
		if not holder[tabKey] then
			holder[tabKey] = UI.NewPage(scroll, CONTENT_W)
			xpcall(build, geterrorhandler(), holder[tabKey])
		end
		return holder[tabKey]
	end
	if not def._page then
		def._page = UI.NewPage(scroll, CONTENT_W)
		xpcall(build, geterrorhandler(), def._page)
	end
	return def._page
end

function Panel:Select(key, tabKey)
	local def = O.pages[key]
	if not def then return end
	if currentPage then currentPage.frame:Hide() end

	for k, b in pairs(navButtons) do
		local on = k == key
		b.bg:SetShown(on)
		b.mark:SetShown(on)
		b.text:SetTextColor(unpack(on and C.text or C.dim))
	end
	current = key
	settings.page = key

	if def.tabs then
		settings.tabs = settings.tabs or {}
		tabKey = tabKey or settings.tabs[key]
		local valid = false
		for _, t in ipairs(def.tabs) do
			if t.key == tabKey then valid = true end
		end
		if not valid then tabKey = def.tabs[1].key end
		settings.tabs[key] = tabKey
		showTabs(def, tabKey)
		anchorScroll(true)
	else
		tabKey = nil
		tabBar:Hide()
		anchorScroll(false)
	end

	local page = pageFor(def, tabKey)
	currentPage = page
	scroll:SetScrollChild(page.frame)
	page.frame:Show()
	scroll:SetVerticalScroll(0)
	page:Refresh()
	title:SetText(def.label)
	subtitle:SetText(def.desc or "")
end

function Panel:Show(key)
	if not frame then self:Build() end
	frame:Show()
	if not (key and O.pages[key]) then key = current or settings.page end
	if not (key and O.pages[key]) then
		local first = sortedPages()[1]
		key = first and first.key
	end
	if key then self:Select(key) end
end

function Panel:Hide()
	if frame then frame:Hide() end
end

function Panel:IsShown()
	return frame ~= nil and frame:IsShown()
end

function Panel:Refresh()
	if currentPage then currentPage:Refresh() end
end

function Panel:SetScale(scale)
	settings.scale = scale
	if frame then frame:SetScale(scale) end
end
