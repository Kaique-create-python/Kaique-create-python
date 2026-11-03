-- BIZARRE BATTLEGROUNDS :: a cidade quebrável (monta, quebra e reconstrói sozinha)
-- Quebrar = a peça some (fica invisível e sem colisão) e os celulares soltam os destroços.
-- Depois de um tempo ela volta (se ninguém estiver no lugar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Plano = require(BB:WaitForChild("Mapa"):WaitForChild("Plano"))
local Fisica = require(script.Parent.Fisica)
local Hitbox = require(script.Parent.Hitbox)

local Mapa = {}

-- força mínima para quebrar cada tipo de peça
Mapa.RESISTENCIA = { vidro = 1, adereco = 1, parede = 2, carro = 2, estatua = 3, temporario = 1 }

local pecas: { [number]: any } = {}
local porParte: { [BasePart]: number } = {}
local grupos: { [number]: { number } } = {}
local quebradas: { [number]: boolean } = {}
local pendentesQuebra: { any } = {}
local pendentesVolta: { BasePart } = {}
local remoto: RemoteEvent? = nil
local plano: any = nil
Mapa.pasta = nil :: Folder?
Mapa.pastaQuebravel = nil :: Folder?

local paramsQuebravel = OverlapParams.new()
paramsQuebravel.FilterType = Enum.RaycastFilterType.Include
paramsQuebravel.MaxParts = 300

local function agora(): number
	return workspace:GetServerTimeNow()
end

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

function Mapa.construir(pai: Instance?, planoPronto: any?)
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
			pecas[p.id] = { spec = p, parte = parte, volta = 0 }
			porParte[parte] = p.id
			if p.g then
				grupos[p.g] = grupos[p.g] or {}
				table.insert(grupos[p.g], p.id)
			end
		else
			parte.Parent = fixas
		end
	end
	pasta.Parent = pai or workspace
	Mapa.pasta = pasta
	Mapa.pastaQuebravel = quebraveis
	paramsQuebravel.FilterDescendantsInstances = { quebraveis }
	return pasta, plano
end

function Mapa.plano()
	return plano
end

function Mapa.iniciar(efeito: RemoteEvent?)
	remoto = efeito
	RunService.Heartbeat:Connect(function()
		Mapa.passo()
	end)
end

function Mapa.ehQuebravel(parte: Instance): boolean
	return parte:IsA("BasePart") and porParte[parte :: BasePart] ~= nil
end

function Mapa.estaQuebrada(parte: BasePart): boolean
	local id = porParte[parte]
	return id ~= nil and quebradas[id] == true
end

local function esconder(info: any)
	local parte = info.parte
	parte.Transparency = 1
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	for _, l in parte:GetChildren() do
		if l:IsA("Light") or l:IsA("SurfaceGui") then
			(l :: any).Enabled = false
		end
	end
end

local function mostrar(info: any)
	local parte = info.parte
	local p = info.spec
	parte.Transparency = p.t or 0
	parte.CanCollide = not p.semColisao
	parte.CanQuery = true
	parte.CanTouch = true
	for _, l in parte:GetChildren() do
		if l:IsA("Light") or l:IsA("SurfaceGui") then
			(l :: any).Enabled = true
		end
	end
end

local function marcarQuebra(id: number, dir: Vector3?, forca: number, t: number)
	local info = pecas[id]
	if not info or quebradas[id] then
		return false
	end
	quebradas[id] = true
	info.volta = t + Config.MAPA.regenerar + math.random() * Config.MAPA.regenerarVariacao
	esconder(info)
	table.insert(pendentesQuebra, { info.parte, dir or Vector3.zero, forca })
	return true
end

-- quebra uma peça (e o grupo dela, se for carro/árvore/poste...)
function Mapa.quebrar(parte: BasePart, dir: Vector3?, forca: number?): boolean
	local id = porParte[parte]
	if not id or quebradas[id] then
		return false
	end
	local info = pecas[id]
	local f = forca or 1
	local precisa = Mapa.RESISTENCIA[info.spec.k] or 1
	if f < precisa then
		return false
	end
	local t = agora()
	local g = info.spec.g
	if g and grupos[g] then
		for _, outro in grupos[g] do
			marcarQuebra(outro, dir, f, t)
		end
		return true
	end
	return marcarQuebra(id, dir, f, t)
end

function Mapa.quebrarCaixa(cf: CFrame, tam: Vector3, forca: number, dir: Vector3?): number
	if forca <= 0 then
		return 0
	end
	local n = 0
	for _, p in workspace:GetPartBoundsInBox(cf, tam, paramsQuebravel) do
		if Mapa.quebrar(p, dir or cf.LookVector, forca) then
			n += 1
		end
	end
	return n
end

function Mapa.quebrarArea(centro: Vector3, raio: number, forca: number, dir: Vector3?): number
	if forca <= 0 then
		return 0
	end
	local n = 0
	for _, p in workspace:GetPartBoundsInRadius(centro, raio, paramsQuebravel) do
		local d = dir
		if not d then
			local v = p.Position - centro
			d = if v.Magnitude > 0.1 then v.Unit else Vector3.new(0, 1, 0)
		end
		if Mapa.quebrar(p, d, forca) then
			n += 1
		end
	end
	return n
end

-- só os vidros (o grave do FUNK estoura as janelas em volta)
function Mapa.quebrarVidros(centro: Vector3, raio: number): number
	local n = 0
	for _, p in workspace:GetPartBoundsInRadius(centro, raio, paramsQuebravel) do
		local id = porParte[p]
		if id and pecas[id].spec.k == "vidro" then
			local v = p.Position - centro
			if Mapa.quebrar(p, if v.Magnitude > 0.1 then v.Unit else nil, 1) then
				n += 1
			end
		end
	end
	return n
end

-- quantas peças quebradas existem perto (o CHORINHO usa isso)
function Mapa.quebradasPerto(pos: Vector3, raio: number): number
	local n = 0
	for id in quebradas do
		local info = pecas[id]
		if info and (info.parte.Position - pos).Magnitude <= raio then
			n += 1
		end
	end
	return n
end

local function ocupada(info: any): boolean
	local parte = info.parte
	local achados = workspace:GetPartBoundsInBox(parte.CFrame, parte.Size * 0.96, Hitbox.parametros())
	return #achados > 0
end

local function restaurarId(id: number, forcar: boolean?): boolean
	local info = pecas[id]
	if not info or not quebradas[id] then
		return false
	end
	if not forcar and ocupada(info) then
		info.volta = agora() + 2
		return false
	end
	quebradas[id] = nil
	mostrar(info)
	table.insert(pendentesVolta, info.parte)
	return true
end

-- reconstrói tudo num raio. Devolve as peças que voltaram.
function Mapa.restaurarPerto(pos: Vector3, raio: number, forcar: boolean?): { BasePart }
	local voltaram = {}
	local ids = {}
	for id in quebradas do
		local info = pecas[id]
		if info and (info.parte.Position - pos).Magnitude <= raio then
			table.insert(ids, id)
		end
	end
	for _, id in ids do
		if restaurarId(id, forcar) then
			table.insert(voltaram, pecas[id].parte)
		end
	end
	return voltaram
end

function Mapa.restaurarTudo(): number
	local ids = {}
	for id in quebradas do
		table.insert(ids, id)
	end
	local n = 0
	for _, id in ids do
		if restaurarId(id, true) then
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

-- peças temporárias (paredão de caixas de som etc.): quebram mas não voltam
function Mapa.temporaria(spec: any, duracao: number): BasePart
	spec.q = true
	spec.k = "temporario"
	spec.id = -(#pendentesQuebra + math.random(1, 1e6))
	local parte = criarParte(spec)
	parte:SetAttribute("BB_Q", nil)
	parte.Parent = Mapa.pastaQuebravel
	local id = spec.id
	pecas[id] = { spec = spec, parte = parte, volta = math.huge, temporaria = true }
	porParte[parte] = id
	task.delay(duracao, function()
		if pecas[id] then
			if not quebradas[id] then
				marcarQuebra(id, Vector3.new(0, 1, 0), 1, agora())
			end
			pecas[id].volta = math.huge
			task.delay(1, function()
				porParte[parte] = nil
				pecas[id] = nil
				quebradas[id] = nil
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
	for id in quebradas do
		local info = pecas[id]
		if info and not info.temporaria and t >= info.volta then
			-- grupo inteiro volta junto
			local g = info.spec.g
			if g and grupos[g] then
				local livre = true
				for _, outro in grupos[g] do
					if quebradas[outro] and ocupada(pecas[outro]) then
						livre = false
					end
				end
				if livre then
					for _, outro in grupos[g] do
						restaurarId(outro, true)
					end
				else
					for _, outro in grupos[g] do
						if pecas[outro] then
							pecas[outro].volta = t + 2
						end
					end
				end
			else
				restaurarId(id, false)
			end
		end
	end
end

-- quem está voando quebra o que atravessar
local paramsVoo = OverlapParams.new()
function Mapa.atravessar(lut: any, forca: number)
	local raiz = lut.raiz
	local vel = raiz.AssemblyLinearVelocity
	if vel.Magnitude < 22 then
		return 0
	end
	local _ = paramsVoo
	local cf = CFrame.lookAt(raiz.Position, raiz.Position + vel.Unit)
	return Mapa.quebrarCaixa(cf * CFrame.new(0, 0, -1), Vector3.new(5, 6.5, 6), forca, vel.Unit)
end

function Mapa.spawns(): { CFrame }
	return if plano then plano.spawns else {}
end

function Mapa.treino()
	return if plano then plano.treino else nil
end

return Mapa
