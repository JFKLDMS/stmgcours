-- HorrorClient (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Lampe torche, course/endurance, effets de peur, screamers et interface.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage:WaitForChild("HorrorConfig"))
local remote = ReplicatedStorage:WaitForChild("HorrorEvent") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

----------------------------------------------------------------------
-- Sons (optionnels)
----------------------------------------------------------------------
local function makeSound(id: string?, looped: boolean, volume: number): Sound?
	if not id or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.Parent = SoundService
	return s
end

local sounds = {
	Ambient = makeSound(Config.SOUNDS.Ambient, true, 0.4),
	Heartbeat = makeSound(Config.SOUNDS.Heartbeat, true, 0),
	Scream = makeSound(Config.SOUNDS.Scream, false, 1),
	Sting = makeSound(Config.SOUNDS.Sting, false, 0.8),
	Whisper = makeSound(Config.SOUNDS.Whisper, false, 0.6),
	KeyPickup = makeSound(Config.SOUNDS.KeyPickup, false, 0.7),
	Flashlight = makeSound(Config.SOUNDS.Flashlight, false, 0.5),
}
if sounds.Ambient then sounds.Ambient:Play() end
if sounds.Heartbeat then sounds.Heartbeat:Play() end

local function play(name: string)
	local s = (sounds :: any)[name] :: Sound?
	if s then
		s.TimePosition = 0
		s:Play()
	end
end

----------------------------------------------------------------------
-- Interface
----------------------------------------------------------------------
local function create(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local gui = create("ScreenGui", {
	Name = "HorrorUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
}) :: ScreenGui

-- Vignette (4 dégradés noirs sur les bords)
local vignetteFrames = {}
for _, rot in { 0, 90, 180, 270 } do
	local f = create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 1, Parent = gui,
	})
	create("UIGradient", {
		Rotation = rot,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = f,
	})
	table.insert(vignetteFrames, f)
end

local redOverlay = create("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(140, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = gui,
}) :: Frame

local function label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Creepster,
		TextScaled = true, TextStrokeTransparency = 0.4, ZIndex = 5, Parent = gui,
	}
	for k, v in props do
		base[k] = v
	end
	return create("TextLabel", base) :: TextLabel
end

local statusLabel = label({ Size = UDim2.new(0.5, 0, 0, 36), Position = UDim2.new(0.25, 0, 0, 12) })
local keysLabel = label({
	Size = UDim2.new(0, 220, 0, 34), Position = UDim2.new(0, 16, 0, 12),
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 200, 60),
})
local messageLabel = label({
	Size = UDim2.new(0.8, 0, 0, 48), Position = UDim2.new(0.1, 0, 0.68, 0), TextTransparency = 1, TextStrokeTransparency = 1,
})
local whisperLabel = label({
	Size = UDim2.new(0, 320, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1,
	TextColor3 = Color3.fromRGB(170, 0, 0), Font = Enum.Font.Antique,
})
label({
	Size = UDim2.new(0, 360, 0, 22), Position = UDim2.new(1, -376, 1, -34), Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(150, 150, 150), TextXAlignment = Enum.TextXAlignment.Right,
	Text = "[F] Lampe   [Maj] Courir", TextStrokeTransparency = 1,
})

local function bar(name: string, y: number, color: Color3): Frame
	local holder = create("Frame", {
		Size = UDim2.new(0, 200, 0, 10), Position = UDim2.new(0, 16, 1, y),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5, Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = holder })
	label({
		Size = UDim2.new(0, 200, 0, 16), Position = UDim2.new(0, 16, 1, y - 18), Text = name, Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(180, 180, 180), TextStrokeTransparency = 1,
	})
	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6, Parent = holder,
	}) :: Frame
	create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = fill })
	return fill
end
local staminaFill = bar("Endurance", -60, Color3.fromRGB(220, 220, 220))
local batteryFill = bar("Pile", -24, Color3.fromRGB(255, 210, 80))

-- Effets de post-traitement locaux
local fearCC = create("ColorCorrectionEffect", { Name = "FearCC", Parent = Lighting }) :: ColorCorrectionEffect
local fearBlur = create("BlurEffect", { Name = "FearBlur", Size = 0, Parent = Lighting }) :: BlurEffect

