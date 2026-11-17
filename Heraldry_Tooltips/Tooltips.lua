--[[
	Heraldry_Tooltips - Tooltips.lua
	The game's tooltips on paper (prototype T2): dark parchment by default,
	or light parchment / dark glass, with a thin rim in the theme's metal.

	  - only the background and the border are replaced; the contents are the
	    game's own, so nothing is read from them (safe with secret values)
	  - the rim takes the item's quality colour (option)
	  - player names in their class colour (option)
	  - the health bar becomes a thin flat strip under the tooltip
	  - where they show: the game's place, a fixed place (a mover), or the cursor
	  - unit tooltips can be hidden in combat
	  - on light paper every line is recoloured as ink
]]

local H = Heraldry
local Themes = H.Themes
local Paper = H.Paper

local TT = H:NewModule("Tooltips", {
	label = "Tooltips",
	fonts = true,
	defaults = {
		paper = "dark",
		paperAlpha = 0.95,
		qualityRim = true,
		classNames = true,
		healthBar = true,
		barHeight = 4,
		anchor = "game",          -- "game" | "fixed" | "cursor"
		cursorX = 20, cursorY = 10,
		hideCombat = false,
		headerSize = 14,
		textSize = 12,
		smallSize = 11,
		fontOverride = true,
		fontOutline = "NONE",
	},
})

TT.NAMES = {
	"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
	"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip",
	"WorldMapTooltip", "FriendsTooltip", "QuickKeybindTooltip", "SmallTextTooltip",
}

TT.skinned = {}

local function accent()
	local r, g, b = Themes:Accent()
	if not r then r, g, b = 0.42, 0.34, 0.19 end
	return r, g, b
end

-- the game's border (NineSlice in this client) stays invisible
local function hideBorder(tt)
	local ns = tt.NineSlice
	if ns and not ns.hKilled then
		ns.hKilled = true
		ns:SetAlpha(0)
		hooksecurefunc(ns, "SetAlpha", function(s, a)
			if a > 0 and not s.hLock then
				s.hLock = true
				s:SetAlpha(0)
				s.hLock = false
			end
		end)
	end
end

function TT:Skin(tt)
	if not tt or tt.hSkin or tt:IsForbidden() then return end
	tt.hSkin = true
	hideBorder(tt)
	tt.hPaper = tt:CreateTexture(nil, "BACKGROUND", nil, -8)
	tt.hPaper:SetAllPoints()
	tt.hShades = {}
	for i = 1, 4 do tt.hShades[i] = tt:CreateTexture(nil, "BACKGROUND", nil, -6) end
	tt.hRim = {}
	for i = 1, 4 do tt.hRim[i] = tt:CreateTexture(nil, "BACKGROUND", nil, -5) end
	local r = tt.hRim
	r[1]:SetPoint("TOPLEFT"); r[1]:SetPoint("TOPRIGHT"); r[1]:SetHeight(1)
	r[2]:SetPoint("BOTTOMLEFT"); r[2]:SetPoint("BOTTOMRIGHT"); r[2]:SetHeight(1)
	r[3]:SetPoint("TOPLEFT"); r[3]:SetPoint("BOTTOMLEFT"); r[3]:SetWidth(1)
	r[4]:SetPoint("TOPRIGHT"); r[4]:SetPoint("BOTTOMRIGHT"); r[4]:SetWidth(1)
	tt:HookScript("OnSizeChanged", function(s) Paper:Crop(s.hPaper, TT.db.paper, s:GetSize()) end)
	tt:HookScript("OnShow", function(s)
		hideBorder(s)
		TT:Ink(s)
	end)
	if tt.HasScript and tt:HasScript("OnTooltipCleared") then
		tt:HookScript("OnTooltipCleared", function(s) TT:SetRim(s) end)
	end
	self.skinned[#self.skinned + 1] = tt
	self:Paint(tt)
end

function TT:SetRim(tt, r, g, b)
	if not tt.hRim then return end
	if not r then r, g, b = accent() end
	for _, t in ipairs(tt.hRim) do t:SetColorTexture(r, g, b, 0.9) end
end

function TT:Paint(tt)
	local db = self.db
	Paper:Apply(tt.hPaper, db.paper, db.paperAlpha)
	Paper:Crop(tt.hPaper, db.paper, tt:GetSize())
	Paper:Shades(tt.hShades, db.paper, db.paperAlpha, 10)
	self:SetRim(tt)
end

--[[ Light paper: every line as ink ]]

function TT:Ink(tt)
	if not Paper:IsInk(self.db.paper) or not tt.NumLines then return end
	local name = tt:GetName()
	if not name then return end
	for i = 1, tt:NumLines() do
		for _, side in ipairs({ "Left", "Right" }) do
			local fs = _G[name .. "Text" .. side .. i]
			if fs and fs:IsShown() then
				local ok, r, g, b = pcall(fs.GetTextColor, fs)
				if ok and type(r) == "number" then
					fs:SetTextColor(Paper:InkOf(r, g, b))
				end
			end
		end
	end
end

--[[ Contents: rim by item quality, class colours, combat ]]

local function itemQuality(tt)
	if not tt.GetItem then return nil end
	local _, link = tt:GetItem()
	if not link then return nil end
	if C_Item and C_Item.GetItemQualityByID then
		local q = C_Item.GetItemQualityByID(link)
		if q then return q end
	end
	return select(3, GetItemInfo(link))
end

function TT:OnItem(tt)
	if not self.db.qualityRim or not tt.hRim then return end
	local ok, q = pcall(itemQuality, tt)
	if not ok or not q or q < 2 then return end
	local r, g, b
	if C_Item and C_Item.GetItemQualityColor then r, g, b = C_Item.GetItemQualityColor(q) end
	if not r and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
		local c = ITEM_QUALITY_COLORS[q]
		r, g, b = c.r, c.g, c.b
	end
	if r then self:SetRim(tt, r, g, b) end
end

function TT:OnUnit(tt)
	local db = self.db
	local ok, _, unit = pcall(tt.GetUnit, tt)
	if not ok or not unit then return end
	if db.hideCombat and InCombatLockdown() then
		tt:Hide()
		return
	end
	if db.classNames and tt == GameTooltip then
		pcall(function()
			if UnitIsPlayer(unit) then
				local _, class = UnitClass(unit)
				local c = class and (C_ClassColor and C_ClassColor.GetClassColor(class) or RAID_CLASS_COLORS[class])
				if c then GameTooltipTextLeft1:SetTextColor(c.r, c.g, c.b) end
			end
		end)
	end
end

--[[ Health bar: a thin flat strip under the tooltip ]]

function TT:StyleBar()
	local bar = GameTooltipStatusBar
	if not bar then return end
	local db = self.db
	if not bar.hBg then
		bar.hBg = bar:CreateTexture(nil, "BACKGROUND")
		bar.hBg:SetAllPoints()
		bar.hBg:SetColorTexture(0, 0, 0, 0.6)
	end
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -1)
	bar:SetHeight(db.barHeight)
	bar:SetAlpha(db.healthBar and 1 or 0)
