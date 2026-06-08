-- PaintGui: LocalScript in StarterGui
-- Full paint UI for hiders during the Paint phase.
-- Paint is submitted ONCE (on submit or timer expiry), not per stroke.
--
-- TODO (future): Replace flat Color3 fills with EditableImage painting.
--   Each body-part button can host a SurfaceAppearance driven by an
--   EditableImage. Add a brush-size picker here and stream cell data
--   to PaintSubmitted as a grid table instead of a flat Color3 map.
--
-- TODO (future): Add pattern stamps — pre-made textures the player
--   can overlay on a body part (leaves, bark, brick, etc.) for camouflage.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── Remotes & config ───────────────────────────────────────────────────────
local Remotes           = ReplicatedStorage:WaitForChild("Remotes", 30)
local Modules           = ReplicatedStorage:WaitForChild("Modules", 30)
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")      :: RemoteEvent
local PaintSubmitted    = Remotes:WaitForChild("PaintSubmitted")    :: RemoteEvent
local RoundConfig       = require(Modules:WaitForChild("RoundConfig"))

-- ── State ──────────────────────────────────────────────────────────────────
local currentRole    = "Spectator"
local selectedColor  = Color3.fromRGB(255, 255, 255)
local bodyColors: { [string]: Color3 } = {}
local submitted      = false
local timerConn: RBXScriptConnection? = nil

local WHITE = Color3.fromRGB(255, 255, 255)

local function resetBodyColors()
	for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
		bodyColors[partName] = WHITE
	end
end
resetBodyColors()

-- ── GUI construction ───────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "PaintGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled      = false
screenGui.DisplayOrder = 10
screenGui.Parent       = playerGui

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Returns black or white depending on background brightness (WCAG contrast)
local function contrastColor(bg: Color3): Color3
	local lum = bg.R * 0.299 + bg.G * 0.587 + bg.B * 0.114
	return lum > 0.55 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
end

local function makeCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent       = parent
	return c
end

local function makeStroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color     = color
	s.Thickness = thickness
	s.Parent    = parent
	return s
end

-- ── Root frame ────────────────────────────────────────────────────────────

local root = Instance.new("Frame")
root.Name              = "Root"
root.Size              = UDim2.new(0, 680, 0, 540)
root.Position          = UDim2.new(0.5, -340, 0.5, -270)
root.BackgroundColor3  = Color3.fromRGB(15, 15, 24)
root.BorderSizePixel   = 0
root.Parent            = screenGui
makeCorner(root, 16)
makeStroke(root, Color3.fromRGB(70, 40, 160), 2)

-- ── Header bar ────────────────────────────────────────────────────────────

local header = Instance.new("Frame")
header.Name            = "Header"
header.Size            = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3 = Color3.fromRGB(45, 25, 110)
header.BorderSizePixel = 0
header.Parent          = root
makeCorner(header, 16)

-- Mask bottom-rounded corners of header so it flush-connects to body
local headerMask = Instance.new("Frame")
headerMask.Size            = UDim2.new(1, 0, 0, 16)
headerMask.Position        = UDim2.new(0, 0, 1, -16)
headerMask.BackgroundColor3 = Color3.fromRGB(45, 25, 110)
headerMask.BorderSizePixel = 0
headerMask.Parent          = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(1, -130, 1, 0)
titleLbl.Position               = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3             = Color3.fromRGB(255, 230, 60)
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextSize               = 20
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.TextYAlignment         = Enum.TextYAlignment.Center
titleLbl.Text                   = "🎨  PAINT PHASE — BLEND IN!"
titleLbl.Parent                 = header

local timerLbl = Instance.new("TextLabel")
timerLbl.Name                   = "Timer"
timerLbl.Size                   = UDim2.new(0, 110, 1, 0)
timerLbl.Position               = UDim2.new(1, -118, 0, 0)
timerLbl.BackgroundTransparency = 1
timerLbl.TextColor3             = Color3.fromRGB(100, 240, 140)
timerLbl.Font                   = Enum.Font.GothamBold
timerLbl.TextSize               = 22
timerLbl.TextXAlignment         = Enum.TextXAlignment.Right
timerLbl.TextYAlignment         = Enum.TextYAlignment.Center
timerLbl.Text                   = "1:00"
timerLbl.Parent                 = header

