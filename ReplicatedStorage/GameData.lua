-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local GameData = {}

GameData.TitanRanks = {
	["E"] = 5, ["D"] = 10, ["C"] = 15,
	["B"] = 20, ["A"] = 25, ["S"] = 30,
	["None"] = 0
}

GameData.BaseStats = { Health = 1, Strength = 1, Defense = 1, Speed = 1, Stamina = 1, Willpower = 1 }

GameData.TitanStats = { "Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val" }

GameData.WeaponBonuses = {
	["Unarmed"] = { Stamina = 15, Speed = 5 },
	["Ultrahard Steel Blades"] = { Strength = 25, Speed = 15 },
	["Thunder Spears"] = { Strength = 60, Defense = -15 },
	["Anti-Personnel Firearms"] = { Precision = 40, Speed = 20 },
	["Titan Martial Arts"] = { Health = 35, Strength = 30 },
	["Marleyan Rifle"] = { Precision = 25, Willpower = 10 },
	["Heavy Artillery"] = { Strength = 75, Speed = -25 },
}

GameData.StatDescriptions = {
	Health = "Increases your Maximum HP. Essential for surviving Titan attacks.",
	Strength = "Increases the base damage of your blades and physical strikes.",
	Defense = "Reduces the amount of damage you take from all incoming attacks.",
	Speed = "Determines turn order and increases your chance to dodge incoming grabs.",
	Stamina = "Required to use ODM gear and perform physical skills. Regenerates slowly.",
	Willpower = "Increases critical hit chance and reduces cooldowns on heavy abilities.",
	Titan_Power = "Increases the overall damage dealt while transformed into a Titan.",
	Titan_Speed = "Boosts your overall combat speed and dodge chance when transformed.",
	Titan_Hardening = "Provides a protective barrier and massive damage reduction.",
	Titan_Endurance = "Increases the maximum health pool of your Titan form.",
	Titan_Precision = "Vastly increases your critical hit chance to strike enemy napes.",
	Titan_Potential = "Increases your Maximum Titan Energy, allowing for more frequent abilities."
}

GameData.BattleConditions = {
	["Clear Weather"] = { Description = "Conditions are standard. No advantages or disadvantages.", Color = "#FFFFFF" },
	["Night Operation"] = { Description = "Pure Titans lack sunlight and become sluggish. Enemies suffer -25% Speed.", Color = "#00008B" },
	["Rainstorm"] = { Description = "Visibility is poor and ODM grips slip. Player suffers -15% Speed and -15% Precision.", Color = "#5555FF" },
	["Forest of Giant Trees"] = { Description = "Perfect terrain for ODM Gear. Player gains +30% Speed and +15% Strength.", Color = "#228B22" },
	["Open Plains"] = { Description = "Nowhere to grapple. Player suffers -25% Speed and -10% Defense.", Color = "#DAA520" },
	["The Rumbling"] = { Description = "Absolute chaos. Everyone (Player and Enemies) deals +50% damage.", Color = "#FF0000" }
}

function GameData.GetStatCap(prestige)
	return 100 + ((prestige or 0) * 10)
end

function GameData.CalculateStatCost(currentStat, baseStat, prestige)
	local baseCost = 10
	local growthFactor = 1.05
	local prestigeMultiplier = math.max(0.1, 1 - (prestige * 0.03))
	local statDifference = math.max(0, currentStat - baseStat)
	return math.floor(baseCost * (growthFactor ^ statDifference) * prestigeMultiplier)
end

function GameData.GetMaxInventory(player)
	if not player then return 15 end
	local baseMax = 15

	local clanBoost = player:GetAttribute("ClanInvBoost") or 0

	local ls = player:FindFirstChild("leaderstats")
	local elo = ls and ls:FindFirstChild("Elo") and ls.Elo.Value or 1000
	local eloBoost = elo >= 4000 and 5 or 0

	local totalCapacity = baseMax + clanBoost + eloBoost

	-- [[ THE FIX: Applied Backpack Expansion Gamepass ]]
	if player:GetAttribute("HasBackpackExpansion") then
		totalCapacity = totalCapacity + 50
	end

	if player:GetAttribute("Has2xInventory") then
		totalCapacity = totalCapacity * 2
	end

	return totalCapacity
end

function GameData.GetInventoryCount(player)
	if not player then return 0 end
	local count = 0

	local ItemData = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemData"))
	local ignoredKeys = {}

	for itemName, data in pairs(ItemData.Consumables) do
		ignoredKeys[itemName:gsub("[^%w]", "") .. "Count"] = true
	end

	for itemName, data in pairs(ItemData.Equipment) do
		if data.Rarity == "Unique" then
			ignoredKeys[itemName:gsub("[^%w]", "") .. "Count"] = true
		end
	end

	local attrs = player:GetAttributes()
	for key, val in pairs(attrs) do
		if type(val) == "number" and val > 0 and string.sub(key, -5) == "Count" then
			if not ignoredKeys[key] then
				count += val
			end
		end
	end
	return count
end

return GameData