-- PoseGui: LocalScript in StarterGui
-- Pose Mode HUD for hiders. Visible only when in pose mode during Paint/PoseLock.
-- All buttons fire RemoteEvents; server decides validity.
-- Works alongside HiderPoseController (keyboard) — same remotes, different input.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

local Remotes            = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules            = ReplicatedStorage:WaitForChild("Modules", 30)
local RoundStateChanged  = Remotes:WaitForChild("RoundStateChanged")  :: RemoteEvent
local RoleAssigned       = Remotes:WaitForChild("RoleAssigned")       :: RemoteEvent
local PoseModeUpdated    = Remotes:WaitForChild("PoseModeUpdated")    :: RemoteEvent
local ChangePose         = Remotes:WaitForChild("ChangePose")         :: RemoteEvent
local AdjustPosePosition = Remotes:WaitForChild("AdjustPosePosition") :: RemoteEvent
local LockPose           = Remotes:WaitForChild("LockPose")           :: RemoteEvent
local ExitPoseMode       = Remotes:WaitForChild("ExitPoseMode")       :: RemoteEvent
local EnterPoseMode      = Remotes:WaitForChild("EnterPoseMode")      :: RemoteEvent

local PoseConfig = require(Modules:WaitForChild("PoseConfig"))

-- ── Client state ───────────────────────────────────────────────────────────
local currentRole    = "Spectator"
local currentPhase   = "Idle"
local isInPoseMode   = false
local isLocked       = false
local isFrozen       = false
local currentPoseIdx = 1

-- ── Build ScreenGui ────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name         = "PoseGui"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 11
gui.Parent       = playerGui

-- ── Helpers ────────────────────────────────────────────────────────────────

local function corner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p
end
local function stroke(p, col, t)
	local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t; s.Parent = p
end

local function makeBtn(parent, text, color, size, pos, zIndex)
	local btn = Instance.new("TextButton")
	btn.Size              = size
	btn.Position          = pos
	btn.BackgroundColor3  = color
	btn.BorderSizePixel   = 0
	btn.Text              = text
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 13
	btn.TextColor3        = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor   = false
	btn.ZIndex            = zIndex or 1
	btn.Parent            = parent
	corner(btn, 8)

	local dimColor = color:Lerp(Color3.new(0,0,0), 0.3)
	btn.MouseEnter:Connect(function()  btn.BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.15) end)
	btn.MouseLeave:Connect(function()  btn.BackgroundColor3 = color end)
	btn.MouseButton1Down:Connect(function() btn.BackgroundColor3 = dimColor end)
	btn.MouseButton1Up:Connect(function()   btn.BackgroundColor3 = color end)

	return btn
end

-- ── Layout constants ───────────────────────────────────────────────────────

local PANEL_W = 220
local PANEL_H = 390
local BLUE    = Color3.fromRGB(55, 35, 130)
local GREEN   = Color3.fromRGB(30, 180, 90)
local RED     = Color3.fromRGB(200, 50, 50)
local DARK    = Color3.fromRGB(28, 22, 50)
local ORANGE  = Color3.fromRGB(200, 130, 30)

-- ── Panel ──────────────────────────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name            = "Panel"
panel.Size            = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position        = UDim2.new(1, -(PANEL_W + 12), 0.5, -(PANEL_H / 2))
panel.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
panel.BorderSizePixel = 0
panel.Parent          = gui
corner(panel, 14)
stroke(panel, Color3.fromRGB(80, 50, 160), 2)

-- Header
local header = Instance.new("Frame")
header.Size            = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(40, 22, 100)
header.BorderSizePixel = 0
header.Parent          = panel
corner(header, 14)
local hMask = Instance.new("Frame")
hMask.Size            = UDim2.new(1, 0, 0, 14)
hMask.Position        = UDim2.new(0, 0, 1, -14)
hMask.BackgroundColor3 = Color3.fromRGB(40, 22, 100)
hMask.BorderSizePixel = 0
hMask.Parent          = header

local headerLbl = Instance.new("TextLabel")
headerLbl.Name                   = "HeaderLbl"
headerLbl.Size                   = UDim2.new(1, -12, 1, 0)
headerLbl.Position               = UDim2.new(0, 10, 0, 0)
headerLbl.BackgroundTransparency = 1
headerLbl.TextColor3             = Color3.fromRGB(255, 230, 60)
headerLbl.Font                   = Enum.Font.GothamBold
headerLbl.TextSize               = 15
headerLbl.TextXAlignment         = Enum.TextXAlignment.Left
headerLbl.TextYAlignment         = Enum.TextYAlignment.Center
headerLbl.Text                   = "🧊  POSE MODE"
headerLbl.Parent                 = header

