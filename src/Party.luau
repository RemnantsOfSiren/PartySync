--!strict
local HttpService = game:GetService("HttpService")

local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Parent.Signal)
local Promise = require(script.Parent.Parent.Promise)

local Party = {}
Party.__index = Party

export type Party = typeof(setmetatable(
	{} :: {
        _metadata: {[string]: any},
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

function Party.new(Config: {
	Player: Player,
	MaxSize: number?,
	Override: string?,
	Processor: { Add: (self: any, Event: Types.Process) -> () },
    metadata: {[string]: any}?,
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

function Party:Add(Player: Player)
    if #self._Members > self._metadata.MaxSize then
        return Promise.reject("Party is already at max size.")
    end

	return Promise.resolve(self._Processor:Add({
		Key = self._Id,
		Time = os.time(),
		Event = "Add",
		Value = Player.UserId,
	}))
end

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

function Party:Destroy()
	local Destroying = self.Destroying
	Destroying:Fire()
	task.defer(Destroying.Destroy, Destroying)
	self.PlayerAdded:Destroy()
	self.PlayerRemoved:Destroy()
	table.clear(self)
end

return Party
