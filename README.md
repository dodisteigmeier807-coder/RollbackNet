# RollbackNet

RollbackNet is a lightweight, zero-GC lag compensation and hit registration framework for Roblox. It utilizes native Luau buffers to provide server-authoritative hitscan networking without the memory overhead associated with traditional table-based snapshot systems.

## Overview

In standard Roblox network models, hitscan weapons often suffer from desync due to client ping. RollbackNet solves this by keeping a historical record of hitbox positions on the server. When a client fires a weapon, the server rewinds the hitboxes to the exact moment the client pulled the trigger, validates the trajectory, and confirms the hit.

## Key Features

- **Zero-GC Architecture:** Uses Luau `buffer` types to store positional history (ring buffer). This eliminates table allocation overhead and prevents Garbage Collection spikes, making it suitable for high-player-count servers.
- **Server-Authoritative Validation:** Prevents common exploits (Silent Aim, Spinbots, Fire-rate modifiers).
- **Recoil Verification:** Enforces strict deterministic recoil patterns (e.g., CS:GO style) on the server.
- **Ping Mitigation:** Caps maximum rollback time (default 250ms) to prevent high-ping players from hitting targets that are already behind cover.
- **Agnostic & Modular:** Does not require custom character controllers. It works out-of-the-box with standard R6/R15 models or custom rigs.

## Installation

1. Download the latest `RollbackNet.rbxm` from the Releases tab.
2. Drag and drop the `.rbxm` file into Roblox Studio.
3. Move the `RollbackNet` folder to `ReplicatedStorage`.
4. Move the `RollbackNetServer` folder to `ServerScriptService`.

## Quick Start

RollbackNet acts as a bridge. It handles the math and validation, but leaves game logic (health, damage, UI) entirely up to you.

### Server Implementation

To track entities and listen for validated hits, set up a server script:

--lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RollbackNetServer = require(ServerScriptService.RollbackNetServer.ServerAPI)

-- 1. Register hitboxes when a character spawns
game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Automatically finds and registers all BaseParts in the model
        RollbackNetServer:RegisterCharacter(character)
    end)
end)

-- 2. Listen for verified hits
RollbackNetServer.OnHitConfirmed.Event:Connect(function(player, weaponName, raycastResult)
    local hitPart = raycastResult.Instance
    local hitCharacter = hitPart.Parent
    
    local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
    if humanoid then
        print(player.Name .. " hit " .. hitPart.Name .. " using " .. weaponName)
        -- Implement your custom damage logic here
        -- e.g., humanoid:TakeDamage(25)
    end
end)
--

### Client Implementation

To fire a weapon, use the Client API and provide the origin and direction.

--lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ClientAPI = require(ReplicatedStorage.RollbackNet.ClientAPI)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Example: Firing a weapon towards the center of the screen
local function OnShootCommand()
    local weaponName = "Hardcore_Rifle"
    local origin = camera.CFrame.Position
    local direction = camera.CFrame.LookVector
    
    -- Send the raw input to the framework. 
    -- The client API will handle recoil application and timestamping.
    ClientAPI.FireWeapon(weaponName, origin, direction * 1000)
end
--

## Configuration

Weapon behaviors and anti-cheat strictness are defined in `ReplicatedStorage.RollbackNet.WeaponConfigs`. 

--lua
return {
    ["Hardcore_Rifle"] = {
        FireRate = 0.1,
        UseRecoilPatterns = true,
        RecoilRecoveryRate = 0.5,
        RecoilPattern = {
            Vector2.new(2, 0),
            Vector2.new(2.5, -1),
            Vector2.new(3, 1),
            -- Add as many vectors as needed
        }
    },
    ["Arcade_Pistol"] = {
        FireRate = 0.3,
        UseRecoilPatterns = false,
    }
}
--

## Architecture Notes

* **SnapshotManager:** Runs on `RunService.Heartbeat`. Records the position of registered hitboxes into binary buffers.
* **HitValidator:** Uses standard `workspace:Raycast`. It sets the `FilterType` to `Exclude` internally, ensuring that the ray accurately respects world geometry (walls, terrain) and only ignores the shooter's own character.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
