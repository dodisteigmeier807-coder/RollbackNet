# 🎯 RollbackNet

> **Zero-GC Server Authoritative Lag Compensation & Anti-Cheat Framework for Roblox**

RollbackNet is a lightweight, zero-garbage-collection lag compensation and hit registration framework for Roblox. It utilizes native Luau buffers to provide server-authoritative hitscan networking without memory overhead. Perfect for competitive shooter games requiring strict anti-cheat validation and ping mitigation.

---

## 📋 Overview

In standard Roblox network models, hitscan weapons often suffer from desynchronization due to client ping. RollbackNet solves this by maintaining a historical record of hitbox positions on the server. When a client fires a shot, the server rolls back to the time when the shot was fired and validates the hit against the hitbox positions at that moment—eliminating ghost hits while preventing exploits.

---

## ✨ Key Features

- **⚡ Zero-GC Architecture**
  - Uses Luau `buffer` types to store positional history (ring buffer)
  - Eliminates table allocation overhead
  - Prevents Garbage Collection spikes during gameplay

- **🛡️ Server-Authoritative Validation**
  - Prevents common exploits: Silent Aim, Spinbots, Fire-rate modifiers
  - Strict server-side enforcement of all weapon rules

- **🔫 Recoil Verification**
  - Enforces deterministic recoil patterns (CS:GO style)
  - Validates client recoil application server-side

- **📡 Ping Mitigation**
  - Configurable maximum rollback time (default: 250ms)
  - Prevents high-ping players from hitting targets already behind cover

- **🔧 Agnostic & Modular**
  - Works with standard R6/R15 models or custom rigs
  - Drop-in ready—no custom character controllers required
  - Strictly typed for safety and IDE support

---

## 📦 Installation

1. Download the latest `RollbackNet.rbxm` from the [Releases](../../releases) tab
2. Drag and drop the `.rbxm` file into Roblox Studio
3. Move the `RollbackNet` folder to `ReplicatedStorage`
4. Move the `RollbackNetServer` folder to `ServerScriptService`

---

## 🚀 Quick Start

RollbackNet acts as a validation bridge—it handles the math and hit detection, but leaves game logic (health, damage, UI) entirely up to you.

### Server Implementation

Set up a server script to track entities and listen for validated hits:

```lua
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
```

### Client Implementation

Fire weapons using the Client API with origin and direction vectors:

```lua
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
    
    -- Send the raw input to the framework
    -- The client API will handle recoil application and timestamping
    ClientAPI.FireWeapon(weaponName, origin, direction * 1000)
end
```

---

## ⚙️ Configuration

Weapon behaviors and anti-cheat strictness are defined in `ReplicatedStorage.RollbackNet.WeaponConfigs`:

```lua
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
```

---

## 🏗️ Architecture Notes

- **SnapshotManager**
  - Runs on `RunService.Heartbeat`
  - Records hitbox positions into binary buffers at each frame
  - Maintains a fixed-size ring buffer for efficient memory usage

- **HitValidator**
  - Uses standard `workspace:Raycast` for hit detection
  - Sets `FilterType` to `Exclude` internally
  - Respects world geometry (walls, terrain)
  - Validates shots against server-recorded positions at the time of firing

---

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

---

**Made with ❤️ for competitive Roblox gaming**
