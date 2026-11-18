--!strict
-- PROJETO BASTIÃO :: giroflex (cliente)
-- O servidor só liga as luzes; cada cliente gira o rotor dos giroflexes que estão
-- carregados (streaming) enquanto o alarme durar. Nada roda quando o alarme está desligado.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Giroflex = {}

local TAG = "BastiaoGiroflex"
local VELOCIDADE = 4.2 -- radianos por segundo

function Giroflex.iniciar(ligado: () -> boolean)
	local bases: { [BasePart]: CFrame } = {}
	local function entrou(inst: Instance)
		if inst:IsA("BasePart") then
			bases[inst] = inst.CFrame
		end
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		entrou(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(entrou)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst: Instance)
		bases[inst :: BasePart] = nil
	end)

	local girando = false
	RunService.RenderStepped:Connect(function()
		local agora = ligado()
		if agora then
			local angulo = (os.clock() * VELOCIDADE) % (math.pi * 2)
			for p, base in bases do
				if p.Parent then
					p.CFrame = base * CFrame.Angles(0, angulo, 0)
				end
			end
		elseif girando then
			for p, base in bases do
				if p.Parent then
					p.CFrame = base
				end
			end
		end
		girando = agora
	end)
end

return Giroflex
