-- HiderController: LocalScript in StarterPlayer/StarterPlayerScripts
-- Manages the Pose Selection UI shown to hiders during the PoseLock phase.
-- Movement lock is applied server-side by PoseService; this only handles the UI.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

local Remotes           = ReplicatedStorage:WaitForChild("Remotes",  30)
local Modules           = ReplicatedStorage:WaitForChild("Modules",  30)
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged")  :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")       :: RemoteEvent
local SetPose           = Remotes:WaitForChild("SetPose")            :: RemoteEvent

local RoundConfig = require(Modules:WaitForChild("RoundConfig"))

-- ── State ──────────────────────────────────────────────────────────────────
local currentRole = "Spectator"
local poseSent    = false
local timerConn: RBXScriptConnection? = nil

-- ── Build Pose GUI ─────────────────────────────────────────────────────────

local poseGui = Instance.new("ScreenGui")
poseGui.Name         = "PoseGui"
poseGui.ResetOnSpawn = false
poseGui.Enabled      = false
poseGui.DisplayOrder = 9
poseGui.Parent       = playerGui

-- ── Container ──────────────────────────────────────────────────────────────
local poseFrame = Instance.new("Frame")
poseFrame.Name              = "PoseFrame"
poseFrame.Size              = UDim2.new(0, 360, 0, 320)
poseFrame.Position          = UDim2.new(0.5, -180, 0.5, -160)
poseFrame.BackgroundColor3  = Color3.fromRGB(18, 18, 28)
poseFrame.BorderSizePixel   = 0
poseFrame.ClipsDescendants  = true
poseFrame.Parent            = poseGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 14)
fCorner.Parent       = poseFrame

-- Header bar
local header = Instance.new("Frame")
header.Name            = "Header"
header.Size            = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = Color3.fromRGB(50, 30, 120)
header.BorderSizePixel = 0
header.Parent          = poseFrame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 14)
hCorner.Parent       = header

local hFix = Instance.new("Frame")  -- Mask rounded bottom corners of header
hFix.Size             = UDim2.new(1, 0, 0, 14)
hFix.Position         = UDim2.new(0, 0, 1, -14)
hFix.BackgroundColor3 = Color3.fromRGB(50, 30, 120)
hFix.BorderSizePixel  = 0
hFix.Parent           = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(1, -100, 1, 0)
titleLbl.Position               = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3             = Color3.fromRGB(255, 230, 60)
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextSize               = 18
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.TextYAlignment         = Enum.TextYAlignment.Center
titleLbl.Text                   = "🧊  CHOOSE YOUR POSE"
titleLbl.Parent                 = header

local timerLbl = Instance.new("TextLabel")
timerLbl.Name                   = "Timer"
timerLbl.Size                   = UDim2.new(0, 80, 1, 0)
timerLbl.Position               = UDim2.new(1, -90, 0, 0)
timerLbl.BackgroundTransparency = 1
timerLbl.TextColor3             = Color3.fromRGB(100, 240, 140)
timerLbl.Font                   = Enum.Font.GothamBold
timerLbl.TextSize               = 20
timerLbl.TextXAlignment         = Enum.TextXAlignment.Right
timerLbl.TextYAlignment         = Enum.TextYAlignment.Center
timerLbl.Text                   = "0:15"
timerLbl.Parent                 = header

-- Scrollable pose list
local scroll = Instance.new("ScrollingFrame")
scroll.Name                  = "PoseScroll"
scroll.Size                  = UDim2.new(1, -20, 1, -72)
scroll.Position              = UDim2.new(0, 10, 0, 62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel       = 0
scroll.ScrollBarThickness    = 6
scroll.ScrollBarImageColor3  = Color3.fromRGB(130, 80, 220)
scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
scroll.Parent                = poseFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding    = UDim.new(0, 8)
listLayout.SortOrder  = Enum.SortOrder.LayoutOrder
listLayout.Parent     = scroll

-- Auto-resize canvas
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end)

-- ── Pose button factory ────────────────────────────────────────────────────

local function sendPose(index: number)
	if poseSent then return end
	poseSent = true

	SetPose:FireServer(index)
	poseGui.Enabled = false

	if timerConn then timerConn:Disconnect(); timerConn = nil end
end

for i, pose in ipairs(RoundConfig.POSES) do
	local btn = Instance.new("TextButton")
	btn.Name             = "Pose_" .. i
	btn.Size             = UDim2.new(1, 0, 0, 48)
	btn.BackgroundColor3 = Color3.fromRGB(40, 28, 90)
	btn.BorderSizePixel  = 0
	btn.Text             = pose.name
	btn.Font             = Enum.Font.GothamBold
	btn.TextSize         = 16
	btn.TextColor3       = Color3.fromRGB(230, 220, 255)
	btn.AutoButtonColor  = false
	btn.LayoutOrder      = i
	btn.Parent           = scroll

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent       = btn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color     = Color3.fromRGB(80, 50, 160)
	btnStroke.Thickness = 1
	btnStroke.Parent    = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(80, 50, 180)
		btnStroke.Color      = Color3.fromRGB(180, 130, 255)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(40, 28, 90)
		btnStroke.Color      = Color3.fromRGB(80, 50, 160)
	end)
	btn.MouseButton1Click:Connect(function()
		sendPose(i)
	end)
end

-- ── Phase listener ─────────────────────────────────────────────────────────

RoleAssigned.OnClientEvent:Connect(function(role: string)
	currentRole = role
	poseSent    = false
end)

RoundStateChanged.OnClientEvent:Connect(function(
	phase: string,
	_duration: number,
	endsAt: number,
	_roundId: number
)
	if phase == "PoseLock" then
		if currentRole ~= "Hider" then
			poseGui.Enabled = false
			return
		end

		poseSent        = false
		poseGui.Enabled = true

		-- Countdown ticker
		if timerConn then timerConn:Disconnect() end
		timerConn = RunService.Heartbeat:Connect(function()
			local rem = endsAt - workspace:GetServerTimeNow()
			if rem <= 0 then
				timerLbl.Text       = "0:00"
				timerLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
				if timerConn then timerConn:Disconnect(); timerConn = nil end
				if not poseSent then sendPose(1) end  -- Auto-submit default pose
				return
			end

			local secs = math.ceil(rem)
			timerLbl.Text = string.format("0:%02d", secs)
			timerLbl.TextColor3 = rem <= 5
				and Color3.fromRGB(255, 60, 60)
				or  Color3.fromRGB(100, 240, 140)
		end)
	else
		poseGui.Enabled = false
		if timerConn then timerConn:Disconnect(); timerConn = nil end
	end
end)
