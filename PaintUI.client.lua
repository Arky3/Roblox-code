-- PaintUI.client.lua
-- LocalScript for Blend Game: lets Hiders paint their character during the Paint phase.
-- Place inside StarterPlayerScripts (or StarterCharacterScripts won't work; use StarterPlayerScripts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── Remotes ────────────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("BlendGameRemotes", 10)
assert(remotesFolder, "[PaintUI] BlendGameRemotes folder not found in ReplicatedStorage")

local PhaseChanged   = remotesFolder:WaitForChild("PhaseChanged",   10)
local RoleAssigned   = remotesFolder:WaitForChild("RoleAssigned",   10)
local PaintSubmitted = remotesFolder:WaitForChild("PaintSubmitted",  10)

-- ── State ──────────────────────────────────────────────────────────────────
local currentRole   = nil   -- "Hider" | "Seeker"
local selectedColor = Color3.fromRGB(255, 255, 255)
local bodyColors    = {
	Head     = Color3.fromRGB(255, 255, 255),
	Torso    = Color3.fromRGB(255, 255, 255),
	LeftArm  = Color3.fromRGB(255, 255, 255),
	RightArm = Color3.fromRGB(255, 255, 255),
	LeftLeg  = Color3.fromRGB(255, 255, 255),
	RightLeg = Color3.fromRGB(255, 255, 255),
}
local paintPhaseEndsAt = 0
local timerConnection  = nil
local submitted        = false

-- ── Palette ────────────────────────────────────────────────────────────────
local PALETTE = {
	Color3.fromRGB(255,  80,  80),  -- Red
	Color3.fromRGB(255, 160,  40),  -- Orange
	Color3.fromRGB(255, 230,  40),  -- Yellow
	Color3.fromRGB( 80, 200,  80),  -- Green
	Color3.fromRGB( 40, 180, 200),  -- Cyan
	Color3.fromRGB( 60, 100, 240),  -- Blue
	Color3.fromRGB(160,  60, 240),  -- Purple
	Color3.fromRGB(240,  80, 180),  -- Pink
	Color3.fromRGB(180, 120,  60),  -- Brown
	Color3.fromRGB(255, 255, 255),  -- White
	Color3.fromRGB(160, 160, 160),  -- Gray
	Color3.fromRGB( 20,  20,  20),  -- Black
	Color3.fromRGB(100, 220, 140),  -- Mint
	Color3.fromRGB(255, 200, 100),  -- Peach
	Color3.fromRGB( 40,  60,  80),  -- Dark Blue
	Color3.fromRGB(200, 255, 120),  -- Lime
}

-- ── Build GUI ──────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "PaintUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled      = false
screenGui.DisplayOrder = 10
screenGui.Parent       = playerGui

-- Main container
local mainFrame = Instance.new("Frame")
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(0, 620, 0, 520)
mainFrame.Position        = UDim2.new(0.5, -310, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
mainFrame.BorderSizePixel = 0
mainFrame.Parent          = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent       = mainFrame

-- Gradient stripe at the top
local headerFrame = Instance.new("Frame")
headerFrame.Name              = "Header"
headerFrame.Size              = UDim2.new(1, 0, 0, 56)
headerFrame.BackgroundColor3  = Color3.fromRGB(50, 30, 120)
headerFrame.BorderSizePixel   = 0
headerFrame.Parent            = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent       = headerFrame

-- Cover bottom corners of header
local headerFix = Instance.new("Frame")
headerFix.Size              = UDim2.new(1, 0, 0, 14)
headerFix.Position          = UDim2.new(0, 0, 1, -14)
headerFix.BackgroundColor3  = Color3.fromRGB(50, 30, 120)
headerFix.BorderSizePixel   = 0
headerFix.Parent            = headerFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, -120, 1, 0)
titleLabel.Position          = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3        = Color3.fromRGB(255, 230, 60)
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 22
titleLabel.TextXAlignment    = Enum.TextXAlignment.Left
titleLabel.TextYAlignment    = Enum.TextYAlignment.Center
titleLabel.Text              = "🎨  PAINT PHASE — BLEND IN!"
titleLabel.Parent            = headerFrame

-- Timer label (top-right of header)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name              = "Timer"
timerLabel.Size              = UDim2.new(0, 100, 1, 0)
timerLabel.Position          = UDim2.new(1, -110, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3        = Color3.fromRGB(255, 100, 100)
timerLabel.Font              = Enum.Font.GothamBold
timerLabel.TextSize          = 20
timerLabel.TextXAlignment    = Enum.TextXAlignment.Right
timerLabel.TextYAlignment    = Enum.TextYAlignment.Center
timerLabel.Text              = "0:00"
timerLabel.Parent            = headerFrame

-- ── Paper-doll layout ──────────────────────────────────────────────────────
-- Positions are relative to a 200×380 canvas centered in the frame

local dollCanvas = Instance.new("Frame")
dollCanvas.Name              = "DollCanvas"
dollCanvas.Size              = UDim2.new(0, 200, 0, 380)
dollCanvas.Position          = UDim2.new(0, 20, 0, 70)
dollCanvas.BackgroundTransparency = 1
dollCanvas.Parent            = mainFrame

-- Part name → { x, y, w, h } in pixels within dollCanvas
local PART_LAYOUT = {
	Head     = { x = 60,  y = 0,   w = 80,  h = 80  },
	Torso    = { x = 30,  y = 88,  w = 140, h = 130 },
	LeftArm  = { x = 0,   y = 88,  w = 26,  h = 120 },
	RightArm = { x = 174, y = 88,  w = 26,  h = 120 },
	LeftLeg  = { x = 40,  y = 226, w = 55,  h = 130 },
	RightLeg = { x = 105, y = 226, w = 55,  h = 130 },
}

local bodyPartButtons = {}

local function makePartButton(partName, layout)
	local btn = Instance.new("TextButton")
	btn.Name              = partName
	btn.Size              = UDim2.new(0, layout.w, 0, layout.h)
	btn.Position          = UDim2.new(0, layout.x, 0, layout.y)
	btn.BackgroundColor3  = bodyColors[partName]
	btn.BorderSizePixel   = 3
	btn.BorderColor3      = Color3.fromRGB(80, 80, 120)
	btn.Text              = partName
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 11
	btn.TextColor3        = Color3.fromRGB(0, 0, 0)
	btn.TextWrapped       = true
	btn.AutoButtonColor   = false
	btn.Parent            = dollCanvas

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = btn

	btn.MouseButton1Click:Connect(function()
		bodyColors[partName]   = selectedColor
		btn.BackgroundColor3   = selectedColor
		-- Use contrasting text color
		local brightness = selectedColor.R * 0.299 + selectedColor.G * 0.587 + selectedColor.B * 0.114
		btn.TextColor3 = brightness > 0.5 and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255)
	end)

	bodyPartButtons[partName] = btn
end

for partName, layout in pairs(PART_LAYOUT) do
	makePartButton(partName, layout)
end

-- ── Right panel ────────────────────────────────────────────────────────────
local rightPanel = Instance.new("Frame")
rightPanel.Name              = "RightPanel"
rightPanel.Size              = UDim2.new(0, 360, 0, 440)
rightPanel.Position          = UDim2.new(0, 240, 0, 66)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent            = mainFrame

-- Selected color preview
local previewLabel = Instance.new("TextLabel")
previewLabel.Name              = "PreviewLabel"
previewLabel.Size              = UDim2.new(1, 0, 0, 20)
previewLabel.Position          = UDim2.new(0, 0, 0, 0)
previewLabel.BackgroundTransparency = 1
previewLabel.TextColor3        = Color3.fromRGB(200, 200, 220)
previewLabel.Font              = Enum.Font.GothamBold
previewLabel.TextSize          = 14
previewLabel.TextXAlignment    = Enum.TextXAlignment.Left
previewLabel.Text              = "SELECTED COLOR"
previewLabel.Parent            = rightPanel

local colorPreview = Instance.new("Frame")
colorPreview.Name              = "ColorPreview"
colorPreview.Size              = UDim2.new(1, 0, 0, 36)
colorPreview.Position          = UDim2.new(0, 0, 0, 24)
colorPreview.BackgroundColor3  = selectedColor
colorPreview.BorderSizePixel   = 0
colorPreview.Parent            = rightPanel

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 8)
previewCorner.Parent       = colorPreview

