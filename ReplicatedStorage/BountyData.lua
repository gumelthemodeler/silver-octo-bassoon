-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BountyData = {}

BountyData.Dailies = {
	{Task = "Kill", Desc = "Slay %d Enemies", Min = 10, Max = 25, Reward = 500},
	{Task = "Clear", Desc = "Clear %d Encounters", Min = 5, Max = 15, Reward = 600},
	{Task = "Maneuver", Desc = "Use Maneuver %d times", Min = 10, Max = 20, Reward = 300},
	{Task = "Transform", Desc = "Transform into a Titan %d times", Min = 2, Max = 5, Reward = 400}
}

BountyData.Weeklies = {
	{Task = "Kill", Desc = "Slay %d Enemies", Min = 150, Max = 250, RewardType = "Standard Titan Serum", RewardAmt = 1},
	{Task = "Clear", Desc = "Clear %d Encounters", Min = 75, Max = 150, RewardType = "Clan Blood Vial", RewardAmt = 1}
}

return BountyData