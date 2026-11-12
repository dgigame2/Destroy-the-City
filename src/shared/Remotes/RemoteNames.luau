-- Único lugar onde os nomes de RemoteEvents/RemoteFunctions existem.
local RemoteNames = {
	Events = {
		BuyUpgrade = "BuyUpgrade",
	},
	Functions = {},
}

return table.freeze(RemoteNames)
