-- PaintGridService: ModuleScript in ServerScriptService
-- Manages per-player grid state, SurfaceGui creation/update, undo/redo,
-- and wires all paint-related RemoteEvents.

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local PaintConfig           = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PaintConfig"))
local PaintPanelConfig      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PaintPanelConfig"))
local PaintColorConfig      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PaintColorConfig"))
local PaintValidationService = require(ServerScriptService:WaitForChild("PaintValidationService"))

local PaintGridService = {}

-- ──────────────────────────────────────────────────────────────────────────────
-- Internal state
-- ──────────────────────────────────────────────────────────────────────────────

-- playerData[player][panelId] = { width, height, cells:{[idx]=colorId} }
local playerData  = {}
-- undoStacks[player] = array of { panelId, changes:{[idx]={from,to}} }
local undoStacks  = {}
-- redoStacks[player] = same structure
local redoStacks  = {}

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────

local function flatIndex(row, col, width)
	return (row - 1) * width + col
end

local function rowCol(idx, width)
	local row = math.ceil(idx / width)
	local col = ((idx - 1) % width) + 1
	return row, col
end

-- Returns the Color3 to use for a colorId (handles eraser → DEFAULT_COLOR).
local function colorForId(colorId)
	if colorId == PaintColorConfig.ERASER_ID then
		return PaintConfig.DEFAULT_COLOR
	end
	local entry = PaintColorConfig.ById[colorId]
	return entry and entry.Color or PaintConfig.DEFAULT_COLOR
end

-- Effective stored color: eraser is stored as DEFAULT_COLOR_ID.
local function storedColor(colorId)
	if colorId == PaintColorConfig.ERASER_ID then
		return PaintConfig.DEFAULT_COLOR_ID
	end
	return colorId
end

-- Initialise playerData for one player (does NOT create SurfaceGuis yet).
local function initPlayerData(player)
	if playerData[player] then return end
	playerData[player] = {}
	for panelId, panel in pairs(PaintPanelConfig.Panels) do
		local cells = {}
		local total = panel.Width * panel.Height
		for i = 1, total do
			cells[i] = PaintConfig.DEFAULT_COLOR_ID
		end
		playerData[player][panelId] = {
			width  = panel.Width,
			height = panel.Height,
			cells  = cells,
		}
	end
	undoStacks[player] = {}
	redoStacks[player] = {}
end

-- ──────────────────────────────────────────────────────────────────────────────
-- SurfaceGui management
-- ──────────────────────────────────────────────────────────────────────────────

-- Update one cell Frame inside an existing SurfaceGui.
local function updateCellFrame(surfaceGui, row, col, colorId)
	local frameName = string.format("C_%d_%d", row, col)
	local frame = surfaceGui:FindFirstChild(frameName)
	if frame then
		frame.BackgroundColor3 = colorForId(colorId)
	end
end

-- Build (or rebuild) the SurfaceGui for one panel on a player's character.
local function buildPanelSurfaceGui(player, panelId)
	if not player.Character then return end

	local panel     = PaintPanelConfig.Panels[panelId]
	local part      = player.Character:FindFirstChild(panel.PartName)
	if not part then return end

	local guiName   = "PaintSurface_" .. panelId
	local existing  = part:FindFirstChild(guiName)
	if existing then existing:Destroy() end

	local gui = Instance.new("SurfaceGui")
	gui.Name              = guiName
	gui.Face              = panel.Face
	gui.SizingMode        = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud     = PaintConfig.SURFACE_CELL_PX
	gui.ResetOnBasePartSize = false
	gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
	gui.AlwaysOnTop       = false
	gui.Enabled           = true
	gui.Parent            = part   -- parented to workspace part → replicates automatically

	local panelState = playerData[player] and playerData[player][panelId]
	local cells      = panelState and panelState.cells or {}
	local w, h       = panel.Width, panel.Height

	for r = 1, h do
		for c = 1, w do
			local idx    = flatIndex(r, c, w)
			local colorId = cells[idx] or PaintConfig.DEFAULT_COLOR_ID

			local frame = Instance.new("Frame")
			frame.Name             = string.format("C_%d_%d", r, c)
			frame.Size             = UDim2.new(1 / w, 0, 1 / h, 0)
			frame.Position         = UDim2.new((c - 1) / w, 0, (r - 1) / h, 0)
			frame.BackgroundColor3 = colorForId(colorId)
			frame.BorderSizePixel  = 0
			frame.Parent           = gui
		end
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- PaintDataUpdated broadcast
-- ──────────────────────────────────────────────────────────────────────────────

