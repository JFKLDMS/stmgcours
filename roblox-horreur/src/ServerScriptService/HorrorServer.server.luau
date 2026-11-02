-- HorrorServer (Script dans ServerScriptService)
-- Génère l'asile, gère les manches, les clés, la sortie et l'IA du monstre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("HorrorConfig"))
local Maze = require(script.Parent:WaitForChild("Maze"))

local S = Config.CELL_SIZE
local H = Config.WALL_HEIGHT
local W_CELLS = Config.MAZE_WIDTH
local H_CELLS = Config.MAZE_HEIGHT
local ORIGIN = Vector3.new(0, 0, 0)
local LOBBY_POS = Vector3.new(0, 150, 0)
local MONSTER_Y = 4.5

local RED = Color3.fromRGB(200, 30, 30)
local GOLD = Color3.fromRGB(255, 200, 60)
local GREEN = Color3.fromRGB(80, 220, 110)

local WALL_TEXTS = {
	"IL TE VOIT", "NE COURS PAS", "SORS D'ICI", "TROP TARD", "IL EST DERRIÈRE TOI",
	"5 CLÉS", "PAS DE SORTIE", "AIDE-MOI", "ÉTEINS TA LAMPE", "ON NE SORT JAMAIS",
}

----------------------------------------------------------------------
-- Remote + état partagé (attributs répliqués aux clients)
----------------------------------------------------------------------
local remote = Instance.new("RemoteEvent")
remote.Name = "HorrorEvent"
remote.Parent = ReplicatedStorage

local function setState(name: string, value: any)
	ReplicatedStorage:SetAttribute(name, value)
end

local function broadcast(text: string, color: Color3?, duration: number?)
	remote:FireAllClients("Message", text, color or Color3.new(1, 1, 1), duration or 3)
end

local function tell(player: Player, text: string, color: Color3?, duration: number?)
	remote:FireClient(player, "Message", text, color or Color3.new(1, 1, 1), duration or 3)
end

----------------------------------------------------------------------
-- Ambiance
----------------------------------------------------------------------
local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 8, 12)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.FogStart = 0
	Lighting.FogEnd = 90
	Lighting.FogColor = Color3.new(0, 0, 0)

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.35
	cc.Contrast = 0.15
	cc.TintColor = Color3.fromRGB(225, 230, 255)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
end

----------------------------------------------------------------------
-- Helpers de construction
----------------------------------------------------------------------
local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function addSurfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, rotation: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.8, 0.35)
	label.Position = UDim2.fromScale(0.1, 0.3)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Creepster
	label.TextColor3 = color
	label.Rotation = rotation or 0
	label.Parent = gui
end

local function cellCenter(x: number, z: number): Vector3
	return ORIGIN + Vector3.new((x - 0.5) * S, 0, (z - 0.5) * S)
end

local function worldToCell(pos: Vector3): (number, number)
	local x = math.clamp(math.floor((pos.X - ORIGIN.X) / S) + 1, 1, W_CELLS)
	local z = math.clamp(math.floor((pos.Z - ORIGIN.Z) / S) + 1, 1, H_CELLS)
	return x, z
end

----------------------------------------------------------------------
-- Lobby
----------------------------------------------------------------------
local lobbySpawn: SpawnLocation

