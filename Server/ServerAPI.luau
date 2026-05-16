--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RollbackNet = ReplicatedStorage:WaitForChild("RollbackNet")
local RollbackNetServer = ServerScriptService:WaitForChild("RollbackNetServer")

local WeaponConfigs = require(RollbackNet:WaitForChild("WeaponConfigs"))
local FireProjectileEvent = RollbackNet:WaitForChild("FireProjectileEvent") :: RemoteEvent
local HitValidator = require(RollbackNetServer:WaitForChild("HitValidator"))
local SpreadValidator = require(RollbackNetServer:WaitForChild("SpreadValidator"))

local ServerAPI = {}

--- Event fired when a hit is confirmed by the server.
--- @param player Player The player who fired the shot.
--- @param weaponName string The name of the weapon used.
--- @param raycastResult RaycastResult Detailed hit data.
ServerAPI.OnHitConfirmed = Instance.new("BindableEvent")

-- Constant for sanity checks
local MAX_ALLOWED_LATENCY = 0.5 -- 500ms
local MAX_ROLLBACK_TIME = 0.25 -- 250ms max compensation for fairness
local playerLastShotTimes: { [number]: number } = {}

--- Registers a single part as a rollback-tracked hitbox.
--- @param hitboxInstance BasePart The part to track.
--- @param customSize number? Optional buffer size (default: 60).
function ServerAPI.RegisterHitbox(hitboxInstance: BasePart, customSize: number?)
	local SnapshotManager = require(ServerScriptService.RollbackNetServer.SnapshotManager)
	local hitboxId = hitboxInstance.Name -- Using name as ID for simplicity, or unique ID
	
	SnapshotManager.RegisterHitbox(hitboxId, customSize, hitboxInstance)
	
	hitboxInstance.Destroying:Connect(function()
		SnapshotManager.UnregisterHitbox(hitboxId)
	end)
end

--- Registers all BaseParts within a model (e.g., Character) as hitboxes.
--- @param characterModel Model The model to scan.
--- @param customSize number? Optional buffer size.
function ServerAPI.RegisterCharacter(characterModel: Model, customSize: number?)
	for _, child in characterModel:GetDescendants() do
		if child:IsA("BasePart") then
			ServerAPI.RegisterHitbox(child, customSize)
		end
	end
end

--- Initializes the Rollback Server.
--- @param hitboxProvider function A function that returns a table of tracked hitboxes.
function ServerAPI.Init(hitboxProvider: () -> { [string]: BasePart })
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		playerLastShotTimes[player.UserId] = nil
		SpreadValidator.ClearPlayerData(player)
		print("[RollbackNet] Player data cleared: " .. player.Name)
	end)
	
	FireProjectileEvent.OnServerEvent:Connect(function(player: Player, configName: string, clientTimestamp: number, origin: Vector3, baseDir: Vector3, finalDir: Vector3, clientShotIndex: number)
		local config = WeaponConfigs[configName]
		if not config then return end
		
		local serverTime = workspace:GetServerTimeNow()
		local pingDelta = math.abs(serverTime - clientTimestamp)
		
		-- 1. Sanity Check: Lag Switch / High Ping
		if pingDelta > MAX_ALLOWED_LATENCY then
			warn(string.format("[Server] Shot rejected for %s: ping too high (%.2fms)", player.Name, pingDelta * 1000))
			return
		end
		
		-- 2. Sanity Check: Future Packets
		if clientTimestamp > serverTime + 0.05 then
			warn(string.format("[Server] Shot rejected for %s: packet from future", player.Name))
			return
		end
		
		-- 2.1 Soft Fire-Rate Check
		local now = os.clock()
		local lastShot = playerLastShotTimes[player.UserId] or 0
		local delta = now - lastShot
		
		-- 70% threshold to allow for network jitter (soft check)
		if config.FireRate and delta < (config.FireRate * 0.7) then
			warn(string.format("[Server - AntiCheat] Fast Fire Detected for %s! Delta: %.3fs, Expected: %.3fs", player.Name, delta, config.FireRate))
			return
		end
		playerLastShotTimes[player.UserId] = now

		-- 3. Modular Validation (Smart Anti-Cheat)
		if config.EnableSpreadValidation then
			local char = player.Character
			if not char or not char:FindFirstChild("HumanoidRootPart") then return end
			
			-- A. Spinbot / Snap Check (Is player shooting behind themselves?)
			local hrpLook = char.HumanoidRootPart.CFrame.LookVector
			if baseDir:Dot(hrpLook) < -0.5 then -- Tolerance for looking back
				warn(string.format("[Server - AntiCheat] Spinbot/Impossible Angle Detected for %s!", player.Name))
				return
			end

			-- B. Recoil Pattern Validation with Index Jitter Protection
			local shotIndex = clientShotIndex or 1
			if config.RecoilPattern then
				shotIndex = math.clamp(shotIndex, 1, #config.RecoilPattern)
			end
			
			local expectedFinal = baseDir
			if config.UseRecoilPatterns then
				expectedFinal = SpreadValidator.GetRecoilAdjustedVector(baseDir, configName, shotIndex)
			end
			
			-- Tolerance logic: Check current index and broader window (network jitter protection)
			local tolerance = 10.0 -- 10 degrees for perfect vertical stability
			local validated, deviation = SpreadValidator.ValidateDirection(expectedFinal, finalDir, tolerance)
			
			-- If failed, check +/- 3 indices to account for high-speed burst jitter or slight latency
			if not validated and config.UseRecoilPatterns and config.RecoilPattern then
				for offset = -3, 3 do
					if offset == 0 then continue end
					local checkIndex = math.clamp(shotIndex + offset, 1, #config.RecoilPattern)
					local otherExpected = SpreadValidator.GetRecoilAdjustedVector(baseDir, configName, checkIndex)
					local altValidated, altDeviation = SpreadValidator.ValidateDirection(otherExpected, finalDir, tolerance)
					if altValidated then
						validated = true
						deviation = altDeviation
						shotIndex = checkIndex 
						break
					end
				end
			end
			
			if not validated then
				warn(string.format("[Server - AntiCheat] Validation Failed for %s (Weapon: %s)! Index: %d, Angle Deviation: %.2f°", player.Name, configName, clientShotIndex, deviation))
				return
			end
			
			SpreadValidator.UpdateHeat(player, configName)
		end
		
		-- 4. Perform Rollback & Validation using finalDir
		local targetRollbackTime = math.max(clientTimestamp, serverTime - MAX_ROLLBACK_TIME)
		
		local hitboxes = hitboxProvider()
		local hitResult = HitValidator.ValidateHit(targetRollbackTime, hitboxes, origin, finalDir, player)
		
		if hitResult then
			ServerAPI.OnHitConfirmed:Fire(player, configName, hitResult)
		end
	end)
end

return ServerAPI