-- Lock status badge
local statusBadge = Instance.new("Frame")
statusBadge.Name            = "StatusBadge"
statusBadge.Size            = UDim2.new(0, 66, 0, 22)
statusBadge.Position        = UDim2.new(1, -76, 0.5, -11)
statusBadge.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
statusBadge.BorderSizePixel = 0
statusBadge.Parent          = header
corner(statusBadge, 6)
local statusLbl = Instance.new("TextLabel")
statusLbl.Name                   = "StatusLbl"
statusLbl.Size                   = UDim2.new(1, 0, 1, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
statusLbl.Font                   = Enum.Font.GothamBold
statusLbl.TextSize               = 11
statusLbl.Text                   = "POSING"
statusLbl.Parent                 = statusBadge

-- ── Current pose row ───────────────────────────────────────────────────────

local poseNameLbl = Instance.new("TextLabel")
poseNameLbl.Name                   = "PoseName"
poseNameLbl.Size                   = UDim2.new(1, -16, 0, 26)
poseNameLbl.Position               = UDim2.new(0, 8, 0, 56)
poseNameLbl.BackgroundTransparency = 1
poseNameLbl.TextColor3             = Color3.fromRGB(220, 210, 255)
poseNameLbl.Font                   = Enum.Font.GothamBold
poseNameLbl.TextSize               = 14
poseNameLbl.TextXAlignment         = Enum.TextXAlignment.Center
poseNameLbl.Text                   = "Standing Flat"
poseNameLbl.Parent                 = panel

-- ── Prev / Next pose buttons ───────────────────────────────────────────────

local prevPoseBtn = makeBtn(panel, "◀ Prev", BLUE,
	UDim2.new(0.46, -4, 0, 30), UDim2.new(0, 8, 0, 86))
local nextPoseBtn = makeBtn(panel, "Next ▶", BLUE,
	UDim2.new(0.46, -4, 0, 30), UDim2.new(0.5, 0, 0, 86))

-- Separator
local sep = Instance.new("Frame")
sep.Size            = UDim2.new(1, -16, 0, 1)
sep.Position        = UDim2.new(0, 8, 0, 126)
sep.BackgroundColor3 = Color3.fromRGB(60, 50, 100)
sep.BorderSizePixel = 0
sep.Parent          = panel

-- Section label
local adjLbl = Instance.new("TextLabel")
adjLbl.Size                   = UDim2.new(1, -16, 0, 18)
adjLbl.Position               = UDim2.new(0, 8, 0, 133)
adjLbl.BackgroundTransparency = 1
adjLbl.TextColor3             = Color3.fromRGB(160, 150, 200)
adjLbl.Font                   = Enum.Font.GothamBold
adjLbl.TextSize               = 11
adjLbl.TextXAlignment         = Enum.TextXAlignment.Left
adjLbl.Text                   = "ADJUST POSITION"
adjLbl.Parent                 = panel

-- ── Adjustment D-pad ──────────────────────────────────────────────────────
-- Layout:          [Up]
--          [Left] [empty] [Right]
--                 [Down]
--       [Rot L]          [Rot R]

local DPAD_Y   = 156
local DPAD_BTN = UDim2.new(0, 58, 0, 38)
local COL_L    = UDim2.new(0, 8,  0, 0)
local COL_C    = UDim2.new(0.5, -29, 0, 0)
local COL_R    = UDim2.new(1, -66, 0, 0)

local btnMoveUp    = makeBtn(panel, "▲ Up",    DARK, DPAD_BTN, UDim2.new(0.5, -29, 0, DPAD_Y))
local btnMoveLeft  = makeBtn(panel, "◀ Left",  DARK, DPAD_BTN, UDim2.new(0, 8,  0, DPAD_Y + 46))
local btnMoveRight = makeBtn(panel, "Right ▶", DARK, DPAD_BTN, UDim2.new(1, -66, 0, DPAD_Y + 46))
local btnMoveDown  = makeBtn(panel, "▼ Down",  DARK, DPAD_BTN, UDim2.new(0.5, -29, 0, DPAD_Y + 46))

local DPAD_ROT_Y = DPAD_Y + 96
local btnRotL = makeBtn(panel, "↺ Rotate", DARK, DPAD_BTN, UDim2.new(0, 8,  0, DPAD_ROT_Y))
local btnRotR = makeBtn(panel, "Rotate ↻", DARK, DPAD_BTN, UDim2.new(1, -66, 0, DPAD_ROT_Y))

-- ── Lock / Cancel buttons ──────────────────────────────────────────────────

local lockBtn   = makeBtn(panel, "🔒  LOCK IN", GREEN,
	UDim2.new(1, -16, 0, 44), UDim2.new(0, 8, 0, 308))
local cancelBtn = makeBtn(panel, "✕  Cancel",   RED,
	UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 358))

-- ── Enter Pose Mode button (shown when NOT in pose mode) ──────────────────

local enterBtn = Instance.new("TextButton")
enterBtn.Name            = "EnterPoseBtn"
enterBtn.Size            = UDim2.new(0, 180, 0, 44)
enterBtn.Position        = UDim2.new(1, -192, 1, -56)
enterBtn.BackgroundColor3 = BLUE
enterBtn.BorderSizePixel = 0
enterBtn.Text            = "🧊  Enter Pose Mode  [P]"
enterBtn.Font            = Enum.Font.GothamBold
enterBtn.TextSize        = 13
enterBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
enterBtn.AutoButtonColor = false
enterBtn.Visible         = false
enterBtn.Parent          = gui
corner(enterBtn, 10)
stroke(enterBtn, Color3.fromRGB(120, 80, 220), 2)
enterBtn.MouseButton1Click:Connect(function()
	EnterPoseMode:FireServer()
end)

