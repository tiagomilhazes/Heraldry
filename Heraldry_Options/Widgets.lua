--[[
	Heraldry_Options - Widgets.lua
	Page builder used by every settings page (core and modules).

	page:Section(title [, desc])
	page:Text(textOrFunction [, height])
	page:Toggle   { label, desc, get, set }
	page:Slider   { label, desc, min, max, step, format, get, set, onRelease }
	page:Dropdown { label, desc, values = fn -> { {value, text}, ... }, get, set, placeholder }
	page:Input    { label, desc, placeholder, button, maxLetters, onSubmit = fn(text) -> ok }
	page:Button   { label, desc, text, kind, onClick }

	Every control re-reads its value on page:Refresh(), which runs whenever the
	page is shown and after any change, so values never go stale.

	UI.Confirm(text, yesLabel, onYes)   modal question inside the panel
	UI.OpenMenu(anchor, items, current, onPick)
]]

local H = Heraldry
local UI = H.UI
local C = UI.colors

local CONTROL_W = 260

local Page = {}
Page.__index = Page

function UI.NewPage(parent, width)
	local page = setmetatable({ width = width, y = 0, refreshers = {} }, Page)
	page.frame = CreateFrame("Frame", nil, parent)
	page.frame:SetSize(width, 1)
	return page
end

function Page:Place(f, h, gap)
	f:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -self.y)
	f:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -self.y)
	f:SetHeight(h)
	self.y = self.y + h + (gap or 4)
	self.frame:SetHeight(math.max(self.y, 1))
end

function Page:OnRefresh(fn)
	self.refreshers[#self.refreshers + 1] = fn
end

function Page:Refresh()
	local handler = geterrorhandler()
	for i = 1, #self.refreshers do
		xpcall(self.refreshers[i], handler)
	end
end

function Page:Section(title, desc)
	if self.y > 0 then self.y = self.y + 20 end
	local f = CreateFrame("Frame", nil, self.frame)
	local t = UI.Text(f, 15, C.accent)
	t:SetPoint("BOTTOMLEFT", 2, 8)
	t:SetText(title)
	local line = UI.Tex(f, C.border, "ARTWORK")
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	self:Place(f, 32, 8)
	if desc then self:Text(desc) end
end

function Page:Text(text, height)
	local f = CreateFrame("Frame", nil, self.frame)
	local fs = UI.Text(f, 12, C.dim)
	fs:SetPoint("TOPLEFT", 2, 0)
	fs:SetWidth(self.width - 4)
	fs:SetJustifyV("TOP")
	local function paint()
		fs:SetText(type(text) == "function" and text() or text)
	end
	paint()
	if type(text) == "function" then self:OnRefresh(paint) end
	self:Place(f, height or (fs:GetStringHeight() + 2), 10)
	return fs
end

-- A row: label (+ one line of description) on the left, control on the right.
local function newRow(page, label, desc)
	local f = CreateFrame("Frame", nil, page.frame)
	UI.Fill(f, C.row)
	local w = page.width - CONTROL_W - 40
	local l = UI.Text(f, 13, C.text)
	l:SetWidth(w)
	l:SetWordWrap(false)
	l:SetText(label or "")
	if desc then
		l:SetPoint("TOPLEFT", 14, -10)
		local d = UI.Text(f, 11, C.dim)
		d:SetWidth(w)
		d:SetWordWrap(false)
		d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -5)
		if type(desc) == "function" then
			page:OnRefresh(function() d:SetText(desc()) end)
		else
			d:SetText(desc)
		end
		page:Place(f, 50)
	else
		l:SetPoint("LEFT", 14, 0)
		page:Place(f, 38)
	end
	return f
end

function Page:Toggle(o)
	local page = self
	local f = newRow(self, o.label, o.desc)
	local b = CreateFrame("Button", nil, f)
	b:SetSize(42, 20)
	b:SetPoint("RIGHT", -14, 0)
	local track = UI.Fill(b, C.control)
	UI.Border(b, C.borderStrong)
	local knob = UI.Tex(b, C.dim, "OVERLAY")
	knob:SetSize(14, 14)
	local function paint()
		local on = o.get() and true or false
		knob:ClearAllPoints()
		knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
		knob:SetColorTexture(unpack(on and C.accent or C.dim))
		track:SetColorTexture(unpack(on and C.accentDim or C.control))
	end
	b:SetScript("OnClick", function()
		o.set(not o.get())
		page:Refresh()
	end)
	self:OnRefresh(paint)
end