local function buildLobby()
	-- Supprime le Baseplate et les spawns du template par défaut
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	local size = 40
	local wallColor = Color3.fromRGB(45, 40, 40)
	makePart({ Name = "Floor", Size = Vector3.new(size, 1, size), Position = LOBBY_POS - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(60, 45, 35), Parent = folder })
	makePart({ Name = "Ceiling", Size = Vector3.new(size, 1, size), Position = LOBBY_POS + Vector3.new(0, 14.5, 0),
		Color = Color3.fromRGB(20, 20, 20), Parent = folder })
	for i, offset in { Vector3.new(size / 2, 7, 0), Vector3.new(-size / 2, 7, 0), Vector3.new(0, 7, size / 2), Vector3.new(0, 7, -size / 2) } do
		local wall = makePart({
			Name = "Wall" .. i,
			Size = if offset.X ~= 0 then Vector3.new(1, 14, size) else Vector3.new(size, 14, 1),
			Position = LOBBY_POS + offset,
			Material = Enum.Material.Brick,
			Color = wallColor,
			Parent = folder,
		})
		if i == 4 then
			-- Mur nord : panneau titre (face Back = +Z, vers l'intérieur)
			addSurfaceText(wall, Enum.NormalId.Back, "L'ASILE DES OMBRES", RED)
		end
	end

	local lamp = makePart({ Name = "Lamp", Size = Vector3.new(3, 0.4, 3), Position = LOBBY_POS + Vector3.new(0, 13.8, 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 120), CanCollide = false, Parent = folder })
	local light = Instance.new("PointLight")
	light.Range = 35
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 180, 110)
	light.Shadows = true
	light.Parent = lamp

	lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Anchored = true
	lobbySpawn.Size = Vector3.new(8, 1, 8)
	lobbySpawn.Position = LOBBY_POS + Vector3.new(0, 0.05, 0)
	lobbySpawn.Material = Enum.Material.Slate
	lobbySpawn.Color = Color3.fromRGB(30, 30, 30)
	lobbySpawn.Duration = 0
	lobbySpawn.Neutral = true
	lobbySpawn.Parent = folder
end

local function sendToLobby(player: Player)
	local char = player.Character
	if not char then
		return
	end
	char:SetAttribute("Frozen", nil)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
	end
	local offset = Vector3.new(math.random(-12, 12), 4, math.random(-12, 12))
	char:PivotTo(CFrame.new(LOBBY_POS + offset))
end

----------------------------------------------------------------------
-- Construction du labyrinthe
----------------------------------------------------------------------
type Lamp = { part: BasePart, light: PointLight }

