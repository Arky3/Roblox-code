-- ScoreService: ModuleScript in ReplicatedStorage/Modules
-- Tracks cumulative scores across all rounds in the current server session.
-- All writes happen server-side only.

local RoundConfig = require(script.Parent.RoundConfig)

local ScoreService = {}

-- { [Player]: number }
local scores: { [Player]: number } = {}

-- ── Public API ────────────────────────────────────────────────────────────

--[[
	initPlayer(player)
	Creates a zero-score entry. Safe to call multiple times (no-op if exists).
]]
function ScoreService.initPlayer(player: Player)
	if scores[player] == nil then
		scores[player] = 0
	end
end

--[[
	addScore(player, amount)
	Adds (or subtracts if negative) points. Score never goes below 0.
]]
function ScoreService.addScore(player: Player, amount: number)
	local current = scores[player] or 0
	scores[player] = math.max(0, current + amount)
end

--[[
	getScore(player) → number
]]
function ScoreService.getScore(player: Player): number
	return scores[player] or 0
end

-- ── Outcome helpers ────────────────────────────────────────────────────────

--[[
	applyHiderResult(player, survived, seekDuration, timeAlive)
	  survived    — true if the hider was never eliminated
	  seekDuration — total Seek phase length (from RoundConfig)
	  timeAlive   — seconds the hider survived during Seek phase
]]
function ScoreService.applyHiderResult(
	player: Player,
	survived: boolean,
	seekDuration: number,
	timeAlive: number
)
	if survived then
		ScoreService.addScore(player, RoundConfig.SCORE_HIDER_SURVIVE_FULL)
	elseif timeAlive >= seekDuration * 0.5 then
		ScoreService.addScore(player, RoundConfig.SCORE_HIDER_SURVIVE_HALF)
	end
	-- Eliminated before half time → no hider points
end

--[[
	applySeekerCorrect(seeker, fastBonus)
	Base find score + time-based bonus.
]]
function ScoreService.applySeekerCorrect(seeker: Player, fastBonus: number)
	ScoreService.addScore(seeker, RoundConfig.SCORE_SEEKER_CORRECT_FIND + fastBonus)
end

--[[
	applySeekerWrong(seeker)
	Penalty for clicking a non-hider or already-eliminated hider.
]]
function ScoreService.applySeekerWrong(seeker: Player)
	ScoreService.addScore(seeker, RoundConfig.SCORE_SEEKER_WRONG_CLICK)
end

-- ── Leaderboard ────────────────────────────────────────────────────────────

--[[
	getLeaderboard() → { { player: Player, playerName: string, score: number } }
	Returns a new sorted (descending) list each call.
	Includes userId so clients can reconstruct the list after the player leaves.
]]
function ScoreService.getLeaderboard(): { { player: Player, playerName: string, userId: number, score: number } }
	local list = {}
	for player, score in pairs(scores) do
		table.insert(list, {
			player     = player,
			playerName = player.Name,
			userId     = player.UserId,
			score      = score,
		})
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	return list
end

--[[
	removePlayer(player)
	Call on PlayerRemoving. Preserves the score record for the leaderboard
	display until the round ends, then clearAll() drops everything.
	Actually we keep the score in the table so Results screen still shows
	the leaving player's score — just remove the Player reference by name.
]]
function ScoreService.removePlayer(player: Player)
	-- Keep the number; GameManager decides when to clearAll()
	-- scores[player] = nil  ← intentionally NOT clearing here
end

--[[
	clearAll()
	Wipes scores completely. Call between game sessions if desired.
	Not called between rounds — scores accumulate across rounds.
]]
function ScoreService.clearAll()
	table.clear(scores)
end

return ScoreService
