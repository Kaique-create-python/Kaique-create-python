-- OI3 :: roupas dos personagens (AJUSTE-5)
-- O servidor usa o sistema oficial do Roblox (HumanoidDescription) para carregar camisa, calça,
-- cabelo e rosto do catálogo, e guarda só essas peças em ReplicatedStorage.OI3_Roupas/<código>.
-- Os bonecos da cutscene (montados por código, com rosto desenhado) vestem esses kits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OI3 = ReplicatedStorage:WaitForChild("OI3")
local Config = require(OI3:WaitForChild("Config"))

local Roupas = {}

local function kitDe(codigo: string, r: any): Folder
	local kit = Instance.new("Folder")
	kit.Name = codigo
	local d = Instance.new("HumanoidDescription")
	d.Shirt = tonumber(r.camisa) or 0
	d.Pants = tonumber(r.calca) or 0
	d.Face = tonumber(r.rosto) or 0
	local cabelos = {}
	for _, id in r.cabelo or {} do
		if tonumber(id) and tonumber(id) > 0 then
			table.insert(cabelos, tostring(id))
		end
	end
	d.HairAccessory = table.concat(cabelos, ",")
	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R6)
	end)
	if not ok or not modelo then
		warn("[OI3] roupas de " .. codigo .. " não carregaram:", modelo)
		return kit
	end
	for _, x in modelo:GetChildren() do
		if x:IsA("Shirt") or x:IsA("Pants") or x:IsA("Accessory") then
			x:Clone().Parent = kit
		end
	end
	if (tonumber(r.rosto) or 0) > 0 then
		local cabeca = modelo:FindFirstChild("Head")
		local rosto = cabeca and cabeca:FindFirstChildWhichIsA("Decal")
		if rosto then
			local c = rosto:Clone()
			c.Name = "RostoCatalogo"
			c.Parent = kit
		end
	end
	modelo:Destroy()
	return kit
end

function Roupas.preparar()
	task.spawn(function()
		local pasta = Instance.new("Folder")
		pasta.Name = "OI3_Roupas_Montando"
		for codigo, r in Config.ROUPAS or {} do
			kitDe(codigo, r).Parent = pasta
		end
		local antiga = ReplicatedStorage:FindFirstChild("OI3_Roupas")
		if antiga then
			antiga:Destroy()
		end
		pasta.Name = "OI3_Roupas"
		pasta.Parent = ReplicatedStorage
	end)
end

return Roupas
