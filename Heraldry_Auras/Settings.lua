--[[
	Heraldry_Auras - Settings.lua
	Options page. Tabs: Power orb | Life orb | Buffs | Debuffs | Font.
]]

local H = Heraldry
local AU = H.Modules.byName.Auras

local function field(name)
	return function() return AU.db[name] end, function(v)
		AU.db[name] = v
		AU:Layout()
	end
end

local function rowField(name)
	return function() return AU.db[name] end, function(v)
		AU.db[name] = v
		if AU.LayoutRows then AU:LayoutRows() end
	end
end

local function pct(v) return ("%d%%"):format(v * 100 + 0.5) end

local WHERE = { "Top gem", "Right gem", "Bottom gem", "Left gem" }

H:RegisterOptionsPage({
	key = "auras",
	label = "Auras",
	desc = "Your auras set into the orbs' gems. Needs the Orbs module.",
	group = "modules",
	order = 45,
	tabs = {
		{ key = "power", label = "Power orb", build = function(page)
			page:Text("Each gem of the power orb holds an aura you choose: while it is on you, its icon sits in the gem and darkens as it runs out. Type the spell's name (or its ID). Saved per character, so each class keeps its own (a paladin starts with his seals).")
			page:Section("Gems")
			for i = 1, 4 do
				page:Input({
					label = WHERE[i],
					placeholder = "Spell name",
					maxLetters = 64,
					button = "Set",
					get = function() return AU:Chosen()[i] end,
					onSubmit = function(text)
						AU:SetChosen(i, strtrim(text or ""))
						return true
					end,
				})
			end
			page:Section("Look")
			local get, set = field("socketsShow")
			page:Toggle({ label = "Show auras in the power orb", get = get, set = set })
			get, set = field("socketScale")
			page:Slider({ label = "Icon size", desc = "Against the size of the gem.", min = 1, max = 3, step = 0.05, get = get, set = set })
			get, set = field("socketDrain")
			page:Toggle({ label = "Darken as it runs out", get = get, set = set })
			get, set = field("socketTime")
			page:Toggle({ label = "Time left", desc = "In the middle of each gem.", get = get, set = set })
			get, set = field("socketTimeSize")
			page:Slider({ label = "Time left size", min = 6, max = 24, step = 1, get = get, set = set })
			get, set = field("socketInactive")
			page:Toggle({ label = "Show inactive auras faded", desc = "Off: an aura that is not on you leaves the plain gem.", get = get, set = set })
			page:Preview("sockets")
		end },
		{ key = "life", label = "Life orb", build = function(page)
			page:Text("The life orb's gems light in a debuff's colour while you have one: top magic, right curse, bottom poison, left disease.")
			page:Section("Debuffs")
			local get, set = field("debuffSockets")
			page:Toggle({ label = "Light the life orb's gems", get = get, set = set })
			get, set = field("debuffPulse")
			page:Toggle({ label = "Pulse when you can remove it", get = get, set = set })
			get, set = field("debuffTime")
			page:Toggle({ label = "Time left", desc = "In the middle of each lit gem: the debuff of that type.", get = get, set = set })
			get, set = field("debuffTimeSize")
			page:Slider({ label = "Time left size", min = 6, max = 24, step = 1, get = get, set = set })
			page:Text("Preview: the \"Orb sockets\" switch in the Power orb tab shows both orbs.", 20)
		end },
		{ key = "buffs", label = "Buffs", build = function(page)
			page:Text("All your buffs in a small row at the top of the screen, by the minimap. Right click one to cancel it, in combat too. Move it in edit mode (\"Buffs\").")
			page:Section("Buffs")
			local get, set = rowField("buffsShow")
			page:Toggle({ label = "Show the buff row", get = get, set = set })
			get, set = rowField("buffsScale")
			page:Slider({ label = "Size", min = 0.5, max = 2, step = 0.05, format = pct, get = get, set = set })
			get, set = rowField("buffsPerRow")
			page:Slider({ label = "Icons per row", min = 4, max = 24, step = 1, get = get, set = set })
			get, set = rowField("buffsTime")
			page:Toggle({ label = "Time left", desc = "Under each icon. Applies after a /reload.", get = get, set = set })
			get, set = rowField("hideBlizzardAuras")
			page:Toggle({ label = "Hide the game's buff and debuff frames", get = get, set = set })
		end },
		{ key = "debuffs", label = "Debuffs", build = function(page)
			page:Text("Serious debuffs (crowd control: stuns, fears, roots, silences...) as big icons over the life orb. The life orb's gems already show the debuff types. Move them in edit mode (\"Serious debuffs\").")
			page:Section("Debuffs")
			local get, set = rowField("debuffsShow")
			page:Toggle({ label = "Show serious debuffs", get = get, set = set })
			get, set = rowField("debuffsAll")
			page:Toggle({ label = "Every debuff", desc = "Off: crowd control only.", get = get, set = set })
			get, set = rowField("debuffsScale")
			page:Slider({ label = "Size", min = 0.5, max = 2.5, step = 0.05, format = pct, get = get, set = set })
			get, set = rowField("debuffsGrow")
			page:Dropdown({
				label = "Grow",
				values = function()
					return {
						{ value = "right", text = "Right (a row)" }, { value = "left", text = "Left (a row)" },
						{ value = "up", text = "Up (a column)" }, { value = "down", text = "Down (a column)" },
					}
				end,
				get = get, set = set,
			})
			get, set = rowField("debuffsPerRow")
			page:Slider({ label = "Icons per row or column", min = 2, max = 16, step = 1, get = get, set = set })
			get, set = rowField("debuffsTime")
			page:Toggle({ label = "Time left", desc = "Inside each icon. Applies after a /reload.", get = get, set = set })
			page:Preview("debuffs")
		end },
		{ key = "font", label = "Font", build = function(page)
			page:Section("Rows")
			local get, set = rowField("rowsTimeSize")
			page:Slider({ label = "Time left size (buffs and debuffs)", desc = "Applies after a /reload.", min = 6, max = 20, step = 1, get = get, set = set })
			page:FontSection(AU, function() AU:Layout() end)
		end },
	},
})
