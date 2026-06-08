-- MapBuilder: Script in ServerScriptService
-- Procedural map generator for Blend Game.
-- Runs in Edit mode only — safe to keep in the game tree during live play.

if game:GetService("RunService"):IsRunning() then return end

local CollectionService = game:GetService("CollectionService")
local Workspace         = game:GetService("Workspace")

-- ── Constants ──────────────────────────────────────────────────────────────

local MAP_NAME = "VintageHallway"

-- Room dimensions (studs)
local ROOM_L = 80   -- X axis (length / long axis)
local ROOM_W = 20   -- Z axis (width)
local ROOM_H = 30   -- Y axis (height)

-- World origin: floor sits at Y=0, room is centred on X=0, Z=0
local FLOOR_Y    = 0
local CEILING_Y  = ROOM_H
local WALL_T     = 1      -- Wall / floor / ceiling thickness
local TILE_SIZE  = 4      -- Checkerboard tile edge length

-- ── Folder scaffolding ─────────────────────────────────────────────────────

-- Remove any previous build so re-running is idempotent
local mapsFolder = Workspace:FindFirstChild("Maps")
if mapsFolder then
	local prev = mapsFolder:FindFirstChild(MAP_NAME)
	if prev then prev:Destroy() end
else
	mapsFolder = Instance.new("Folder")
	mapsFolder.Name   = "Maps"
	mapsFolder.Parent = Workspace
end

local mapFolder = Instance.new("Folder")
mapFolder.Name   = MAP_NAME
mapFolder.Parent = mapsFolder

local function makeFolder(name, parent)
	local f = Instance.new("Folder")
	f.Name   = name
	f.Parent = parent or mapFolder
	return f
end

local floorFolder            = makeFolder("Floor")
local wallsFolder            = makeFolder("Walls")
local ceilingFolder          = makeFolder("Ceiling")
local propsFolder            = makeFolder("Props")
local hiderSpawnsFolder      = makeFolder("HiderSpawns")
local seekerSpawnsFolder     = makeFolder("SeekerSpawns")
local sampleableSurfsFolder  = makeFolder("SampleableSurfaces")

-- Map name tag
local mapNameVal = Instance.new("StringValue")
mapNameVal.Name   = "MapName"
mapNameVal.Value  = MAP_NAME
mapNameVal.Parent = mapFolder

-- ── Helpers ────────────────────────────────────────────────────────────────

