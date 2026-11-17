--[[
	Heraldry_Quests - Quests.lua
	The quest tracker as a parchment scroll (prototype Q4): a rod on top and
	one at the bottom, paper between them, the quests written on the paper.
	Two papers: light (ink colours) and dark (gold and parchment colours).

	  - the rods are the theme's "scroll.rod" piece, with the theme's finish
	  - clicking the top rod rolls the scroll up (only the rods stay) or down
	  - a quest's title opens the quest log on it; shift-click stops tracking
	  - the game's own tracker is hidden while this one is shown
	  - when Questie's tracker is on, this one steps aside (Questie keeps its own)

	The quest data is read with the modern API (C_QuestLog) and falls back to
	the classic one, because this client mixes both.
]]

local H = Heraldry
local Themes = H.Themes
local PAPER = "Interface\\AddOns\\Heraldry\\Media\\Paper\\"   -- shared with the chat

local Q = H:NewModule("Quests", {
	label = "Quests",
	fonts = true,
	defaults = {
		paper = "light",          -- "light" | "dark"
		paperAlpha = 1,
		width = 280,
		maxHeight = 420,
		rodSize = 26,
		margin = 10,              -- text distance from the paper's edges
		headerShow = true, headerSize = 13,
		titleSize = 12,
		objectiveSize = 11,
		questSpacing = 6,
		showLevel = true,
		difficultyColor = true,
		hideDone = false,         -- hide finished objectives
		source = "watched",       -- "watched" | "all"
		hideBlizzard = true,
		combatRollUp = false,
		rolledUp = false,
		rolledCount = true,       -- rolled up: a strip of paper with the number of quests
		-- ink does not want a black outline: the module's font starts without one
		fontOverride = true,
		fontOutline = "NONE",
	},
})

Q.PAPERS = {
	light = { file = PAPER .. "Light", size = { 512, 512 }, shade = 0.30 },
	dark  = { file = PAPER .. "Dark",  size = { 512, 256 }, shade = 0.45 },
}

-- text colours for each paper
Q.INK = {
	light = {
		header = { 0.45, 0.08, 0.06 },
		title  = { 0.24, 0.14, 0.05 },
		text   = { 0.33, 0.25, 0.15 },
		done   = { 0.18, 0.40, 0.12 },
		failed = { 0.58, 0.10, 0.08 },
		faint  = { 0.45, 0.38, 0.28 },
		dim    = 0.55,   -- difficulty colours are darkened this much to read on light paper
	},
	dark = {
		header = { 0.91, 0.69, 0.29 },
		title  = { 0.91, 0.69, 0.29 },
		text   = { 0.86, 0.81, 0.71 },
		done   = { 0.50, 0.80, 0.40 },
		failed = { 0.92, 0.36, 0.30 },
		faint  = { 0.62, 0.58, 0.50 },
		dim    = 1,
	},
}

Q.TEXTS = {
	{ key = "header",    label = "Header (\"Quests\")" },
	{ key = "title",     label = "Quest titles" },
	{ key = "objective", label = "Objectives" },
}

local CQL = C_QuestLog

--[[ Quest data: modern API first, classic second ]]

local function logInfo(index)
	if not index or index < 1 then return nil end
	if CQL and CQL.GetInfo then
		local i = CQL.GetInfo(index)
		if not i then return nil end
		return { id = i.questID, title = i.title, level = i.level, isHeader = i.isHeader, hidden = i.isHidden, index = index }
	elseif GetQuestLogTitle then
		local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(index)
		if not title then return nil end
		return { id = questID, title = title, level = level, isHeader = isHeader, index = index, completeFlag = isComplete }
	end
end

local function logIndexFor(id)
	if CQL and CQL.GetLogIndexForQuestID then return CQL.GetLogIndexForQuestID(id) end
end

local function numEntries()
	if CQL and CQL.GetNumQuestLogEntries then return (CQL.GetNumQuestLogEntries()) or 0 end
	return GetNumQuestLogEntries and (GetNumQuestLogEntries()) or 0
end

