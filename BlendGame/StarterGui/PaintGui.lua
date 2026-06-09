-- PaintGui: LocalScript in StarterGui
-- Grid-based paint UI for hiders during the Paint and PoseLock phases.
-- Each body panel is a grid of cells that can be painted individually.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Config & Remotes ───────────────────────────────────────────────────────
local Modules           = ReplicatedStorage:WaitForChild("Modules", 30)
local Remotes           = ReplicatedStorage:WaitForChild("Remotes", 30)

local PaintConfig      = require(Modules:WaitForChild("PaintConfig"))
local PaintPanelConfig = require(Modules:WaitForChild("PaintPanelConfig"))
local PaintColorConfig = require(Modules:WaitForChild("PaintColorConfig"))

local PaintStroke      = Remotes:WaitForChild("PaintStroke")      :: RemoteEvent
local FillPanel        = Remotes:WaitForChild("FillPanel")        :: RemoteEvent
local ClearPanel       = Remotes:WaitForChild("ClearPanel")       :: RemoteEvent
local UndoPaint        = Remotes:WaitForChild("UndoPaint")        :: RemoteEvent
local RedoPaint        = Remotes:WaitForChild("RedoPaint")        :: RemoteEvent
local MirrorPanel      = Remotes:WaitForChild("MirrorPanel")      :: RemoteEvent
local PaintDataUpdated = Remotes:WaitForChild("PaintDataUpdated") :: RemoteEvent
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned     = Remotes:WaitForChild("RoleAssigned")     :: RemoteEvent

-- ── Constants ──────────────────────────────────────────────────────────────
local CELL_PX          = 28      -- UI cell size in pixels
local HOVER_ALPHA      = 0.45    -- overlay transparency for hover preview
local STROKE_INTERVAL  = PaintConfig.STROKE_SEND_INTERVAL
local MAX_UNDO         = PaintConfig.MAX_UNDO_HISTORY
local DEFAULT_COLOR_ID = PaintConfig.DEFAULT_COLOR_ID
local ERASER_ID        = PaintColorConfig.ERASER_ID

-- ── Client-side state ──────────────────────────────────────────────────────
local localCells       = {}  -- localCells[panelId][flatIdx] = colorId
local undoHistory      = {}  -- stack of { panelId, snapshot:{[idx]=colorId} }
local redoHistory      = {}

local currentPanel     = PaintPanelConfig.PanelOrder[1] or "TorsoFront"
local currentColor     = "Red"
local currentTool      = "Brush"   -- "Brush"|"Fill"|"Eraser"|"Eyedropper"
local currentBrushRadius = 1       -- Medium

local myRole           = nil
local isDragging       = false
local paintedThisStroke = {}       -- set of flat indices already painted this drag
local pendingStrokeCells = {}      -- cells to send next flush
local lastFlushTime    = 0

-- ── Helpers ────────────────────────────────────────────────────────────────
local function flatIndex(row, col, width)
	return (row - 1) * width + col
end

local function rowCol(idx, width)
	return math.ceil(idx / width), ((idx - 1) % width) + 1
end

local function colorForId(colorId)
	if colorId == ERASER_ID then
		return PaintColorConfig.ById[DEFAULT_COLOR_ID].Color
	end
	local entry = PaintColorConfig.ById[colorId]
	return entry and entry.Color or PaintColorConfig.ById[DEFAULT_COLOR_ID].Color
end

local function effectiveColorId()
	if currentTool == "Eraser" then return ERASER_ID end
	return currentColor
end

local function storedColorId(colorId)
	if colorId == ERASER_ID then return DEFAULT_COLOR_ID end
	return colorId
end

-- Closest palette color by RGB Euclidean distance
local function closestPaletteColor(color3)
	local bestId, bestDist = DEFAULT_COLOR_ID, math.huge
	for _, entry in ipairs(PaintColorConfig.Colors) do
		local dr = color3.R - entry.Color.R
		local dg = color3.G - entry.Color.G
		local db = color3.B - entry.Color.B
		local d  = dr*dr + dg*dg + db*db
		if d < bestDist then bestDist = d; bestId = entry.Id end
	end
	return bestId
end