local function makePart(parent, name, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Name         = name
	p.Size         = size
	p.CFrame       = cframe
	p.Color        = color or Color3.fromRGB(200, 200, 200)
	p.Material     = material or Enum.Material.SmoothPlastic
	p.Anchored     = true
	p.TopSurface   = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = transparency or 0
	p.CastShadow   = true
	p.Parent       = parent
	return p
end

-- Tag a part as Sampleable and register it in SampleableSurfaces
local function tagSampleable(part, baseColor, accentColor, patternType)
	CollectionService:AddTag(part, "Sampleable")

	part:SetAttribute("BaseColor",   baseColor   or Color3.fromRGB(255, 255, 255))
	part:SetAttribute("AccentColor", accentColor or Color3.fromRGB(0,   0,   0  ))
	part:SetAttribute("PatternType", patternType or "Solid")

	-- Mirror reference in SampleableSurfaces folder
	local ref = Instance.new("ObjectValue")
	ref.Name   = part.Name
	ref.Value  = part
	ref.Parent = sampleableSurfsFolder
end

-- Spawn marker: an invisible anchored part tagged for the game manager
local function makeSpawn(folder, name, cf)
	local p = Instance.new("Part")
	p.Name         = name
	p.Size         = Vector3.new(3, 0.2, 3)
	p.CFrame       = cf
	p.Anchored     = true
	p.CanCollide   = false
	p.Transparency = 0.8
	p.Color        = Color3.fromRGB(0, 200, 100)
	p.Material     = Enum.Material.Neon
	p.TopSurface   = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent       = folder
	CollectionService:AddTag(p, name:find("Hider") and "HiderSpawn" or "SeekerSpawn")
	return p
end

-- ── FLOOR: black-and-white checkerboard (4×4 tiles) ───────────────────────

local TILE_COUNT_X = ROOM_L / TILE_SIZE   -- 20 tiles along length
local TILE_COUNT_Z = ROOM_W / TILE_SIZE   -- 5 tiles across width
local BLACK = Color3.fromRGB(20,  20,  20)
local WHITE = Color3.fromRGB(240, 240, 240)

for tx = 0, TILE_COUNT_X - 1 do
	for tz = 0, TILE_COUNT_Z - 1 do
		local isBlack = (tx + tz) % 2 == 0
		local color   = isBlack and BLACK or WHITE
		local worldX  = -ROOM_L/2 + tx * TILE_SIZE + TILE_SIZE/2
		local worldZ  = -ROOM_W/2 + tz * TILE_SIZE + TILE_SIZE/2
		local worldY  = FLOOR_Y - WALL_T/2

		local tile = makePart(
			floorFolder,
			string.format("Tile_%d_%d", tx, tz),
			Vector3.new(TILE_SIZE, WALL_T, TILE_SIZE),
			CFrame.new(worldX, worldY, worldZ),
			color,
			Enum.Material.SmoothPlastic
		)
		tagSampleable(tile,
			color,
			isBlack and WHITE or BLACK,
			"Checker"
		)
	end
end

-- ── CEILING: off-white plaster ────────────────────────────────────────────

local CEILING_COLOR = Color3.fromRGB(235, 230, 220)

local ceiling = makePart(
	ceilingFolder,
	"Ceiling",
	Vector3.new(ROOM_L, WALL_T, ROOM_W),
	CFrame.new(0, CEILING_Y + WALL_T/2, 0),
	CEILING_COLOR,
	Enum.Material.SmoothPlastic
)
tagSampleable(ceiling, CEILING_COLOR, Color3.fromRGB(210, 205, 195), "Solid")

-- ── WALLS ──────────────────────────────────────────────────────────────────
-- TODO: Replace WallpaperGreen solid fill with a tiled texture / EditableImage
--       for detailed green-and-cream wallpaper pattern.

local WALL_COLOR   = Color3.fromRGB(88, 130, 90)   -- Muted Victorian green
local WALL_ACCENT  = Color3.fromRGB(200, 185, 150)  -- Cream trim accent

local wallMidY  = ROOM_H / 2
local wallThick = WALL_T

-- North wall  (Z = -ROOM_W/2)
local wallN = makePart(
	wallsFolder, "WallNorth",
	Vector3.new(ROOM_L, ROOM_H, wallThick),
	CFrame.new(0, wallMidY, -ROOM_W/2 - wallThick/2),
	WALL_COLOR, Enum.Material.SmoothPlastic
)
tagSampleable(wallN, WALL_COLOR, WALL_ACCENT, "Stripes")

-- South wall  (Z = +ROOM_W/2)
local wallS = makePart(
	wallsFolder, "WallSouth",
	Vector3.new(ROOM_L, ROOM_H, wallThick),
	CFrame.new(0, wallMidY,  ROOM_W/2 + wallThick/2),
	WALL_COLOR, Enum.Material.SmoothPlastic
)
tagSampleable(wallS, WALL_COLOR, WALL_ACCENT, "Stripes")

-- West end wall  (X = -ROOM_L/2)
local wallW = makePart(
	wallsFolder, "WallWest",
	Vector3.new(wallThick, ROOM_H, ROOM_W),
	CFrame.new(-ROOM_L/2 - wallThick/2, wallMidY, 0),
	WALL_COLOR, Enum.Material.SmoothPlastic
)
tagSampleable(wallW, WALL_COLOR, WALL_ACCENT, "Stripes")

-- East end wall  (X = +ROOM_L/2)
local wallE = makePart(
	wallsFolder, "WallEast",
	Vector3.new(wallThick, ROOM_H, ROOM_W),
	CFrame.new( ROOM_L/2 + wallThick/2, wallMidY, 0),
	WALL_COLOR, Enum.Material.SmoothPlastic
)
tagSampleable(wallE, WALL_COLOR, WALL_ACCENT, "Stripes")

-- Baseboard trim along North and South walls
local TRIM_COLOR = Color3.fromRGB(210, 195, 160)
for _, data in ipairs({
	{ name = "BaseboardN", z = -ROOM_W/2 - wallThick/2 },
	{ name = "BaseboardS", z =  ROOM_W/2 + wallThick/2 },
}) do
	makePart(
		wallsFolder, data.name,
		Vector3.new(ROOM_L, 2, wallThick + 0.2),
		CFrame.new(0, 1, data.z),
		TRIM_COLOR, Enum.Material.SmoothPlastic
	)
end

-- ── PROPS ──────────────────────────────────────────────────────────────────

-- ── 4 Picture frames (flat parts on North wall) ───────────────────────────
-- TODO: Replace BrickColor faces with SurfaceAppearance + EditableImage
--       to display actual painted artwork.

local FRAME_COLORS = {
	Color3.fromRGB(180, 120,  60),   -- warm gold
	Color3.fromRGB( 70,  90, 160),   -- blue
	Color3.fromRGB(140,  60,  60),   -- dark red
	Color3.fromRGB( 60, 130,  90),   -- dark green
}
local FRAME_X_POSITIONS = { -30, -10, 10, 30 }

for i, xPos in ipairs(FRAME_X_POSITIONS) do
	local frameGroup = Instance.new("Model")
	frameGroup.Name   = "PictureFrame" .. i
	frameGroup.Parent = propsFolder

	-- Backing (canvas)
	local canvas = makePart(
		frameGroup, "Canvas",
		Vector3.new(6, 5, 0.3),
		CFrame.new(xPos, 15, -ROOM_W/2 + 0.5),
		Color3.fromRGB(245, 235, 210),
		Enum.Material.SmoothPlastic
	)
	tagSampleable(canvas,
		Color3.fromRGB(245, 235, 210),
		FRAME_COLORS[i],
		"Solid"
	)

	-- Frame border
	local border = makePart(
		frameGroup, "Border",
		Vector3.new(6.8, 5.8, 0.2),
		CFrame.new(xPos, 15, -ROOM_W/2 + 0.45),
		FRAME_COLORS[i],
		Enum.Material.SmoothPlastic
	)
	tagSampleable(border,
		FRAME_COLORS[i],
		Color3.fromRGB(210, 175, 100),
		"Solid"
	)
end

-- ── 2 Curtains (near east and west ends) ─────────────────────────────────

local CURTAIN_COLOR = Color3.fromRGB(100, 20, 20)

for i, xPos in ipairs({ -ROOM_L/2 + 6, ROOM_L/2 - 6 }) do
	-- Two curtain panels per end (one each side of wall centre)
	for _, side in ipairs({ -3, 3 }) do
		local curtain = makePart(
			propsFolder,
			"Curtain" .. i .. (side < 0 and "L" or "R"),
			Vector3.new(3, 22, 0.8),
			CFrame.new(xPos + side * 0.5, 11, ROOM_W/2 - 1),
			CURTAIN_COLOR,
			Enum.Material.SmoothPlastic
		)
		tagSampleable(curtain,
			CURTAIN_COLOR,
			Color3.fromRGB(60, 10, 10),
			"Solid"
		)
	end

	-- Curtain rod
	makePart(
		propsFolder,
		"CurtainRod" .. i,
		Vector3.new(10, 0.4, 0.4),
		CFrame.new(xPos, 23, ROOM_W/2 - 1),
		Color3.fromRGB(160, 130, 80),
		Enum.Material.Metal
	)
end

-- ── 3 Floor lamps ─────────────────────────────────────────────────────────

local LAMP_X_POSITIONS = { -24, 0, 24 }
local LAMP_BASE_COLOR  = Color3.fromRGB(60, 50, 40)
local LAMP_SHADE_COLOR = Color3.fromRGB(240, 200, 120)

for i, xPos in ipairs(LAMP_X_POSITIONS) do
	local lampGroup = Instance.new("Model")
	lampGroup.Name   = "Lamp" .. i
	lampGroup.Parent = propsFolder

	-- Pole (cylinder)
	local pole = Instance.new("Part")
	pole.Name         = "Pole"
	pole.Shape        = Enum.PartType.Cylinder
	pole.Size         = Vector3.new(12, 0.5, 0.5)
	pole.CFrame       = CFrame.new(xPos, 6, ROOM_W/2 - 2)
		* CFrame.Angles(0, 0, math.rad(90))
	pole.Color        = LAMP_BASE_COLOR
	pole.Material     = Enum.Material.Metal
	pole.Anchored     = true
	pole.TopSurface   = Enum.SurfaceType.Smooth
	pole.BottomSurface = Enum.SurfaceType.Smooth
	pole.Parent       = lampGroup

	-- Base disc
	local base = Instance.new("Part")
	base.Name         = "Base"
	base.Shape        = Enum.PartType.Cylinder
	base.Size         = Vector3.new(0.6, 2, 2)
	base.CFrame       = CFrame.new(xPos, 0.3, ROOM_W/2 - 2)
		* CFrame.Angles(0, 0, math.rad(90))
	base.Color        = LAMP_BASE_COLOR
	base.Material     = Enum.Material.Metal
	base.Anchored     = true
	base.TopSurface   = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent       = lampGroup

	-- Shade (sphere, slightly emissive)
	local shade = Instance.new("Part")
	shade.Name         = "Shade"
	shade.Shape        = Enum.PartType.Ball
	shade.Size         = Vector3.new(3, 3, 3)
	shade.CFrame       = CFrame.new(xPos, 13, ROOM_W/2 - 2)
	shade.Color        = LAMP_SHADE_COLOR
	shade.Material     = Enum.Material.Neon
	shade.Transparency = 0.3
	shade.Anchored     = true
	shade.CastShadow   = false
	shade.Parent       = lampGroup

	tagSampleable(shade, LAMP_SHADE_COLOR, Color3.fromRGB(255, 230, 150), "Solid")
end

-- ── 2 Vases ───────────────────────────────────────────────────────────────

local VASE_COLOR     = Color3.fromRGB(0, 140, 150)
local VASE_POSITIONS = {
	Vector3.new(-ROOM_L/2 + 8, 0, 0),
	Vector3.new( ROOM_L/2 - 8, 0, 0),
}

for i, pos in ipairs(VASE_POSITIONS) do
	local vaseGroup = Instance.new("Model")
	vaseGroup.Name   = "Vase" .. i
	vaseGroup.Parent = propsFolder

	-- Body
	local body = Instance.new("Part")
	body.Name         = "Body"
	body.Shape        = Enum.PartType.Cylinder
	body.Size         = Vector3.new(5, 2.5, 2.5)
	body.CFrame       = CFrame.new(pos.X, 2.5, pos.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	body.Color        = VASE_COLOR
	body.Material     = Enum.Material.SmoothPlastic
	body.Anchored     = true
	body.TopSurface   = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent       = vaseGroup

	tagSampleable(body, VASE_COLOR, Color3.fromRGB(0, 100, 110), "Solid")

	-- Neck (narrower cylinder)
	local neck = Instance.new("Part")
	neck.Name         = "Neck"
	neck.Shape        = Enum.PartType.Cylinder
	neck.Size         = Vector3.new(2, 1.2, 1.2)
	neck.CFrame       = CFrame.new(pos.X, 6, pos.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	neck.Color        = VASE_COLOR
	neck.Material     = Enum.Material.SmoothPlastic
	neck.Anchored     = true
	neck.TopSurface   = Enum.SurfaceType.Smooth
	neck.BottomSurface = Enum.SurfaceType.Smooth
	neck.Parent       = vaseGroup
end

-- ── Central rug ───────────────────────────────────────────────────────────

local RUG_COLOR    = Color3.fromRGB(110, 20, 20)
local BORDER_COLOR = Color3.fromRGB(170, 130, 60)

-- Rug body
local rug = makePart(
	propsFolder, "Rug",
	Vector3.new(30, 0.2, 12),
	CFrame.new(0, 0.1, 0),
	RUG_COLOR, Enum.Material.SmoothPlastic
)
tagSampleable(rug, RUG_COLOR, BORDER_COLOR, "Stripes")

-- Rug border (slightly larger, sits underneath)
makePart(
	propsFolder, "RugBorder",
	Vector3.new(32, 0.18, 14),
	CFrame.new(0, 0.09, 0),
	BORDER_COLOR, Enum.Material.SmoothPlastic
)

-- ── Balloons (spheres near ceiling) ──────────────────────────────────────

local BALLOON_CONFIGS = {
	{ x = -28, z = -4,  color = Color3.fromRGB(255, 60,  60)  },
	{ x = -14, z =  5,  color = Color3.fromRGB(60,  120, 255) },
	{ x =   0, z = -6,  color = Color3.fromRGB(80,  220, 80)  },
	{ x =  14, z =  4,  color = Color3.fromRGB(255, 200, 40)  },
	{ x =  28, z = -3,  color = Color3.fromRGB(220, 60,  220) },
	{ x = -35, z =  2,  color = Color3.fromRGB(255, 140, 40)  },
	{ x =  35, z = -5,  color = Color3.fromRGB(80,  230, 230) },
}

for i, cfg in ipairs(BALLOON_CONFIGS) do
	local balloonGroup = Instance.new("Model")
	balloonGroup.Name   = "Balloon" .. i
	balloonGroup.Parent = propsFolder

	-- Balloon sphere (near ceiling, slight random height variation)
	local yOffset = CEILING_Y - 3 - (i % 3) * 1.5
	local balloon = Instance.new("Part")
	balloon.Name         = "Sphere"
	balloon.Shape        = Enum.PartType.Ball
	balloon.Size         = Vector3.new(2.5, 2.5, 2.5)
	balloon.CFrame       = CFrame.new(cfg.x, yOffset, cfg.z)
	balloon.Color        = cfg.color
	balloon.Material     = Enum.Material.SmoothPlastic
	balloon.Anchored     = true
	balloon.CastShadow   = false
	balloon.TopSurface   = Enum.SurfaceType.Smooth
	balloon.BottomSurface = Enum.SurfaceType.Smooth
	balloon.Parent       = balloonGroup

	tagSampleable(balloon, cfg.color, cfg.color:Lerp(Color3.new(0,0,0), 0.2), "Solid")

	-- String (thin vertical part)
	local stringH = yOffset - 1.8
	makePart(
		balloonGroup,
		"String",
		Vector3.new(0.1, stringH, 0.1),
		CFrame.new(cfg.x, stringH/2, cfg.z),
		Color3.fromRGB(200, 200, 200),
		Enum.Material.SmoothPlastic
	)
end

-- ── HIDER SPAWNS (6 positions spread across the map) ─────────────────────
-- Placed at floor level (Y=0.5) so characters land correctly.

local HIDER_SPAWNS = {
	CFrame.new(-32, 0.5, -6),
	CFrame.new(-16, 0.5,  6),
	CFrame.new(  0, 0.5, -6),
	CFrame.new( 16, 0.5,  6),
	CFrame.new( 32, 0.5, -6),
	CFrame.new( -8, 0.5,  0),
}

for i, cf in ipairs(HIDER_SPAWNS) do
	makeSpawn(hiderSpawnsFolder, "HiderSpawn" .. i, cf)
end

-- ── SEEKER SPAWNS (2 positions at the west end) ───────────────────────────

local SEEKER_SPAWNS = {
	CFrame.new(-ROOM_L/2 + 5, 0.5, -4),
	CFrame.new(-ROOM_L/2 + 5, 0.5,  4),
}

for i, cf in ipairs(SEEKER_SPAWNS) do
	makeSpawn(seekerSpawnsFolder, "SeekerSpawn" .. i, cf)
end

-- ── Done ──────────────────────────────────────────────────────────────────

print(MAP_NAME .. " built successfully")
print(string.format(
	"  Floor tiles: %d | Props: %d | Sampleable surfaces: %d",
	TILE_COUNT_X * TILE_COUNT_Z,
	#propsFolder:GetChildren(),
	#sampleableSurfsFolder:GetChildren()
))
