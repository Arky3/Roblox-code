-- RoleService: ModuleScript in ReplicatedStorage/Modules
-- Assigns roles at round start and maintains the role table during a round.
-- All mutations happen server-side only; clients are notified via RoleAssigned.

local RoundConfig = require(script.Parent.RoundConfig)

local RoleService = {}

-- ── Internal helpers ───────────────────────────────────────────────────────

-- Fisher-Yates shuffle (in place, returns same table)
local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function removeFromList(list, player)
	for i, p in ipairs(list) do
		if p == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

-- ── Public API ────────────────────────────────────────────────────────────

--[[
	assignRoles(players: {Player}) → roles
	roles = { hiders: {Player}, seekers: {Player}, spectators: {Player} }

	Called once at the start of a round with the confirmed player list.
	Late joiners are added via assignSpectator().
]]
function RoleService.assignRoles(players)
	local pool = shuffle(table.clone(players))
	local count = #pool

	local seekerCount = math.clamp(
		math.floor(count * RoundConfig.SEEKER_RATIO),
		RoundConfig.MIN_SEEKERS,
		RoundConfig.MAX_SEEKERS
	)
	-- Guard: never assign more seekers than we have players
	seekerCount = math.min(seekerCount, count - 1)

	local roles = {
		hiders     = {},
		seekers    = {},
		spectators = {},
	}

	for i, player in ipairs(pool) do
		if i <= seekerCount then
			table.insert(roles.seekers, player)
		else
			table.insert(roles.hiders, player)
		end
	end

	return roles
end

--[[
	assignSpectator(player, roles)
	Late joiners or overflow players become spectators.
	Safe to call even if the player is already in a list (defensive).
]]
function RoleService.assignSpectator(player, roles)
	-- Remove from active lists first (safety)
	removeFromList(roles.hiders,  player)
	removeFromList(roles.seekers, player)

	if not table.find(roles.spectators, player) then
		table.insert(roles.spectators, player)
	end
end

--[[
	removePlayer(player, roles)
	Called when a player leaves mid-round.
]]
function RoleService.removePlayer(player, roles)
	removeFromList(roles.hiders,     player)
	removeFromList(roles.seekers,    player)
	removeFromList(roles.spectators, player)
end

--[[
	getRole(player, roles) → "Hider" | "Seeker" | "Spectator"
]]
function RoleService.getRole(player, roles)
	if table.find(roles.hiders,     player) then return "Hider"     end
	if table.find(roles.seekers,    player) then return "Seeker"    end
	if table.find(roles.spectators, player) then return "Spectator" end
	return "Spectator"  -- Unknown players are treated as spectators
end

--[[
	isHider / isSeeker — convenience wrappers
]]
function RoleService.isHider(player, roles)
	return table.find(roles.hiders, player) ~= nil
end

function RoleService.isSeeker(player, roles)
	return table.find(roles.seekers, player) ~= nil
end

--[[
	activeHiderCount(roles) → number
	Does NOT count eliminated hiders (role list is not mutated on elimination).
	Use SeekerService.isEliminated() for that.
]]
function RoleService.activeHiderCount(roles)
	return #roles.hiders
end

return RoleService
