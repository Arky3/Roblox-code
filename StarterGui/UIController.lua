-- UIController | StarterGui > UIController (LocalScript)
-- v2 – Enhanced catalog: rarity system, brainrot items, better card visuals,
--       tab icons + counts, HOT badges, rarity-colored borders & strip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameStateChanged = Shared:WaitForChild("GameStateChanged")
local SubmitCreature = Shared:WaitForChild("SubmitCreature")
local SubmitScore = Shared:WaitForChild("SubmitScore")

print("UIController v2 loaded")

-- ============================================================
-- COLORS
-- ============================================================
local C = {
	bg       = Color3.fromRGB(9,   8,  18),
	panel    = Color3.fromRGB(22,  18, 36),
	panel2   = Color3.fromRGB(30,  25, 48),
	dark     = Color3.fromRGB(14,  12, 24),
	card     = Color3.fromRGB(35,  29, 55),
	cardSel  = Color3.fromRGB(55,  44, 88),
	pink     = Color3.fromRGB(255, 62, 169),
	gold     = Color3.fromRGB(255, 210, 86),
	white    = Color3.fromRGB(255, 255, 255),
	sub      = Color3.fromRGB(180, 165, 205),
	green    = Color3.fromRGB(70,  210, 120),
	red      = Color3.fromRGB(255, 100, 100),
}

