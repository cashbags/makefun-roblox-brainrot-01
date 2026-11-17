-- Brainrot Bay: server. Owns the whole game loop.
--
-- DESIGN NOTE: one server script runs everything, in this order:
--   1. Plots: eight player bases ring the island; each plot is a
--      coloured pad with ten numbered slots. A plot is claimed by the
--      first player who touches its pad; unclaimed plots stay neutral.
--   2. Conveyor: every 6 seconds a new brainrot spawns at the west end
--      of the belt and strolls east. It carries a ProximityPrompt with
--      its price; the first player who holds E and can pay owns it, and
--      the model walks itself onto a free slot of their base.
--   3. Earnings: once a second every owned brainrot pays its $/sec
--      (base x rarity x mutation x rebirth multiplier) into its owner's
--      cash. Cash lives in leaderstats so the leaderboard shows it.
--   4. Stealing: a rival's brainrot has a 4-second hold prompt. Finish
--      the hold and the brainrot moves to your base instead. A 30-second
--      cooldown per thief stops one player stripping a whole base.
--   5. The Wave: every 4 minutes the sea rises. A 20-second warning
--      sounds, then a glowing wall sweeps the island for 30 seconds.
--      Anyone caught outside their own base when the wall passes them
--      loses 10% of their cash and is flung back to spawn. Inside your
--      base you are safe -- so every wave ends in a dash home, usually
--      while carrying a fresh catch from the conveyor.
--   6. Rebirth: pay the scaling cost while owning at least one Epic
--      and your cash and base reset, but every future $/sec doubles.
-- The server never trusts the client: every RemoteEvent action is
-- re-validated here (cash, ownership, slot space, cooldowns).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local CharacterFactory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterFactory"))

local rng = Random.new()

-- Island layout: eight plots around the central plaza.
local PLOT_CENTERS = {
	Vector3.new(-52, 0, -52), Vector3.new(0, 0, -60), Vector3.new(52, 0, -52),
	Vector3.new(60, 0, 0), Vector3.new(52, 0, 52), Vector3.new(0, 0, 60),
	Vector3.new(-52, 0, 52), Vector3.new(-60, 0, 0),
}
local PLOT_COLORS = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 160, 255), Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(255, 200, 60), Color3.fromRGB(200, 90, 255), Color3.fromRGB(90, 220, 220),
	Color3.fromRGB(255, 130, 200), Color3.fromRGB(255, 140, 60),
}
local CONVEYOR_START = Vector3.new(-70, 1, -18)
local CONVEYOR_END = Vector3.new(70, 1, -18)
local CONVEYOR_WALK_SECONDS = 24

local plots = {} -- [plotIndex] = { owner, slots = { [slot] = entry }, pad, ownerLabel }
local players = {} -- [player] = { plotIndex, cash, rebirths, stealCooldownUntil }
local conveyor = {} -- active strolling brainrots: { entry, model, prompt }
local wave = { state = "calm", nextAt = os.clock() + BrainrotData.WAVE_EVERY_SECONDS, frontX = -90 }

local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage
local actionEvent = Instance.new("RemoteEvent")
actionEvent.Name = "Action"
actionEvent.Parent = remotes
local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "State"
stateEvent.Parent = remotes

local function makeBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return label
end

-- Build the eight plots in the 3D world: pad, fence posts, owner sign.
local function buildPlots()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for i, center in ipairs(PLOT_CENTERS) do
		local pad = Instance.new("Part")
		pad.Name = "Plot" .. i
		pad.Size = Vector3.new(26, 1, 26)
		pad.Position = center + Vector3.new(0, 0.5, 0)
		pad.Color = PLOT_COLORS[i]
		pad.Material = Enum.Material.SmoothPlastic
		pad.Anchored = true
		pad.Parent = folder
		local trim = Instance.new("Part")
		trim.Name = "Trim"
		trim.Size = Vector3.new(27, 0.3, 27)
		trim.Position = center + Vector3.new(0, 1.05, 0)
		trim.Color = Color3.fromRGB(255, 255, 255)
		trim.Material = Enum.Material.Neon
		trim.Anchored = true
		trim.Parent = pad
		local sign = Instance.new("Part")
		sign.Name = "Sign"
		sign.Size = Vector3.new(6, 4, 0.5)
		sign.Position = center + Vector3.new(0, 5, -13.5)
		sign.Color = Color3.fromRGB(40, 40, 50)
		sign.Anchored = true
		sign.Parent = folder
		local label = makeBillboard(sign, "FREE BASE\nTouch to claim!", Color3.fromRGB(255, 255, 255))
		label.Name = "OwnerLabel"
		plots[i] = { owner = nil, slots = {}, pad = pad, ownerLabel = label, center = center }
		-- Slot markers: ten small pads where brainrots stand.
		for s = 1, BrainrotData.MAX_PLOT_SLOTS do
			local row = math.floor((s - 1) / 5)
			local col = (s - 1) % 5
			local marker = Instance.new("Part")
			marker.Name = "Slot" .. s
			marker.Size = Vector3.new(4, 0.3, 4)
			marker.Position = center + Vector3.new(-8 + col * 4, 1.2, -4 + row * 8)
			marker.Color = Color3.fromRGB(255, 255, 255)
			marker.Transparency = 0.6
			marker.Material = Enum.Material.Neon
			marker.Anchored = true
			marker.Parent = folder
		end
	end
