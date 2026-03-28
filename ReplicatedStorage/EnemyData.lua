-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local EnemyData = {}

local emptyTitans = {Power="None", Speed="None", Hardening="None", Endurance="None", Precision="None", Potential="None"}

EnemyData.Allies = {
	["Armin Arlert"] = { Name = "Armin Arlert", Health = 80, Strength = 12, Defense = 5, Speed = 8, Resolve = 25, TitanStats = emptyTitans, Skills = {"Spinning Slash", "Recover", "Basic Slash"} },
	["Mikasa Ackerman"] = { Name = "Mikasa Ackerman", Health = 150, Strength = 40, Defense = 10, Speed = 35, Resolve = 15, TitanStats = emptyTitans, Skills = {"Nape Strike", "Spinning Slash", "Basic Slash"} },
	["Levi Ackerman"] = { Name = "Levi Ackerman", Health = 250, Strength = 65, Defense = 15, Speed = 55, Resolve = 30, TitanStats = emptyTitans, Skills = {"Nape Strike", "Maneuver", "Spinning Slash"} },
	["Hange Zoe"] = { Name = "Hange Zoe", Health = 200, Strength = 30, Defense = 20, Speed = 25, Resolve = 25, TitanStats = emptyTitans, Skills = {"Spear Volley", "Maneuver", "Basic Slash"} },
	["Erwin Smith"] = { Name = "Erwin Smith", Health = 400, Strength = 35, Defense = 30, Speed = 20, Resolve = 100, Skills = {"Basic Slash", "Recover"} }
}

EnemyData.RaidBosses = {
	["Raid_Part1"] = { IsBoss = true, Name = "Female Titan", Req = 1, Health = 5000, GateType = "Hardening", GateHP = 2000, Strength = 60, Defense = 50, Speed = 65, Resolve = 60, TitanStats = {Power="A", Speed="A", Hardening="A", Endurance="B", Precision="B", Potential="B"}, Skills = {"Hardened Punch", "Nape Guard", "Leg Sweep"}, Drops = { Dews = 1000, XP = 2500, ItemChance = { ["Standard Titan Serum"] = 100, ["Founder's Memory Wipe"] = 5, ["Scout Regiment Cloak"] = 25, ["Scout Training Manual"] = 15 } } },
	["Raid_Part2"] = { IsBoss = true, Name = "Armored Titan", Req = 1, Health = 12000, GateType = "Reinforced Skin", GateHP = 8000, Strength = 80, Defense = 100, Speed = 30, Resolve = 70, TitanStats = {Power="B", Speed="C", Hardening="S", Endurance="A", Precision="C", Potential="C"}, Skills = {"Armored Tackle", "Hardened Punch", "Brutal Swipe"}, Drops = { Dews = 2500, XP = 5000, ItemChance = { ["Standard Titan Serum"] = 100, ["Founder's Memory Wipe"] = 6, ["Advanced ODM Gear"] = 15, ["Ultrahard Steel Blades"] = 25 } } },
	["Raid_Part3"] = { IsBoss = true, Name = "Beast Titan", Req = 1, Health = 15000, Strength = 100, Defense = 60, Speed = 40, Resolve = 85, TitanStats = {Power="S", Speed="C", Hardening="B", Endurance="A", Precision="A", Potential="A"}, Skills = {"Titan Roar", "Hardened Punch", "Brutal Swipe"}, Drops = { Dews = 5000, XP = 10000, ItemChance = { ["Standard Titan Serum"] = 100, ["Founder's Memory Wipe"] = 7, ["Spinal Fluid Syringe"] = 5, ["Marleyan Armband"] = 25 } } },
	["Raid_Part4"] = { IsBoss = true, Name = "War Hammer Titan", Req = 1, Health = 20000, GateType = "Hardening", GateHP = 15000, Strength = 150, Defense = 80, Speed = 60, Resolve = 100, TitanStats = {Power="A", Speed="B", Hardening="S", Endurance="B", Precision="A", Potential="A"}, Skills = {"War Hammer Spike", "Hardened Punch"}, Drops = { Dews = 8000, XP = 15000, ItemChance = { ["Standard Titan Serum"] = 100, ["Founder's Memory Wipe"] = 8, ["Spinal Fluid Syringe"] = 10, ["Marleyan Combat Manual"] = 25 } } },
	["Raid_Part5"] = { IsBoss = true, Name = "Founding Titan (Eren)", Req = 1, Health = 35000, GateType = "Steam", GateHP = 5, Strength = 300, Defense = 150, Speed = 20, Resolve = 250, TitanStats = {Power="S", Speed="E", Hardening="S", Endurance="S", Precision="A", Potential="S"}, Skills = {"Coordinate Command", "Colossal Steam", "Stomp"}, Drops = { Dews = 30000, XP = 50000, ItemChance = { ["Standard Titan Serum"] = 100, ["Founder's Memory Wipe"] = 15, ["Spinal Fluid Syringe"] = 25, ["Ymir's Clay Fragment"] = 5 } } },
	["Raid_Part8"] = { IsBoss = true, Name = "Colossal Titan", Req = 1, Health = 45000, GateType = "Steam", GateHP = 5, Strength = 400, Defense = 100, Speed = 10, Resolve = 150, TitanStats = {Power="S", Speed="E", Hardening="C", Endurance="S", Precision="E", Potential="S"}, Skills = {"Colossal Steam", "Stomp"}, Drops = { Dews = 15000, XP = 25000, ItemChance = { ["Standard Titan Serum"] = 100, ["Spinal Fluid Syringe"] = 10, ["Ymir's Clay Fragment"] = 2 } } }
}

