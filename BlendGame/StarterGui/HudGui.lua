-- HudGui: LocalScript in StarterGui
-- Persistent heads-up display shown to all players throughout the game.
-- Displays: phase banner, countdown timer, role badge, score, elimination feed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── Remotes & config ───────────────────────────────────────────────────────
local Remotes           = ReplicatedStorage:WaitForChild("Remotes", 30)
local RoundStateChanged = Remotes:WaitForChild("RoundStateChanged") :: RemoteEvent
local RoleAssigned      = Remotes:WaitForChild("RoleAssigned")      :: RemoteEvent
local PlayerEliminated  = Remotes:WaitForChild("PlayerEliminated")  :: RemoteEvent
local RoundResults      = Remotes:WaitForChild("RoundResults")      :: RemoteEvent

-- ── State ──────────────────────────────────────────────────────────────────
local currentRole  = "Spectator"
local currentPhase = "Lobby"
local phaseEndsAt  = 0
local timerConn: RBXScriptConnection? = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

local function makeCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent       = parent
end

-- ── Build ScreenGui ────────────────────────────────────────────────────────

local hudGui = Instance.new("ScreenGui")
hudGui.Name         = "HudGui"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 5
hudGui.Parent       = playerGui

-- ═══════════════════════════════════════════════════════════════════════════
-- TOP BAR  (phase name + timer + role badge)
-- ═══════════════════════════════════════════════════════════════════════════

local topBar = Instance.new("Frame")
topBar.Name            = "TopBar"
topBar.Size            = UDim2.new(0, 500, 0, 50)
topBar.Position        = UDim2.new(0.5, -250, 0, 10)
topBar.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
topBar.BorderSizePixel = 0
topBar.Parent          = hudGui
makeCorner(topBar, 12)

local topStroke = Instance.new("UIStroke")
topStroke.Color     = Color3.fromRGB(60, 40, 130)
topStroke.Thickness = 1
topStroke.Parent    = topBar

-- Phase name label (left)
local phaseLbl = Instance.new("TextLabel")
phaseLbl.Name                   = "Phase"
phaseLbl.Size                   = UDim2.new(0.5, 0, 1, 0)
phaseLbl.BackgroundTransparency = 1
phaseLbl.TextColor3             = Color3.fromRGB(255, 230, 60)
phaseLbl.Font                   = Enum.Font.GothamBold
phaseLbl.TextSize               = 18
phaseLbl.TextXAlignment         = Enum.TextXAlignment.Left
phaseLbl.Position               = UDim2.new(0, 14, 0, 0)
phaseLbl.Text                   = "LOBBY"
phaseLbl.Parent                 = topBar

-- Countdown timer (centre)
local countdownLbl = Instance.new("TextLabel")
countdownLbl.Name                   = "Countdown"
countdownLbl.Size                   = UDim2.new(0, 80, 1, 0)
countdownLbl.Position               = UDim2.new(0.5, -40, 0, 0)
countdownLbl.BackgroundTransparency = 1
countdownLbl.TextColor3             = Color3.fromRGB(200, 200, 220)
countdownLbl.Font                   = Enum.Font.GothamBold
countdownLbl.TextSize               = 20
countdownLbl.Text                   = "--:--"
countdownLbl.Parent                 = topBar

-- Role badge (right)
local roleBadge = Instance.new("Frame")
roleBadge.Name            = "RoleBadge"
roleBadge.Size            = UDim2.new(0, 100, 0, 32)
roleBadge.Position        = UDim2.new(1, -112, 0.5, -16)
roleBadge.BackgroundColor3 = Color3.fromRGB(50, 30, 120)
roleBadge.BorderSizePixel = 0
roleBadge.Parent          = topBar
makeCorner(roleBadge, 8)

local roleLbl = Instance.new("TextLabel")
roleLbl.Name                   = "RoleLabel"
roleLbl.Size                   = UDim2.new(1, 0, 1, 0)
roleLbl.BackgroundTransparency = 1
roleLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
roleLbl.Font                   = Enum.Font.GothamBold
roleLbl.TextSize               = 14
roleLbl.Text                   = "SPECTATOR"
roleLbl.Parent                 = roleBadge

-- ═══════════════════════════════════════════════════════════════════════════
-- SCORE DISPLAY  (bottom-left)
-- ═══════════════════════════════════════════════════════════════════════════

local scoreFrame = Instance.new("Frame")
scoreFrame.Name            = "ScoreFrame"
scoreFrame.Size            = UDim2.new(0, 160, 0, 54)
scoreFrame.Position        = UDim2.new(0, 12, 1, -66)
scoreFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent          = hudGui
makeCorner(scoreFrame, 10)