local PaintDataUpdated  -- resolved in hookRemotes

local function firePaintDataUpdated(player, panelId)
	if not PaintDataUpdated then return end
	local panelState = playerData[player] and playerData[player][panelId]
	if not panelState then return end
	-- Deep-copy cells so the client gets a clean snapshot
	local cellsCopy = {}
	for k, v in pairs(panelState.cells) do
		cellsCopy[k] = v
	end
	PaintDataUpdated:FireClient(player, { panelId = panelId, cells = cellsCopy })
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Undo / redo helpers
-- ──────────────────────────────────────────────────────────────────────────────

local function pushUndo(player, panelId, changes)
	local stack = undoStacks[player]
	if not stack then return end
	table.insert(stack, { panelId = panelId, changes = changes })
	-- Trim to MAX_UNDO_HISTORY
	while #stack > PaintConfig.MAX_UNDO_HISTORY do
		table.remove(stack, 1)
	end
	-- Clear redo on new action
	redoStacks[player] = {}
end

-- Apply a changes map (keyed by flat index) to the grid; updates SurfaceGui.
local function applyChanges(player, panelId, changes)
	local panelState = playerData[player] and playerData[player][panelId]
	if not panelState then return end

	if not player.Character then return end
	local panel    = PaintPanelConfig.Panels[panelId]
	local part     = player.Character:FindFirstChild(panel.PartName)
	local guiName  = "PaintSurface_" .. panelId
	local surfaceGui = part and part:FindFirstChild(guiName)

	for idx, colorId in pairs(changes) do
		panelState.cells[idx] = colorId
		if surfaceGui then
			local r, c = rowCol(idx, panelState.width)
			updateCellFrame(surfaceGui, r, c, colorId)
		end
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

-- Called by GameManager at the start of each round with the list of hider Players.
function PaintGridService.startRound(hiders)
	for _, player in ipairs(hiders) do
		initPlayerData(player)
		PaintGridService.applyToCharacter(player)
	end
end

-- Called by GameManager at round end; destroys all SurfaceGuis and wipes state.
function PaintGridService.clearRound()
	for player, panels in pairs(playerData) do
		if player.Character then
			for panelId, _ in pairs(panels) do
				local panel = PaintPanelConfig.Panels[panelId]
				local part  = player.Character:FindFirstChild(panel.PartName)
				if part then
					local gui = part:FindFirstChild("PaintSurface_" .. panelId)
					if gui then gui:Destroy() end
				end
			end
		end
	end
	playerData  = {}
	undoStacks  = {}
	redoStacks  = {}
end

-- Forward phase to validation service.
function PaintGridService.setPhase(phase)
	PaintValidationService.setPhase(phase)
end

-- (Re)build all SurfaceGuis for a player's current character.
function PaintGridService.applyToCharacter(player)
	initPlayerData(player)
	for panelId, _ in pairs(PaintPanelConfig.Panels) do
		buildPanelSurfaceGui(player, panelId)
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Core paint operations (internal, called from remote handlers)
-- ──────────────────────────────────────────────────────────────────────────────