----------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------
local messageToken = 0
local function showMessage(text: string, color: Color3?, duration: number?)
	messageToken += 1
	local token = messageToken
	messageLabel.Text = text
	messageLabel.TextColor3 = color or Color3.new(1, 1, 1)
	TweenService:Create(messageLabel, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	task.delay(duration or 3, function()
		if token == messageToken then
			TweenService:Create(messageLabel, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function inMaze(): boolean
	return player:GetAttribute("InMaze") == true
end

----------------------------------------------------------------------
-- Statut de la partie
----------------------------------------------------------------------
local function formatTime(t: number): string
	return string.format("%d:%02d", t // 60, t % 60)
end

local function updateStatus()
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local keys = ReplicatedStorage:GetAttribute("Keys") or 0
	local total = ReplicatedStorage:GetAttribute("KeysTotal") or Config.KEY_COUNT
	if phase == "Lobby" then
		statusLabel.Text = if t < 0 then "En attente de joueurs..." else "L'asile ouvre ses portes dans " .. t
		keysLabel.Text = ""
	elseif phase == "Playing" then
		statusLabel.Text = if inMaze() then formatTime(t) else "Manche en cours — " .. formatTime(t)
		keysLabel.Text = string.format("Clés : %d / %d", keys, total)
	else
		statusLabel.Text = "Fin de la manche"
	end
end
for _, attr in { "Phase", "TimeLeft", "Keys", "KeysTotal" } do
	ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(updateStatus)
end
player:GetAttributeChangedSignal("InMaze"):Connect(updateStatus)
updateStatus()

----------------------------------------------------------------------
-- Lampe torche
----------------------------------------------------------------------
local flashPart = create("Part", {
	Name = "Flashlight", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
	CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = camera,
}) :: Part
local spot = create("SpotLight", {
	Face = Enum.NormalId.Front, Range = 50, Angle = 55, Brightness = 4, Shadows = true,
	Color = Color3.fromRGB(255, 238, 205), Enabled = false, Parent = flashPart,
}) :: SpotLight
-- Petite lueur autour du joueur pour ne pas être dans le noir total
create("PointLight", { Range = 7, Brightness = 0.25, Color = Color3.fromRGB(150, 160, 200), Parent = flashPart })

local flashlightOn = false
local battery = Config.BATTERY_MAX
local stamina = Config.STAMINA_MAX
local exhausted = false
local sprintHeld = false

local function setFlashlight(on: boolean)
	if on and battery < 5 then
		showMessage("Plus de pile...", Color3.fromRGB(200, 200, 200), 1.5)
		on = false
	end
	if on == flashlightOn then
		return
	end
	flashlightOn = on
	spot.Enabled = on
	play("Flashlight")
	remote:FireServer("Flashlight", on)
end

ContextActionService:BindAction("HorrorFlashlight", function(_, state)
	if state == Enum.UserInputState.Begin then
		setFlashlight(not flashlightOn)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
ContextActionService:SetTitle("HorrorFlashlight", "Lampe")

ContextActionService:BindAction("HorrorSprint", function(_, state)
	sprintHeld = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("HorrorSprint", "Courir")

player.CharacterAdded:Connect(function()
	stamina = Config.STAMINA_MAX
	exhausted = false
end)

----------------------------------------------------------------------
-- Screamer
----------------------------------------------------------------------
local shakeBoost = 0

local function jumpscare()
	play("Scream")
	shakeBoost = 1.5
	setFlashlight(false)

	local frame = create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 50, Parent = gui,
	}) :: Frame
	local entity = workspace:FindFirstChild("TheEntity") :: Model?
	if entity then
		local vp = create("ViewportFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 51,
			Ambient = Color3.fromRGB(160, 50, 50), LightColor = Color3.fromRGB(255, 90, 90),
			LightDirection = Vector3.new(0, -0.5, 1), Parent = frame,
		}) :: ViewportFrame
		local clone = entity:Clone()
		clone:PivotTo(CFrame.new())
		clone.Parent = vp
		local vpCam = Instance.new("Camera")
		vpCam.FieldOfView = 70
		vpCam.Parent = vp
		vp.CurrentCamera = vpCam
		local head = clone:FindFirstChild("Head") :: BasePart?
		local face = if head then head.Position else Vector3.new(0, 5, 0)
		-- Le monstre regarde vers -Z : la caméra se place devant son visage
		vpCam.CFrame = CFrame.lookAt(face + Vector3.new(0, -0.4, -10), face)
		TweenService:Create(vpCam, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.lookAt(face + Vector3.new(0, -0.1, -2.3), face),
		}):Play()
		task.spawn(function()
			task.wait(0.2)
			local base = vpCam.CFrame
			local start = os.clock()
			while os.clock() - start < 1.8 and vp.Parent do
				local s = 0.12
				vpCam.CFrame = base * CFrame.new(math.random() * s - s / 2, math.random() * s - s / 2, 0)
					* CFrame.Angles(0, 0, (math.random() - 0.5) * 0.08)
				RunService.RenderStepped:Wait()
			end
		end)
	end
	local flash = create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 60, Parent = frame,
	}) :: Frame
	TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	local text = label({
		Size = UDim2.new(1, 0, 0.15, 0), Position = UDim2.fromScale(0, 0.78), Text = "IL T'A TROUVÉ",
		TextColor3 = Color3.fromRGB(220, 0, 0), ZIndex = 61, Parent = frame,
	})
	for _ = 1, 4 do
		task.wait(0.12)
		frame.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
		task.wait(0.08)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
	end
	task.wait(1.4)
	local fade = TweenInfo.new(1)
	TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(text, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	local vp = frame:FindFirstChildOfClass("ViewportFrame")
	if vp then
		TweenService:Create(vp, fade, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
	end
	task.wait(1)
	frame:Destroy()
end

-- Apparition fantôme : le monstre apparaît une fraction de seconde au bout du couloir
local function phantomScare()
	local entity = workspace:FindFirstChild("TheEntity") :: Model?
	local char = player.Character
	if not entity or not char then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, camera, entity }
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	flat = flat.Unit
	local hit = workspace:Raycast(origin, flat * 60, params)
	local dist = if hit then hit.Distance else 60
	if dist < 18 then
		return
	end
	local pos = origin + flat * (dist - 3)
	local ghost = entity:Clone()
	ghost:PivotTo(CFrame.lookAt(Vector3.new(pos.X, 4.5, pos.Z), Vector3.new(origin.X, 4.5, origin.Z)))
	ghost.Parent = camera
	play("Sting")
	task.wait(0.15 + math.random() * 0.15)
	ghost:Destroy()
end

local WHISPERS = {
	"...derrière toi...", "tu entends ?", "il arrive", "ne te retourne pas", "reste avec nous",
	"cours", "il sent ta lumière", "...", "on t'attendait",
}

task.spawn(function()
	while true do
		task.wait(math.random(20, 45))
		if inMaze() then
			if math.random() < 0.35 then
				phantomScare()
			else
				play("Whisper")
				whisperLabel.Text = WHISPERS[math.random(1, #WHISPERS)]
				whisperLabel.Position = UDim2.new(math.random(10, 70) / 100, 0, math.random(20, 75) / 100, 0)
				TweenService:Create(whisperLabel, TweenInfo.new(1.2), { TextTransparency = 0.2 }):Play()
				task.wait(2)
				TweenService:Create(whisperLabel, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
			end
		end
	end
end)

----------------------------------------------------------------------
-- Événements serveur
----------------------------------------------------------------------
remote.OnClientEvent:Connect(function(action, a, b, c)
	if action == "Message" then
		showMessage(a, b, c)
	elseif action == "Jumpscare" then
		task.spawn(jumpscare)
	elseif action == "Spotted" then
		play("Sting")
		shakeBoost = math.max(shakeBoost, 0.4)
		redOverlay.BackgroundTransparency = 0.6
		TweenService:Create(redOverlay, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	elseif action == "KeyPickup" then
		play("KeyPickup")
	end
end)

----------------------------------------------------------------------
-- Boucle par frame
----------------------------------------------------------------------
local fear = 0
local bobTime = 0

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local frozen = char ~= nil and char:GetAttribute("Frozen") == true
	local playing = inMaze()

	-- Course / endurance
	local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1
	local sprinting = sprintHeld and moving and not exhausted and not frozen
	if sprinting then
		stamina -= Config.STAMINA_DRAIN * dt
		if stamina <= 0 then
			stamina = 0
			exhausted = true
			showMessage("À bout de souffle...", Color3.fromRGB(200, 200, 200), 1.5)
		end
	else
		stamina = math.min(Config.STAMINA_MAX, stamina + Config.STAMINA_REGEN * dt)
		if exhausted and stamina >= Config.STAMINA_MAX * 0.35 then
			exhausted = false
		end
	end
	if hum then
		local speed = if frozen then 0 elseif sprinting then Config.SPRINT_SPEED else Config.WALK_SPEED
		if hum.WalkSpeed ~= speed then
			hum.WalkSpeed = speed
		end
	end
	staminaFill.Size = UDim2.fromScale(stamina / Config.STAMINA_MAX, 1)
	staminaFill.BackgroundColor3 = if exhausted then Color3.fromRGB(180, 60, 60) else Color3.fromRGB(220, 220, 220)

	-- Pile
	if flashlightOn and playing then
		battery -= Config.BATTERY_DRAIN * dt
		if battery <= 0 then
			battery = 0
			setFlashlight(false)
			showMessage("Ta lampe s'est éteinte...", Color3.fromRGB(200, 200, 200), 2)
		end
	elseif not flashlightOn then
		battery = math.min(Config.BATTERY_MAX, battery + Config.BATTERY_REGEN * dt)
	end
	batteryFill.Size = UDim2.fromScale(battery / Config.BATTERY_MAX, 1)

	-- Peur : selon la distance au monstre
	local target = 0
	local entity = workspace:FindFirstChild("TheEntity") :: Model?
	if entity and playing and root then
		local d = (entity:GetPivot().Position - root.Position).Magnitude
		target = math.clamp(1 - (d - 10) / 55, 0, 1)
	end
	fear += (target - fear) * math.min(1, dt * 3)

	-- La lampe grésille quand il est proche
	if flashlightOn then
		local flicker = fear > 0.45 and math.random() < fear * 0.3
		spot.Enabled = not flicker
		spot.Brightness = 4 - (if flicker then 0 else math.random() * fear * 2)
	end

	-- Effets visuels
	local t = os.clock()
	local pulse = (math.sin(t * (4 + fear * 8)) + 1) / 2
	fearCC.Saturation = -fear * 0.6
	fearCC.Contrast = fear * 0.2
	fearCC.TintColor = Color3.new(1, 1 - fear * 0.35, 1 - fear * 0.35)
	fearBlur.Size = fear * 5
	if redOverlay.BackgroundTransparency > 0.95 or fear > 0.3 then
		redOverlay.BackgroundTransparency = 1 - fear * 0.18 * pulse
	end
	for _, f in vignetteFrames do
		f.BackgroundTransparency = 0.35 - fear * 0.3
	end
	if sounds.Heartbeat then
		sounds.Heartbeat.Volume = fear * 1.2
		sounds.Heartbeat.PlaybackSpeed = 0.9 + fear * 0.6
	end

	-- Balancement de la tête en marchant
	if hum then
		if moving and not frozen then
			bobTime += dt * (if sprinting then 14 else 9)
			local amp = if sprinting then 1.6 else 1
			hum.CameraOffset = Vector3.new(math.cos(bobTime) * 0.08 * amp, math.abs(math.sin(bobTime)) * 0.14 * amp, 0)
		else
			hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.zero, math.min(1, dt * 6))
		end
	end
end)

-- Après la caméra : tremblement + position de la lampe
RunService:BindToRenderStep("HorrorCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	shakeBoost = math.max(0, shakeBoost - dt * 1.5)
	local s = fear * fear * 0.01 + shakeBoost * 0.03
	if s > 0.0005 then
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end
	local goal = camera.CFrame * CFrame.new(0.6, -0.5, -0.5)
	flashPart.CFrame = flashPart.CFrame:Lerp(goal, math.min(1, dt * 18))
end)
