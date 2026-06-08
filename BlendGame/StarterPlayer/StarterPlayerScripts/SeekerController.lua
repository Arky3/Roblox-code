-- SeekerController: LocalScript in StarterPlayer/StarterPlayerScripts
-- Sends a server-authoritative camera ray on every click during Seek phase.
-- The server does all validation; this script only packages the ray.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Remotes ────────────────────────────────────────────────────────────────
local Remotes           = ReplicatedStorage:WaitForChild("Remotes", 30)
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")      :: RemoteEvent
local SeekerClick       = Remotes:WaitForChild("SeekerClick")       :: RemoteEvent
local PlayerEliminated  = Remotes:WaitForChild("PlayerEliminated")  :: RemoteEvent

-- ── State ──────────────────────────────────────────────────────────────────
local currentRole  = "Spectator"
local currentPhase = "Lobby"
local clickEnabled = true          -- Toggled false during wrong-click cooldown
local cooldownEndsAt = 0           -- server time when cooldown expires

-- ── Role / phase tracking ──────────────────────────────────────────────────

RoleAssigned.OnClientEvent:Connect(function(role: string)
	currentRole  = role
	clickEnabled = true
end)

RoundStateChanged.OnClientEvent:Connect(function(
	phase: string,
	_duration: number,
	endsAt: number,
	_roundId: number
)
	if phase == "WrongClick" then
		-- Server tells this seeker they made a wrong click
		clickEnabled   = false
		cooldownEndsAt = endsAt  -- endsAt repurposed as cooldown end time

		-- Re-enable locally once the cooldown window passes
		task.delay(endsAt - workspace:GetServerTimeNow(), function()
			if currentPhase == "Seek" then
				clickEnabled = true
			end
		end)
		return
	end

	currentPhase = phase

	if phase ~= "Seek" then
		clickEnabled = true  -- Reset on any non-seek phase change
	end
end)

-- ── Cursor management ─────────────────────────────────────────────────────

-- Show a crosshair cursor while the seeker can click
RunService.RenderStepped:Connect(function()
	if currentRole == "Seeker" and currentPhase == "Seek" then
		if clickEnabled then
			UserInputService.MouseIcon = "rbxasset://textures/Cursors/CrossHair.png"
		else
			-- Red/blocked cursor feedback during cooldown
			UserInputService.MouseIcon = ""  -- Default cursor during penalty
		end
	else
		UserInputService.MouseIcon = ""
	end
end)

-- ── Click handler ──────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch

	if not (isMouse or isTouch) then return end
	if currentRole  ~= "Seeker" then return end
	if currentPhase ~= "Seek"   then return end
	if not clickEnabled         then return end

	-- Build viewport ray from screen position
	local screenPos: Vector2

	if isTouch then
		screenPos = input.Position  -- Touch position is already a Vector2-like Vector3
		screenPos = Vector2.new(screenPos.X, screenPos.Y)
	else
		screenPos = UserInputService:GetMouseLocation()
	end

	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)

	-- Throttle: prevent spam-firing (the server also enforces cooldown)
	clickEnabled = false
	task.delay(0.1, function()
		-- Re-enable after a short client-side guard (not a full cooldown;
		-- wrong-click cooldown is enforced by the server callback above)
		if currentPhase == "Seek" then
			clickEnabled = true
		end
	end)

	SeekerClick:FireServer(ray.Origin, ray.Direction)
end)

-- ── Elimination feedback ───────────────────────────────────────────────────

PlayerEliminated.OnClientEvent:Connect(function(hider: Player, seeker: Player)
	if seeker == player then
		-- TODO: Play a "found them!" sound / flash effect here
	end
end)
