-- PoseService: ModuleScript in ServerScriptService
-- Central authority for all hider pose state during a round.
-- Owns: pose mode tracking, animation playback, wall snapping, freeze/unfreeze.
-- Delegates position clamping to PositionAdjustService.
-- Delegates wall detection to WallSnapService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PoseConfig            = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PoseConfig"))
local PositionAdjustService = require(script.Parent:WaitForChild("PositionAdjustService"))
local WallSnapService       = require(script.Parent:WaitForChild("WallSnapService"))

-- PoseModeUpdated fires to the hider whenever their pose state changes so
-- their client UI can stay in sync.
local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local PoseModeUpdated = Remotes:WaitForChild("PoseModeUpdated") :: RemoteEvent

local PoseService = {}

-- ── Types ──────────────────────────────────────────────────────────────────

type PoseState = {
	poseId:       string,
	isInPoseMode: boolean,
	isLocked:     boolean,
	isFrozen:     boolean,  -- true while SeekPhase; no changes allowed
	originCFrame: CFrame,   -- CFrame when pose mode was entered
	finalCFrame:  CFrame?,  -- set on lockPose
	wallNormal:   Vector3?, -- set if WallHug succeeded
	animTrack:    AnimationTrack?,
}

-- { [Player]: PoseState }
local poseStates: { [Player]: PoseState } = {}

-- ── Defaults ───────────────────────────────────────────────────────────────

local DEFAULT_WALKSPEED  = 16
local DEFAULT_JUMPHEIGHT = 7.2
local DEFAULT_JUMPPOWER  = 50

-- ── Internal helpers ───────────────────────────────────────────────────────

local function getHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
end

local function stopAnim(state: PoseState)
	if state.animTrack then
		state.animTrack:Stop(0.2)
		state.animTrack = nil
	end
end

local function playAnim(player: Player, state: PoseState, poseData: any)
	local humanoid = getHumanoid(player)
	if not humanoid then return end

	stopAnim(state)

	if not poseData.AnimationId or poseData.AnimationId == "rbxassetid://0" then
		return  -- Placeholder; skip without error
	end

	local animator: Animator = humanoid:FindFirstChildOfClass("Animator")
		or Instance.new("Animator", humanoid)

	local animObj    = Instance.new("Animation")
	animObj.AnimationId = poseData.AnimationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(animObj)
	end)
	animObj:Destroy()

	if ok and track then
		track:Play(0.2)
		state.animTrack = track
	end
end

local function lockMovement(player: Player)
	local humanoid = getHumanoid(player)
	local rootPart = getRootPart(player)
	if humanoid then
		humanoid.WalkSpeed  = 0
		humanoid.JumpPower  = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end
	if rootPart then
		rootPart.Anchored = true
	end
end

local function unlockMovement(player: Player)
	local humanoid = getHumanoid(player)
	local rootPart = getRootPart(player)
	if humanoid then
		humanoid.WalkSpeed  = DEFAULT_WALKSPEED
		humanoid.JumpPower  = DEFAULT_JUMPPOWER
		humanoid.JumpHeight = DEFAULT_JUMPHEIGHT
		humanoid.AutoRotate = true
	end
	if rootPart then
		rootPart.Anchored = false
	end
end

local function fireUpdate(player: Player, state: PoseState)
	PoseModeUpdated:FireClient(player, {
		poseId      = state.poseId,
		isInPoseMode = state.isInPoseMode,
		isLocked    = state.isLocked,
		isFrozen    = state.isFrozen,
	})
end

-- ── Public API ─────────────────────────────────────────────────────────────

