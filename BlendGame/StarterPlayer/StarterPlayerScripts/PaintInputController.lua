-- PaintInputController: LocalScript in StarterPlayerScripts
-- Keyboard controller for the grid-based paint system.
-- E key toggles the PaintGui open/closed, provided the player is a Hider
-- and the current phase allows painting (Paint or PoseLock).

local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes           = ReplicatedStorage:WaitForChild("Remotes", 30)
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")      :: RemoteEvent

local myRole   = nil
local curPhase = nil

local function canPaint()
	return myRole == "Hider"
		and (curPhase == "Paint" or curPhase == "PoseLock")
end

RoleAssigned.OnClientEvent:Connect(function(role: string)
	myRole = role

	-- If role changed to non-Hider while gui is open, close it
	if role ~= "Hider" then
		local gui = playerGui:FindFirstChild("PaintGui")
		if gui and gui.Enabled then
			gui.Enabled = false
			_G.PaintGuiEnabled = false
		end
	end
end)

RoundStateChanged.OnClientEvent:Connect(function(phase: string)
	curPhase = phase

	-- Close gui if phase no longer allows painting
	if not canPaint() then
		local gui = playerGui:FindFirstChild("PaintGui")
		if gui and gui.Enabled then
			gui.Enabled = false
			_G.PaintGuiEnabled = false
		end
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		if not canPaint() then return end

		local gui = playerGui:FindFirstChild("PaintGui")
		if gui then
			gui.Enabled       = not gui.Enabled
			_G.PaintGuiEnabled = gui.Enabled
		end
	end
end)
