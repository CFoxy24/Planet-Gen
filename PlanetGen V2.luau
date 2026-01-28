local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local mathSqrt = math.sqrt
local mathClamp = math.clamp
local mathCeil = math.ceil
local mathRad = math.rad

-- Precalculate golden ratio
local t = (1 + mathSqrt(5)) / 2

local TotalActors = 64
local Actors = {}
local Atmos = {}
local SunLook = {}
local Centers = {}
local isServer = RunService:IsServer()
local Camera = workspace.CurrentCamera

-- Cache task.wait locally
local taskWait = task.wait

-- Clone and initialize actors
for i = 1, TotalActors do
	local actor = script.Actors.ActorEX:Clone()
	actor.Parent = script.Actors
	actor.Name = "Actor"
	if isServer then
		actor.ServerWorker.Enabled = true
	else
		actor.ClientWorker.Enabled = true
	end
	Actors[i] = actor
	-- Wait until actor is ready
	repeat taskWait() until actor:GetAttribute("Ready")
end

-- Precalculate icosahedron vertices (unit sphere)
local V = {
	(Vector3.new(-1, t, 0)).Unit,   (Vector3.new(1, t, 0)).Unit,
	(Vector3.new(-1, -t, 0)).Unit,  (Vector3.new(1, -t, 0)).Unit,
	(Vector3.new(0, -1, t)).Unit,   (Vector3.new(0, 1, t)).Unit,
	(Vector3.new(0, -1, -t)).Unit,  (Vector3.new(0, 1, -t)).Unit,
	(Vector3.new(t, 0, -1)).Unit,   (Vector3.new(t, 0, 1)).Unit,
	(Vector3.new(-t, 0, -1)).Unit,  (Vector3.new(-t, 0, 1)).Unit,
}

local initialTriangles = {
	{ V[1], V[12], V[6] }, { V[1], V[6], V[2] }, { V[1], V[2], V[8] }, { V[1], V[8], V[11] }, { V[1], V[11], V[12] },
	{ V[2], V[6], V[10] }, { V[6], V[12], V[5] }, { V[12], V[11], V[3] }, { V[11], V[8], V[7] }, { V[8], V[2], V[9] },
	{ V[4], V[10], V[5] }, { V[4], V[5], V[3] }, { V[4], V[3], V[7] }, { V[4], V[7], V[9] }, { V[4], V[9], V[10] },
	{ V[5], V[10], V[6] }, { V[3], V[5], V[12] }, { V[7], V[3], V[11] }, { V[9], V[7], V[8] }, { V[10], V[9], V[2] },
}

local function subdivideTriangle(tri)
	local v1, v2, v3 = tri[1], tri[2], tri[3]
	-- Calculate midpoints and project onto the unit sphere
	local m1 = (v1 + v2).Unit
	local m2 = (v2 + v3).Unit
	local m3 = (v3 + v1).Unit
	return {
		{ v1, m1, m3 },
		{ v2, m2, m1 },
		{ v3, m3, m2 },
		{ m1, m2, m3 },
	}
end

