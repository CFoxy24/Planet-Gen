--[[
=========================================

DOCUMENTATION FOR THE PLANET GENERATION

=========================================

If you just want to experiment by yourself, here is a small code you can simply paste into a script:
It will create a planet in the center of the world, this planet is Percephone from SpaceConquest!
------------ Start:

local Seed = 0
local GenParams = {
	CFR = CFrame.new(0,0,0),
	Subdivisions=2,
	Planet_Size=1000,
	Image_Size=30,
	Color_Palette=workspace:GetAttribute("ColorC"),
	Noise={Vector3.one*2, 16, 1.4, .85, Seed},
	
	Atmosphere={
		Atmos_Density=.007,
		Atmos_Color=Color3.fromRGB(112, 133, 255),
		Scatter_Density=.007,
		Scatter_Color=Color3.fromRGB(255, 180, 89),
		Scatter_Size=.05,
		Dark_Size=.019
	},
}

------------ End

Below is a full explanation of every properties you can adjust:

====
local TerrainSeed = 0

The seed of the terrain generation, a different seed will generate a different terrain


====
local CloudSeed = 1000



====

]]