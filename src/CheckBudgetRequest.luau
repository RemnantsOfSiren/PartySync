local DataStoreService = game:GetService("DataStoreService")

return function(Event: "Get" | "Set" | "Increment", Batch: number?): boolean
	local Budget
	local Success, Error = pcall(function()
		Budget = DataStoreService:GetRequestBudgetForRequestType(
			if Event == "Get" then Enum.DataStoreRequestType.GetAsync else Enum.DataStoreRequestType.SetIncrementAsync
		)
	end)
	if not Success then
		warn(Error)
	end
	return (Budget or 0) >= (Batch or 20)
end