local scoreHeaderLbl = Instance.new("TextLabel")
scoreHeaderLbl.Size                   = UDim2.new(1, 0, 0, 22)
scoreHeaderLbl.BackgroundTransparency = 1
scoreHeaderLbl.TextColor3             = Color3.fromRGB(180, 160, 220)
scoreHeaderLbl.Font                   = Enum.Font.GothamBold
scoreHeaderLbl.TextSize               = 12
scoreHeaderLbl.Text                   = "YOUR SCORE"
scoreHeaderLbl.Parent                 = scoreFrame

local scoreLbl = Instance.new("TextLabel")
scoreLbl.Name                   = "Score"
scoreLbl.Size                   = UDim2.new(1, 0, 0, 30)
scoreLbl.Position               = UDim2.new(0, 0, 0, 20)
scoreLbl.BackgroundTransparency = 1
scoreLbl.TextColor3             = Color3.fromRGB(255, 230, 60)
scoreLbl.Font                   = Enum.Font.GothamBold
scoreLbl.TextSize               = 22
scoreLbl.Text                   = "0"
scoreLbl.Parent                 = scoreFrame

-- ═══════════════════════════════════════════════════════════════════════════
-- ELIMINATION FEED  (right side, stacked)
-- ═══════════════════════════════════════════════════════════════════════════

local feedFrame = Instance.new("Frame")
feedFrame.Name              = "EliminationFeed"
feedFrame.Size              = UDim2.new(0, 280, 0, 200)
feedFrame.Position          = UDim2.new(1, -292, 0.5, -100)
feedFrame.BackgroundTransparency = 1
feedFrame.Parent            = hudGui

local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding          = UDim.new(0, 6)
feedLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
feedLayout.SortOrder        = Enum.SortOrder.LayoutOrder
feedLayout.Parent           = feedFrame

local feedEntryCounter = 0

