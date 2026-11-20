--!strict
-- Acesso centralizado aos remotes. O servidor cria as instâncias; o cliente espera por elas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Names = require(script.RemoteNames)

local FOLDER_NAME = "RemoteInstances"

local Remotes = {}
Remotes.Names = Names

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Chamado uma vez pelo servidor, antes de qualquer uso.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init só roda no servidor")
	local folder = getFolder()
	-- não duplica: se outro script já criou o remote, reaproveita (remote duplicado faz o cliente
	-- chamar a cópia sem resposta e ficar esperando para sempre)
	for _, name in Names.Events do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Names.Unreliable do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("UnreliableRemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Names.Functions do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.event(name: string): RemoteEvent
	assert(Names.Events[name] ~= nil, `RemoteEvent desconhecido: {name}`)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.unreliable(name: string): UnreliableRemoteEvent
	assert(Names.Unreliable[name] ~= nil, `UnreliableRemoteEvent desconhecido: {name}`)
	return getFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	assert(Names.Functions[name] ~= nil, `RemoteFunction desconhecida: {name}`)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
