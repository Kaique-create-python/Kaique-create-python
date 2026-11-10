-- BIZARRE BATTLEGROUNDS :: a cidade quebrável (quebra e reconstrói sozinha)
-- Mapa principal: Morioh (Workspace.Morioh, feito no ChatGPT). Cada peça quebrável tem o atributo
-- Health; a força do golpe vira dano (Config.MAPA.danoPorForca) e, quando a vida acaba, a peça
-- some (fica invisível e sem colisão) e os celulares soltam os destroços. Depois de 30 s ela volta
-- (se ninguém estiver no lugar). Peças MoriohStatic (chão, rua, fundação) nunca quebram e um golpe
-- quebra no máximo Config.MAPA.maxPorImpacto peças (as mais perto do impacto).
-- Sem o Morioh (testes), monta a cidade antiga do Plano.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Plano = require(BB:WaitForChild("Mapa"):WaitForChild("Plano"))
local Fisica = require(script.Parent.Fisica)
local Hitbox = require(script.Parent.Hitbox)

local Mapa = {}

Mapa.modo = "plano" :: string
Mapa.pasta = nil :: Instance? -- onde ficam as peças da cidade (Morioh ou BB_Mapa)
Mapa.pastaQuebravel = nil :: Instance?
Mapa.pastaTemporarias = nil :: Folder?

-- vida das peças da cidade antiga (força 1 quebra vidro/adereço, 2 parede/carro, 3 estátua)
Mapa.VIDA_PLANO = { vidro = 20, adereco = 50, parede = 100, carro = 110, estatua = 200, temporario = 40 }

-- pontos de nascer do Morioh: todos conferidos em rua livre (asfalto em Y = 0, nada em cima)
local SPAWNS_MORIOH = {
	{ 0, 40 }, { 0, -40 }, { 40, 0 }, { -40, 0 },
	{ 0, 110 }, { 0, -110 }, { 110, 0 }, { -110, 0 },
	{ 0, 200 }, { 0, -200 }, { 200, 0 }, { -200, 0 },
	{ 240, -120 }, { -240, 120 },
}
-- área de treino: Campo do Budogaoka (chão em Y = 0,16)
local TREINO_MORIOH = {
	spawn = { -760, 140 },
	bonecos = { { -790, 120 }, { -790, 140 }, { -790, 160 } },
}
Mapa.CENTRO_MENU = Vector3.new(0, 30, 0)

type Info = {
	parte: BasePart,
	vida: number,
	vidaMax: number,
	vidro: boolean,
	grupo: any?,
	quebrada: boolean,
	volta: number,
	ultimoDano: number,
	orig: { any }?,
	temporaria: boolean?,
	spec: any?,
}

local infos: { [BasePart]: Info } = {}
local grupos: { [any]: { BasePart } } = {} -- só a cidade antiga (carro/árvore/poste quebram juntos)
local quebradas: { [BasePart]: boolean } = {}
local danificadas: { [BasePart]: boolean } = {}
local pendentesQuebra: { any } = {}
local pendentesVolta: { BasePart } = {}
local remoto: RemoteEvent? = nil
local plano: any = nil
local spawnsProntos: { CFrame } = {}
local treinoPronto: any = nil

local paramsQuebravel = OverlapParams.new()
paramsQuebravel.FilterType = Enum.RaycastFilterType.Include
paramsQuebravel.MaxParts = 900

local function agora(): number
	return workspace:GetServerTimeNow()
end

-------------------------------------------------------------------------------- peças da cidade antiga
local function criarParte(p: any): BasePart
	local parte: BasePart
	if p.f == "Wedge" then
		parte = Instance.new("WedgePart")
	else
		local pp = Instance.new("Part")
		if p.f == "Cylinder" then
			pp.Shape = Enum.PartType.Cylinder
		elseif p.f == "Ball" then
			pp.Shape = Enum.PartType.Ball
		end
		parte = pp
	end
	parte.Name = p.n
	parte.Size = p.s
	parte.CFrame = p.cf
	parte.Color = p.c
	local okMat = pcall(function()
		parte.Material = (Enum.Material :: any)[p.m]
	end)
	if not okMat then
		parte.Material = Enum.Material.SmoothPlastic
	end
	parte.Anchored = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Transparency = p.t or 0
	parte.Reflectance = p.refl or 0
	if p.semColisao or p.k == "enfeite" then
		parte.CanCollide = false
		parte.CanQuery = false
		parte.CanTouch = false
		parte.CastShadow = p.k ~= "enfeite"
	end
	if p.k == "invisivel" then
		parte.CanQuery = false
		parte.CanTouch = false
		parte.CastShadow = false
	end
	if p.luz then
		local l = Instance.new("PointLight")
		l.Brightness = 1.2
		l.Range = 16
		l.Color = Color3.fromRGB(255, 226, 170)
		l.Parent = parte
	end
	if p.placa then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.Parent = parte
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = p.placa
		t.Font = Enum.Font.Bangers
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(30, 20, 60)
		t.Parent = sg
		local sg2 = sg:Clone()
		sg2.Face = Enum.NormalId.Front
		sg2.Parent = parte
	end
	if p.q then
		parte.CollisionGroup = Fisica.GRUPOS.quebravel
		parte:SetAttribute("BB_Q", p.id)
	end
	return parte
