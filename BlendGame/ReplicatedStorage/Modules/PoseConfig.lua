-- PoseConfig: ModuleScript in ReplicatedStorage/Modules
-- Defines all supported hider poses for Blend Game.
-- Replace AnimationId values with real Animator asset IDs before shipping.
-- AnimationId = "rbxassetid://0" → server skips animation loading and freezes the character.

local PoseConfig = {}

-- ── Pose definitions ──────────────────────────────────────────────────────────
--
-- Fields:
--   PoseId           string   Unique identifier
--   DisplayName      string   Human-readable name shown in the UI
--   AnimationId      string   rbxassetid:// URL for the Animator track
--   CanWallSnap      boolean  When true PoseService will snap the character to a nearby wall
--   AllowsAdjustment boolean  When true the hider may nudge position/rotation after locking in
--   RootOffset       Vector3  Offset from the HumanoidRootPart center applied while the pose is active
--   RotationOffset   number   Additional yaw in degrees applied on top of the character's facing angle

PoseConfig.Poses = {
	{
		PoseId           = "StandingFlat",
		DisplayName      = "Standing Flat",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = false,
		RootOffset       = Vector3.new(0, 0, 0),
		RotationOffset   = 0,
	},
	{
		PoseId           = "Crouch",
		DisplayName      = "Crouch",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = true,
		RootOffset       = Vector3.new(0, -1.5, 0),
		RotationOffset   = 0,
	},
	{
		PoseId           = "LayDown",
		DisplayName      = "Lay Down",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = true,
		RootOffset       = Vector3.new(0, -2, 0),
		RotationOffset   = 0,
	},
	{
		PoseId           = "LeanLeft",
		DisplayName      = "Lean Left",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = true,
		RootOffset       = Vector3.new(-0.5, 0, 0),
		RotationOffset   = -15,
	},
	{
		PoseId           = "LeanRight",
		DisplayName      = "Lean Right",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = true,
		RootOffset       = Vector3.new(0.5, 0, 0),
		RotationOffset   = 15,
	},
	{
		PoseId           = "WallHug",
		DisplayName      = "Wall Hug",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = true,
		AllowsAdjustment = true,
		RootOffset       = Vector3.new(0, 0, -0.4),
		RotationOffset   = 0,
	},
	{
		PoseId           = "CornerHide",
		DisplayName      = "Corner Hide",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = true,
		RootOffset       = Vector3.new(0, 0, 0),
		RotationOffset   = 45,
	},
	{
		PoseId           = "ArmsOut",
		DisplayName      = "Arms Out",
		AnimationId      = "rbxassetid://0",
		CanWallSnap      = false,
		AllowsAdjustment = false,
		RootOffset       = Vector3.new(0, 0, 0),
		RotationOffset   = 0,
	},
}

-- ── ById lookup ───────────────────────────────────────────────────────────────
-- Usage: PoseConfig.ById["WallHug"]  →  the WallHug pose entry

PoseConfig.ById = {}
for _, pose in ipairs(PoseConfig.Poses) do
	PoseConfig.ById[pose.PoseId] = pose
end

return PoseConfig