local previewBorder = Instance.new("UIStroke")
previewBorder.Color     = Color3.fromRGB(255, 230, 60)
previewBorder.Thickness = 2
previewBorder.Parent    = colorPreview

-- Palette label
local paletteLabel = Instance.new("TextLabel")
paletteLabel.Name              = "PaletteLabel"
paletteLabel.Size              = UDim2.new(1, 0, 0, 20)
paletteLabel.Position          = UDim2.new(0, 0, 0, 68)
paletteLabel.BackgroundTransparency = 1
paletteLabel.TextColor3        = Color3.fromRGB(200, 200, 220)
paletteLabel.Font              = Enum.Font.GothamBold
paletteLabel.TextSize          = 14
paletteLabel.TextXAlignment    = Enum.TextXAlignment.Left
paletteLabel.Text              = "COLOR PALETTE"
paletteLabel.Parent            = rightPanel

-- Palette grid
local paletteGrid = Instance.new("Frame")
paletteGrid.Name              = "PaletteGrid"
paletteGrid.Size              = UDim2.new(1, 0, 0, 180)
paletteGrid.Position          = UDim2.new(0, 0, 0, 92)
paletteGrid.BackgroundTransparency = 1
paletteGrid.Parent            = rightPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize       = UDim2.new(0, 40, 0, 40)
gridLayout.CellPadding    = UDim2.new(0, 6, 0, 6)
gridLayout.SortOrder      = Enum.SortOrder.LayoutOrder
gridLayout.FillDirection  = Enum.FillDirection.Horizontal
gridLayout.Parent         = paletteGrid

local swatchButtons = {}