-- Compute all cell indices covered by a brush centered at (cr, cc) within the panel
local function brushCells(cr, cc, radius, width, height)
	local cells = {}
	for dr = -radius, radius do
		for dc = -radius, radius do
			-- circle clip: use Chebyshev distance for square brush feel
			if math.sqrt(dr*dr + dc*dc) <= radius + 0.5 then
				local r = cr + dr
				local c = cc + dc
				if r >= 1 and r <= height and c >= 1 and c <= width then
					table.insert(cells, flatIndex(r, c, width))
				end
			end
		end
	end
	return cells
end

-- Initialise localCells for a panel if not yet done
local function ensurePanel(panelId)
	if localCells[panelId] then return end
	local panel = PaintPanelConfig.Panels[panelId]
	local t = {}
	for i = 1, panel.Width * panel.Height do
		t[i] = DEFAULT_COLOR_ID
	end
	localCells[panelId] = t
end

for panelId, _ in pairs(PaintPanelConfig.Panels) do
	ensurePanel(panelId)
end

-- ── GUI construction ───────────────────────────────────────────────────────
local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Thickness = thickness; s.Parent = parent
	return s
end

local function makeLabel(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

-- ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name           = "PaintGui"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 10
gui.Enabled        = false
gui.Parent         = playerGui

-- Root frame
local root = Instance.new("Frame")
root.Name             = "Root"
root.Size             = UDim2.new(0, 800, 0, 600)
root.Position         = UDim2.new(0.5, -400, 0.5, -300)
root.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
root.BorderSizePixel  = 0
root.Parent           = gui
makeCorner(root, 14)
makeStroke(root, Color3.fromRGB(80, 50, 180), 2)

-- Header
local header = Instance.new("Frame")
header.Name             = "Header"
header.Size             = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(40, 22, 100)
header.BorderSizePixel  = 0
header.Parent           = root
makeCorner(header, 14)

local headerMask = Instance.new("Frame")
headerMask.Size             = UDim2.new(1, 0, 0, 14)
headerMask.Position         = UDim2.new(0, 0, 1, -14)
headerMask.BackgroundColor3 = Color3.fromRGB(40, 22, 100)
headerMask.BorderSizePixel  = 0
headerMask.Parent           = header

local titleLbl = makeLabel(header, "🎨 PAINT YOUR DISGUISE", 19, Color3.fromRGB(255, 220, 50), Enum.Font.GothamBold)
titleLbl.Size             = UDim2.new(1, -20, 1, 0)
titleLbl.Position         = UDim2.new(0, 10, 0, 0)
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left

-- Content area
local content = Instance.new("Frame")
content.Name             = "Content"
content.Size             = UDim2.new(1, -20, 1, -62)
content.Position         = UDim2.new(0, 10, 0, 56)
content.BackgroundTransparency = 1
content.Parent           = root

-- ── Tab bar ────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame")
tabBar.Name             = "TabBar"
tabBar.Size             = UDim2.new(1, 0, 0, 34)
tabBar.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
tabBar.BorderSizePixel  = 0
tabBar.Parent           = content
makeCorner(tabBar, 8)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection  = Enum.FillDirection.Horizontal
tabLayout.SortOrder      = Enum.SortOrder.LayoutOrder
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding        = UDim.new(0, 4)
tabLayout.Parent         = tabBar

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingLeft = UDim.new(0, 6)
UIPadding.Parent = tabBar

-- ── Main area (grid + sidebar) ─────────────────────────────────────────────
local mainArea = Instance.new("Frame")
mainArea.Name             = "MainArea"
mainArea.Size             = UDim2.new(1, 0, 1, -44)
mainArea.Position         = UDim2.new(0, 0, 0, 40)
mainArea.BackgroundTransparency = 1
mainArea.Parent           = content

-- Grid container (left)
local gridContainer = Instance.new("Frame")
gridContainer.Name             = "GridContainer"
gridContainer.Size             = UDim2.new(0, 480, 1, -50)
gridContainer.Position         = UDim2.new(0, 0, 0, 0)
gridContainer.BackgroundColor3 = Color3.fromRGB(22, 18, 40)
gridContainer.BorderSizePixel  = 0
gridContainer.Parent           = mainArea
makeCorner(gridContainer, 8)

-- Scroll frame for the grid
local gridScroll = Instance.new("ScrollingFrame")
gridScroll.Name             = "GridScroll"
gridScroll.Size             = UDim2.new(1, -8, 1, -8)
gridScroll.Position         = UDim2.new(0, 4, 0, 4)
gridScroll.BackgroundTransparency = 1
gridScroll.BorderSizePixel  = 0
gridScroll.ScrollBarThickness = 6
gridScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 80, 200)
gridScroll.Parent           = gridContainer

