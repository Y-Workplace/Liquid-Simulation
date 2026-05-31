local Players = game:GetService("Players")

-- UserIds autorizados (TESTERS)
local TESTERS = {
	[989905375] = true, -- Dev
	[4412142376] = true,
}

-- Mensagem padrão
local KICK_MESSAGE = "Access restricted to testers."

Players.PlayerAdded:Connect(function(player)
	if not TESTERS[player.UserId] then
		player:Kick(KICK_MESSAGE)
	end
end)
