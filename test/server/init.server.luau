local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players:GetPlayers()[1]

if not Player then
    repeat
        Player = Players:GetPlayers()[1]
        task.wait()
    until Player
end

local PartySync = require(ReplicatedStorage.Packages.PartySync)

local Sync = PartySync.new({
    Name = "Test",
    Type = "Persistent",
    MaxSize = 5,
    BatchOverrides = {
        Size = 10,
        Delay = 10,
    }
})

local Party = Sync:Get(Player)

Party:SetMaxSize(10)

Party.PlayerAdded:Connect(function(UserId: number)
    print(`{UserId} has joined the party!`, Party._Members)
end)

Party.PlayerRemoved:Connect(function(UserId: number) 
	print(`{UserId} has left the party!`, Party._Members)
end)

Party.Destroying:Connect(function()
    print("Party is being destroyed!")
end)

Party.Updated:Connect(function(Index, Value)
    print(`Party {Index} has been updated to {Value}!`)
end)

--task.delay(10, Party.Remove, Party, Player)