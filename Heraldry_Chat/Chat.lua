--[[
	Heraldry_Chat - Chat.lua
	The chat as a scroll that unrolls sideways: a rod standing on the left and
	one on the right (the theme's "scroll.rodV"), paper between them. Clicking
	a rod rolls the scroll up: the paper narrows until only the two rods stand
	side by side. The side that stays put is the side of the screen the chat
	is on (its mover's anchor); a chat in the middle closes to its centre.

	  - the chat window keeps its size the whole time: it is hidden while the
	    scroll moves and shown again once it is open, so lines never reflow
	  - rolled up, the rods glow when a message arrives; Enter opens the
	    scroll to type and it rolls up again when you are done
	  - tabs sit on the paper's top edge, the input line inside the paper,
	    under the messages
	  - papers: dark, light (channel colours darkened to read as ink) or glass
	  - style "panel": no rods, a flat dark panel with a thin rim (level 3)

	Blizzard's chat keeps working as normal: only its art is hidden, and
	ChatFrame1 (with the windows docked to it) is placed inside our frame.
	None of this is protected, so it is safe in combat.
]]

local H = Heraldry
local Themes = H.Themes
local PAPER = "Interface\\AddOns\\Heraldry\\Media\\Paper\\"

local CH = H:NewModule("Chat", {
	label = "Chat",
	fonts = true,
	defaults = {
		style = "scroll",         -- "scroll" | "panel"
		paper = "dark",           -- "dark" | "light" | "glass"
		paperAlpha = 0.95,
		rodSize = 28,
		width = 540,
		height = 260,
		margin = 8,
		textSize = 0,             -- 0: the size set in the game's chat menu
		tabSize = 12,
		tabGap = 6,               -- space between the tabs and the messages
		editGap = 6,              -- space between the messages and the input line
		rolledUp = false,
		glow = true,
		enterUnrolls = true,
		hideButtons = true,
		fontOverride = true,
		fontOutline = "NONE",
	},
})

CH.PAPERS = {
	-- ink: how much new lines are darkened; text: colour of lines that bring none;
	-- tabOn / tabOff: the selected and the other tabs
	dark  = { file = PAPER .. "Dark",  size = { 512, 256 }, shade = 0.45, ink = 1,
		tabOn = { 0.91, 0.69, 0.29 }, tabOff = { 0.66, 0.60, 0.50 } },
	light = { file = PAPER .. "Light", size = { 512, 512 }, shade = 0.30, ink = 0.5, text = { 0.22, 0.15, 0.08 },
		tabOn = { 0.45, 0.08, 0.06 }, tabOff = { 0.38, 0.30, 0.20 } },
	glass = { color = { 0.035, 0.03, 0.025 }, shade = 0.35, ink = 1,
		tabOn = { 0.91, 0.69, 0.29 }, tabOff = { 0.66, 0.60, 0.50 } },
}

local hidden = CreateFrame("Frame")
hidden:Hide()

local NUM = NUM_CHAT_WINDOWS or 10

local function chatFrames(dockedOnly)
	local t = {}
	for i = 1, NUM do
		local cf = _G["ChatFrame" .. i]
		if cf and (not dockedOnly or i == 1 or cf.isDocked) then t[#t + 1] = cf end
	end
	return t
end

-- Blizzard textures that must stay invisible, even when Blizzard fades them in
local function kill(tex)
	if not tex or not tex.SetAlpha or tex.hKilled then return end
	tex.hKilled = true
	tex:SetAlpha(0)
	hooksecurefunc(tex, "SetAlpha", function(t, a)
		if a > 0 and not t.hLock then
			t.hLock = true
			t:SetAlpha(0)
			t.hLock = false
		end
	end)
end

local function killTextures(frame)
	if not frame then return end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r:GetObjectType() == "Texture" then kill(r) end
	end
end

local function gradient(tex, orientation, from, to)
	tex:SetColorTexture(1, 1, 1, 1)
	local ok = pcall(function()
		tex:SetGradient(orientation, CreateColor(unpack(from)), CreateColor(unpack(to)))
	end)
	if not ok then tex:Hide() end
end

--[[ Frame ]]

local function newRod(parent)
	local r = CreateFrame("Button", nil, parent)
	r.M = r:CreateTexture(nil, "ARTWORK", nil, 0)
	r.T = r:CreateTexture(nil, "ARTWORK", nil, 1)
	r.B = r:CreateTexture(nil, "ARTWORK", nil, 1)
	r.glow = r:CreateTexture(nil, "ARTWORK", nil, 2)
	r.glow:SetBlendMode("ADD")
	r.glow:SetVertexColor(1, 0.72, 0.22)
	r.glow:SetAlpha(0)
	r.glow:SetAllPoints(r.M)
	local ag = r.glow:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(0.1)
	a:SetToAlpha(0.85)
	a:SetDuration(0.9)
	r.pulse = ag
	r:RegisterForClicks("LeftButtonUp")
	r:SetScript("OnClick", function() CH:SetRolledUp(not CH.rolled) end)
	r:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText("Chat")
		GameTooltip:AddLine(CH.rolled and "Click to unroll." or "Click to roll up.", 1, 1, 1)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

function CH:Create()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "HeraldryChat", UIParent)
	f:SetFrameStrata("BACKGROUND")
	f:SetClampedToScreen(true)
	self.frame = f
	local base = f:GetFrameLevel()

	f.paperFrame = CreateFrame("Frame", nil, f)
	f.paperFrame:SetFrameLevel(base + 1)
	f.paper = f.paperFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	f.paper:SetAllPoints()
	f.shades = {}
	for i = 1, 4 do f.shades[i] = f.paperFrame:CreateTexture(nil, "BACKGROUND", nil, 2) end
	f.rim = {}
	for i = 1, 4 do f.rim[i] = f.paperFrame:CreateTexture(nil, "BORDER") end
	f.paperFrame:SetScript("OnSizeChanged", function() CH:CropPaper() end)
	f.tabRule = f.paperFrame:CreateTexture(nil, "BORDER")
	f.tabRule:SetHeight(1)

	f.left = newRod(f)
	f.right = newRod(f)
	f.left:SetFrameLevel(base + 6)
	f.right:SetFrameLevel(base + 6)
	return f
end

--[[ Rods ]]

function CH:SkinRod(r, piece)
	local cap = piece.capH / piece.size[2]
	r.T:SetTexture(piece.cap)
	r.T:SetTexCoord(0, 1, 0, cap)
	if piece.capB then
		r.B:SetTexture(piece.capB)
		r.B:SetTexCoord(0, 1, 1 - cap, 1)
	else
		r.B:SetTexture(piece.cap)
		r.B:SetTexCoord(0, 1, cap, 0)
	end
	for _, t in ipairs({ r.M, r.glow }) do
		if piece.midH then t:SetTexture(piece.mid, "CLAMP", "REPEAT") else t:SetTexture(piece.mid) end
	end
	for _, t in ipairs({ r.T, r.B, r.M }) do Themes:Paint(t) end
end

function CH:LayoutRod(r, piece, w, capPx, length)
	r:SetWidth(w)
	r.T:SetSize(w, capPx)
	r.B:SetSize(w, capPx)
	r.T:ClearAllPoints(); r.T:SetPoint("TOP")
	r.B:ClearAllPoints(); r.B:SetPoint("BOTTOM")
	r.M:ClearAllPoints()
	r.M:SetPoint("TOPLEFT", r.T, "BOTTOMLEFT", 0, 2)
	r.M:SetPoint("BOTTOMRIGHT", r.B, "TOPRIGHT", 0, -2)
	local v = 1
	if piece.midH then
		local len = length - 2 * capPx + 4
		v = len > 0 and len / (piece.midH * w / piece.size[1]) or 1
	end
	r.M:SetTexCoord(0, 1, 0, v)
	r.glow:SetTexCoord(0, 1, 0, v)
end

--[[ Paper ]]

function CH:Paper()
	return self.PAPERS[self.db.paper] or self.PAPERS.dark
end

-- show only the part of the picture that has the paper's own shape (never stretched)
function CH:CropPaper()
	local f = self.frame
	local art = self:Paper()
	if not (f and art.size) or self.db.style ~= "scroll" then return end
	local w, h = f.paperFrame:GetSize()
	if not (w and h and w > 0 and h > 0) then return end
	local a, p = art.size[1] / art.size[2], w / h
	if p >= a then f.paper:SetTexCoord(0, 1, 0, a / p) else f.paper:SetTexCoord(0, p / a, 0, 1) end
end

function CH:LayoutPaper(scroll)
	local f, db = self.frame, self.db
	local art = self:Paper()
	local alpha = db.paperAlpha
	if scroll and art.file then
		f.paper:SetTexture(art.file)
		f.paper:SetVertexColor(1, 1, 1)
		f.paper:SetAlpha(alpha)
		self:CropPaper()
	else
		local c = scroll and art.color or { 0.03, 0.028, 0.025 }
		f.paper:SetColorTexture(c[1], c[2], c[3], 1)
		f.paper:SetTexCoord(0, 1, 0, 1)
		f.paper:SetAlpha(scroll and alpha or math.min(alpha, 0.8))
	end
	-- soft dark edges on the paper
	local dark, clear = { 0, 0, 0, (art.shade or 0.4) * alpha }, { 0, 0, 0, 0 }
	local s = f.shades
	for _, t in ipairs(s) do t:ClearAllPoints(); t:SetShown(scroll) end
	if scroll then
		s[1]:SetPoint("TOPLEFT"); s[1]:SetPoint("BOTTOMLEFT"); s[1]:SetWidth(14); gradient(s[1], "HORIZONTAL", dark, clear)
		s[2]:SetPoint("TOPRIGHT"); s[2]:SetPoint("BOTTOMRIGHT"); s[2]:SetWidth(14); gradient(s[2], "HORIZONTAL", clear, dark)
		s[3]:SetPoint("TOPLEFT"); s[3]:SetPoint("TOPRIGHT"); s[3]:SetHeight(12); gradient(s[3], "VERTICAL", clear, dark)
		s[4]:SetPoint("BOTTOMLEFT"); s[4]:SetPoint("BOTTOMRIGHT"); s[4]:SetHeight(12); gradient(s[4], "VERTICAL", dark, clear)
	end
	-- panel: a thin rim in the theme's metal
	local r, g, b = Themes:Accent()
	if not r then r, g, b = 0.42, 0.34, 0.19 end
	local rim = f.rim
	for _, t in ipairs(rim) do
		t:ClearAllPoints()
		t:SetColorTexture(r, g, b, 0.9)
		t:SetShown(not scroll)
	end
	rim[1]:SetPoint("TOPLEFT"); rim[1]:SetPoint("TOPRIGHT"); rim[1]:SetHeight(1)
	rim[2]:SetPoint("BOTTOMLEFT"); rim[2]:SetPoint("BOTTOMRIGHT"); rim[2]:SetHeight(1)
	rim[3]:SetPoint("TOPLEFT"); rim[3]:SetPoint("BOTTOMLEFT"); rim[3]:SetWidth(1)
	rim[4]:SetPoint("TOPRIGHT"); rim[4]:SetPoint("BOTTOMRIGHT"); rim[4]:SetWidth(1)
end

--[[ Blizzard's chat: placed inside our frame ]]

-- the side of the screen that stays put while the scroll moves
function CH:FixedSide()
	local p = self.frame:GetPoint(1)
	if type(p) ~= "string" then return "LEFT" end
	if p:find("RIGHT") then return "RIGHT" end
	if p:find("LEFT") then return "LEFT" end
	return "CENTER"
end

function CH:PlaceChat()
	local cf, g = ChatFrame1, self.geo
	if not (cf and g) then return end
	cf.hLock = true
	cf:ClearAllPoints()
	if self:FixedSide() == "RIGHT" then
		cf:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -g.x, -g.y)
	else
		cf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", g.x, -g.y)
	end
	cf:SetSize(g.w, g.h)
	cf.hLock = false
end

function CH:HookChat()
	local cf = ChatFrame1
	if not cf or cf.hHooked then return end
	cf.hHooked = true
	local function again()
		if cf.hLock or CH.pending then return end
		CH.pending = true
		C_Timer.After(0, function()
			CH.pending = nil
			CH:PlaceChat()
		end)
	end
	hooksecurefunc(cf, "SetPoint", again)
	hooksecurefunc(cf, "SetSize", again)
	if FCF_SetLocked then pcall(FCF_SetLocked, cf, true) end
	local rb = cf.ResizeButton or _G.ChatFrame1ResizeButton
	if rb then rb:SetParent(hidden) end
end

-- tabs above the scroll
function CH:PlaceDock()
	local d = GeneralDockManager
	if not d then return end
	if not d.hHooked then
		d.hHooked = true
		hooksecurefunc(d, "SetPoint", function()
			if d.hLock then return end
			C_Timer.After(0, function() CH:PlaceDock() end)
		end)
	end
	local cf = ChatFrame1
	d.hLock = true
	d:ClearAllPoints()
	-- in the top of the paper, over the messages
	d:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -6, 3 + self.db.tabGap)
	d:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 0, 3 + self.db.tabGap)
	d.hLock = false

	-- the docked tabs follow the first tab, and the game anchors that one to the chat
	-- window itself (not to the dock): it has to be moved too, or the gap goes above the tabs
	local tab = ChatFrame1Tab
	if tab then
		if not tab.hPlaced then
			tab.hPlaced = true
			hooksecurefunc(tab, "SetPoint", function()
				if tab.hLock then return end
				C_Timer.After(0, function() CH:PlaceDock() end)
			end)
		end
		tab.hLock = true
		tab:ClearAllPoints()
		tab:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -6, 3 + self.db.tabGap)
		tab.hLock = false
	end