local function SubdivideAndSplit(Subdivisions)
	-- Copy initial triangles
	local targetTriangles = { table.unpack(initialTriangles) }
	-- Subdivide based on GenParams.Subdivisions
	for i = 1, Subdivisions do
		local newTriangles = {}
		for j = 1, #targetTriangles do
			local subs = subdivideTriangle(targetTriangles[j])
			for k = 1, #subs do
				newTriangles[#newTriangles + 1] = subs[k]
			end
		end
		targetTriangles = newTriangles
	end

	-- Split triangles evenly among actors
	local SplittedTriangles = {}
	for i = 1, TotalActors do
		SplittedTriangles[i] = {}
	end
	local totalTris = #targetTriangles
	local factor = TotalActors / totalTris
	for i, tri in ipairs(targetTriangles) do
		local index = mathCeil(i * factor)
		SplittedTriangles[index][#SplittedTriangles[index] + 1] = tri
	end
	return SplittedTriangles
end

local module = {}

function module.CreatePlanet(GenParams)
	local startTime = os.clock()
	-- Create a model to hold planet parts
	local planetModel = Instance.new("Model")
	planetModel.Name = "Planet"
	planetModel.Parent = workspace
	local Center = Instance.new("Part")
	Center.CFrame=GenParams.CFR
	Center.Size=Vector3.zero
	Center.Transparency=1
	Center.CanCollide=false
	Center.Anchored=true
	Center.Parent=planetModel
	planetModel.PrimaryPart=Center
	
	local planetSize = GenParams.Planet_Size

	-- Dispatch calculations to actors
	local Poles = GenParams.Poles
	if Poles then
		for i, tris in ipairs(SubdivideAndSplit(GenParams.Subdivisions)) do
			Actors[i]:SendMessage("RunCalculations", tris, GenParams.Image_Size, planetSize, GenParams.CFR, GenParams.Noise, GenParams.Color_Sequence, planetModel, nil, Poles.Color_Sequence, Poles.Offset, Poles.Amplitude)
		end
	else
		for i, tris in ipairs(SubdivideAndSplit(GenParams.Subdivisions)) do
			Actors[i]:SendMessage("RunCalculations", tris, GenParams.Image_Size, planetSize, GenParams.CFR, GenParams.Noise, GenParams.Color_Sequence, planetModel)
		end
	end
	
	-- Atmosphere and additional mesh parts use a common asset
	local baseAssetId = 83680315938025
	local fixedSizeOption = { FixedSize = true }

	-- Create atmosphere meshes if required
	local atmosParams = GenParams.Atmosphere
	local NMP1, NMP2, NMP3
	local CEM1, CEM2, CEM3

	if atmosParams then
		local cloudsParams = atmosParams.Clouds
		if cloudsParams then
			local CloudsCenter = Instance.new("Part")
			CloudsCenter.CFrame=GenParams.CFR
			CloudsCenter.Parent=planetModel
			CloudsCenter.Anchored=true
			CloudsCenter.Transparency=1
			CloudsCenter.CanCollide=false
			CloudsCenter.Size=Vector3.zero
			CloudsCenter.Name="CloudsCenter"
			table.insert(Centers,{CloudsCenter,cloudsParams.Speed})
			for i, tris in ipairs(SubdivideAndSplit(cloudsParams.Subdivisions)) do
				Actors[i]:SendMessage("RunCalculations", tris, cloudsParams.Image_Size, planetSize*1.02, GenParams.CFR, cloudsParams.Noise, cloudsParams.Color, planetModel,cloudsParams.Coverage)
			end
		end
		
		-- First atmosphere mesh
		CEM1 = AssetService:CreateEditableMeshAsync(Content.fromAssetId(baseAssetId), fixedSizeOption)
		local faces = CEM1:GetFaces()
		for i = 1, #faces do
			local face = faces[i]
			local verts = CEM1:GetFaceVertices(face)
			local colorIds = CEM1:GetFaceColors(face)
			local pos1 = CEM1:GetPosition(verts[1]) * atmosParams.Atmos_Density
			local pos2 = CEM1:GetPosition(verts[2]) * atmosParams.Atmos_Density
			local pos3 = CEM1:GetPosition(verts[3]) * atmosParams.Atmos_Density

			CEM1:SetColorAlpha(colorIds[1], Vector3.new(0, pos1.Y, pos1.Z).Magnitude)
			CEM1:SetColorAlpha(colorIds[2], Vector3.new(0, pos2.Y, pos2.Z).Magnitude)
			CEM1:SetColorAlpha(colorIds[3], Vector3.new(0, pos3.Y, pos3.Z).Magnitude)
		end
		local TM1 = AssetService:CreateMeshPartAsync(Content.fromObject(CEM1))
		NMP1 = script.TMPMesh:Clone()
		NMP1:ApplyMesh(TM1)
		NMP1.Parent = planetModel
		local scale1 = planetSize * (2 + 0.04)
		NMP1.Size = Vector3.new(scale1, scale1, scale1)
		NMP1.Color = atmosParams.Atmos_Color
		NMP1.CFrame = GenParams.CFR
		NMP1.Transparency=.02
		Atmos[#Atmos + 1] = NMP1

		-- Second atmosphere mesh
		CEM2 = AssetService:CreateEditableMeshAsync(Content.fromAssetId(baseAssetId), fixedSizeOption)
		faces = CEM2:GetFaces()
		for i = 1, #faces do
			local face = faces[i]
			local verts = CEM2:GetFaceVertices(face)
			local colorIds = CEM2:GetFaceColors(face)
			local a = CEM2:GetPosition(verts[1]).X * atmosParams.Scatter_Density
			local b = CEM2:GetPosition(verts[2]).X * atmosParams.Scatter_Density
			local c = CEM2:GetPosition(verts[3]).X * atmosParams.Scatter_Density
			CEM2:SetColorAlpha(colorIds[1], mathClamp(a + atmosParams.Scatter_Size, 0, 1))
			CEM2:SetColorAlpha(colorIds[2], mathClamp(b + atmosParams.Scatter_Size, 0, 1))
			CEM2:SetColorAlpha(colorIds[3], mathClamp(c + atmosParams.Scatter_Size, 0, 1))
		end
		NMP2 = AssetService:CreateMeshPartAsync(Content.fromObject(CEM2))
		NMP2.Parent = planetModel
		local scale2 = planetSize * (2 + 0.06)
		NMP2.Size = Vector3.new(scale2, scale2, scale2)
		NMP2.Color = atmosParams.Scatter_Color
		NMP2.Anchored = true
		NMP2.CFrame = GenParams.CFR
		NMP2.Transparency=.02
		NMP2.Material = Enum.Material.Neon
		SunLook[#SunLook + 1] = {NMP2,GenParams.Planet_Size*.01}
	end

	-- Third mesh part (planet surface overlay)
	CEM3 = AssetService:CreateEditableMeshAsync(Content.fromAssetId(baseAssetId), fixedSizeOption)
	local faces3 = CEM3:GetFaces()
	for i = 1, #faces3 do
		local face = faces3[i]
		local verts = CEM3:GetFaceVertices(face)
		local colorIds = CEM3:GetFaceColors(face)
		local a = CEM3:GetPosition(verts[1]).X * GenParams.Dark_Size
		local b = CEM3:GetPosition(verts[2]).X * GenParams.Dark_Size
		local c = CEM3:GetPosition(verts[3]).X * GenParams.Dark_Size
		CEM3:SetColorAlpha(colorIds[1], mathClamp(a, 0, 1))
		CEM3:SetColorAlpha(colorIds[2], mathClamp(b, 0, 1))
		CEM3:SetColorAlpha(colorIds[3], mathClamp(c, 0, 1))
	end
	NMP3 = AssetService:CreateMeshPartAsync(Content.fromObject(CEM3))
	NMP3.Parent = planetModel
	local scale3 = planetSize * (2 + 0.08)
	NMP3.Size = Vector3.new(scale3, scale3, scale3)
	NMP3.Color = Color3.new()
	NMP3.Anchored = true
	NMP3.Material = Enum.Material.Concrete
	NMP3.CFrame = GenParams.CFR
	NMP3.Transparency=.02
	SunLook[#SunLook + 1] = {NMP3,GenParams.Planet_Size*.02}

	local endTime = os.clock()
	print(endTime - startTime)
	table.insert(Centers,{Center,GenParams.Planet_Speed})
	
	planetModel.Destroying:Connect(function()
		if CEM1 then CEM1:Destroy() end
		if CEM2 then CEM2:Destroy() end
		if CEM3 then CEM3:Destroy() end
		if NMP1 then NMP1:Destroy() end
		if NMP2 then NMP2:Destroy() end
		if NMP3 then NMP3:Destroy() end
	end)
	
	return planetModel
end

local function Update(delta)
	for i = 1, #Atmos do
		local part = Atmos[i]
			if part and part.Parent then
			part.CFrame = CFrame.lookAt(part.Parent.PrimaryPart.Position, Camera.CFrame.Position) * CFrame.Angles(0, mathRad(90), 0)
		end
	end
	-- Update SunLook parts based on the sun direction
	for i = 1, #SunLook do
		local part = SunLook[i][1]
		if part and part.Parent then
			part.CFrame = CFrame.lookAt(Vector3.zero, Lighting:GetSunDirection()) * CFrame.Angles(0, mathRad(-90), 0) + part.Parent.PrimaryPart.Position + CFrame.lookAt(part.Parent.PrimaryPart.Position, Camera.CFrame.Position).LookVector*SunLook[i][2]
		end
	end

	for i = 1, #Centers do
		local part = Centers[i][1]
		if part and part.Parent then
			part.CFrame *= CFrame.Angles(0,mathRad(delta* Centers[i][2]),0)
		end
	end
end

if isServer then
	RunService.Heartbeat:Connect(Update)
else
	RunService.RenderStepped:Connect(Update)
end

return module