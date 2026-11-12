local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared.Remotes.RemoteNames)

-- Cria todos os remotes a partir da lista central
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "RemoteInstances"

for _, name in RemoteNames.Events do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
end

for _, name in RemoteNames.Functions do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotesFolder
end

remotesFolder.Parent = ReplicatedStorage

print("[Server] Rojo funcionando! Remotes criados.")