end

-- the input line below the scroll
function CH:PlaceEdit()
	local eb = ChatFrame1EditBox
	if not eb then return end
	if not eb.hHooked then
		eb.hHooked = true
		hooksecurefunc(eb, "SetPoint", function()
			if eb.hLock or eb.hPending then return end
			eb.hPending = true
			C_Timer.After(0, function()
				eb.hPending = nil
				CH:PlaceEdit()
			end)
		end)
		killTextures(eb)
		for _, n in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
			kill(_G[eb:GetName() .. n])
		end
		eb.hBg = eb:CreateTexture(nil, "BACKGROUND", nil, -7)
		eb.hBg:SetAllPoints()
		eb.hBg:SetColorTexture(0, 0, 0, 0.3)
		eb.hLine = eb:CreateTexture(nil, "BORDER")
		eb.hLine:SetPoint("BOTTOMLEFT")
		eb.hLine:SetPoint("BOTTOMRIGHT")
		eb.hLine:SetHeight(1)
	end
	local r, g, b = Themes:Accent()
	if not r then r, g, b = 0.42, 0.34, 0.19 end
	eb.hLine:SetColorTexture(r, g, b, 0.9)
	local cf = ChatFrame1
	eb.hLock = true
	eb:ClearAllPoints()
	-- inside the paper, under the messages
	eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -4, -self.db.editGap)
	eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 4, -self.db.editGap)
	eb:SetHeight(self.editH)
	eb.hLock = false
