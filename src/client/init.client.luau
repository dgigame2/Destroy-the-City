local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteInstances")

print("[Client] Rojo funcionando! Remotes encontrados:", #remotes:GetChildren())
