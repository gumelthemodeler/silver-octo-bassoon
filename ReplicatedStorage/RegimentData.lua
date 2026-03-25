-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RegimentData = {}

RegimentData.Regiments = {
	["Cadet Corps"] = {
		Icon = "rbxassetid://132795247",
		Description = "New recruits in training. Gaining basic experience.",
		Buff = "No specific buff."
	},
	["Garrison"] = {
		Icon = "rbxassetid://133062844",
		Description = "Protectors of the Walls. Increased defense in missions.",
		Buff = "+10% Defense"
	},
	["Military Police"] = {
		Icon = "rbxassetid://132793466",
		Description = "The inner guard. Increased Dews from all sources.",
		Buff = "+15% Dews"
	},
	["Scout Regiment"] = {
		Icon = "rbxassetid://132793532",
		Description = "The humanity's vanguard. Faster speed in combat.",
		Buff = "+10% Speed"
	}
}

return RegimentData