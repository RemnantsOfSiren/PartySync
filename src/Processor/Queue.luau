--!strict
local Types = require(script.Parent.Parent.Types)

local Queue = {}
Queue.__index = Queue

export type Queue = typeof(setmetatable(
	{} :: {
		List: { Types.Process },
	},
	Queue
))

function Queue.new(): Queue
	return setmetatable({
		List = {} :: { Types.Process },
	}, Queue)
end

function Queue:Size()
	return #self.List
end

function Queue:Enqueue(Process: Types.Process)
	table.insert(self.List, Process)

	return true
end

function Queue:Dequeue(): Types.Process?
	if #self.List == 0 then
		return nil
	end

	return table.remove(self.List, 1)
end

function Queue:Peek()
	return self.List[1]
end

function Queue:Clear()
	table.clear(self.List)
end

function Queue:Remove(Process: Types.Process)
	for I = #self.List, 1, -1 do
		if self.List[I] == Process then
			table.remove(self.List, I)
			return true
		end
	end
	return false
end

return Queue