EnemyData.WorldBosses = {
	["Rod Reiss Titan"] = {
		Name = "Rod Reiss (Abnormal)", Desc = "A massive, crawling monstrosity radiating intense heat. Slow, but devastatingly durable.", IsBoss = true, 
		Health = 150000, GateHP = 0, Strength = 250, Defense = 200, Speed = 10, Resolve = 500, TitanStats = {Power="S", Speed="E", Hardening="C", Endurance="S", Precision="E", Potential="E"},
		Skills = {"Colossal Steam", "Stomp"},
		Drops = { XP = 100000, Dews = 50000, ItemChance = { ["Standard Titan Serum"] = 100, ["Clan Blood Vial"] = 50, ["Spinal Fluid Syringe"] = 20 } },
		Phases = {
			{ Health = 50000, GateType = "None", GateHP = 0, Strength = 350, Defense = 50, Speed = 5, Skills = {"Colossal Steam", "Crushed Boulders"}, Flavor = "<font color='#FFAA00'><b>Rod Reiss's face has dragged completely off! The heat is intensifying!</b></font>" }
		}
	},
	["Lara Tybur"] = {
		Name = "War Hammer (Lara)", Desc = "The true wielder of the War Hammer. Master of structural hardening and lethal spikes.", IsBoss = true,
		Health = 250000, GateType = "Hardening", GateHP = 50000, Strength = 350, Defense = 250, Speed = 120, Resolve = 800, TitanStats = {Power="S", Speed="A", Hardening="S", Endurance="B", Precision="S", Potential="A"},
		Skills = {"War Hammer Spike", "Hardened Punch", "Brutal Swipe"},
		Drops = { XP = 250000, Dews = 150000, ItemChance = { ["Standard Titan Serum"] = 100, ["Clan Blood Vial"] = 75, ["Spinal Fluid Syringe"] = 40, ["Ymir's Clay Fragment"] = 10 } },
		Phases = {
			{ Health = 200000, GateType = "Hardening", GateHP = 150000, Strength = 450, Defense = 400, Speed = 0, Skills = {"War Hammer Spike", "Crushed Boulders"}, Flavor = "<font color='#55FFFF'><b>Lara Tybur encases herself in a crystal underground and manifests a new Titan body remotely!</b></font>" }
		}
	},
	["Doomsday Titan"] = {
		Name = "The Doomsday Titan", Desc = "Eren's skeletal monstrosity leading the Rumbling. Commands pure titans at will.", IsBoss = true,
		Health = 1500000, GateType = "Steam", GateHP = 10, Strength = 600, Defense = 400, Speed = 50, Resolve = 1000, TitanStats = {Power="S", Speed="E", Hardening="S", Endurance="S", Precision="S", Potential="S"},
		Skills = {"Coordinate Command", "Colossal Steam", "Stomp"},
		Drops = { XP = 600000, Dews = 350000, ItemChance = { ["Spinal Fluid Syringe"] = 100, ["Clan Blood Vial"] = 100, ["Ymir's Clay Fragment"] = 25 } }
	},
	["Ymir Fritz"] = {
		Name = "Ymir Fritz (Founder)", Desc = "The original progenitor. She molds the world in the Paths. The ultimate trial.", IsBoss = true,
		Health = 5000000, GateType = "Hardening", GateHP = 150000, Strength = 1000, Defense = 600, Speed = 200, Resolve = 5000, TitanStats = {Power="S", Speed="S", Hardening="S", Endurance="S", Precision="S", Potential="S"},
		Skills = {"Coordinate Command", "War Hammer Spike", "Colossal Steam", "Armored Tackle"},
		Drops = { XP = 1500000, Dews = 1000000, ItemChance = { ["Spinal Fluid Syringe"] = 100, ["Clan Blood Vial"] = 100, ["Ymir's Clay Fragment"] = 100 } }
	}
}