local function applyStroke(player, panelId, cellIndices, colorId)
	local panelState = playerData[player] and playerData[player][panelId]
	if not panelState then return end

	local stored  = storedColor(colorId)
	local changes = {}   -- { [idx] = { from = oldColorId, to = newColorId } }

	for _, idx in ipairs(cellIndices) do
		local old = panelState.cells[idx]
		if old ~= stored then
			changes[idx] = { from = old, to = stored }
		end
	end

	if next(changes) == nil then return end  -- nothing changed

	-- Record undo (before state)
	local undoChanges = {}
	for idx, ch in pairs(changes) do
		undoChanges[idx] = ch.from
	end
	pushUndo(player, panelId, undoChanges)

	-- Apply
	local newValues = {}
	for idx, ch in pairs(changes) do
		newValues[idx] = ch.to
	end
	applyChanges(player, panelId, newValues)

	firePaintDataUpdated(player, panelId)
end

local function fillPanel(player, panelId, colorId)
	local panelState = playerData[player] and playerData[player][panelId]
	if not panelState then return end

	local stored = storedColor(colorId)
	-- Record undo: snapshot all cells
	local undoChanges = {}
	for idx, c in pairs(panelState.cells) do
		undoChanges[idx] = c
	end
	pushUndo(player, panelId, undoChanges)

	-- Fill
	local newValues = {}
	for idx = 1, panelState.width * panelState.height do
		newValues[idx] = stored
	end
	applyChanges(player, panelId, newValues)

	firePaintDataUpdated(player, panelId)
end

local function clearPanel(player, panelId)
	fillPanel(player, panelId, PaintConfig.DEFAULT_COLOR_ID)
end

local function mirrorPanel(player, sourcePanelId)
	-- Find target from MirrorPairs
	local targetPanelId = nil
	for _, pair in ipairs(PaintPanelConfig.MirrorPairs) do
		if pair.source == sourcePanelId then
			targetPanelId = pair.target
			break
		end
	end
	if not targetPanelId then
		warn("PaintGridService.mirrorPanel: no mirror pair for", sourcePanelId)
		return
	end

	local srcState = playerData[player] and playerData[player][sourcePanelId]
	local tgtState = playerData[player] and playerData[player][targetPanelId]
	if not srcState or not tgtState then return end

	-- Horizontal flip: target column = (width + 1 - source column)
	-- Panels in a mirror pair share the same dimensions.
	local w = srcState.width
	local h = srcState.height

	-- Record undo for target
	local undoChanges = {}
	for idx, c in pairs(tgtState.cells) do
		undoChanges[idx] = c
	end
	-- We push the undo for the target panel; redo will be handled symmetrically.
	local undoEntry = { panelId = targetPanelId, changes = undoChanges }
	local stack = undoStacks[player]
	if stack then
		table.insert(stack, undoEntry)
		while #stack > PaintConfig.MAX_UNDO_HISTORY do
			table.remove(stack, 1)
		end
		redoStacks[player] = {}
	end

	-- Compute and apply mirrored values
	local newValues = {}
	for r = 1, h do
		for c = 1, w do
			local srcIdx = flatIndex(r, c, w)
			local tgtCol = (w + 1) - c
			local tgtIdx = flatIndex(r, tgtCol, w)
			newValues[tgtIdx] = srcState.cells[srcIdx] or PaintConfig.DEFAULT_COLOR_ID
		end
	end
	applyChanges(player, targetPanelId, newValues)

	firePaintDataUpdated(player, sourcePanelId)
	firePaintDataUpdated(player, targetPanelId)
end

