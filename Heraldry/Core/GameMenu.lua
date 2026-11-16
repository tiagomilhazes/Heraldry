--[[
	Heraldry - Core/GameMenu.lua
	"Heraldry" button in the game menu (Escape), right under "AddOns".

	The game menu rebuilds its buttons on every open (Layout). After each
	rebuild we place our button under the anchor and push the buttons below it
	down. The anchor is "AddOns" on purpose: EllesmereUI puts its own button
	under "Shop"/"Options", so the two never land in the same spot.
]]

local _, ns = ...
local H = ns.H

local BUTTON_GAP = 4

local function findAnchor()
	local fallback
	for b in GameMenuFrame.buttonPool:EnumerateActive() do
		local text = b:GetText()
		if text == ADDONS then return b end
		if text == GAMEMENU_OPTIONS then fallback = b end
	end
	return fallback
end

local function setup()
	if not (GameMenuFrame and GameMenuFrame.buttonPool) then
		H:Debug("Game menu not found: no Heraldry button")
		return
	end

	local btn = CreateFrame("Button", "Heraldry_GameMenuButton", GameMenuFrame, "MainMenuFrameButtonTemplate")
	btn:SetText("|cff" .. H.color .. "Heraldry|r")
	btn:Hide()
	btn:SetScript("OnClick", function()
		HideUIPanel(GameMenuFrame)
		H:OpenOptions()
	end)

	local baseHeight
	hooksecurefunc(GameMenuFrame, "Layout", function()
		-- Leave the menu alone in combat.
		if InCombatLockdown() then
			btn:Hide()
			return
		end
		local anchor = findAnchor()
		if not anchor then
			btn:Hide()
			return
		end

		local w, h = anchor:GetSize()
		btn:SetSize(w, h)
		btn:ClearAllPoints()
		btn:SetPoint("TOP", anchor, "BOTTOM", 0, -BUTTON_GAP)
		btn:Show()
		local extra = h + BUTTON_GAP

		-- Push down every Blizzard button below the anchor.
		local anchorBottom = anchor:GetBottom()
		if anchorBottom then
			for b in GameMenuFrame.buttonPool:EnumerateActive() do
				local top = b:GetTop()
				if b ~= anchor and top and top < anchorBottom + 2 then
					local p, rel, rp, x, y = b:GetPoint(1)
					if p then
						b:ClearAllPoints()
						b:SetPoint(p, rel, rp, x, (y or 0) - extra)
					end
				end
			end
		end

		baseHeight = baseHeight or GameMenuFrame:GetHeight()
		GameMenuFrame:SetHeight(baseHeight + extra)
	end)
end

H:On("READY", setup)
