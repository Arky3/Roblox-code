-- MapVoteService: ModuleScript in ServerScriptService
-- Manages the map voting flow for a single round.
-- GameManager calls MapVoteService.runVote(duration) and awaits the winning map.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MapConfig"))

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local MapVoteStarted = Remotes:WaitForChild("MapVoteStarted") :: RemoteEvent
local SubmitMapVote  = Remotes:WaitForChild("SubmitMapVote")  :: RemoteEvent
local MapVoteUpdated = Remotes:WaitForChild("MapVoteUpdated") :: RemoteEvent
local MapVoteEnded   = Remotes:WaitForChild("MapVoteEnded")   :: RemoteEvent

local MapVoteService = {}

-- ── Round-scoped state ─────────────────────────────────────────────────────
local currentChoices: { any }               = {}
local playerVotes:   { [Player]: string }   = {}
local voteCounts:    { [string]: number }   = {}
local voteActive     = false
local submitConn:    RBXScriptConnection?   = nil
local leaveConn:     RBXScriptConnection?   = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Partial Fisher-Yates: pick `n` items from `pool` without full shuffle
local function pickRandom(pool: { any }, n: number): { any }
	local copy = table.clone(pool)
	local result = {}
	n = math.min(n, #copy)
	for i = 1, n do
		local j = math.random(i, #copy)
		copy[i], copy[j] = copy[j], copy[i]
		table.insert(result, copy[i])
	end
	return result
end

local function buildCountsPayload(): { [string]: number }
	local payload: { [string]: number } = {}
	for _, map in ipairs(currentChoices) do
		payload[map.Id] = voteCounts[map.Id] or 0
	end
	return payload
end

local function broadcastCounts()
	local payload = buildCountsPayload()
	for _, player in ipairs(Players:GetPlayers()) do
		MapVoteUpdated:FireClient(player, payload)
	end
end

local function determineWinner(): any
	local best   = -1
	local winners: { any } = {}
	for _, map in ipairs(currentChoices) do
		local count = voteCounts[map.Id] or 0
		if count > best then
			best    = count
			winners = { map }
		elseif count == best then
			table.insert(winners, map)
		end
	end
	-- Random tiebreak
	return winners[math.random(1, #winners)]
end

local function clearState()
	table.clear(currentChoices)
	table.clear(playerVotes)
	table.clear(voteCounts)
	voteActive = false

	if submitConn then submitConn:Disconnect(); submitConn = nil end
	if leaveConn  then leaveConn:Disconnect();  leaveConn  = nil end
end

-- ── Public API ─────────────────────────────────────────────────────────────

--[[
	runVote(duration) → mapData
	Yields for `duration` seconds, then returns the winning map table.
	GameManager calls this directly; it blocks the calling coroutine.
]]
function MapVoteService.runVote(duration: number): any
	clearState()

	-- Select 4 random maps (or fewer if MapConfig has less)
	currentChoices = pickRandom(MapConfig.Maps, 4)
	for _, map in ipairs(currentChoices) do
		voteCounts[map.Id] = 0
	end
	voteActive = true

	local endsAt = workspace:GetServerTimeNow() + duration

	-- Broadcast choices to all current players
	for _, player in ipairs(Players:GetPlayers()) do
		MapVoteStarted:FireClient(player, currentChoices, duration, endsAt)
	end

	-- Give choices to players who join mid-vote
	leaveConn = Players.PlayerRemoving:Connect(function(player)
		if not voteActive then return end
		local prev = playerVotes[player]
		if prev then
			voteCounts[prev] = math.max(0, (voteCounts[prev] or 1) - 1)
			playerVotes[player] = nil
			broadcastCounts()
		end
	end)

	-- Accept votes
	submitConn = SubmitMapVote.OnServerEvent:Connect(function(player, mapId)
		if not voteActive then return end
		if type(mapId) ~= "string" then return end

		-- Validate mapId is one of the current choices
		local valid = false
		for _, map in ipairs(currentChoices) do
			if map.Id == mapId then valid = true; break end
		end
		if not valid then return end

		-- Undo previous vote
		local prev = playerVotes[player]
		if prev then
			voteCounts[prev] = math.max(0, (voteCounts[prev] or 1) - 1)
		end

		-- Record new vote
		playerVotes[player] = mapId
		voteCounts[mapId]   = (voteCounts[mapId] or 0) + 1

		broadcastCounts()
	end)

	-- Wait out the voting window
	task.wait(duration)

	-- Close voting
	voteActive = false
	if submitConn then submitConn:Disconnect(); submitConn = nil end
	if leaveConn  then leaveConn:Disconnect();  leaveConn  = nil end

	local winner = determineWinner()

	for _, player in ipairs(Players:GetPlayers()) do
		MapVoteEnded:FireClient(player, winner)
	end

	clearState()
	return winner
end

--[[
	clear() — safety cleanup if the round ends unexpectedly.
]]
function MapVoteService.clear()
	clearState()
end

return MapVoteService
