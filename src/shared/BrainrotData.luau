-- Brainrot Bay: shared catalogue and economy tuning.
--
-- DESIGN NOTE (written for this game, not copied from any template):
-- The cast is deliberately absurd and original: every character is a
-- household object fused with an animal and a catchphrase, invented here
-- so the game never reuses the genre's famous names. The economy is
-- tuned so a new player earns their first Common within a minute, a
-- Legendary takes a focused session, and a Brainrot God is a
-- rebirth-gated trophy, not a first-hour purchase.
--
-- Rarity ladder (weight = spawn chance on the conveyor, cost = buy
-- price, base = dollars earned per second while standing on a base):
--   Common 55% | Rare 25% | Epic 12% | Legendary 5.5% | Mythic 2% | Brainrot God 0.5%
-- Mutations roll independently at spawn and multiply earnings:
--   Normal x1, Gold x2 (8%), Diamond x5 (2.5%), Rainbow x10 (0.8%),
--   and the rare Cosmic x25 (0.15%) that only ever appears during a wave.
-- Rebirth resets cash and the base, but permanently multiplies ALL
-- future earnings (x2 per rebirth, stacking) and unlocks the next
-- rarity tier on the conveyor. The first rebirth needs $50,000 and
-- at least one Epic on the base; later rebirths scale x6 in cost.

local BrainrotData = {}

BrainrotData.RARITIES = {
	{ name = "Common",       color = Color3.fromRGB(170, 170, 170), weight = 55.0,  costMultiplier = 1,   incomeMultiplier = 1 },
	{ name = "Rare",         color = Color3.fromRGB(80, 160, 255),  weight = 25.0,  costMultiplier = 4,   incomeMultiplier = 3 },
	{ name = "Epic",         color = Color3.fromRGB(170, 90, 255),  weight = 12.0,  costMultiplier = 12,  incomeMultiplier = 8 },
	{ name = "Legendary",    color = Color3.fromRGB(255, 190, 40),  weight = 5.5,   costMultiplier = 40,  incomeMultiplier = 25 },
	{ name = "Mythic",       color = Color3.fromRGB(255, 70, 120),  weight = 2.0,   costMultiplier = 150, incomeMultiplier = 90 },
	{ name = "Brainrot God", color = Color3.fromRGB(0, 230, 190),   weight = 0.5,   costMultiplier = 600, incomeMultiplier = 400 },
}

BrainrotData.MUTATIONS = {
	{ name = "Normal",  color = Color3.fromRGB(255, 255, 255), weight = 88.55, multiplier = 1 },
	{ name = "Gold",    color = Color3.fromRGB(255, 215, 0),   weight = 8.0,   multiplier = 2 },
	{ name = "Diamond", color = Color3.fromRGB(120, 220, 255), weight = 2.5,   multiplier = 5 },
	{ name = "Rainbow", color = Color3.fromRGB(255, 120, 220), weight = 0.8,   multiplier = 10 },
	{ name = "Cosmic",  color = Color3.fromRGB(140, 80, 255),  weight = 0.15,  multiplier = 25 },
}