end

local function slotPosition(plotIndex, slot)
	local center = PLOT_CENTERS[plotIndex]
	local row = math.floor((slot - 1) / 5)
	local col = (slot - 1) % 5
	return center + Vector3.new(-8 + col * 4, 1.35, -4 + row * 8)
end

local function freeSlot(plotIndex)
	for s = 1, BrainrotData.MAX_PLOT_SLOTS do
		if plots[plotIndex].slots[s] == nil then
			return s
		end
	end
	return nil
end

local function placeOnPlot(entry, plotIndex, slot)
	local plot = plots[plotIndex]
	plot.slots[slot] = entry
	entry.plotIndex = plotIndex
	entry.slot = slot
	local target = CFrame.new(slotPosition(plotIndex, slot))
	local tween = TweenService:Create(entry.model.PrimaryPart, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = target })
	tween:Play()
	-- Rebuild the steal prompt so it now guards a base brainrot.
	if entry.prompt then
		entry.prompt:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal " .. entry.character.name
	prompt.ObjectText = entry.rarity.name .. " " .. entry.mutation.name .. " ($" .. entry.income .. "/s)"
	prompt.HoldDuration = BrainrotData.STEAL_CHANNEL_SECONDS
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = entry.model.PrimaryPart
	prompt.Triggered:Connect(function(thief)
		stealBrainrot(thief, entry)
	end)
	entry.prompt = prompt
end

function stealBrainrot(thief, entry)
	local thiefState = players[thief]
	if not thiefState or not thiefState.plotIndex then
		return
	end
	if os.clock() < thiefState.stealCooldownUntil then
		return
	end
	if entry.plotIndex == thiefState.plotIndex then
		return -- cannot steal your own brainrot
	end
	local slot = freeSlot(thiefState.plotIndex)
	if not slot then
		return
	end
	local victim = plots[entry.plotIndex].owner
	plots[entry.plotIndex].slots[entry.slot] = nil
	thiefState.stealCooldownUntil = os.clock() + BrainrotData.STEAL_COOLDOWN_SECONDS
	placeOnPlot(entry, thiefState.plotIndex, slot)
	if victim then
		stateEvent:FireClient(victim, { type = "stolen", name = entry.character.name, by = thief.DisplayName })
	end
	stateEvent:FireClient(thief, { type = "stole", name = entry.character.name })
end

