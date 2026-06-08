-- PaintService: ModuleScript in ReplicatedStorage/Modules
-- Server-side: stores, validates, and applies per-player paint data.
--
-- TODO (future): Replace part.Color assignment with EditableImage texture
--   painting so players can paint detailed patterns onto each body part.
--   Hook point is marked below in applyPaint().
--
-- TODO (future): Add grid-based painting support — divide each body part
--   into an N×N grid, let clients paint individual cells, and composite
--   the grid into the EditableImage texture.

local RoundConfig = require(script.Parent.RoundConfig)

local PaintService = {}

-- { [Player]: { partName: Color3 } }
local paintData: { [Player]: { [string]: Color3 } } = {}

local WHITE = Color3.fromRGB(255, 255, 255)

-- ── Validation ────────────────────────────────────────────────────────────

local VALID_PARTS = {}
for _, name in ipairs(RoundConfig.PAINTABLE_PARTS) do
	VALID_PARTS[name] = true
end

local function isValidColor(v)
	return typeof(v) == "Color3"
		and v.R >= 0 and v.R <= 1
		and v.G >= 0 and v.G <= 1
		and v.B >= 0 and v.B <= 1
end

--[[
	submitPaint(player, data) → boolean
	data is the table received from the client:
	  { bodyColors = { Head=Color3, Torso=Color3, ... } }

	Returns true on success, false if validation fails.
	Invalid individual parts are silently defaulted to white (not rejected).
]]
function PaintService.submitPaint(player: Player, data: any): boolean
	if type(data) ~= "table" then
		warn("[PaintService] submitPaint: data is not a table from", player.Name)
		return false
	end
	if type(data.bodyColors) ~= "table" then
		warn("[PaintService] submitPaint: bodyColors missing from", player.Name)
		return false
	end

	local validated: { [string]: Color3 } = {}

	for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
		local color = data.bodyColors[partName]
		validated[partName] = isValidColor(color) and color or WHITE
	end

	paintData[player] = validated
	return true
end

--[[
	applyPaint(player)
	Applies the stored Color3 values to the player's character parts.
	If no paint was submitted the character remains white.
]]
function PaintService.applyPaint(player: Player)
	local data = paintData[player]
	if not data then return end

	local character = player.Character
	if not character then return end

	for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
		local color = data[partName] or WHITE
		local part  = character:FindFirstChild(partName)

		if part and part:IsA("BasePart") then
			-- ── Current: flat Color3 fill ──────────────────────────────────
			part.Color = color

			-- TODO: EditableImage hook — replace the line above with:
			--   PaintService._applyEditableImage(part, color, gridData)
			-- where gridData is an optional N×N cell table for pattern painting.
		end
	end
end

--[[
	resetPaint(player)
	Clears stored data and resets character to plain white.
]]
function PaintService.resetPaint(player: Player)
	paintData[player] = nil

	local character = player.Character
	if not character then return end

	for _, partName in ipairs(RoundConfig.PAINTABLE_PARTS) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = WHITE
		end
	end
end

--[[
	hasPaint(player) → boolean
	Returns true if the player has submitted paint data this round.
]]
function PaintService.hasPaint(player: Player): boolean
	return paintData[player] ~= nil
end

--[[
	clearAll()
	Wipes all stored paint data. Call at the end of every round.
]]
function PaintService.clearAll()
	table.clear(paintData)
end

return PaintService