local RARITY = {
	Common    = { label = "COMMON",    color = Color3.fromRGB(160, 155, 180) },
	Rare      = { label = "RARE",      color = Color3.fromRGB(60,  140, 255) },
	Epic      = { label = "EPIC",      color = Color3.fromRGB(170,  80, 255) },
	Legendary = { label = "LEGEND",    color = Color3.fromRGB(255, 200,  50) },
	Mythic    = { label = "MYTHIC",    color = Color3.fromRGB(255,  75,  75) },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function mkCorner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end

local function mkStroke(p, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or C.pink
	s.Thickness = thick or 2
	s.Parent = p
end

local function mkFrame(parent, size, pos, color, radius)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or C.panel
	f.BorderSizePixel = 0
	f.Parent = parent
	if radius then mkCorner(f, radius) end
	return f
end

local function mkLabel(parent, text, size, pos, color, font, textSize)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextColor3 = color or C.white
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize or 15
	l.TextScaled = false
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function mkBtn(parent, text, size, pos, color, font, textSize)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Text = text
	b.BackgroundColor3 = color or C.pink
	b.TextColor3 = C.white
	b.BorderSizePixel = 0
	b.Font = font or Enum.Font.GothamBold
	b.TextSize = textSize or 15
	b.AutoButtonColor = true
	b.Parent = parent
	mkCorner(b, 10)
	return b
end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- ============================================================
-- CATALOG DATA
-- Fields: id, display, desc, color, shape (body only), text (face only),
--         icon, rarity, hot (bool), new_item (bool)
-- ============================================================

local BODY_ITEMS = {
	-- Common
	{ id="Blob",      display="Blob",        desc="Squishy guy",      color=rgb(255,129,190), shape="blob",     rarity="Common",    icon="◉" },
	{ id="Fish",      display="Fish",        desc="Aquatic king",     color=rgb(73, 174,255), shape="fish",     rarity="Common",    icon="~>" },
	{ id="Nugget",    display="Nugget",      desc="Crispy form",      color=rgb(236,173, 75), shape="nugget",   rarity="Common",    icon=">>>" },
	{ id="Frog",      display="Frog",        desc="Ribbit bro",       color=rgb(80, 210,100), shape="frog",     rarity="Common",    icon="o_o" },
	{ id="Ghost",     display="Ghost",       desc="Boo!",             color=rgb(235,235,255), shape="ghost",    rarity="Common",    icon="oOo" },
	{ id="Mushroom",  display="Mushroom",    desc="Spore lord",       color=rgb(255, 95,115), shape="mushroom", rarity="Common",    icon="[^]" },
	{ id="Cloud",     display="Cloud",       desc="Floaty vibes",     color=rgb(220,235,255), shape="cloud",    rarity="Common",    icon="~~~" },
	{ id="Cactus",    display="Cactus",      desc="Spiky",            color=rgb(55, 180, 95), shape="cactus",   rarity="Common",    icon="|+|" },
	{ id="Chicken",   display="Chicken",     desc="Bawkster",         color=rgb(255,230,118), shape="chicken",  rarity="Common",    icon="(>)" },
	-- Rare
	{ id="Toilet",    display="Toilet",      desc="Classic Ohio",     color=rgb(210,225,245), shape="toilet",   rarity="Rare",      icon="[O]" },
	{ id="Alien",     display="Alien",       desc="Cosmic rizz",      color=rgb(92, 226,136), shape="alien",    rarity="Rare",      icon="(*)" },
	{ id="Goblin",    display="Goblin",      desc="Gobbo mode",       color=rgb(67, 190, 94), shape="goblin",   rarity="Rare",      icon=">:3" },
	{ id="Shark",     display="Shark",       desc="NPC eater",        color=rgb(91, 134,170), shape="shark",    rarity="Rare",      icon="><>" },
	{ id="TVHead",    display="TV Head",     desc="Static gang",      color=rgb(95, 105,130), shape="tv",       rarity="Rare",      icon="[=]" },
	{ id="Robot",     display="Robot",       desc="Chrome bro",       color=rgb(155,170,185), shape="robot",    rarity="Rare",      icon="[R]" },
	{ id="Pizza",     display="Pizza",       desc="Cheesy drip",      color=rgb(255,190, 70), shape="pizza",    rarity="Rare",      icon="(o)" },
	-- Epic
	{ id="Skibidi",   display="Skibidi",     desc="Ohio chaos fr",    color=rgb(80, 200,255), shape="toilet",   rarity="Epic",      icon="SKB", hot=true },
	{ id="Sigma",     display="Sigma",       desc="Top of the chain", color=rgb(40,  40, 55), shape="robot",    rarity="Epic",      icon="SIG" },
	{ id="NPC",       display="NPC",         desc="No thoughts",      color=rgb(190,185,200), shape="robot",    rarity="Epic",      icon="NPC" },
	{ id="Cameraman", display="Cameraman",   desc="Always watching",  color=rgb(30,  30, 40), shape="tv",       rarity="Epic",      icon="CAM" },
	{ id="Speakerman",display="Speakerman",  desc="Very loud",        color=rgb(50,  50, 65), shape="tv",       rarity="Epic",      icon="SPK" },
	{ id="OhioMan",   display="Ohio Man",    desc="From Ohio",        color=rgb(110, 90,150), shape="goblin",   rarity="Epic",      icon="OHO" },
	-- Legendary
	{ id="GigaChad",  display="Giga Chad",   desc="Peak fiction",     color=rgb(255,220,100), shape="alien",    rarity="Legendary", icon="GCH", hot=true },
	{ id="RizzGod",   display="Rizz God",    desc="Unmatched W",      color=rgb(255, 80,200), shape="alien",    rarity="Legendary", icon="RZG" },
	{ id="BasedKing", display="Based King",  desc="Max based",        color=rgb(255,165, 50), shape="blob",     rarity="Legendary", icon="BSK" },
	-- Mythic
	{ id="GyattBoss", display="Gyatt Boss",  desc="Immeasurable",     color=rgb(255, 60, 60), shape="blob",     rarity="Mythic",    icon="GYT", hot=true },
}

local FACE_ITEMS = {
	{ id="None",       display="Blank",        desc="No expression",    text="",     rarity="Common" },
	{ id="Happy",      display="Happy",        desc="Cute",             text=":)",   rarity="Common" },
	{ id="Sus",        display="Sus",          desc="Side eye",         text="-_-",  rarity="Common" },
	{ id="Angry",      display="Angry",        desc="Mad",              text=">:(",  rarity="Common" },
	{ id="Crying",     display="Crying",       desc="Drama",            text="T_T",  rarity="Common" },
	{ id="Sleepy",     display="Sleepy",       desc="Tired",            text="-.-",  rarity="Common" },
	{ id="Empty",      display="Empty",        desc="No thoughts",      text="0_0",  rarity="Common" },
	{ id="Dizzy",      display="Dizzy",        desc="Lost",             text="@_@",  rarity="Rare"   },
	{ id="Sunglasses", display="Shades",       desc="Cool guy",         text="B)",   rarity="Rare"   },
	{ id="Yapping",    display="Yapping",      desc="Not stopping",     text=":O",   rarity="Rare"   },
	{ id="Goofy",      display="Goofy",        desc="Silly ahh",        text="xD",   rarity="Rare"   },
	{ id="Panic",      display="Panic",        desc="Not good",         text="!!",   rarity="Rare"   },
	{ id="Rich",       display="Rich",         desc="Money eyes",       text="$_$",  rarity="Rare"   },
	{ id="Evil",       display="Evil",         desc="Villain arc",      text=">:D",  rarity="Epic"   },
	{ id="Sigma",      display="Sigma Stare",  desc="Intimidating",     text=">_>",  rarity="Epic",   hot=true },
	{ id="Rizz",       display="Rizz Smirk",   desc="Unmatched",        text=";)",   rarity="Epic"   },
	{ id="Blud",       display="Blud",         desc="Blud thinks...",   text=":|",   rarity="Epic"   },
	{ id="NoCap",      display="No Cap",       desc="Fr fr",            text="=_=",  rarity="Epic"   },
	{ id="Ohio",       display="Ohio Face",    desc="Only in Ohio",     text="O_O",  rarity="Legendary", hot=true },
	{ id="Gyatt",      display="Gyatt",        desc="Immense shock",    text=":O!",  rarity="Legendary" },
	{ id="Based",      display="Based",        desc="Extremely based",  text="^_^",  rarity="Legendary" },
	{ id="Grimace",    display="Grimace",      desc="The shake",        text="UwU",  rarity="Mythic",    hot=true },
}

local CLOTHES_ITEMS = {
	{ id="None",       display="No Clothes",   desc="Naked drip",       color=rgb(55, 50, 75),  rarity="Common"   },
	{ id="Hoodie",     display="Hoodie",       desc="Comfy",            color=rgb(80,110,230),  rarity="Common"   },
	{ id="Pajamas",    display="Pajamas",      desc="Sleepy fit",       color=rgb(110,190,255), rarity="Common"   },
	{ id="Apron",      display="Apron",        desc="Chef mode",        color=rgb(245,245,235), rarity="Common"   },
	{ id="Tracksuit",  display="Tracksuit",    desc="Sporty",           color=rgb(70, 210,120), rarity="Common"   },
	{ id="PizzaShirt", display="Pizza Shirt",  desc="Extra cheese",     color=rgb(255,180, 70), rarity="Common"   },
	{ id="Suit",       display="Suit",         desc="CEO behavior",     color=rgb(25,  25, 35), rarity="Rare"     },
	{ id="Dress",      display="Dress",        desc="Runway ready",     color=rgb(255, 85,180), rarity="Rare"     },
	{ id="Armor",      display="Armor",        desc="Battle ready",     color=rgb(125,135,150), rarity="Rare"     },
	{ id="LabCoat",    display="Lab Coat",     desc="Nerd scientist",   color=rgb(240,240,255), rarity="Rare"     },
	{ id="RoyalRobe",  display="Royal Robe",   desc="Medieval king",    color=rgb(135, 65,210), rarity="Rare"     },
	{ id="ShadowFit",  display="Shadow Fit",   desc="Mysterious",       color=rgb(35,  20, 55), rarity="Rare"     },
	{ id="DripSuit",   display="Drip Suit",    desc="Max drip",         color=rgb(255, 62,169), rarity="Epic",    hot=true },
	{ id="OhioFit",    display="Ohio Fit",     desc="Only in Ohio",     color=rgb(100, 80,140), rarity="Epic"     },
	{ id="SigmaFit",   display="Sigma Fit",    desc="Lone wolf",        color=rgb(20,  15, 30), rarity="Epic"     },
	{ id="RizzJacket", display="Rizz Jacket",  desc="Unmatched W",      color=rgb(255,140, 50), rarity="Epic",    hot=true },
	{ id="GyattGear",  display="Gyatt Gear",   desc="Too powerful",     color=rgb(255, 50,100), rarity="Legendary" },
	{ id="BasedFit",   display="Based Fit",    desc="Extremely based",  color=rgb(255,200, 50), rarity="Legendary" },
	{ id="GigaDrip",   display="Giga Drip",    desc="Peak fashion",     color=rgb(180, 80,255), rarity="Mythic",  hot=true },
}

local HAT_ITEMS = {
	{ slot="hat", id="None",       display="No Hat",       desc="Bald drip",      color=rgb(55,  50, 75), rarity="Common"   },
	{ slot="hat", id="Beanie",     display="Beanie",       desc="Chill vibes",    color=rgb(255, 90, 90), rarity="Common"   },
	{ slot="hat", id="Bucket",     display="Bucket",       desc="Drip check",     color=rgb(80, 120,200), rarity="Common"   },
	{ slot="hat", id="ChefHat",    display="Chef Hat",     desc="Gordon mode",    color=rgb(250,250,250), rarity="Common"   },
	{ slot="hat", id="Cone",       display="Traffic Cone", desc="Street icon",    color=rgb(255,117, 44), rarity="Common"   },
	{ slot="hat", id="Sombrero",   display="Sombrero",     desc="Fiesta time",    color=rgb(245,190, 70), rarity="Common"   },
	{ slot="hat", id="TopHat",     display="Top Hat",      desc="Distinguished",  color=rgb(45,  35, 60), rarity="Rare"     },
	{ slot="hat", id="Propeller",  display="Propeller",    desc="Spin master",    color=rgb(255, 80,160), rarity="Rare"     },
	{ slot="hat", id="Headphones", display="Headphones",   desc="No talking",     color=rgb(80, 240,220), rarity="Rare"     },
	{ slot="hat", id="BurgerHat",  display="Burger Hat",   desc="Lunchtime",      color=rgb(180, 95, 45), rarity="Rare"     },
	{ slot="hat", id="WifiHalo",   display="WiFi Halo",    desc="Always online",  color=rgb(102,225,255), rarity="Rare"     },
	{ slot="hat", id="Viking",     display="Viking Helm",  desc="Pillage mode",   color=rgb(190,190,205), rarity="Rare"     },
	{ slot="hat", id="Wizard",     display="Wizard Hat",   desc="Magic user",     color=rgb(95,  60,190), rarity="Epic"     },
	{ slot="hat", id="Crown",      display="Crown",        desc="Royal W",        color=rgb(255,217, 67), rarity="Epic"     },
	{ slot="hat", id="FishBowl",   display="Fish Bowl",    desc="Underwater",     color=rgb(160,230,255), rarity="Epic"     },
	{ slot="hat", id="PartyCrown", display="Party Crown",  desc="Always hype",    color=rgb(255, 95,210), rarity="Epic"     },
	{ slot="hat", id="NpcHelmet",  display="NPC Helmet",   desc="No thoughts",    color=rgb(120,130,150), rarity="Epic",    hot=true },
	{ slot="hat", id="OhioCrown",  display="Ohio Crown",   desc="From Ohio",      color=rgb(180, 50,255), rarity="Legendary", hot=true },
	{ slot="hat", id="SigmaCap",   display="Sigma Cap",    desc="Lone wolf fit",  color=rgb(20,  15, 30), rarity="Legendary" },
	{ slot="hat", id="RizzHalo",   display="Rizz Halo",    desc="Divine W",       color=rgb(255,200, 80), rarity="Legendary" },
	{ slot="hat", id="GyattHorns", display="Gyatt Horns",  desc="Too powerful",   color=rgb(255, 50, 50), rarity="Mythic",  hot=true },
}

local BACK_ITEMS = {
	{ slot="back", id="None",       display="No Back",      desc="Light carry",    color=rgb(55,  50, 75), rarity="Common"   },
	{ slot="back", id="SchoolBag",  display="School Bag",   desc="Still learning", color=rgb(90, 140,255), rarity="Common"   },
	{ slot="back", id="Teddy",      display="Teddy Bear",   desc="Adorable",       color=rgb(185,125, 75), rarity="Common"   },
	{ slot="back", id="PizzaBox",   display="Pizza Box",    desc="Delivery bro",   color=rgb(220,120, 60), rarity="Common"   },
	{ slot="back", id="TrashBag",   display="Trash Bag",    desc="Chaotic",        color=rgb(45,  45, 50), rarity="Common"   },
	{ slot="back", id="Cape",       display="Cape",         desc="Hero vibes",     color=rgb(255, 91,190), rarity="Rare"     },
	{ slot="back", id="Router",     display="WiFi Router",  desc="No signal",      color=rgb(55,  55, 66), rarity="Rare"     },
	{ slot="back", id="Skateboard", display="Skateboard",   desc="Trick shot",     color=rgb(80,  80,100), rarity="Rare"     },
	{ slot="back", id="Speaker",    display="Speaker",      desc="Max volume",     color=rgb(35,  35, 45), rarity="Rare"     },
	{ slot="back", id="Guitar",     display="Guitar",       desc="Rock on",        color=rgb(210, 95, 65), rarity="Rare"     },
	{ slot="back", id="Sword",      display="Sword",        desc="Epic moment",    color=rgb(180,190,210), rarity="Epic"     },
	{ slot="back", id="Jetpack",    display="Jetpack",      desc="W speed",        color=rgb(210, 70, 70), rarity="Epic"     },
	{ slot="back", id="Wings",      display="Wings",        desc="DIY flight",     color=rgb(174,112, 58), rarity="Epic"     },
	{ slot="back", id="AngelWings", display="Angel Wings",  desc="Holy rizz",      color=rgb(245,245,255), rarity="Epic"     },
	{ slot="back", id="Rocket",     display="Rocket",       desc="Blast off",      color=rgb(255, 80, 65), rarity="Epic",    hot=true },
	{ slot="back", id="DemonWings", display="Demon Wings",  desc="Cursed W",       color=rgb(120, 25, 55), rarity="Legendary" },
	{ slot="back", id="WFlag",      display="W Flag",       desc="Ultimate W",     color=rgb(255,200, 50), rarity="Legendary", hot=true },
	{ slot="back", id="OhioFlag",   display="Ohio Flag",    desc="From Ohio",      color=rgb(100, 80,150), rarity="Legendary" },
	{ slot="back", id="SigmaScroll",display="Sigma Scroll", desc="Ancient power",  color=rgb(80,  60,120), rarity="Legendary" },
	{ slot="back", id="RizzCape",   display="Rizz Cape",    desc="Legendary W",    color=rgb(255, 80,180), rarity="Mythic",  hot=true },
}

local AURA_ITEMS = {
	{ slot="aura", id="None",       display="No Aura",      desc="Plain",          color=rgb(55,  50, 75), rarity="Common"   },
	{ slot="aura", id="Smoke",      display="Smoke",        desc="Foggy",          color=rgb(110,110,125), rarity="Common"   },
	{ slot="aura", id="Bubbles",    display="Bubbles",      desc="Splashy",        color=rgb(100,220,255), rarity="Common"   },
	{ slot="aura", id="Hearts",     display="Hearts",       desc="Loveable",       color=rgb(255,100,170), rarity="Common"   },
	{ slot="aura", id="Stars",      display="Stars",        desc="Sparkly",        color=rgb(255,240,130), rarity="Common"   },
	{ slot="aura", id="Frozen",     display="Frozen",       desc="Ice cold",       color=rgb(140,220,255), rarity="Rare"     },
	{ slot="aura", id="Spicy",      display="Spicy",        desc="Very hot",       color=rgb(255, 78, 78), rarity="Rare"     },
	{ slot="aura", id="Toxic",      display="Toxic",        desc="Radioactive",    color=rgb(105,255,104), rarity="Rare"     },
	{ slot="aura", id="Electric",   display="Electric",     desc="Zappy",          color=rgb(95, 160,255), rarity="Rare"     },
	{ slot="aura", id="Fire",       display="Fire",         desc="Burning",        color=rgb(255,110, 45), rarity="Rare"     },
	{ slot="aura", id="Glitch",     display="Glitch",       desc="Bugged out",     color=rgb(124, 93,255), rarity="Epic"     },
	{ slot="aura", id="Shadow",     display="Shadow",       desc="Dark energy",    color=rgb(70,  25,110), rarity="Epic"     },
	{ slot="aura", id="Rainbow",    display="Rainbow",      desc="Prism god",      color=rgb(255,120,220), rarity="Epic",    hot=true },
	{ slot="aura", id="OhioAura",   display="Ohio Aura",    desc="Only in Ohio",   color=rgb(130, 60,200), rarity="Epic",    hot=true },
	{ slot="aura", id="Gold",       display="Gold Aura",    desc="Legendary",      color=rgb(255,210, 70), rarity="Legendary" },
	{ slot="aura", id="SigmaAura",  display="Sigma Aura",   desc="Lone wolf",      color=rgb(40,  40, 60), rarity="Legendary" },
	{ slot="aura", id="RizzField",  display="Rizz Field",   desc="Divine W",       color=rgb(255, 80,200), rarity="Legendary", hot=true },
	{ slot="aura", id="BasedGlow",  display="Based Glow",   desc="Max based",      color=rgb(255,165, 50), rarity="Legendary" },
	{ slot="aura", id="GyattBlast", display="Gyatt Blast",  desc="Unstoppable",    color=rgb(255, 50, 80), rarity="Mythic",  hot=true },
	{ slot="aura", id="GigaAura",   display="Giga Aura",    desc="Peak fiction",   color=rgb(180, 80,255), rarity="Mythic"   },
}

local TABS = {
	{ key="body",    label="BODY",    icon="[B]", items=BODY_ITEMS    },
	{ key="face",    label="FACE",    icon="[F]", items=FACE_ITEMS    },
	{ key="clothes", label="FIT",     icon="[C]", items=CLOTHES_ITEMS },
	{ key="hat",     label="HATS",    icon="[H]", items=HAT_ITEMS     },
	{ key="back",    label="BACK",    icon="[K]", items=BACK_ITEMS    },
	{ key="aura",    label="AURAS",   icon="[A]", items=AURA_ITEMS    },
}

local selected = {
	body    = BODY_ITEMS[1],
	face    = FACE_ITEMS[2],
	clothes = CLOTHES_ITEMS[1],
	hat     = HAT_ITEMS[1],
	back    = BACK_ITEMS[1],
	aura    = AURA_ITEMS[1],
}

-- ============================================================
-- ROOT GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local lobbyPanel = mkFrame(gui, UDim2.new(0.36,0,0.25,0), UDim2.new(0.32,0,0.375,0), C.panel, 16)
lobbyPanel.Visible = false
mkStroke(lobbyPanel, C.pink, 2)
mkLabel(lobbyPanel, "JUDGE A BRAINROT", UDim2.new(0.9,0,0,38), UDim2.new(0.05,0,0,20), C.gold, Enum.Font.GothamBlack, 26)
mkLabel(lobbyPanel, "Waiting for round to start...", UDim2.new(0.85,0,0,22), UDim2.new(0.075,0,0,72), C.sub, Enum.Font.Gotham, 15)

local revealPanel = mkFrame(gui, UDim2.new(0.46,0,0.26,0), UDim2.new(0.27,0,0.37,0), C.panel, 16)
revealPanel.Visible = false
mkStroke(revealPanel, C.gold, 2)
mkLabel(revealPanel, "THIS ROUND'S PROMPT", UDim2.new(0.9,0,0,20), UDim2.new(0.05,0,0,16), C.sub, Enum.Font.GothamBold, 14)
local revealPromptLabel = mkLabel(revealPanel, "???", UDim2.new(0.9,0,0,54), UDim2.new(0.05,0,0,44), C.gold, Enum.Font.GothamBlack, 30)
revealPromptLabel.TextXAlignment = Enum.TextXAlignment.Center
mkLabel(revealPanel, "Get ready to build your creature!", UDim2.new(0.85,0,0,20), UDim2.new(0.075,0,1,-30), C.sub, Enum.Font.Gotham, 13)

local creationPanel = mkFrame(gui, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), C.bg, 0)
creationPanel.Visible = false

local topBar = mkFrame(creationPanel, UDim2.new(1,0,0,50), UDim2.new(0,0,0,0), C.panel, 0)
local creationPromptLabel = mkLabel(topBar, "PROMPT: ???", UDim2.new(0.65,0,1,0), UDim2.new(0.02,0,0,0), C.gold, Enum.Font.GothamBlack, 20)
local timerLabel = mkLabel(topBar, "60s", UDim2.new(0.1,0,1,0), UDim2.new(0.88,0,0,0), C.red, Enum.Font.GothamBold, 20)

local contentArea = mkFrame(creationPanel, UDim2.new(1,-24,1,-60), UDim2.new(0,12,0,54), C.bg, 0)
contentArea.BackgroundTransparency = 1

local catalogPanel = mkFrame(contentArea, UDim2.new(1,-350,1,0), UDim2.new(0,0,0,0), C.panel, 12)

-- Tab bar (taller to accommodate item counts)
local tabBar = mkFrame(catalogPanel, UDim2.new(1,0,0,50), UDim2.new(0,0,0,0), C.dark, 12)

local tabListLayout = Instance.new("UIListLayout")
tabListLayout.FillDirection = Enum.FillDirection.Horizontal
tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabListLayout.Padding = UDim.new(0, 6)
tabListLayout.Parent = tabBar

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingLeft = UDim.new(0, 8)
tabPadding.Parent = tabBar

local gridScroll = Instance.new("ScrollingFrame")
gridScroll.Size = UDim2.new(1,0,1,-58)
gridScroll.Position = UDim2.new(0,0,0,58)
gridScroll.BackgroundTransparency = 1
gridScroll.BorderSizePixel = 0
gridScroll.ScrollBarThickness = 6
gridScroll.ScrollBarImageColor3 = C.pink
gridScroll.CanvasSize = UDim2.fromOffset(0,0)
gridScroll.Parent = catalogPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(130, 188)
gridLayout.CellPadding = UDim2.fromOffset(12, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridScroll

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 12)
gridPadding.PaddingLeft = UDim.new(0, 12)
gridPadding.Parent = gridScroll

-- ============================================================
-- PREVIEW PANEL
-- ============================================================
local previewPanel = mkFrame(contentArea, UDim2.new(0,338,1,0), UDim2.new(1,-338,0,0), C.panel, 12)
mkStroke(previewPanel, Color3.fromRGB(85,54,130), 2)
mkLabel(previewPanel, "YOUR CREATURE", UDim2.new(1,-20,0,24), UDim2.fromOffset(10,10), C.sub, Enum.Font.GothamBlack, 15)

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1,-20,0,300)
viewport.Position = UDim2.fromOffset(10,40)
viewport.BackgroundColor3 = Color3.fromRGB(12,10,22)
viewport.BorderSizePixel = 0
viewport.LightDirection = Vector3.new(-1,-1,-1)
viewport.LightColor = Color3.fromRGB(255,255,255)
viewport.Ambient = Color3.fromRGB(130,130,150)
viewport.Parent = previewPanel
mkCorner(viewport, 12)

