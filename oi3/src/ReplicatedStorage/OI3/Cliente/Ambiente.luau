-- OI3 :: ambiente sonoro da exploração (AJUSTE-4)
--  * dentro x fora da casa: troca suave entre vento + grilos (fora) e o ar da casa + assobio do vento (dentro)
--  * sons presos no lugar (3D): a lareira estalando no hall e o relógio em cima dela
--  * sons soltos de vez em quando, vindos de um ponto perto do jogador: goteira, estalo da madeira,
--    rangido, galhos batendo no vidro e (raro) um sussurro
-- Se o arquivo de ambiente não estiver disponível, usa só os sons antigos (rangido/sussurro).

local Players = game:GetService("Players")

local Som = require(script.Parent.Som)

local Ambiente = {}

-- caixas do prédio {x0, x1, z0, z1}: prédio principal e a ala leste (corredor + quarto do espelho)
local CAIXAS = {
	{ -36.5, 36.5, -24.5, 12.5 },
	{ 12, 71, -9, 9 },
}
local Y_MIN, Y_MAX = -3, 16
local VOLUME_MINIMO = 0.005 -- nunca zera de vez: evita recriar o som toda vez que passa na porta

local estado = {
	ativo = false,
	token = 0,
	dentro = nil :: boolean?,
	pasta = nil :: Folder?,
	lareira = nil :: Sound?,
	relogio = nil :: Sound?,
}

-- função pura (testável)
function Ambiente.dentroDaCasa(p: Vector3): boolean
	if p.Y < Y_MIN or p.Y > Y_MAX then
		return false
	end
	for _, c in CAIXAS do
		if p.X >= c[1] and p.X <= c[2] and p.Z >= c[3] and p.Z <= c[4] then
			return true
		end
	end
	return false
end

-- volumes de cada som de fundo (função pura, testável)
function Ambiente.mistura(dentro: boolean): { [string]: number }
	if dentro then
		return { interior = 0.6, vento = 0.12, grilos = 0.07, assobio = 0.24 }
	end
	return { interior = 0, vento = 0.5, grilos = 0.45, assobio = 0 }
end

-- sorteia o som solto da vez (função pura, testável). r = número de 0 a 1.
function Ambiente.sortear(dentro: boolean, r: number, temNovos: boolean): string?
	if not temNovos then
		if not dentro then
			return nil
		end
		return if r < 0.75 then "rangido" else "sussurro"
	end
	if dentro then
		if r < 0.28 then
			return "goteira"
		elseif r < 0.56 then
			return "estalo"
		elseif r < 0.78 then
			return "rangido"
		elseif r < 0.94 then
			return "galhos"
		end
		return "sussurro"
	end
	if r < 0.55 then
		return "galhos"
	elseif r < 0.8 then
		return "estalo"
	end
	return nil
end

local function raizDoJogador(): BasePart?
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		return raiz
	end
	return nil
end

local function ponto(posicao: Vector3, nome: string): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = posicao
	p.Parent = estado.pasta
	return p
end

local function acharLareira(): BasePart?
	local orfanato = workspace:FindFirstChild("Orfanato")
	if not orfanato then
		return nil
	end
	for _, d in orfanato:GetDescendants() do
		if d:IsA("Fire") and d.Parent and d.Parent:IsA("BasePart") then
			return d.Parent :: BasePart
		end
	end
	return nil
end

-- cria (ou recria) a lareira e o relógio que tocam no lugar
local function garantirEmissores()
	if not estado.pasta then
		return
	end
	local lareiraOk = estado.lareira ~= nil and estado.lareira.Parent ~= nil
	local relogioOk = estado.relogio ~= nil and estado.relogio.Parent ~= nil
	if lareiraOk and relogioOk then
		return -- já está tudo tocando: nem procura de novo
	end
	local brasa = acharLareira()
	if not brasa then
		return
	end
	local function emissor(nome: string, deslocamento: Vector3, opcoes: any): Sound?
		local velho = estado.pasta and estado.pasta:FindFirstChild("OI3_Som_" .. nome)
		if velho then
			velho:Destroy() -- o som anterior não carregou: recomeça limpo
		end
		local p = ponto(brasa.Position + deslocamento, "OI3_Som_" .. nome)
		opcoes.pai = p
		opcoes.loop = true
		local s = Som.tocar(nome, opcoes)
		if not s then
			p:Destroy()
		end
		return s
	end
	if not lareiraOk and Som.disponivel("lareira") then
		estado.lareira = emissor("lareira", Vector3.new(0, 1.2, 0), { volume = 0.9, minimo = 5, alcance = 48 })
	end
	if not relogioOk and Som.disponivel("relogio") then
		estado.relogio = emissor("relogio", Vector3.new(0, 4.6, 0), { volume = 0.32, minimo = 3, alcance = 22 })
	end
