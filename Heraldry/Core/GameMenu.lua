--[[
	Heraldry - Core/GameMenu.lua
	"Heraldry" button in the game menu (Escape), right under "AddOns".

	Two kinds of game menu exist:
	- Modern (InitButtons/AddButton): the list is rebuilt on every open. We add
	  our button with AddButton and give it a layout index right after AddOns.
	- Classic (fixed buttons chained one under another, as in WoW Forever): we
	  put our button under AddOns, hook the next button to ours and make the
	  menu taller. Redone on every open, because the game re-anchors its
	  buttons when the menu shows.
]]

local _, ns = ...
local H = ns.H

local LABEL = "|cff" .. H.color .. "Heraldry|r"

local function open()
	if GameMenuFrame:IsShown() then
		if not pcall(HideUIPanel, GameMenuFrame) then GameMenuFrame:Hide() end
	end
	H:OpenOptions()
end

--[[ Modern menu ]]

local function findPooled(menu, text)
	for b in menu.buttonPool:EnumerateActive() do
		if b:GetText() == text then return b end
	end
end

local function setupModern(menu)
	hooksecurefunc(menu, "InitButtons", function(m)
		if not pcall(m.AddButton, m, LABEL, open) then return end
		local mine = findPooled(m, LABEL)
		local anchor = findPooled(m, ADDONS) or findPooled(m, GAMEMENU_OPTIONS)
		if mine and anchor and anchor.layoutIndex then
			mine.layoutIndex = anchor.layoutIndex + 0.5
			if m.MarkDirty then m:MarkDirty() end
		end
	end)
end

--[[ Classic menu ]]

local function findChild(menu, text, except)
	for _, child in ipairs({ menu:GetChildren() }) do
		if child ~= except and child:IsObjectType("Button") and child:GetText() == text then
			return child
		end
	end
end

local function setupClassic(menu)
	local template = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("GameMenuButtonTemplate") and "GameMenuButtonTemplate" or "UIPanelButtonTemplate"
	local btn = CreateFrame("Button", "GameMenuButtonHeraldry", menu, template)
	btn:SetText(LABEL)
	btn:SetScript("OnClick", open)

	local function place()
		local anchor = findChild(menu, ADDONS, btn) or findChild(menu, GAMEMENU_OPTIONS, btn)
		if not anchor then
			btn:Hide()
			H:Debug("Game menu: no AddOns/Options button to anchor to")
			return
		end
		btn:SetSize(anchor:GetSize())
		btn:Show()

		-- The button hanging under the anchor now hangs under ours.
		local gap = -1
		local moved = false
		for _, child in ipairs({ menu:GetChildren() }) do
			if child ~= btn and child:IsObjectType("Button") then
				for i = 1, child:GetNumPoints() do
					local p, rel, rp, x, y = child:GetPoint(i)
					if rel == anchor and p == "TOP" then
						gap = y or gap
						child:SetPoint(p, btn, rp, x, y)
						moved = true
					end
				end
			end
		end
		btn:ClearAllPoints()
		btn:SetPoint("TOP", anchor, "BOTTOM", 0, gap)
		-- Only grow the menu when the game re-anchored its buttons (and so its height).
		if moved then
			menu:SetHeight(menu:GetHeight() + btn:GetHeight() - gap)
		end
	end

	menu:HookScript("OnShow", place)
end

local function setup()
	local menu = GameMenuFrame
	if not menu then
		H:Debug("Game menu: GameMenuFrame not found")
		return
	end
	if menu.InitButtons and menu.AddButton and menu.buttonPool then
		H:Debug("Game menu: modern")
		setupModern(menu)
	else
		H:Debug("Game menu: classic")
		setupClassic(menu)
	end
end

H:On("READY", setup)