EnemyData.Parts = {
	[1] = {
		RandomFlavor = {"You wander the streets of Trost, and encounter a %s!", "A %s steps out from the ruins!"},
		Mobs = { 
			{ Name = "3-Meter Pure Titan",  Health = 40, Strength = 5, Defense = 2, Speed = 3, Resolve = 2, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "Titan Grab"}, Drops = { Dews = 5, XP = 10, ItemChance = {["Cadet Training Blade"]=1} } } 
		},
		Templates = {
			["3-Meter Pure Titan"] = { Name = "3-Meter Pure Titan", Health = 40, Strength = 5, Defense = 2, Speed = 3, Resolve = 2, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "Titan Grab"}, Drops = { Dews = 5, XP = 10, ItemChance = {["Cadet Training Blade"]=1} } },
			["7-Meter Pure Titan"] = { Name = "7-Meter Pure Titan", Health = 80, Strength = 8, Defense = 4, Speed = 5, Resolve = 3, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "Titan Bite"}, Drops = { Dews = 8, XP = 20, ItemChance = {["Cadet Training Blade"]=2} } },
			["Crawler Titan"] = { Name = "Crawler Titan", Health = 50, Strength = 6, Defense = 2, Speed = 8, Resolve = 2, TitanStats = emptyTitans, Skills = {"Titan Bite", "Brutal Swipe"}, Drops = { Dews = 5, XP = 10, ItemChance = {["Cadet Training Blade"]=1} } },
			["Abnormal"] = { Name = "Abnormal Titan", Health = 120, Strength = 12, Defense = 5, Speed = 12, Resolve = 5, TitanStats = emptyTitans, Skills = {"Frenzied Thrash", "Brutal Swipe", "Stomp"}, Drops = { Dews = 20, XP = 40, ItemChance = {["Scout Training Manual"]=1} } },
			["15-Meter Pure Titan"] = { Name = "15-Meter Pure Titan", Health = 250, Strength = 25, Defense = 10, Speed = 8, Resolve = 15, TitanStats = emptyTitans, Skills = {"Stomp", "Brutal Swipe"}, Drops = { Dews = 50, XP = 100, ItemChance = {["Scout Training Manual"]=2} } },
			["Part1Boss"] = { IsBoss = true, Name = "Vanguard Abnormal (Boss)", Health = 400, Strength = 35, Defense = 15, Speed = 20, Resolve = 30, TitanStats = emptyTitans, Skills = {"Frenzied Thrash", "Stomp", "Titan Grab"}, Drops = { Dews = 150, XP = 400, ItemChance={["Cadet Training Blade"]=25, ["Scout Training Manual"]=5} } }
		},
		Missions = {
			[1] = { Name = "The Fall of Shiganshina", Waves = { 
				{ Template = "3-Meter Pure Titan", Flavor = "Wall Maria has been breached! Fight your way to the boats." }, 
				{ Template = "3-Meter Pure Titan", Flavor = "More pure titans are swarming the streets." }, 
				{ Template = "7-Meter Pure Titan", Flavor = "A larger titan spots you. Don't die here!" }, 
				{ Template = "7-Meter Pure Titan", Flavor = "They just keep coming!" }, 
				{ Template = "Crawler Titan", Flavor = "Years later in Trost... A crawler is trying to ambush the vanguard!" }, 
				{ Template = "Crawler Titan", Flavor = "Another crawler! Watch your step!" }, 
				{ Template = "Abnormal", Flavor = "An abnormal is ignoring the civilians and charging you!" }, 
				{ Template = "15-Meter Pure Titan", Flavor = "A massive 15-meter class approaches. Take it down!" }, 
				{ Template = "Part1Boss", Flavor = "<font color='#FF5555'>WARNING: A massive Abnormal is leading the horde. Give your hearts!</font>" } 
			} }
		}
	},

	[2] = {
		RandomFlavor = {"You face a Wooden Titan Dummy on the training grounds!"},
		Mobs = { 
			{ Name = "Wooden Titan Dummy", Health = 60, Strength = 2, Defense = 5, Speed = 2, Resolve = 5, TitanStats = emptyTitans, Skills = {"Brutal Swipe"}, Drops = { Dews = 10, XP = 20, ItemChance = {["Cadet Training Blade"]=2} } } 
		},
		Templates = {
			["Wooden Titan Dummy"] = { Name = "Wooden Titan Dummy", Health = 60, Strength = 2, Defense = 5, Speed = 2, Resolve = 5, TitanStats = emptyTitans, Skills = {"Brutal Swipe"}, Drops = { Dews = 10, XP = 20, ItemChance = {["Cadet Training Blade"]=2} } },
			["Balance Minigame"] = { IsMinigame = "Balance", Name = "ODM Balance Training", Health = 1, GateHP = 0, Strength = 0, Defense = 0, Speed = 0, Resolve = 0, TitanStats = emptyTitans, Skills = {}, Drops = { Dews = 150, XP = 300, ItemChance = {} } },
			["Armored Titan Dummy"] = { Name = "Armored Titan Dummy", Health = 100, GateType = "Reinforced Skin", GateHP = 50, Strength = 5, Defense = 10, Speed = 3, Resolve = 10, TitanStats = emptyTitans, Skills = {"Block"}, Drops = { Dews = 15, XP = 30, ItemChance = {["Scout Training Manual"]=1} } },
			["Part2Boss"] = { IsBoss = true, IsHuman = true, Name = "Instructor Shadis", Health = 500, Strength = 25, Defense = 15, Speed = 30, Resolve = 50, TitanStats = emptyTitans, Skills = {"Heavy Slash", "Evasive Maneuver"}, Drops = { Dews = 150, XP = 500, ItemChance = { ["Scout Training Manual"] = 10, ["Cadet Training Blade"] = 25 } } },

			-- [[ THE FIX: Added Regiment Choice pseudo-enemy to serve as the final wave ]]
			["Regiment Selection"] = { IsMinigame = "RegimentChoice", Name = "Graduation Ceremony", Health = 1, GateHP = 0, Strength = 0, Defense = 0, Speed = 0, Resolve = 0, TitanStats = emptyTitans, Skills = {}, Drops = { Dews = 0, XP = 0, ItemChance = {} } }
		},
		Missions = {
			[1] = { Name = "104th Cadet Corps Training", Waves = { 
				{ Template = "Wooden Titan Dummy", Flavor = "Welcome to the 104th! Prove your worth on the dummies." }, 
				{ Template = "Balance Minigame", Flavor = "ODM Gear Balance Test: Keep the indicator in the white zone by holding/releasing the button!" }, 
				{ Template = "Armored Titan Dummy", Flavor = "They've reinforced the nape on this one. Strike hard!" }, 
				{ Template = "Armored Titan Dummy", Flavor = "Another armored dummy. Practice your spacing!" }, 
				{ Template = "Part2Boss", Flavor = "<font color='#FF5555'>WARNING: Instructor Shadis wants to test your mettle personally! Don't hold back!</font>" },
				-- [[ THE FIX: Regiment Selection is now natively part of the combat queue! ]]
				{ Template = "Regiment Selection", Flavor = "You have survived training. It is time to pledge your heart to a Regiment." }
			} }
		}
	},

	[3] = {
		RandomFlavor = {"You encounter a %s in the open fields!", "A %s jumps out from the giant trees!"},
		Mobs = { { Name = "Field Titan", Health = 100, Strength = 12, Defense = 8, Speed = 15, Resolve = 8, TitanStats = emptyTitans, Skills = {"Titan Grab", "Brutal Swipe", "Titan Bite"}, Drops = { Dews = 15, XP = 40, ItemChance = {["Scout Regiment Cloak"]=1} } } },
		Templates = {
			["Field Titan"] = { Name = "Field Titan", Health = 100, Strength = 12, Defense = 8, Speed = 15, Resolve = 8, TitanStats = emptyTitans, Skills = {"Titan Grab", "Brutal Swipe"}, Drops = { Dews = 15, XP = 40, ItemChance = {["Scout Regiment Cloak"]=1} } },
			["Tree Glider Abnormal"] = { Name = "Tree Glider Abnormal", Health = 150, Strength = 16, Defense = 10, Speed = 25, Resolve = 12, TitanStats = emptyTitans, Skills = {"Stomp", "Frenzied Thrash"}, Drops = { Dews = 25, XP = 60, ItemChance = {["Scout Regiment Cloak"]=2} } },
			["Female Titan (Forest)"] = { Name = "Female Titan (Pursuit)", Health = 1500, GateType = "Hardening", GateHP = 500, Strength = 45, Defense = 30, Speed = 50, Resolve = 40, TitanStats = {Power="A", Speed="A", Hardening="A", Endurance="B", Precision="B", Potential="B"}, Skills = {"Hardened Punch", "Brutal Swipe"}, Drops = { Dews = 200, XP = 500, ItemChance = {["Standard Titan Serum"]=2} } },
			["Part3Boss"] = { 
				IsBoss = true, Name = "Female Titan (Annie)", Health = 2000, GateType = "Hardening", GateHP = 1500, Strength = 55, Defense = 45, Speed = 60, Resolve = 50, TitanStats = {Power="A", Speed="A", Hardening="A", Endurance="B", Precision="B", Potential="B"}, 
				Skills = {"Hardened Punch", "Block"}, Drops = { Dews = 800, XP = 2000, ItemChance = { ["Ultrahard Steel Blades"] = 20, ["Standard Titan Serum"]=10 } },
				Phases = {
					{ Health = 1500, GateType = "None", GateHP = 0, Strength = 75, Defense = 30, Speed = 90, Skills = {"Frenzied Thrash", "Brutal Swipe", "Evasive Maneuver"}, Flavor = "<font color='#FF5555'><b>Annie abandons her hardening to prioritize sheer speed! She's getting desperate!</b></font>" }
				} 
			}
		},
		Missions = {
			[1] = { Name = "Clash of the Titans", Waves = { 
				{ Template = "Field Titan", Flavor = "You are on the right flank. Keep the titans away from the center!" }, 
				{ Template = "Tree Glider Abnormal", Flavor = "An abnormal is ignoring the flares! Intercept it!" }, 
				{ Template = "Female Titan (Forest)", Flavor = "<font color='#FF5555'>A highly intelligent Titan has wiped out the right flank. SURVIVE!</font>" }, 
				{ Template = "Part3Boss", Flavor = "<font color='#FF5555'>WARNING: The trap failed! Annie has transformed in Stohess. Bring her down!</font>" } 
			} }
		}
	},

	[4] = {
		RandomFlavor = {"An %s attacks you in the Crystal Caverns!"},
		Mobs = { { IsHuman = true, Name = "Anti-Personnel MP", Health = 200, Strength = 25, Defense = 15, Speed = 30, Resolve = 18, TitanStats = emptyTitans, Skills = {"Anti-Titan Round"}, Drops = { Dews = 300, XP = 150, ItemChance = {["Anti-Personnel Pistols"]=1} } } },
		Templates = {
			["Interior MP"] = { IsHuman = true, Name = "Interior MP Grunt", Health = 220, Strength = 28, Defense = 16, Speed = 25, Resolve = 20, TitanStats = emptyTitans, Skills = {"Heavy Slash", "Regroup"}, Drops = { Dews = 250, XP = 180, ItemChance = {["Anti-Personnel Pistols"]=1} } },
			["Anti-Personnel MP"] = { IsHuman = true, Name = "Anti-Personnel MP", Health = 200, Strength = 25, Defense = 15, Speed = 30, Resolve = 18, TitanStats = emptyTitans, Skills = {"Anti-Titan Round", "Evasive Maneuver"}, Drops = { Dews = 300, XP = 150, ItemChance = {["Anti-Personnel Pistols"]=2} } },
			["Part4Boss"] = { 
				IsHuman = true, IsBoss = true, Name = "Kenny's Lieutenant", Health = 1000, Strength = 60, Defense = 35, Speed = 50, Resolve = 45, TitanStats = emptyTitans, 
				Skills = {"Anti-Titan Round", "Smoke Screen"}, Drops = { Dews = 4000, XP = 2500, ItemChance = { ["Anti-Personnel Pistols"] = 25, ["Commander's Bolo Tie"] = 5 } },
				Phases = {
					{ Health = 800, GateType = "None", GateHP = 0, Strength = 85, Defense = 20, Speed = 80, Skills = {"Heavy Slash", "Evasive Maneuver"}, Flavor = "<font color='#FFAA00'><b>The Lieutenant runs out of ammo and draws her blades!</b></font>" }
				}
			}
		},
		Missions = {
			[1] = { Name = "The Uprising", Waves = { 
				{ Template = "Interior MP", Flavor = "The Military Police are targeting the Scouts in Stohess!" }, 
				{ Template = "Anti-Personnel MP", Flavor = "You've entered the Crystal Caverns. They have guns instead of blades! Take cover!" }, 
				{ Template = "Part4Boss", Flavor = "<font color='#FF5555'>WARNING: Kenny's Lieutenant blocks the path to Eren!</font>" } 
			} }
		}
	},

	[5] = {
		RandomFlavor = {"You sneak through the streets of Liberio!", "Marleyan guards spot you!"},
		Mobs = { { IsHuman = true, Name = "Marleyan Guard", Health = 300, Strength = 35, Defense = 20, Speed = 30, Resolve = 30, TitanStats = emptyTitans, Skills = {"Heavy Slash", "Block"}, Drops = { Dews = 400, XP = 200, ItemChance = {["Anti-Personnel Pistols"]=1} } } },
		Templates = {
			["Marleyan Guard"] = { IsHuman = true, Name = "Marleyan Guard", Health = 300, Strength = 35, Defense = 20, Speed = 30, Resolve = 30, TitanStats = emptyTitans, Skills = {"Heavy Slash", "Block"}, Drops = { Dews = 400, XP = 200, ItemChance = {["Anti-Personnel Pistols"]=1} } },
			["Marleyan Elite"] = { IsHuman = true, Name = "Marleyan Elite", Health = 450, Strength = 50, Defense = 30, Speed = 45, Resolve = 40, TitanStats = emptyTitans, Skills = {"Anti-Titan Round", "Evasive Maneuver"}, Drops = { Dews = 600, XP = 300, ItemChance = {["Anti-Personnel Pistols"]=2, ["Advanced ODM Gear"]=1} } },
			["Part5Boss"] = { 
				IsBoss = true, Name = "War Hammer Titan", Health = 2000, GateType = "Hardening", GateHP = 1500, Strength = 150, Defense = 80, Speed = 60, Resolve = 100, TitanStats = {Power="A", Speed="B", Hardening="S", Endurance="B", Precision="A", Potential="A"}, 
				Skills = {"War Hammer Spike", "Hardened Punch"}, Drops = { Dews = 8000, XP = 4000, ItemChance = { ["Spinal Fluid Syringe"] = 5, ["Marleyan Combat Manual"] = 15 } },
				Phases = {
					{ Health = 1000, GateType = "None", GateHP = 0, Strength = 200, Defense = 50, Speed = 80, Skills = {"War Hammer Spike", "Crushed Boulders"}, Flavor = "<font color='#FFAA00'><b>The War Hammer sheds its armor for a final desperate assault!</b></font>" }
				}
			}
		},
		Missions = {
			[1] = { Name = "Marleyan Assault", Waves = { 
				{ Template = "Marleyan Guard", Flavor = "Infiltrate Liberio. Take out the guards quietly." }, 
				{ Template = "Marleyan Elite", Flavor = "They've spotted you! Elite forces inbound!" }, 
				{ Template = "Part5Boss", Flavor = "<font color='#FF5555'>WARNING: The War Hammer Titan has appeared!</font>" } 
			} }
		}
	},

	[6] = {
		RandomFlavor = {"You are ambushed in the ruins of Shiganshina!"},
		Mobs = { { Name = "Zeke's Controlled Titan", Health = 450, Strength = 50, Defense = 20, Speed = 40, Resolve = 20, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "Stomp"}, Drops = { Dews = 900, XP = 300, ItemChance = {["Standard Titan Serum"]=1} } } },
		Templates = {
			["Zeke's Controlled Titan"] = { Name = "Zeke's Controlled Titan", Health = 450, Strength = 50, Defense = 20, Speed = 40, Resolve = 20, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "Stomp"}, Drops = { Dews = 900, XP = 300, ItemChance = {["Standard Titan Serum"]=1} } }, 
			["Beast Titan Pitcher"] = { Name = "Beast Titan (Rock Throw)", Health = 800, Strength = 150, Defense = 60, Speed = 30, Resolve = 80, TitanStats = emptyTitans, IsLongRange = true, Skills = {"Crushed Boulders", "Block"}, Drops = { Dews = 1200, XP = 600, ItemChance = {["Thunder Spear"]=1} } },
			["Part6Boss"] = { 
				IsBoss = true, Name = "Armored Titan (Reiner)", Health = 2500, GateType = "Reinforced Skin", GateHP = 2500, Strength = 120, Defense = 150, Speed = 45, Resolve = 90, TitanStats = {Power="B", Speed="C", Hardening="S", Endurance="A", Precision="C", Potential="C"}, 
				Skills = {"Armored Tackle", "Hardened Punch", "Brutal Swipe"}, Drops = { Dews = 15000, XP = 5000, ItemChance = { ["Spinal Fluid Syringe"] = 2, ["Thunder Spear"] = 5 } },
				Phases = {
					{ Health = 3000, GateType = "None", GateHP = 0, Strength = 180, Defense = 70, Speed = 90, Skills = {"Frenzied Thrash", "Stomp"}, Flavor = "<font color='#FF5555'><b>Reiner sheds the armor from the back of his legs! His speed has doubled!</b></font>" }
				}
			}
		},
		Missions = {
			[1] = { Name = "Return to Shiganshina", Waves = { 
				{ Template = "Zeke's Controlled Titan", Flavor = "The Beast Titan has trapped the Scouts in Shiganshina!" }, 
				{ Template = "Beast Titan Pitcher", Flavor = "A barrage of crushed boulders obliterates the front lines!" }, 
				{ Template = "Part6Boss", Flavor = "<font color='#FF5555'>WARNING: The Armored Titan is charging the gates!</font>" } 
			} }
		}
	},

	[7] = {
		RandomFlavor = {"Marleyan forces are dropping from the sky!"},
		Mobs = { { IsHuman = true, Name = "Marleyan Paratrooper", Health = 600, Strength = 70, Defense = 40, Speed = 60, Resolve = 50, TitanStats = emptyTitans, Skills = {"Heavy Slash", "Evasive Maneuver"}, Drops = { Dews = 1500, XP = 500, ItemChance = {["Advanced ODM Gear"]=1} } } },
		Templates = {
			["Marleyan Paratrooper"] = { IsHuman = true, Name = "Marleyan Paratrooper", Health = 600, Strength = 70, Defense = 40, Speed = 60, Resolve = 50, TitanStats = emptyTitans, Skills = {"Heavy Slash", "Evasive Maneuver"}, Drops = { Dews = 1500, XP = 500, ItemChance = {["Advanced ODM Gear"]=1} } },
			["Anti-Titan Artillery"] = { IsHuman = true, Name = "Anti-Titan Artillery", Health = 500, Strength = 200, Defense = 100, Speed = 10, Resolve = 100, TitanStats = emptyTitans, Skills = {"Anti-Titan Round", "Block"}, Drops = { Dews = 2500, XP = 800, ItemChance = {["Ultrahard Steel Blades"]=1} } },
			["Part7Boss"] = { 
				IsBoss = true, Name = "Jaw Titan (Porco)", Health = 4000, GateType = "Hardening", GateHP = 1500, Strength = 160, Defense = 80, Speed = 150, Resolve = 100, TitanStats = {Power="A", Speed="S", Hardening="B", Endurance="C", Precision="A", Potential="B"}, 
				Skills = {"Frenzied Thrash", "Titan Bite"}, Drops = { Dews = 25000, XP = 8000, ItemChance = { ["Standard Titan Serum"] = 20, ["Advanced ODM Gear"] = 10 } },
				Phases = {
					{ Health = 2000, GateType = "Hardening", GateHP = 500, Strength = 220, Defense = 60, Speed = 200, Skills = {"Titan Bite", "Evasive Maneuver"}, Flavor = "<font color='#FF5555'><b>Porco goes into a blind rage! His speed is unfathomable!</b></font>" }
				}
			}
		},
		Missions = {
			[1] = { Name = "War for Paradis", Waves = { 
				{ Template = "Marleyan Paratrooper", Flavor = "Marleyan forces invade Paradis Island! They are dropping from airships!" }, 
				{ Template = "Anti-Titan Artillery", Flavor = "They've mounted cannons on the walls! Take them out!" }, 
				{ Template = "Part7Boss", Flavor = "<font color='#FF5555'>WARNING: The Jaw Titan is tearing through the ranks!</font>" } 
			} }
		}
	},

	[8] = {
		RandomFlavor = {"The ground shakes violently. The Rumbling has begun!"},
		Mobs = { { Name = "Wall Titan", Health = 1500, Strength = 250, Defense = 80, Speed = 20, Resolve = 100, TitanStats = emptyTitans, Skills = {"Colossal Steam", "Stomp", "Brutal Swipe"}, Drops = { Dews = 3000, XP = 1200, ItemChance = {["Spinal Fluid Syringe"]=1} } } },
		Templates = {
			["Wall Titan"] = { Name = "Wall Titan", Health = 1500, GateType = "Steam", GateHP = 2, Strength = 250, Defense = 80, Speed = 20, Resolve = 100, TitanStats = emptyTitans, Skills = {"Colossal Steam", "Stomp"}, Drops = { Dews = 3000, XP = 1200, ItemChance = {["Spinal Fluid Syringe"]=1} } },
			["Ancient Shifter"] = { Name = "Ancient Nine Titan Husk", Health = 2000, Strength = 200, Defense = 120, Speed = 100, Resolve = 150, TitanStats = emptyTitans, Skills = {"Armored Tackle", "War Hammer Spike", "Titan Bite"}, Drops = { Dews = 1500, XP = 2000, ItemChance = {["Standard Titan Serum"]=2, ["Ymir's Clay Fragment"]=1} } },
			["Part8Boss"] = { 
				IsBoss = true, Name = "Founding Titan", Health = 8000, GateType = "Steam", GateHP = 3, Strength = 300, Defense = 200, Speed = 15, Resolve = 200, TitanStats = {Power="S", Speed="E", Hardening="S", Endurance="S", Precision="S", Potential="S"}, 
				Skills = {"Coordinate Command", "Colossal Steam", "War Hammer Spike"}, Drops = { Dews = 40000, XP = 35000, ItemChance = { ["Ymir's Clay Fragment"] = 2, ["Spinal Fluid Syringe"] = 5 } },
				Phases = {
					{ Health = 4000, GateType = "Hardening", GateHP = 4000, Strength = 400, Defense = 300, Speed = 40, Skills = {"Coordinate Command", "War Hammer Spike"}, Flavor = "<font color='#FFD700'><b>Ymir interferes! The Founding Titan is covered in crystal hardening!</b></font>" }
				}
			}
		},
		Missions = {
			[1] = { Name = "The Rumbling", Waves = { 
				{ Template = "Wall Titan", Flavor = "Millions of Colossal Titans march forward." }, 
				{ Template = "Ancient Shifter", Flavor = "Ymir is summoning Titans from past generations on the Founding Titan's back!" }, 
				{ Template = "Part8Boss", Flavor = "<font color='#FF5555'>WARNING: You have reached the nape. This is the end.</font>" } 
			} }
		}
	}
}