function Page:Slider(o)
	local page = self
	local f = newRow(self, o.label, o.desc)
	local step = o.step or 1
	local fmt = o.format or tostring
	local function round(v) return math.floor(v / step + 0.5) * step end

	local val = UI.Text(f, 12, C.text, nil, "RIGHT")
	val:SetPoint("RIGHT", -14, 0)
	val:SetWidth(50)

	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(170, 16)
	s:SetPoint("RIGHT", val, "LEFT", -12, 0)
	s:SetMinMaxValues(o.min, o.max)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouse(true)
	local track = UI.Tex(s, C.control, "BACKGROUND")
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(4)
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(unpack(C.accent))
	thumb:SetSize(10, 16)
	s:SetThumbTexture(thumb)

	local updating = false
	s:SetScript("OnValueChanged", function(_, v, user)
		v = round(v)
		val:SetText(fmt(v))
		if user and not updating then o.set(v) end
	end)
	s:SetScript("OnMouseUp", function()
		if o.onRelease then o.onRelease(round(s:GetValue())) end
		page:Refresh()
	end)
	self:OnRefresh(function()
		updating = true
		local v = o.get()
		s:SetValue(v)
		val:SetText(fmt(v))
		updating = false
	end)
end

--[[ Dropdown menu (one shared list for every dropdown) ]]

local menu
local ITEM_H = 22

function UI.IsMenuOpenFor(anchor)
	return menu ~= nil and menu:IsShown() and menu.anchor == anchor
end

function UI.CloseMenu()
	if menu then menu:Hide() end
end

function UI.OpenMenu(anchor, items, current, onPick)
	if not menu then
		menu = CreateFrame("Frame", nil, UI.root)
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		-- The list frame itself takes no clicks: only its items do. If it took
		-- clicks and ended above its items, they would look disabled.
		menu:EnableMouse(false)
		menu:Hide()
		UI.Fill(menu, C.menu)
		UI.Border(menu, C.borderStrong)
		menu.items = {}
		-- Close on a click anywhere outside the list (or its own dropdown button,
		-- which toggles it instead).
		menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
		menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
		menu:SetScript("OnEvent", function(self)
			if not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then
				self:Hide()
			end
		end)
		UI.root:HookScript("OnHide", function() menu:Hide() end)
	end
	menu.anchor = anchor

	local n = math.max(#items, 1)
	for i = 1, n do
		local it = menu.items[i]
		if not it then
			it = CreateFrame("Button", nil, menu)
			it:EnableMouse(true)
			it:RegisterForClicks("LeftButtonUp")
			it:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ITEM_H)
			it:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * ITEM_H)
			it:SetHeight(ITEM_H)
			it.hl = UI.Fill(it, C.rowHover)
			it.hl:Hide()
			it.text = UI.Text(it, 12)
			it.text:SetPoint("LEFT", 8, 0)
			it.text:SetPoint("RIGHT", -8, 0)
			it.text:SetWordWrap(false)
			it:SetScript("OnEnter", function(self) self.hl:Show() end)
			it:SetScript("OnLeave", function(self) self.hl:Hide() end)
			menu.items[i] = it
		end
		it:SetFrameLevel(menu:GetFrameLevel() + 2)
		local data = items[i]
		if data then
			it.text:SetText(data.text)
			it.text:SetTextColor(unpack(data.value == current and C.accent or C.text))
			it:SetScript("OnClick", function()
				menu:Hide()
				H:Debug("Menu pick:", tostring(data.value))
				onPick(data.value)
			end)
		else
			it.text:SetText("Nothing to choose")
			it.text:SetTextColor(unpack(C.faint))
			it:SetScript("OnClick", function() menu:Hide() end)
		end
		it:Show()
	end
	for i = n + 1, #menu.items do menu.items[i]:Hide() end

	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu:SetSize(anchor:GetWidth(), n * ITEM_H + 4)
	menu:Show()
end

function Page:Dropdown(o)
	local page = self
	local f = newRow(self, o.label, o.desc)
	local b = UI.Button(f, "", 210)
	b:SetPoint("RIGHT", -14, 0)
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", 8, 0)
	b.label:SetPoint("RIGHT", -24, 0)
	b.label:SetJustifyH("LEFT")
	b.label:SetWordWrap(false)
	local arrow = b:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
	arrow:SetSize(18, 18)
	arrow:SetPoint("RIGHT", -3, 0)

	local function paint()
		local cur = o.get and o.get()
		local text
		if cur ~= nil then
			for _, it in ipairs(o.values()) do
				if it.value == cur then text = it.text end
			end
		end
		b.label:SetText(text or o.placeholder or "")
		b.label:SetTextColor(unpack(text and C.text or C.faint))
	end
	b:SetScript("OnClick", function()
		if UI.IsMenuOpenFor(b) then
			UI.CloseMenu()
			return
		end
		UI.OpenMenu(b, o.values(), o.get and o.get(), function(value)
			o.set(value)
			page:Refresh()
		end)
	end)
	self:OnRefresh(paint)
