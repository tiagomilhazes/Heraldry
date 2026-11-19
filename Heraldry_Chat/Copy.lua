--[[
	Heraldry_Chat - Copy.lua
	/hui copy: the last lines of the chat window in a box you can copy from
	(prototype K2, dark parchment like the chat). The text opens selected, so
	Ctrl+C copies it at once; Escape closes the box. Colours, links and icons
	are stripped so it reads clean when pasted. Lines the game keeps secret
	are skipped.
]]

local H = Heraldry
local CH = H.Modules.byName.Chat

local MAX_LINES = 200
local TEXT = { 0.94, 0.89, 0.78 }

-- colour codes, links (their text stays), icons and atlases out
local function clean(t)
	return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
		:gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

local function readable(t)
	return type(t) == "string" and not (issecretvalue and issecretvalue(t))
end

-- the visible chat window's last lines, oldest first, and how many the game hides
local function chatLines()
	local cf = SELECTED_CHAT_FRAME or ChatFrame1
	local lines, hidden = {}, 0
	if not (cf and cf.GetNumMessages and cf.GetMessageInfo) then return lines, hidden end
	local n = cf:GetNumMessages()
	for i = math.max(1, n - MAX_LINES + 1), n do
		local text = cf:GetMessageInfo(i)
		if readable(text) then lines[#lines + 1] = clean(text) elseif issecretvalue and issecretvalue(text) then hidden = hidden + 1 end
	end
	return lines, hidden
end

local function edges(f, r, g, b)
	local pts = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }
	for i, p in ipairs(pts) do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetColorTexture(r, g, b, 1)
		t:SetPoint(p[1]); t:SetPoint(p[2])
		if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
	end
end

local function button(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(80, 22)
	edges(b, 0.42, 0.33, 0.20)
	b.text = b:CreateFontString(nil, "OVERLAY")
	H.Fonts:Apply(b.text, "body", 12, CH)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function() b.text:SetTextColor(1, 0.85, 0.5) end)
	b:SetScript("OnLeave", function() b.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3]) end)
	return b
end

local box

local function build()
	local f = CreateFrame("Frame", "HeraldryChatCopy", UIParent)
	f:SetSize(560, 340)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	tinsert(UISpecialFrames, "HeraldryChatCopy")

	local paper = f:CreateTexture(nil, "BACKGROUND")
	paper:SetAllPoints()
	H.Paper:Apply(paper, "dark", 0.97)
	H.Paper:Crop(paper, "dark", f:GetSize())
	edges(f, 0.42, 0.33, 0.20)

	f.title = f:CreateFontString(nil, "OVERLAY")
	H.Fonts:Apply(f.title, "header", 14, CH)
	f.title:SetPoint("TOPLEFT", 12, -10)
	f.title:SetText("Copy chat")
	local on = CH.PAPERS.dark.tabOn
	f.title:SetTextColor(on[1], on[2], on[3])
	f.count = f:CreateFontString(nil, "OVERLAY")
	H.Fonts:Apply(f.count, "body", 12, CH)
	f.count:SetPoint("TOPRIGHT", -12, -12)
	f.count:SetTextColor(0.72, 0.64, 0.49)

	-- the text area: a darker well on the paper
	local well = CreateFrame("Frame", nil, f)
	well:SetPoint("TOPLEFT", 12, -34)
	well:SetPoint("BOTTOMRIGHT", -12, 40)
	local bg = well:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.35)
	edges(well, 0.35, 0.27, 0.16)

	local scroll = CreateFrame("ScrollFrame", nil, well)
	scroll:SetPoint("TOPLEFT", 8, -6)
	scroll:SetPoint("BOTTOMRIGHT", -8, 6)
	local eb = CreateFrame("EditBox", nil, scroll)
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(0)
	eb:SetWidth(scroll:GetWidth() > 0 and scroll:GetWidth() or 520)
	local path, size, flags = H.Fonts:Resolve("body", 12, CH)   -- font before any SetText
	eb:SetFont(path, size, flags)
	eb:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	eb:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(eb)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(s, delta)
		s:SetVerticalScroll(math.max(0, math.min(s:GetVerticalScroll() - delta * 40, s:GetVerticalScrollRange())))
	end)
	scroll:SetScript("OnSizeChanged", function(s, w) eb:SetWidth(w) end)
	f.eb, f.scroll = eb, scroll

	local close = button(f, "Close", function() f:Hide() end)
	close:SetPoint("BOTTOMRIGHT", -12, 10)
	local all = button(f, "Select all", function() eb:SetFocus() eb:HighlightText() end)
	all:SetPoint("RIGHT", close, "LEFT", -8, 0)
	return f
end

function CH:ShowCopy()
	box = box or build()
	local lines, hidden = chatLines()
	box.eb:SetText(table.concat(lines, "\n"))
	if #lines == 0 then
		box.count:SetText(hidden > 0 and ("Nothing to copy: the game hides these %d lines"):format(hidden) or "Nothing to copy in this window")
	else
		box.count:SetText(("%d lines%s · Ctrl+C to copy"):format(#lines, hidden > 0 and (", %d hidden by the game"):format(hidden) or ""))
	end
	box:Show()
	box.eb:SetFocus()
	box.eb:HighlightText()
	-- newest lines at the bottom: start there once the text has its height
	C_Timer.After(0, function() box.scroll:SetVerticalScroll(box.scroll:GetVerticalScrollRange()) end)
end

H.commands = H.commands or {}
H.commands.copy = function() CH:ShowCopy() end