end

-- Blizzard's own art and buttons
function CH:StyleBlizzard()
	for _, cf in ipairs(chatFrames()) do
		for _, n in ipairs(CHAT_FRAME_TEXTURES or { "Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture",
			"BottomRightTexture", "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }) do
			kill(_G[cf:GetName() .. n])
		end
		if cf.Background then kill(cf.Background) end
		local tab = _G[cf:GetName() .. "Tab"]
		if tab then self:StyleTab(tab) end
	end
	local names = { "QuickJoinToastButton", "ChatFrameChannelButton", "ChatFrameMenuButton",
		"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "TextToSpeechButton" }
	local frames = {}
	for _, n in ipairs(names) do frames[#frames + 1] = _G[n] end
	for _, cf in ipairs(chatFrames()) do
		frames[#frames + 1] = cf.buttonFrame or _G[cf:GetName() .. "ButtonFrame"]
		-- the scroll bar and "jump to the end" button on the right of the text (the wheel still scrolls)
		frames[#frames + 1] = cf.ScrollBar
		frames[#frames + 1] = cf.ScrollToBottomButton
	end
	for _, b in pairs(frames) do
		if b then
			if not b.hParent then b.hParent = b:GetParent() end
			if self.db.hideButtons then
				b:SetParent(hidden)
			elseif b:GetParent() == hidden then
				b:SetParent(b.hParent)
			end
		end
	end
end

--[[ Tabs: written on the paper, the selected one underlined in the theme's metal ]]

function CH:StyleTab(tab)
	if not tab.hStyled then
		tab.hStyled = true
		killTextures(tab)
		-- the game fades tabs out when the mouse is away; on paper they stay readable
		hooksecurefunc(tab, "SetAlpha", function(t, a)
			if a < 1 and not t.hLock then
				t.hLock = true
				t:SetAlpha(1)
				t.hLock = false
			end
		end)
		tab:SetAlpha(1)
		tab.hLine = tab:CreateTexture(nil, "OVERLAY")
		tab.hLine:SetHeight(2)
		tab.hLine:SetPoint("BOTTOMLEFT", 6, 2)
		tab.hLine:SetPoint("BOTTOMRIGHT", -6, 2)
	end
end

function CH:ColorTabs()
	local art = self:Paper()
	if self.db.style ~= "scroll" then art = self.PAPERS.dark end
	local r, g, b = Themes:Accent()
	if not r then r, g, b = 0.42, 0.34, 0.19 end
	local sel = GeneralDockManager and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GeneralDockManager)
	for _, cf in ipairs(chatFrames()) do
		local tab = _G[cf:GetName() .. "Tab"]
		if tab and tab.hLine then
			local on = (sel == cf) or (not sel and cf == SELECTED_CHAT_FRAME)
			local c = on and art.tabOn or art.tabOff
			local fs = tab:GetFontString() or tab.Text
			if fs then fs:SetTextColor(c[1], c[2], c[3]) end
			tab.hLine:SetColorTexture(r, g, b, 0.9)
			tab.hLine:SetShown(on)
		end
	end
end

--[[ Fonts ]]

function CH:ApplyFonts()
	local db = self.db
	local path, size, flags, shadow = H.Fonts:Resolve("body", db.textSize > 0 and db.textSize or 12, self)
	local function set(fr)
		if not fr.hFont then fr.hFont = { fr:GetFont() } end
		local sz = size
		if db.textSize <= 0 then
			local _, cur = fr:GetFont()
			sz = cur or fr.hFont[2] or 13
		end
		if fr:SetFont(path, sz, flags) == false and fr.hFont[1] then fr:SetFont(fr.hFont[1], sz, flags) end
		fr:SetShadowColor(0, 0, 0, 1)
		fr:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
	end
	for _, cf in ipairs(chatFrames()) do
		set(cf)
		local tab = _G[cf:GetName() .. "Tab"]
		local text = tab and (tab.Text or _G[tab:GetName() .. "Text"])
		if text then H.Fonts:Apply(text, "header", db.tabSize, self) end
	end
	local eb = ChatFrame1EditBox
	if eb then
		set(eb)
		local hd = ChatFrame1EditBoxHeader
		if hd then set(hd) end
	end
end

--[[ Ink: on light paper new lines are darkened, so channel colours read as ink ]]

function CH:HookMessages()
	for _, cf in ipairs(chatFrames()) do
		if not cf.hAdd then
			local orig = cf.AddMessage
			cf.hAdd = orig
			cf.AddMessage = function(fr, text, r, g, b, ...)
				-- light paper: every line in ink (Text.lua)
				if CH.ink and CH.ink ~= 1 and CH.InkLine then
					local ok, t2, r2, g2, b2 = pcall(CH.InkLine, CH, text, r, g, b, ...)
					if ok then text, r, g, b = t2, r2, g2, b2 end
				end
				-- abbreviations, timestamps and the like (Text.lua)
				if CH.FormatLine then
					local ok, out = pcall(CH.FormatLine, CH, text)
					if ok and out then text = out end
				end
				if fr ~= ChatFrame2 and CH.rolled then CH:Glow(true) end
				return orig(fr, text, r, g, b, ...)
			end
		end
	end
end

--[[ Rolling ]]

function CH:Glow(on)
	local f = self.frame
	if not f then return end
	on = on and self.db.glow and self.rolled
	for _, r in ipairs({ f.left, f.right }) do
		if on then
			if not r.pulse:IsPlaying() then r.pulse:Play() end
		else
			r.pulse:Stop()
		end
	end
end

-- chat windows, tabs and input are hidden (and let clicks through) while rolled up
function CH:SetChatVisible(on)
	for _, cf in ipairs(chatFrames(true)) do
		cf:SetAlpha(on and 1 or 0)
		if cf.hMouse == nil then cf.hMouse, cf.hWheel = cf:IsMouseEnabled(), cf:IsMouseWheelEnabled() end
		cf:EnableMouse(on and cf.hMouse or false)
		cf:EnableMouseWheel(on and cf.hWheel or false)
		local tab = _G[cf:GetName() .. "Tab"]
		if tab then tab:EnableMouse(on) end
	end
	if GeneralDockManager then GeneralDockManager:SetAlpha(on and 1 or 0) end
	if ChatFrame1EditBox then ChatFrame1EditBox:SetAlpha(on and 1 or 0) end
end

-- temp: opened only to type (Enter); the saved state stays rolled up
function CH:SetRolledUp(on, temp)
	local f = self.frame
	if not f or self.db.style ~= "scroll" then return end
	if not temp then self.db.rolledUp = on end
	if on == self.rolled and not self.animW then return end
	self.rolled = on
	if on then self:SetChatVisible(false) else self:Glow(false) end
	local from = self.animW or f:GetWidth()
	local to = on and self.rolledW or self.openW
	local t, dur = 0, 0.3
	f:SetScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		local p = math.min(t / dur, 1)
		local e = 1 - (1 - p) ^ 3
		self.animW = from + (to - from) * e
		f:SetWidth(self.animW)
		if p >= 1 then
			f:SetScript("OnUpdate", nil)
			self.animW = nil
			self:Layout()
		end
	end)
end

--[[ Layout ]]

function CH:Layout()
	local f, db = self.frame, self.db
	if not f then return end
	local piece = Themes:Piece("scroll.rodV")
	local scroll = db.style == "scroll" and piece ~= nil
	local w = scroll and db.rodSize or 0
	local capPx = scroll and piece.capH * w / piece.size[1] or 0
	local inset = scroll and math.floor(capPx * 0.55) or 0
	local side = scroll and (w / 2 + w * piece.shaft / 2) or 0

	self.openW = db.width
	self.rolledW = scroll and (2 * w + 2) or db.width
	if not scroll then self.rolled = false end
	f:SetSize(self.animW or (self.rolled and self.rolledW or self.openW), db.height)

	-- where the chat window goes, and its size (always the open size)
	-- the input line takes the bottom of the paper, under the messages
	self.editH = 22
	-- the tabs take the top of the paper, over the messages
	self.tabH = db.tabSize + 12 + db.tabGap
	self.geo = {
		x = side + db.margin,
		y = inset + db.margin + self.tabH,
		w = math.max(db.width - 2 * (side + db.margin), 80),
		h = math.max(db.height - 2 * (inset + db.margin) - self.editH - db.editGap - self.tabH, 40),
	}

	for _, r in ipairs({ f.left, f.right }) do r:SetShown(scroll) end
	if scroll then
		self:SkinRod(f.left, piece)
		self:SkinRod(f.right, piece)
		self:LayoutRod(f.left, piece, w, capPx, db.height)
		self:LayoutRod(f.right, piece, w, capPx, db.height)
		f.left:ClearAllPoints()
		f.left:SetPoint("TOPLEFT"); f.left:SetPoint("BOTTOMLEFT")
		f.right:ClearAllPoints()
		f.right:SetPoint("TOPRIGHT"); f.right:SetPoint("BOTTOMRIGHT")
	end
	f.paperFrame:ClearAllPoints()
	f.paperFrame:SetPoint("TOPLEFT", f, "TOPLEFT", w / 2, -inset)
	f.paperFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -w / 2, inset)
	self:LayoutPaper(scroll)
	self.ink = scroll and self:Paper().ink or 1

	self:StyleBlizzard()
	self:ApplyFonts()
	self:PlaceChat()
	self:PlaceDock()
	self:PlaceEdit()
	-- a thin rule between the tabs and the messages
	local ar, ag, ab = Themes:Accent()
	if not ar then ar, ag, ab = 0.42, 0.34, 0.19 end
	f.tabRule:ClearAllPoints()
	-- the rule sits under the tabs; the gap is below it
	f.tabRule:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", -4, 2 + db.tabGap)
	f.tabRule:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 4, 2 + db.tabGap)
	f.tabRule:SetColorTexture(ar, ag, ab, 0.45)
	self:ColorTabs()
	if self.ApplyText then self:ApplyText() end
	if not self.animW then self:SetChatVisible(not self.rolled) end
	if not self.rolled then self:Glow(false) end
end

--[[ Lifecycle ]]

function CH:OnEnable()
	local f = self:Create()
	self.rolled = self.db.style == "scroll" and self.db.rolledUp
	f.mover = H:RegisterMover(f, "Chat.frame", {
		label = "Chat", default = { "BOTTOMLEFT", 20, 46 }, scalable = true,
	})
	self:HookChat()
	self:HookMessages()
	self:Layout()
	H.Movers:Apply(f.mover)

	local eb = ChatFrame1EditBox
	if eb then
		-- Enter opens the scroll to type; it rolls up again afterwards
		eb:HookScript("OnEditFocusGained", function()
			if CH.rolled and CH.db.enterUnrolls then
				CH.tempOpen = true
				CH:SetRolledUp(false, true)
			end
		end)
		eb:HookScript("OnEditFocusLost", function()
			if CH.tempOpen then
				CH.tempOpen = nil
				if CH.db.rolledUp then CH:SetRolledUp(true, true) end
			end
		end)
	end
	for _, fn in ipairs({ "FCFTab_UpdateColors", "FCF_Tab_OnClick", "FCFDock_SelectWindow" }) do
		if _G[fn] then hooksecurefunc(fn, function() CH:ColorTabs() end) end
	end
	if FCF_SetChatWindowFontSize then
		hooksecurefunc("FCF_SetChatWindowFontSize", function()
			C_Timer.After(0, function() CH:ApplyFonts() end)
		end)
	end
	for _, fn in ipairs({ "FCF_OpenNewWindow", "FCF_DockFrame", "FCF_UnDockFrame", "FCFDock_SelectWindow" }) do
		if _G[fn] then
			hooksecurefunc(fn, function()
				C_Timer.After(0, function()
					CH:HookMessages()
					CH:Layout()
				end)
			end)
		end
	end
	-- the game places the chat again late in the loading
	C_Timer.After(1, function() CH:Layout() end)
	H:On("THEME_CHANGED", function() CH:Layout() end)
	H:On("FONTS_CHANGED", function() CH:Layout() end)
end

function CH:OnProfileChanged()
	self.rolled = self.db.style == "scroll" and self.db.rolledUp
	self:Layout()
	H.Movers:Apply(self.frame.mover)
end
