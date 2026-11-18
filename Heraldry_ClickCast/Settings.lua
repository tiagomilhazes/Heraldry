--[[
	Heraldry_ClickCast - Settings.lua
	Options page. Tabs: Bindings | Behaviour.
]]

local H = Heraldry
local CC = H.Modules.byName.ClickCast

-- the binding being made on the page
local pending = { action = "spell" }

local function rebuild()
	if H.Panel and H.Panel.Rebuild then H.Panel:Rebuild("clickcast") end
end

-- the spells in your spellbook (names, no ranks, no passives), sorted
local function knownSpells()
	local names, seen = {}, {}
	local function add(name, id)
		if not name or seen[name] then return end
		if id and C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id) then return end
		seen[name] = true
		names[#names + 1] = name
	end
	pcall(function()
		if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
			local bank = Enum.SpellBookSpellBank.Player
			for l = 1, C_SpellBook.GetNumSpellBookSkillLines() do
				local line = C_SpellBook.GetSpellBookSkillLineInfo(l)
				if line and not line.shouldHide then
					for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
						local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
						if info and info.itemType == Enum.SpellBookItemType.Spell then add(info.name, info.spellID) end
					end
				end
			end
		elseif GetNumSpellTabs then
			for t = 1, GetNumSpellTabs() do
				local _, _, offset, num = GetSpellTabInfo(t)
				for i = offset + 1, offset + num do
					local name = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
					add(name)
				end
			end
		end
	end)
	table.sort(names)
	return names
end

local function describe(b)
	local action = b.action
	local text
	if action == "spell" or action == "macro" or action == "item" then
		text = b.value ~= "" and b.value or "?"
	else
		for _, a in ipairs(CC.ACTIONS) do if a.value == action then text = a.text end end
	end
	if b.harm and b.harm ~= "" then text = text .. "  ·  enemies: " .. b.harm end
	if b.dead and b.dead ~= "" then text = text .. "  ·  dead: " .. b.dead end
	return text
end

-- the capture row: a wide button you click with the combination you want
local function captureRow(page)
	local UI, C = H.UI, H.UI.colors
	local f = CreateFrame("Frame", nil, page.frame)
	UI.Fill(f, C.row)
	local l = UI.Text(f, 13, C.text)
	l:SetPoint("TOPLEFT", 14, -10)
	l:SetText("Combination")
	local d = UI.Text(f, 11, C.dim)
	d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -5)
	d:SetText("Hold Shift, Ctrl or Alt and click the box with any mouse button.")
	local b = UI.Button(f, "", 260)
	b:SetHeight(32)
	b:SetPoint("RIGHT", -14, 0)
	b:RegisterForClicks("AnyUp")
	local function paint()
		if pending.button then
			b.label:SetText(CC:Label(pending))
			b.label:SetTextColor(unpack(C.accent))
		else
			b.label:SetText("Click here with the combination")
			b.label:SetTextColor(unpack(C.faint))
		end
	end
	b:SetScript("OnClick", function(_, button)
		local n
		for i, name in ipairs(CC.BUTTONS) do if name == button then n = i end end
		if not n then return end
		pending.mods, pending.button = CC:CurrentMods(), n
		-- a combination already bound: start from what it does
		local _, old = CC:Find(pending.mods, n)
		if old then
			pending.action, pending.value, pending.harm, pending.dead = old.action, old.value, old.harm, old.dead
		end
		page:Refresh()
	end)
	page:OnRefresh(paint)
	page:Place(f, 50)
end

H:RegisterOptionsPage({
	key = "clickcast",
	label = "Click casting",
	desc = "Cast on unit frames with mouse clicks. Spells always use your highest rank.",
	group = "modules",
	order = 85,
	tabs = {
		{ key = "bindings", label = "Bindings", build = function(page)
			page:Text("Bindings are saved per character. Spells are kept by name, so a click casts the highest rank you know, and a new rank is used as soon as you learn it; write \"Flash of Light(Rank 2)\" to keep a rank. A spell can have an alternative for enemies and one for dead units. Changes made in combat apply when the fight ends.")

			page:Section("New binding")
			captureRow(page)
			page:Dropdown({
				label = "Action",
				values = function() return CC.ACTIONS end,
				get = function() return pending.action end,
				set = function(v) pending.action = v end,
			})
			page:Input({
				label = "Spell, macro text or item",
				desc = "For the actions that need one.",
				placeholder = "Flash of Light",
				maxLetters = 255,
				button = "Set",
				get = function() return pending.value or "" end,
				onSubmit = function(text) pending.value = strtrim(text or "") return true end,
			})
			page:Dropdown({
				label = "From your spellbook",
				desc = "Picks the spell above.",
				placeholder = "Choose a spell",
				values = function()
					local list = {}
					for _, name in ipairs(knownSpells()) do list[#list + 1] = { value = name, text = name } end
					return list
				end,
				get = function() return pending.value end,
				set = function(v) pending.value = v pending.action = "spell" end,
			})
			page:Input({
				label = "On enemies (optional)",
				desc = "Spell for the same click on a hostile unit.",
				placeholder = "Judgement",
				maxLetters = 128,
				button = "Set",
				get = function() return pending.harm or "" end,
				onSubmit = function(text) pending.harm = strtrim(text or "") return true end,
			})
			page:Input({
				label = "When dead (optional)",
				desc = "Spell for the same click on a dead friend.",
				placeholder = "Redemption",
				maxLetters = 128,
				button = "Set",
				get = function() return pending.dead or "" end,
				onSubmit = function(text) pending.dead = strtrim(text or "") return true end,
			})
			page:Button({
				label = "Save this binding",
				desc = "Replaces what the combination did before.",
				text = "Save",
				onClick = function()
					if not pending.button then
						H:Print("Click casting: click the combination box first.")
						return
					end
					local needs = pending.action == "spell" or pending.action == "macro" or pending.action == "item"
					if needs and (not pending.value or pending.value == "") then
						H:Print("Click casting: this action needs a spell, macro text or item.")
						return
					end
					CC:Set({
						mods = pending.mods, button = pending.button, action = pending.action,
						value = needs and pending.value or "",
						harm = pending.action == "spell" and pending.harm or nil,
						dead = pending.action == "spell" and pending.dead or nil,
					})
					wipe(pending)
					pending.action = "spell"
					rebuild()
				end,
			})

			page:Section("Your bindings")
			local list = CC:Bindings()
			if #list == 0 then
				page:Text("None yet. Your frames keep left click to target and right click for the menu until you bind those buttons.")
			end
			for _, b in ipairs(list) do
				page:Button({
					label = CC:Label(b),
					desc = describe(b),
					text = "Remove",
					kind = "danger",
					onClick = function()
						CC:Remove(b.mods, b.button)
						rebuild()
					end,
				})
			end
		end },
		{ key = "behaviour", label = "Behaviour", build = function(page)
			page:Section("Click casting")
			page:Toggle({
				label = "Use click casting",
				desc = "Off: frames go back to left click to target and right click for the menu.",
				get = function() return CC.db.enabled end,
				set = function(v)
					CC.db.enabled = v
					CC:ApplyAll()
				end,
			})
		end },
	},
})