end

function Page:Input(o)
	local page = self
	local f = newRow(self, o.label, o.desc)
	local btn = UI.Button(f, o.button or "OK", 80)
	btn:SetPoint("RIGHT", -14, 0)

	local eb = CreateFrame("EditBox", nil, f)
	eb:SetSize(160, 24)
	eb:SetPoint("RIGHT", btn, "LEFT", -8, 0)
	eb:SetAutoFocus(false)
	eb:SetFont(UI.FONT, 12, "")
	eb:SetTextColor(unpack(C.text))
	eb:SetTextInsets(8, 8, 0, 0)
	eb:SetMaxLetters(o.maxLetters or 32)
	UI.Fill(eb, C.input)
	local border = UI.Border(eb, C.borderStrong)
	local ph = UI.Text(eb, 12, C.faint)
	ph:SetPoint("LEFT", 8, 0)
	ph:SetText(o.placeholder or "")

	local function updatePlaceholder()
		ph:SetShown(eb:GetText() == "" and not eb:HasFocus())
	end
	local function submit()
		if o.onSubmit(eb:GetText()) then
			eb:SetText("")
			eb:ClearFocus()
		end
		updatePlaceholder()
		page:Refresh()
	end
	eb:SetScript("OnEnterPressed", submit)
	btn:SetScript("OnClick", submit)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnTextChanged", updatePlaceholder)
	eb:SetScript("OnEditFocusGained", function()
		border:SetColor(unpack(C.accent))
		updatePlaceholder()
	end)
	eb:SetScript("OnEditFocusLost", function()
		border:SetColor(unpack(C.borderStrong))
		updatePlaceholder()
	end)
	updatePlaceholder()
end

function Page:Button(o)
	local f = newRow(self, o.label, o.desc)
	local b = UI.Button(f, o.text, 120, o.kind)
	b:SetPoint("RIGHT", -14, 0)
	b:SetScript("OnClick", function() o.onClick() end)
end

-- Font override of a module (made with { fonts = true }): one section,
-- the same on every module page. onChange re-applies the module's texts.
function Page:FontSection(mod, onChange)
	local F = H.Fonts
	local function set(key)
		return function(v)
			mod.db[key] = v
			onChange()
		end
	end
	self:Section("Font")
	self:Toggle({
		label = "Use the global font",
		desc = "Off: pick a font and outline for this module only.",
		get = function() return not mod.db.fontOverride end,
		set = function(v)
			mod.db.fontOverride = not v
			onChange()
		end,
	})
	self:Dropdown({
		label = "Font for this module",
		desc = "Used while the global font is off.",
		values = function()
			local t = { { value = false, text = ("Global (%s)"):format(F:Get("header")) } }
			for _, name in ipairs(F:List()) do t[#t + 1] = { value = name, text = name } end
			return t
		end,
		get = function() return mod.db.font end,
		set = set("font"),
	})
	self:Dropdown({
		label = "Outline for this module",
		desc = "Used while the global font is off.",
		values = function()
			local t = { { value = false, text = "Global" } }
			for _, o in ipairs(F.OUTLINES) do t[#t + 1] = o end
			return t
		end,
		get = function() return mod.db.fontOutline end,
		set = set("fontOutline"),
	})
end

--[[ Confirmation dialog ]]

local confirm

function UI.Confirm(text, yesLabel, onYes)
	if not confirm then
		confirm = CreateFrame("Frame", nil, UI.root)
		confirm:SetAllPoints(UI.root)
		confirm:SetFrameStrata("DIALOG")
		confirm:EnableMouse(true)
		UI.Fill(confirm, { 0, 0, 0, 0.6 })

		local box = CreateFrame("Frame", nil, confirm)
		box:SetSize(400, 140)
		box:SetPoint("CENTER")
		UI.Fill(box, C.header)
		UI.Border(box, C.borderStrong)

		confirm.text = UI.Text(box, 13, C.text, nil, "CENTER")
		confirm.text:SetPoint("TOPLEFT", 24, -26)
		confirm.text:SetPoint("TOPRIGHT", -24, -26)

		confirm.yes = UI.Button(box, "", 120, "danger")
		confirm.yes:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -6, 20)
		local no = UI.Button(box, "Cancel", 120)
		no:SetPoint("BOTTOMLEFT", box, "BOTTOM", 6, 20)
		no:SetScript("OnClick", function() confirm:Hide() end)
		confirm:Hide()
	end
	confirm.text:SetText(text)
	confirm.yes.label:SetText(yesLabel or "Confirm")
	confirm.yes:SetScript("OnClick", function()
		confirm:Hide()
		onYes()
	end)
	confirm:Show()
end