end

local function infoPlano(parte: BasePart, spec: any): Info
	local vida = Mapa.VIDA_PLANO[spec.k] or 50
	return {
		parte = parte,
		vida = vida,
		vidaMax = vida,
		vidro = spec.k == "vidro",
		grupo = spec.g,
		quebrada = false,
		volta = 0,
		ultimoDano = 0,
		spec = spec,
	}
end

local function construirPlano(pai: Instance?, planoPronto: any?)
	plano = planoPronto or Plano.gerar()
	local pasta = Instance.new("Folder")
	pasta.Name = "BB_Mapa"
	local fixas = Instance.new("Folder")
	fixas.Name = "Fixas"
	fixas.Parent = pasta
	local quebraveis = Instance.new("Folder")
	quebraveis.Name = "Quebraveis"
	quebraveis.Parent = pasta
	for _, p in plano.pecas do
		local parte = criarParte(p)
		if p.q then
			parte.Parent = quebraveis
			infos[parte] = infoPlano(parte, p)
			if p.g then
				grupos[p.g] = grupos[p.g] or {}
				table.insert(grupos[p.g], parte)
			end
		else
			parte.Parent = fixas
		end
	end
	pasta.Parent = pai or workspace
	Mapa.pasta = pasta
	Mapa.pastaQuebravel = quebraveis
	spawnsProntos = plano.spawns
	treinoPronto = plano.treino
	return pasta
end

-------------------------------------------------------------------------------- Morioh
local function ehDoMorioh(parte: BasePart): boolean
	return Mapa.modo == "morioh" and Mapa.pasta ~= nil and parte:IsDescendantOf(Mapa.pasta :: Instance)
end

local function quebravelMorioh(parte: BasePart): boolean
	if parte:GetAttribute("Destructible") ~= true or CollectionService:HasTag(parte, "MoriohStatic") then
		return false
	end
	local h = parte:GetAttribute("Health")
	return type(h) == "number" and h > 0
end

-- informação da peça (criada só quando ela leva o primeiro golpe)
local function infoDe(parte: BasePart): Info?
	local info = infos[parte]
	if info then
		return info
	end
	if not ehDoMorioh(parte) or not quebravelMorioh(parte) then
		return nil
	end
	local vida = parte:GetAttribute("Health") :: number
	-- peça enorme (toldo, letreiro, telhado inteiro) precisa de mais pancada
	local maior = math.max(parte.Size.X, parte.Size.Y, parte.Size.Z)
	if maior > 40 then
		vida *= maior / 40
	end
	local vidro = CollectionService:HasTag(parte, "MoriohGlass") or parte:GetAttribute("MaterialClass") == "Glass"
	local novo: Info = {
		parte = parte,
		vida = vida,
		vidaMax = vida,
		vidro = vidro,
		grupo = nil,
		quebrada = false,
		volta = 0,
		ultimoDano = 0,
	}
	infos[parte] = novo
	return novo
end

local PISO = {
	Floor = true, Stair = true, Paving = true, Deck = true, SportSurface = true, Sidewalk = true,
	Road = true, Curb = true, Ground = true, Foundation = true, Railway = true, Beach = true,
	Crosswalk = true, RoadMarking = true, RoadDetail = true, SidewalkDetail = true, Plinth = true,
}

