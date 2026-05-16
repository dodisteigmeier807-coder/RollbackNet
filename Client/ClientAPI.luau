--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RollbackNet = ReplicatedStorage:WaitForChild("RollbackNet")
local FireProjectileEvent = RollbackNet:WaitForChild("FireProjectileEvent") :: RemoteEvent
local WeaponConfigs = require(RollbackNet:WaitForChild("WeaponConfigs"))

local ClientAPI = {}

--- Fires a weapon from the client.
--- @param configName string The name of the weapon config in WeaponConfigs.
--- @param origin Vector3 The starting position of the shot (e.g., Camera position).
--- @param direction Vector3 The look direction of the shot.
function ClientAPI.FireWeapon(configName: string, origin: Vector3, direction: Vector3)
	local config = WeaponConfigs[configName]
	if not config then warn("Weapon config not found:", configName) return end
	
	local now = os.clock()
	-- 2. Capture Base Camera Vector
	local baseCameraVector = direction.Unit -- The raw look direction provided to FireWeapon
	local recoilAdjustedDir = baseCameraVector

	-- 1. Optional Recoil Logic
	if config.UseRecoilPatterns and config.RecoilPattern then
		-- ... (logic stays same but uses baseCameraVector)
		if now - lastShotTime > config.RecoilRecoveryRate then
			currentShotIndex = 1
		else
			currentShotIndex = math.min(#config.RecoilPattern, currentShotIndex + 1)
		end
		
		local recoil = config.RecoilPattern[currentShotIndex]
		local baseCF = CFrame.lookAt(Vector3.zero, baseCameraVector)
		local recoilRotation = CFrame.Angles(math.rad(recoil.X), math.rad(recoil.Y), 0)
		recoilAdjustedDir = (baseCF * recoilRotation).LookVector

		-- Apply Camera Kick
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame * recoilRotation
		
		print(string.format("[Client] Shot (%s) #%d. Applying recoil.", configName, currentShotIndex))
	else
		print(string.format("[Client] Shot (%s). Recoil disabled.", configName))
	end
	
	lastShotTime = now
	
	-- 2. Capture Server Time and Send (include base vector and final vector)
	DrawTracer(origin, origin + recoilAdjustedDir * 100, Color3.new(0, 0,  blue))
	
	local clientTimestamp = workspace:GetServerTimeNow()
	FireProjectileEvent:FireServer(configName, clientTimestamp, origin, baseCameraVector, recoilAdjustedDir, currentShotIndex)
end

return ClientAPI