local function undoPaint(player)
	local stack = undoStacks[player]
	if not stack or #stack == 0 then return end

	local entry   = table.remove(stack, #stack)
	local panelId = entry.panelId
	local panelState = playerData[player] and playerData[player][panelId]
	if not panelState then return end

	-- Build redo entry: current state of the affected indices
	local redoChanges = {}
	for idx, _ in pairs(entry.changes) do
		redoChanges[idx] = panelState.cells[idx]
	end
	local redoEntry = { panelId = panelId, changes = redoChanges }
	local rStack = redoStacks[player]
	if rStack then
		table.insert(rStack, redoEntry)
		while #rStack > PaintConfig.MAX_UNDO_HISTORY do
			table.remove(rStack, 1)
		end
	end

	applyChanges(player, panelId, entry.changes)
	firePaintDataUpdated(player, panelId)
end

local function redoPaint(player)
	local stack = redoStacks[player]
	if not stack or #stack == 0 then return end

	local entry   = table.remove(stack, #stack)
	local panelId = entry.panelId
	local panelState = playerData[player] and playerData[player][panelId]
	if not panelState then return end

	-- Build undo entry: current state of the affected indices
	local undoChanges = {}
	for idx, _ in pairs(entry.changes) do
		undoChanges[idx] = panelState.cells[idx]
	end
	local undoEntry = { panelId = panelId, changes = undoChanges }
	local uStack = undoStacks[player]
	if uStack then
		table.insert(uStack, undoEntry)
		while #uStack > PaintConfig.MAX_UNDO_HISTORY do
			table.remove(uStack, 1)
		end
	end

	applyChanges(player, panelId, entry.changes)
	firePaintDataUpdated(player, panelId)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Remote wiring
-- ──────────────────────────────────────────────────────────────────────────────

function PaintGridService.hookRemotes()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)

	local PaintStroke   = Remotes:WaitForChild("PaintStroke")
	local FillPanel     = Remotes:WaitForChild("FillPanel")
	local ClearPanel    = Remotes:WaitForChild("ClearPanel")
	local UndoPaint     = Remotes:WaitForChild("UndoPaint")
	local RedoPaint     = Remotes:WaitForChild("RedoPaint")
	local MirrorPanel   = Remotes:WaitForChild("MirrorPanel")
	PaintDataUpdated    = Remotes:WaitForChild("PaintDataUpdated")

	PaintStroke.OnServerEvent:Connect(function(player, data)
		if type(data) ~= "table" then return end
		local ok, err = PaintValidationService.validateStroke(
			player, data.PanelId, data.CellIndices, data.ColorId, data.BrushSize
		)
		if not ok then
			warn("PaintStroke rejected for", player.Name, ":", err)
			return
		end
		applyStroke(player, data.PanelId, data.CellIndices, data.ColorId)
	end)

	FillPanel.OnServerEvent:Connect(function(player, data)
		if type(data) ~= "table" then return end
		local ok, err = PaintValidationService.validateFill(player, data.PanelId, data.ColorId)
		if not ok then
			warn("FillPanel rejected for", player.Name, ":", err)
			return
		end
		fillPanel(player, data.PanelId, data.ColorId)
	end)

	ClearPanel.OnServerEvent:Connect(function(player, data)
		if type(data) ~= "table" then return end
		-- Clear uses DEFAULT_COLOR_ID; still validate basic access (role/phase/panel).
		local ok, err = PaintValidationService.validateFill(
			player, data.PanelId, PaintConfig.DEFAULT_COLOR_ID
		)
		if not ok then
			warn("ClearPanel rejected for", player.Name, ":", err)
			return
		end
		clearPanel(player, data.PanelId)
	end)

	UndoPaint.OnServerEvent:Connect(function(player)
		undoPaint(player)
	end)

	RedoPaint.OnServerEvent:Connect(function(player)
		redoPaint(player)
	end)

	MirrorPanel.OnServerEvent:Connect(function(player, data)
		if type(data) ~= "table" then return end
		-- Validate basic with a neutral colorId (Cream) — mirror doesn't change to a new color.
		local ok, err = PaintValidationService.validateBasic(
			player, data.sourcePanelId, PaintConfig.DEFAULT_COLOR_ID
		)
		if not ok then
			warn("MirrorPanel rejected for", player.Name, ":", err)
			return
		end
		mirrorPanel(player, data.sourcePanelId)
	end)

	-- Clean up when players leave mid-round
	Players.PlayerRemoving:Connect(function(player)
		playerData[player]  = nil
		undoStacks[player]  = nil
		redoStacks[player]  = nil
	end)
end

return PaintGridService