end

--[[ Where tooltips show ]]

function TT:CreateAnchor()
	local f = CreateFrame("Frame", "HeraldryTooltipAnchor", UIParent)
	f:SetSize(200, 60)
	f:SetClampedToScreen(true)
	self.anchorFrame = f
	f.mover = H:RegisterMover(f, "Tooltips.anchor", {
		label = "Tooltips", default = { "BOTTOMRIGHT", -40, 240 },
		isShown = function() return TT.db.anchor == "fixed" end,
	})
end

function TT:Anchor(tt, parent)
	local db = self.db
	if db.anchor == "cursor" then
		tt:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", db.cursorX, db.cursorY)
	elseif db.anchor == "fixed" then
		tt:SetOwner(parent, "ANCHOR_NONE")
		tt:ClearAllPoints()
		tt:SetPoint("BOTTOMRIGHT", self.anchorFrame, "BOTTOMRIGHT")
	end
end

--[[ Fonts: the tooltip font objects ]]

function TT:ApplyFonts()
	local db = self.db
	for _, it in ipairs({
		{ GameTooltipHeaderText, "header", db.headerSize },
		{ GameTooltipText, "body", db.textSize },
		{ GameTooltipTextSmall, "body", db.smallSize },
	}) do
		local obj = it[1]
		if obj then
			local path, size, flags, shadow = H.Fonts:Resolve(it[2], it[3], self)
			obj:SetFont(path, size, flags)
			obj:SetShadowColor(0, 0, 0, 1)
			obj:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
		end
	end
end

--[[ Layout ]]

function TT:Layout()
	for _, tt in ipairs(self.skinned) do self:Paint(tt) end
	self:StyleBar()
	self:ApplyFonts()
	if self.anchorFrame then H.Movers:Apply(self.anchorFrame.mover) end
end

function TT:SkinAll()
	for _, n in ipairs(self.NAMES) do
		local tt = _G[n]
		if tt then self:Skin(tt) end
	end
end

function TT:OnEnable()
	self:CreateAnchor()
	self:SkinAll()
	self:Layout()

	-- every tooltip the game fills (addons' own included) gets skinned on its way
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		local all = TooltipDataProcessor.AllTypes or "ALL"
		TooltipDataProcessor.AddTooltipPostCall(all, function(tt)
			if tt and not tt.hSkin and not tt:IsForbidden() then TT:Skin(tt) end
			if tt and tt.hSkin then TT:Ink(tt) end
		end)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt) TT:OnItem(tt) end)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) TT:OnUnit(tt) end)
	else
		GameTooltip:HookScript("OnTooltipSetItem", function(tt) TT:OnItem(tt) end)
		GameTooltip:HookScript("OnTooltipSetUnit", function(tt) TT:OnUnit(tt) end)
	end

	-- the game redraws its border on some tooltips: keep it hidden
	if SharedTooltip_SetBackdropStyle then
		hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tt)
			if tt and tt.hSkin then hideBorder(tt) end
		end)
	end
	if GameTooltip_SetDefaultAnchor then
		hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent) TT:Anchor(tt, parent) end)
	end

	-- tooltips made later by the game (first time a window opens)
	C_Timer.After(2, function() TT:SkinAll() end)
	H:On("THEME_CHANGED", function() TT:Layout() end)
	H:On("FONTS_CHANGED", function() TT:ApplyFonts() end)
end

function TT:OnProfileChanged()
	self:Layout()
end
