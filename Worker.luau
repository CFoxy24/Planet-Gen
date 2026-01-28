local AssetService = game:GetService("AssetService")

local mathClamp = math.clamp
local mathNoise = math.noise
local Vector2_new = Vector2.new
local taskWait = task.wait
local buffer_writeu8 = buffer.writeu8

local function fractalNoise(x, y, z, octaves, lacunarity, persistence, seed)
	local value = 0
	local amplitude = 1
	local frequency = 1
	for i = 1, octaves do
		value = value + mathNoise(seed + x * frequency, seed + y * frequency, seed + z * frequency) * amplitude
		frequency = frequency * lacunarity
		amplitude = amplitude * persistence
	end
	return mathClamp(value, -1, 1)
end

local function GetColor(seq, perc)
	local keypoints = seq.Keypoints
	local n = #keypoints
	-- Early exit if before the first keypoint
	if perc <= keypoints[1].Time then
		return keypoints[1].Value
	end
	for i = 1, n - 1 do
		local current = keypoints[i]
		local following = keypoints[i + 1]
		if perc < following.Time then
			local diff = (perc - current.Time) / (following.Time - current.Time)
			return current.Value:Lerp(following.Value, diff)
		end
	end
	return keypoints[n].Value
end

script.Parent:BindToMessage("RunCalculations", function(triangles, ISize, MSize, CFR, Noise, Color, Parent, Cloud, Color2, Offset, Amplitude)
	local invISize = 1 / ISize

	for _, tri in ipairs(triangles) do
		-- Cache triangle vertices for reuse
		local v1, v2, v3 = tri[1], tri[2], tri[3]

		local IMG = AssetService:CreateEditableImage({Size = Vector2_new(ISize, ISize)})
		local PixelsBuffer = buffer.create(ISize * ISize * 4)
		local AntiCrash = 0
		local index = 0

		-- Spawn a task for image processing
		task.spawn(function()
			if Cloud then
				for y = 0, ISize - 1 do
					local rowIndex = y * ISize
					for x = 0, ISize - 1 do
						AntiCrash = AntiCrash + 1
						local u = x * invISize
						local v = y * invISize

						if u + v <= 1 then
							local w = 1 - u - v
							-- Compute barycentric combination and normalize
							local vec = (v1 * w + v2 * u + v3 * v).Unit
							-- Calculate fractal noise value and scale to 0-1 range
							local clampedNoise = mathClamp(mathClamp(fractalNoise(vec.X * Noise[1].X, vec.Y * Noise[1].Y, vec.Z * Noise[1].Z, Noise[2], Noise[3], Noise[4], Noise[5]) * 0.5 + 0.5, 0, 1)-(1-Cloud),0,1)/Cloud

							buffer_writeu8(PixelsBuffer, index,     Color.R * 255)
							buffer_writeu8(PixelsBuffer, index + 1, Color.G * 255)
							buffer_writeu8(PixelsBuffer, index + 2, Color.B * 255)
							buffer_writeu8(PixelsBuffer, index + 3, clampedNoise * 255)
						end
						index=index+4

						-- Yield periodically to prevent a long stall
						if AntiCrash % 400 == 1 then
							taskWait()
						end
					end
				end
			elseif Color2 then
				for y = 0, ISize - 1 do
					local rowIndex = y * ISize
					for x = 0, ISize - 1 do
						AntiCrash = AntiCrash + 1
						local u = x * invISize
						local v = y * invISize

						if u + v <= 1 then
							local w = 1 - u - v
							-- Compute barycentric combination and normalize
							local vec = (v1 * w + v2 * u + v3 * v).Unit
							-- Calculate fractal noise value and scale to 0-1 range
							local clampedNoise = mathClamp(fractalNoise(vec.X * Noise[1].X, vec.Y * Noise[1].Y, vec.Z * Noise[1].Z, Noise[2], Noise[3], Noise[4], Noise[5]) * 0.5 + 0.5, 0, 1)
							local colorValue = GetColor(Color, clampedNoise)
							local colorValue2 = GetColor(Color2, clampedNoise)
							local colorValue3 = colorValue:Lerp(colorValue2,mathClamp((math.abs(vec.Y)-Offset)*Amplitude,0,1))

							buffer_writeu8(PixelsBuffer, index,     colorValue3.R * 255)
							buffer_writeu8(PixelsBuffer, index + 1, colorValue3.G * 255)
							buffer_writeu8(PixelsBuffer, index + 2, colorValue3.B * 255)
						end
						index=index+4

						-- Yield periodically to prevent a long stall
						if AntiCrash % 400 == 1 then
							taskWait()
						end
					end
				end
			else
				for y = 0, ISize - 1 do
					local rowIndex = y * ISize
					for x = 0, ISize - 1 do
						AntiCrash = AntiCrash + 1
						local u = x * invISize
						local v = y * invISize

						if u + v <= 1 then
							local w = 1 - u - v
							-- Compute barycentric combination and normalize
							local vec = (v1 * w + v2 * u + v3 * v).Unit
							-- Calculate fractal noise value and scale to 0-1 range
							local clampedNoise = mathClamp(fractalNoise(vec.X * Noise[1].X, vec.Y * Noise[1].Y, vec.Z * Noise[1].Z, Noise[2], Noise[3], Noise[4], Noise[5]) * 0.5 + 0.5, 0, 1)
							local colorValue = GetColor(Color, clampedNoise)

							buffer_writeu8(PixelsBuffer, index,     colorValue.R * 255)
							buffer_writeu8(PixelsBuffer, index + 1, colorValue.G * 255)
							buffer_writeu8(PixelsBuffer, index + 2, colorValue.B * 255)
						end
						index=index+4

						-- Yield periodically to prevent a long stall
						if AntiCrash % 400 == 1 then
							taskWait()
						end
					end
				end
			end

			IMG:WritePixelsBuffer(Vector2_new(0, 0), Vector2_new(ISize, ISize), PixelsBuffer)
		end)

		-- Spawn a task for mesh creation
		task.spawn(function()
			local EM = AssetService:CreateEditableMesh()
			local OF = 1 / ISize
			-- Pre-calculate UVs to avoid recreating each time
			local uv1 = Vector2_new(OF, OF)
			local uv2 = Vector2_new(1 - OF, OF)
			local uv3 = Vector2_new(OF, 1 - OF)
			EM:SetFaceUVs(
				EM:AddTriangle(
					EM:AddVertex(v1),
					EM:AddVertex(v2),
					EM:AddVertex(v3)
				),
				{ EM:AddUV(uv1), EM:AddUV(uv2), EM:AddUV(uv3) }
			)
			local AS = AssetService:CreateEditableMeshAsync(Content.fromObject(EM),{FixedSize=true})
			EM:Destroy()
			
			local M = AssetService:CreateMeshPartAsync(Content.fromObject(AS))
			M.Parent = Parent
			M.Size = M.Size * MSize
			M.CFrame = CFR
			M.TextureContent = Content.fromObject(IMG)

			local w = Instance.new("Weld")
			w.Parent=M
			w.Part0=M

			if Cloud then
				w.Part1=Parent.CloudsCenter
				M.Transparency=.02
				M.Material = Enum.Material.Glass
			else
				w.Part1=Parent.PrimaryPart
				M.Material = Enum.Material.Grass
			end
			
			Parent.Destroying:Connect(function()
				if AS then AS:Destroy()end
				if EM then EM:Destroy()end
				if IMG then IMG:Destroy()end
				if M then M:Destroy()end
			end)
		end)
	end
end)


script.Parent:SetAttribute("Ready", true)