local function addFeedEntry(text: string, color: Color3)
	feedEntryCounter += 1

	local entry = Instance.new("Frame")
	entry.Name            = "Entry_" .. feedEntryCounter
	entry.Size            = UDim2.new(1, 0, 0, 30)
	entry.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
	entry.BackgroundTransparency = 0.15
	entry.BorderSizePixel = 0
	entry.LayoutOrder     = feedEntryCounter
	entry.Parent          = feedFrame
	makeCorner(entry, 6)

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, -12, 1, 0)
	lbl.Position               = UDim2.new(0, 6, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = color
	lbl.Font                   = Enum.Font.Gotham
	lbl.TextSize               = 13
	lbl.TextXAlignment         = Enum.TextXAlignment.Left
	lbl.Text                   = text
	lbl.TextTruncate           = Enum.TextTruncate.AtEnd
	lbl.Parent                 = entry

	-- Auto-remove after 5 seconds
	task.delay(5, function()
		if entry and entry.Parent then
			entry:Destroy()
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- WRONG-CLICK PENALTY FLASH  (full-screen red vignette)
-- ═══════════════════════════════════════════════════════════════════════════

local penaltyFlash = Instance.new("Frame")
penaltyFlash.Name              = "PenaltyFlash"
penaltyFlash.Size              = UDim2.new(1, 0, 1, 0)
penaltyFlash.BackgroundColor3  = Color3.fromRGB(200, 30, 30)
penaltyFlash.BackgroundTransparency = 1
penaltyFlash.BorderSizePixel   = 0
penaltyFlash.ZIndex            = 20
penaltyFlash.Parent            = hudGui

local penaltyLbl = Instance.new("TextLabel")
penaltyLbl.Size                   = UDim2.new(0, 300, 0, 60)
penaltyLbl.Position               = UDim2.new(0.5, -150, 0.5, -30)
penaltyLbl.BackgroundTransparency = 1
penaltyLbl.TextColor3             = Color3.fromRGB(255, 80, 80)
penaltyLbl.Font                   = Enum.Font.GothamBold
penaltyLbl.TextSize               = 26
penaltyLbl.Text                   = "✗  WRONG CLICK  –15"
penaltyLbl.TextTransparency       = 1
penaltyLbl.ZIndex                 = 21
penaltyLbl.Parent                 = hudGui

local flashActive = false

local function showPenaltyFlash()
	if flashActive then return end
	flashActive = true

	-- Fade in
	penaltyFlash.BackgroundTransparency = 0.6
	penaltyLbl.TextTransparency         = 0

	task.delay(0.8, function()
		-- Fade out
		penaltyFlash.BackgroundTransparency = 1
		penaltyLbl.TextTransparency         = 1
		flashActive = false
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RESULTS SCREEN  (overlay shown during Results phase)
-- ═══════════════════════════════════════════════════════════════════════════

local resultsOverlay = Instance.new("Frame")
resultsOverlay.Name              = "ResultsOverlay"
resultsOverlay.Size              = UDim2.new(0, 440, 0, 460)
resultsOverlay.Position          = UDim2.new(0.5, -220, 0.5, -230)
resultsOverlay.BackgroundColor3  = Color3.fromRGB(12, 10, 22)
resultsOverlay.BorderSizePixel   = 0
resultsOverlay.Visible           = false
resultsOverlay.ZIndex            = 15
resultsOverlay.Parent            = hudGui
makeCorner(resultsOverlay, 16)

local resultsStroke = Instance.new("UIStroke")
resultsStroke.Color     = Color3.fromRGB(120, 80, 220)
resultsStroke.Thickness = 2
resultsStroke.Parent    = resultsOverlay

local resultsHeader = Instance.new("Frame")
resultsHeader.Size            = UDim2.new(1, 0, 0, 56)
resultsHeader.BackgroundColor3 = Color3.fromRGB(45, 25, 110)
resultsHeader.BorderSizePixel = 0
resultsHeader.Parent          = resultsOverlay
makeCorner(resultsHeader, 16)

local rHeaderMask = Instance.new("Frame")
rHeaderMask.Size            = UDim2.new(1, 0, 0, 16)
rHeaderMask.Position        = UDim2.new(0, 0, 1, -16)
rHeaderMask.BackgroundColor3 = Color3.fromRGB(45, 25, 110)
rHeaderMask.BorderSizePixel = 0
rHeaderMask.Parent          = resultsHeader

local resultsTitleLbl = Instance.new("TextLabel")
resultsTitleLbl.Size                   = UDim2.new(1, 0, 1, 0)
resultsTitleLbl.BackgroundTransparency = 1
resultsTitleLbl.TextColor3             = Color3.fromRGB(255, 230, 60)
resultsTitleLbl.Font                   = Enum.Font.GothamBold
resultsTitleLbl.TextSize               = 22
resultsTitleLbl.Text                   = "🏆  ROUND RESULTS"
resultsTitleLbl.Parent                 = resultsHeader

local resultsScroll = Instance.new("ScrollingFrame")
resultsScroll.Size              = UDim2.new(1, -20, 1, -72)
resultsScroll.Position          = UDim2.new(0, 10, 0, 62)
resultsScroll.BackgroundTransparency = 1
resultsScroll.BorderSizePixel   = 0
resultsScroll.ScrollBarThickness = 5
resultsScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 200)
resultsScroll.Parent            = resultsOverlay

local resultsLayout = Instance.new("UIListLayout")
resultsLayout.Padding    = UDim.new(0, 6)
resultsLayout.SortOrder  = Enum.SortOrder.LayoutOrder
resultsLayout.Parent     = resultsScroll

resultsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	resultsScroll.CanvasSize = UDim2.new(0, 0, 0, resultsLayout.AbsoluteContentSize.Y + 8)
end)

local RANK_COLORS = {
	Color3.fromRGB(255, 210, 40),   -- 1st: gold
	Color3.fromRGB(210, 210, 220),  -- 2nd: silver
	Color3.fromRGB(205, 127, 50),   -- 3rd: bronze
}

local function populateResults(data: { { rank: number, playerName: string, score: number } })
	-- Clear previous entries
	for _, child in ipairs(resultsScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for _, entry in ipairs(data) do
		local row = Instance.new("Frame")
		row.Name             = "Row_" .. entry.rank
		row.Size             = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(22, 18, 40)
		row.BorderSizePixel  = 0
		row.LayoutOrder      = entry.rank
		row.Parent           = resultsScroll
		makeCorner(row, 8)

		-- Rank number
		local rankColor = RANK_COLORS[entry.rank] or Color3.fromRGB(160, 150, 200)
		local rankLbl = Instance.new("TextLabel")
		rankLbl.Size                   = UDim2.new(0, 40, 1, 0)
		rankLbl.BackgroundTransparency = 1
		rankLbl.TextColor3             = rankColor
		rankLbl.Font                   = Enum.Font.GothamBold
		rankLbl.TextSize               = 18
		rankLbl.Text                   = "#" .. entry.rank
		rankLbl.Parent                 = row

		-- Player name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size                   = UDim2.new(0.6, 0, 1, 0)
		nameLbl.Position               = UDim2.new(0, 44, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3             = Color3.fromRGB(230, 225, 255)
		nameLbl.Font                   = Enum.Font.GothamBold
		nameLbl.TextSize               = 15
		nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
		nameLbl.Text                   = entry.playerName
		nameLbl.TextTruncate           = Enum.TextTruncate.AtEnd
		nameLbl.Parent                 = row

		-- Score
		local scoreLblR = Instance.new("TextLabel")
		scoreLblR.Size                   = UDim2.new(0, 80, 1, 0)
		scoreLblR.Position               = UDim2.new(1, -88, 0, 0)
		scoreLblR.BackgroundTransparency = 1
		scoreLblR.TextColor3             = rankColor
		scoreLblR.Font                   = Enum.Font.GothamBold
		scoreLblR.TextSize               = 18
		scoreLblR.TextXAlignment         = Enum.TextXAlignment.Right
		scoreLblR.Text                   = tostring(entry.score) .. " pts"
		scoreLblR.Parent                 = row

		-- Highlight the local player's row
		if entry.playerName == player.Name then
			row.BackgroundColor3 = Color3.fromRGB(40, 30, 80)
			local s = Instance.new("UIStroke")
			s.Color     = Color3.fromRGB(200, 170, 255)
			s.Thickness = 1
			s.Parent    = row
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Phase display logic
-- ═══════════════════════════════════════════════════════════════════════════

local PHASE_DISPLAY: { [string]: { label: string, color: Color3 } } = {
	Lobby    = { label = "LOBBY",      color = Color3.fromRGB(100, 200, 255) },
	Paint    = { label = "PAINT",      color = Color3.fromRGB(255, 220, 60)  },
	PoseLock = { label = "POSE LOCK",  color = Color3.fromRGB(180, 100, 255) },
	Seek     = { label = "SEEK",       color = Color3.fromRGB(255, 80, 80)   },
	Results  = { label = "RESULTS",    color = Color3.fromRGB(80, 220, 130)  },
	Abandoned= { label = "ABANDONED",  color = Color3.fromRGB(160, 160, 160) },
}

local ROLE_COLORS: { [string]: Color3 } = {
	Hider     = Color3.fromRGB(80, 220, 130),
	Seeker    = Color3.fromRGB(255, 80, 80),
	Spectator = Color3.fromRGB(160, 160, 180),
}

local function updateRoleBadge(role: string)
	roleLbl.Text            = role:upper()
	roleBadge.BackgroundColor3 = (ROLE_COLORS[role] or Color3.fromRGB(80, 80, 120))
		:Lerp(Color3.new(0, 0, 0), 0.5)
	roleLbl.TextColor3 = ROLE_COLORS[role] or Color3.fromRGB(200, 200, 220)
end

local function startTimer(endsAt: number)
	if timerConn then timerConn:Disconnect() end
	timerConn = RunService.Heartbeat:Connect(function()
		local rem = endsAt - workspace:GetServerTimeNow()
		if rem <= 0 then
			countdownLbl.Text       = "0:00"
			countdownLbl.TextColor3 = Color3.fromRGB(255, 60, 60)
			timerConn:Disconnect()
			timerConn = nil
			return
		end

		local secs = math.floor(rem)
		local mins = math.floor(secs / 60)
		countdownLbl.Text = string.format("%d:%02d", mins, secs % 60)
		countdownLbl.TextColor3 = rem <= 10
			and Color3.fromRGB(255, 60, 60)
			or rem <= 30
			and Color3.fromRGB(255, 180, 40)
			or  Color3.fromRGB(200, 200, 220)
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Remote listeners
-- ═══════════════════════════════════════════════════════════════════════════

RoleAssigned.OnClientEvent:Connect(function(role: string)
	currentRole = role
	updateRoleBadge(role)
end)

RoundStateChanged.OnClientEvent:Connect(function(
	phase: string,
	duration: number,
	endsAt: number,
	_roundId: number
)
	currentPhase = phase

	-- Update phase banner
	local info = PHASE_DISPLAY[phase] or { label = phase:upper(), color = Color3.fromRGB(200, 200, 200) }
	phaseLbl.Text       = info.label
	phaseLbl.TextColor3 = info.color

	-- Timer
	if duration > 0 then
		phaseEndsAt = endsAt
		startTimer(endsAt)
	else
		if timerConn then timerConn:Disconnect(); timerConn = nil end
		countdownLbl.Text = "--"
	end

	-- Results overlay
	resultsOverlay.Visible = (phase == "Results")

	-- Wrong-click feedback (fires only on this seeker's client)
	if phase == "WrongClick" then
		showPenaltyFlash()
	end
end)

PlayerEliminated.OnClientEvent:Connect(function(hider: Player, seeker: Player)
	local hiderName  = hider and hider.Name or "???"
	local seekerName = seeker and seeker.Name or "???"

	if seeker == player then
		addFeedEntry("✅ You found " .. hiderName .. "!", Color3.fromRGB(80, 220, 130))
	elseif hider == player then
		addFeedEntry("❌ You were found by " .. seekerName .. "!", Color3.fromRGB(255, 80, 80))
	else
		addFeedEntry(seekerName .. " found " .. hiderName, Color3.fromRGB(200, 190, 240))
	end
end)

RoundResults.OnClientEvent:Connect(function(data)
	populateResults(data)

	-- Update local score display from results table
	for _, entry in ipairs(data) do
		if entry.playerName == player.Name then
			scoreLbl.Text = tostring(entry.score)
			break
		end
	end
end)
