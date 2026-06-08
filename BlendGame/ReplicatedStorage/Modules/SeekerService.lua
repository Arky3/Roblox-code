-- SeekerService: ModuleScript in ReplicatedStorage/Modules
-- Server-side processing of SeekerClick remote events.
-- All validation happens here; the client only sends a ray origin + direction.

local RoundConfig = require(script.Parent.RoundConfig)

local SeekerService = {}

-- { [Player (seeker)]: number }  tick() of last wrong click
local wrongClickTimestamps: { [Player]: number } = {}
-- { [Player (hider)]: true }  hiders eliminated this round
local eliminatedSet: { [Player]: true } = {}

-- Callbacks wired up by GameManager each round
local _onEliminated: ((hider: Player, seeker: Player, fastBonus: number) -> ())? = nil
local _onWrongClick: ((seeker: Player) -> ())? = nil

-- ── Internal helpers ───────────────────────────────────────────────────────

-- Build RaycastParams that exclude all seeker and spectator characters
-- so the ray only hits hiders, terrain, and props.
local function buildRaycastParams(
	seekerChar: Model?,
	roles: { seekers: { Player }, spectators: { Player } }
): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local excluded: { Instance } = {}

	if seekerChar then
		table.insert(excluded, seekerChar)
	end
	for _, s in ipairs(roles.seekers) do
		if s.Character then table.insert(excluded, s.Character) end
	end
	for _, sp in ipairs(roles.spectators) do
		if sp.Character then table.insert(excluded, sp.Character) end
	end

	params.FilterDescendantsInstances = excluded
	return params
end

-- Walk up the instance hierarchy to find the owning Player (if any)
local function findPlayerFromInstance(instance: Instance): Player?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	return game:GetService("Players"):GetPlayerFromCharacter(model)
end

-- ── Public API ────────────────────────────────────────────────────────────

--[[
	setCallbacks(onEliminated, onWrongClick)
	GameManager calls this at the start of each Seek phase.
	Callbacks are cleared in clearRound().
]]
function SeekerService.setCallbacks(
	onEliminated: (hider: Player, seeker: Player, fastBonus: number) -> (),
	onWrongClick: (seeker: Player) -> ()
)
	_onEliminated = onEliminated
	_onWrongClick = onWrongClick
end

--[[
	processClick(seeker, origin, direction, roles, seekPhaseStart) → boolean
	Returns true on a successful elimination, false otherwise.

	Validation layers (in order):
	  1. Seeker is in the roles.seekers list
	  2. Not on wrong-click cooldown
	  3. origin and direction are Vector3 values
	  4. direction has non-zero magnitude
	  5. origin is within MAX_ORIGIN_DRIFT studs of the seeker's HRP (anti-cheat)
	  6. Raycast hits something
	  7. Hit belongs to an active (non-eliminated) hider
]]
function SeekerService.processClick(
	seeker: Player,
	origin: any,
	direction: any,
	roles: { hiders: { Player }, seekers: { Player }, spectators: { Player } },
	seekPhaseStart: number
): boolean
	-- 1. Validate role
	if not table.find(roles.seekers, seeker) then return false end

	-- 2. Cooldown check
	local now = tick()
	local lastWrong = wrongClickTimestamps[seeker]
	if lastWrong and (now - lastWrong) < RoundConfig.WRONG_CLICK_COOLDOWN then
		return false  -- Still in cooldown window; silently drop the input
	end

	-- 3 & 4. Validate ray inputs
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return false
	end
	if direction.Magnitude < 1e-4 then return false end
	direction = direction.Unit

	-- 5. Origin proximity check (anti-cheat: reject spoofed far-away rays)
	local seekerChar = seeker.Character
	local hrp = seekerChar and seekerChar:FindFirstChild("HumanoidRootPart")
	if hrp then
		local drift = (origin - hrp.Position).Magnitude
		if drift > RoundConfig.MAX_ORIGIN_DRIFT then
			warn("[SeekerService] Rejected ray from", seeker.Name,
				"— origin drift", drift, "studs")
			return false
		end
	end

	-- 6. Server-authoritative raycast
	local params = buildRaycastParams(seekerChar, roles)
	local result = workspace:Raycast(
		origin,
		direction * RoundConfig.MAX_CLICK_DISTANCE,
		params
	)

	if not result then
		-- Missed: hit nothing within range
		wrongClickTimestamps[seeker] = now
		if _onWrongClick then _onWrongClick(seeker) end
		return false
	end

	-- 7a. Identify hit player
	local hitPlayer = findPlayerFromInstance(result.Instance)

	-- 7b. Must be an active hider
	if not hitPlayer or not table.find(roles.hiders, hitPlayer) then
		wrongClickTimestamps[seeker] = now
		if _onWrongClick then _onWrongClick(seeker) end
		return false
	end

	-- 7c. Must not already be eliminated
	if eliminatedSet[hitPlayer] then
		wrongClickTimestamps[seeker] = now
		if _onWrongClick then _onWrongClick(seeker) end
		return false
	end

	-- ✅ Valid elimination
	eliminatedSet[hitPlayer] = true

	-- Calculate speed bonus: linear scale from full bonus at t=0 to 0 at t=end
	local elapsed   = now - seekPhaseStart
	local bonusFrac = math.max(0, 1 - elapsed / RoundConfig.SEEK_DURATION)
	local fastBonus = math.floor(bonusFrac * RoundConfig.SCORE_SEEKER_FAST_BONUS)

	if _onEliminated then
		_onEliminated(hitPlayer, seeker, fastBonus)
	end

	return true
end

--[[
	isEliminated(player) → boolean
]]
function SeekerService.isEliminated(player: Player): boolean
	return eliminatedSet[player] == true
end

--[[
	clearRound()
	Call at round cleanup. Resets all state and callbacks.
]]
function SeekerService.clearRound()
	table.clear(wrongClickTimestamps)
	table.clear(eliminatedSet)
	_onEliminated = nil
	_onWrongClick = nil
end

return SeekerService
