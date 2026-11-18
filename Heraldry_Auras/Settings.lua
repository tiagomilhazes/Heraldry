--[[
	Heraldry_Auras - Settings.lua
	Options page. Tabs: Power orb | Life orb.
]]

local H = Heraldry
local AU = H.Modules.byName.Auras

local function field(name)
	return function() return AU.db[name] end, function(v)
		AU.db[name] = v
		AU:Layout()
	end
end

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
			get, set = field("socketInactive")
			page:Toggle({ label = "Show inactive auras faded", desc = "Off: an aura that is not on you leaves the plain gem.", get = get, set = set })
		end },
		{ key = "life", label = "Life orb", build = function(page)
			page:Text("The life orb's gems light in a debuff's colour while you have one: top magic, right curse, bottom poison, left disease.")
			page:Section("Debuffs")
			local get, set = field("debuffSockets")
			page:Toggle({ label = "Light the life orb's gems", get = get, set = set })
			get, set = field("debuffPulse")
			page:Toggle({ label = "Pulse when you can remove it", get = get, set = set })
		end },
	},
})
