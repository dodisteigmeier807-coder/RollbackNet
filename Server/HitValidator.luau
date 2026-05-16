--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local RollbackNetServer = ServerScriptService:WaitForChild("RollbackNetServer")
local SnapshotManager = require(RollbackNetServer:WaitForChild("SnapshotManager"))

local HitValidator = {}

local function DrawTracer(origin: Vector3, endPos: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = "ServerTracer"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	
	local distance = (endPos - origin).Magnitude
	part.Size = Vector3.new(0.1, 0.1, distance)
	part.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -distance / 2)
	
	part.Parent = workspace
	game:GetService("Debris"):AddItem(part, 2)
end

function HitValidator.ValidateHit(targetTime: number, hitboxes: { [string]: BasePart }, rayOrigin: Vector3, rayDirection: Vector3, player: Player?): RaycastResult?
	local originalPositions: { [string]: Vector3 } = {}
	
	-- 1. Rollback
	for id, part in hitboxes do
		local rolledBackPos = SnapshotManager.GetInterpolatedPosition(id, targetTime)
		
		-- Fallback & Safety: If position is invalid or distance is abnormally huge (> 100 studs)
		if rolledBackPos and (rolledBackPos - rolledBackPos).Magnitude == 0 then -- Check for NaN
			local currentPos = part.Position
			local dist = (rolledBackPos - currentPos).Magnitude
			
			if dist < 100 and rolledBackPos.Magnitude > 0.001 then
				originalPositions[id] = currentPos
				part.Position = rolledBackPos
			else
				warn(string.format("[HitValidator] Rollback skipped for %s: position anomaly (dist: %.2f)", id, dist))
			end
		else
			warn(string.format("[HitValidator] Rollback failed for %s: no data or NaN", id))
		end
	end
	
	-- 2. Raycast
	local params = RaycastParams.new()
	local filterList = {}
	
	-- Blacklist the shooting player
	if player and player.Character then
		table.insert(filterList, player.Character)
	end
	
	params.FilterDescendantsInstances = filterList
	params.FilterType = Enum.RaycastFilterType.Exclude -- Reverted to Exclude to hit map geometry
	
	local result = workspace:Raycast(rayOrigin, rayDirection.Unit * 500, params)
	
	-- Draw Server Tracer
	local endPos = result and result.Position or (rayOrigin + rayDirection.Unit * 100)
	DrawTracer(rayOrigin, endPos, Color3.new(1, 0, 0))
	
	-- 3. Restore
	for id, originalPos in originalPositions do
		local part = hitboxes[id]
		if part then
			part.Position = originalPos
		end
	end
	
	return result
end

return HitValidator