end

local function aplicarMistura(dentro: boolean, fade: number)
	for nome, v in Ambiente.mistura(dentro) do
		if Som.disponivel(nome) then
			Som.ambiente(nome, math.max(v, VOLUME_MINIMO), fade)
		end
	end
end

local function tocarSolto(dentro: boolean)
	local raiz = raizDoJogador()
	if not raiz then
		return
	end
	local temNovos = Som.disponivel("goteira1")
	local tipo = Ambiente.sortear(dentro, math.random(), temNovos)
	if not tipo then
		return
	end
	if tipo == "sussurro" then
		Som.tocar("sussurro", { volume = 0.2 })
		return
	end
	local nome = tipo
	if tipo == "goteira" or tipo == "estalo" then
		nome = tipo .. math.random(1, 2)
	end
	-- vem de um ponto perto (8 a 22 studs), em volta do jogador
	local ang = math.random() * math.pi * 2
	local dist = 8 + math.random() * 14
	local pos = raiz.Position + Vector3.new(math.cos(ang) * dist, math.random() * 5 - 1, math.sin(ang) * dist)
	local volume = ({ goteira = 0.55, estalo = if dentro then 0.6 else 0.35, rangido = 0.4, galhos = if dentro then 0.35 else 0.5 })[tipo] or 0.4
	local p = ponto(pos, "OI3_SomSolto")
	local s = Som.tocar(nome, { pai = p, volume = volume, minimo = 10, alcance = 70, velocidade = 0.9 + math.random() * 0.2 })
	task.delay(if s then 8 else 0, function()
		p:Destroy()
	end)
end

function Ambiente.iniciar()
	Ambiente.parar(0)
	estado.ativo = true
	estado.token += 1
	local token = estado.token
	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_SonsAmbiente"
	pasta.Parent = workspace
	estado.pasta = pasta
	estado.dentro = nil

	-- mistura dentro/fora (confere 2x por segundo; reaplica de tempos em tempos)
	task.spawn(function()
		local ultimaReaplicacao = 0
		while estado.ativo and token == estado.token do
			local raiz = raizDoJogador()
			if raiz then
				local dentro = Ambiente.dentroDaCasa(raiz.Position)
				local agora = os.clock()
				if dentro ~= estado.dentro then
					aplicarMistura(dentro, if estado.dentro == nil then 2 else 1.8)
					estado.dentro = dentro
					ultimaReaplicacao = agora
				elseif agora - ultimaReaplicacao > 6 then
					-- se um áudio ficou pronto depois (ou caiu), ele entra aqui
					aplicarMistura(dentro, 1)
					garantirEmissores()
					ultimaReaplicacao = agora
				end
			end
			task.wait(0.5)
		end
	end)
	garantirEmissores()

	-- sons soltos de vez em quando
	task.spawn(function()
		while estado.ativo and token == estado.token do
			task.wait(7 + math.random() * 11)
			if not estado.ativo or token ~= estado.token then
				break
			end
			tocarSolto(estado.dentro == true)
		end
	end)
end

function Ambiente.parar(fade: number?)
	local t = fade or 1.2
	estado.ativo = false
	estado.token += 1
	for nome in Ambiente.mistura(true) do
		Som.ambiente(nome, 0, t)
	end
	local pasta = estado.pasta
	estado.pasta = nil
	estado.lareira = nil
	estado.relogio = nil
	if pasta then
		task.delay(t + 0.2, function()
			pasta:Destroy()
		end)
	end
end

return Ambiente
