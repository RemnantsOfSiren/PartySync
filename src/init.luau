--!strict
local PlayerService = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local TestSuccess = pcall(function()
	local TestStore = MemoryStoreService:GetSortedMap("-")
	TestStore:SetAsync("1", "Hello", 1)
end)

if not TestSuccess then
	error("MemoryStoreService is not enabled.")
	return
end

local Flags = require(script.Flags)
local Types = require(script.Types)
local Processor = require(script.Processor)

local Party = require(script.Party)

local PartySyncDS = DataStoreService:GetDataStore("PartySync", "PlayerLookup")
local CheckBudgetRequest = require(script.CheckBudgetRequest)

local IdFlag = Flags.IdFlag
local ReadyFlag = Flags.ReadyFlag

local Syncs = {}

local PartySync = {}
PartySync.__index = PartySync

export type PartySync = typeof(setmetatable(
	{} :: {
		_Name: string,
		_Type: string,
		_Processor: Processor.Processor?,
		_MemoryStore: MemoryStoreSortedMap?,
		_PartiesInServer: { [string]: Party.Party },
	},
	PartySync
))

--[=[
    @class PartySync
    Object (PartySync) for creating parties.
]=]

local function AttemptToResetExpireTime(MemoryStore: MemoryStoreSortedMap, Key: string)
	local Success

	repeat
		Success = pcall(MemoryStore.UpdateAsync, MemoryStore, Key, function(Data)
			if not Data then
				return
			end

			Data.metadata.LastActive = os.time()
			return Data
		end, 2592000)
		task.wait(1)
	until Success
end

local function AttemptToRemoveParty(MemoryStore: MemoryStoreSortedMap, Key: string)
	local Success

	repeat
		Success = pcall(MemoryStore.RemoveAsync, MemoryStore, Key)
		task.wait(1)
	until Success
end

local function AttemptToLoadParty(MemoryStore: MemoryStoreSortedMap, Key: string)
	local Success, _Party

	repeat
		Success, _Party = pcall(MemoryStore.GetAsync, MemoryStore, Key)
		task.wait(1)
	until Success

	return _Party
end

--[=[
    @function new
    @within PartySync
    @param Config { Name: string, Type: string, MaxSize: number?, BatchOverrides: { Size: number?, Delay: number? }?, }
    @return PartySync

    Creates a new PartySync object.
    - `Name` (string): The name of the PartySync,
    - `Type` (string): The type of the PartySync, Options are "Persistent" and "Temporary".
    - `MaxSize` (number): The maximum size of the Party. Defaults to 5.
    - `BatchOverrides` (table, optional): The batch overrides for the Processor.
        - `Size` (number, optional): The number of requests to process at once. Defaults to 20
        - `Delay` (number, optional): The delay between each batch. Defaults to 30
]=]

function PartySync.new(Config: Types.Config): PartySync
	if not Config.MaxSize then
		Config.MaxSize = 5
	end

	local self = setmetatable({
		_Name = Config.Name,
		_Type = Config.Type,
		_PartiesInServer = {} :: { [string]: Party.Party },
	}, PartySync)

	if self._Type == "Persistent" then
		self._MemoryStore = MemoryStoreService:GetSortedMap(Config.Name)
	end

	local function Callback(Process: Types.Process)
		local _Party = self._PartiesInServer[Process.Key]

		if not _Party then
			return false
		end

		if Process.Event == "SetMax" then
			if self._Type == "Persistent" then
				local Success = pcall(self._MemoryStore.UpdateAsync, self._MemoryStore, Process.Key, function(Data)
					if not Data then
						return
					end

					Data.metadata.MaxSize = Process.Value
					return Data
				end, 2592000)

				if not Success then
					return false
				else
					_Party.Updated:Fire("MaxSize", Process.Value)
				end
			end

			_Party._MaxSize = Process.Value
			return true
		end

		local Success = self._Type == "Temporary"

		if self._Type == "Persistent" then
			if not CheckBudgetRequest("Get") or not CheckBudgetRequest("Set") then
				while not CheckBudgetRequest("Get") and not CheckBudgetRequest("Set") do
					task.wait()
				end
			end

			local AddedToPlayerDS = pcall(
				if Process.Event == "Add" then PartySyncDS.UpdateAsync else PartySyncDS.RemoveAsync,
				PartySyncDS,
				`Player_{Process.Value}`,
				if Process.Event == "Add"
					then function()
						return `{self._Name}::{Process.Key}`
					end
					else nil
			)

			if AddedToPlayerDS then
				local PartyInfoOrError
				Success, PartyInfoOrError = pcall(
					self._MemoryStore.UpdateAsync,
					self._MemoryStore,
					Process.Key,
					function(Data)
						if not Data then
							Data = {
								_Members = {},
								metadata = _Party._metadata,
							}
						end

						if Process.Event == "Add" then
							table.insert(Data._Members, Process.Value)
						else
							table.remove(Data._Members, table.find(Data._Members, Process.Value))
						end

						return Data
					end,
					2592000
				)

				if not Success then
					warn(PartyInfoOrError)
				end
			end
		end

		if Success then
			local IsInParty = table.find(_Party._Members, Process.Value)

			if Process.Event == "Add" and not IsInParty then
				table.insert(_Party._Members, Process.Value)
				_Party.PlayerAdded:Fire(Process.Value)
			elseif Process.Event == "Remove" and IsInParty then
				table.remove(_Party._Members, IsInParty)
				_Party.PlayerRemoved:Fire(Process.Value)
			end

			if #_Party._Members == 0 then
				if self._Type == "Persistent" then
					task.spawn(AttemptToRemoveParty, self._MemoryStore, Process.Key)
				end

				_Party:Destroy()
			end
		end

		return Success
	end

	self._Processor = Processor.new(Callback, Config.BatchOverrides)

	Syncs[self._Name] = self

	return self