local worldModel = Instance.new("WorldModel")
worldModel.Parent = viewport

local vpCam = Instance.new("Camera")
vpCam.FieldOfView = 35
vpCam.CFrame = CFrame.new(Vector3.new(0,3,14), Vector3.new(0,3,0))
viewport.CurrentCamera = vpCam
vpCam.Parent = viewport

local modelFolder = Instance.new("Folder")
modelFolder.Name = "CreatureModel"
modelFolder.Parent = worldModel

local summaryLabel = nil
local previewYaw = 0
local baseDescription = nil
local currentAvatarModel = nil
local avatarStandY = 3
local previewUpdateToken = 0

local function applyPreviewRotation()
	if currentAvatarModel then
		currentAvatarModel:PivotTo(CFrame.new(0, avatarStandY, 0) * CFrame.Angles(0, previewYaw, 0))
	end
end

-- ============================================================
-- R15 AVATAR PREVIEW
-- ============================================================
local function buildCreatureShape()
	if not baseDescription then return end

	local token = previewUpdateToken + 1
	previewUpdateToken = token

	-- Build a modified HumanoidDescription
	local desc = Instance.new("HumanoidDescription")

	-- Body color from selected body item
	local bodyColor = selected.body and selected.body.color or Color3.fromRGB(163, 162, 165)

	-- Glitch aura: blend body color 50% toward purple
	if selected.aura and selected.aura.id == "Glitch" then
		local purple = Color3.fromRGB(124, 93, 255)
		bodyColor = Color3.new(
			(bodyColor.R + purple.R) / 2,
			(bodyColor.G + purple.G) / 2,
			(bodyColor.B + purple.B) / 2
		)
	end

	desc.HeadColor     = bodyColor
	desc.TorsoColor    = bodyColor
	desc.LeftArmColor  = bodyColor
	desc.RightArmColor = bodyColor
	desc.LeftLegColor  = bodyColor
	desc.RightLegColor = bodyColor

	-- Preserve the player's face and hair from base description
	desc.Face          = baseDescription.Face
	desc.HairAccessory = baseDescription.HairAccessory

	-- Hat accessories: Crown and Cone have real asset ids; others use no accessory
	local hatId = selected.hat and selected.hat.id or "None"
	if hatId == "Crown" then
		desc.HatAccessory = "3284939"
	elseif hatId == "Cone" then
		desc.HatAccessory = "3085632"
	else
		desc.HatAccessory = ""
	end

	-- Back accessories: Wings and AngelWings have real asset ids
	local backId = selected.back and selected.back.id or "None"
	if backId == "Wings" then
		desc.BackAccessory = "119916949"
	elseif backId == "AngelWings" then
		desc.BackAccessory = "144076838"
	else
		desc.BackAccessory = ""
	end

	-- Clear remaining slots so nothing bleeds in from baseDescription
	desc.FaceAccessory      = ""
	desc.NeckAccessory      = ""
	desc.ShouldersAccessory = ""
	desc.FrontAccessory     = ""
	desc.WaistAccessory     = ""

	-- Create the R15 avatar model (yields)
	local ok, newModel = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)

	if not ok or not newModel then return end

	-- Discard if a newer update was already queued
	if previewUpdateToken ~= token then
		newModel:Destroy()
		return
	end

	-- Anchor all parts; disable physics interactions
	for _, part in ipairs(newModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
			part.CanTouch   = false
			part.CanQuery   = false
		end
	end

	local humanoid = newModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,   false)
	end

	-- Swap out old model
	if currentAvatarModel then
		currentAvatarModel:Destroy()
		currentAvatarModel = nil
	end

	newModel.Parent    = modelFolder
	currentAvatarModel = newModel

	-- Stand on podium top surface (y ≈ 0.53)
	local pivotCF, size = newModel:GetBoundingBox()
	local feetY        = pivotCF.Y - size.Y / 2
	local podiumTopY   = 0.53
	local currentPivY  = newModel:GetPivot().Y
	avatarStandY       = currentPivY + (podiumTopY - feetY)

	newModel:PivotTo(CFrame.new(0, avatarStandY, 0) * CFrame.Angles(0, previewYaw, 0))

	-- Frame camera: full-body shot, looking at mid-chest
	local midY = podiumTopY + size.Y * 0.5
	vpCam.CFrame = CFrame.new(Vector3.new(0, midY + 0.4, 11), Vector3.new(0, midY - 0.3, 0))