local function spawnConveyorBrainrot()
	local character = BrainrotData.CHARACTERS[rng:NextInteger(1, #BrainrotData.CHARACTERS)]
	local rarityIndex, rarity = BrainrotData.rollRarity(rng)
	local mutationIndex, mutation = BrainrotData.rollMutation(rng, wave.state == "wave")
	local cost = BrainrotData.buyCost(character, rarityIndex)
	local income = BrainrotData.incomePerSecond(character, rarityIndex, mutationIndex, 0)
	local model = CharacterFactory.build(character, rarity, mutation, CFrame.new(CONVEYOR_START))
	model.Parent = workspace:WaitForChild("ConveyorBrainrots")
	local entry = {
		character = character, rarity = rarity, rarityIndex = rarityIndex,
		mutation = mutation, mutationIndex = mutationIndex,
		cost = cost, income = income, model = model, onConveyor = true,
	}
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy $" .. cost
	prompt.ObjectText = rarity.name .. " " .. mutation.name .. " ($" .. income .. "/s)"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		buyBrainrot(player, entry)
	end)
	entry.prompt = prompt
	table.insert(conveyor, entry)
	-- Stroll east along the belt, bobbing gently.
	local tween = TweenService:Create(model.PrimaryPart, TweenInfo.new(CONVEYOR_WALK_SECONDS, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(CONVEYOR_END),
	})
	tween:Play()
	task.delay(CONVEYOR_WALK_SECONDS, function()
		if entry.onConveyor then
			entry.onConveyor = false
			model:Destroy()
			for i, e in ipairs(conveyor) do
				if e == entry then
					table.remove(conveyor, i)
					break
				end
			end
		end
	end)
end

function buyBrainrot(player, entry)
	local state = players[player]
	if not state or not state.plotIndex or not entry.onConveyor then
		return
	end
	if state.cash < entry.cost then
		stateEvent:FireClient(player, { type = "denied", reason = "Need $" .. entry.cost .. " for " .. entry.character.name })
		return
	end
	local slot = freeSlot(state.plotIndex)
	if not slot then
		stateEvent:FireClient(player, { type = "denied", reason = "Your base is full! Rebirth or steal space." })
		return
	end
	state.cash -= entry.cost
	entry.onConveyor = false
	for i, e in ipairs(conveyor) do
		if e == entry then
			table.remove(conveyor, i)
			break
		end
	end
	-- Income scales with the buyer's rebirths from the moment it is placed.
	entry.income = BrainrotData.incomePerSecond(entry.character, entry.rarityIndex, entry.mutationIndex, state.rebirths)
	placeOnPlot(entry, state.plotIndex, slot)
	stateEvent:FireClient(player, { type = "bought", name = entry.character.name, rarity = entry.rarity.name })
end

local function claimPlot(player, plotIndex)
	local plot = plots[plotIndex]
	if plot.owner then
		return
	end
	local state = players[player]
	if state.plotIndex then
		return -- one base per player
	end
	plot.owner = player
	state.plotIndex = plotIndex
	plot.ownerLabel.Text = player.DisplayName .. "'s BASE"
	plot.ownerLabel.TextColor3 = PLOT_COLORS[plotIndex]
	stateEvent:FireClient(player, { type = "claimed", plot = plotIndex })
end

local function doRebirth(player)
	local state = players[player]
	if not state or not state.plotIndex then
		return
	end
	local cost = BrainrotData.rebirthCost(state.rebirths)
	if state.cash < cost then
		stateEvent:FireClient(player, { type = "denied", reason = "Rebirth needs $" .. cost })
		return
	end
	local hasEpic = false
	for _, entry in pairs(plots[state.plotIndex].slots) do
		if entry.rarityIndex >= BrainrotData.REBIRTH_MIN_RARITY_INDEX then
			hasEpic = true
			break
		end
	end
	if not hasEpic then
		stateEvent:FireClient(player, { type = "denied", reason = "Rebirth needs at least one Epic on your base." })
		return
	end
	state.cash -= cost
	state.rebirths += 1
	-- Clear the base, refund nothing: the multiplier is the reward.
	for slot, entry in pairs(plots[state.plotIndex].slots) do
		entry.model:Destroy()
		plots[state.plotIndex].slots[slot] = nil
	end
	state.cash = 0
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Rebirths.Value = state.rebirths
		leaderstats.Cash.Value = 0
	end
	stateEvent:FireClient(player, { type = "reborn", rebirths = state.rebirths })
end

actionEvent.OnServerEvent:Connect(function(player, action, _arg)
	if action == "Rebirth" then
		doRebirth(player)
	elseif action == "Collect" then
		-- Cash is automatic; Collect is a client feel-good ping that
		-- answers with the current income rate for the HUD.
		local state = players[player]
		if state then
			stateEvent:FireClient(player, { type = "income", perSecond = incomePerSecond(player) })
		end
	end
end)

function incomePerSecond(player)
	local state = players[player]
	if not state or not state.plotIndex then
		return 0
	end
	local total = 0
	for _, entry in pairs(plots[state.plotIndex].slots) do
		total += entry.income
	end
	return total
end

local function setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 100 -- starting cash: enough for the cheapest Common
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats
	players[player] = { plotIndex = nil, cash = 100, rebirths = 0, stealCooldownUntil = 0 }
	-- Touch a plot pad to claim it.
	for i, plot in ipairs(plots) do
		plot.pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local toucher = Players:GetPlayerFromCharacter(character)
			if toucher == player then
				claimPlot(player, i)
			end
		end)
	end
end

local function removePlayer(player)
	local state = players[player]
	if state and state.plotIndex then
		local plot = plots[state.plotIndex]
		plot.owner = nil
		plot.ownerLabel.Text = "FREE BASE\nTouch to claim!"
		plot.ownerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		for _, entry in pairs(plot.slots) do
			entry.model:Destroy()
		end
		plot.slots = {}
	end
	players[player] = nil
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(removePlayer)

