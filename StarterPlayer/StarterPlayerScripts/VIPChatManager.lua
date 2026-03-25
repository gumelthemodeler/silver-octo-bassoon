-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")

	if message.TextSource then
		local player = Players:GetPlayerByUserId(message.TextSource.UserId)
		if player and player:GetAttribute("HasVIP") then
			-- Adds the Golden VIP Tag and colors their name
			properties.PrefixText = "<font color='#FFD700'><b>[VIP]</b></font> <font color='#FFD700'>" .. (message.PrefixText or player.Name) .. "</font>"
		end
	end

	return properties
end