end

--[=[
    @method Get
    @within PartySync
    @param Player Player
    @return Party

    Creates a new Party object for the Player, if they are not already in a Party, other-wise returns the existing Party object.
]=]
function PartySync:Get(Player: Player): Party.Party
	if not Player:GetAttribute(ReadyFlag) then
		while not Player:GetAttribute(ReadyFlag) do
            task.wait()
        end
	end

	if Player:GetAttribute(IdFlag) then
		local _Party = self._PartiesInServer[Player:GetAttribute(IdFlag)]
		if not _Party then
			return warn("@PartySync - Player's party is part of a different PartySync.")
		end
		return _Party
	end

	local _Party = Party.new({
		Player = Player,
		MaxSize = self.MaxSize,
		Processor = self._Processor,
	})
	self._PartiesInServer[_Party._Id] = _Party
	return _Party
end

do
	local function OnPlayerAdded(Player: Player)
		if not CheckBudgetRequest("Get") then
			while not CheckBudgetRequest("Get") do
				task.wait()
			end
		end

		local Success, PartyOrError = pcall(PartySyncDS.GetAsync, PartySyncDS, `Player_{Player.UserId}`)

		if not Success then
			return
		end

		if not PartyOrError then
			Player:SetAttribute(ReadyFlag, true)
			return
		end

		local ExpectedParty = PartyOrError:sub(1, PartyOrError:find("::") - 1)

		if not Syncs[ExpectedParty] then
			return
		end

		ExpectedParty = Syncs[ExpectedParty]

		if ExpectedParty._Type ~= "Persistent" then -- this case should never happen, due to the ID never being added to the PlayerLookup if it's not a Persistent PartySync
			return
		end

		local Id = PartyOrError:sub(PartyOrError:find("::") + 2)

		local PartyInfo = AttemptToLoadParty(ExpectedParty._MemoryStore, Id)

		if PartyInfo then
			ExpectedParty._PartiesInServer[Id] = Party.new({
				Player = Player,
				Override = Id,
				Processor = ExpectedParty._Processor,
				metadata = PartyInfo.metadata,
			})

            Player:SetAttribute(IdFlag, Id)
            task.spawn(AttemptToResetExpireTime, ExpectedParty._MemoryStore, Id)
		else
            if not CheckBudgetRequest("Set") then
                while not CheckBudgetRequest("Set") do
                    task.wait()
                end
            end
            
            local SucessfullyRemoved = pcall(PartySyncDS.RemoveAsync, PartySyncDS, `Player_{Player.UserId}`)
            
            if  SucessfullyRemoved then
                warn(`@PartySync: {Player.Name} was removed from PlayerLookup. Party was inactive for 30 days.`)
            end
        end

		Player:SetAttribute(ReadyFlag, true)

	end

	for _, Player in PlayerService:GetPlayers() do
		task.spawn(OnPlayerAdded, Player)
	end

	PlayerService.PlayerAdded:Connect(OnPlayerAdded)
end

return PartySync
