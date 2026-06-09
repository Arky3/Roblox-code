-- PaintColorConfig: ModuleScript in ReplicatedStorage/Modules
-- 22-color paint palette shared by both client UI and server validation.

local PaintColorConfig = {}

PaintColorConfig.Colors = {
	{ Id = "White",      Color = Color3.fromRGB(255, 255, 255), Label = "White"       },
	{ Id = "Black",      Color = Color3.fromRGB(20,  20,  20),  Label = "Black"       },
	{ Id = "Gray",       Color = Color3.fromRGB(130, 130, 130), Label = "Gray"        },
	{ Id = "LightGray",  Color = Color3.fromRGB(200, 200, 200), Label = "Light Gray"  },
	{ Id = "DarkGreen",  Color = Color3.fromRGB(35,  90,  35),  Label = "Dark Green"  },
	{ Id = "Green",      Color = Color3.fromRGB(75,  170, 75),  Label = "Green"       },
	{ Id = "LightGreen", Color = Color3.fromRGB(130, 210, 90),  Label = "Light Green" },
	{ Id = "Red",        Color = Color3.fromRGB(215, 45,  45),  Label = "Red"         },
	{ Id = "DarkRed",    Color = Color3.fromRGB(110, 15,  15),  Label = "Dark Red"    },
	{ Id = "Orange",     Color = Color3.fromRGB(235, 125, 35),  Label = "Orange"      },
	{ Id = "Yellow",     Color = Color3.fromRGB(245, 215, 55),  Label = "Yellow"      },
	{ Id = "Gold",       Color = Color3.fromRGB(205, 165, 35),  Label = "Gold"        },
	{ Id = "Blue",       Color = Color3.fromRGB(55,  95,  215), Label = "Blue"        },
	{ Id = "LightBlue",  Color = Color3.fromRGB(95,  175, 235), Label = "Light Blue"  },
	{ Id = "DarkBlue",   Color = Color3.fromRGB(25,  45,  125), Label = "Dark Blue"   },
	{ Id = "Purple",     Color = Color3.fromRGB(135, 55,  195), Label = "Purple"      },
	{ Id = "Pink",       Color = Color3.fromRGB(235, 95,  175), Label = "Pink"        },
	{ Id = "Brown",      Color = Color3.fromRGB(135, 75,  35),  Label = "Brown"       },
	{ Id = "Tan",        Color = Color3.fromRGB(195, 155, 105), Label = "Tan"         },
	{ Id = "Cream",      Color = Color3.fromRGB(242, 235, 220), Label = "Cream"       },
	{ Id = "Teal",       Color = Color3.fromRGB(35,  155, 145), Label = "Teal"        },
	{ Id = "Cyan",       Color = Color3.fromRGB(55,  215, 205), Label = "Cyan"        },
}

-- Fast lookup by Id
PaintColorConfig.ById = {}
for _, c in ipairs(PaintColorConfig.Colors) do
	PaintColorConfig.ById[c.Id] = c
end

-- Validation set
PaintColorConfig.ValidColorIds = {}
for id in pairs(PaintColorConfig.ById) do
	PaintColorConfig.ValidColorIds[id] = true
end

-- Special sentinel value used by the Eraser tool
PaintColorConfig.ERASER_ID = "__ERASER__"

return PaintColorConfig
