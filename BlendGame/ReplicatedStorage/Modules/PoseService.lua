-- PoseService: ModuleScript in ReplicatedStorage/Modules
-- Freezes hiders in a chosen pose during PoseLock and Seek phases.
-- Unfreeze is safe to call multiple times and on already-clean players.

local RoundConfig = require(script.Parent.RoundConfig)

local PoseService = {}

-- { [Player]: AnimationTrack | false }  false = frozen without animation
local activeAnimations: { [Player]: AnimationTrack | false } = {}
-- { [Player]: true }
local frozenPlayers: { [Player]: true } = {}

-- Default humanoid stats restored on unfreeze
local DEFAULT_WALKSPEED  = 16
local DEFAULT_JUMPHEIGHT = 7.2  -- R15 default
local DEFAULT_JUMPPOWER  = 50   -- R6 fallback

-- ── Internal helpers ───────────────────────────────────────────────────────

local function getHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function isValidPoseIndex(idx: any): boolean
	return type(idx) == "number"
		and math.floor(idx) == idx
		and idx >= 1
		and idx <= #RoundConfig.POSES
end

-- ── Public API ────────────────────────────────────────────────────────────

--[[
	freezePlayer(player, poseIndex)
	Locks movement, anchors HumanoidRootPart, plays pose animation (if set).
	Safe to call on already-frozen players (re-applies chosen pose).
]]
function PoseService.freezePlayer(player: Player, poseIndex: number)
	if not isValidPoseIndex(poseIndex) then
		poseIndex = 1
	end

	local humanoid = getHumanoid(player)
	local rootPart = getRootPart(player)

	if not humanoid or not rootPart then return end

	-- Stop previous animation before re-applying
	if activeAnimations[player] and activeAnimations[player] ~= false then
		;(activeAnimations[player] :: AnimationTrack):Stop(0)
		activeAnimations[player] = false
	end

	-- Lock movement
	humanoid.WalkSpeed  = 0
	humanoid.JumpPower  = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false

	-- Anchor to prevent physics drift while frozen
	rootPart.Anchored = true

	frozenPlayers[player] = true

	-- Load animation if the pose has a real asset ID
	local poseConfig = RoundConfig.POSES[poseIndex]
	if poseConfig and poseConfig.animId ~= "rbxassetid://0" then
		local animator: Animator = humanoid:FindFirstChildOfClass("Animator")
			or Instance.new("Animator", humanoid)

		local animObj    = Instance.new("Animation")
		animObj.AnimationId = poseConfig.animId

		local ok, track = pcall(function()
			return animator:LoadAnimation(animObj)
		end)
		animObj:Destroy()  -- Asset ID has been consumed; clean up

		if ok and track then
			track:Play(0)
			track:AdjustSpeed(0)  -- Pause on first frame to hold the pose
			activeAnimations[player] = track
		else
			activeAnimations[player] = false
		end
	else
		activeAnimations[player] = false
	end
end

--[[
	unfreezePlayer(player)
	Restores movement, unanchors HumanoidRootPart, stops animation.
	Safe to call on players that were never frozen.
]]
function PoseService.unfreezePlayer(player: Player)
	if not frozenPlayers[player] then return end

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

	if activeAnimations[player] and activeAnimations[player] ~= false then
		;(activeAnimations[player] :: AnimationTrack):Stop(0.2)
	end

	activeAnimations[player] = nil
	frozenPlayers[player]    = nil
end

--[[
	unfreezeAll()
	Unfreezes every tracked player. Call at round end.
]]
function PoseService.unfreezeAll()
	-- Snapshot keys; unfreezePlayer mutates frozenPlayers
	local snapshot: { Player } = {}
	for player in pairs(frozenPlayers) do
		table.insert(snapshot, player)
	end
	for _, player in ipairs(snapshot) do
		PoseService.unfreezePlayer(player)
	end
end

--[[
	isFrozen(player) → boolean
]]
function PoseService.isFrozen(player: Player): boolean
	return frozenPlayers[player] == true
end

return PoseService
