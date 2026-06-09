-- GameManager: Script in ServerScriptService
-- Full round loop: Intermission → MapVote → RoleReveal → Paint →
--                  PoseLock → Seek → Results

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Wait for folder structure ──────────────────────────────────────────────
local Modules = ReplicatedStorage:WaitForChild("Modules", 30)
local Remotes = ReplicatedStorage:WaitForChild("Remotes",  30)
assert(Modules, "[GameManager] ReplicatedStorage/Modules missing")
assert(Remotes, "[GameManager] ReplicatedStorage/Remotes missing")

-- ── Shared modules (ReplicatedStorage) ────────────────────────────────────
local RoundConfig = require(Modules:WaitForChild("RoundConfig"))
local RoleService = require(Modules:WaitForChild("RoleService"))
local PaintService = require(Modules:WaitForChild("PaintService"))
local ScoreService = require(Modules:WaitForChild("ScoreService"))

-- ── Server-only services (ServerScriptService siblings) ───────────────────
local MapVoteService        = require(script.Parent:WaitForChild("MapVoteService"))
local MapService            = require(script.Parent:WaitForChild("MapService"))
local PoseService           = require(script.Parent:WaitForChild("PoseService"))
local SeekerService         = require(script.Parent:WaitForChild("SeekerService"))

-- ── Remotes ────────────────────────────────────────────────────────────────
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")      :: RemoteEvent
local PaintSubmitted    = Remotes:WaitForChild("PaintSubmitted")    :: RemoteEvent
local EnterPoseMode     = Remotes:WaitForChild("EnterPoseMode")     :: RemoteEvent
local ChangePose        = Remotes:WaitForChild("ChangePose")        :: RemoteEvent
local AdjustPosePosition= Remotes:WaitForChild("AdjustPosePosition"):: RemoteEvent
local LockPose          = Remotes:WaitForChild("LockPose")          :: RemoteEvent
local ExitPoseMode      = Remotes:WaitForChild("ExitPoseMode")      :: RemoteEvent
local SeekerClick       = Remotes:WaitForChild("SeekerClick")       :: RemoteEvent
local PlayerEliminated  = Remotes:WaitForChild("PlayerEliminated")  :: RemoteEvent
local RoundResults      = Remotes:WaitForChild("RoundResults")      :: RemoteEvent

-- ── Round state ────────────────────────────────────────────────────────────
local currentRoles: {
	hiders:     { Player },
	seekers:    { Player },
	spectators: { Player },
}? = nil

local currentPhase   = "Idle"
local roundIdCounter = 0

-- Per-round connections — all disconnected in cleanupRound()
local roundConnections: { RBXScriptConnection } = {}
local seekPhaseStart   = 0
local hiderSeekEntry:  { [Player]: number } = {}

-- ── Utilities ──────────────────────────────────────────────────────────────

local function fireAll(remote: RemoteEvent, ...)
	for _, p in ipairs(Players:GetPlayers()) do remote:FireClient(p, ...) end
end

local function track(conn: RBXScriptConnection)
	table.insert(roundConnections, conn)
end

local function disconnectAll()
	for _, c in ipairs(roundConnections) do
		if c.Connected then c:Disconnect() end
	end
	table.clear(roundConnections)
end

local function broadcastPhase(phase: string, duration: number)
	roundIdCounter += 1
	local endsAt = workspace:GetServerTimeNow() + duration
	fireAll(RoundStateChanged, phase, duration, endsAt, roundIdCounter)
	currentPhase = phase
end

local function teleport(player: Player, cf: CFrame)
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = cf end
end

-- ── Phase: Intermission ────────────────────────────────────────────────────

local function doIntermission()
	currentPhase = "Intermission"
	currentRoles = nil

	while #Players:GetPlayers() < RoundConfig.MIN_PLAYERS do
		local endsAt = workspace:GetServerTimeNow() + RoundConfig.INTERMISSION_DURATION
		fireAll(RoundStateChanged, "Intermission", RoundConfig.INTERMISSION_DURATION, endsAt, 0)
		task.wait(2)
	end

	broadcastPhase("Intermission", RoundConfig.INTERMISSION_DURATION)
	task.wait(RoundConfig.INTERMISSION_DURATION)
end

-- ── Phase: MapVote ─────────────────────────────────────────────────────────

