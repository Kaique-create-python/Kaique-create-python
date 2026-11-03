-- BIZARRE BATTLEGROUNDS :: quem está lutando (jogadores e bots), com o estado de combate de cada um

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BB = ReplicatedStorage:WaitForChild("BB")
local Regras = require(BB:WaitForChild("Regras"))
local Stands = require(BB:WaitForChild("Stands"))

local Lutadores = {}

local porModelo: { [Model]: any } = {}
local lista: { any } = {}
local versao = 0

function Lutadores.criar(modelo: Model, jogador: Player?, standId: string, opcoes: any?)
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	assert(hum and raiz, "lutador sem Humanoid/HumanoidRootPart")
	local stand = Stands.get(standId) or Stands.get(Stands.padrao())
	local o = opcoes or {}
	local lut = {
		modelo = modelo,
		hum = hum,
		raiz = raiz,
		jogador = jogador,
		bot = o.bot,
		boneco = o.boneco,
		nome = o.nome or (if jogador then jogador.DisplayName else modelo.Name),
		standId = stand.id,
		stand = stand,
		estado = Regras.novoEstado(),
		dir = raiz.CFrame.LookVector,
		dirT = 0,
		correndo = false,
		filaTempo = nil,
		congeladoPor = nil,
		ultimoAtacante = nil,
		ultimoAtacanteT = -1e9,
		sequencia = 0,
		marcas = {},
	}
	lut.estado.multDanoRecebido = (stand.passiva and stand.passiva.multDanoRecebido) or 1
	porModelo[modelo] = lut
	table.insert(lista, lut)
	versao += 1
	modelo:SetAttribute("BB_Stand", stand.id)
	modelo:SetAttribute("BB_StandFora", false)
	modelo:SetAttribute("BB_Lutador", true)
	modelo:SetAttribute("BB_Nome", lut.nome)
	return lut
end

function Lutadores.trocarStand(lut: any, standId: string)
	local stand = Stands.get(standId)
	if not stand then
		return false
	end
	lut.standId = stand.id
	lut.stand = stand
	lut.estado.cds = {}
	lut.estado.despertar = 0
	lut.estado.despertoAte = 0
	lut.estado.multDanoRecebido = (stand.passiva and stand.passiva.multDanoRecebido) or 1
	lut.modelo:SetAttribute("BB_Stand", stand.id)
	lut.modelo:SetAttribute("BB_Despertar", 0)
	lut.modelo:SetAttribute("BB_Desperto", 0)
	return true
end

function Lutadores.de(modelo: Instance?): any
	if not modelo then
		return nil
	end
	return porModelo[modelo :: Model]
end

-- acha o lutador dono de uma peça qualquer (braço, acessório...)
function Lutadores.daPeca(peca: Instance): any
	local p: Instance? = peca
	while p and p ~= workspace do
		local l = porModelo[p :: Model]
		if l then
			return l
		end
		p = p.Parent
	end
	return nil
end

function Lutadores.remover(modelo: Model)
	local lut = porModelo[modelo]
	if not lut then
		return
	end
	porModelo[modelo] = nil
	local i = table.find(lista, lut)
	if i then
		table.remove(lista, i)
	end
	versao += 1
end

function Lutadores.todos(): { any }
	return lista
end

function Lutadores.vivos(): { any }
	local r = {}
	for _, l in lista do
		if l.hum.Health > 0 and l.modelo.Parent then
			table.insert(r, l)
		end
	end
	return r
end

function Lutadores.versao(): number
	return versao
end

function Lutadores.doJogador(jogador: Player): any
	for _, l in lista do
		if l.jogador == jogador then
			return l
		end
	end
	return nil
end

-- direção "achatada" para onde o lutador está olhando (a que o cliente mandou, se for recente)
function Lutadores.olhar(lut: any, agora: number): Vector3
	if agora - (lut.dirT or 0) < 0.6 and lut.dir then
		return Regras.achatar(lut.dir)
	end
	return Regras.achatar(lut.raiz.CFrame.LookVector)
end

return Lutadores
