-- RoundConfig: ModuleScript in ReplicatedStorage/Modules
-- Single source of truth for all tunable game constants.
-- Both server and client require this module.

local RoundConfig = {}

-- ── Phase durations (seconds) ──────────────────────────────────────────────
RoundConfig.LOBBY_DURATION     = 15
RoundConfig.PAINT_DURATION     = 60
RoundConfig.POSE_LOCK_DURATION = 15
RoundConfig.SEEK_DURATION      = 45
RoundConfig.RESULTS_DURATION   = 10

-- ── Player limits ──────────────────────────────────────────────────────────
RoundConfig.MIN_PLAYERS = 2
RoundConfig.MAX_PLAYERS = 10

-- Seeker count = clamp(floor(playerCount * ratio), MIN, MAX)
RoundConfig.SEEKER_RATIO = 0.30
RoundConfig.MIN_SEEKERS  = 1
RoundConfig.MAX_SEEKERS  = 3

-- ── Scoring ────────────────────────────────────────────────────────────────
RoundConfig.SCORE_HIDER_SURVIVE_FULL  = 100
RoundConfig.SCORE_HIDER_SURVIVE_HALF  = 40
RoundConfig.SCORE_SEEKER_CORRECT_FIND = 75
RoundConfig.SCORE_SEEKER_FAST_BONUS   = 25   -- Max additional bonus for speed
RoundConfig.SCORE_SEEKER_WRONG_CLICK  = -15

-- ── Seeker mechanics ───────────────────────────────────────────────────────
RoundConfig.WRONG_CLICK_COOLDOWN  = 2     -- seconds between wrong clicks
RoundConfig.MAX_CLICK_DISTANCE    = 100   -- studs; server raycast length
-- Maximum distance the ray origin may be from the seeker's HRP (anti-cheat)
RoundConfig.MAX_ORIGIN_DRIFT      = 50

-- ── Body parts ────────────────────────────────────────────────────────────
-- Ordered; used by PaintService and PaintGui
RoundConfig.PAINTABLE_PARTS = {
	"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
}

-- ── Poses ─────────────────────────────────────────────────────────────────
-- Replace animId values with real Animator asset IDs before shipping.
-- animId = "rbxassetid://0" → server will skip animation loading and just freeze.
RoundConfig.POSES = {
	{ name = "Stand Straight", animId = "rbxassetid://0" },
	{ name = "Crouch",         animId = "rbxassetid://0" },
	{ name = "Wave",           animId = "rbxassetid://0" },
	{ name = "Sit",            animId = "rbxassetid://0" },
	{ name = "Look Up",        animId = "rbxassetid://0" },
	{ name = "Lean",           animId = "rbxassetid://0" },
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