local function cfNoChao(x: number, y: number, z: number, olharPara: Vector3?): CFrame
	local pos = Vector3.new(x, y + 3.2, z)
	local alvo = olharPara or Vector3.new(0, pos.Y, 0)
	if (Vector3.new(alvo.X, pos.Y, alvo.Z) - pos).Magnitude < 1 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, Vector3.new(alvo.X, pos.Y, alvo.Z))
end

-- AJUSTE7: microdetalhes sem colisão que pesam no celular. Feito ao ligar o servidor (o mapa
-- original continua inteiro no arquivo do place): fica 1 de cada 3 lâminas de persiana por
-- janela; saem as juntas de revestimento e os reflexos finos; detalhes pequenos sem sombra.
local SEM_SOMBRA = {
	Trim = true, Detail = true, Hardware = true, Cable = true, Decor = true, GlassHighlight = true,
	RoadMarking = true, Crosswalk = true, RoadDetail = true, SidewalkDetail = true, SportMarking = true,
	Electrical = true, Lighting = true, Curtain = true, Goods = true, Prop = true,
}
function Mapa.simplificar(morioh: Instance): (number, number)
	local removidas, semSombra = 0, 0
	local persianas: { [Instance]: number } = {}
	for _, p in morioh:GetDescendants() do
		if p:IsA("BasePart") and not p.CanCollide and p.Parent then
			local nome = p.Name
			if nome == "Junta_Revestimento" or nome == "Reflexo_fino" then
				p:Destroy()
				removidas += 1
			elseif nome == "Lamina_Persiana" then
				local pai = p.Parent :: Instance
				local n = persianas[pai] or 0
				persianas[pai] = n + 1
				if n % 3 ~= 0 then
					p:Destroy()
					removidas += 1
				end
			elseif p.CastShadow and SEM_SOMBRA[p:GetAttribute("Role") or ""] then
				p.CastShadow = false
				semSombra += 1
			end
		end
	end
	return removidas, semSombra
end

local function construirMorioh(morioh: Instance)
	Mapa.modo = "morioh"
	local removidas, semSombra = Mapa.simplificar(morioh)
	workspace:SetAttribute("BB_MapaRemovidas", removidas)
	workspace:SetAttribute("BB_MapaSemSombra", semSombra)
	Mapa.pasta = morioh
	Mapa.pastaQuebravel = morioh
	-- quem está voando atravessa (e quebra) as paredes: grupo de colisão nas peças quebráveis
	-- (menos o que é chão: piso, escada, calçada... senão o corpo caído afunda)
	task.spawn(function()
		local n = 0
		for _, p in CollectionService:GetTagged("MoriohDestructible") do
			if p:IsA("BasePart") and not PISO[p:GetAttribute("Role") or ""] and p:IsDescendantOf(morioh) then
				p.CollisionGroup = Fisica.GRUPOS.quebravel
				n += 1
				if n % 4000 == 0 then
					task.wait()
				end
			end
		end
	end)
	spawnsProntos = {}
	for _, xz in SPAWNS_MORIOH do
		table.insert(spawnsProntos, cfNoChao(xz[1], 0, xz[2]))
	end
	local centroTreino = Vector3.new(-790, 0, 140)
	local bonecos = {}
	local s = TREINO_MORIOH.spawn
	for _, xz in TREINO_MORIOH.bonecos do
		table.insert(bonecos, cfNoChao(xz[1], 0.16, xz[2], Vector3.new(s[1], 0, s[2])))
	end
	treinoPronto = {
		centro = cfNoChao(centroTreino.X, 0.16, centroTreino.Z),
		bonecos = bonecos,
		spawn = cfNoChao(s[1], 0.16, s[2], centroTreino),
	}
end

function Mapa.construir(pai: Instance?, planoPronto: any?)
	local raiz = pai or workspace
	local morioh = if planoPronto then nil else raiz:FindFirstChild("Morioh")
	local temporarias = Instance.new("Folder")
	temporarias.Name = "BB_Temporarias"
	temporarias.Parent = raiz
	Mapa.pastaTemporarias = temporarias
	local pasta
	if morioh then
		construirMorioh(morioh)
		pasta = morioh
	else
		Mapa.modo = "plano"
		pasta = construirPlano(raiz, planoPronto)
	end
	paramsQuebravel.FilterDescendantsInstances = { Mapa.pasta :: Instance, temporarias }
	return pasta, plano
end

function Mapa.plano()
	return plano
end

