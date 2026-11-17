-- Brainrot Bay: client. Builds the whole HUD as a ScreenGui over the
-- 3D world and talks to the server only through the two RemoteEvents.
--
-- DESIGN NOTE: the HUD is deliberately an overlay, never the game
-- itself -- the game is the 3D island, conveyor and bases the camera
-- shows. The HUD answers four questions at a glance: how much cash do
-- I have, how fast is it growing, when is the next wave, and what can
-- I do next (buy the brainrot in front of me, rebirth, or run home).
-- A big centre banner carries wave warnings and steal/bought notices,
-- because those are the moments that change what the player should do
-- right now. The camera starts pulled back over the island so the
-- conveyor, the plaza and the nearest bases are all visible on join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local actionEvent = remotes:WaitForChild("Action")
local stateEvent = remotes:WaitForChild("State")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBayGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name, parent, pos, size, text, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	l.BackgroundTransparency = 0.25
	l.BorderSizePixel = 0
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.Font = Enum.Font.FredokaOne
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = l
	return l
end

-- Top bar: cash, income, rebirths.
local cashLabel = label("Cash", gui, UDim2.new(0.02, 0, 0.02, 0), UDim2.fromOffset(280, 54), "Cash: $100", 26, Color3.fromRGB(120, 255, 140))
local incomeLabel = label("Income", gui, UDim2.new(0.02, 0, 0.02, 66), UDim2.fromOffset(280, 40), "+$0 / sec", 20, Color3.fromRGB(255, 220, 100))
local rebirthLabel = label("Rebirths", gui, UDim2.new(0.02, 0, 0.02, 116), UDim2.fromOffset(280, 40), "Rebirths: 0 (x1)", 20, Color3.fromRGB(150, 220, 255))

-- Wave timer, top centre: the threat the player plans around.
local waveLabel = label("Wave", gui, UDim2.new(0.5, -180, 0.02, 0), UDim2.fromOffset(360, 54), "Next wave: --", 24, Color3.fromRGB(120, 200, 255))

-- Centre banner for warnings and notices.
local banner = label("Banner", gui, UDim2.new(0.5, -300, 0.3, 0), UDim2.fromOffset(600, 70), "", 28, Color3.fromRGB(255, 255, 255))
banner.Visible = false

-- Bottom bar: what to do next.
local helpLabel = label("Help", gui, UDim2.new(0.5, -320, 0.96, -44), UDim2.fromOffset(640, 36),
	"Walk to a coloured pad to claim a base  |  Hold E on the conveyor to buy  |  Hold E on a rival brainrot to steal it", 16)
helpLabel.BackgroundTransparency = 0.45

-- Rebirth button, bottom right.
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Position = UDim2.new(1, -220, 1, -90)
rebirthButton.Size = UDim2.fromOffset(200, 64)
rebirthButton.BackgroundColor3 = Color3.fromRGB(160, 60, 220)
rebirthButton.Text = "REBIRTH\n$50,000 + 1 Epic"
rebirthButton.TextSize = 20
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.Parent = gui
local rebirthCorner = Instance.new("UICorner")
rebirthCorner.CornerRadius = UDim.new(0, 12)
rebirthCorner.Parent = rebirthButton
rebirthButton.MouseButton1Click:Connect(function()
	actionEvent:FireServer("Rebirth")
end)

-- Steal cooldown readout, above the rebirth button.
local stealLabel = label("Steal", gui, UDim2.new(1, -220, 1, -140), UDim2.fromOffset(200, 36), "Steal: READY", 18, Color3.fromRGB(255, 150, 150))

local bannerTween = nil
local function showBanner(text, color, seconds)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	if bannerTween then
		bannerTween:Cancel()
	end
	banner.BackgroundTransparency = 0.25
	bannerTween = TweenService:Create(banner, TweenInfo.new(0.5), { BackgroundTransparency = 0.25 })
	task.delay(seconds or 4, function()
		banner.Visible = false
	end)
end

stateEvent.OnClientEvent:Connect(function(msg)
	if msg.type == "tick" then
		cashLabel.Text = "Cash: $" .. tostring(msg.cash)
		incomeLabel.Text = "+$" .. tostring(msg.income) .. " / sec"
		rebirthLabel.Text = "Rebirths: " .. tostring(msg.rebirths) .. " (x" .. tostring(2 ^ msg.rebirths) .. ")"
		if msg.waveState == "warning" then
			waveLabel.Text = "WAVE INCOMING: " .. tostring(msg.waveIn) .. "s -- RUN HOME!"
			waveLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		elseif msg.waveState == "wave" then
			waveLabel.Text = "WAVE SWEEPING THE ISLAND!"
			waveLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		else
			waveLabel.Text = "Next wave: " .. tostring(msg.waveIn) .. "s"
			waveLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
		end
		if msg.stealReadyIn > 0 then
			stealLabel.Text = "Steal ready in " .. tostring(msg.stealReadyIn) .. "s"
		else
			stealLabel.Text = "Steal: READY"
		end
	elseif msg.type == "waveWarning" then
		showBanner("THE WAVE IS COMING IN " .. tostring(msg.seconds) .. "s -- DASH TO YOUR BASE!", Color3.fromRGB(255, 90, 90), 6)
	elseif msg.type == "waveHit" then
		showBanner("The wave caught you! Lost $" .. tostring(msg.lost), Color3.fromRGB(255, 90, 90), 5)
	elseif msg.type == "bought" then
		showBanner("You bought " .. msg.name .. " (" .. msg.rarity .. ")!", Color3.fromRGB(120, 255, 140), 3)
	elseif msg.type == "stole" then
		showBanner("You stole " .. msg.name .. "! Run!", Color3.fromRGB(255, 220, 100), 4)
	elseif msg.type == "stolen" then
		showBanner(msg.by .. " stole your " .. msg.name .. "!", Color3.fromRGB(255, 90, 90), 4)
	elseif msg.type == "reborn" then
		showBanner("REBIRTH " .. tostring(msg.rebirths) .. "! All income x" .. tostring(2 ^ msg.rebirths) .. " forever.", Color3.fromRGB(200, 120, 255), 5)
	elseif msg.type == "claimed" then
		showBanner("Base claimed! Brainrots you buy will live here and earn for you.", Color3.fromRGB(120, 255, 140), 4)
	elseif msg.type == "denied" then
		showBanner(msg.reason, Color3.fromRGB(255, 150, 150), 3)
	end
end)

-- Pull the camera back on join so the island, conveyor and bases are
-- visible; the player can still orbit and zoom freely afterwards.
local camera = workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Custom
end

print("Brainrot Bay client ready.")