-- ── Left panel: paper doll ────────────────────────────────────────────────

local dollCanvas = Instance.new("Frame")
dollCanvas.Name              = "DollCanvas"
dollCanvas.Size              = UDim2.new(0, 210, 0, 420)
dollCanvas.Position          = UDim2.new(0, 20, 0, 72)
dollCanvas.BackgroundTransparency = 1
dollCanvas.Parent            = root

--[[
	Body-part layout within the 210×420 doll canvas.
	Coordinates chosen to look like a blocky Roblox character silhouette.
	{ x, y, w, h } in pixels.
]]
local PART_LAYOUT = {
	Head     = { x = 65,  y = 0,   w = 80,  h = 80  },
	Torso    = { x = 35,  y = 88,  w = 140, h = 140 },
	LeftArm  = { x = 0,   y = 88,  w = 32,  h = 130 },
	RightArm = { x = 178, y = 88,  w = 32,  h = 130 },
	LeftLeg  = { x = 45,  y = 236, w = 58,  h = 140 },
	RightLeg = { x = 107, y = 236, w = 58,  h = 140 },
}

-- { [partName]: TextButton }
local partButtons: { [string]: TextButton } = {}

local function paintPart(partName: string, color: Color3)
	bodyColors[partName] = color
	local btn = partButtons[partName]
	if btn then
		btn.BackgroundColor3 = color
		btn.TextColor3       = contrastColor(color)
	end
end

for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
	local layout = PART_LAYOUT[partName]
	if not layout then continue end

	local btn = Instance.new("TextButton") :: TextButton
	btn.Name              = partName
	btn.Size              = UDim2.new(0, layout.w, 0, layout.h)
	btn.Position          = UDim2.new(0, layout.x, 0, layout.y)
	btn.BackgroundColor3  = WHITE
	btn.BorderSizePixel   = 0
	btn.Text              = partName
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 11
	btn.TextColor3        = Color3.new(0, 0, 0)
	btn.TextWrapped       = true
	btn.AutoButtonColor   = false
	btn.Parent            = dollCanvas

	makeCorner(btn, 8)
	makeStroke(btn, Color3.fromRGB(90, 60, 180), 2)

	-- Hover highlight
	btn.MouseEnter:Connect(function()
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color     = Color3.fromRGB(255, 230, 60)
			stroke.Thickness = 3
		end
	end)
	btn.MouseLeave:Connect(function()
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color     = Color3.fromRGB(90, 60, 180)
			stroke.Thickness = 2
		end
	end)

	btn.MouseButton1Click:Connect(function()
		paintPart(partName, selectedColor)
	end)

	partButtons[partName] = btn
end

-- ── Right panel ────────────────────────────────────────────────────────────

local rightPanel = Instance.new("Frame")
rightPanel.Name              = "RightPanel"
rightPanel.Size              = UDim2.new(0, 400, 0, 460)
rightPanel.Position          = UDim2.new(0, 250, 0, 66)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent            = root

-- ── Color preview strip ────────────────────────────────────────────────────

local previewHeader = Instance.new("TextLabel")
previewHeader.Size                   = UDim2.new(1, 0, 0, 18)
previewHeader.BackgroundTransparency = 1
previewHeader.TextColor3             = Color3.fromRGB(180, 170, 210)
previewHeader.Font                   = Enum.Font.GothamBold
previewHeader.TextSize               = 12
previewHeader.TextXAlignment         = Enum.TextXAlignment.Left
previewHeader.Text                   = "SELECTED COLOR"
previewHeader.Parent                 = rightPanel

local colorPreview = Instance.new("Frame")
colorPreview.Name            = "ColorPreview"
colorPreview.Size            = UDim2.new(1, 0, 0, 38)
colorPreview.Position        = UDim2.new(0, 0, 0, 22)
colorPreview.BackgroundColor3 = selectedColor
colorPreview.BorderSizePixel = 0
colorPreview.Parent          = rightPanel
makeCorner(colorPreview, 8)

local previewStroke = makeStroke(colorPreview, Color3.fromRGB(255, 230, 60), 2)

-- ── Palette ────────────────────────────────────────────────────────────────

