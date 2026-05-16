--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RollbackNet = ReplicatedStorage:WaitForChild("RollbackNet")
local Types = require(RollbackNet:WaitForChild("Types"))
local Serializer = require(RollbackNet:WaitForChild("BufferSerializer"))
local RunService = game:GetService("RunService")

local SnapshotManager = {}

local SNAPSHOT_SIZE = 20 -- 8 (f64 timestamp) + 12 (3xf32 vector3)
local DEFAULT_BUFFER_SIZE = 60

type HitboxRecord = {
	buffer: buffer,
	count: number,
	maxSize: number,
	instance: BasePart?,
}

local hitboxes: { [string]: HitboxRecord } = {}
local currentTick = 0

-- Auto-recording loop
RunService.Heartbeat:Connect(function()
	currentTick += 1
	local now = workspace:GetServerTimeNow()
	for id, record in hitboxes do
		if record.instance and record.instance.Parent then
			SnapshotManager.SaveSnapshot(id, now, record.instance.Position)
		end
	end
end)

function SnapshotManager.UnregisterHitbox(hitboxId: string)
	if hitboxes[hitboxId] then
		hitboxes[hitboxId] = nil
	end
end

function SnapshotManager.RegisterHitbox(hitboxId: string, customSize: number?, instance: BasePart?)
	local size = customSize or DEFAULT_BUFFER_SIZE
	hitboxes[hitboxId] = {
		buffer = buffer.create(size * SNAPSHOT_SIZE),
		count = 0,
		maxSize = size,
		instance = instance,
	}
end

function SnapshotManager.SaveSnapshot(hitboxId: string, timestamp: number, position: Vector3)
	local record = hitboxes[hitboxId]
	if not record then return end
	
	-- Using integer-based incrementing count for stable ring buffer indexing
	local index = record.count % record.maxSize
	local offset = index * SNAPSHOT_SIZE
	
	buffer.writef64(record.buffer, offset, timestamp)
	Serializer.writeVector3(record.buffer, offset + 8, position)
	
	record.count += 1
end

function SnapshotManager.GetInterpolatedPosition(hitboxId: string, targetTime: number): Vector3?
	local record = hitboxes[hitboxId]
	if not record or record.count == 0 then return nil end
	
	local b = record.buffer
	local latestIdx = (record.count - 1) % record.maxSize
	local oldestIdx = (record.count > record.maxSize) and (record.count % record.maxSize) or 0
	
	-- Binary search or linear scan for the two snapshots surrounding targetTime
	-- For simplicity and 60 snapshots, linear scan from newest is efficient enough
	local nextIdx = -1
	local prevIdx = -1
	
	for i = 0, math.min(record.count, record.maxSize) - 1 do
		local currIdx = (record.count - 1 - i) % record.maxSize
		local t = buffer.readf64(b, currIdx * SNAPSHOT_SIZE)
		
		if t <= targetTime then
			prevIdx = currIdx
			nextIdx = (record.count - i) % record.maxSize -- The one we checked just before
			if i == 0 then nextIdx = -1 end -- targetTime is newer than latest
			break
		end
		nextIdx = currIdx
	end
	
	if prevIdx == -1 or nextIdx == -1 then
		-- Fallback to nearest if out of bounds
		local firstT = buffer.readf64(b, oldestIdx * SNAPSHOT_SIZE)
		local lastT = buffer.readf64(b, latestIdx * SNAPSHOT_SIZE)
		
		if targetTime <= firstT then return Serializer.readVector3(b, oldestIdx * SNAPSHOT_SIZE + 8) end
		if targetTime >= lastT then return Serializer.readVector3(b, latestIdx * SNAPSHOT_SIZE + 8) end
		return nil
	end
	
	local t1 = buffer.readf64(b, prevIdx * SNAPSHOT_SIZE)
	local t2 = buffer.readf64(b, nextIdx * SNAPSHOT_SIZE)
	
	local p1 = Serializer.readVector3(b, prevIdx * SNAPSHOT_SIZE + 8)
	local p2 = Serializer.readVector3(b, nextIdx * SNAPSHOT_SIZE + 8)
	
	-- Precision safety: check for identical timestamps to avoid division by zero
	if math.abs(t2 - t1) < 1e-5 then return p1 end
	
	local alpha = (targetTime - t1) / (t2 - t1)
	return p1:Lerp(p2, alpha)
end

return SnapshotManager