local gridFrame = Instance.new("Frame")
gridFrame.Name             = "GridFrame"
gridFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
gridFrame.BorderSizePixel  = 0
gridFrame.Parent           = gridScroll
makeCorner(gridFrame, 4)

-- Sidebar (right)
local sidebar = Instance.new("Frame")
sidebar.Name             = "Sidebar"
sidebar.Size             = UDim2.new(1, -488, 1, -50)
sidebar.Position         = UDim2.new(0, 488, 0, 0)
sidebar.BackgroundTransparency = 1
sidebar.Parent           = mainArea

-- Color tray label
local colorLabel = makeLabel(sidebar, "COLORS", 11, Color3.fromRGB(170, 155, 210))
colorLabel.Size     = UDim2.new(1, 0, 0, 18)
colorLabel.Position = UDim2.new(0, 0, 0, 0)
colorLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Color tray scroll frame
local colorScroll = Instance.new("ScrollingFrame")
colorScroll.Name             = "ColorScroll"
colorScroll.Size             = UDim2.new(1, 0, 0, 240)
colorScroll.Position         = UDim2.new(0, 0, 0, 20)
colorScroll.BackgroundColor3 = Color3.fromRGB(22, 18, 40)
colorScroll.BorderSizePixel  = 0
colorScroll.ScrollBarThickness = 5
colorScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 80, 200)
colorScroll.Parent           = sidebar
makeCorner(colorScroll, 6)

local colorGrid = Instance.new("Frame")
colorGrid.Name             = "ColorGrid"
colorGrid.BackgroundTransparency = 1
colorGrid.Parent           = colorScroll

local colorGridLayout = Instance.new("UIGridLayout")
colorGridLayout.CellSize      = UDim2.new(0, 34, 0, 34)
colorGridLayout.CellPadding   = UDim2.new(0, 4, 0, 4)
colorGridLayout.SortOrder     = Enum.SortOrder.LayoutOrder
colorGridLayout.FillDirection = Enum.FillDirection.Horizontal
colorGridLayout.Parent        = colorGrid

local colorGridPadding = Instance.new("UIPadding")
colorGridPadding.PaddingLeft = UDim.new(0, 4)
colorGridPadding.PaddingTop  = UDim.new(0, 4)
colorGridPadding.Parent      = colorGrid

-- Brush size label
local brushLabel = makeLabel(sidebar, "BRUSH SIZE", 11, Color3.fromRGB(170, 155, 210))
brushLabel.Size     = UDim2.new(1, 0, 0, 18)
brushLabel.Position = UDim2.new(0, 0, 0, 268)
brushLabel.TextXAlignment = Enum.TextXAlignment.Left

local brushSizeBar = Instance.new("Frame")
brushSizeBar.Name             = "BrushSizeBar"
brushSizeBar.Size             = UDim2.new(1, 0, 0, 34)
brushSizeBar.Position         = UDim2.new(0, 0, 0, 288)
brushSizeBar.BackgroundTransparency = 1
brushSizeBar.Parent           = sidebar

local brushSizeLayout = Instance.new("UIListLayout")
brushSizeLayout.FillDirection  = Enum.FillDirection.Horizontal
brushSizeLayout.SortOrder      = Enum.SortOrder.LayoutOrder
brushSizeLayout.Padding        = UDim.new(0, 4)
brushSizeLayout.Parent         = brushSizeBar

-- Bottom toolbar
local toolbar = Instance.new("Frame")
toolbar.Name             = "Toolbar"
toolbar.Size             = UDim2.new(1, 0, 0, 42)
toolbar.Position         = UDim2.new(0, 0, 1, -42)
toolbar.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
toolbar.BorderSizePixel  = 0
toolbar.Parent           = content
makeCorner(toolbar, 8)

local toolbarLayout = Instance.new("UIListLayout")
toolbarLayout.FillDirection     = Enum.FillDirection.Horizontal
toolbarLayout.SortOrder         = Enum.SortOrder.LayoutOrder
toolbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
toolbarLayout.Padding           = UDim.new(0, 6)
toolbarLayout.Parent            = toolbar

local toolbarPad = Instance.new("UIPadding")
toolbarPad.PaddingLeft = UDim.new(0, 8)
toolbarPad.Parent = toolbar