-- The Wave: a glowing wall that sweeps west to east across the island.
local function buildWaveWall()
	local wall = Instance.new("Part")
	wall.Name = "WaveWall"
	wall.Size = Vector3.new(4, 60, 220)
	wall.Position = Vector3.new(-110, 30, 0)
	wall.Color = Color3.fromRGB(40, 140, 255)
	wall.Material = Enum.Material.Neon
	wall.Transparency = 0.35
	wall.Anchored = true
	wall.CanCollide = false
	wall.Parent = workspace
	return wall
end

local function waveHitsPlayer(player, frontX)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local state = players[player]
	-- Safe inside your own base: the base pad is your shelter.
	if state and state.plotIndex then
		local center = PLOT_CENTERS[state.plotIndex]
		if math.abs(root.Position.X - center.X) <= 13 and math.abs(root.Position.Z - center.Z) <= 13 then
			return false
		end
	end
	return root.Position.X <= frontX
end

buildPlots()
local conveyorFolder = Instance.new("Folder")
conveyorFolder.Name = "ConveyorBrainrots"
conveyorFolder.Parent = workspace
local waveWall = buildWaveWall()
waveWall.Transparency = 1 -- hidden until the wave runs

-- Earnings tick: 1 second.
task.spawn(function()
	while true do
		task.wait(1)
		for player, state in pairs(players) do
			local earned = incomePerSecond(player)
			if earned > 0 then
				state.cash += earned
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					leaderstats.Cash.Value = state.cash
				end
			end
		end
	end
end)

-- Conveyor spawner.
task.spawn(function()
	while true do
		task.wait(BrainrotData.CONVEYOR_SPAWN_SECONDS)
		spawnConveyorBrainrot()
	end
end)

-- State push to clients every 2 seconds: cash, income, wave timer.
task.spawn(function()
	while true do
		task.wait(2)
		for player, state in pairs(players) do
			local waveIn = math.max(0, math.floor(wave.nextAt - os.clock()))
			stateEvent:FireClient(player, {
				type = "tick", cash = state.cash, income = incomePerSecond(player),
				rebirths = state.rebirths, waveState = wave.state, waveIn = waveIn,
				stealReadyIn = math.max(0, math.floor(state.stealCooldownUntil - os.clock())),
			})
		end
	end
end)

-- Wave scheduler: calm -> warning (20s) -> wave sweep (30s) -> calm.
task.spawn(function()
	while true do
		task.wait(1)
		if wave.state == "calm" and os.clock() >= wave.nextAt then
			wave.state = "warning"
			wave.warnUntil = os.clock() + BrainrotData.WAVE_WARNING_SECONDS
			for _, player in ipairs(Players:GetPlayers()) do
				stateEvent:FireClient(player, { type = "waveWarning", seconds = BrainrotData.WAVE_WARNING_SECONDS })
			end
		elseif wave.state == "warning" and os.clock() >= wave.warnUntil then
			wave.state = "wave"
			wave.frontX = -110
			waveWall.Transparency = 0.35
			wave.waveUntil = os.clock() + BrainrotData.WAVE_DURATION_SECONDS
		elseif wave.state == "wave" then
			wave.frontX += 220 / BrainrotData.WAVE_DURATION_SECONDS
			waveWall.Position = Vector3.new(wave.frontX, 30, 0)
			for _, player in ipairs(Players:GetPlayers()) do
				if waveHitsPlayer(player, wave.frontX) and not player:GetAttribute("WaveHit") then
					player:SetAttribute("WaveHit", true)
					local state = players[player]
					if state then
						local lost = math.floor(state.cash * 0.10)
						state.cash -= lost
						local leaderstats = player:FindFirstChild("leaderstats")
						if leaderstats then
							leaderstats.Cash.Value = state.cash
						end
						stateEvent:FireClient(player, { type = "waveHit", lost = lost })
					end
					local character = player.Character
					if character then
						local root = character:FindFirstChild("HumanoidRootPart")
						if root then
							root.CFrame = CFrame.new(0, 5, 0) -- flung back to spawn
						end
					end
				end
			end
			if os.clock() >= wave.waveUntil then
				wave.state = "calm"
				wave.nextAt = os.clock() + BrainrotData.WAVE_EVERY_SECONDS
				waveWall.Transparency = 1
				for _, player in ipairs(Players:GetPlayers()) do
					player:SetAttribute("WaveHit", false)
				end
			end
		end
	end
end)

print("Brainrot Bay server ready: 8 plots, conveyor, earnings, stealing, wave, rebirth.")