local function buildMap(maze: Maze.MazeData, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Asylum"

	local totalX, totalZ = W_CELLS * S, H_CELLS * S
	local mid = ORIGIN + Vector3.new(totalX / 2, 0, totalZ / 2)

	makePart({ Name = "Floor", Size = Vector3.new(totalX + 2, 1, totalZ + 2), Position = mid - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(45, 32, 25), Parent = folder })
	makePart({ Name = "Ceiling", Size = Vector3.new(totalX + 2, 1, totalZ + 2), Position = mid + Vector3.new(0, H + 0.5, 0),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(25, 25, 25), Parent = folder })

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder

	local function wall(pos: Vector3, size: Vector3, faces: { Enum.NormalId })
		local p = makePart({
			Size = size,
			Position = pos,
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(70 + rng:NextInteger(-8, 8), 66, 60),
			Parent = walls,
		})
		if rng:NextNumber() < 0.07 then
			local text = WALL_TEXTS[rng:NextInteger(1, #WALL_TEXTS)]
			addSurfaceText(p, faces[rng:NextInteger(1, #faces)], text, Color3.fromRGB(120, 0, 0), rng:NextInteger(-8, 8))
		end
		return p
	end

	local exitX, exitZ = W_CELLS, H_CELLS
	for x = 1, W_CELLS do
		for z = 1, H_CELLS do
			local c = maze.cells[x][z]
			local center = cellCenter(x, z)
			local y = H / 2
			if c.N then
				wall(center + Vector3.new(0, y, -S / 2), Vector3.new(S + 1, H, 1), { Enum.NormalId.Front, Enum.NormalId.Back })
			end
			if c.W then
				wall(center + Vector3.new(-S / 2, y, 0), Vector3.new(1, H, S + 1), { Enum.NormalId.Left, Enum.NormalId.Right })
			end
			if x == W_CELLS and c.E then
				wall(center + Vector3.new(S / 2, y, 0), Vector3.new(1, H, S + 1), { Enum.NormalId.Left })
			end
			if z == H_CELLS and c.S and not (x == exitX and z == exitZ) then
				wall(center + Vector3.new(0, y, S / 2), Vector3.new(S + 1, H, 1), { Enum.NormalId.Front })
			end
		end
	end

	-- Porte de sortie (mur sud de la dernière case)
	local exitCenter = cellCenter(exitX, exitZ) + Vector3.new(0, 0, S / 2)
	local doorW, doorH = 7, 10
	local side = (S + 1 - doorW) / 2
	for _, sign in { -1, 1 } do
		makePart({ Size = Vector3.new(side, H, 1), Position = exitCenter + Vector3.new(sign * (doorW / 2 + side / 2), H / 2, 0),
			Material = Enum.Material.Concrete, Color = Color3.fromRGB(60, 56, 52), Parent = folder })
	end
	local header = makePart({ Size = Vector3.new(doorW, H - doorH, 1), Position = exitCenter + Vector3.new(0, doorH + (H - doorH) / 2, 0),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(60, 56, 52), Parent = folder })
	addSurfaceText(header, Enum.NormalId.Front, "SORTIE", RED)
	local door = makePart({ Name = "ExitDoor", Size = Vector3.new(doorW, doorH, 1), Position = exitCenter + Vector3.new(0, doorH / 2, 0),
		Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(90, 20, 20), Parent = folder })
	local doorLight = Instance.new("PointLight")
	doorLight.Color = RED
	doorLight.Range = 14
	doorLight.Brightness = 1.5
	doorLight.Parent = header

	-- Lampes au plafond + taches de sang
	local lamps: { Lamp } = {}
	for x = 1, W_CELLS do
		for z = 1, H_CELLS do
			local center = cellCenter(x, z)
			if rng:NextNumber() < Config.LAMP_RATIO then
				local lampPart = makePart({ Name = "Lamp", Size = Vector3.new(2, 0.3, 2), Position = center + Vector3.new(0, H - 0.15, 0),
					Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 140), CanCollide = false, Parent = folder })
				local light = Instance.new("PointLight")
				light.Range = 18
				light.Brightness = 1.1
				light.Color = Color3.fromRGB(255, 190, 130)
				light.Shadows = true
				light.Parent = lampPart
				if rng:NextNumber() < 0.25 then
					-- lampe morte
					light.Enabled = false
					lampPart.Material = Enum.Material.SmoothPlastic
					lampPart.Color = Color3.fromRGB(40, 40, 40)
				else
					table.insert(lamps, { part = lampPart, light = light })
				end
			end
			if rng:NextNumber() < 0.2 then
				local d = rng:NextNumber(2, 5)
				makePart({ Name = "Blood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, d, d),
					CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-4, 4), 0.03, rng:NextNumber(-4, 4))) * CFrame.Angles(0, 0, math.pi / 2),
					Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(70, 0, 0), CanCollide = false, CanQuery = false, Parent = folder })
			end
		end
	end

	return folder, door, doorLight, lamps
end

----------------------------------------------------------------------
-- Monstre
----------------------------------------------------------------------
local function buildMonster(): Model
	local model = Instance.new("Model")
	model.Name = "TheEntity"
	local black = Color3.fromRGB(8, 8, 10)

	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?)
		local p = makePart({
			Name = name, Size = size, CFrame = CFrame.new(offset), Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false, CanTouch = false, CanQuery = false, Parent = model,
		})
		return p
	end

	local root = part("Root", Vector3.new(2, 2, 1), Vector3.zero, black)
	root.Transparency = 1
	model.PrimaryPart = root
	part("Torso", Vector3.new(2.2, 4.5, 1.1), Vector3.new(0, 1.5, 0), black, Enum.Material.Fabric)
	local head = part("Head", Vector3.new(1.8, 2.2, 1.8), Vector3.new(0, 4.9, 0), black)
	part("EyeL", Vector3.new(0.4, 0.22, 0.1), Vector3.new(-0.42, 5.15, -0.92), Color3.fromRGB(255, 0, 0), Enum.Material.Neon)
	part("EyeR", Vector3.new(0.4, 0.22, 0.1), Vector3.new(0.42, 5.15, -0.92), Color3.fromRGB(255, 0, 0), Enum.Material.Neon)
	part("Mouth", Vector3.new(1.1, 0.5, 0.1), Vector3.new(0, 4.3, -0.92), Color3.fromRGB(40, 0, 0), Enum.Material.Neon)
	part("ArmL", Vector3.new(0.45, 7, 0.45), Vector3.new(-1.4, 0.3, 0), black)
	part("ArmR", Vector3.new(0.45, 7, 0.45), Vector3.new(1.4, 0.3, 0), black)
	part("LegL", Vector3.new(0.7, 4, 0.7), Vector3.new(-0.6, -2.5, 0), black)
	part("LegR", Vector3.new(0.7, 4, 0.7), Vector3.new(0.6, -2.5, 0), black)

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 20, 20)
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = head

	return model