function Q:Quests()
	local out = {}
	if self.db.source == "all" then
		for i = 1, numEntries() do
			local q = logInfo(i)
			if q and not q.isHeader and not q.hidden then out[#out + 1] = q end
		end
	elseif CQL and CQL.GetNumQuestWatches and CQL.GetQuestIDForQuestWatchIndex then
		for w = 1, CQL.GetNumQuestWatches() or 0 do
			local id = CQL.GetQuestIDForQuestWatchIndex(w)
			local q = id and logInfo(logIndexFor(id))
			if q then
				q.id = q.id or id
				out[#out + 1] = q
			end
		end
	elseif GetNumQuestWatches and GetQuestIndexForWatch then
		for w = 1, GetNumQuestWatches() or 0 do
			local q = logInfo(GetQuestIndexForWatch(w))
			if q then out[#out + 1] = q end
		end
	end
	return out
end

-- { { text, finished }, ... }
local function objectives(q)
	local list = {}
	if CQL and CQL.GetQuestObjectives and q.id then
		for _, o in ipairs(CQL.GetQuestObjectives(q.id) or {}) do
			if o.text and o.text ~= "" then list[#list + 1] = { o.text, o.finished } end
		end
	elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
		for j = 1, GetNumQuestLeaderBoards(q.index) or 0 do
			local text, _, finished = GetQuestLogLeaderBoard(j, q.index)
			if text and text ~= "" then list[#list + 1] = { text, finished } end
		end
	end
	return list
end

-- "done" | "failed" | nil
local function state(q)
	if q.id and CQL then
		if CQL.IsFailed and CQL.IsFailed(q.id) then return "failed" end
		if CQL.ReadyForTurnIn and CQL.ReadyForTurnIn(q.id) then return "done" end
		if CQL.IsComplete and CQL.IsComplete(q.id) then return "done" end
	end
	if q.completeFlag == 1 then return "done" end
	if q.completeFlag == -1 then return "failed" end
end

local function difficulty(level)
	if not level or level <= 0 or not GetQuestDifficultyColor then return nil end
	local ok, c = pcall(GetQuestDifficultyColor, level)
	if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
end

--[[ Clicks on a title ]]

local function openLog(q)
	if q.id and QuestMapFrame_OpenToQuestDetails then
		if pcall(QuestMapFrame_OpenToQuestDetails, q.id) then return end
	end
	local index = q.index or (q.id and logIndexFor(q.id))
	if QuestLogFrame then
		pcall(ShowUIPanel, QuestLogFrame)
		if index and SelectQuestLogEntry then
			pcall(SelectQuestLogEntry, index)
			if QuestLog_Update then pcall(QuestLog_Update) end
		end
	elseif ToggleQuestLog then
		pcall(ToggleQuestLog)
	end
end

local function untrack(q)
	if q.id and CQL and CQL.RemoveQuestWatch then
		CQL.RemoveQuestWatch(q.id)
	elseif q.index and RemoveQuestWatch then
		RemoveQuestWatch(q.index)
	end
	Q:Refresh()
end

--[[ Frame ]]

-- gradient between two colours; hidden if the client has no gradients
local function gradient(tex, orientation, from, to)
	tex:SetColorTexture(1, 1, 1, 1)
	local ok = pcall(function()
		tex:SetGradient(orientation, CreateColor(unpack(from)), CreateColor(unpack(to)))
	end)
	if not ok then tex:Hide() end
end

local function newRod(parent)
	local r = CreateFrame("Frame", nil, parent)
	r.M = r:CreateTexture(nil, "ARTWORK", nil, 0)
	r.L = r:CreateTexture(nil, "ARTWORK", nil, 1)
	r.R = r:CreateTexture(nil, "ARTWORK", nil, 1)
	return r
end

function Q:Create()
	if self.frame then return self.frame end
	local f = CreateFrame("Frame", "HeraldryQuestTracker", UIParent)
	f:SetFrameStrata("LOW")
	f:SetClampedToScreen(true)
	self.frame = f

	f.paperFrame = CreateFrame("Frame", nil, f)
	f.paperFrame:SetClipsChildren(true)
	f.paper = f.paperFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	f.shades = {}
	for i = 1, 4 do f.shades[i] = f.paperFrame:CreateTexture(nil, "BACKGROUND", nil, 2) end
	f.content = CreateFrame("Frame", nil, f.paperFrame)

	f.top = newRod(f)
	f.bot = newRod(f)
	local base = f:GetFrameLevel()
	f.paperFrame:SetFrameLevel(base + 1)
	f.top:SetFrameLevel(base + 6)
	f.bot:SetFrameLevel(base + 6)

	-- the top rod rolls the scroll up and down
	f.rodButton = CreateFrame("Button", nil, f)
	f.rodButton:SetAllPoints(f.top)
	f.rodButton:SetFrameLevel(base + 7)
	f.rodButton:RegisterForClicks("LeftButtonUp")
	f.rodButton:SetScript("OnClick", function() Q:SetRolledUp(not Q.db.rolledUp) end)
	f.rodButton:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:SetText("Quests")
		GameTooltip:AddLine(Q.db.rolledUp and "Click to unroll." or "Click to roll up.", 1, 1, 1)
		GameTooltip:Show()
	end)
	f.rodButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	f.header = f.content:CreateFontString(nil, "OVERLAY")
	f.empty = f.content:CreateFontString(nil, "OVERLAY")

	f.strip = f.paperFrame:CreateFontString(nil, "OVERLAY")
	f.strip:SetPoint("CENTER")

	self.titles, self.lines = {}, {}
	return f
end

local function titleButton(i)
	local b = Q.titles[i]
	if b then return b end
	b = CreateFrame("Button", nil, Q.frame.content)
	b.text = b:CreateFontString(nil, "OVERLAY")
	b.text:SetPoint("TOPLEFT")
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(true)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function(self)
		if not self.quest then return end
		if IsShiftKeyDown() then untrack(self.quest) else openLog(self.quest) end
	end)
	b:SetScript("OnEnter", function(self)
		self.text:SetAlpha(0.75)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(self.quest and self.quest.title or "")
		GameTooltip:AddLine("Click: open in the quest log.", 1, 1, 1)
		GameTooltip:AddLine("Shift-click: stop tracking.", 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		self.text:SetAlpha(1)
		GameTooltip:Hide()
	end)
	Q.titles[i] = b
	return b
end

local function line(i)
	local fs = Q.lines[i]
	if fs then return fs end
	fs = Q.frame.content:CreateFontString(nil, "OVERLAY")
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	Q.lines[i] = fs
	return fs
end

--[[ Geometry ]]

-- rod textures for the theme's piece
function Q:SkinRod(r, piece)
	local cap = piece.capW / piece.size[1]
	r.L:SetTexture(piece.cap)
	r.L:SetTexCoord(0, cap, 0, 1)
	if piece.capR then
		r.R:SetTexture(piece.capR)
		r.R:SetTexCoord(1 - cap, 1, 0, 1)
	else
		r.R:SetTexture(piece.cap)
		r.R:SetTexCoord(cap, 0, 0, 1)
	end
	if piece.midW then
		r.M:SetTexture(piece.mid, "REPEAT", "CLAMP")
	else
		r.M:SetTexture(piece.mid)
	end
	for _, t in ipairs({ r.L, r.R, r.M }) do Themes:Paint(t) end
end

function Q:LayoutRod(r, piece, h, capW)
	r:SetHeight(h)
	r.L:SetSize(capW, h)
	r.R:SetSize(capW, h)
	r.L:ClearAllPoints(); r.L:SetPoint("LEFT")
	r.R:ClearAllPoints(); r.R:SetPoint("RIGHT")
	r.M:ClearAllPoints()
	r.M:SetPoint("TOPLEFT", r.L, "TOPRIGHT", -2, 0)
	r.M:SetPoint("BOTTOMRIGHT", r.R, "BOTTOMLEFT", 2, 0)
	if piece.midW then
		local w = (self.db.width or 0) - 2 * capW + 4
		local u = w > 0 and w / (piece.midW * h / piece.size[2]) or 1
		r.M:SetTexCoord(0, u, 0, 1)
	else
		r.M:SetTexCoord(0, 1, 0, 1)
	end
end

-- crop the paper picture to the paper's shape, so it is never stretched
local function cropPaper(tex, art, w, h)
	if not (w and h and w > 0 and h > 0) then return end
	local a, p = art.size[1] / art.size[2], w / h
	if p >= a then
		tex:SetTexCoord(0, 1, 0, a / p)
	else
		tex:SetTexCoord(0, p / a, 0, 1)
	end
end

--[[ Content ]]

-- writes the quests on the paper and returns the height they take
function Q:Fill(textW)
	local f, db = self.frame, self.db
	local ink = self.INK[db.paper] or self.INK.light
	local function color(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end
	local y = 0
	local function place(region, x, h, gap)
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", f.content, "TOPLEFT", x, -y)
		y = y + h + (gap or 0)
	end

	if db.headerShow then
		H.Fonts:Apply(f.header, "header", db.headerSize, self)
		f.header:SetText("Quests")
		color(f.header, ink.header)
		f.header:SetJustifyH("CENTER")
		f.header:SetWidth(textW)
		place(f.header, 0, f.header:GetStringHeight(), db.questSpacing + 2)
		f.header:Show()
	else
		f.header:Hide()
	end

	local quests = self:Quests()
	local nt, nl = 0, 0
	local limit = db.maxHeight
	for _, q in ipairs(quests) do
		if y > limit then break end
		nt = nt + 1
		local b = titleButton(nt)
		b.quest = q
		H.Fonts:Apply(b.text, "header", db.titleSize, self)
		b.text:SetWidth(textW)
		local st = state(q)
		local base = st == "failed" and ink.failed or st == "done" and ink.done or ink.title
		local title = q.title or ""
		if st == "done" then title = title .. " \194\183 Ready" elseif st == "failed" then title = title .. " \194\183 Failed" end
		if db.showLevel and q.level and q.level > 0 then
			-- only the level carries the difficulty colour; the title stays in ink
			local r, g, bl
			if db.difficultyColor then r, g, bl = difficulty(q.level) end
			local lv = ("[%d]"):format(q.level)
			if r then
				lv = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * ink.dim * 255), math.floor(g * ink.dim * 255), math.floor(bl * ink.dim * 255), lv)
			end
			title = lv .. " " .. title
		end
		b.text:SetText(title)
		color(b.text, base)
		local th = b.text:GetStringHeight()
		b:SetSize(textW, th)
		place(b, 0, th, 2)
		b:Show()

		local list = {}
		if not st then
			for _, o in ipairs(objectives(q)) do
				if not (db.hideDone and o[2]) then list[#list + 1] = o end
			end
		end
		for _, o in ipairs(list) do
			nl = nl + 1
			local fs = line(nl)
			H.Fonts:Apply(fs, "body", db.objectiveSize, self)
			fs:SetWidth(textW - 10)
			fs:SetText("- " .. o[1])
			color(fs, o[3] and ink.failed or o[2] and ink.done or ink.text)
			place(fs, 10, fs:GetStringHeight(), 1)
			fs:Show()
		end
		y = y + db.questSpacing
	end
	for i = nt + 1, #self.titles do self.titles[i]:Hide(); self.titles[i].quest = nil end
	for i = nl + 1, #self.lines do self.lines[i]:Hide() end

	if nt == 0 then
		H.Fonts:Apply(f.empty, "body", db.objectiveSize, self)
		f.empty:SetText("No tracked quests")
		color(f.empty, ink.faint)
		f.empty:SetWidth(textW)
		f.empty:SetJustifyH("CENTER")
		place(f.empty, 0, f.empty:GetStringHeight(), db.questSpacing)
		f.empty:Show()
	else
		f.empty:Hide()
	end
	self.count = #quests
	return math.min(math.max(y - db.questSpacing, 0), limit)
end

--[[ Layout ]]

function Q:Layout()
	local f, db = self.frame, self.db
	if not f then return end
	local piece = Themes:Piece("scroll.rod")
	local art = self.PAPERS[db.paper] or self.PAPERS.light
	local W = db.width
	local h = db.rodSize
	local capW, shaft = h * 0.9, h * 0.5
	if piece then
		capW = piece.capW * h / piece.size[2]
		shaft = h * piece.shaft
		self:SkinRod(f.top, piece)
		self:SkinRod(f.bot, piece)
		self:LayoutRod(f.top, piece, h, capW)
		self:LayoutRod(f.bot, piece, h, capW)
	end
	f.top:SetShown(piece ~= nil)
	f.bot:SetShown(piece ~= nil)

	-- the paper hangs between the two rods, tucked under the ends
	local inset = math.floor(capW * 0.7)
	local textW = W - 2 * (inset + db.margin)
	local pad = shaft / 2 + db.margin * 0.6
	local padBottom = h / 2 + db.margin * 0.6   -- the bottom rod's ends reach higher than its shaft
	local contentH = self:Fill(math.max(textW, 40))
	local open = contentH + pad + padBottom
	self.openHeight = open

	-- rolled up: nothing, or a strip of paper showing how many quests there are
	if db.rolledCount then
		H.Fonts:Apply(f.strip, "header", db.objectiveSize, self)
		local ink = self.INK[db.paper] or self.INK.light
		f.strip:SetTextColor(ink.header[1], ink.header[2], ink.header[3])
		local n = self.count or 0
		f.strip:SetText(n == 1 and "1 quest" or n .. " quests")
		self.rolledHeight = h + f.strip:GetStringHeight() + 4
	else
		self.rolledHeight = 0
	end
	local paperH = db.rolledUp and self.rolledHeight or open
	if self.animH then paperH = self.animH end

	f:SetWidth(W)
	f.paperFrame:SetWidth(W - 2 * inset)
	f.paper:SetTexture(art.file)
	f.paper:SetAlpha(db.paperAlpha)
	f.paper:SetAllPoints(f.paperFrame)
	local dark, clear = { 0, 0, 0, art.shade * db.paperAlpha }, { 0, 0, 0, 0 }
	local s = f.shades
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT"); s[1]:SetPoint("BOTTOMLEFT"); s[1]:SetWidth(16); gradient(s[1], "HORIZONTAL", dark, clear)
	s[2]:SetPoint("TOPRIGHT"); s[2]:SetPoint("BOTTOMRIGHT"); s[2]:SetWidth(16); gradient(s[2], "HORIZONTAL", clear, dark)
	s[3]:SetPoint("TOPLEFT"); s[3]:SetPoint("TOPRIGHT"); s[3]:SetHeight(10); gradient(s[3], "VERTICAL", clear, dark)
	s[4]:SetPoint("BOTTOMLEFT"); s[4]:SetPoint("BOTTOMRIGHT"); s[4]:SetHeight(10); gradient(s[4], "VERTICAL", dark, clear)

	f.paperFrame:ClearAllPoints()
	f.paperFrame:SetPoint("TOPLEFT", f.top, "CENTER", -W / 2 + inset, 0)
	self:SetPaperHeight(paperH)
	f.content:ClearAllPoints()
	f.content:SetPoint("TOPLEFT", f.paperFrame, "TOPLEFT", db.margin, -pad)
	f.content:SetSize(math.max(textW, 40), math.max(contentH, 1))

	if f.mover then H.Movers:Apply(f.mover) end
end

-- the paper's height (0 = rolled up); the frame and the bottom rod follow it
function Q:SetPaperHeight(ph)
	local f, db = self.frame, self.db
	local h = db.rodSize
	f.top:ClearAllPoints()
	f.top:SetPoint("TOPLEFT", f, "TOPLEFT")
	f.top:SetPoint("TOPRIGHT", f, "TOPRIGHT")
	f.bot:ClearAllPoints()
	local gap = ph > 1 and 0 or h * 0.45    -- fully closed: the rods overlap a little
	f.bot:SetPoint("TOPLEFT", f.top, "TOPLEFT", 0, -ph - gap)
	f.bot:SetPoint("TOPRIGHT", f.top, "TOPRIGHT", 0, -ph - gap)
	f.paperFrame:SetHeight(math.max(ph, 0.01))
	f.paperFrame:SetShown(ph > 1)
	-- the quests show while the paper is open; the count shows on the strip
	local rolled = self.db.rolledUp and not self.animH
	f.content:SetShown(not rolled)
	f.strip:SetShown(rolled and self.db.rolledCount)
	f:SetHeight(h + ph + gap)
	cropPaper(f.paper, self.PAPERS[db.paper] or self.PAPERS.light, f.paperFrame:GetWidth(), ph)
end

--[[ Rolling up and down ]]

function Q:SetRolledUp(on)
	self.db.rolledUp = on and true or false
	local f = self.frame
	if not f then return end
	local from = self.animH or (on and self.openHeight or self.rolledHeight or 0)
	local to = on and (self.rolledHeight or 0) or (self.openHeight or 0)
	local t, dur = 0, 0.25
	f:SetScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		local p = math.min(t / dur, 1)
		local e = 1 - (1 - p) ^ 3
		self.animH = from + (to - from) * e
		self:SetPaperHeight(self.animH)
		if p >= 1 then
			f:SetScript("OnUpdate", nil)
			self.animH = nil
			self:Layout()
		end
	end)
end

--[[ Refresh: many quest events come at once, so they are merged ]]

function Q:Refresh()
	if self.pending then return end
	self.pending = true
	C_Timer.After(0.1, function()
		self.pending = nil
		if self.frame and self.frame:IsShown() then self:Layout() end
	end)
end

--[[ The game's tracker ]]

-- Hidden with Hide() and kept hidden from OnShow, like Questie does on this
-- client: the frame is protected and reparenting it taints the game's layout.
local blizzHooked = {}
local function blizzTrackers()
	local t = {}
	for _, name in ipairs({ "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }) do
		if _G[name] then t[#t + 1] = _G[name] end
	end
	return t
end

function Q:ApplyBlizzard()
	local hide = self.db.hideBlizzard and not self.stepAside
	if InCombatLockdown() then
		H:RunOutOfCombat(function() Q:ApplyBlizzard() end, "Quests.blizzard")
		return
	end
	self.hidingBlizzard = hide
	for _, fr in ipairs(blizzTrackers()) do
		if not blizzHooked[fr] then
			blizzHooked[fr] = true
			fr:HookScript("OnShow", function(s)
				if Q.hidingBlizzard then
					if InCombatLockdown() and s:IsProtected() then
						H:RunOutOfCombat(function() Q:ApplyBlizzard() end, "Quests.blizzard")
					else
						s:Hide()
					end
				end
			end)
		end
		if hide then fr:Hide() elseif self.hidBlizzard then fr:Show() end
	end
	self.hidBlizzard = hide
end

--[[ Questie ]]

-- Questie's own tracker is on: ours steps aside and the game's tracker is left to Questie.
function Q:QuestieTracker()
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie")
	if not loaded then return false end
	local ok, on = pcall(function() return Questie.db.profile.trackerEnabled end)
	return not ok or on ~= false
end

function Q:CheckQuestie()
	local aside = self:QuestieTracker()
	if aside ~= self.stepAside then
		self.stepAside = aside
		if aside then H:Debug("Quests: Questie's tracker is on, the scroll steps aside.") end
	end
	self.frame:SetShown(not aside)
	self:ApplyBlizzard()
end

--[[ Lifecycle ]]

function Q:OnEnable()
	local f = self:Create()
	f.mover = H:RegisterMover(f, "Quests.tracker", {
		label = "Quests", default = { "TOPRIGHT", -40, -300 }, scalable = true,
		isShown = function() return not Q.stepAside end,
	})
	self:Layout()
	self:CheckQuestie()
	C_Timer.After(2, function() Q:CheckQuestie() end)

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED",
		"QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	pcall(ev.RegisterUnitEvent, ev, "UNIT_QUEST_LOG_CHANGED", "player")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, e)
		if e == "PLAYER_REGEN_DISABLED" then
			if Q.db.combatRollUp and not Q.db.rolledUp then
				Q.combatRolled = true
				Q:SetRolledUp(true)
			end
		elseif e == "PLAYER_REGEN_ENABLED" then
			if Q.combatRolled then
				Q.combatRolled = nil
				Q:SetRolledUp(false)
			end
		else
			Q:Refresh()
		end
	end)

	H:On("THEME_CHANGED", function() Q:Layout() end)
	H:On("FONTS_CHANGED", function() Q:Layout() end)
end

function Q:OnProfileChanged()
	self:Layout()
	self:ApplyBlizzard()
end
