local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RollbackNetServer = ServerScriptService:WaitForChild("RollbackNetServer")
local SnapshotManager = require(RollbackNetServer:WaitForChild("SnapshotManager"))
local ServerAPI = require(RollbackNetServer:WaitForChild("ServerAPI"))

local dummy = workspace:WaitForChild("TestDummy")

-- Register the dummy in the system (Auto-recording loop is now inside SnapshotManager)
ServerAPI.RegisterHitbox(dummy)

-- Mock hitbox provider that includes the dummy
local function getHitboxes()
    return {["TestDummy"] = dummy} -- Note: RegisterHitbox uses Name by default
end

ServerAPI.Init(getHitboxes)

print("[Server Test] TestDummy registered in RollbackNet (Stable Mode).")
