--!strict
local HttpService = game:GetService("HttpService")

local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Parent.Signal)
local Promise = require(script.Parent.Parent.Promise)

local Flags = require(script.Parent.Flags)

local Party = {}
Party.__index = Party

--[=[
    @class Party
    Party object for managing parties.
]=]
export type Party = typeof(setmetatable(
	{} :: {
		_metadata: { [string]: any },
		_Id: string,
		_MaxSize: number?,
		_Members: { number },
		_Processor: {
			Add: (self: any, Event: Types.Process) -> (),
		},

		Updated: typeof(Signal.new()),
		Destroying: typeof(Signal.new()),
		PlayerAdded: typeof(Signal.new()),
		PlayerRemoved: typeof(Signal.new()),
	},
	Party
))

--[=[
    @prop Updated Signal
    @within Party
    Signal that fires when the party is being Updated.
]=]

--[=[
    @prop PlayerAdded Signal
    @within Party
    Signal that fires when a player is added to the party.
]=]

--[=[
    @prop PlayerRemoved Signal
    @within Party
    Signal that fires when a player is removed from the party.
]=]

--[=[
    @prop Destroying Signal
    @within Party
    Signal that fires when the party is being destroyed.
]=]
function Party.new(Config: {
	Player: Player,
	MaxSize: number?,
	Override: string?,
	Processor: { Add: (self: any, Event: Types.Process) -> () },
	metadata: { [string]: any }?,
}): Party
	local self = setmetatable({
		_metadata = Config.metadata or {
			Owner = Config.Player.UserId,
			MaxSize = Config.MaxSize,
			Created = os.time(),
			LastActive = os.time(),
		},
		_Id = Config.Override or HttpService:GenerateGUID(false),
		_Members = {},
		_MaxSize = Config.MaxSize,
		_Processor = Config.Processor,
		Updated = Signal.new(),
		Destroying = Signal.new(),
		PlayerAdded = Signal.new(),
		PlayerRemoved = Signal.new(),
	}, Party)

	if not Config.Override then
		self:Add(Config.Player)
	else
		table.insert(self._Members, Config.Player.UserId)
	end

	return self
end

--[=[
    @within Party
    @function Add
    @param Player Player
    @return Promise
    Adds a player to the party.
    - `Player` (Player): The player to add to the party.
    - Returns a Promise.
]=]
function Party:Add(Player: Player)
    if not Player:GetAttribute(Flags.ReadyFlag) then
        while not Player:GetAttribute(Flags.ReadyFlag) do
            task.wait()
        end
    end

	if #self._Members > self._metadata.MaxSize then
		return Promise.reject("Party is already at max size.")
    elseif table.find(self._Members, Player.UserId) then
        return Promise.reject("Player is already in the party.")
    elseif Player:GetAttribute(Flags.IdFlag) then
        return Promise.reject("Player is already in a party.")
    end

	return Promise.resolve(self._Processor:Add({
		Key = self._Id,
		Time = os.time(),
		Event = "Add",
		Value = Player.UserId,
	}))
end

--[=[
    @within Party
    @function Remove
    @param Player Player
    @return Promise
    Removes a player from the party.
    - `Player` (Player): The player to remove from the party.
    - Returns a Promise.
]=]
function Party:Remove(Player: Player)
	if not table.find(self._Members, Player.UserId) then
		return Promise.reject("Player is not in the party.")
	end

	return Promise.resolve(self._Processor:Add({
		Key = self._Id,
		Time = os.time(),
		Event = "Remove",
		Value = Player.UserId,
	}))
end

--[=[
    @within Party
    @function SetMaxSize
    @param MaxSize number
    @return Promise
    Sets the maximum size of the party.
    - `MaxSize` (number): The new maximum size of the party.
    - Returns a Promise.
]=]
function Party:SetMaxSize(MaxSize: number)
	if MaxSize == self._metadata.MaxSize then
		return Promise.reject("MaxSize is already equal to the current MaxSize.")
	elseif MaxSize == #self._Members then
		return Promise.reject("MaxSize is already equal to the current number of members.")
	elseif MaxSize < #self._Members then
		return Promise.reject("MaxSize cannot be less than the current number of members.")
	elseif MaxSize < 0 then
		return Promise.reject("MaxSize cannot be less than 0.")
	end

	return Promise.resolve(self._Processor:Add({
		Key = self._Id,
		Time = os.time(),
		Event = "SetMax",
		Value = MaxSize,
	}))
end

--[=[
    @within Party
    @function Destroy
    Destroys the party. should internally be called when the party is empty.
]=]
function Party:Destroy()
	local Destroying = self.Destroying
	Destroying:Fire()
	task.defer(Destroying.Destroy, Destroying)
	self.PlayerAdded:Destroy()
	self.PlayerRemoved:Destroy()
	table.clear(self)
end

return Party
