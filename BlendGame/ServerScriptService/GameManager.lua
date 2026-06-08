-- GameManager: Script in ServerScriptService
-- Orchestrates the full Blend Game round loop.
-- All round state lives here; services are stateless helpers.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Wait for folder structure ──────────────────────────────────────────────
local Modules = ReplicatedStorage:WaitForChild("Modules", 30)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)

assert(Modules, "[GameManager] ReplicatedStorage/Modules not found after 30s")
assert(Remotes, "[GameManager] ReplicatedStorage/Remotes not found after 30s")

-- ── Services ───────────────────────────────────────────────────────────────
local RoundConfig   = require(Modules:WaitForChild("RoundConfig"))
local RoleService   = require(Modules:WaitForChild("RoleService"))
local PaintService  = require(Modules:WaitForChild("PaintService"))
local PoseService   = require(Modules:WaitForChild("PoseService"))
local SeekerService = require(Modules:WaitForChild("SeekerService"))
local ScoreService  = require(Modules:WaitForChild("ScoreService"))

-- ── Remotes ────────────────────────────────────────────────────────────────
-- All remotes must be pre-created as RemoteEvent instances in Studio
-- under ReplicatedStorage/Remotes before running.
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")      :: RemoteEvent
local PaintSubmitted    = Remotes:WaitForChild("PaintSubmitted")    :: RemoteEvent
local SetPose           = Remotes:WaitForChild("SetPose")           :: RemoteEvent
local SeekerClick       = Remotes:WaitForChild("SeekerClick")       :: RemoteEvent
local PlayerEliminated  = Remotes:WaitForChild("PlayerEliminated")  :: RemoteEvent
local RoundResults      = Remotes:WaitForChild("RoundResults")      :: RemoteEvent

-- ── Map CFrames ────────────────────────────────────────────────────────────
-- TODO: Replace these with the actual CFrames from your map geometry.
local SEEKER_WAIT_CFRAME = CFrame.new(0, 10, -150)   -- Sealed waiting room
local MAP_SPAWN_CFRAME   = CFrame.new(0,  5,   0)    -- Main play area

-- ── Round state ────────────────────────────────────────────────────────────
local currentRoles: {
	hiders:     { Player },
	seekers:    { Player },
	spectators: { Player },
}? = nil

local currentPhase   = "Lobby"
local roundIdCounter = 0

-- Connections created per-round; disconnected in cleanupRound()
local roundConnections: { RBXScriptConnection } = {}

-- Hider seek-phase entry times for half-survival scoring
-- { [Player]: number (tick()) }
local hiderSeekEntryTime: { [Player]: number } = {}
local seekPhaseStart = 0

-- ── Helpers ────────────────────────────────────────────────────────────────

local function fireAll(remote: RemoteEvent, ...)
	for _, player in ipairs(Players:GetPlayers()) do
		remote:FireClient(player, ...)
	end
end

local function trackConnection(conn: RBXScriptConnection)
	table.insert(roundConnections, conn)
end

local function disconnectAll()
	for _, conn in ipairs(roundConnections) do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(roundConnections)
end

--[[
	broadcastPhase(phase, duration)
	Fires RoundStateChanged to all clients with server-authoritative timing.
	Clients use endsAt = workspace:GetServerTimeNow() + duration to sync timers.
]]
local function broadcastPhase(phase: string, duration: number)
	roundIdCounter += 1
	local endsAt = workspace:GetServerTimeNow() + duration
	fireAll(RoundStateChanged, phase, duration, endsAt, roundIdCounter)
	currentPhase = phase
end

local function teleportCharacter(player: Player, cf: CFrame)
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = cf
	end
end

-- Counts active (non-spectator) players in the current roles table
local function activePlayerCount(): number
	if not currentRoles then return #Players:GetPlayers() end
	return #currentRoles.hiders + #currentRoles.seekers
end

-- ── Phase implementations ──────────────────────────────────────────────────

