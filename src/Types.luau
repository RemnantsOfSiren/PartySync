export type Process = {
	Key: string,
	Time: number,
	Value: number,
	Event: "Add" | "Remove" | "SetMax",
}

export type Config = {
	Name: string,
	Type: "Persistent" | "Temporary",
	MaxSize: number?,
	BatchOverrides: {
		Size: number?,
		Delay: number?,
	}?,
}

return {}
