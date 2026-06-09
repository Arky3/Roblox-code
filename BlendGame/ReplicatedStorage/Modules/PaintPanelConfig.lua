-- PaintPanelConfig: ModuleScript in ReplicatedStorage/Modules
-- Defines every paintable body panel: which character part it maps to,
-- which face of that part the SurfaceGui should appear on, and the grid size.

local PaintPanelConfig = {}

-- NormalId usage in R6 characters:
--   Torso/Head  Front  = character's forward-facing chest/face surface
--   Torso/Head  Back   = rear surface
--   Left Arm    Left   = outer (away-from-body) surface of the left arm
--   Right Arm   Right  = outer surface of the right arm
--   Left Leg    Left   = outer surface of the left leg
--   Right Leg   Right  = outer surface of the right leg

PaintPanelConfig.Panels = {
	HeadFront  = { PartName = "Head",      Face = Enum.NormalId.Front, Width = 8,  Height = 8,  DisplayName = "Head Front"   },
	HeadBack   = { PartName = "Head",      Face = Enum.NormalId.Back,  Width = 8,  Height = 8,  DisplayName = "Head Back"    },
	TorsoFront = { PartName = "Torso",     Face = Enum.NormalId.Front, Width = 12, Height = 16, DisplayName = "Torso Front"  },
	TorsoBack  = { PartName = "Torso",     Face = Enum.NormalId.Back,  Width = 12, Height = 16, DisplayName = "Torso Back"   },
	LeftArm    = { PartName = "Left Arm",  Face = Enum.NormalId.Left,  Width = 6,  Height = 14, DisplayName = "Left Arm"     },
	RightArm   = { PartName = "Right Arm", Face = Enum.NormalId.Right, Width = 6,  Height = 14, DisplayName = "Right Arm"    },
	LeftLeg    = { PartName = "Left Leg",  Face = Enum.NormalId.Left,  Width = 6,  Height = 14, DisplayName = "Left Leg"     },
	RightLeg   = { PartName = "Right Leg", Face = Enum.NormalId.Right, Width = 6,  Height = 14, DisplayName = "Right Leg"    },
}

-- Left-to-right display order in the body-panel selector
PaintPanelConfig.PanelOrder = {
	"HeadFront", "HeadBack",
	"TorsoFront", "TorsoBack",
	"LeftArm",  "RightArm",
	"LeftLeg",  "RightLeg",
}

-- Pairs that can be mirrored.  Both directions are listed so the
-- Mirror tool works from either side.
PaintPanelConfig.MirrorPairs = {
	{ source = "LeftArm",  target = "RightArm" },
	{ source = "RightArm", target = "LeftArm"  },
	{ source = "LeftLeg",  target = "RightLeg" },
	{ source = "RightLeg", target = "LeftLeg"  },
}

-- Fast lookup set for server validation
PaintPanelConfig.ValidPanelIds = {}
for panelId in pairs(PaintPanelConfig.Panels) do
	PaintPanelConfig.ValidPanelIds[panelId] = true
end

return PaintPanelConfig