local function doLobby()
	currentPhase = "Lobby"
	currentRoles = nil

	-- Keep rebroadcasting every second until we hit MIN_PLAYERS
	while #Players:GetPlayers() < RoundConfig.MIN_PLAYERS do
		local endsAt = workspace:GetServerTimeNow() + RoundConfig.LOBBY_DURATION
		fireAll(RoundStateChanged, "Lobby", RoundConfig.LOBBY_DURATION, endsAt, 0)
		task.wait(2)
	end

	-- Final countdown broadcast
	broadcastPhase("Lobby", RoundConfig.LOBBY_DURATION)
	task.wait(RoundConfig.LOBBY_DURATION)
end

local function doPaintPhase()
	-- ── Role assignment ────────────────────────────────────────────────────
	local activePlayers = Players:GetPlayers()
	currentRoles = RoleService.assignRoles(activePlayers)

	-- Initialise scores for everyone (no-op if already initialised)
	for _, p in ipairs(activePlayers) do
		ScoreService.initPlayer(p)
	end

	-- Notify each player of their role
	for _, hider in ipairs(currentRoles.hiders) do
		RoleAssigned:FireClient(hider, "Hider")
	end
	for _, seeker in ipairs(currentRoles.seekers) do
		RoleAssigned:FireClient(seeker, "Seeker")
		teleportCharacter(seeker, SEEKER_WAIT_CFRAME)
	end
	for _, spec in ipairs(currentRoles.spectators) do
		RoleAssigned:FireClient(spec, "Spectator")
	end

	-- Reset hider characters to white
	for _, hider in ipairs(currentRoles.hiders) do
		PaintService.resetPaint(hider)
	end

	-- Accept PaintSubmitted only from hiders, only during Paint phase
	trackConnection(PaintSubmitted.OnServerEvent:Connect(function(player, data)
		if currentPhase ~= "Paint" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PaintService.submitPaint(player, data)
	end))

	broadcastPhase("Paint", RoundConfig.PAINT_DURATION)
	task.wait(RoundConfig.PAINT_DURATION)

	-- Apply whatever colors were submitted (unpainted parts remain white)
	for _, hider in ipairs(currentRoles.hiders) do
		PaintService.applyPaint(hider)
	end
end

local function doPoseLockPhase()
	-- Accept SetPose only from hiders, only during PoseLock phase
	trackConnection(SetPose.OnServerEvent:Connect(function(player, poseIndex)
		if currentPhase ~= "PoseLock" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PoseService.freezePlayer(player, poseIndex)
	end))

	broadcastPhase("PoseLock", RoundConfig.POSE_LOCK_DURATION)
	task.wait(RoundConfig.POSE_LOCK_DURATION)

	-- Freeze any hider that didn't choose a pose
	for _, hider in ipairs(currentRoles.hiders) do
		if not PoseService.isFrozen(hider) then
			PoseService.freezePlayer(hider, 1)
		end
	end
end

local function doSeekPhase()
	seekPhaseStart = tick()

	-- Record seek-entry time per hider for half-survival scoring
	for _, hider in ipairs(currentRoles.hiders) do
		hiderSeekEntryTime[hider] = seekPhaseStart
	end

	-- Set elimination and wrong-click callbacks before accepting clicks
	SeekerService.setCallbacks(
		-- onEliminated
		function(hider: Player, seeker: Player, fastBonus: number)
			-- Notify all clients (HUD, spectator view, etc.)
			fireAll(PlayerEliminated, hider, seeker)

			-- Award seeker
			ScoreService.applySeekerCorrect(seeker, fastBonus)

			-- Score hider based on survival time
			local timeAlive = tick() - (hiderSeekEntryTime[hider] or seekPhaseStart)
			ScoreService.applyHiderResult(
				hider, false, RoundConfig.SEEK_DURATION, timeAlive
			)

			-- Unfreeze and allow the eliminated hider to spectate
			PoseService.unfreezePlayer(hider)
		end,
		-- onWrongClick
		function(seeker: Player)
			ScoreService.applySeekerWrong(seeker)
			-- Send WrongClick phase signal only to this seeker so their HUD
			-- can show the penalty flash and cooldown indicator.
			RoundStateChanged:FireClient(
				seeker, "WrongClick",
				RoundConfig.WRONG_CLICK_COOLDOWN,
				workspace:GetServerTimeNow() + RoundConfig.WRONG_CLICK_COOLDOWN,
				roundIdCounter
			)
		end
	)

	-- Release seekers into the map
	for _, seeker in ipairs(currentRoles.seekers) do
		teleportCharacter(seeker, MAP_SPAWN_CFRAME)
	end

	-- Accept SeekerClick only during Seek phase
	trackConnection(SeekerClick.OnServerEvent:Connect(function(player, origin, direction)
		if currentPhase ~= "Seek" then return end
		if not currentRoles then return end
		SeekerService.processClick(
			player, origin, direction, currentRoles, seekPhaseStart
		)
	end))

	broadcastPhase("Seek", RoundConfig.SEEK_DURATION)
	task.wait(RoundConfig.SEEK_DURATION)

	-- Award hiders who survived the full Seek phase
	for _, hider in ipairs(currentRoles.hiders) do
		if not SeekerService.isEliminated(hider) then
			ScoreService.applyHiderResult(
				hider, true, RoundConfig.SEEK_DURATION, RoundConfig.SEEK_DURATION
			)
		end
	end
