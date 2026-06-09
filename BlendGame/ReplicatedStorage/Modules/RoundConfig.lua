-- RoundConfig: ModuleScript in ReplicatedStorage/Modules
-- Single source of truth for all tunable game constants.
-- Both server and client require this module.
-- Pose definitions have been moved to PoseConfig.

local RoundConfig = {}

-- ── Phase durations (seconds) ──────────────────────────────────────────────
RoundConfig.INTERMISSION_DURATION  = 20
RoundConfig.MAP_VOTE_DURATION      = 20
RoundConfig.ROLE_REVEAL_DURATION   = 5
RoundConfig.PAINT_DURATION         = 60
RoundConfig.POSE_LOCK_DURATION     = 20
RoundConfig.SEEK_DURATION          = 90
RoundConfig.RESULTS_DURATION       = 12

-- ── Player limits ──────────────────────────────────────────────────────────
RoundConfig.MIN_PLAYERS = 2
RoundConfig.MAX_PLAYERS = 10

-- Seeker count = clamp(floor(playerCount * ratio), MIN, MAX)
RoundConfig.SEEKER_RATIO = 0.25
RoundConfig.MIN_SEEKERS  = 1
RoundConfig.MAX_SEEKERS  = 3

-- ── Scoring ────────────────────────────────────────────────────────────────
RoundConfig.HIDER_SURVIVE_FULL  = 100
RoundConfig.HIDER_SURVIVE_HALF  = 40
RoundConfig.SEEKER_CORRECT      = 75
RoundConfig.SEEKER_FAST_BONUS   = 25   -- Max additional bonus for speed
RoundConfig.SEEKER_WRONG        = -15

-- ── Seeker mechanics ───────────────────────────────────────────────────────
RoundConfig.WRONG_CLICK_COOLDOWN  = 2     -- seconds between wrong clicks
RoundConfig.MAX_CLICK_DISTANCE    = 100   -- studs; server raycast length
-- Maximum distance the ray origin may be from the seeker's HRP (anti-cheat)
RoundConfig.MAX_ORIGIN_DRIFT      = 50

-- ── Position adjustment limits ────────────────────────────────────────────
-- Controls how far a hider can nudge their pose position after locking in.
-- Only applies to poses where AllowsAdjustment = true (see PoseConfig).
RoundConfig.ADJUST_STEP          = 0.4   -- studs per adjustment tap
RoundConfig.ADJUST_MAX_DISTANCE  = 3     -- max studs from original pose position
RoundConfig.ADJUST_ROTATION_STEP = 5     -- degrees per tap
RoundConfig.ADJUST_MAX_ROTATION  = 45    -- max degrees from original facing

-- ── Wall snap ─────────────────────────────────────────────────────────────
-- Used by PoseService for poses where CanWallSnap = true (see PoseConfig).
RoundConfig.WALL_SNAP_DISTANCE = 5     -- max studs to detect a wall
RoundConfig.WALL_SNAP_OFFSET   = 0.6   -- distance to keep from wall surface

-- ── Body parts ────────────────────────────────────────────────────────────
-- Ordered; used by PaintService and PaintGui.
RoundConfig.PAINTABLE_PARTS = {
	"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
}

-- ── Color palette ─────────────────────────────────────────────────────────
-- Shared between PaintGui and HudGui color previews.
RoundConfig.PALETTE = {
	Color3.fromRGB(255,  80,  80),   -- Red
	Color3.fromRGB(255, 160,  40),   -- Orange
	Color3.fromRGB(255, 230,  40),   -- Yellow
	Color3.fromRGB( 80, 200,  80),   -- Green
	Color3.fromRGB( 40, 180, 200),   -- Cyan
	Color3.fromRGB( 60, 100, 240),   -- Blue
	Color3.fromRGB(160,  60, 240),   -- Purple
	Color3.fromRGB(240,  80, 180),   -- Pink
	Color3.fromRGB(180, 120,  60),   -- Brown
	Color3.fromRGB(255, 255, 255),   -- White
	Color3.fromRGB(160, 160, 160),   -- Gray
	Color3.fromRGB( 20,  20,  20),   -- Black
	Color3.fromRGB(100, 220, 140),   -- Mint
	Color3.fromRGB(255, 200, 100),   -- Peach
	Color3.fromRGB( 40,  60,  80),   -- Dark Navy
	Color3.fromRGB(200, 255, 120),   -- Lime
}

return RoundConfig