local function doMapVote(): boolean
	-- MapVoteService.runVote() handles its own broadcasts and waits
	broadcastPhase("MapVote", RoundConfig.MAP_VOTE_DURATION)
	local winner = MapVoteService.runVote(RoundConfig.MAP_VOTE_DURATION)

	local loaded = MapService.loadMap(winner.Id)
	if not loaded then
		warn("[GameManager] Could not load map:", winner.Id, "— skipping round")
		return false
	end
	return true
end

-- ── Phase: RoleReveal ──────────────────────────────────────────────────────

local function doRoleReveal()
	local players = Players:GetPlayers()
	currentRoles  = RoleService.assignRoles(players)

	for _, p in ipairs(players) do ScoreService.initPlayer(p) end

	for _, h in ipairs(currentRoles.hiders)     do RoleAssigned:FireClient(h, "Hider")     end
	for _, s in ipairs(currentRoles.seekers)    do RoleAssigned:FireClient(s, "Seeker")    end
	for _, sp in ipairs(currentRoles.spectators) do RoleAssigned:FireClient(sp, "Spectator") end

	broadcastPhase("RoleReveal", RoundConfig.ROLE_REVEAL_DURATION)
	task.wait(RoundConfig.ROLE_REVEAL_DURATION)
end

-- ── Phase: Paint ───────────────────────────────────────────────────────────

local function doPaintPhase()
	-- Move seekers to waiting room; reset hider paint
	for i, s in ipairs(currentRoles.seekers) do
		teleport(s, MapService.getWaitingRoomCFrame())
	end
	for _, h in ipairs(currentRoles.hiders) do
		PaintService.resetPaint(h)
	end

	-- ── Paint submission ──────────────────────────────────────────────────
	track(PaintSubmitted.OnServerEvent:Connect(function(player, data)
		if currentPhase ~= "Paint" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PaintService.submitPaint(player, data)
	end))

	-- ── Pose mode controls (active for Paint + PoseLock) ─────────────────
	track(EnterPoseMode.OnServerEvent:Connect(function(player)
		if currentPhase ~= "Paint" and currentPhase ~= "PoseLock" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PoseService.enterPoseMode(player)
	end))

	track(ChangePose.OnServerEvent:Connect(function(player, poseId)
		if currentPhase ~= "Paint" and currentPhase ~= "PoseLock" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PoseService.changePose(player, poseId)
	end))

	track(AdjustPosePosition.OnServerEvent:Connect(function(player, action)
		if currentPhase ~= "Paint" and currentPhase ~= "PoseLock" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PoseService.adjustPosition(player, action)
	end))

	track(LockPose.OnServerEvent:Connect(function(player)
		if currentPhase ~= "Paint" and currentPhase ~= "PoseLock" then return end
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PoseService.lockPose(player)
	end))

	track(ExitPoseMode.OnServerEvent:Connect(function(player)
		if currentPhase == "Seek" then return end  -- No exit during Seek
		if not currentRoles or not RoleService.isHider(player, currentRoles) then return end
		PoseService.exitPoseMode(player)
	end))

	broadcastPhase("Paint", RoundConfig.PAINT_DURATION)
	task.wait(RoundConfig.PAINT_DURATION)

	-- Apply submitted paint colors to characters
	for _, h in ipairs(currentRoles.hiders) do
		PaintService.applyPaint(h)
	end
end

-- ── Phase: PoseLock ────────────────────────────────────────────────────────

local function doPoseLockPhase()
	broadcastPhase("PoseLock", RoundConfig.POSE_LOCK_DURATION)
	task.wait(RoundConfig.POSE_LOCK_DURATION)

	-- Force-lock any hiders who didn't choose to lock themselves
	for _, h in ipairs(currentRoles.hiders) do
		if not PoseService.isLocked(h) then
			PoseService.forceLockedAt(h)
		end
	end
end

-- ── Phase: Seek ────────────────────────────────────────────────────────────

