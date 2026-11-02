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

-- Os rostos são itens do catálogo: não mudam por código (mantidas para a cutscene não quebrar)
function Personagens.expressao(_modelo: Model, _nome: string) end
function Personagens.piscar(_modelo: Model) end

return Personagens
