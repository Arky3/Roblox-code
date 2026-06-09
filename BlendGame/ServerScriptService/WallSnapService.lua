-- WallSnapService: ModuleScript in ServerScriptService
-- Server-side wall detection for the WallHug pose.
-- Casts rays in 4 horizontal directions from the player's HRP,
-- finds the nearest valid tagged surface, and returns a snap CFrame.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RoundConfig"))

local WallSnapService = {}

-- Tags that mark a surface as a valid wall to snap to
local VALID_TAGS = { "Sampleable", "HidableSurface" }

-- ── Helpers ────────────────────────────────────────────────────────────────

local function isValidSurface(part: BasePart): boolean
	for _, tag in ipairs(VALID_TAGS) do
		if CollectionService:HasTag(part, tag) then
			return true
		end
	end
	return false
end

-- Build RaycastParams that exclude the player's own character
local function makeParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType                 = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return params
end

--[[
	Compute the snap CFrame from a hit result.
	The character will stand at the snap position facing AWAY from the wall
	(back against the wall, facing into the room).
]]
local function computeSnapCFrame(hitPoint: Vector3, wallNormal: Vector3, hrpY: number): CFrame
	-- Keep the character at their current floor height
	local snapPos = Vector3.new(
		hitPoint.X + wallNormal.X * RoundConfig.WALL_SNAP_OFFSET,
		hrpY,
		hitPoint.Z + wallNormal.Z * RoundConfig.WALL_SNAP_OFFSET
	)

	-- The character's look vector should point ALONG the wall normal
	-- (facing away from the wall = back pressed against it)
	-- Guard against straight up/down normals (floor/ceiling hits)
	local flatNormal = Vector3.new(wallNormal.X, 0, wallNormal.Z)
	if flatNormal.Magnitude < 0.01 then
		-- Wall is a floor or ceiling — can't snap horizontally
		return nil
	end
	flatNormal = flatNormal.Unit

	-- Right vector: perpendicular to normal in the horizontal plane
	local right = flatNormal:Cross(Vector3.new(0, 1, 0)).Unit

	-- Build CFrame: position + orientation (LookVector = flatNormal outward)
	return CFrame.fromMatrix(snapPos, right, Vector3.new(0, 1, 0))
end

-- ── Public API ─────────────────────────────────────────────────────────────

--[[
	findSnap(player) → result? | nil
	result = {
	    snapCFrame : CFrame,
	    wallNormal : Vector3,
	    hitPart    : BasePart,
	}
	Returns nil if no valid wall is within WALL_SNAP_DISTANCE studs.
]]
function WallSnapService.findSnap(player: Player): { snapCFrame: CFrame, wallNormal: Vector3, hitPart: BasePart }?
	local character = player.Character
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end

	local params    = makeParams(character)
	local origin    = hrp.Position
	local cf        = hrp.CFrame
	local maxDist   = RoundConfig.WALL_SNAP_DISTANCE

	-- 4 horizontal scan directions: forward, back, left, right
	local directions = {
		cf.LookVector,
		-cf.LookVector,
		cf.RightVector,
		-cf.RightVector,
	}

	local bestDist:   number?  = nil
	local bestResult: { snapCFrame: CFrame, wallNormal: Vector3, hitPart: BasePart }? = nil

	for _, dir in ipairs(directions) do
		-- Flatten to horizontal (ignore Y component so we only hit walls, not floor/ceiling)
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		if flatDir.Magnitude < 0.01 then continue end
		flatDir = flatDir.Unit

		local result = workspace:Raycast(origin, flatDir * maxDist, params)
		if not result then continue end
		if not result.Instance:IsA("BasePart") then continue end
		if not isValidSurface(result.Instance :: BasePart) then continue end

		local dist = (result.Position - origin).Magnitude
		if bestDist and dist >= bestDist then continue end

		local snapCF = computeSnapCFrame(result.Position, result.Normal, origin.Y)
		if not snapCF then continue end

		bestDist   = dist
		bestResult = {
			snapCFrame = snapCF,
			wallNormal = result.Normal,
			hitPart    = result.Instance :: BasePart,
		}
	end

	return bestResult
end

return WallSnapService
