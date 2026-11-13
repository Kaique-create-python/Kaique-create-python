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

local function copiar(b: Model, codigo: string): Model
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

-- Cópia do avatar para cena (raiz ancorada, sem colisão, sem nome em cima da cabeça)
function Personagens.criar(codigo: string): Model
	local b = base(codigo)
	assert(b, "o avatar " .. codigo .. " ainda não carregou do catálogo")
	return copiar(b, codigo)
end

-- o monstro. AJUSTE-11: "variante" escolhe um modelo específico (ex.: "catalogo" no esconde-esconde);
-- sem variante (ou se ela não carregou) vem o monstro principal (o Wendigo, se carregou)
function Personagens.criarCriatura(variante: string?): Model
	if variante then
		local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores")
		local lista = pasta and pasta:FindFirstChild("Monstros")
		local v = lista and lista:FindFirstChild(variante)
		if v and v:IsA("Model") then
			return copiar(v, "CRIATURA")
		end
	end
	return Personagens.criar("CRIATURA")
end

-- Reações: troca o rosto por outro ITEM do catálogo (medo, risada, nervoso, choro). Fora delas, o rosto
-- do personagem volta. Os rostos vêm prontos do servidor (OI3_Atores/Rostos).
--
-- AJUSTE-8: os rostos do catálogo são feitos para a cabeça R15, que é um pouco menor que a cabeça R6
-- (malha "Head" com escala 1.25 → 0.625 de meia profundidade). Encaixados pelo jeito normal, alguns
-- ficavam DENTRO da cabeça e a cabeça aparecia só amarela. Agora cada rosto é encaixado pelo ponto
-- certo (FaceFront/FaceCenter), medido, e puxado para fora (ou aumentado, se for um "casco" de cabeça
-- inteira) até ficar visível. E fica numa pasta soldada à cabeça, não num Accessory (o Humanoid não
-- re-solda por conta própria e não briga com a nossa solda).
local OI3 = script.Parent
local Config = require(OI3.Config)
local guardados: { [Model]: { Instance } } = setmetatable({}, { __mode = "k" }) :: any

local MEIA_CABECA_R6 = 0.625

-- função pura (testável): a frente da caixa do rosto, no espaço da cabeça (-Z = frente)
function Personagens.frenteDoRosto(rel: CFrame, tam: Vector3): number
	local frente = math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = rel * Vector3.new(sx * tam.X / 2, sy * tam.Y / 2, sz * tam.Z / 2)
				if p.Z < frente then
					frente = p.Z
				end
			end
		end
	end
	return frente
end

-- função pura (testável): onde o rosto fica para aparecer (novo rel no espaço da cabeça + fator de aumento)
function Personagens.posicaoRosto(rel: CFrame, tam: Vector3, s: number): (CFrame, number)
	local frenteCabeca = -MEIA_CABECA_R6 * s
	local frente = Personagens.frenteDoRosto(rel, tam)
	local largura = math.min(tam.X, tam.Y)
	if largura >= 0.85 * 2 * MEIA_CABECA_R6 * s then
		-- "casco" (rosto pintado num capacete do tamanho da cabeça): aumenta até cobrir a cabeça R6
		if frente > frenteCabeca - 0.02 then
			local fator = (2 * MEIA_CABECA_R6 * s + 0.08) / math.max(math.min(tam.X, tam.Z), 0.05)
			return rel, math.max(fator, 1)
		end
		return rel, 1
	end
	if frente > frenteCabeca - 0.02 then
		-- rosto só da frente (olhos e boca): puxa para fora da cabeça
		return CFrame.new(0, 0, (frenteCabeca - 0.035) - frente) * rel, 1
	end
	return rel, 1
end