EnemyData.PathsMemories = {
	{ Name = "Memory of the Smiling Titan", Health = 3000, Strength = 120, Defense = 50, Speed = 45, Resolve = 200, TitanStats = emptyTitans, Skills = {"Titan Grab", "Brutal Swipe"}, Drops = {XP=1000, Dews=500} },
	{ Name = "Memory of the Female Titan", Health = 8000, GateType="Hardening", GateHP=3000, Strength = 200, Defense = 100, Speed = 100, Resolve = 300, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "Block"}, Drops = {XP=3000, Dews=1500} },
	{ Name = "Memory of the Armored Titan", Health = 12000, GateType="Reinforced Skin", GateHP=6000, Strength = 150, Defense = 200, Speed = 50, Resolve = 400, TitanStats = emptyTitans, Skills = {"Armored Tackle", "Brutal Swipe"}, Drops = {XP=4000, Dews=2000} },
	{ Name = "Memory of the Beast Titan", Health = 10000, Strength = 300, Defense = 80, Speed = 70, Resolve = 350, TitanStats = emptyTitans, IsLongRange = true, Skills = {"Crushed Boulders", "Block"}, Drops = {XP=5000, Dews=2500} },
	{ Name = "Memory of the War Hammer", Health = 15000, GateType="Hardening", GateHP=8000, Strength = 350, Defense = 150, Speed = 90, Resolve = 500, TitanStats = emptyTitans, Skills = {"Brutal Swipe", "War Hammer Spike"}, Drops = {XP=6000, Dews=3000} },
	{ Name = "Memory of the Colossal", Health = 25000, GateType="Steam", GateHP=6, Strength = 600, Defense = 100, Speed = 10, Resolve = 800, TitanStats = emptyTitans, Skills = {"Colossal Steam", "Stomp"}, Drops = {XP=8000, Dews=4000} }
}

return EnemyData