end

----------------------------------------------------------------------
-- Manche
----------------------------------------------------------------------
local alive: { [Player]: boolean } = {} -- joueurs encore dans l'asile
local escaped: { Player } = {}
local flashlightOn: { [Player]: boolean } = {}
local roundId = 0
local keysCollected = 0
local currentMaze: Maze.MazeData? = nil

type MonsterState = {
	model: Model,
	pos: Vector3,
	facing: Vector3,
	path: { { number } },
	mode: string, -- "wander" | "chase" | "search"
	target: Player?,
	lastKnown: { number }?,
	thinkTimer: number,
	pauseUntil: number,
}
local monster: MonsterState? = nil

local function getRoot(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inMazeCount(): number
	local n = 0
	for _ in alive do
		n += 1
	end
	return n
end

local function removeFromMaze(player: Player)
	alive[player] = nil
	player:SetAttribute("InMaze", false)
end

local function killPlayer(player: Player)
	if not alive[player] then
		return
	end
	removeFromMaze(player)
	local char = player.Character
	if char then
		char:SetAttribute("Frozen", true)
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = true
		end
	end
	remote:FireClient(player, "Jumpscare")
	broadcast(player.DisplayName .. " a été attrapé...", RED, 3)
	task.delay(2.6, function()
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Parent then
			hum.Health = 0
		end
	end)
end

local function monsterSpeed(state: MonsterState): number
	if state.mode == "chase" then
		return Config.MONSTER_CHASE_SPEED + keysCollected * Config.MONSTER_ENRAGE_PER_KEY
	elseif state.mode == "search" then
		return (Config.MONSTER_CHASE_SPEED + Config.MONSTER_WANDER_SPEED) / 2
	end
	return Config.MONSTER_WANDER_SPEED
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(state: MonsterState, player: Player, root: BasePart): boolean
	local eye = state.pos + Vector3.new(0, 3, 0)
	local target = root.Position + Vector3.new(0, 1.5, 0)
	rayParams.FilterDescendantsInstances = { state.model }
	local result = workspace:Raycast(eye, target - eye, rayParams)
	return result == nil or (player.Character ~= nil and result.Instance:IsDescendantOf(player.Character))
end

local function think(state: MonsterState, maze: Maze.MazeData)
	local mx, mz = worldToCell(state.pos)
	local best: Player? = nil
	local bestDist = math.huge
	for player in alive do
		local root = getRoot(player)
		if root then
			local d = (root.Position - state.pos).Magnitude
			local vel = root.AssemblyLinearVelocity
			local running = Vector3.new(vel.X, 0, vel.Z).Magnitude > Config.WALK_SPEED + 2
			local sight = if flashlightOn[player] then Config.MONSTER_SIGHT_RANGE_LIGHT else Config.MONSTER_SIGHT_RANGE
			local detected = d < Config.MONSTER_SENSE_RANGE
				or (d < sight and canSee(state, player, root))
				or (d < Config.MONSTER_HEAR_RANGE and running)
			if detected and d < bestDist then
				best, bestDist = player, d
			end
		end
	end

	if best then
		local root = getRoot(best) :: BasePart
		if state.mode ~= "chase" or state.target ~= best then
			remote:FireClient(best, "Spotted")
		end
		state.mode = "chase"
		state.target = best
		local px, pz = worldToCell(root.Position)
		state.lastKnown = { px, pz }
		state.path = Maze.findPath(maze, mx, mz, px, pz)
	elseif state.mode == "chase" and state.lastKnown then
		-- Cible perdue : va voir le dernier endroit connu
		state.mode = "search"
		state.target = nil
		state.path = Maze.findPath(maze, mx, mz, state.lastKnown[1], state.lastKnown[2])
	elseif #state.path == 0 then
		state.mode = "wander"
		state.target = nil
		local tx, tz = math.random(1, W_CELLS), math.random(1, H_CELLS)
		-- Instinct de chasseur : se dirige parfois vers un joueur au hasard
		if math.random() < 0.4 then
			local list = {}
			for p in alive do
				table.insert(list, p)
			end
			local root = #list > 0 and getRoot(list[math.random(1, #list)])
			if root then
				tx, tz = worldToCell(root.Position)
			end
		end
		state.path = Maze.findPath(maze, mx, mz, tx, tz)
	end
end

local function updateMonster(state: MonsterState, maze: Maze.MazeData, dt: number)
	if os.clock() < state.pauseUntil then
		return
	end

	state.thinkTimer -= dt
	if state.thinkTimer <= 0 then
		state.thinkTimer = 0.25
		think(state, maze)
	end

	-- Déplacement
	local targetPos: Vector3? = nil
	local direct = false
	if state.mode == "chase" and state.target then
		local root = getRoot(state.target)
		if root then
			local px, pz = worldToCell(root.Position)
			local mx, mz = worldToCell(state.pos)
			if px == mx and pz == mz then
				targetPos = Vector3.new(root.Position.X, MONSTER_Y, root.Position.Z)
				direct = true
			end
		end
	end
	if not targetPos and #state.path > 0 then
		local c = state.path[1]
		targetPos = cellCenter(c[1], c[2]) + Vector3.new(0, MONSTER_Y, 0)
	end

	if targetPos then
		local delta = targetPos - state.pos
		delta = Vector3.new(delta.X, 0, delta.Z)
		local dist = delta.Magnitude
		if dist < 0.3 then
			if not direct then
				table.remove(state.path, 1)
			end
		else
			local dir = delta.Unit
			state.pos += dir * math.min(dist, monsterSpeed(state) * dt)
			local f = state.facing:Lerp(dir, math.min(1, dt * 8))
			state.facing = if f.Magnitude > 0.05 then f.Unit else dir
		end
	end

	local t = os.clock()
	local bob = math.sin(t * 9) * 0.15
	local sway = math.sin(t * 4.5) * 0.06
	state.model:PivotTo(CFrame.lookAt(state.pos, state.pos + state.facing) * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, sway))

	-- Attaque
	for player in alive do
		local root = getRoot(player)
		if root then
			local d = root.Position - state.pos
			if Vector3.new(d.X, 0, d.Z).Magnitude < Config.MONSTER_KILL_RANGE and math.abs(d.Y) < 7 then
				state.facing = Vector3.new(d.X, 0, d.Z).Unit
				killPlayer(player)
				state.pauseUntil = os.clock() + 3
				state.path = {}
				state.mode = "wander"
				state.target = nil
				state.lastKnown = nil
				break
			end
		end
	end