local function doSeekPhase()
	seekPhaseStart = tick()

	-- Freeze all hiders; no more pose changes from this point
	PoseService.freezeAll()

	-- Record seek entry time per hider for half-survival scoring
	for _, h in ipairs(currentRoles.hiders) do
		hiderSeekEntry[h] = seekPhaseStart
	end

	-- Set scoring callbacks on SeekerService
	SeekerService.setCallbacks(
		function(hider, seeker, fastBonus)
			fireAll(PlayerEliminated, hider, seeker)
			ScoreService.applySeekerCorrect(seeker, fastBonus)

			local timeAlive = tick() - (hiderSeekEntry[hider] or seekPhaseStart)
			ScoreService.applyHiderResult(hider, false, RoundConfig.SEEK_DURATION, timeAlive)

			PoseService.unfreezePlayer(hider)
		end,
		function(seeker)
			ScoreService.applySeekerWrong(seeker)
			RoundStateChanged:FireClient(seeker, "WrongClick",
				RoundConfig.WRONG_CLICK_COOLDOWN,
				workspace:GetServerTimeNow() + RoundConfig.WRONG_CLICK_COOLDOWN,
				roundIdCounter)
		end
	)

	-- Release seekers into the map
	for i, s in ipairs(currentRoles.seekers) do
		teleport(s, MapService.getSeekerSpawn(i))
	end

	track(SeekerClick.OnServerEvent:Connect(function(player, origin, direction)
		if currentPhase ~= "Seek" then return end
		if not currentRoles then return end
		SeekerService.processClick(player, origin, direction, currentRoles, seekPhaseStart)
	end))

	broadcastPhase("Seek", RoundConfig.SEEK_DURATION)

	-- Wait until all hiders found OR timer ends, checking every 0.5s
	local seekEnd = workspace:GetServerTimeNow() + RoundConfig.SEEK_DURATION
	while workspace:GetServerTimeNow() < seekEnd do
		task.wait(0.5)
		if currentPhase == "Abandoned" then break end

		local remaining = 0
		for _, h in ipairs(currentRoles.hiders) do
			if not SeekerService.isEliminated(h) then remaining += 1 end
		end
		if remaining == 0 then break end
	end

	-- Award hiders who survived the full seek phase
	for _, h in ipairs(currentRoles.hiders) do
		if not SeekerService.isEliminated(h) then
			ScoreService.applyHiderResult(h, true, RoundConfig.SEEK_DURATION, RoundConfig.SEEK_DURATION)
		end
	end
end

-- ── Phase: Results ─────────────────────────────────────────────────────────

local function doResults()
	local leaderboard = ScoreService.getLeaderboard()
	local payload: { { rank: number, playerName: string, userId: number, score: number } } = {}
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

-- ── Cleanup ────────────────────────────────────────────────────────────────

local function cleanupRound()
	disconnectAll()
	PoseService.clearRound()
	PaintService.clearAll()
	SeekerService.clearRound()
	MapVoteService.clear()
	table.clear(hiderSeekEntry)
	currentRoles = nil
end

-- ── Player lifecycle ───────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	ScoreService.initPlayer(player)

	if currentRoles and currentPhase ~= "Intermission" and currentPhase ~= "Results" then
		RoleService.assignSpectator(player, currentRoles)
		RoleAssigned:FireClient(player, "Spectator")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if PoseService.isLocked(player) or PoseService.isInPoseMode(player) then
		PoseService.removePlayer(player)
	end
	if currentRoles then
		RoleService.removePlayer(player, currentRoles)
	end

	-- Abandon round if we fall below minimum mid-game
	if currentPhase ~= "Intermission" and currentPhase ~= "Results" then
		if #Players:GetPlayers() - 1 < RoundConfig.MIN_PLAYERS then
			warn("[GameManager] Below minimum players — abandoning round")
			fireAll(RoundStateChanged, "Abandoned", 0, workspace:GetServerTimeNow(), roundIdCounter)
			currentPhase = "Abandoned"
		end
	end
end)

-- ── Main loop ──────────────────────────────────────────────────────────────

local function runLoop()
	while true do
		local ok, err = pcall(function()
			doIntermission()

			if #Players:GetPlayers() < RoundConfig.MIN_PLAYERS then return end

			local mapLoaded = doMapVote()
			if not mapLoaded then return end

			doRoleReveal()

			if currentPhase == "Abandoned" then return end
			doPaintPhase()

			if currentPhase == "Abandoned" then return end
			doPoseLockPhase()

			if currentPhase == "Abandoned" then return end
			doSeekPhase()

			if currentPhase == "Abandoned" then return end
			doResults()
		end)

		if not ok then
			warn("[GameManager] Round error:", err)
		end

		cleanupRound()
		task.wait(2)
	end
end

task.spawn(runLoop)