local paletteHeader = Instance.new("TextLabel")
paletteHeader.Size                   = UDim2.new(1, 0, 0, 18)
paletteHeader.Position               = UDim2.new(0, 0, 0, 68)
paletteHeader.BackgroundTransparency = 1
paletteHeader.TextColor3             = Color3.fromRGB(180, 170, 210)
paletteHeader.Font                   = Enum.Font.GothamBold
paletteHeader.TextSize               = 12
paletteHeader.TextXAlignment         = Enum.TextXAlignment.Left
paletteHeader.Text                   = "COLOR PALETTE"
paletteHeader.Parent                 = rightPanel

local paletteGrid = Instance.new("Frame")
paletteGrid.Name              = "Palette"
paletteGrid.Size              = UDim2.new(1, 0, 0, 200)
paletteGrid.Position          = UDim2.new(0, 0, 0, 90)
paletteGrid.BackgroundTransparency = 1
paletteGrid.Parent            = rightPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize      = UDim2.new(0, 44, 0, 44)
gridLayout.CellPadding   = UDim2.new(0, 6, 0, 6)
gridLayout.SortOrder     = Enum.SortOrder.LayoutOrder
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.Parent        = paletteGrid

-- Track which swatch is active so we can un-highlight it
local activeSwatchStroke: UIStroke? = nil

local function selectColor(color: Color3, stroke: UIStroke)
	selectedColor = color
	colorPreview.BackgroundColor3 = color
	previewStroke.Color = contrastColor(color)

	if activeSwatchStroke and activeSwatchStroke ~= stroke then
		activeSwatchStroke.Color     = Color3.fromRGB(60, 50, 100)
		activeSwatchStroke.Thickness = 1
	end
	stroke.Color     = Color3.fromRGB(255, 230, 60)
	stroke.Thickness = 3
	activeSwatchStroke = stroke
end

for i, color in ipairs(RoundConfig.PALETTE) do
	local swatch = Instance.new("TextButton")
	swatch.Name             = "Swatch_" .. i
	swatch.Size             = UDim2.new(0, 44, 0, 44)
	swatch.BackgroundColor3 = color
	swatch.BorderSizePixel  = 0
	swatch.Text             = ""
	swatch.AutoButtonColor  = false
	swatch.LayoutOrder      = i
	swatch.Parent           = paletteGrid
	makeCorner(swatch, 7)
	local st = makeStroke(swatch, Color3.fromRGB(60, 50, 100), 1)

	swatch.MouseButton1Click:Connect(function()
		selectColor(color, st)
	end)
end

-- Select white by default on first open
do
	local firstStroke = paletteGrid:FindFirstChild("Swatch_10")
		and paletteGrid.Swatch_10:FindFirstChildOfClass("UIStroke")
	if firstStroke then
		activeSwatchStroke          = firstStroke
		firstStroke.Color           = Color3.fromRGB(255, 230, 60)
		firstStroke.Thickness       = 3
	end
end

-- ── Tip label ─────────────────────────────────────────────────────────────

local tipLbl = Instance.new("TextLabel")
tipLbl.Size              = UDim2.new(1, 0, 0, 36)
tipLbl.Position          = UDim2.new(0, 0, 0, 300)
tipLbl.BackgroundColor3  = Color3.fromRGB(28, 22, 50)
tipLbl.BorderSizePixel   = 0
tipLbl.TextColor3        = Color3.fromRGB(160, 150, 200)
tipLbl.Font              = Enum.Font.Gotham
tipLbl.TextSize          = 12
tipLbl.TextWrapped       = true
tipLbl.Text              = "Pick a color → click a body part to paint it."
tipLbl.Parent            = rightPanel
makeCorner(tipLbl, 8)

-- ── Fill All button ────────────────────────────────────────────────────────

local fillAllBtn = Instance.new("TextButton")
fillAllBtn.Name            = "FillAll"
fillAllBtn.Size            = UDim2.new(0.48, -4, 0, 46)
fillAllBtn.Position        = UDim2.new(0, 0, 0, 346)
fillAllBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 140)
fillAllBtn.BorderSizePixel = 0
fillAllBtn.Text            = "Paint All"
fillAllBtn.Font            = Enum.Font.GothamBold
fillAllBtn.TextSize        = 15
fillAllBtn.TextColor3      = Color3.fromRGB(220, 210, 255)
fillAllBtn.AutoButtonColor = false
fillAllBtn.Parent          = rightPanel
makeCorner(fillAllBtn, 10)