-- ── Cell frames lookup ─────────────────────────────────────────────────────
-- cellFrames[panelId][flatIdx] = Frame (built when panel is rendered)
local cellFrames     = {}
-- hoverFrames[flatIdx] = Frame overlay (reused)
local hoverFrames    = {}

-- ── Tool / color button references ────────────────────────────────────────
local toolButtons    = {}   -- toolButtons[toolId] = TextButton
local brushSizeBtns  = {}   -- brushSizeBtns[radius] = TextButton
local colorSwatches  = {}   -- colorSwatches[colorId] = Frame
local tabButtons     = {}   -- tabButtons[panelId] = TextButton

-- ── Selection highlight helpers ────────────────────────────────────────────
local function setTabActive(panelId)
	for id, btn in pairs(tabButtons) do
		if id == panelId then
			btn.BackgroundColor3 = Color3.fromRGB(80, 50, 200)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 28, 70)
			btn.TextColor3       = Color3.fromRGB(170, 155, 210)
		end
	end
end

local function setToolActive(toolId)
	for id, btn in pairs(toolButtons) do
		if id == toolId then
			btn.BackgroundColor3 = Color3.fromRGB(80, 50, 200)
		else
			btn.BackgroundColor3 = Color3.fromRGB(40, 30, 80)
		end
	end
end

local function setColorActive(colorId)
	for id, frame in pairs(colorSwatches) do
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			if id == colorId then
				stroke.Color     = Color3.fromRGB(255, 220, 50)
				stroke.Thickness = 3
			else
				stroke.Color     = Color3.fromRGB(50, 40, 90)
				stroke.Thickness = 1
			end
		end
	end
end

local function setBrushActive(radius)
	for r, btn in pairs(brushSizeBtns) do
		if r == radius then
			btn.BackgroundColor3 = Color3.fromRGB(80, 50, 200)
		else
			btn.BackgroundColor3 = Color3.fromRGB(40, 30, 80)
		end
	end
end

-- ── Build color tray ───────────────────────────────────────────────────────
for i, entry in ipairs(PaintColorConfig.Colors) do
	local swatch = Instance.new("TextButton")
	swatch.Name            = "Swatch_" .. entry.Id
	swatch.Size            = UDim2.new(0, 34, 0, 34)
	swatch.BackgroundColor3 = entry.Color
	swatch.BorderSizePixel  = 0
	swatch.Text            = ""
	swatch.AutoButtonColor = false
	swatch.LayoutOrder     = i
	swatch.Parent          = colorGrid
	makeCorner(swatch, 5)
	local st = makeStroke(swatch, Color3.fromRGB(50, 40, 90), 1)

	colorSwatches[entry.Id] = swatch

	swatch.MouseButton1Click:Connect(function()
		currentColor = entry.Id
		if currentTool == "Eraser" then
			currentTool = "Brush"
			setToolActive("Brush")
		end
		setColorActive(currentColor)
	end)
end