-- ── Update helpers ─────────────────────────────────────────────────────────

local function updatePoseLabel()
	local pose = PoseConfig.Poses[currentPoseIdx]
	poseNameLbl.Text = pose and pose.DisplayName or "Unknown"
end

local function setButtonsEnabled(enabled: boolean)
	local alpha = enabled and 0 or 0.5
	for _, btn in ipairs({
		prevPoseBtn, nextPoseBtn,
		btnMoveUp, btnMoveDown, btnMoveLeft, btnMoveRight,
		btnRotL, btnRotR, lockBtn,
	}) do
		btn.BackgroundTransparency = alpha
		btn.TextTransparency       = alpha
		btn.Active                 = enabled
	end
end

local function refreshUI()
	-- Show/hide the main panel
	local showPanel = currentRole == "Hider"
		and (currentPhase == "Paint" or currentPhase == "PoseLock")
		and isInPoseMode

	panel.Visible = showPanel

	-- Show enter button when hider is NOT in pose mode
	local showEnter = currentRole == "Hider"
		and (currentPhase == "Paint" or currentPhase == "PoseLock")
		and not isInPoseMode
		and not isFrozen

	enterBtn.Visible = showEnter

	-- Enable/disable adjustment buttons based on lock state
	if showPanel then
		setButtonsEnabled(not isLocked and not isFrozen)
		lockBtn.Visible   = not isLocked
		cancelBtn.Visible = not isLocked

		if isLocked then
			statusBadge.BackgroundColor3 = Color3.fromRGB(200, 140, 0)
			statusLbl.Text               = "LOCKED"
			headerLbl.Text               = "🔒  POSE LOCKED"
		elseif isFrozen then
			statusBadge.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			statusLbl.Text               = "FROZEN"
			headerLbl.Text               = "❄  SEEKING..."
		else
			statusBadge.BackgroundColor3 = Color3.fromRGB(30, 130, 60)
			statusLbl.Text               = "POSING"
			headerLbl.Text               = "🧊  POSE MODE"
		end

		updatePoseLabel()
	end

	gui.Enabled = showPanel or showEnter
end

-- ── Button wiring ──────────────────────────────────────────────────────────

prevPoseBtn.MouseButton1Click:Connect(function()
	if isLocked or isFrozen then return end
	currentPoseIdx = ((currentPoseIdx - 2) % #PoseConfig.Poses) + 1
	local pose = PoseConfig.Poses[currentPoseIdx]
	if pose then ChangePose:FireServer(pose.PoseId) end
end)

nextPoseBtn.MouseButton1Click:Connect(function()
	if isLocked or isFrozen then return end
	currentPoseIdx = (currentPoseIdx % #PoseConfig.Poses) + 1
	local pose = PoseConfig.Poses[currentPoseIdx]
	if pose then ChangePose:FireServer(pose.PoseId) end
end)

btnMoveUp.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then AdjustPosePosition:FireServer("MoveUp")    end
end)
btnMoveDown.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then AdjustPosePosition:FireServer("MoveDown")  end
end)
btnMoveLeft.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then AdjustPosePosition:FireServer("MoveLeft")  end
end)
btnMoveRight.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then AdjustPosePosition:FireServer("MoveRight") end
end)
btnRotL.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then AdjustPosePosition:FireServer("RotateLeft")  end
end)
btnRotR.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then AdjustPosePosition:FireServer("RotateRight") end
end)

lockBtn.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then LockPose:FireServer() end
end)
cancelBtn.MouseButton1Click:Connect(function()
	if not isLocked and not isFrozen then ExitPoseMode:FireServer() end
end)

-- ── Remote listeners ───────────────────────────────────────────────────────

RoleAssigned.OnClientEvent:Connect(function(role: string)
	currentRole    = role
	isInPoseMode   = false
	isLocked       = false
	isFrozen       = false
	currentPoseIdx = 1
	refreshUI()
end)

RoundStateChanged.OnClientEvent:Connect(function(phase: string)
	currentPhase = phase
	if phase ~= "Paint" and phase ~= "PoseLock" then
		isInPoseMode = false
	end
	refreshUI()
end)

PoseModeUpdated.OnClientEvent:Connect(function(state: {
	poseId:       string,
	isInPoseMode: boolean,
	isLocked:     boolean,
	isFrozen:     boolean,
})
	isInPoseMode = state.isInPoseMode
	isLocked     = state.isLocked
	isFrozen     = state.isFrozen

	-- Sync pose index to confirmed server pose
	if state.poseId and state.poseId ~= "" then
		for i, pose in ipairs(PoseConfig.Poses) do
			if pose.PoseId == state.poseId then
				currentPoseIdx = i
				break
			end
		end
	end

	refreshUI()
end)