end

-- Fetch the player's HumanoidDescription once at startup
task.spawn(function()
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	baseDescription = (ok and desc) or Instance.new("HumanoidDescription")
	updatePreview()
end)

-- Mouse / touch drag to rotate preview
local draggingPreview = false
local lastDragX = 0

viewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingPreview = true
		lastDragX = input.Position.X
	end
end)

viewport.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingPreview = false
	end
end)

viewport.InputChanged:Connect(function(input)
	if not draggingPreview then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local deltaX = input.Position.X - lastDragX
	lastDragX = input.Position.X
	previewYaw = previewYaw + deltaX * 0.012
	applyPreviewRotation()
end)

local function updatePreview()
	-- Update summary label immediately (synchronous)
	local parts = {}
	if selected.body    then table.insert(parts, selected.body.display) end
	if selected.face    and selected.face.id    ~= "None" then table.insert(parts, selected.face.display)    end
	if selected.clothes and selected.clothes.id ~= "None" then table.insert(parts, selected.clothes.display) end
	if selected.hat     and selected.hat.id     ~= "None" then table.insert(parts, selected.hat.display)     end
	if selected.back    and selected.back.id    ~= "None" then table.insert(parts, selected.back.display)    end
	if selected.aura    and selected.aura.id    ~= "None" then table.insert(parts, selected.aura.display)    end
	if summaryLabel then
		summaryLabel.Text = #parts > 0 and table.concat(parts, " + ") or "Pick a body to start"
	end

	-- Rebuild avatar (async, cancels stale loads automatically)
	task.spawn(buildCreatureShape)
