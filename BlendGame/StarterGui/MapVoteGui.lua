-- MapVoteGui: LocalScript in StarterGui
-- Shows 4 map cards during the MapVote phase. Players click to vote.
-- Live vote counts update via MapVoteUpdated. Winner announced via MapVoteEnded.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

local Remotes        = ReplicatedStorage:WaitForChild("Remotes", 30)
local MapVoteStarted = Remotes:WaitForChild("MapVoteStarted") :: RemoteEvent
local SubmitMapVote  = Remotes:WaitForChild("SubmitMapVote")  :: RemoteEvent
local MapVoteUpdated = Remotes:WaitForChild("MapVoteUpdated") :: RemoteEvent
local MapVoteEnded   = Remotes:WaitForChild("MapVoteEnded")   :: RemoteEvent

-- ── Build ScreenGui ────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name         = "MapVoteGui"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 8
gui.Parent       = playerGui

-- ── Helpers ────────────────────────────────────────────────────────────────

local function corner(parent, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = parent
end
local function stroke(parent, color, t)
	local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = t; s.Parent = parent
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	for k, v in pairs(props) do l[k] = v end
	l.BackgroundTransparency = 1
	l.Parent = parent
	return l
end

-- ── Root container ─────────────────────────────────────────────────────────

local root = Instance.new("Frame")
root.Name             = "Root"
root.Size             = UDim2.new(0, 700, 0, 420)
root.Position         = UDim2.new(0.5, -350, 0.5, -210)
root.BackgroundColor3 = Color3.fromRGB(12, 10, 22)
root.BorderSizePixel  = 0
root.Parent           = gui
corner(root, 18)
stroke(root, Color3.fromRGB(80, 50, 160), 2)

-- Header
local header = Instance.new("Frame")
header.Size            = UDim2.new(1, 0, 0, 60)
header.BackgroundColor3 = Color3.fromRGB(40, 22, 100)
header.BorderSizePixel = 0
header.Parent          = root
corner(header, 18)
local headerMask = Instance.new("Frame")
headerMask.Size            = UDim2.new(1, 0, 0, 18)
headerMask.Position        = UDim2.new(0, 0, 1, -18)
headerMask.BackgroundColor3 = Color3.fromRGB(40, 22, 100)
headerMask.BorderSizePixel = 0
headerMask.Parent          = header

label(header, {
	Size = UDim2.new(0.6, 0, 1, 0),
	Position = UDim2.new(0, 18, 0, 0),
	TextColor3 = Color3.fromRGB(255, 230, 60),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🗺  VOTE FOR A MAP",
})

local timerLbl = label(header, {
	Name = "Timer",
	Size = UDim2.new(0, 100, 1, 0),
	Position = UDim2.new(1, -114, 0, 0),
	TextColor3 = Color3.fromRGB(100, 240, 140),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "0:20",
})

-- Card grid
local cardArea = Instance.new("Frame")
cardArea.Name             = "CardArea"
cardArea.Size             = UDim2.new(1, -32, 1, -80)
cardArea.Position         = UDim2.new(0, 16, 0, 68)
cardArea.BackgroundTransparency = 1
cardArea.Parent           = root

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize      = UDim2.new(0.5, -8, 1, -8)
gridLayout.CellPadding   = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder     = Enum.SortOrder.LayoutOrder
gridLayout.Parent        = cardArea

-- ── Winner overlay ─────────────────────────────────────────────────────────

local winnerOverlay = Instance.new("Frame")
winnerOverlay.Name             = "WinnerOverlay"
winnerOverlay.Size             = UDim2.new(1, 0, 1, 0)
winnerOverlay.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
winnerOverlay.BackgroundTransparency = 0.1
winnerOverlay.BorderSizePixel  = 0
winnerOverlay.ZIndex           = 5
winnerOverlay.Visible          = false
winnerOverlay.Parent           = root

label(winnerOverlay, {
	Name = "WinLabel",
	Size = UDim2.new(1, 0, 0, 60),
	Position = UDim2.new(0, 0, 0.35, 0),
	TextColor3 = Color3.fromRGB(255, 230, 60),
	Font = Enum.Font.GothamBold,
	TextSize = 28,
	Text = "⭐  LOADING MAP...",
})
label(winnerOverlay, {
	Name = "MapNameLabel",
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.new(0, 0, 0.55, 0),
	TextColor3 = Color3.fromRGB(200, 200, 255),
	Font = Enum.Font.Gotham,
	TextSize = 20,
	Text = "",
})

-- ── Card builder ───────────────────────────────────────────────────────────

local DIFF_COLORS = {
	Easy   = Color3.fromRGB(80, 220, 100),
	Medium = Color3.fromRGB(255, 200, 40),
	Hard   = Color3.fromRGB(255, 80, 80),
}

local cardFrames:     { [string]: Frame }      = {}
local voteCountLabels:{ [string]: TextLabel }  = {}
local myVote:          string?                 = nil
local timerConn:       RBXScriptConnection?    = nil

local function buildCard(mapData: any, order: number): Frame
	local card = Instance.new("Frame")
	card.Name            = "Card_" .. mapData.Id
	card.BackgroundColor3 = (mapData.ThumbnailColor or Color3.fromRGB(40, 30, 80))
		:Lerp(Color3.new(0,0,0), 0.5)
	card.BorderSizePixel = 0
	card.LayoutOrder     = order
	card.Parent          = cardArea
	corner(card, 12)

	-- Clickable overlay
	local btn = Instance.new("TextButton")
	btn.Size              = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text              = ""
	btn.ZIndex            = 2
	btn.Parent            = card

	-- Thumbnail color block (top half)
	local thumb = Instance.new("Frame")
	thumb.Name            = "Thumb"
	thumb.Size            = UDim2.new(1, 0, 0.5, 0)
	thumb.BackgroundColor3 = mapData.ThumbnailColor or Color3.fromRGB(60, 50, 120)
	thumb.BorderSizePixel = 0
	thumb.Parent          = card
	corner(thumb, 12)
	-- TODO: replace with ImageLabel using mapData.PreviewImage when assets are ready

	-- Map name
	label(card, {
		Size = UDim2.new(1, -12, 0, 28),
		Position = UDim2.new(0, 6, 0.5, 4),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = mapData.DisplayName,
	})

	-- Difficulty badge
	local diffColor = DIFF_COLORS[mapData.Difficulty] or Color3.fromRGB(200, 200, 200)
	local diffBadge = Instance.new("Frame")
	diffBadge.Size            = UDim2.new(0, 70, 0, 20)
	diffBadge.Position        = UDim2.new(0, 6, 0.5, 34)
	diffBadge.BackgroundColor3 = diffColor:Lerp(Color3.new(0,0,0), 0.4)
	diffBadge.BorderSizePixel = 0
	diffBadge.Parent          = card
	corner(diffBadge, 5)
	label(diffBadge, {
		Size = UDim2.new(1, 0, 1, 0),
		TextColor3 = diffColor,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Text = mapData.Difficulty,
	})

	-- Vote count
	local voteCount = label(card, {
		Name = "VoteCount",
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.new(0, 6, 1, -26),
		TextColor3 = Color3.fromRGB(200, 190, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0 votes",
	})
	voteCountLabels[mapData.Id] = voteCount

	-- Selected border (shown when this is the player's vote)
	local selStroke = Instance.new("UIStroke")
	selStroke.Color     = Color3.fromRGB(255, 230, 60)
	selStroke.Thickness = 0
	selStroke.Parent    = card

	-- Click handler
	btn.MouseButton1Click:Connect(function()
		if myVote == mapData.Id then return end  -- Already voted for this
		myVote = mapData.Id

		-- Update all card borders
		for id, cf in pairs(cardFrames) do
			local st = cf:FindFirstChildOfClass("UIStroke")
			if st then st.Thickness = (id == mapData.Id) and 3 or 0 end
		end

		SubmitMapVote:FireServer(mapData.Id)
	end)

	cardFrames[mapData.Id] = card
	return card
end

-- ── Phase listeners ────────────────────────────────────────────────────────

local function resetGui()
	-- Clear previous cards
	for _, child in ipairs(cardArea:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	table.clear(cardFrames)
	table.clear(voteCountLabels)
	myVote              = nil
	winnerOverlay.Visible = false
end

MapVoteStarted.OnClientEvent:Connect(function(
	choices: { any },
	duration: number,
	endsAt: number
)
	resetGui()
	gui.Enabled = true

	-- Build one card per map choice
	for i, mapData in ipairs(choices) do
		buildCard(mapData, i)
	end

	-- Countdown timer
	if timerConn then timerConn:Disconnect() end
	timerConn = RunService.Heartbeat:Connect(function()
		local rem = endsAt - workspace:GetServerTimeNow()
		if rem <= 0 then
			timerLbl.Text       = "0:00"
			timerLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
			if timerConn then timerConn:Disconnect(); timerConn = nil end
			return
		end
		local s = math.floor(rem)
		timerLbl.Text = string.format("0:%02d", s)
		timerLbl.TextColor3 = rem <= 5
			and Color3.fromRGB(255, 60, 60)
			or  Color3.fromRGB(100, 240, 140)
	end)
end)

MapVoteUpdated.OnClientEvent:Connect(function(counts: { [string]: number })
	for mapId, count in pairs(counts) do
		local lbl = voteCountLabels[mapId]
		if lbl then
			lbl.Text = count == 1 and "1 vote" or (count .. " votes")
		end
	end
end)

MapVoteEnded.OnClientEvent:Connect(function(winner: any)
	if timerConn then timerConn:Disconnect(); timerConn = nil end

	-- Show winner overlay briefly
	winnerOverlay.Visible = true
	local wLabel = winnerOverlay:FindFirstChild("WinLabel") :: TextLabel
	local mLabel = winnerOverlay:FindFirstChild("MapNameLabel") :: TextLabel
	if wLabel then wLabel.Text    = "⭐  MAP SELECTED!" end
	if mLabel then mLabel.Text    = winner.DisplayName  end

	task.delay(3, function()
		gui.Enabled = false
		resetGui()
	end)
end)