-- Encaixa um rosto (Accessory ou a peça dele) na cabeça do modelo, visível. Devolve a pasta criada.
function Personagens.encaixarRosto(modelo: Model, rosto: Instance, escala: number?, marca: string?): Folder?
	local cabeca = modelo:FindFirstChild("Head")
	local alca = if rosto:IsA("BasePart") then rosto else rosto:FindFirstChild("Handle")
	if not (cabeca and cabeca:IsA("BasePart") and alca and alca:IsA("BasePart")) then
		return nil
	end
	local s = escala or modelo:GetAttribute("Escala") or 1
	local encaixe = alca:FindFirstChild("FaceFrontAttachment") or alca:FindFirstChild("FaceCenterAttachment")
	local alvo = encaixe and cabeca:FindFirstChild(encaixe.Name)
	local rel: CFrame
	if encaixe and encaixe:IsA("Attachment") and alvo and alvo:IsA("Attachment") then
		rel = alvo.CFrame * encaixe.CFrame:Inverse()
	elseif alca:IsDescendantOf(modelo) then
		rel = cabeca.CFrame:ToObjectSpace(alca.CFrame)
	else
		rel = CFrame.new(0, 0, -MEIA_CABECA_R6 * s)
	end
	if alca:FindFirstChildOfClass("SpecialMesh") then
		-- malha antiga: o tamanho da peça não é o da malha; só garante que fica um pouco para fora
		rel = CFrame.new(0, 0, -0.04 * s) * rel
	else
		local novoRel, fator = Personagens.posicaoRosto(rel, alca.Size, s)
		rel = novoRel
		if fator > 1.001 then
			alca.Size *= fator
		end
	end
	for _, j in alca:GetChildren() do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
			j:Destroy()
		end
	end
	alca.Anchored = false
	alca.CanCollide = false
	alca.CanQuery = false
	alca.CanTouch = false
	alca.Massless = true
	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_Rosto"
	pasta:SetAttribute(marca or "OI3_Rosto", true)
	alca.Name = "RostoMalha"
	alca.Parent = pasta
	if rosto ~= alca then
		rosto:Destroy() -- o Accessory vazio não serve mais
	end
	alca.CFrame = cabeca.CFrame * rel
	local w = Instance.new("WeldConstraint")
	w.Name = "OI3_RostoSolda"
	w.Part0 = cabeca
	w.Part1 = alca
	w.Parent = alca
	pasta.Parent = modelo
	return pasta
end

-- Troca TODOS os acessórios de rosto de um modelo pela versão encaixada e visível (servidor e cliente)
function Personagens.fixarRostos(modelo: Model, escala: number?): number
	local n = 0
	for _, a in modelo:GetChildren() do
		if a:IsA("Accessory") then
			local alca = a:FindFirstChild("Handle")
			if alca and (alca:FindFirstChild("FaceFrontAttachment") or alca:FindFirstChild("FaceCenterAttachment")) then
				if Personagens.encaixarRosto(modelo, a, escala, "OI3_Rosto") then
					n += 1
				end
			end
		end
	end
	return n
end

local function ehRosto(x: Instance): boolean
	return x:GetAttribute("OI3_Rosto") == true or x:GetAttribute("OI3_Reacao") == true
end

function Personagens.expressao(modelo: Model, nome: string)
	local reacao = (Config.REACOES or {})[nome]
	local atual = modelo:GetAttribute("Reacao") or "base"
	local alvo = reacao or "base"
	if atual == alvo then
		return
	end
	local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores")
	local biblioteca = pasta and pasta:FindFirstChild("Rostos")
	local codigo = modelo:GetAttribute("Codigo")
	-- rosto de reação do personagem (se tiver) ou o geral
	local novo = reacao
		and biblioteca
		and (biblioteca:FindFirstChild((codigo or "") .. "_" .. reacao) or biblioteca:FindFirstChild(reacao))
	if reacao and not novo then
		return -- rosto de reação não carregou: fica com o rosto de sempre
	end
	-- tira o rosto atual (o de sempre fica guardado para voltar depois)
	local base = guardados[modelo]
	for _, a in modelo:GetChildren() do
		if ehRosto(a) then
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
		local ok = pcall(function()
			assert(Personagens.encaixarRosto(modelo, novo:Clone(), nil, "OI3_Reacao"))
		end)
		if not ok and base then
			-- não deu para encaixar: volta o rosto de sempre (nunca fica sem rosto)
			for _, a in base do
				a.Parent = modelo
			end
			guardados[modelo] = nil
			modelo:SetAttribute("Reacao", "base")
			return
		end
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