end

-- ============================================================
-- NAME BOX + SUMMARY + READY BUTTON
-- ============================================================
mkLabel(previewPanel, "NAME", UDim2.new(0.9,0,0,16), UDim2.fromOffset(10,350), C.sub, Enum.Font.GothamBold, 12)

local nameBox = Instance.new("TextBox")
nameBox.Size       = UDim2.new(0.9,0,0,36)
nameBox.Position   = UDim2.new(0.05,0,0,368)
nameBox.PlaceholderText = "Name your creature..."
nameBox.Text            = ""
nameBox.BackgroundColor3  = C.dark
nameBox.TextColor3        = C.white
nameBox.PlaceholderColor3 = C.sub
nameBox.Font              = Enum.Font.Gotham
nameBox.TextSize          = 14
nameBox.ClearTextOnFocus  = false
nameBox.BorderSizePixel   = 0
nameBox.Parent = previewPanel
mkCorner(nameBox, 8)

summaryLabel = mkLabel(previewPanel, "Pick a body to start", UDim2.new(0.9,0,0,54), UDim2.new(0.05,0,0,412), C.sub, Enum.Font.Gotham, 11)
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left

local readyBtn = mkBtn(previewPanel, "READY FOR RUNWAY", UDim2.new(0.9,0,0,46), UDim2.new(0.05,0,1,-56), C.pink, Enum.Font.GothamBlack, 16)