end

local function flickerLamp(lamp: Lamp)
	for _ = 1, math.random(3, 8) do
		lamp.light.Enabled = false
		lamp.part.Material = Enum.Material.SmoothPlastic
		task.wait(math.random() * 0.12 + 0.03)
		lamp.light.Enabled = true
		lamp.part.Material = Enum.Material.Neon
		task.wait(math.random() * 0.15 + 0.03)
	end
end

local function runRound()
	roundId += 1
	local myRound = roundId
	local rng = Random.new()

	local maze = Maze.generate(W_CELLS, H_CELLS, Config.BRAID_RATIO, rng)
	currentMaze = maze
	local map, door, doorLight, lamps = buildMap(maze, rng)
	map.Parent = workspace

	keysCollected = 0
	escaped = {}
	table.clear(alive)
	setState("Keys", 0)
	setState("KeysTotal", Config.KEY_COUNT)

	-- Placement des clés : de préférence dans des culs-de-sac loin du départ
	local dist = Maze.distances(maze, 1, 1)
	local deadEnds, others = {}, {}
	for x = 1, W_CELLS do
		for z = 1, H_CELLS do
			local d = dist[x][z]
			if d and d >= 5 and not (x == W_CELLS and z == H_CELLS) then
				table.insert(if Maze.isDeadEnd(maze, x, z) then deadEnds else others, { x, z })
			end
		end
	end
	local function shuffle(t)
		for i = #t, 2, -1 do
			local j = rng:NextInteger(1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	shuffle(deadEnds)
	shuffle(others)
	local keyCells = {}
	for _, list in { deadEnds, others } do
		for _, c in list do
			if #keyCells >= Config.KEY_COUNT then
				break
			end
			table.insert(keyCells, c)
		end
	end

	local function onAllKeys()
		doorLight.Color = GREEN
		door.Color = Color3.fromRGB(30, 80, 40)
		broadcast("Toutes les clés ! La SORTIE est ouverte... et IL est furieux.", GREEN, 4)
	end

	for _, c in keyCells do
		local key = makePart({
			Name = "Key", Size = Vector3.new(1.4, 0.35, 0.7),
			CFrame = CFrame.new(cellCenter(c[1], c[2]) + Vector3.new(0, 3, 0)),
			Material = Enum.Material.Neon, Color = GOLD, CanCollide = false, Parent = map,
		})
		local glow = Instance.new("PointLight")
		glow.Color = GOLD
		glow.Range = 9
		glow.Brightness = 1.2
		glow.Parent = key
		TweenService:Create(key, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ CFrame = key.CFrame * CFrame.Angles(0, math.pi, 0) }):Play()

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ramasser"
		prompt.ObjectText = "Clé rouillée"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = key
		prompt.Triggered:Connect(function(player)
			if myRound ~= roundId or not alive[player] or not key.Parent then
				return
			end
			key:Destroy()
			keysCollected += 1
			setState("Keys", keysCollected)
			remote:FireClient(player, "KeyPickup")
			broadcast(string.format("%s a trouvé une clé (%d/%d)", player.DisplayName, keysCollected, Config.KEY_COUNT), GOLD, 3)
			if keysCollected >= Config.KEY_COUNT then
				onAllKeys()
			end
		end)
	end

	-- Porte de sortie
	local doorPrompt = Instance.new("ProximityPrompt")
	doorPrompt.ActionText = "S'échapper"
	doorPrompt.ObjectText = "Porte de sortie"
	doorPrompt.HoldDuration = 1.5
	doorPrompt.MaxActivationDistance = 8
	doorPrompt.RequiresLineOfSight = false
	doorPrompt.Parent = door
	doorPrompt.Triggered:Connect(function(player)
		if myRound ~= roundId or not alive[player] then
			return
		end
		if keysCollected < Config.KEY_COUNT then
			tell(player, string.format("Verrouillée... (%d/%d clés)", keysCollected, Config.KEY_COUNT), RED, 2.5)
			return
		end
		removeFromMaze(player)
		table.insert(escaped, player)
		sendToLobby(player)
		broadcast(player.DisplayName .. " s'est échappé !", GREEN, 3)
	end)

	-- Téléporte les joueurs dans l'asile
	local connections: { RBXScriptConnection } = {}
	local spawnPos = cellCenter(1, 1)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and hum and hum.Health > 0 then
			alive[player] = true
			player:SetAttribute("InMaze", true)
			char:PivotTo(CFrame.new(spawnPos + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3))) * CFrame.Angles(0, math.pi, 0))
			table.insert(connections, hum.Died:Connect(function()
				if alive[player] then
					removeFromMaze(player)
				end
			end))
		end
	end

	setState("Phase", "Playing")
	broadcast(string.format("Trouve les %d clés et échappe-toi... Ne fais pas de bruit.", Config.KEY_COUNT), Color3.new(1, 1, 1), 5)

	-- Le monstre apparaît dans la case la plus éloignée du départ
	local far, farDist = { W_CELLS, H_CELLS }, -1
	for x = 1, W_CELLS do
		for z = 1, H_CELLS do
			if dist[x][z] and dist[x][z] > farDist then
				far, farDist = { x, z }, dist[x][z]
			end
		end
	end
	local model = buildMonster()
	local state: MonsterState = {
		model = model,
		pos = cellCenter(far[1], far[2]) + Vector3.new(0, MONSTER_Y, 0),
		facing = Vector3.new(0, 0, -1),
		path = {},
		mode = "wander",
		target = nil,
		lastKnown = nil,
		thinkTimer = 0,
		pauseUntil = os.clock() + Config.MONSTER_GRACE,
	}
	model:PivotTo(CFrame.new(state.pos))
	model.Parent = workspace
	monster = state
	task.delay(Config.MONSTER_GRACE, function()
		if myRound == roundId then
			broadcast("Quelque chose s'est réveillé...", RED, 4)
		end
	end)
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		updateMonster(state, maze, dt)
	end))

	-- Lampes qui clignotent (beaucoup plus quand le monstre est proche)
	task.spawn(function()
		while myRound == roundId and map.Parent do
			for _, lamp in lamps do
				local near = (lamp.part.Position - state.pos).Magnitude < 28
				if math.random() < (if near then 0.35 else 0.015) then
					task.spawn(flickerLamp, lamp)
				end
			end
			task.wait(0.3)
		end
	end)

	-- Boucle de la manche
	local timeLeft = Config.ROUND_TIME
	while timeLeft > 0 and inMazeCount() > 0 do
		setState("TimeLeft", timeLeft)
		task.wait(1)
		timeLeft -= 1
	end

	-- Temps écoulé : les lumières s'éteignent et il prend tout le monde
	if inMazeCount() > 0 then
		for _, lamp in lamps do
			lamp.light.Enabled = false
			lamp.part.Material = Enum.Material.SmoothPlastic
		end
		broadcast("Le temps est écoulé... les lumières s'éteignent.", RED, 3)
		task.wait(2)
		for player in table.clone(alive) do
			killPlayer(player)
		end
	end

	setState("Phase", "Ended")
	if #escaped > 0 then
		local names = {}
		for _, p in escaped do
			table.insert(names, p.DisplayName)
		end
		broadcast("Survivants : " .. table.concat(names, ", "), GREEN, 5)
	else
		broadcast("Personne n'est sorti de l'asile...", RED, 5)
	end

	task.wait(3)
	roundId += 1 -- invalide les prompts et la boucle des lampes
	for _, c in connections do
		c:Disconnect()
	end
	monster = nil
	currentMaze = nil
	model:Destroy()
	map:Destroy()
	for player in table.clone(alive) do
		removeFromMaze(player)
		sendToLobby(player)
	end