--[[
	enterPoseMode(player) → ok: boolean, reason: string
	Allowed only if the player is not already locked or frozen.
]]
function PoseService.enterPoseMode(player: Player): (boolean, string)
	local state = poseStates[player]
	if state and state.isLocked  then return false, "already_locked"  end
	if state and state.isFrozen  then return false, "frozen"          end
	if state and state.isInPoseMode then return true, "ok"           end  -- Already in pose mode

	local rootPart = getRootPart(player)
	if not rootPart then return false, "no_character" end

	-- Restrict movement so they can only adjust via the pose system
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed  = 0
		humanoid.JumpPower  = 0
		humanoid.JumpHeight = 0
	end

	local originCF = rootPart.CFrame
	poseStates[player] = {
		poseId       = "StandingFlat",
		isInPoseMode = true,
		isLocked     = false,
		isFrozen     = false,
		originCFrame = originCF,
		finalCFrame  = nil,
		wallNormal   = nil,
		animTrack    = nil,
	}

	PositionAdjustService.init(player, originCF)

	-- Play default pose animation
	local poseData = PoseConfig.ById["StandingFlat"]
	if poseData then playAnim(player, poseStates[player], poseData) end

	fireUpdate(player, poseStates[player])
	return true, "ok"
end

--[[
	exitPoseMode(player)
	Restores movement. Not allowed after lock-in.
]]
function PoseService.exitPoseMode(player: Player)
	local state = poseStates[player]
	if not state then return end
	if state.isLocked or state.isFrozen then return end

	stopAnim(state)
	unlockMovement(player)
	PositionAdjustService.clear(player)
	poseStates[player] = nil

	PoseModeUpdated:FireClient(player, {
		poseId       = "",
		isInPoseMode = false,
		isLocked     = false,
		isFrozen     = false,
	})
end

--[[
	changePose(player, poseId) → ok: boolean, reason: string
]]
function PoseService.changePose(player: Player, poseId: string): (boolean, string)
	local state = poseStates[player]
	if not state                 then return false, "not_in_pose_mode" end
	if not state.isInPoseMode    then return false, "not_in_pose_mode" end
	if state.isLocked            then return false, "already_locked"   end
	if state.isFrozen            then return false, "frozen"           end
	if type(poseId) ~= "string"  then return false, "invalid_pose"     end

	local poseData = PoseConfig.ById[poseId]
	if not poseData then return false, "invalid_pose" end

	-- Handle wall snap
	local newCFrame = PositionAdjustService.getCurrentCFrame(player)
		or getRootPart(player) and getRootPart(player).CFrame
	state.wallNormal = nil

	if poseData.CanWallSnap then
		local snapResult = WallSnapService.findSnap(player)
		if not snapResult then
			return false, "no_wall_nearby"
		end
		newCFrame        = snapResult.snapCFrame
		state.wallNormal = snapResult.wallNormal

		-- Re-init adjustment from the snap position
		PositionAdjustService.clear(player)
		PositionAdjustService.init(player, snapResult.snapCFrame)
	end

	state.poseId = poseId
	playAnim(player, state, poseData)

	-- Apply root offset from pose config
	if newCFrame then
		local rootPart = getRootPart(player)
		if rootPart and poseData.RootOffset ~= Vector3.zero then
			local offset = poseData.RootOffset
			newCFrame = newCFrame * CFrame.new(offset)
		end
		if rootPart then
			rootPart.CFrame = newCFrame
		end
	end

	fireUpdate(player, state)
	return true, "ok"
end

--[[
	adjustPosition(player, action) → ok: boolean, reason: string
	Delegates to PositionAdjustService, then moves the character.
]]
function PoseService.adjustPosition(player: Player, action: string): (boolean, string)
	local state = poseStates[player]
	if not state              then return false, "not_in_pose_mode" end
	if not state.isInPoseMode then return false, "not_in_pose_mode" end
	if state.isLocked         then return false, "already_locked"   end
	if state.isFrozen         then return false, "frozen"           end

	local poseData = PoseConfig.ById[state.poseId]
	if poseData and not poseData.AllowsAdjustment then
		return false, "pose_no_adjustment"
	end

	local newCF = PositionAdjustService.adjust(player, action)
	if not newCF then return false, "out_of_bounds" end

	local rootPart = getRootPart(player)
	if rootPart then rootPart.CFrame = newCF end

	return true, "ok"