-- ============================================================
-- CATALOG GRID BUILDER
-- ============================================================
local tabBtns = {}

local function clearGrid()
	for _, child in ipairs(gridScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function isSelected(tabKey, item)
	if tabKey == "body"    then return selected.body    == item end
	if tabKey == "face"    then return selected.face    == item end
	if tabKey == "clothes" then return selected.clothes == item end
	if tabKey == "hat"     then return selected.hat     == item end
	if tabKey == "back"    then return selected.back    == item end
	if tabKey == "aura"    then return selected.aura    == item end
	return false
end

-- Returns a tinted-down version of a color for card backgrounds
local function dimColor(c, factor)
	factor = factor or 0.35
	return Color3.new(c.R * factor, c.G * factor, c.B * factor)
end

local function buildGrid(tabKey, items)
	clearGrid()

	for i, item in ipairs(items) do
		local sel      = isSelected(tabKey, item)
		local rarData  = RARITY[item.rarity or "Common"]
		local rarColor = rarData and rarData.color or Color3.fromRGB(160,155,180)

		-- Card: tinted background derived from rarity/item color when selected
		local cardBg = sel and dimColor(item.color or C.card, 0.28) or C.card
		local card = mkFrame(gridScroll, UDim2.fromOffset(130,188), UDim2.new(0,0,0,0), cardBg, 14)
		card.LayoutOrder = i

		-- Border: rarity color, thicker when selected
		mkStroke(card, rarColor, sel and 2.5 or 1)

		-- ── Color preview block ──
		local colorBlock = mkFrame(card, UDim2.new(1,-12,0,98), UDim2.fromOffset(6,6), item.color or C.panel2, 10)

		-- Bottom shadow gradient on color block
		local shadow = Instance.new("UIGradient")
		shadow.Color = ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(0,0,0))
		shadow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.75),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		shadow.Rotation = 90
		shadow.Parent   = colorBlock

		-- Top shine
		local shine = mkFrame(colorBlock, UDim2.new(1,0,0,22), UDim2.new(0,0,0,0), Color3.fromRGB(255,255,255), 10)
		shine.BackgroundTransparency = 0.82

		-- Icon / symbol inside the color block
		if tabKey == "face" and item.text and item.text ~= "" then
			local fl = mkLabel(colorBlock, item.text, UDim2.new(1,0,0.8,0), UDim2.new(0,0,0.1,0), Color3.fromRGB(20,20,30), Enum.Font.GothamBlack, 30)
			fl.TextXAlignment  = Enum.TextXAlignment.Center
			fl.TextYAlignment  = Enum.TextYAlignment.Center
		elseif item.icon and item.icon ~= "" then
			local il = mkLabel(colorBlock, item.icon, UDim2.new(1,-4,0.65,0), UDim2.new(0,2,0.15,0), Color3.fromRGB(255,255,255), Enum.Font.GothamBlack, 22)
			il.TextXAlignment  = Enum.TextXAlignment.Center
			il.TextYAlignment  = Enum.TextYAlignment.Center
			il.TextTransparency = 0.08
		end

		-- HOT badge (top-left of color block)
		if item.hot then
			local hot = mkFrame(colorBlock, UDim2.fromOffset(42,16), UDim2.fromOffset(3,3), rgb(220,60,30), 5)
			local hl = mkLabel(hot, "HOT", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), C.white, Enum.Font.GothamBlack, 10)
			hl.TextXAlignment = Enum.TextXAlignment.Center
		end

		-- Rarity badge (bottom of color block)
		local badgeW = 68
		local badge  = mkFrame(colorBlock, UDim2.fromOffset(badgeW, 16), UDim2.new(0.5, -badgeW/2, 1, -20), rarColor, 4)
		badge.BackgroundTransparency = 0.25
		local bl = mkLabel(badge, rarData and rarData.label or "COMMON", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), C.white, Enum.Font.GothamBlack, 10)
		bl.TextXAlignment = Enum.TextXAlignment.Center

		-- Item name
		local nl = mkLabel(card, item.display, UDim2.new(1,-10,0,22), UDim2.fromOffset(5,108), C.white, Enum.Font.GothamBlack, 13)
		nl.TextXAlignment = Enum.TextXAlignment.Center

		-- Description
		local dl = mkLabel(card, item.desc or "", UDim2.new(1,-10,0,18), UDim2.fromOffset(5,130), C.sub, Enum.Font.Gotham, 11)
		dl.TextXAlignment = Enum.TextXAlignment.Center

		-- Selected bottom strip (rarity color)
		if sel then
			mkFrame(card, UDim2.new(1,0,0,4), UDim2.new(0,0,1,-4), rarColor, 4)
		end

		-- Invisible click overlay
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1,0,1,0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 5
		btn.Parent = card

		btn.MouseButton1Click:Connect(function()
			if     tabKey == "body"    then selected.body    = item
			elseif tabKey == "face"    then selected.face    = item
			elseif tabKey == "clothes" then selected.clothes = item
			elseif tabKey == "hat"     then selected.hat     = item
			elseif tabKey == "back"    then selected.back    = item
			elseif tabKey == "aura"    then selected.aura    = item
			end
			updatePreview()
			buildGrid(tabKey, items)
		end)
	end

	task.defer(function()
		gridScroll.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 24)
	end)