end

local function doResults()
	-- Build serialisable leaderboard (no Player refs across the network)
	local leaderboard = ScoreService.getLeaderboard()
	local payload = {}
	for rank, entry in ipairs(leaderboard) do
		table.insert(payload, {
			rank       = rank,
			playerName = entry.playerName,
			userId     = entry.userId,
			score      = entry.score,
		})
	end

	fireAll(RoundResults, payload)
	broadcastPhase("Results", RoundConfig.RESULTS_DURATION)
	task.wait(RoundConfig.RESULTS_DURATION)
end

-- ── Round cleanup ──────────────────────────────────────────────────────────

local function cleanupRound()
	disconnectAll()
	PoseService.unfreezeAll()
	PaintService.clearAll()
	SeekerService.clearRound()
	table.clear(hiderSeekEntryTime)
	currentRoles = nil
end

-- ── Player lifecycle ───────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	ScoreService.initPlayer(player)

	if currentRoles and currentPhase ~= "Lobby" and currentPhase ~= "Results" then
		-- Mid-round join → spectator
		RoleService.assignSpectator(player, currentRoles)
		RoleAssigned:FireClient(player, "Spectator")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if currentRoles then
		-- Unfreeze before removing so physics state is clean
		if PoseService.isFrozen(player) then
			PoseService.unfreezePlayer(player)
		end
		RoleService.removePlayer(player, currentRoles)
	end

	-- If we've dropped below minimum mid-round, abandon and restart
	if currentPhase ~= "Lobby" and currentPhase ~= "Results" then
		if #Players:GetPlayers() - 1 < RoundConfig.MIN_PLAYERS then
			warn("[GameManager] Below minimum players — abandoning round")
			fireAll(RoundStateChanged, "Abandoned", 0, workspace:GetServerTimeNow(), roundIdCounter)
			-- The running coroutine will hit task.wait() next and naturally
			-- complete its phase; cleanupRound + new lobby will follow.
			-- We forcibly shorten the current phase by overwriting the phase
			-- name so no further server-authoritative actions run.
			currentPhase = "Abandoned"
		end
	end
end)

-- ── Main game loop ─────────────────────────────────────────────────────────

local function runLoop()
	while true do
		local ok, err = pcall(function()
			doLobby()

			-- Recheck minimum after lobby wait
			if #Players:GetPlayers() < RoundConfig.MIN_PLAYERS then
				return  -- Skip to next iteration; doLobby will wait again
			end

			doPaintPhase()

			if currentPhase == "Abandoned" then return end
			doPoseLockPhase()

			if currentPhase == "Abandoned" then return end
			doSeekPhase()

			if currentPhase == "Abandoned" then return end
			doResults()
		end)

		if not ok then
			warn("[GameManager] Uncaught error in round loop:", err)
		end

		cleanupRound()
		task.wait(2)  -- Brief gap before the next lobby countdown
	end
end

task.spawn(runLoop)
