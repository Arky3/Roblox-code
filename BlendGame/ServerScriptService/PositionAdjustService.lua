-- PositionAdjustService: ModuleScript in ServerScriptService
-- Handles small incremental position / rotation adjustments while a hider
-- is in Pose Mode. The server clamps all movement — the client only sends
-- direction tokens ("MoveLeft", "RotateRight", etc.), never raw positions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RoundConfig"))

local PositionAdjustService = {}

-- ── Per-player adjustment state ────────────────────────────────────────────
-- Initialised when a hider enters Pose Mode; cleared on exit/round end.

type AdjustState = {
	originCFrame:   CFrame,  -- where they entered pose mode (immutable anchor)
	totalDeltaPos:  Vector3, -- accumulated XZ displacement from origin
	totalRotDeg:    number,  -- accumulated Y rotation in degrees from origin
}

local states: { [Player]: AdjustState } = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Returns the horizontal displacement magnitude (ignores Y-axis travel)
local function flatDist(v: Vector3): number
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- ── Public API ─────────────────────────────────────────────────────────────

--[[
	init(player, originCFrame)
	Call when a hider enters Pose Mode. Records their starting CFrame so
	subsequent adjustments are clamped relative to it.
]]
function PositionAdjustService.init(player: Player, originCFrame: CFrame)
	states[player] = {
		originCFrame   = originCFrame,
		totalDeltaPos  = Vector3.zero,
		totalRotDeg    = 0,
	}
end

--[[
	adjust(player, action) → CFrame?
	Applies one incremental adjustment and returns the new world CFrame,
	or nil if the request is rejected.

	Valid action strings:
	  "RotateLeft"  "RotateRight"
	  "MoveLeft"    "MoveRight"
	  "MoveUp"      "MoveDown"   (vertical; clamped so char stays above floor)
]]
function PositionAdjustService.adjust(player: Player, action: string): CFrame?
	local state = states[player]
	if not state then return nil end

	if type(action) ~= "string" then return nil end

	local step    = RoundConfig.ADJUST_STEP
	local rotStep = RoundConfig.ADJUST_ROTATION_STEP
	local maxDist = RoundConfig.ADJUST_MAX_DISTANCE
	local maxRot  = RoundConfig.ADJUST_MAX_ROTATION

	-- Current world CFrame rebuilt from origin + accumulated deltas
	local originPos = state.originCFrame.Position
	local currentY  = originPos.Y + state.totalDeltaPos.Y

	-- Facing direction of origin (Y-rotated by accumulated rotation)
	local baseAngle    = math.rad(state.originCFrame:ToEulerAnglesYXZ() -- returns rx,ry,rz; we want ry
		-- ToEulerAnglesYXZ not in Luau; use workaround:
	)
	-- Compute current facing: origin yaw + accumulated rotation
	local _, originYaw, _ = state.originCFrame:ToOrientation()
	local currentYaw      = originYaw + math.rad(state.totalRotDeg)
	local facingCF        = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), currentYaw)

	-- Local movement axes (relative to current facing)
	local right   = facingCF.RightVector
	local up      = Vector3.new(0, 1, 0)
	local forward = facingCF.LookVector

	local newDeltaPos = state.totalDeltaPos
	local newRotDeg   = state.totalRotDeg

	if action == "RotateLeft" then
		local candidate = state.totalRotDeg - rotStep
		if math.abs(candidate) > maxRot then return nil end
		newRotDeg = candidate

	elseif action == "RotateRight" then
		local candidate = state.totalRotDeg + rotStep
		if math.abs(candidate) > maxRot then return nil end
		newRotDeg = candidate

	elseif action == "MoveLeft" then
		local candidate = newDeltaPos - right * step
		if flatDist(candidate) > maxDist then return nil end
		newDeltaPos = candidate

	elseif action == "MoveRight" then
		local candidate = newDeltaPos + right * step
		if flatDist(candidate) > maxDist then return nil end
		newDeltaPos = candidate

	elseif action == "MoveUp" then
		-- Vertical: allow up to 2 studs up
		local candidate = newDeltaPos + up * step
		if candidate.Y > 2 then return nil end
		newDeltaPos = candidate

	elseif action == "MoveDown" then
		-- Vertical: don't let character sink below origin floor level
		local candidate = newDeltaPos - up * step
		if candidate.Y < -0.5 then return nil end
		newDeltaPos = candidate

	else
		warn("[PositionAdjustService] Unknown action:", action)
		return nil
	end

	-- Commit
	state.totalDeltaPos = newDeltaPos
	state.totalRotDeg   = newRotDeg

	-- Build and return the new world CFrame
	local newPos  = originPos + newDeltaPos
	local newYaw  = originYaw + math.rad(newRotDeg)
	local newCF   = CFrame.new(newPos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), newYaw)

	return newCF
end

--[[
	getCurrentCFrame(player) → CFrame?
	Returns the player's current adjusted CFrame, or nil if not tracked.
]]
function PositionAdjustService.getCurrentCFrame(player: Player): CFrame?
	local state = states[player]
	if not state then return nil end

	local originPos        = state.originCFrame.Position
	local _, originYaw, _  = state.originCFrame:ToOrientation()
	local newPos           = originPos + state.totalDeltaPos
	local newYaw           = originYaw + math.rad(state.totalRotDeg)

	return CFrame.new(newPos) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), newYaw)
end

--[[
	clear(player) — call on pose exit or player leave.
]]
function PositionAdjustService.clear(player: Player)
	states[player] = nil
end

--[[
	clearAll() — call at round end.
]]
function PositionAdjustService.clearAll()
	table.clear(states)
end

return PositionAdjustService