-- The cast. Each entry: display name, catchphrase shown above its head,
-- base body colour, base income ($/sec before rarity/mutation/rebirth),
-- and a "quirk" that decides its silhouette (hat, wings, long legs...).
-- All names are original inventions for Brainrot Bay.
BrainrotData.CHARACTERS = {
	{ name = "Sir Toastalot",      phrase = "I am bread, fear me!",      color = Color3.fromRGB(222, 184, 120), baseIncome = 2,   quirk = "Crown" },
	{ name = "Captain Noodle",     phrase = "Slurp responsibly.",        color = Color3.fromRGB(245, 222, 130), baseIncome = 3,   quirk = "Hat" },
	{ name = "DJ Fridge",          phrase = "Cool beats only.",          color = Color3.fromRGB(200, 220, 235), baseIncome = 5,   quirk = "Antenna" },
	{ name = "Baron Von Sock",     phrase = "One sock. Zero shame.",     color = Color3.fromRGB(150, 120, 200), baseIncome = 7,   quirk = "Cape" },
	{ name = "Professor Pickle",   phrase = "Brine is a lifestyle.",     color = Color3.fromRGB(90, 180, 80),   baseIncome = 10,  quirk = "Glasses" },
	{ name = "Madame Microwave",   phrase = "Beep. Your food is done.",  color = Color3.fromRGB(120, 120, 130), baseIncome = 14,  quirk = "Antenna" },
	{ name = "Lord Llama Latte",   phrase = "Foam is forever.",          color = Color3.fromRGB(210, 180, 140), baseIncome = 20,  quirk = "Hat" },
	{ name = "General Gnome Chomps", phrase = "Garden? More like mine.", color = Color3.fromRGB(200, 60, 60),   baseIncome = 28,  quirk = "Crown" },
	{ name = "Queen Quokka Couch", phrase = "Sit. Stay. Pay rent.",      color = Color3.fromRGB(190, 140, 90),  baseIncome = 40,  quirk = "Crown" },
	{ name = "Turbo Toilet Terry", phrase = "Flush with cash!",          color = Color3.fromRGB(240, 240, 250), baseIncome = 55,  quirk = "Cape" },
	{ name = "Sir Reginald Spoon", phrase = "Stirring things up.",       color = Color3.fromRGB(190, 190, 200), baseIncome = 75,  quirk = "Glasses" },
	{ name = "Emperor Eggplant",   phrase = "Bow to the aubergine.",     color = Color3.fromRGB(120, 60, 160),  baseIncome = 100, quirk = "Crown" },
}

BrainrotData.REBIRTH_BASE_COST = 50000
BrainrotData.REBIRTH_COST_GROWTH = 6
BrainrotData.REBIRTH_MULTIPLIER = 2 -- per rebirth, multiplies all income
BrainrotData.REBIRTH_MIN_RARITY_INDEX = 3 -- must own at least one Epic (index 3) to rebirth

BrainrotData.MAX_PLOT_SLOTS = 10
BrainrotData.CONVEYOR_SPAWN_SECONDS = 6
BrainrotData.WAVE_EVERY_SECONDS = 240
BrainrotData.WAVE_WARNING_SECONDS = 20
BrainrotData.WAVE_DURATION_SECONDS = 30
BrainrotData.STEAL_CHANNEL_SECONDS = 4 -- hold near a rival plot this long to steal
BrainrotData.STEAL_COOLDOWN_SECONDS = 30

function BrainrotData.rollRarity(rng)
	local total = 0
	for _, r in ipairs(BrainrotData.RARITIES) do
		total += r.weight
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for i, r in ipairs(BrainrotData.RARITIES) do
		acc += r.weight
		if roll <= acc then
			return i, r
		end
	end
	return 1, BrainrotData.RARITIES[1]
end

function BrainrotData.rollMutation(rng, waveActive)
	local total = 0
	for _, m in ipairs(BrainrotData.MUTATIONS) do
		total += m.weight
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for i, m in ipairs(BrainrotData.MUTATIONS) do
		-- Cosmic only ever rolls while the wave is sweeping the map.
		if m.name == "Cosmic" and not waveActive then
			continue
		end
		acc += m.weight
		if roll <= acc then
			return i, m
		end
	end
	return 1, BrainrotData.MUTATIONS[1]
end

function BrainrotData.incomePerSecond(character, rarityIndex, mutationIndex, rebirths)
	local rarity = BrainrotData.RARITIES[rarityIndex]
	local mutation = BrainrotData.MUTATIONS[mutationIndex]
	return character.baseIncome * rarity.incomeMultiplier * mutation.multiplier
		* (BrainrotData.REBIRTH_MULTIPLIER ^ rebirths)
end

function BrainrotData.buyCost(character, rarityIndex)
	return math.max(10, math.floor(character.baseIncome * 12 * BrainrotData.RARITIES[rarityIndex].costMultiplier))
end

function BrainrotData.rebirthCost(rebirths)
	return BrainrotData.REBIRTH_BASE_COST * (BrainrotData.REBIRTH_COST_GROWTH ^ rebirths)
end

return BrainrotData