end

-- ============================================================
-- TAB BUTTONS  (icon + label + item count)
-- ============================================================
local function switchTab(tabKey)
	for _, tab in ipairs(TABS) do
		if tabBtns[tab.key] then
			tabBtns[tab.key].BackgroundColor3 = tab.key == tabKey and C.pink or C.panel2
			tabBtns[tab.key].TextColor3       = tab.key == tabKey and C.white or C.sub
		end
		if tab.key == tabKey then
			buildGrid(tabKey, tab.items)
		end
	end
end

for _, tab in ipairs(TABS) do
	local count = #tab.items
	local label = tab.label .. " " .. count
	local tb = mkBtn(tabBar, label, UDim2.fromOffset(100, 38), UDim2.new(0,0,0,0), C.panel2, Enum.Font.GothamBlack, 12)
	tb.TextColor3 = C.sub
	tabBtns[tab.key] = tb
	tb.MouseButton1Click:Connect(function()
		switchTab(tab.key)
	end)
end

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	gridScroll.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 24)
end)

-- ============================================================
-- READY BUTTON
-- ============================================================
local hasSubmitted = false
readyBtn.MouseButton1Click:Connect(function()
	if hasSubmitted then return end

	local accs = {}
	if selected.clothes and selected.clothes.id ~= "None" then table.insert(accs, selected.clothes.display) end
	if selected.hat     and selected.hat.id     ~= "None" then table.insert(accs, selected.hat.display)     end
	if selected.back    and selected.back.id    ~= "None" then table.insert(accs, selected.back.display)     end
	if selected.aura    and selected.aura.id    ~= "None" then table.insert(accs, selected.aura.display)     end

	SubmitCreature:FireServer({
		body        = selected.body    and selected.body.display    or "Blob",
		bodyShape   = selected.body    and selected.body.shape      or "blob",
		face        = selected.face    and selected.face.display    or "None",
		clothes     = selected.clothes and selected.clothes.display or "None",
		accessories = accs,
		name        = nameBox.Text ~= "" and nameBox.Text or "Unnamed Creature",
	})

	hasSubmitted = true
	readyBtn.Text             = "Submitted!  Waiting..."
	readyBtn.BackgroundColor3 = C.green
end)

-- ============================================================
-- JUDGING PANEL
-- ============================================================
local judgePanel = mkFrame(gui, UDim2.new(0.46,0,0.60,0), UDim2.new(0.27,0,0.20,0), C.panel, 16)
judgePanel.Visible = false
mkStroke(judgePanel, C.pink, 2)

mkLabel(judgePanel, "JUDGE THIS BRAINROT", UDim2.new(0.9,0,0,32), UDim2.new(0.05,0,0,14), C.gold, Enum.Font.GothamBlack, 22)
local judgeCreatureLabel = mkLabel(judgePanel, "", UDim2.new(0.9,0,0,70), UDim2.new(0.05,0,0,54), C.white, Enum.Font.GothamBold, 16)
local judgePromptLabel   = mkLabel(judgePanel, "", UDim2.new(0.9,0,0,22), UDim2.new(0.05,0,0,132), C.sub, Enum.Font.Gotham, 13)
local judgeProgLabel     = mkLabel(judgePanel, "", UDim2.new(0.9,0,0,20), UDim2.new(0.05,0,0,158), C.sub, Enum.Font.Gotham, 12)
mkLabel(judgePanel, "Your score:", UDim2.new(0.9,0,0,22), UDim2.new(0.05,0,0,184), C.white, Enum.Font.GothamBold, 15)

