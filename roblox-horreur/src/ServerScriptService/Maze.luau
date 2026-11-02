-- Maze (ModuleScript dans ServerScriptService)
-- Génération de labyrinthe (backtracker récursif + boucles) et recherche de chemin (BFS).

local Maze = {}

export type Cell = { N: boolean, S: boolean, E: boolean, W: boolean, visited: boolean }
export type MazeData = { width: number, height: number, cells: { { Cell } } }

local DIRS = {
	{ dx = 0, dz = -1, wall = "N", opp = "S" },
	{ dx = 0, dz = 1, wall = "S", opp = "N" },
	{ dx = 1, dz = 0, wall = "E", opp = "W" },
	{ dx = -1, dz = 0, wall = "W", opp = "E" },
}

local function inBounds(maze: MazeData, x: number, z: number): boolean
	return x >= 1 and x <= maze.width and z >= 1 and z <= maze.height
end

function Maze.generate(width: number, height: number, braidRatio: number, rng: Random): MazeData
	local cells = {}
	for x = 1, width do
		cells[x] = {}
		for z = 1, height do
			cells[x][z] = { N = true, S = true, E = true, W = true, visited = false }
		end
	end
	local maze: MazeData = { width = width, height = height, cells = cells }

	-- Backtracker récursif (itératif avec une pile)
	local stack = { { 1, 1 } }
	cells[1][1].visited = true
	while #stack > 0 do
		local cur = stack[#stack]
		local cx, cz = cur[1], cur[2]
		local options = {}
		for _, d in DIRS do
			local nx, nz = cx + d.dx, cz + d.dz
			if inBounds(maze, nx, nz) and not cells[nx][nz].visited then
				table.insert(options, d)
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local d = options[rng:NextInteger(1, #options)]
			local nx, nz = cx + d.dx, cz + d.dz
			cells[cx][cz][d.wall] = false
			cells[nx][nz][d.opp] = false
			cells[nx][nz].visited = true
			table.insert(stack, { nx, nz })
		end
	end

	-- Supprime quelques murs en plus pour créer des boucles (sinon impossible de semer le monstre)
	for _ = 1, math.floor(width * height * braidRatio) do
		local x, z = rng:NextInteger(1, width), rng:NextInteger(1, height)
		local d = DIRS[rng:NextInteger(1, 4)]
		local nx, nz = x + d.dx, z + d.dz
		if inBounds(maze, nx, nz) then
			cells[x][z][d.wall] = false
			cells[nx][nz][d.opp] = false
		end
	end

	return maze
end

function Maze.openNeighbors(maze: MazeData, x: number, z: number): { { number } }
	local c = maze.cells[x][z]
	local res = {}
	if not c.N then table.insert(res, { x, z - 1 }) end
	if not c.S then table.insert(res, { x, z + 1 }) end
	if not c.E then table.insert(res, { x + 1, z }) end
	if not c.W then table.insert(res, { x - 1, z }) end
	return res
end

local function key(x: number, z: number): number
	return x * 10000 + z
end

-- Renvoie la liste des cases de (sx,sz) exclue à (tx,tz) incluse. {} si déjà dessus.
function Maze.findPath(maze: MazeData, sx: number, sz: number, tx: number, tz: number): { { number } }
	if sx == tx and sz == tz then
		return {}
	end
	local prev = { [key(sx, sz)] = false }
	local queue = { { sx, sz } }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		if cur[1] == tx and cur[2] == tz then
			local path = {}
			local node = cur
			while node and not (node[1] == sx and node[2] == sz) do
				table.insert(path, 1, node)
				node = prev[key(node[1], node[2])]
			end
			return path
		end
		for _, n in Maze.openNeighbors(maze, cur[1], cur[2]) do
			local k = key(n[1], n[2])
			if prev[k] == nil then
				prev[k] = cur
				table.insert(queue, n)
			end
		end
	end
	return {}
end

-- Distance (en cases) depuis (sx,sz) vers toutes les cases
function Maze.distances(maze: MazeData, sx: number, sz: number): { { number } }
	local dist = {}
	for x = 1, maze.width do
		dist[x] = {}
	end
	dist[sx][sz] = 0
	local queue = { { sx, sz } }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		for _, n in Maze.openNeighbors(maze, cur[1], cur[2]) do
			if dist[n[1]][n[2]] == nil then
				dist[n[1]][n[2]] = dist[cur[1]][cur[2]] + 1
				table.insert(queue, n)
			end
		end
	end
	return dist
end

function Maze.isDeadEnd(maze: MazeData, x: number, z: number): boolean
	return #Maze.openNeighbors(maze, x, z) == 1
end

return Maze
