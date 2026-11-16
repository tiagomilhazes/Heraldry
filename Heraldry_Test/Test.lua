--[[
	Heraldry_Test - Test.lua
	A gold square near the top of the screen. Its size and visibility live in
	the profile, so switching profiles changes it right away. It exists only to
	prove the module system and will be removed with the first real module.
]]

local H = Heraldry

local Test = H:NewModule("Test", {
	label = "Test module",
	defaults = { show = true, size = 64 },
})

function Test:OnInitialize()
	H:Debug("Test: OnInitialize")
end

function Test:OnEnable()
	H:Debug("Test: OnEnable")
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetPoint("TOP", 0, -140)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.91, 0.69, 0.29, 0.85)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.text:SetPoint("TOP", f, "BOTTOM", 0, -4)
	self.frame = f
	self:Apply()
end

function Test:OnProfileChanged()
	H:Debug("Test: OnProfileChanged")
	self:Apply()
end

function Test:Apply()
	local f = self.frame
	if not f then return end
	f:SetSize(self.db.size, self.db.size)
	f:SetShown(self.db.show)
	f.text:SetText(("Test module - profile: %s - size: %d"):format(H.char.profile, self.db.size))
end

H:RegisterOptionsPage({
	key = "test",
	label = "Test module",
	desc = "Proves the module system. Will be removed with the first real module.",
	group = "modules",
	order = 100,
	build = function(page)
		page:Section("Square")
		page:Toggle({
			label = "Show the square",
			desc = "Saved in the active profile.",
			get = function() return Test.db.show end,
			set = function(v)
				Test.db.show = v
				Test:Apply()
			end,
		})
		page:Slider({
			label = "Size",
			desc = "Saved in the active profile.",
			min = 24, max = 160, step = 4,
			get = function() return Test.db.size end,
			set = function(v)
				Test.db.size = v
				Test:Apply()
			end,
		})
		page:Button({
			label = "Reset this module",
			desc = "Back to the defaults, in the active profile only.",
			text = "Reset",
			kind = "danger",
			onClick = function()
				Test:ResetSettings()
				page:Refresh()
			end,
		})
	end,
})
