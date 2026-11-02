-- OI3 :: personagens (AJUSTE-6)
-- Todos os personagens são AVATARES DO ROBLOX montados pelo servidor SÓ com IDs do catálogo
-- (rosto, cabelo, chapéu, camisa, calça e cor do corpo — veja Config.ROUPAS e o módulo Atores
-- do servidor). Nada é modelado por código. Aqui o cliente só copia o avatar pronto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Personagens = {}

Personagens.DEFS = {
	VO = { nome = "Vô" },
	KE = { nome = "Keko" },
	NI = { nome = "Nina" },
	ME = { nome = "Menino" },
}

local function base(codigo: string): Model?
	local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores") or ReplicatedStorage:WaitForChild("OI3_Atores", 30)
	if not pasta then
		return nil
	end
	return (pasta:FindFirstChild(codigo) or pasta:WaitForChild(codigo, 10)) :: Model?
end

-- true quando o servidor já montou os avatares
function Personagens.pronto(): boolean
	return ReplicatedStorage:FindFirstChild("OI3_Atores") ~= nil
end

-- Cópia do avatar para cena (raiz ancorada, sem colisão, sem nome em cima da cabeça)
function Personagens.criar(codigo: string): Model
	local b = base(codigo)
	assert(b, "o avatar " .. codigo .. " ainda não carregou do catálogo")
	local m = b:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	local raiz = m:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		raiz.Anchored = true
		m.PrimaryPart = raiz
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
	end
	m:SetAttribute("Codigo", codigo)
	return m
end

-- a sombra do espelho (avatar padrão do Roblox, todo preto)
function Personagens.criarCriatura(): Model
	return Personagens.criar("CRIATURA")
end

-- Reações: troca o rosto por outro ITEM do catálogo (medo, risada, nervoso). Fora delas, o rosto
-- do personagem volta. Os rostos vêm prontos do servidor (OI3_Atores/Rostos).
local OI3 = script.Parent
local Config = require(OI3.Config)
local guardados: { [Model]: { Accessory } } = setmetatable({}, { __mode = "k" }) :: any

local function escalar(a: Accessory, s: number)
	local alca = a:FindFirstChild("Handle")
	if not alca or not alca:IsA("BasePart") then
		return
	end
	alca.Anchored = false
	alca.CanCollide = false
	alca.CanQuery = false
	alca.CanTouch = false
	alca.Massless = true
	if math.abs(s - 1) > 0.001 then
		local malha = alca:FindFirstChildOfClass("SpecialMesh")
		if malha then
			malha.Scale *= s
			malha.Offset *= s
		end
		alca.Size *= s
		for _, at in alca:GetChildren() do
			if at:IsA("Attachment") then
				at.Position *= s
			end
		end
	end
end

function Personagens.expressao(modelo: Model, nome: string)
	local reacao = (Config.REACOES or {})[nome]
	local atual = modelo:GetAttribute("Reacao") or "base"
	local alvo = reacao or "base"
	if atual == alvo then
		return
	end
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores")
	local biblioteca = pasta and pasta:FindFirstChild("Rostos")
	local novo = reacao and biblioteca and biblioteca:FindFirstChild(reacao)
	if reacao and not novo then
		return -- rosto de reação não carregou: fica com o rosto de sempre
	end
	-- tira o rosto atual (o de sempre fica guardado para voltar depois)
	local base = guardados[modelo]
	for _, a in modelo:GetChildren() do
		if a:IsA("Accessory") and a:GetAttribute("OI3_Rosto") then
			if a:GetAttribute("OI3_Reacao") then
				a:Destroy()
			else
				if not base then
					base = {}
					guardados[modelo] = base
				end
				table.insert(base, a)
				a.Parent = nil
			end
		end
	end
	if novo then
		local c = novo:Clone()
		c:SetAttribute("OI3_Reacao", true)
		escalar(c, modelo:GetAttribute("Escala") or 1)
		pcall(function()
			hum:AddAccessory(c)
		end)
	elseif base then
		for _, a in base do
			a.Parent = modelo
		end
		guardados[modelo] = nil
	end
	modelo:SetAttribute("Reacao", alvo)
end

function Personagens.piscar(_modelo: Model) end

return Personagens
