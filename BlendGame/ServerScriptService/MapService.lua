-- MapService: ModuleScript in ServerScriptService
-- Loads and unloads maps. Supports maps pre-built in ServerStorage (cloned in)
-- or maps already placed in Workspace/Maps by MapBuilder (used in place).

local ServerStorage = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")

local MapService = {}

-- ── State ──────────────────────────────────────────────────────────────────
local currentMapModel: Instance? = nil
local currentMapId:    string?   = nil
local wasCloned        = false

local hiderSpawns:  { CFrame } = {}
local seekerSpawns: { CFrame } = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function collectSpawns(folder: Instance?, dest: { CFrame })
	table.clear(dest)
	if not folder then return end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(dest, child.CFrame)
		end
	end
end

-- ── Public API ─────────────────────────────────────────────────────────────

--[[
	loadMap(mapId) → boolean
	Search order:
	  1. ServerStorage/Maps/<mapId>  — clone into Workspace
	  2. Workspace/Maps/<mapId>      — use in place (MapBuilder output)
	Returns true on success.
]]
function MapService.loadMap(mapId: string): boolean
	MapService.unloadMap()

	local mapModel: Instance? = nil

	-- 1. Check ServerStorage
	local ssFolder = ServerStorage:FindFirstChild("Maps")
	if ssFolder then
		local candidate = ssFolder:FindFirstChild(mapId)
		if candidate then
			mapModel  = candidate:Clone()
			mapModel.Parent = Workspace
			wasCloned = true
		end
	end

	-- 2. Fall back to Workspace (Edit-mode MapBuilder output)
	if not mapModel then
		local wsFolder = Workspace:FindFirstChild("Maps")
		if wsFolder then
			mapModel  = wsFolder:FindFirstChild(mapId)
			wasCloned = false
		end
	end

	if not mapModel then
		warn("[MapService] Map not found:", mapId)
		return false
	end

	currentMapModel = mapModel
	currentMapId    = mapId

	collectSpawns(mapModel:FindFirstChild("HiderSpawns"),  hiderSpawns)
	collectSpawns(mapModel:FindFirstChild("SeekerSpawns"), seekerSpawns)

	return true
end

--[[
	unloadMap()
	Destroys the map only if it was cloned in by this service.
	Maps already in Workspace (from MapBuilder) are left untouched.
]]
function MapService.unloadMap()
	if wasCloned and currentMapModel and currentMapModel.Parent then
		currentMapModel:Destroy()
	end
	currentMapModel = nil
	currentMapId    = nil
	wasCloned       = false
	table.clear(hiderSpawns)
	table.clear(seekerSpawns)
end

--[[
	getHiderSpawn(index) → CFrame
	Wraps around if more hiders than spawn points.
]]
function MapService.getHiderSpawn(index: number): CFrame
	if #hiderSpawns == 0 then return CFrame.new(0, 5, 0) end
	return hiderSpawns[((index - 1) % #hiderSpawns) + 1]
end

--[[
	getSeekerSpawn(index) → CFrame
]]
function MapService.getSeekerSpawn(index: number): CFrame
	if #seekerSpawns == 0 then return CFrame.new(0, 5, -150) end
	return seekerSpawns[((index - 1) % #seekerSpawns) + 1]
end

--[[
	getWaitingRoomCFrame() → CFrame
	Where seekers wait during Paint and PoseLock phases.
	TODO: Replace with a real waiting room in your map.
]]
function MapService.getWaitingRoomCFrame(): CFrame
	return CFrame.new(0, 10, -200)
end

function MapService.getCurrentMapId(): string?
	return currentMapId
end

return MapService