-- o que os raios/caixas de cenário devem enxergar (chão, paredes e peças temporárias)
function Mapa.filtro(): { Instance }
	local l = {}
	if Mapa.pasta then
		table.insert(l, Mapa.pasta :: Instance)
	end
	if Mapa.pastaTemporarias then
		table.insert(l, Mapa.pastaTemporarias :: Instance)
	end
	return l
end

function Mapa.iniciar(efeito: RemoteEvent?)
	remoto = efeito
	RunService.Heartbeat:Connect(function()
		Mapa.passo()
	end)
end

function Mapa.ehQuebravel(parte: Instance): boolean
	if not parte:IsA("BasePart") then
		return false
	end
	if infos[parte :: BasePart] then
		return true
	end
	return ehDoMorioh(parte :: BasePart) and quebravelMorioh(parte :: BasePart)
end

function Mapa.estaQuebrada(parte: BasePart): boolean
	return quebradas[parte] == true
end

-------------------------------------------------------------------------------- quebrar / voltar
local function esconder(info: Info)
	local parte = info.parte
	if not info.orig then
		info.orig = { parte.Transparency, parte.CanCollide, parte.CanQuery, parte.CanTouch }
	end
	parte.Transparency = 1
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	for _, l in parte:GetChildren() do
		if l:IsA("Light") or l:IsA("SurfaceGui") then
			(l :: any).Enabled = false
		elseif l:IsA("Decal") then
			l.Transparency = 1
		end
	end
end

local function mostrar(info: Info)
	local parte = info.parte
	local o = info.orig
	if o then
		parte.Transparency = o[1]
		parte.CanCollide = o[2]
		parte.CanQuery = o[3]
		parte.CanTouch = o[4]
	end
	info.orig = nil
	for _, l in parte:GetChildren() do
		if l:IsA("Light") or l:IsA("SurfaceGui") then
			(l :: any).Enabled = true
		elseif l:IsA("Decal") then
			l.Transparency = 0
		end
	end
end

local function marcarQuebra(info: Info, dir: Vector3?, forca: number, t: number): boolean
	if info.quebrada then
		return false
	end
	info.quebrada = true
	info.vida = 0
	quebradas[info.parte] = true
	danificadas[info.parte] = nil
	info.volta = if info.temporaria then math.huge else t + Config.MAPA.regenerar + math.random() * Config.MAPA.regenerarVariacao
	esconder(info)
	table.insert(pendentesQuebra, { info.parte, dir or Vector3.zero, forca })
	return true
end