local function selectSwatch(color)
	selectedColor = color
	colorPreview.BackgroundColor3 = color
end

for i, color in ipairs(PALETTE) do
	local swatch = Instance.new("TextButton")
	swatch.Name             = "Swatch_" .. i
	swatch.Size             = UDim2.new(0, 40, 0, 40)
	swatch.BackgroundColor3 = color
	swatch.BorderSizePixel  = 0
	swatch.Text             = ""
	swatch.AutoButtonColor  = false
	swatch.LayoutOrder      = i
	swatch.Parent           = paletteGrid

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 6)
	sc.Parent       = swatch

	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(80, 80, 120)
	stroke.Thickness = 2
	stroke.Parent    = swatch

	swatch.MouseButton1Click:Connect(function()
		selectSwatch(color)
		-- Highlight selected swatch
		for _, s in ipairs(swatchButtons) do
			local st = s:FindFirstChildOfClass("UIStroke")
			if st then st.Color = Color3.fromRGB(80, 80, 120); st.Thickness = 2 end
		end
		stroke.Color     = Color3.fromRGB(255, 230, 60)
		stroke.Thickness = 3
	end)

	table.insert(swatchButtons, swatch)
end

-- Tip text
local tipLabel = Instance.new("TextLabel")
tipLabel.Name              = "Tip"
tipLabel.Size              = UDim2.new(1, 0, 0, 36)
tipLabel.Position          = UDim2.new(0, 0, 0, 280)
tipLabel.BackgroundColor3  = Color3.fromRGB(30, 30, 50)
tipLabel.BorderSizePixel   = 0
tipLabel.TextColor3        = Color3.fromRGB(160, 160, 200)
tipLabel.Font              = Enum.Font.Gotham
tipLabel.TextSize          = 12
tipLabel.TextWrapped        = true
tipLabel.Text              = "Click a palette color → then click a body part to paint it."
tipLabel.Parent            = rightPanel

local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 8)
tipCorner.Parent       = tipLabel

-- Submit button
local submitBtn = Instance.new("TextButton")
submitBtn.Name             = "SubmitButton"
submitBtn.Size             = UDim2.new(1, 0, 0, 50)
submitBtn.Position         = UDim2.new(0, 0, 0, 326)
submitBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
submitBtn.BorderSizePixel  = 0
submitBtn.Text             = "✔  SUBMIT DISGUISE"
submitBtn.Font             = Enum.Font.GothamBold
submitBtn.TextSize         = 18
submitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
submitBtn.AutoButtonColor  = false
submitBtn.Parent           = rightPanel

local submitCorner = Instance.new("UICorner")
submitCorner.CornerRadius = UDim.new(0, 10)
submitCorner.Parent       = submitBtn

-- Submit hover effect
submitBtn.MouseEnter:Connect(function()
	submitBtn.BackgroundColor3 = Color3.fromRGB(50, 220, 120)
end)
submitBtn.MouseLeave:Connect(function()
	submitBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
end)

-- ── Helpers ────────────────────────────────────────────────────────────────
local function resetBodyColors()
	local white = Color3.fromRGB(255, 255, 255)
	for partName, btn in pairs(bodyPartButtons) do
		bodyColors[partName]  = white
		btn.BackgroundColor3  = white
		btn.TextColor3        = Color3.fromRGB(0, 0, 0)
	end
end

local function closeUI()
	screenGui.Enabled = false
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
end

local function submitPaint()
	if submitted then return end
	submitted = true

	PaintSubmitted:FireServer({ bodyColors = bodyColors })
	closeUI()
end

submitBtn.MouseButton1Click:Connect(submitPaint)

-- ── Timer ──────────────────────────────────────────────────────────────────
local function startTimer(endsAt)
	if timerConnection then timerConnection:Disconnect() end

	timerConnection = RunService.Heartbeat:Connect(function()
		local remaining = endsAt - workspace:GetServerTimeNow()
		if remaining <= 0 then
			timerLabel.Text = "0:00"
			timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
			submitPaint()
			return
		end

		local secs = math.floor(remaining)
		local mins = math.floor(secs / 60)
		local s    = secs % 60
		timerLabel.Text = string.format("%d:%02d", mins, s)

		-- Color shift as time runs low
		if remaining <= 10 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
		elseif remaining <= 30 then
			timerLabel.TextColor3 = Color3.fromRGB(255, 180, 40)
		else
			timerLabel.TextColor3 = Color3.fromRGB(100, 240, 140)
		end
	end)
end

-- ── Phase / Role listeners ─────────────────────────────────────────────────
RoleAssigned.OnClientEvent:Connect(function(role)
	currentRole = role
end)

PhaseChanged.OnClientEvent:Connect(function(phase, duration, endsAt, roundId)
	if phase == "Paint" then
		if currentRole ~= "Hider" then
			closeUI()
			return
		end

		submitted          = false
		paintPhaseEndsAt   = endsAt

		resetBodyColors()
		screenGui.Enabled  = true
		startTimer(endsAt)
	else
		-- Any phase other than Paint closes the UI
		closeUI()
	end
end)