end

--[[
	lockPose(player) → ok: boolean, reason: string
	Anchors the character in its final position. Cannot be undone until round end.
]]
function PoseService.lockPose(player: Player): (boolean, string)
	local state = poseStates[player]
	if not state              then return false, "not_in_pose_mode" end
	if not state.isInPoseMode then return false, "not_in_pose_mode" end
	if state.isLocked         then return true,  "ok"               end  -- Already locked
	if state.isFrozen         then return false,  "frozen"          end

	local rootPart = getRootPart(player)
	if not rootPart then return false, "no_character" end

	-- Save final CFrame
	state.finalCFrame = rootPart.CFrame
	state.isLocked    = true

	-- Fully anchor
	lockMovement(player)

	-- Ensure animation is still playing (paused on last frame)
	local poseData = PoseConfig.ById[state.poseId]
	if poseData and state.animTrack then
		state.animTrack:AdjustSpeed(0)
	end

	PositionAdjustService.clear(player)
	fireUpdate(player, state)
	return true, "ok"
end

--[[
	forceLockedAt(player)
	Called at PoseLock expiry for hiders who didn't lock manually.
	Locks them at their current position with whatever pose they have.
]]
function PoseService.forceLockedAt(player: Player)
	local state = poseStates[player]
	if state and state.isLocked then return end

	if not state then
		-- Player never entered pose mode; create a basic locked state
		local rootPart = getRootPart(player)
		if not rootPart then return end
		state = {
			poseId       = "StandingFlat",
			isInPoseMode = true,
			isLocked     = false,
			isFrozen     = false,
			originCFrame = rootPart.CFrame,
			finalCFrame  = nil,
			wallNormal   = nil,
			animTrack    = nil,
		}
		poseStates[player] = state
	end

	local rootPart = getRootPart(player)
	if rootPart then state.finalCFrame = rootPart.CFrame end
	state.isLocked = true

	lockMovement(player)
	PositionAdjustService.clear(player)
	fireUpdate(player, state)
end

--[[
	freezeAll()
	Called at the start of SeekPhase. Marks all tracked hiders as frozen
	so no further pose changes are accepted even if connections are open.
]]
function PoseService.freezeAll()
	for player, state in pairs(poseStates) do
		state.isFrozen = true
		-- Ensure still anchored (safety)
		lockMovement(player)
		fireUpdate(player, state)
	end
end

--[[
	unfreezePlayer(player)
	Restores movement after round ends. Stops animation.
]]
function PoseService.unfreezePlayer(player: Player)
	local state = poseStates[player]
	if state then stopAnim(state) end
	unlockMovement(player)
	poseStates[player] = nil
	PositionAdjustService.clear(player)
end

--[[
	unfreezeAll() — call at round cleanup.
]]
function PoseService.unfreezeAll()
	local snapshot: { Player } = {}
	for player in pairs(poseStates) do table.insert(snapshot, player) end
	for _, player in ipairs(snapshot) do
		PoseService.unfreezePlayer(player)
	end
end

--[[
	removePlayer(player) — call on PlayerRemoving.
]]
function PoseService.removePlayer(player: Player)
	PoseService.unfreezePlayer(player)
end

-- ── State queries ──────────────────────────────────────────────────────────

function PoseService.isInPoseMode(player: Player): boolean
	local s = poseStates[player]
	return s ~= nil and s.isInPoseMode
end

function PoseService.isLocked(player: Player): boolean
	local s = poseStates[player]
	return s ~= nil and s.isLocked
end

function PoseService.isFrozen(player: Player): boolean
	local s = poseStates[player]
	return s ~= nil and s.isFrozen
end

function PoseService.clearRound()
	PoseService.unfreezeAll()
	PositionAdjustService.clearAll()
end

return PoseService
