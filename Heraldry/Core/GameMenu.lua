--[[
	Heraldry - Core/GameMenu.lua
	"Heraldry" button in the game menu (Escape), right under "AddOns".

	The game menu rebuilds its list every time it opens (InitButtons). We add
	our button with the menu's own AddButton, so it gets the native look and
	spacing, then give it a layout index just after "AddOns" so the menu's
	layout places it there. Nothing is moved by hand.
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

local function findButton(menu, text)
	for b in menu.buttonPool:EnumerateActive() do
		if b:GetText() == text then return b end
	end
end

local function onInitButtons(menu)
	local ok, err = pcall(menu.AddButton, menu, LABEL, open)
	if not ok then
		H:Debug("Game menu: AddButton failed:", err)
		return
	end
	local mine = findButton(menu, LABEL)
	local anchor = findButton(menu, ADDONS) or findButton(menu, GAMEMENU_OPTIONS)
	if mine and anchor and anchor.layoutIndex then
		mine.layoutIndex = anchor.layoutIndex + 0.5
		if menu.MarkDirty then menu:MarkDirty() end
	else
		H:Debug("Game menu: anchor not found, button left at the end")
	end
end

local menu = GameMenuFrame
if menu and menu.InitButtons and menu.AddButton and menu.buttonPool then
	hooksecurefunc(menu, "InitButtons", onInitButtons)
else
	H:Debug("Game menu API not found: no Heraldry button")
end
