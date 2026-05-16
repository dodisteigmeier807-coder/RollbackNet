--!strict
--- Configuration for different weapon types.
--- @class WeaponConfig
--- @field EnableSpreadValidation boolean If true, server will validate shot angles.
--- @field UseRecoilPatterns boolean If true, complex recoil patterns are applied.
--- @field FireRate number Delay between shots.
--- @field RecoilRecoveryRate number Time until recoil resets.
--- @field RecoilPattern table List of Vector2 offsets for burst fire.
local WeaponConfigs = {
	Hardcore_Rifle = {
		EnableSpreadValidation = true,
		UseRecoilPatterns = true,
		FireRate = 0.1, -- 10 shots per second
		
		BaseSpread = 0.5,
		MaxSpread = 4.0,
		SpreadIncrement = 0.3,
		SpreadRecovery = 2.0,
		
		RecoilRecoveryRate = 0.5,
		RecoilPattern = {
			Vector2.new(0.0, 0.0),
			Vector2.new(0.8, 0.1),
			Vector2.new(1.5, 0.2),
			Vector2.new(2.1, -0.3),
			Vector2.new(2.5, -0.6),
			Vector2.new(2.8, 0.0),
		}
	},
	Arcade_Pistol = {
		EnableSpreadValidation = false,
		UseRecoilPatterns = false,
		FireRate = 0.3, -- ~3 shots per second
		-- No recoil or complex spread needed here
	}
}

return WeaponConfigs