-- força (1 a 9) -> dano na peça
function Mapa.dano(forca: number): number
	local tabela = Config.MAPA.danoPorForca
	if forca <= 0 then
		return 0
	end
	local i = math.floor(forca)
	if i <= #tabela then
		local base = tabela[math.max(1, i)]
		local prox = tabela[math.min(#tabela, i + 1)]
		return base + (prox - base) * (forca - i)
	end
	return tabela[#tabela] + (forca - #tabela) * 200
end

-- tira vida de uma peça; quebra quando acaba. Devolve true se quebrou agora.
local function ferir(info: Info, dano: number, dir: Vector3?, forca: number, t: number): boolean
	if info.quebrada or dano <= 0 then
		return false
	end
	info.vida -= dano
	info.ultimoDano = t
	if info.vida > 0 then
		danificadas[info.parte] = true
		return false
	end
	local g = info.grupo
	if g and grupos[g] then
		for _, outra in grupos[g] do
			local io = infos[outra]
			if io then
				marcarQuebra(io, dir, forca, t)
			end
		end
		return true
	end
	return marcarQuebra(info, dir, forca, t)
end

-- quebra uma peça só (o projétil que bate numa parede, por exemplo)
function Mapa.quebrar(parte: BasePart, dir: Vector3?, forca: number?): boolean
	local info = infoDe(parte)
	if not info or info.quebrada then
		return false
	end
	local f = forca or 1
	return ferir(info, Mapa.dano(f), dir, f, agora())
end

local function ehPiso(p: BasePart): boolean
	return Mapa.modo == "morioh" and PISO[p:GetAttribute("Role") or ""] == true
end

-- aplica o dano nas peças achadas, das mais perto para as mais longe (máximo por impacto)
local function aplicar(achadas: { BasePart }, centro: Vector3, forca: number, dirFixa: Vector3?, raio: number?, soVidro: boolean?, semPiso: boolean?): number
	local lista = {}
	for _, p in achadas do
		local info = infoDe(p)
		if info and not info.quebrada and (not soVidro or info.vidro) and not (semPiso and ehPiso(p)) then
			table.insert(lista, { info, (p.CFrame.Position - centro).Magnitude })
		end
	end
	table.sort(lista, function(a, b)
		return a[2] < b[2]
	end)
	local maximo = Config.MAPA.maxPorImpacto or 40
	local dano = Mapa.dano(forca)
	local t = agora()
	local n = 0
	for i = 1, math.min(#lista, maximo) do
		local info, d = lista[i][1], lista[i][2]
		local dir = dirFixa
		if not dir then
			local v = info.parte.CFrame.Position - centro
			dir = if v.Magnitude > 0.1 then v.Unit else Vector3.new(0, 1, 0)
		end
		-- na borda da explosão o dano cai até a metade
		local mult = if raio and raio > 0 then 1 - 0.5 * math.clamp(d / raio, 0, 1) else 1
		local danoAqui = if soVidro then info.vida + 1 else dano * mult
		if ferir(info, danoAqui, dir, forca, t) then
			n += 1
		end
	end
	return n
end

-- semPiso: não quebra o chão (quem está deslizando ou levantando não abre buraco embaixo)
function Mapa.quebrarCaixa(cf: CFrame, tam: Vector3, forca: number, dir: Vector3?, semPiso: boolean?): number
	if forca <= 0 then
		return 0
	end
	local achadas = workspace:GetPartBoundsInBox(cf, tam, paramsQuebravel)
	return aplicar(achadas, cf.Position, forca, dir or cf.LookVector, nil, nil, semPiso)
end

-- a peça quebrável mais perto do centro da caixa (a Killer Queen transforma em bomba)
function Mapa.maisPerto(cf: CFrame, tam: Vector3): BasePart?
	local melhor, melhorD = nil, math.huge
	for _, p in workspace:GetPartBoundsInBox(cf, tam, paramsQuebravel) do
		local info = infoDe(p)
		if info and not info.quebrada and not ehPiso(p) then
			local d = (p.CFrame.Position - cf.Position).Magnitude
			if d < melhorD then
				melhor, melhorD = p, d
			end
		end
	end
	return melhor
end

function Mapa.quebrarArea(centro: Vector3, raio: number, forca: number, dir: Vector3?): number
	if forca <= 0 then
		return 0
	end
	local achadas = workspace:GetPartBoundsInRadius(centro, raio, paramsQuebravel)
	return aplicar(achadas, centro, forca, dir, raio)
end

-- só os vidros (onda de choque estoura as janelas em volta)
function Mapa.quebrarVidros(centro: Vector3, raio: number): number
	local achadas = workspace:GetPartBoundsInRadius(centro, raio, paramsQuebravel)
	return aplicar(achadas, centro, 1, nil, nil, true)
end

-- quantas peças quebradas existem perto (o Crazy Diamond usa isso)
function Mapa.quebradasPerto(pos: Vector3, raio: number): number
	local n = 0
	for parte in quebradas do
		if (parte.CFrame.Position - pos).Magnitude <= raio then
			n += 1
		end
	end
	return n
end

local function ocupada(info: Info): boolean
	local parte = info.parte
	local achados = workspace:GetPartBoundsInBox(parte.CFrame, parte.Size * 0.96, Hitbox.parametros())
	return #achados > 0
end

local function restaurar(info: Info, forcar: boolean?): boolean
	if not info.quebrada then
		return false
	end
	if not forcar and ocupada(info) then
		info.volta = agora() + 2
		return false
	end
	info.quebrada = false
	quebradas[info.parte] = nil
	mostrar(info)
	table.insert(pendentesVolta, info.parte)
	if info.temporaria then
		return true
	end
	if info.spec then
		info.vida = info.vidaMax -- cidade antiga: a peça fica guardada
	else
		infos[info.parte] = nil -- Morioh: esquece a peça (memória do servidor)
	end
	return true
end

-- reconstrói tudo num raio. Devolve as peças que voltaram.
function Mapa.restaurarPerto(pos: Vector3, raio: number, forcar: boolean?): { BasePart }
	local voltaram = {}
	local lista = {}
	for parte in quebradas do
		if (parte.CFrame.Position - pos).Magnitude <= raio then
			table.insert(lista, parte)
		end
	end
	for _, parte in lista do
		local info = infos[parte]
		if info and not info.temporaria and restaurar(info, forcar) then
			table.insert(voltaram, parte)
		end
	end
	-- o que só estava rachado também volta inteiro
	for parte in danificadas do
		if (parte.CFrame.Position - pos).Magnitude <= raio then
			local info = infos[parte]
			if info then
				info.vida = info.vidaMax
			end
		end
	end
	return voltaram
end

function Mapa.restaurarTudo(): number
	local lista = {}
	for parte in quebradas do
		table.insert(lista, parte)
	end
	local n = 0
	for _, parte in lista do
		local info = infos[parte]
		if info and not info.temporaria and restaurar(info, true) then
			n += 1
		end
	end
	return n
end

function Mapa.totalQuebradas(): number
	local n = 0
	for _ in quebradas do
		n += 1
	end
	return n
end

-- peças temporárias (paredão de pedra etc.): quebram mas não voltam
function Mapa.temporaria(spec: any, duracao: number): BasePart
	spec.q = true
	spec.k = "temporario"
	spec.id = -math.random(1, 1e9)
	local parte = criarParte(spec)
	parte:SetAttribute("BB_Q", nil)
	parte.Parent = Mapa.pastaTemporarias or Mapa.pastaQuebravel or workspace
	local info = infoPlano(parte, spec)
	info.temporaria = true
	info.grupo = nil
	infos[parte] = info
	task.delay(duracao, function()
		if infos[parte] then
			if not info.quebrada then
				marcarQuebra(info, Vector3.new(0, 1, 0), 1, agora())
			end
			task.delay(1, function()
				infos[parte] = nil
				quebradas[parte] = nil
				danificadas[parte] = nil
				parte:Destroy()
			end)
		end
	end)
	return parte
end

-- a cada quadro: manda os avisos de quebra/volta juntos e reconstrói o que deu o tempo
local acumulado = 0
function Mapa.passo()
	if #pendentesQuebra > 0 and remoto then
		local lote = pendentesQuebra
		pendentesQuebra = {}
		remoto:FireAllClients("quebra", { pecas = lote })
	end
	if #pendentesVolta > 0 and remoto then
		local lote = pendentesVolta
		pendentesVolta = {}
		remoto:FireAllClients("restaura", { pecas = lote })
	end
	acumulado += 1
	if acumulado % 15 ~= 0 then
		return
	end
	local t = agora()
	-- rachadas que ninguém mais bateu saram sozinhas
	local saradas = {}
	for parte in danificadas do
		local info = infos[parte]
		if not info or info.quebrada then
			table.insert(saradas, parte)
		elseif t - info.ultimoDano > Config.MAPA.regenerar then
			info.vida = info.vidaMax
			table.insert(saradas, parte)
			if not info.spec and not info.temporaria then
				infos[parte] = nil
			end
		end
	end
	for _, parte in saradas do
		danificadas[parte] = nil
	end
	local prontas = {}
	for parte in quebradas do
		local info = infos[parte]
		if info and not info.temporaria and t >= info.volta then
			table.insert(prontas, info)
		end
	end
	for _, info in prontas do
		if info.quebrada then
			local g = info.grupo
			if g and grupos[g] then
				-- grupo inteiro volta junto (carro, árvore, poste)
				local livre = true
				for _, outra in grupos[g] do
					local io = infos[outra]
					if io and io.quebrada and ocupada(io) then
						livre = false
					end
				end
				for _, outra in grupos[g] do
					local io = infos[outra]
					if io then
						if livre then
							restaurar(io, true)
						else
							io.volta = t + 2
						end
					end
				end
			else
				restaurar(info, false)
			end
		end
	end
end

-- quem está voando quebra o que atravessar
function Mapa.atravessar(lut: any, forca: number)
	local raiz = lut.raiz
	local vel = raiz.AssemblyLinearVelocity
	if vel.Magnitude < 22 then
		return 0
	end
	local cf = CFrame.lookAt(raiz.Position, raiz.Position + vel.Unit)
	-- força mínima 3: atravessar uma parede de concreto sem quebrar ficaria estranho
	return Mapa.quebrarCaixa(cf * CFrame.new(0, 0, -1), Vector3.new(5, 6.5, 6), math.max(forca, 3), vel.Unit, true)
end

function Mapa.spawns(): { CFrame }
	return spawnsProntos
end

function Mapa.treino()
	return treinoPronto
end

return Mapa