-- Resize colorGrid canvas
colorGrid.Size = UDim2.new(0, 4 * (34 + 4) + 4, 0, math.ceil(#PaintColorConfig.Colors / 4) * (34 + 4) + 4)
colorScroll.CanvasSize = colorGrid.Size

-- ── Build brush size buttons ───────────────────────────────────────────────
for _, brushDef in ipairs(PaintConfig.BRUSH_SIZES) do
	local btn = Instance.new("TextButton")
	btn.Name             = "Brush_" .. brushDef.Id
	btn.Size             = UDim2.new(0, 38, 0, 30)
	btn.BackgroundColor3 = Color3.fromRGB(40, 30, 80)
	btn.BorderSizePixel  = 0
	btn.Text             = brushDef.Label
	btn.Font             = Enum.Font.GothamBold
	btn.TextSize         = 14
	btn.TextColor3       = Color3.fromRGB(220, 210, 255)
	btn.AutoButtonColor  = false
	btn.LayoutOrder      = brushDef.Radius
	btn.Parent           = brushSizeBar
	makeCorner(btn, 6)

	brushSizeBtns[brushDef.Radius] = btn

	btn.MouseButton1Click:Connect(function()
		currentBrushRadius = brushDef.Radius
		setBrushActive(currentBrushRadius)
	end)
end

-- ── Build tab buttons ──────────────────────────────────────────────────────
local function renderPanel(panelId)
	local panel = PaintPanelConfig.Panels[panelId]
	if not panel then return end
	ensurePanel(panelId)

	local w, h = panel.Width, panel.Height
	local frameW = w * CELL_PX
	local frameH = h * CELL_PX

	-- Resize gridFrame and scrolling canvas
	gridFrame.Size      = UDim2.new(0, frameW, 0, frameH)
	gridScroll.CanvasSize = UDim2.new(0, frameW + 8, 0, frameH + 8)

	-- Clear existing cells
	for _, child in ipairs(gridFrame:GetChildren()) do
		child:Destroy()
	end
	hoverFrames = {}

	if not cellFrames[panelId] then
		cellFrames[panelId] = {}
	end
	cellFrames[panelId] = {}

	local cells = localCells[panelId]

	for r = 1, h do
		for c = 1, w do
			local idx     = flatIndex(r, c, w)
			local colorId = cells[idx] or DEFAULT_COLOR_ID

			local cell = Instance.new("ImageButton")
			cell.Name             = string.format("C_%d_%d", r, c)
			cell.Size             = UDim2.new(0, CELL_PX, 0, CELL_PX)
			cell.Position         = UDim2.new(0, (c-1)*CELL_PX, 0, (r-1)*CELL_PX)
			cell.BackgroundColor3 = colorForId(colorId)
			cell.BorderSizePixel  = 0
			cell.Image            = ""
			cell.AutoButtonColor  = false
			cell.Parent           = gridFrame

			cellFrames[panelId][idx] = cell

			-- Hover overlay
			local hov = Instance.new("Frame")
			hov.Name                  = "Hover"
			hov.Size                  = UDim2.new(1, 0, 1, 0)
			hov.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
			hov.BackgroundTransparency = 1
			hov.BorderSizePixel       = 0
			hov.ZIndex                = cell.ZIndex + 1
			hov.Parent                = cell
			hoverFrames[idx] = hov

			-- Mouse interactions
			local function paintCell()
				if currentTool == "Fill" then
					-- handled on click not drag
					return
				end
				if currentTool == "Eyedropper" then
					return
				end
				-- Paint cells in brush radius
				local targetCells = brushCells(r, c, currentBrushRadius, w, h)
				local colorId2    = effectiveColorId()
				local stored      = storedColorId(colorId2)

				for _, tidx in ipairs(targetCells) do
					if not paintedThisStroke[tidx] then
						paintedThisStroke[tidx] = true
						-- Update local state
						localCells[panelId][tidx] = stored
						-- Update visual
						local f = cellFrames[panelId][tidx]
						if f then f.BackgroundColor3 = colorForId(colorId2) end
						-- Queue for server
						table.insert(pendingStrokeCells, tidx)
					end
				end
			end

			cell.MouseButton1Down:Connect(function()
				if not isDragging then
					isDragging = true
					paintedThisStroke = {}
					pendingStrokeCells = {}
				end

				if currentTool == "Fill" then
					FillPanel:FireServer({ PanelId = panelId, ColorId = effectiveColorId() })
					-- Optimistically fill local
					local stored = storedColorId(effectiveColorId())
					for i2 = 1, w * h do
						localCells[panelId][i2] = stored
						if cellFrames[panelId] and cellFrames[panelId][i2] then
							cellFrames[panelId][i2].BackgroundColor3 = colorForId(effectiveColorId())
						end
					end
					return
				end

				if currentTool == "Eyedropper" then
					local sampledId = localCells[panelId][idx] or DEFAULT_COLOR_ID
					local bestId = closestPaletteColor(colorForId(sampledId))
					currentColor = bestId
					currentTool  = "Brush"
					setToolActive("Brush")
					setColorActive(currentColor)
					return
				end

				paintCell()
			end)

			cell.MouseEnter:Connect(function()
				-- Hover highlight
				local hoverTargets = brushCells(r, c, currentBrushRadius, w, h)
				for _, tidx in ipairs(hoverTargets) do
					if hoverFrames[tidx] then
						hoverFrames[tidx].BackgroundTransparency = HOVER_ALPHA
					end
				end

				if isDragging and (currentTool == "Brush" or currentTool == "Eraser") then
					paintCell()
				end
			end)

			cell.MouseLeave:Connect(function()
				-- Clear hover
				local hoverTargets = brushCells(r, c, currentBrushRadius, w, h)
				for _, tidx in ipairs(hoverTargets) do
					if hoverFrames[tidx] then
						hoverFrames[tidx].BackgroundTransparency = 1
					end
				end
			end)
		end
	end
end

-- Switch active panel
local function switchPanel(panelId)
	if currentPanel == panelId and cellFrames[panelId] then return end
	currentPanel = panelId
	setTabActive(panelId)
	renderPanel(panelId)
end

for i, panelId in ipairs(PaintPanelConfig.PanelOrder) do
	local panel = PaintPanelConfig.Panels[panelId]
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name             = "Tab_" .. panelId
	tabBtn.Size             = UDim2.new(0, 82, 0, 26)
	tabBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 70)
	tabBtn.BorderSizePixel  = 0
	tabBtn.Text             = panel.DisplayName
	tabBtn.Font             = Enum.Font.GothamBold
	tabBtn.TextSize         = 11
	tabBtn.TextColor3       = Color3.fromRGB(170, 155, 210)
	tabBtn.AutoButtonColor  = false
	tabBtn.LayoutOrder      = i
	tabBtn.Parent           = tabBar
	makeCorner(tabBtn, 5)

	tabButtons[panelId] = tabBtn

	tabBtn.MouseButton1Click:Connect(function()
		switchPanel(panelId)
	end)
end

-- ── Build toolbar buttons ──────────────────────────────────────────────────
local ACTION_TOOLS   = { "Brush", "Fill", "Eraser", "Eyedropper" }
local INSTANT_TOOLS  = { "Undo", "Redo", "Clear", "Mirror" }

local function makeToolBtn(label, layoutOrder)
	local btn = Instance.new("TextButton")
	btn.Name             = label
	btn.Size             = UDim2.new(0, 70, 0, 30)
	btn.BackgroundColor3 = Color3.fromRGB(40, 30, 80)
	btn.BorderSizePixel  = 0
	btn.Text             = label
	btn.Font             = Enum.Font.GothamBold
	btn.TextSize         = 13
	btn.TextColor3       = Color3.fromRGB(220, 210, 255)
	btn.AutoButtonColor  = false
	btn.LayoutOrder      = layoutOrder
	btn.Parent           = toolbar
	makeCorner(btn, 7)
	return btn
end

-- Separator
local function makeSep()
	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(0, 2, 0, 24)
	sep.BackgroundColor3 = Color3.fromRGB(70, 55, 140)
	sep.BorderSizePixel  = 0
	sep.Parent           = toolbar
	return sep
end

for i, toolId in ipairs(ACTION_TOOLS) do
	local btn = makeToolBtn(toolId, i)
	toolButtons[toolId] = btn
	btn.MouseButton1Click:Connect(function()
		currentTool = toolId
		setToolActive(toolId)
	end)
end

makeSep()

-- Undo
local undoBtn = makeToolBtn("Undo", 10)
undoBtn.MouseButton1Click:Connect(function()
	if #undoHistory > 0 then
		local entry = table.remove(undoHistory, #undoHistory)
		-- Save redo snapshot
		local redoSnap = {}
		local pState = localCells[entry.panelId]
		if pState then
			for idx, _ in pairs(entry.snapshot) do
				redoSnap[idx] = pState[idx]
			end
		end
		table.insert(redoHistory, { panelId = entry.panelId, snapshot = redoSnap })
		-- Apply undo
		if pState then
			for idx, colorId in pairs(entry.snapshot) do
				pState[idx] = colorId
				if cellFrames[entry.panelId] and cellFrames[entry.panelId][idx] then
					cellFrames[entry.panelId][idx].BackgroundColor3 = colorForId(colorId)
				end
			end
		end
		UndoPaint:FireServer()
	end
end)

-- Redo
local redoBtn = makeToolBtn("Redo", 11)
redoBtn.MouseButton1Click:Connect(function()
	if #redoHistory > 0 then
		local entry = table.remove(redoHistory, #redoHistory)
		local redoSnap = {}
		local pState = localCells[entry.panelId]
		if pState then
			for idx, _ in pairs(entry.snapshot) do
				redoSnap[idx] = pState[idx]
			end
		end
		table.insert(undoHistory, { panelId = entry.panelId, snapshot = redoSnap })
		if pState then
			for idx, colorId in pairs(entry.snapshot) do
				pState[idx] = colorId
				if cellFrames[entry.panelId] and cellFrames[entry.panelId][idx] then
					cellFrames[entry.panelId][idx].BackgroundColor3 = colorForId(colorId)
				end
			end
		end
		RedoPaint:FireServer()
	end
end)

-- Clear
local clearBtn = makeToolBtn("Clear", 12)
clearBtn.MouseButton1Click:Connect(function()
	-- Save undo snapshot
	local snap = {}
	if localCells[currentPanel] then
		for idx, colorId in pairs(localCells[currentPanel]) do
			snap[idx] = colorId
		end
		table.insert(undoHistory, { panelId = currentPanel, snapshot = snap })
		while #undoHistory > MAX_UNDO do table.remove(undoHistory, 1) end
		redoHistory = {}
	end
	ClearPanel:FireServer({ PanelId = currentPanel })
	-- Optimistically clear
	local panel = PaintPanelConfig.Panels[currentPanel]
	if panel and localCells[currentPanel] then
		for i = 1, panel.Width * panel.Height do
			localCells[currentPanel][i] = DEFAULT_COLOR_ID
			if cellFrames[currentPanel] and cellFrames[currentPanel][i] then
				cellFrames[currentPanel][i].BackgroundColor3 = colorForId(DEFAULT_COLOR_ID)
			end
		end
	end
end)

-- Mirror
local mirrorBtn = makeToolBtn("Mirror", 13)
mirrorBtn.MouseButton1Click:Connect(function()
	MirrorPanel:FireServer({ sourcePanelId = currentPanel })
end)

-- ── Stroke flushing (Heartbeat) ────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	if not isDragging then return end
	if #pendingStrokeCells == 0 then return end

	local now = tick()
	if now - lastFlushTime < STROKE_INTERVAL then return end
	lastFlushTime = now

	-- Snapshot and clear
	local toSend = pendingStrokeCells
	pendingStrokeCells = {}

	-- Deduplicate
	local seen = {}
	local unique = {}
	for _, idx in ipairs(toSend) do
		if not seen[idx] then
			seen[idx] = true
			table.insert(unique, idx)
		end
	end

	if #unique == 0 then return end

	PaintStroke:FireServer({
		PanelId     = currentPanel,
		CellIndices = unique,
		ColorId     = effectiveColorId(),
		BrushSize   = currentBrushRadius,
	})
end)

-- Flush on mouse up
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isDragging then
			-- Final flush
			if #pendingStrokeCells > 0 then
				local seen = {}
				local unique = {}
				for _, idx in ipairs(pendingStrokeCells) do
					if not seen[idx] then
						seen[idx] = true
						table.insert(unique, idx)
					end
				end
				if #unique > 0 then
					PaintStroke:FireServer({
						PanelId     = currentPanel,
						CellIndices = unique,
						ColorId     = effectiveColorId(),
						BrushSize   = currentBrushRadius,
					})
				end
				pendingStrokeCells = {}
			end
			isDragging = false
			paintedThisStroke = {}
		end
	end
end)

-- ── PaintDataUpdated sync ──────────────────────────────────────────────────
PaintDataUpdated.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local panelId = data.panelId
	local cells   = data.cells
	if not panelId or not cells then return end

	ensurePanel(panelId)
	for idx, colorId in pairs(cells) do
		localCells[panelId][idx] = colorId
	end

	-- Refresh visual if this panel is active
	if panelId == currentPanel and cellFrames[panelId] then
		for idx, colorId in pairs(cells) do
			local f = cellFrames[panelId][idx]
			if f then
				f.BackgroundColor3 = colorForId(colorId)
			end
		end
	end
end)

-- ── Phase and role gating ──────────────────────────────────────────────────
RoleAssigned.OnClientEvent:Connect(function(role)
	myRole = role
end)

RoundStateChanged.OnClientEvent:Connect(function(phase)
	local allowed = (phase == "Paint" or phase == "PoseLock")
	gui.Enabled = allowed and (myRole == "Hider")

	if gui.Enabled then
		-- Render current panel on open
		renderPanel(currentPanel)
		setTabActive(currentPanel)
		setToolActive(currentTool)
		setColorActive(currentColor)
		setBrushActive(currentBrushRadius)
	end
end)

-- ── Initial setup ──────────────────────────────────────────────────────────
setTabActive(currentPanel)
setToolActive(currentTool)
setColorActive(currentColor)
setBrushActive(currentBrushRadius)

-- Render first panel when GUI is parented (deferred)
task.defer(function()
	renderPanel(currentPanel)
end)
