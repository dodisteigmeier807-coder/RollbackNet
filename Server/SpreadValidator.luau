--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RollbackNet = ReplicatedStorage:WaitForChild("RollbackNet")
local WeaponConfigs = require(RollbackNet:WaitForChild("WeaponConfigs"))

local SpreadValidator = {}

type PlayerState = {
	currentHeat: number,
	lastShotTime: number,
	currentShotIndex: number,
}

local playerStates: { [number]: PlayerState } = {}

function SpreadValidator.GetPlayerShotIndex(player: Player, weaponName: string): number
	local config = WeaponConfigs[weaponName]
	if not config then return 1 end
	
	local state = playerStates[player.UserId]
	if not state then
		state = { currentHeat = 0, lastShotTime = 0, currentShotIndex = 0 }
		playerStates[player.UserId] = state
	end
	
	local now = os.clock()
	if now - state.lastShotTime > config.RecoilRecoveryRate then
		return 1
	else
		return math.min(#config.RecoilPattern, state.currentShotIndex + 1)
	end
end

function SpreadValidator.GetRecoilAdjustedVector(baseLook: Vector3, weaponName: string, shotIndex: number): Vector3
	local config = WeaponConfigs[weaponName]
	if not config then return baseLook end
	
	local recoil = config.RecoilPattern[shotIndex]
	if not recoil then return baseLook end
	
	-- Use a stable CFrame construction to prevent unwanted 'Roll' desync
	-- CFrame.lookAt with a fixed UpVector ensures Pitch/Yaw rotations are consistent
	local baseCF = CFrame.lookAt(Vector3.zero, baseLook, Vector3.yAxis)
	local adjustedCF = baseCF * CFrame.Angles(math.rad(recoil.X), math.rad(recoil.Y), 0)
	
	return adjustedCF.LookVector
end

function SpreadValidator.GetPlayerSpread(player: Player, weaponName: string): number
	local config = WeaponConfigs[weaponName]
	if not config then return 0 end
	
	local state = playerStates[player.UserId]
	if not state then
		state = { currentHeat = 0, lastShotTime = 0 }
		playerStates[player.UserId] = state
	end
	
	local now = os.clock()
	local timePassed = now - state.lastShotTime
	
	-- Decay heat
	state.currentHeat = math.max(0, state.currentHeat - (timePassed * config.SpreadRecovery))
	
	return config.BaseSpread + state.currentHeat
end

function SpreadValidator.UpdateHeat(player: Player, weaponName: string)
	local config = WeaponConfigs[weaponName]
	local state = playerStates[player.UserId]
	if not config or not state then return end
	
	local now = os.clock()
	if now - state.lastShotTime > config.RecoilRecoveryRate then
		state.currentShotIndex = 1
	else
		state.currentShotIndex = math.min(#config.RecoilPattern, state.currentShotIndex + 1)
	end
	
	state.currentHeat = math.min(config.MaxSpread, state.currentHeat + config.SpreadIncrement)
	state.lastShotTime = now
end

function SpreadValidator.ClearPlayerData(player: Player)
	playerStates[player.UserId] = nil
end

function SpreadValidator.ValidateDirection(expectedLook: Vector3, clientDir: Vector3, maxSpreadDeg: number): (boolean, number)
	-- Normalize vectors
	local u = expectedLook.Unit
	local v = clientDir.Unit
	
	-- Scalar product (Dot Product)
	local dot = u:Dot(v)
	dot = math.clamp(dot, -1, 1) -- Precision safety
	
	local angleRad = math.acos(dot)
	local angleDeg = math.deg(angleRad)
	
	-- Threshold with 2.0 deg tolerance for testing stability
	return angleDeg <= (maxSpreadDeg + 2.0), angleDeg
end

return SpreadValidator
