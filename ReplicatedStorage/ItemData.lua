-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ItemData = {}

ItemData.Equipment = {
	["Training Dummy Sword"] = { Type = "Weapon", Style = "None", Rarity = "Common", Cost = 250, Bonus = { Strength = 1 }, Desc = "A blunt wooden sword. Practically useless." },
	["Cadet Training Blade"] = { Type = "Weapon", Style = "None", Rarity = "Common", Cost = 500, Bonus = { Strength = 2, Speed = 2 }, Desc = "Standard issue cadet blade." },
	["Garrison Standard Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Uncommon", Cost = 1200, Bonus = { Strength = 6, Speed = 4 }, Desc = "Standard blades used by the Garrison Regiment." },
	["Marleyan Rifle"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Uncommon", Cost = 1500, Bonus = { Strength = 25, Defense = 5 }, Desc = "Standard Marleyan military rifle." },
	["Ultrahard Steel Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Rare", Cost = 2500, Bonus = { Strength = 15, Speed = 10 }, Desc = "The staple weapon of the Scout Regiment." },
	["Advanced ODM Gear"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Epic", Cost = 5000, Bonus = { Strength = 20, Speed = 25, Gas = 10 }, Desc = "A highly maneuverable rig designed for elite Scouts." },
	["Anti-Personnel Pistols"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Rare", Cost = 3000, Bonus = { Speed = 20, Strength = 10 }, Desc = "Designed to kill humans, not titans." },
	["Prototype Thunder Spear"] = { Type = "Weapon", Style = "Thunder Spears", Rarity = "Rare", Cost = 3500, Bonus = { Strength = 20, Speed = -2 }, Desc = "An early, unstable version of the Thunder Spear." },
	["Veteran Scout Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Epic", Cost = 7500, Bonus = { Strength = 25, Speed = 15, Resolve = 10 }, Desc = "Perfectly honed blades used by surviving veterans." },
	["Thunder Spear"] = { Type = "Weapon", Style = "Thunder Spears", Rarity = "Epic", Cost = 8000, Bonus = { Strength = 35, Speed = -5 }, Desc = "High-explosive anti-armor weaponry." },
	["Iceburst Steel Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Legendary", Cost = 30000, Bonus = { Strength = 50, Speed = 35, Gas = 20 }, Desc = "Forged from rare Iceburst stone. Never dulls." },
	["Titan-Killer Artillery"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Legendary", Cost = 35000, Bonus = { Strength = 65, Defense = 10, Speed = -10 }, Desc = "A portable anti-titan cannon. Devastating power." },
	["Kenny's Custom Pistols"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Legendary", Cost = 45000, Bonus = { Speed = 50, Strength = 40 }, Desc = "The legendary weapons of Kenny the Ripper." },

	["Worn Trainee Badge"] = { Type = "Accessory", Rarity = "Common", Cost = 300, Bonus = { Resolve = 2, Health = 2 }, Desc = "A badge worn by new recruits." },
	["Scout Training Manual"] = { Type = "Accessory", Rarity = "Common", Cost = 500, Bonus = { Resolve = 5 }, Desc = "Basic training guidelines." },
	["Garrison Hip Flask"] = { Type = "Accessory", Rarity = "Uncommon", Cost = 1200, Bonus = { Health = 10, Resolve = 5 }, Desc = "Liquid courage for the wall guards." },
	["Marleyan Armband"] = { Type = "Accessory", Rarity = "Uncommon", Cost = 1500, Bonus = { Defense = 5, Strength = 5 }, Desc = "An armband worn by Marleyan forces." },
	["Scout Regiment Cloak"] = { Type = "Accessory", Rarity = "Rare", Cost = 2500, Bonus = { Defense = 10, Resolve = 15 }, Desc = "The Wings of Freedom." },
	["Marleyan Combat Manual"] = { Type = "Accessory", Rarity = "Rare", Cost = 3000, Bonus = { Strength = 15, Resolve = 10 }, Desc = "Advanced military tactics." },
	["Commander's Bolo Tie"] = { Type = "Accessory", Rarity = "Epic", Cost = 8000, Bonus = { Resolve = 30, Defense = 15 }, Desc = "Worn by the commander of the Scouts." },
	["Hardened Titan Crystal"] = { Type = "Accessory", Rarity = "Epic", Cost = 12000, Bonus = { Defense = 35, Health = 20 }, Desc = "A chunk of dense Titan hardening." },
	["Hange's Goggles"] = { Type = "Accessory", Rarity = "Epic", Cost = 15000, Bonus = { Speed = 25, Gas = 20 }, Desc = "Protects the eyes during high-speed maneuvers." },
	["Mikasa's Scarf"] = { Type = "Accessory", Rarity = "Legendary", Cost = 40000, Bonus = { Strength = 30, Speed = 30, Resolve = 25 }, Desc = "A warm, red scarf. Fills you with a burning resolve." },
	["Erwin's Pendant"] = { Type = "Accessory", Rarity = "Legendary", Cost = 45000, Bonus = { Resolve = 60, Defense = 30, Health = 30 }, Desc = "A symbol of absolute, unwavering leadership." },
	["Coordinate's Sand"] = { Type = "Accessory", Rarity = "Mythical", Cost = 250000, Bonus = { Strength = 50, Defense = 50, Speed = 50, Resolve = 50, Gas = 50, Health = 50 }, Desc = "A handful of sand from the Paths. Godlike power." }
}

ItemData.Consumables = {
	["Standard Titan Serum"] = { Rarity = "Rare", Cost = 5000, Desc = "Used in the Inherit tab to roll for a Titan." },
	["Spinal Fluid Syringe"] = { Rarity = "Legendary", Cost = 25000, Desc = "Premium item. Guarantees a Legendary or Mythical Titan." },
	["Clan Blood Vial"] = { Rarity = "Epic", Cost = 10000, Desc = "Used to roll for Clan Lineages." },

	["Ancestral Awakening Serum"] = { Rarity = "Mythical", Cost = 150000, Action = "AwakenClan", Desc = "Awakens the true power of your current lineage. Only works on major clans." },
	["Ymir's Clay Fragment"] = { Rarity = "Mythical", Cost = 150000, Action = "AwakenTitan", Desc = "Allows the Attack Titan to reach the Coordinate." },

	["Titan Hardening Extract"] = { Rarity = "Legendary", Cost = 75000, Desc = "Used in the Forge to Awaken max-tier weapons with random Substats." },

	["Iron Bamboo Extract"] = { Rarity = "Epic", Cost = 8000, Action = "Consume", Buff = "Damage", Duration = 900, Desc = "Increases all damage dealt by 50% for 15 minutes." },
	["Titan Research Notes"] = { Rarity = "Rare", Cost = 5000, Action = "Consume", Buff = "XP", Duration = 900, Desc = "Doubles all XP gained from combat and training for 15 minutes." },
	["Garrison Supply Crate"] = { Rarity = "Uncommon", Cost = 15000, Action = "Consume", Buff = "Dews", MinAmount = 5000, MaxAmount = 20000, Desc = "Instantly grants between 5,000 and 20,000 Dews when opened." },

	-- [[ GIFTS & GAMEPASSES ]]
	["Auto Train (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "AutoTrain", Desc = "Permanently unlocks Auto Train. Cannot be sold." },
	["2x XP & Funds (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "DoubleXP", Desc = "Permanently unlocks 2x XP & Dews. Cannot be sold." },
	["Titan Vault Expansion (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "TitanVault", Desc = "Unlocks Titan Vault slots 4-6. Cannot be sold." },
	["Clan Vault Expansion (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "ClanVault", Desc = "Unlocks Clan Vault slots 4-6. Cannot be sold." },
	["VIP Pass (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "VIP", Desc = "Permanently unlocks VIP status. Cannot be sold." },
	["2x Item Drops (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "DoubleDrops", Desc = "Permanently unlocks 2x Item Drops from combat. Cannot be sold." },
	["2x Battle Speed (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "DoubleSpeed", Desc = "Permanently doubles the speed of combat turns. Cannot be sold." },
	["Backpack Expansion (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "BackpackExpansion", Desc = "Permanently adds +50 slots to your Max Inventory capacity. Cannot be sold." }
}

-- [[ THE FIX: Dynamically injects an Itemized Consumable for every Titan ]]
local TitanData = require(script.Parent:WaitForChild("TitanData"))
for tName, tData in pairs(TitanData.Titans) do
	ItemData.Consumables["Itemized " .. tName] = { 
		Rarity = tData.Rarity, 
		Cost = 25000, 
		Action = "EquipTitan", 
		TitanName = tName, 
		Desc = "An extracted spine of the " .. tName .. ". Consume to equip it (WARNING: Overwrites your currently equipped Titan)." 
	}
end

ItemData.ForgeRecipes = {
	["Cadet Training Blade"] = { Result = "Garrison Standard Blades", ReqAmt = 3, DewCost = 1500 },
	["Garrison Standard Blades"] = { Result = "Ultrahard Steel Blades", ReqAmt = 3, DewCost = 4500 },
	["Ultrahard Steel Blades"] = { Result = "Advanced ODM Gear", ReqAmt = 2, DewCost = 6000 },
	["Advanced ODM Gear"] = { Result = "Veteran Scout Blades", ReqAmt = 3, DewCost = 15000 },
	["Veteran Scout Blades"] = { Result = "Iceburst Steel Blades", ReqAmt = 5, DewCost = 45000 },
	["Marleyan Rifle"] = { Result = "Anti-Personnel Pistols", ReqAmt = 3, DewCost = 5000 },
	["Anti-Personnel Pistols"] = { Result = "Titan-Killer Artillery", ReqAmt = 4, DewCost = 25000 },
	["Titan-Killer Artillery"] = { Result = "Kenny's Custom Pistols", ReqAmt = 2, DewCost = 55000 },
	["Worn Trainee Badge"] = { Result = "Scout Training Manual", ReqAmt = 2, DewCost = 500 },
	["Scout Training Manual"] = { Result = "Scout Regiment Cloak", ReqAmt = 3, DewCost = 3500 },
	["Scout Regiment Cloak"] = { Result = "Commander's Bolo Tie", ReqAmt = 3, DewCost = 10000 },
	["Commander's Bolo Tie"] = { Result = "Erwin's Pendant", ReqAmt = 3, DewCost = 50000 },

	["Standard Titan Serum"] = { Result = "Spinal Fluid Syringe", ReqAmt = 10, DewCost = 50000 },
	["Spinal Fluid Syringe"] = { Result = "Ymir's Clay Fragment", ReqAmt = 10, DewCost = 1000000 },

	["Clan Blood Vial"] = { Result = "Titan Hardening Extract", ReqAmt = 5, DewCost = 100000 },
	["Titan Hardening Extract"] = { Result = "Ancestral Awakening Serum", ReqAmt = 5, DewCost = 1000000 }
}

ItemData.Gamepasses = {
	{ ID = 1749846514, GiftID = 3562817556, Name = "Auto Train", Desc = "Passively generates Training XP in the background.", Key = "AutoTrain" },
	{ ID = 1748534838, GiftID = 3562817710, Name = "2x XP & Funds", Desc = "Doubles all XP and Dews gained from combat and training.", Key = "DoubleXP" },
	{ ID = 1748263337, GiftID = 3562817821, Name = "Titan Vault Expansion", Desc = "Unlocks slots 4, 5, and 6 in the Titan vault.", Key = "TitanVault" },
	{ ID = 1760797262, GiftID = 3562817914, Name = "Clan Vault Expansion", Desc = "Unlocks slots 4, 5, and 6 in the Clan vault.", Key = "ClanVault" },
	{ ID = 1747847881, GiftID = 3562817987, Name = "VIP Pass", Desc = "Exclusive Golden Chat Tag, 1 Free Shop Reroll, +25% Auto-Train Synergy!", Key = "VIP" },
	{ ID = 1772364456, GiftID = 3564165877, Name = "2x Item Drops", Desc = "Doubles the amount of items dropped from bosses and enemies.", Key = "DoubleDrops" },
	{ ID = 1772394444, GiftID = 3564165946, Name = "2x Battle Speed", Desc = "Doubles the animation speed and turn resolution in combat.", Key = "DoubleSpeed" },
	{ ID = 1772982444, GiftID = 3564166063, Name = "Backpack Expansion", Desc = "Permanently adds +50 slots to your Max Inventory capacity.", Key = "BackpackExpansion" }
}

ItemData.Products = {
	{ ID = 3557925572, Name = "Shop Reroll", Desc = "Instantly restocks the Military Supply with new items.", IsReroll = true },
	{ ID = 3557909080, Name = "5,000 Dews", Desc = "A small injection of military funds.", Reward = "Dews", Amount = 5000 },
	{ ID = 3557908989, Name = "15,000 Dews", Desc = "A healthy supply of military funds.", Reward = "Dews", Amount = 15000 },
	{ ID = 3557908863, Name = "50,000 Dews", Desc = "A massive vault of military funds.", Reward = "Dews", Amount = 50000 },
	{ ID = 3557909565, Name = "1x Titan Serum", Desc = "Grants one Standard Titan Serum.", Reward = "Item", ItemName = "Standard Titan Serum", Amount = 1 },
	{ ID = 3557909698, Name = "5x Titan Serums", Desc = "Grants five Standard Titan Serums.", Reward = "Item", ItemName = "Standard Titan Serum", Amount = 5 },
	{ ID = 3557938597, Name = "1x Clan Vial", Desc = "Grants one Clan Blood Vial.", Reward = "Item", ItemName = "Clan Blood Vial", Amount = 1 },
	{ ID = 3557938636, Name = "5x Clan Vials", Desc = "Grants five Clan Blood Vials.", Reward = "Item", ItemName = "Clan Blood Vial", Amount = 5 },

	{ ID = 3562817556, Name = "Gift: Auto Train", Desc = "Grants a tradable Auto Train pass.", Reward = "Item", ItemName = "Auto Train (Gift)", Amount = 1 },
	{ ID = 3562817710, Name = "Gift: 2x XP & Funds", Desc = "Grants a tradable 2x XP pass.", Reward = "Item", ItemName = "2x XP & Funds (Gift)", Amount = 1 },
	{ ID = 3562817821, Name = "Gift: Titan Vault", Desc = "Grants a tradable Titan Vault Expansion.", Reward = "Item", ItemName = "Titan Vault Expansion (Gift)", Amount = 1 },
	{ ID = 3562817914, Name = "Gift: Clan Vault", Desc = "Grants a tradable Clan Vault Expansion.", Reward = "Item", ItemName = "Clan Vault Expansion (Gift)", Amount = 1 },
	{ ID = 3562817987, Name = "Gift: VIP Pass", Desc = "Grants a tradable VIP Pass.", Reward = "Item", ItemName = "VIP Pass (Gift)", Amount = 1 },

	{ ID = 3564165877, Name = "Gift: 2x Item Drops", Desc = "Grants a tradable 2x Drops pass.", Reward = "Item", ItemName = "2x Item Drops (Gift)", Amount = 1 },
	{ ID = 3564165946, Name = "Gift: 2x Battle Speed", Desc = "Grants a tradable 2x Battle Speed pass.", Reward = "Item", ItemName = "2x Battle Speed (Gift)", Amount = 1 },
	{ ID = 3564166063, Name = "Gift: Backpack Expansion", Desc = "Grants a tradable Backpack Expansion pass.", Reward = "Item", ItemName = "Backpack Expansion (Gift)", Amount = 1 }
}

return ItemData