-- PaintValidationService: ModuleScript in ServerScriptService
-- Validates incoming paint requests server-side before applying them to the grid.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local PaintConfig      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PaintConfig"))
local PaintPanelConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PaintPanelConfig"))
local PaintColorConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PaintColorConfig"))
local RoleService      = require(ServerScriptService:WaitForChild("RoleService"))
local PoseService      = require(ServerScriptService:WaitForChild("PoseService"))

local PaintValidationService = {}

local currentPhase = nil

-- Called by GameManager / PaintGridService at each phase transition.
function PaintValidationService.setPhase(phase: string)
	currentPhase = phase
end

--[[
	validateBasic: checks role, phase, panelId, colorId.
	Returns ok (bool), err (string or nil).
--]]
function PaintValidationService.validateBasic(player, panelId, colorId)
	-- Role check
	local role = RoleService.getRole(player)
	if role ~= "Hider" then
		return false, "Player is not a Hider (role=" .. tostring(role) .. ")"
	end

	-- Phase check
	if not currentPhase or not PaintConfig.ALLOWED_PHASES[currentPhase] then
		return false, "Painting not allowed in phase: " .. tostring(currentPhase)
	end

	-- Panel check
	if not PaintPanelConfig.ValidPanelIds[panelId] then
		return false, "Invalid panelId: " .. tostring(panelId)
	end

	-- Color check (valid color OR eraser)
	if not PaintColorConfig.ValidColorIds[colorId] and colorId ~= PaintColorConfig.ERASER_ID then
		return false, "Invalid colorId: " .. tostring(colorId)
	end

	return true, nil
end

--[[
	validateStroke: validates a brush stroke.
	data.brushRadius must be <= MAX_BRUSH_SIZE_RADIUS.
	cellIndices count must be <= MAX_CELLS_PER_STROKE.
	Each index must be in [1, width*height].
	Player must not be pose-locked.
--]]
function PaintValidationService.validateStroke(player, panelId, cellIndices, colorId, brushRadius)
	local ok, err = PaintValidationService.validateBasic(player, panelId, colorId)
	if not ok then return false, err end

	-- Pose lock check
	if PoseService.isLocked(player) then
		return false, "Player is pose-locked"
	end

	-- Brush radius
	if type(brushRadius) ~= "number" or brushRadius > PaintConfig.MAX_BRUSH_SIZE_RADIUS or brushRadius < 0 then
		return false, "Invalid brushRadius: " .. tostring(brushRadius)
	end

	-- Cell count
	if type(cellIndices) ~= "table" then
		return false, "cellIndices must be a table"
	end
	if #cellIndices > PaintConfig.MAX_CELLS_PER_STROKE then
		return false, string.format("Too many cells in stroke: %d (max %d)", #cellIndices, PaintConfig.MAX_CELLS_PER_STROKE)
	end

	-- Index range
	local panel = PaintPanelConfig.Panels[panelId]
	local maxIndex = panel.Width * panel.Height
	for _, idx in ipairs(cellIndices) do
		if type(idx) ~= "number" or idx < 1 or idx > maxIndex or idx ~= math.floor(idx) then
			return false, "Cell index out of range or non-integer: " .. tostring(idx)
		end
	end

	return true, nil
end

--[[
	validateFill: validates a fill-panel request.
	Player must not be pose-locked.
--]]
function PaintValidationService.validateFill(player, panelId, colorId)
	local ok, err = PaintValidationService.validateBasic(player, panelId, colorId)
	if not ok then return false, err end

	if PoseService.isLocked(player) then
		return false, "Player is pose-locked"
	end

	return true, nil
end

return PaintValidationService