fillAllBtn.MouseEnter:Connect(function()
	fillAllBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
end)
fillAllBtn.MouseLeave:Connect(function()
	fillAllBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 140)
end)
fillAllBtn.MouseButton1Click:Connect(function()
	for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
		paintPart(partName, selectedColor)
	end
end)

-- ── Submit button ──────────────────────────────────────────────────────────

local submitBtn = Instance.new("TextButton")
submitBtn.Name            = "Submit"
submitBtn.Size            = UDim2.new(0.52, -4, 0, 46)
submitBtn.Position        = UDim2.new(0.48, 4, 0, 346)
submitBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 90)
submitBtn.BorderSizePixel = 0
submitBtn.Text            = "✔  SUBMIT"
submitBtn.Font            = Enum.Font.GothamBold
submitBtn.TextSize        = 17
submitBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
submitBtn.AutoButtonColor = false
submitBtn.Parent          = rightPanel
makeCorner(submitBtn, 10)

submitBtn.MouseEnter:Connect(function()
	submitBtn.BackgroundColor3 = Color3.fromRGB(40, 210, 110)
end)
submitBtn.MouseLeave:Connect(function()
	submitBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 90)
end)

-- ── Reset button ───────────────────────────────────────────────────────────

local resetBtn = Instance.new("TextButton")
resetBtn.Name            = "Reset"
resetBtn.Size            = UDim2.new(1, 0, 0, 34)
resetBtn.Position        = UDim2.new(0, 0, 0, 402)
resetBtn.BackgroundColor3 = Color3.fromRGB(35, 25, 70)
resetBtn.BorderSizePixel = 0
resetBtn.Text            = "Reset to White"
resetBtn.Font            = Enum.Font.Gotham
resetBtn.TextSize        = 13
resetBtn.TextColor3      = Color3.fromRGB(180, 160, 220)
resetBtn.AutoButtonColor = false
resetBtn.Parent          = rightPanel
makeCorner(resetBtn, 8)

resetBtn.MouseButton1Click:Connect(function()
	resetBodyColors()
	for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
		local btn = partButtons[partName]
		if btn then
			btn.BackgroundColor3 = WHITE
			btn.TextColor3       = Color3.new(0, 0, 0)
		end
	end
end)

-- ── Submit logic ───────────────────────────────────────────────────────────

local function closeUI()
	screenGui.Enabled = false
	if timerConn then timerConn:Disconnect(); timerConn = nil end
end

local function doSubmit()
	if submitted then return end
	submitted = true

	PaintSubmitted:FireServer({ bodyColors = bodyColors })
	closeUI()
end

submitBtn.MouseButton1Click:Connect(doSubmit)

-- ── Phase / role listeners ─────────────────────────────────────────────────

RoleAssigned.OnClientEvent:Connect(function(role: string)
	currentRole = role
end)

RoundStateChanged.OnClientEvent:Connect(function(
	phase: string,
	_duration: number,
	endsAt: number,
	_roundId: number
)
	if phase == "Paint" then
		if currentRole ~= "Hider" then
			closeUI()
			return
		end

		submitted     = false
		resetBodyColors()

		-- Reset doll buttons to white
		for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
			local btn = partButtons[partName]
			if btn then
				btn.BackgroundColor3 = WHITE
				btn.TextColor3       = Color3.new(0, 0, 0)
			end
		end

		screenGui.Enabled = true

		-- Sync countdown timer to server time
		if timerConn then timerConn:Disconnect() end
		timerConn = RunService.Heartbeat:Connect(function()
			local rem = endsAt - workspace:GetServerTimeNow()
			if rem <= 0 then
				timerLbl.Text       = "0:00"
				timerLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
				if timerConn then timerConn:Disconnect(); timerConn = nil end
				doSubmit()
				return
			end

			local secs = math.floor(rem)
			local mins = math.floor(secs / 60)
			timerLbl.Text = string.format("%d:%02d", mins, secs % 60)
			timerLbl.TextColor3 = rem <= 10
				and Color3.fromRGB(255, 60, 60)
				or rem <= 30
				and Color3.fromRGB(255, 180, 40)
				or  Color3.fromRGB(100, 240, 140)
		end)
	else
		closeUI()
	end
end)
