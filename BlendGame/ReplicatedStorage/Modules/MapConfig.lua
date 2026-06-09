-- MapConfig: ModuleScript in ReplicatedStorage/Modules
-- Lookup table for all available maps in Blend Game.
-- Maps are keyed by Id, which matches the folder name under Workspace/Maps.

local MapConfig = {}

-- ── Map definitions ───────────────────────────────────────────────────────────

MapConfig.Maps = {
	{
		Id            = "VintageHallway",
		DisplayName   = "Vintage Hallway",
		Difficulty    = "Medium",
		PreviewImage  = "rbxassetid://0",
		MaxPlayers    = 10,
		ThumbnailColor = Color3.fromRGB(120, 90, 60),
	},
	{
		Id            = "BirthdayRoom",
		DisplayName   = "Birthday Room",
		Difficulty    = "Easy",
		PreviewImage  = "rbxassetid://0",
		MaxPlayers    = 10,
		ThumbnailColor = Color3.fromRGB(240, 140, 180),
	},
	{
		Id            = "Kitchen",
		DisplayName   = "Kitchen",
		Difficulty    = "Hard",
		PreviewImage  = "rbxassetid://0",
		MaxPlayers    = 8,
		ThumbnailColor = Color3.fromRGB(200, 220, 230),
	},
	{
		Id            = "ToyRoom",
		DisplayName   = "Toy Room",
		Difficulty    = "Easy",
		PreviewImage  = "rbxassetid://0",
		MaxPlayers    = 10,
		ThumbnailColor = Color3.fromRGB(100, 180, 240),
	},
}

-- ── ById lookup ───────────────────────────────────────────────────────────────
-- Usage: MapConfig.ById["Kitchen"]  →  the Kitchen map entry

MapConfig.ById = {}
for _, map in ipairs(MapConfig.Maps) do
	MapConfig.ById[map.Id] = map
end

return MapConfig