local scoreRow = mkFrame(judgePanel, UDim2.new(0.95,0,0,50), UDim2.new(0.025,0,0,212), C.bg, 0)
scoreRow.BackgroundTransparency = 1
local scoreColors = {
	rgb(220,50,50),  rgb(220,95,50),  rgb(210,135,50), rgb(195,178,50), rgb(155,198,50),
	rgb(85,198,80),  rgb(50,198,128), rgb(50,168,218), rgb(80,128,228), rgb(138,80,228),
}
for i = 1, 10 do
	local sb = mkBtn(scoreRow, tostring(i), UDim2.new(0.09,0,1,0), UDim2.new((i-1)*0.1,0,0,0), scoreColors[i], Enum.Font.GothamBlack, 18)
	sb.MouseButton1Click:Connect(function()
		SubmitScore:FireServer(i)
		judgePanel.Visible = false
	end)
end

-- ============================================================
-- RESULTS PANEL
-- ============================================================
local resultsPanel = mkFrame(gui, UDim2.new(0.5,0,0.76,0), UDim2.new(0.25,0,0.12,0), C.panel, 16)
resultsPanel.Visible = false
mkStroke(resultsPanel, C.gold, 2)
mkLabel(resultsPanel, "ROUND RESULTS", UDim2.new(0.9,0,0,34), UDim2.new(0.05,0,0,12), C.gold, Enum.Font.GothamBlack, 24)
local resultsPromptLabel = mkLabel(resultsPanel, "", UDim2.new(0.9,0,0,20), UDim2.new(0.05,0,0,52), C.sub, Enum.Font.Gotham, 13)

local resultsScroll = Instance.new("ScrollingFrame")
resultsScroll.Size                = UDim2.new(0.92,0,1,-82)
resultsScroll.Position            = UDim2.new(0.04,0,0,76)
resultsScroll.BackgroundTransparency = 1
resultsScroll.BorderSizePixel     = 0
resultsScroll.ScrollBarThickness  = 5
resultsScroll.ScrollBarImageColor3 = C.pink
resultsScroll.Parent = resultsPanel

local resultsList = Instance.new("UIListLayout")
resultsList.SortOrder = Enum.SortOrder.LayoutOrder
resultsList.Padding   = UDim.new(0, 8)
resultsList.Parent    = resultsScroll

-- ============================================================
-- GAME STATE MACHINE
-- ============================================================
local function hideAll()
	lobbyPanel.Visible    = false
	revealPanel.Visible   = false
	creationPanel.Visible = false
	judgePanel.Visible    = false
	resultsPanel.Visible  = false
end

local function resetCreation()
	selected.body    = BODY_ITEMS[1]
	selected.face    = FACE_ITEMS[2]
	selected.clothes = CLOTHES_ITEMS[1]
	selected.hat     = HAT_ITEMS[1]
	selected.back    = BACK_ITEMS[1]
	selected.aura    = AURA_ITEMS[1]
	hasSubmitted              = false
	nameBox.Text              = ""
	readyBtn.Text             = "READY FOR RUNWAY"
	readyBtn.BackgroundColor3 = C.pink
	updatePreview()
	switchTab("body")
end

GameStateChanged.OnClientEvent:Connect(function(state, data)
	hideAll()
	data = data or {}

	if state == "Lobby" then
		lobbyPanel.Visible = true

	elseif state == "PromptReveal" then
		revealPromptLabel.Text = data.prompt or "???"
		revealPanel.Visible    = true

	elseif state == "Creation" then
		resetCreation()
		creationPromptLabel.Text = "PROMPT: " .. (data.prompt or "???")
		creationPanel.Visible    = true
		task.spawn(function()
			for i = (data.timeLimit or 60), 0, -1 do
				if not creationPanel.Visible then break end
				timerLabel.Text = i .. "s"
				task.wait(1)
			end
		end)

	elseif state == "Judging" then
		if data.isJudge then
			local creature = data.creature or {}
			local accList  = {}
			for _, acc in ipairs(creature.accessories or {}) do table.insert(accList, acc) end
			judgeCreatureLabel.Text =
				'"' .. tostring(creature.name or "Unnamed") .. '"\n' ..
				tostring(creature.body or "?") .. "  •  " .. tostring(creature.face or "?") ..
				(#accList > 0 and ("\n" .. table.concat(accList, "  ")) or "")
			judgePromptLabel.Text = "Prompt: " .. (data.prompt or "???")
			judgeProgLabel.Text   = "Creature " .. (data.current or 1) .. " of " .. (data.total or 1)
			judgePanel.Visible    = true
		end

	elseif state == "Results" then
		for _, child in ipairs(resultsScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		resultsPromptLabel.Text = 'Prompt: "' .. (data.prompt or "???") .. '"'

		local medals     = { "1st", "2nd", "3rd" }
		local cardColors = { rgb(80,65,15), rgb(52,52,68), rgb(62,38,16) }
		for rank, entry in ipairs(data.results or {}) do
			local creature = entry.creature or {}
			local accList  = {}
			for _, acc in ipairs(creature.accessories or {}) do table.insert(accList, acc) end
			local card = mkFrame(resultsScroll, UDim2.new(1,0,0,66), UDim2.new(0,0,0,0), cardColors[rank] or C.card, 8)
			card.LayoutOrder = rank
			local row = mkLabel(card,
				(medals[rank] or "#"..rank) .. "  " .. tostring(creature.name or "Unnamed") ..
					"   [" .. string.format("%.1f", entry.avgScore or 0) .. "/10]\n" ..
					"     " .. tostring(creature.body or "?") .. " • " .. tostring(creature.face or "?") ..
					(#accList > 0 and ("  •  " .. table.concat(accList,"  ")) or ""),
				UDim2.new(1,-14,1,0), UDim2.fromOffset(7,0), C.white, Enum.Font.Gotham, 14)
			row.TextXAlignment = Enum.TextXAlignment.Left
		end
		resultsScroll.CanvasSize = UDim2.new(0,0,0, resultsList.AbsoluteContentSize.Y + 10)
		resultsPanel.Visible     = true
	end
end)

-- ============================================================
-- INIT
-- ============================================================
updatePreview()
switchTab("body")
print("UIController v2 ready – " ..
	#BODY_ITEMS .. " bodies, " ..
	#FACE_ITEMS .. " faces, " ..
	#CLOTHES_ITEMS .. " clothes, " ..
	#HAT_ITEMS .. " hats, " ..
	#BACK_ITEMS .. " backs, " ..
	#AURA_ITEMS .. " auras")
