--[[
	Heraldry_ActionBars - Text.lua
	The three texts of a button: keybind (HotKey), macro name (Name) and
	charges/count (Count). For every bar at once:
	  show, size (a share of the button, so it follows the button size),
	  position (corner) and fine offsets.
	Per bar: only "show keybinds" (e.g. a bar used with the mouse).
	Short keybinds: "s-Z" -> "SZ", "Mouse Button 4" -> "M4" ...

	Fonts come from the core (Fonts page) or this module's override.
	Showing/hiding uses opacity: the game shows and hides these texts itself.
]]

local H = Heraldry
local AB = H.Modules.byName.ActionBars

AB.TEXTS = {
	{ key = "hotkey", region = "HotKey", label = "Keybind" },
	{ key = "count",  region = "Count",  label = "Charges and count" },
	{ key = "name",   region = "Name",   label = "Macro name" },
}

-- Order matters: longer names first.
local SHORT = {
	{ "Mouse Wheel Up", "WU" }, { "Mouse Wheel Down", "WD" }, { "Middle Mouse", "M3" },
	{ "Mouse Button (%d+)", "M%1" }, { "Num Pad ", "N" }, { "Spacebar", "Spc" },
	{ "Page Up", "PU" }, { "Page Down", "PD" }, { "Backspace", "BS" }, { "Capslock", "Caps" },
	{ "Insert", "Ins" }, { "Delete", "Del" }, { "Home", "Hm" },
	{ "BUTTON(%d+)", "M%1" },
	{ "s%-", "S" }, { "c%-", "C" }, { "a%-", "A" }, { "m%-", "M" },
	{ "SHIFT%-", "S" }, { "CTRL%-", "C" }, { "ALT%-", "A" },
}

local function shorten(text)
	if not text or text == "" or text == RANGE_INDICATOR then return text end
	for _, rule in ipairs(SHORT) do text = text:gsub(rule[1], rule[2]) end
	return text:upper()
end

local function justify(anchor)
	if anchor:find("LEFT") then return "LEFT" end
	if anchor:find("RIGHT") then return "RIGHT" end
	return "CENTER"
end

-- Short keybind text after every game update of the button.
local function hookHotkey(b)
	if b.hdHotkeyHooked or not b.UpdateHotkeys then return end
	b.hdHotkeyHooked = true
	hooksecurefunc(b, "UpdateHotkeys", function(self)
		if AB.db.hotkeyShort and self.HotKey then
			local t = self.HotKey:GetText()
			local s = shorten(t)
			if s ~= t then self.HotKey:SetText(s) end
		end
	end)
end

-- Out of combat (called from LayoutBar).
function AB:StyleTexts(bar)
	local base = bar.base
	local showKeys = self:Get(bar.n, "hotkeys")
	for _, b in ipairs(bar.buttons) do
		hookHotkey(b)
		for _, t in ipairs(self.TEXTS) do
			local fs = b[t.region]
			if fs then
				local k = t.key
				local shown = self.db[k .. "Show"] and (k ~= "hotkey" or showKeys)
				fs:SetAlpha(shown and 1 or 0)
				H.Fonts:Apply(fs, "body", base * self.db[k .. "Size"], self)
				local anchor = self.db[k .. "Pos"]
				fs:ClearAllPoints()
				fs:SetPoint(anchor, b, anchor, self.db[k .. "X"], self.db[k .. "Y"])
				fs:SetJustifyH(justify(anchor))
				fs:SetWidth(base - 2)
				fs:SetWordWrap(false)
			end
		end
		-- Short form right away (the hook keeps it after the game's updates).
		if self.db.hotkeyShort and b.HotKey then
			local t = b.HotKey:GetText()
			local s = shorten(t)
			if s ~= t then b.HotKey:SetText(s) end
		end
	end
end
