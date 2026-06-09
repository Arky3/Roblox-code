-- HiderPoseController: LocalScript in StarterPlayer/StarterPlayerScripts
-- Sends pose-mode requests to the server on keyboard / UI button input.
-- The SERVER decides validity; this script only fires RemoteEvents.
--
-- Keybindings (active only when role=Hider and phase=Paint or PoseLock):
--   P       — Enter / toggle Pose Mode
--   R       — Cycle to next pose
--   Q       — Rotate left
--   E       — Rotate right
--   W       — Move up (vertical nudge)
--   S       — Move down (vertical nudge)
--   A       — Shift left
--   D       — Shift right
--   F       — Lock pose
--   C       — Exit pose mode

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ── Remotes ────────────────────────────────────────────────────────────────
local Remotes            = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules            = ReplicatedStorage:WaitForChild("Modules", 30)
local RoundStateChanged  = Remotes:WaitForChild("RoundStateChanged")  :: RemoteEvent
local RoleAssigned       = Remotes:WaitForChild("RoleAssigned")       :: RemoteEvent
local PoseModeUpdated    = Remotes:WaitForChild("PoseModeUpdated")    :: RemoteEvent
local EnterPoseMode      = Remotes:WaitForChild("EnterPoseMode")      :: RemoteEvent
local ChangePose         = Remotes:WaitForChild("ChangePose")         :: RemoteEvent
local AdjustPosePosition = Remotes:WaitForChild("AdjustPosePosition") :: RemoteEvent
local LockPose           = Remotes:WaitForChild("LockPose")           :: RemoteEvent
local ExitPoseMode       = Remotes:WaitForChild("ExitPoseMode")       :: RemoteEvent

local PoseConfig = require(Modules:WaitForChild("PoseConfig"))

-- ── Client-side state (mirrors server state from PoseModeUpdated) ──────────
local currentRole    = "Spectator"
local currentPhase   = "Idle"
local isInPoseMode   = false
local isLocked       = false
local isFrozen       = false
local currentPoseIdx = 1   -- index into PoseConfig.Poses array

-- ── Helpers ────────────────────────────────────────────────────────────────

local function canUsePoseControls(): boolean
	return currentRole == "Hider"
		and (currentPhase == "Paint" or currentPhase == "PoseLock")
		and not isFrozen
end

local function canAdjust(): boolean
	return canUsePoseControls() and isInPoseMode and not isLocked
end

local function cyclePose(direction: number)
	if not canAdjust() then return end
	local total = #PoseConfig.Poses
	currentPoseIdx = ((currentPoseIdx - 1 + direction) % total) + 1
	local pose = PoseConfig.Poses[currentPoseIdx]
	ChangePose:FireServer(pose.PoseId)
end

-- ── Keyboard input ─────────────────────────────────────────────────────────

-- Map KeyCode → action function
-- Built lazily so Enum is resolved at runtime
local function handleKey(keyCode: Enum.KeyCode)
	if not canUsePoseControls() then return end

	-- P: toggle pose mode
	if keyCode == Enum.KeyCode.P then
		if isInPoseMode then
			if not isLocked then
				ExitPoseMode:FireServer()
			end
		else
			EnterPoseMode:FireServer()
		end
		return
	end

	-- Keys below require pose mode to be active
	if not isInPoseMode then return end

	if keyCode == Enum.KeyCode.R then
		cyclePose(1)

	elseif keyCode == Enum.KeyCode.Q then
		if not isLocked then AdjustPosePosition:FireServer("RotateLeft")  end
	elseif keyCode == Enum.KeyCode.E then
		if not isLocked then AdjustPosePosition:FireServer("RotateRight") end
	elseif keyCode == Enum.KeyCode.W then
		if not isLocked then AdjustPosePosition:FireServer("MoveUp")      end
	elseif keyCode == Enum.KeyCode.S then
		if not isLocked then AdjustPosePosition:FireServer("MoveDown")    end
	elseif keyCode == Enum.KeyCode.A then
		if not isLocked then AdjustPosePosition:FireServer("MoveLeft")    end
	elseif keyCode == Enum.KeyCode.D then
		if not isLocked then AdjustPosePosition:FireServer("MoveRight")   end

	elseif keyCode == Enum.KeyCode.F then
		if not isLocked then LockPose:FireServer() end

	elseif keyCode == Enum.KeyCode.C then
		if not isLocked then ExitPoseMode:FireServer() end
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	handleKey(input.KeyCode)
end)

-- ── Remote listeners ───────────────────────────────────────────────────────

RoleAssigned.OnClientEvent:Connect(function(role: string)
	currentRole  = role
	isInPoseMode = false
	isLocked     = false
	isFrozen     = false
	currentPoseIdx = 1
end)

RoundStateChanged.OnClientEvent:Connect(function(phase: string)
	currentPhase = phase
	if phase ~= "Paint" and phase ~= "PoseLock" then
		-- Entering a phase where pose mode is no longer relevant
		isInPoseMode = false
	end
end)

-- Server tells us the authoritative pose state after every change
PoseModeUpdated.OnClientEvent:Connect(function(state: {
	poseId:       string,
	isInPoseMode: boolean,
	isLocked:     boolean,
	isFrozen:     boolean,
})
	isInPoseMode = state.isInPoseMode
	isLocked     = state.isLocked
	isFrozen     = state.isFrozen

	-- Keep local pose index in sync with what the server confirmed
	if state.poseId and state.poseId ~= "" then
		for i, pose in ipairs(PoseConfig.Poses) do
			if pose.PoseId == state.poseId then
				currentPoseIdx = i
				break
			end
		end
	end
end)

-- ── Expose state for PoseGui ───────────────────────────────────────────────
-- PoseGui reads these via shared module state or direct require.
-- We expose a simple getter table on _G for sibling LocalScripts to read.
-- In a real game, use a shared module instead.

_G.HiderPoseState = {
	getRole      = function() return currentRole    end,
	getPhase     = function() return currentPhase   end,
	isInPoseMode = function() return isInPoseMode   end,
	isLocked     = function() return isLocked       end,
	isFrozen     = function() return isFrozen       end,
	getPoseIdx   = function() return currentPoseIdx end,
	cyclePose    = cyclePose,
	fireAdjust   = function(action) if canAdjust() then AdjustPosePosition:FireServer(action) end end,
	fireLock     = function() if canUsePoseControls() and isInPoseMode and not isLocked then LockPose:FireServer() end end,
	fireExit     = function() if canUsePoseControls() and isInPoseMode and not isLocked then ExitPoseMode:FireServer() end end,
	fireEnter    = function() if canUsePoseControls() and not isInPoseMode then EnterPoseMode:FireServer() end end,
}