end

----------------------------------------------------------------------
-- Joueurs
----------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player:SetAttribute("InMaze", false)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	alive[player] = nil
	flashlightOn[player] = nil
end)

-- Le client indique si sa lampe est allumée (la lumière attire le monstre)
remote.OnServerEvent:Connect(function(player, action, value)
	if action == "Flashlight" and typeof(value) == "boolean" then
		flashlightOn[player] = value
	end
end)

----------------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------------
Players.RespawnTime = 4
setupLighting()
buildLobby()
setState("Phase", "Lobby")
setState("Keys", 0)
setState("KeysTotal", Config.KEY_COUNT)

while true do
	setState("Phase", "Lobby")
	while #Players:GetPlayers() < Config.MIN_PLAYERS do
		setState("TimeLeft", -1)
		task.wait(1)
	end
	for t = Config.INTERMISSION, 1, -1 do
		setState("TimeLeft", t)
		task.wait(1)
	end
	local ok, err = pcall(runRound)
	if not ok then
		warn("[Horreur] Erreur pendant la manche :", err)
		roundId += 1
		monster = nil
		local leftover = workspace:FindFirstChild("Asylum")
		if leftover then leftover:Destroy() end
		local entity = workspace:FindFirstChild("TheEntity")
		if entity then entity:Destroy() end
		for player in table.clone(alive) do
			removeFromMaze(player)
			sendToLobby(player)
		end
	end
end
