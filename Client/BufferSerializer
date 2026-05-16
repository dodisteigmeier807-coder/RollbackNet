--!strict
local BufferSerializer = {}

function BufferSerializer.writeVector3(b: buffer, offset: number, vec: Vector3)
	local x = vec.X
	local y = vec.Y
	local z = vec.Z
	
	-- NaN protection
	if x ~= x then x = 0 end
	if y ~= y then y = 0 end
	if z ~= z then z = 0 end
	
	buffer.writef32(b, offset, x)
	buffer.writef32(b, offset + 4, y)
	buffer.writef32(b, offset + 8, z)
end

function BufferSerializer.readVector3(b: buffer, offset: number): Vector3
	local x = buffer.readf32(b, offset)
	local y = buffer.readf32(b, offset + 4)
	local z = buffer.readf32(b, offset + 8)
	return Vector3.new(x, y, z)
end

return BufferSerializer
