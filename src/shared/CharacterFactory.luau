-- Brainrot Bay: builds the visible 3D body of a brainrot character.
--
-- DESIGN NOTE: every character is assembled from plain Roblox parts, so
-- the whole cast exists in the 3D world and Rojo can build it with no
-- meshes or assets that need Studio. A character is a chunky body block
-- on two stubby legs, a face made of two eye spheres and a smile decal
-- built from a thin part, a name/phrase BillboardGui floating above its
-- head, and one "quirk" accessory (crown, hat, cape, glasses, antenna)
-- that makes silhouettes readable from across the map at a glance.
-- Rarity is readable too: a neon trim part under the body glows in the
-- rarity colour, and a mutation tints the whole body. The model is
-- anchored and gently bobs with a sine wobble driven by the server.

local CharacterFactory = {}

local function part(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	return p
end

-- Builds a Model for one spawned brainrot. `spot` is the CFrame where
-- its feet stand; the caller owns the model afterwards.
function CharacterFactory.build(character, rarity, mutation, spot)
	local model = Instance.new("Model")
	model.Name = character.name .. " (" .. rarity.name .. ")"

	local bodyColor = mutation.name == "Normal" and character.color or mutation.color

	local body = part("Body", Vector3.new(2.2, 2.4, 1.6), bodyColor)
	body.CFrame = spot * CFrame.new(0, 1.9, 0)
	body.Parent = model

	local head = part("Head", Vector3.new(1.8, 1.5, 1.4), bodyColor)
	head.CFrame = spot * CFrame.new(0, 3.85, 0)
	head.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local leg = part("Leg", Vector3.new(0.6, 0.7, 0.7), Color3.fromRGB(60, 50, 45))
		leg.CFrame = spot * CFrame.new(0.55 * side, 0.35, 0)
		leg.Parent = model
		local eye = part("Eye", Vector3.new(0.35, 0.5, 0.2), Color3.fromRGB(20, 20, 20))
		eye.CFrame = spot * CFrame.new(0.4 * side, 4.0, 0.75)
		eye.Material = Enum.Material.Neon
		eye.Parent = model
		local arm = part("Arm", Vector3.new(0.5, 1.4, 0.5), bodyColor)
		arm.CFrame = spot * CFrame.new(1.35 * side, 1.9, 0)
		arm.Parent = model
	end

	local smile = part("Smile", Vector3.new(0.9, 0.15, 0.1), Color3.fromRGB(20, 20, 20))
	smile.CFrame = spot * CFrame.new(0, 3.45, 0.75)
	smile.Parent = model

	-- Rarity trim: a neon slab under the body, coloured per rarity.
	local trim = part("RarityTrim", Vector3.new(2.4, 0.25, 1.8), rarity.color)
	trim.Material = Enum.Material.Neon
	trim.CFrame = spot * CFrame.new(0, 0.75, 0)
	trim.Parent = model

	-- One quirk accessory per character, so silhouettes differ.
	if character.quirk == "Crown" then
		local crown = part("Crown", Vector3.new(1.6, 0.5, 1.6), Color3.fromRGB(255, 215, 0))
		crown.Material = Enum.Material.Metal
		crown.CFrame = spot * CFrame.new(0, 4.85, 0)
		crown.Parent = model
	elseif character.quirk == "Hat" then
		local hat = part("Hat", Vector3.new(2.0, 0.3, 2.0), Color3.fromRGB(180, 40, 60))
		hat.CFrame = spot * CFrame.new(0, 4.75, 0)
		hat.Parent = model
		local top = part("HatTop", Vector3.new(1.0, 0.8, 1.0), Color3.fromRGB(180, 40, 60))
		top.CFrame = spot * CFrame.new(0, 5.25, 0)
		top.Parent = model
	elseif character.quirk == "Cape" then
		local cape = part("Cape", Vector3.new(1.8, 2.0, 0.15), Color3.fromRGB(200, 30, 30))
		cape.CFrame = spot * CFrame.new(0, 2.0, -0.95)
		cape.Parent = model
	elseif character.quirk == "Glasses" then
		for _, side in ipairs({ -1, 1 }) do
			local lens = part("Lens", Vector3.new(0.6, 0.6, 0.1), Color3.fromRGB(30, 30, 40))
			lens.Material = Enum.Material.Glass
			lens.CFrame = spot * CFrame.new(0.4 * side, 4.05, 0.8)
			lens.Parent = model
		end
	elseif character.quirk == "Antenna" then
		local rod = part("Antenna", Vector3.new(0.15, 1.0, 0.15), Color3.fromRGB(80, 80, 80))
		rod.CFrame = spot * CFrame.new(0, 5.1, 0)
		rod.Parent = model
		local ball = part("AntennaBall", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 80, 80))
		ball.Material = Enum.Material.Neon
		ball.Shape = Enum.PartType.Ball
		ball.CFrame = spot * CFrame.new(0, 5.8, 0)
		ball.Parent = model
	end

	-- Floating name + catchphrase, readable from the conveyor.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffset = Vector3.new(0, 6.4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = character.name
	nameLabel.TextColor3 = rarity.color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = billboard

	local phraseLabel = Instance.new("TextLabel")
	phraseLabel.Name = "Phrase"
	phraseLabel.Position = UDim2.fromScale(0, 0.55)
	phraseLabel.Size = UDim2.fromScale(1, 0.45)
	phraseLabel.BackgroundTransparency = 1
	phraseLabel.Text = '"' .. character.phrase .. '"'
	phraseLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	phraseLabel.TextScaled = true
	phraseLabel.Font = Enum.Font.SourceSansItalic
	phraseLabel.TextStrokeTransparency = 0.4
	phraseLabel.Parent = billboard

	model.PrimaryPart = body
	return model
end

return CharacterFactory
