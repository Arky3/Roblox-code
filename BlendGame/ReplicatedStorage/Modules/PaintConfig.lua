-- PaintConfig: ModuleScript in ReplicatedStorage/Modules
-- Top-level constants for the grid-based painting system.

local PaintConfig = {}

-- Phases where painting is permitted (server checks these)
PaintConfig.ALLOWED_PHASES = { Paint = true, PoseLock = true }

-- Default (eraser) body color — off-white
PaintConfig.DEFAULT_COLOR    = Color3.fromRGB(242, 235, 220)
PaintConfig.DEFAULT_COLOR_ID = "Cream"

-- Brush radius: 0 = 1 cell, 1 = 3x3, 2 = 5x5 (circle-clipped)
PaintConfig.MAX_BRUSH_SIZE_RADIUS = 2

-- Server rejects strokes with more than this many cells
PaintConfig.MAX_CELLS_PER_STROKE = 200

-- Client undo history depth
PaintConfig.MAX_UNDO_HISTORY = 20

-- How often (seconds) the client flushes a drag-stroke to the server
PaintConfig.STROKE_SEND_INTERVAL = 0.08

-- Canvas pixel size per grid cell (used by the SurfaceGui 3D preview)
PaintConfig.SURFACE_CELL_PX = 12

PaintConfig.BRUSH_SIZES = {
	{ Id = "Small",  Label = "S",  Radius = 0 },
	{ Id = "Medium", Label = "M",  Radius = 1 },
	{ Id = "Large",  Label = "L",  Radius = 2 },
}

-- Tools available in the UI
PaintConfig.TOOLS = {
	"Brush", "Fill", "Eraser", "Eyedropper",
	"Undo",  "Redo", "Clear",  "Mirror",
}

return PaintConfig
