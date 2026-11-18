-- Roda o Criatura.luau INTEIRO (carregar, rondar, ver, rugir, perseguir, bote e garra) no Lune,
-- com o mapa Sector7World de verdade (raycast em caixas orientadas), jogadores falsos que andam
-- ou correm por rotas e animações falsas que disparam os marcadores nos tempos do catálogo.
-- Uso: lune run sim_criatura.luau <Criatura.luau> <CriaturaCore.luau> <MonsterCatalog.luau> <place.rbxl> <cenario>
-- Cenários: anda | corre | oficina | dois
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local V3, CF = roblox.Vector3, roblox.CFrame
local Enum = roblox.Enum

local ARQ_CRIATURA, ARQ_CORE, ARQ_CATALOGO, ARQ_PLACE, CENARIO = table.unpack(process.args)
assert(ARQ_PLACE, "uso: sim_criatura.luau Criatura Core Catalogo place cenario")
CENARIO = CENARIO or "anda"

local relogio = 1000
local avisos = {}

-- ===== mapa real e raycast em caixas orientadas (com grade para ficar rápido) =====
local place = roblox.deserializePlace(fs.readFile(ARQ_PLACE))
local mapa = place:GetService("Workspace"):FindFirstChild("Sector7World")
assert(mapa, "place sem Sector7World")
local pecas = {}
local G = 16
local grade = {}
local function chave(ix, iz) return ix * 100003 + iz end
for _, d in mapa:GetDescendants() do
	if d:IsA("BasePart") and d.CanQuery ~= false then
		local cf, h = d.CFrame, d.Size / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = V3.new(
			math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
			math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
			math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z)
		local p = cf.Position
		local item = { parte = d, cf = cf, meia = h, min = p - ext, max = p + ext, colide = d.CanCollide }
		table.insert(pecas, item)
		local i = #pecas
		for ix = math.floor(item.min.X / G), math.floor(item.max.X / G) do
			for iz = math.floor(item.min.Z / G), math.floor(item.max.Z / G) do
				local k = chave(ix, iz)
				grade[k] = grade[k] or {}
				table.insert(grade[k], i)
			end
		end
	end
end

local function candidatas(minX, maxX, minZ, maxZ)
	local vistos, lista = {}, {}
	for ix = math.floor(minX / G), math.floor(maxX / G) do
		for iz = math.floor(minZ / G), math.floor(maxZ / G) do
			for _, i in grade[chave(ix, iz)] or {} do
				if not vistos[i] then vistos[i] = true; table.insert(lista, i) end
			end
		end
	end
	return lista
end

local function raioCaixa(origem, dir, item)
	local cf, h = item.cf, item.meia
	local o = cf:PointToObjectSpace(origem)
	local d = cf:VectorToObjectSpace(dir)
	local t0, t1 = -math.huge, math.huge
	local eixo0, sinal0 = nil, 0
	for _, eixo in { "X", "Y", "Z" } do
		local oo, dd, hh = o[eixo], d[eixo], h[eixo]
		if math.abs(dd) < 1e-9 then
			if oo < -hh or oo > hh then return nil end
		else
			local a, b = (-hh - oo) / dd, (hh - oo) / dd
			local s = -1
			if a > b then a, b = b, a; s = 1 end
			if a > t0 then t0, eixo0, sinal0 = a, eixo, s end
			t1 = math.min(t1, b)
			if t0 > t1 then return nil end
		end
	end
	if t0 < 0 or t0 > 1 or not eixo0 then return nil end -- começa dentro: o Roblox não acerta essa peça
	local n = V3.new(if eixo0 == "X" then sinal0 else 0, if eixo0 == "Y" then sinal0 else 0, if eixo0 == "Z" then sinal0 else 0)
	return t0, cf:VectorToWorldSpace(n)
end

local dados = setmetatable({}, { __mode = "k" })
local function eFalso(x) return type(x) == "table" and dados[x] ~= nil end

local function raycast(origem, dir, params)
	params = params or {}
	local lista = params.FilterDescendantsInstances or {}
	local reais = {}
	for _, x in lista do if typeof(x) == "Instance" then table.insert(reais, x) end end
	local incluir = params.FilterType == Enum.RaycastFilterType.Include
	if incluir and #reais == 0 then return nil end
	local fim = origem + dir
	local cand = candidatas(math.min(origem.X, fim.X), math.max(origem.X, fim.X), math.min(origem.Z, fim.Z), math.max(origem.Z, fim.Z))
	local melhor, achado, normal = math.huge, nil, nil
	local yMin, yMax = math.min(origem.Y, fim.Y), math.max(origem.Y, fim.Y)
	for _, i in cand do
		local item = pecas[i]
		if item.max.Y >= yMin and item.min.Y <= yMax and (not params.RespectCanCollide or item.colide) then
			local ok = true
			if incluir then
				ok = false
				for _, x in reais do if item.parte == x or item.parte:IsDescendantOf(x) then ok = true; break end end
			else
				for _, x in reais do if item.parte == x or item.parte:IsDescendantOf(x) then ok = false; break end end
			end
			if ok then
				local t, n = raioCaixa(origem, dir, item)
				if t and t < melhor then melhor, achado, normal = t, item, n end
			end
		end
	end
	if not achado then return nil end
	local parte = achado.parte
	local embrulho = {
		Name = parte.Name, Material = parte.Material,
		IsDescendantOf = function(_, x) if eFalso(x) then return false end return parte:IsDescendantOf(x) end,
	}
	return { Instance = embrulho, Position = origem + dir * melhor, Normal = normal, Material = parte.Material }
end

-- OBB x OBB (eixos separadores) para GetPartBoundsInBox
local function sobrepoe(cfA, hA, item)
	local eixosA = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local cfB, hB = item.cf, item.meia
	local eixosB = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local mA, mB = { hA.X, hA.Y, hA.Z }, { hB.X, hB.Y, hB.Z }
	local t = cfB.Position - cfA.Position
	local testes = {}
	for _, a in eixosA do table.insert(testes, a) end
	for _, b in eixosB do table.insert(testes, b) end
	for _, a in eixosA do for _, b in eixosB do
		local c = a:Cross(b)
		if c.Magnitude > 1e-6 then table.insert(testes, c.Unit) end
	end end
	for _, L in testes do
		local ra, rb = 0, 0
		for i = 1, 3 do ra += mA[i] * math.abs(eixosA[i]:Dot(L)); rb += mB[i] * math.abs(eixosB[i]:Dot(L)) end
		if math.abs(t:Dot(L)) > ra + rb then return false end
	end
	return true
end
local function partesNaCaixa(cf, tamanho, params)
	params = params or {}
	local h = tamanho / 2
	local p = cf.Position
	local res = {}
	for _, i in candidatas(p.X - h.X - 1, p.X + h.X + 1, p.Z - h.Z - 1, p.Z + h.Z + 1) do
		local item = pecas[i]
		if (not params.RespectCanCollide or item.colide) and item.max.Y >= p.Y - h.Y and item.min.Y <= p.Y + h.Y then
			if sobrepoe(cf, h, item) then
				table.insert(res, item.parte)
				if params.MaxParts and params.MaxParts > 0 and #res >= params.MaxParts then break end
			end
		end
	end
	return res
end

-- ===== objetos falsos (o mínimo de Instance que o Criatura usa) =====
local function sinal()
	local ls = {}
	local s = {}
	function s:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect() self.Connected = false end
		table.insert(ls, { fn, c })
		return c
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...) c:Disconnect(); fn(...) end)
		return c
	end
	function s:Fire(...)
		for _, l in table.clone(ls) do if l[2].Connected then l[1](...) end end
	end
	return s
end

local HERANCA = {
	Part = { BasePart = true, PVInstance = true }, MeshPart = { BasePart = true, PVInstance = true },
	Model = { PVInstance = true }, Workspace = { Model = true, PVInstance = true },
	ModuleScript = { LuaSourceContainer = true },
}
local Metodos = {}
local MT = {}
local mapaFalsoWorkspace = nil
local function novo(classe, props)
	local obj = {}
	dados[obj] = { classe = classe, props = { Name = classe }, filhos = {}, attrs = {}, sinaisAttr = {}, pai = nil }
	setmetatable(obj, MT)
	if classe == "Humanoid" then obj.MaxHealth = 100; obj.Health = 100 end
	for k, v in props or {} do obj[k] = v end
	return obj
end
MT.__index = function(obj, k)
	local d = dados[obj]
	if k == "Parent" then return d.pai end
	if k == "ClassName" then return d.classe end
	if k == "Position" then local cf = d.props.CFrame; return if cf then cf.Position else nil end
	local m = Metodos[k]
	if m then return m end
	return d.props[k]
end
MT.__newindex = function(obj, k, v)
	local d = dados[obj]
	if k == "Parent" then
		if d.pai then
			local irmaos = dados[d.pai].filhos
			local i = table.find(irmaos, obj)
			if i then table.remove(irmaos, i) end
		end
		d.pai = v
		if v then table.insert(dados[v].filhos, obj) end
		return
	end
	if k == "Position" then
		local cf = d.props.CFrame or CF.new()
		d.props.CFrame = cf - cf.Position + v
		return
	end
	d.props[k] = v
end
MT.__tostring = function(obj) return dados[obj].props.Name end

local function isA(obj, classe)
	local c = dados[obj].classe
	return classe == "Instance" or c == classe or (HERANCA[c] ~= nil and HERANCA[c][classe] == true)
end
function Metodos.IsA(self, classe) return isA(self, classe) end
function Metodos.GetChildren(self) return table.clone(dados[self].filhos) end
function Metodos.GetDescendants(self)
	local r = {}
	local function andar(o) for _, f in dados[o].filhos do table.insert(r, f); andar(f) end end
	andar(self)
	return r
end
function Metodos.FindFirstChild(self, nome, recursivo)
	if dados[self].classe == "Workspace" and nome == "Sector7World" then return mapa end
	local lista = if recursivo then Metodos.GetDescendants(self) else dados[self].filhos
	for _, f in lista do if f.Name == nome then return f end end
	return nil
end
function Metodos.WaitForChild(self, nome) return Metodos.FindFirstChild(self, nome) end
function Metodos.FindFirstChildWhichIsA(self, classe, recursivo)
	local lista = if recursivo then Metodos.GetDescendants(self) else dados[self].filhos
	for _, f in lista do if isA(f, classe) then return f end end
	return nil
end
function Metodos.FindFirstChildOfClass(self, classe)
	for _, f in dados[self].filhos do if dados[f].classe == classe then return f end end
	return nil
end
function Metodos.IsDescendantOf(self, anc)
	local p = dados[self].pai
	while p do
		if p == anc then return true end
		p = dados[p].pai
	end
	return false
end
function Metodos.Destroy(self)
	for _, f in table.clone(dados[self].filhos) do Metodos.Destroy(f) end
	self.Parent = nil
	dados[self].destruido = true
end
function Metodos.GetFullName(self)
	local n, p = self.Name, dados[self].pai
	while p do n = p.Name .. "." .. n; p = dados[p].pai end
	return n
end
function Metodos.SetAttribute(self, k, v)
	local d = dados[self]
	if d.attrs[k] == v then return end
	d.attrs[k] = v
	if d.sinaisAttr[k] then d.sinaisAttr[k]:Fire() end
end
function Metodos.GetAttribute(self, k) return dados[self].attrs[k] end
function Metodos.GetAttributeChangedSignal(self, k)
	local d = dados[self]
	d.sinaisAttr[k] = d.sinaisAttr[k] or sinal()
	return d.sinaisAttr[k]
end
function Metodos.PivotTo(self, cf)
	dados[self].props.pivo = cf
	local primaria = self.PrimaryPart
	if primaria then primaria.CFrame = cf end
end
function Metodos.GetPivot(self) return dados[self].props.pivo or CF.new() end
function Metodos.MoveTo() end
function Metodos.TakeDamage(self, n) self.Health = math.max(0, (self.Health or 0) - n) end
function Metodos.Raycast(_, origem, dir, params) return raycast(origem, dir, params) end
function Metodos.GetPartBoundsInBox(_, cf, tamanho, params) return partesNaCaixa(cf, tamanho, params) end

-- ===== animações falsas: tocam no relógio da simulação e disparam os marcadores =====
local catalogo = luau.load(fs.readFile(ARQ_CATALOGO))()
local trilhas = {}
function Metodos.LoadAnimation(_, animacao)
	local nome = animacao.Name
	local clip = assert(catalogo.animations[nome], "animação fora do catálogo: " .. tostring(nome))
	local t = { Length = clip.duration, IsPlaying = false, Looped = false, TimePosition = 0, Speed = 1,
		nome = nome, clip = clip, marcadores = {}, Stopped = sinal() }
	function t:Play(_, _, velocidade) self.IsPlaying = true; self.TimePosition = 0; self.Speed = velocidade or 1 end
	function t:Stop() if self.IsPlaying then self.IsPlaying = false; self.Stopped:Fire() end end
	function t:AdjustSpeed(v) self.Speed = v end
	function t:Destroy() self.destruida = true; self.IsPlaying = false end
	function t:GetMarkerReachedSignal(n)
		self.marcadores[n] = self.marcadores[n] or sinal()
		return self.marcadores[n]
	end
	table.insert(trilhas, t)
	return t
end
local function avancarTrilhas(dt)
	for _, t in trilhas do
		if t.IsPlaying and not t.destruida then
			local antes = t.TimePosition
			local depois = antes + dt * t.Speed
			local function disparar(de, ate)
				for _, m in t.clip.markers or {} do
					if m.time > de and m.time <= ate and t.marcadores[m.name] then t.marcadores[m.name]:Fire(m.value) end
				end
			end
			disparar(antes, math.min(depois, t.Length))
			if depois >= t.Length then
				if t.Looped then
					depois -= t.Length
					disparar(-1, depois)
				else
					t.TimePosition = t.Length
					t.IsPlaying = false
					t.Stopped:Fire()
					continue
				end
			end
			t.TimePosition = depois
		end
	end
end

-- ===== serviços e ambiente =====
local Workspace = novo("Workspace", { Name = "Workspace" })
mapaFalsoWorkspace = Workspace
local historia = novo("Folder", { Name = "BastiaoHistoria" }); historia.Parent = Workspace
local Players = { Name = "Players" }
local jogadores = {}
function Players:GetPlayers() return table.clone(jogadores) end
function Players:GetPlayerByUserId(id) for _, p in jogadores do if p.UserId == id then return p end end return nil end
local Heartbeat = sinal()
local servicos = {
	Players = Players, Workspace = Workspace, RunService = { Heartbeat = Heartbeat },
	AssetService = { LoadAssetAsync = function()
		local m = novo("Model", { Name = "Monster" })
		local h = catalogo.heightStuds
		local mesh = novo("MeshPart", { Name = catalogo.meshName or "Mesh", Size = V3.new(6, h, 4),
			CFrame = CF.new(0, h / 2, 0), MeshId = "rbxassetid://1", Transparency = 0 })
		mesh.Parent = m
		return m
	end },
	ContentProvider = { PreloadAsync = function(_, lista, cb)
		if cb then for _, a in lista do cb(a, Enum.AssetFetchStatus.Success) end end
	end },
	PathfindingService = { CreatePath = function() error("o andar novo não deve usar pathfinding") end },
}
local game = { GetService = function(_, n) return assert(servicos[n], "serviço não simulado: " .. n) end }

local CoreReal = luau.load(fs.readFile(ARQ_CORE), { debugName = "CriaturaCore" })()
local Core = setmetatable({
	inspectRig = function(model, h)
		local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
		if not mesh then return nil, "sem_mesh" end
		return { parts = { mesh }, meshes = { mesh }, width = 6, height = h, depth = 4,
			centerX = 0, centerY = h / 2, centerZ = 0 }, nil
	end,
}, { __index = CoreReal })
local Contrato = {
	VisualFacingYawDegrees = 180,
	Prepare = function() return { ok = true, errors = {}, maxRestPositionErrorStuds = 0, importYawDegrees = 0 } end,
}
local servidor = novo("Folder", { Name = "BastiaoServidor" })
local mCore = novo("ModuleScript", { Name = "CriaturaCore" }); mCore.Parent = servidor
local mContrato = novo("ModuleScript", { Name = "MonsterImportContract" }); mContrato.Parent = servidor
local mCriatura = novo("ModuleScript", { Name = "Criatura" }); mCriatura.Parent = servidor
local compartilhado = novo("Folder", { Name = "BastiaoCompartilhado" })
local mCatalogo = novo("ModuleScript", { Name = "MonsterCatalog" }); mCatalogo.Parent = compartilhado
local valores = { [mCore] = Core, [mContrato] = Contrato, [mCatalogo] = catalogo }

local env = {
	game = game, workspace = Workspace, script = mCriatura,
	require = function(m) return assert(valores[m], "require desconhecido: " .. tostring(m)) end,
	Instance = { new = function(classe) return novo(classe) end },
	typeof = function(x) if eFalso(x) then return "Instance" end return typeof(x) end,
	Vector3 = V3, CFrame = CF, Enum = Enum, UDim2 = roblox.UDim2, Color3 = roblox.Color3,
	RaycastParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude } end },
	OverlapParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude } end },
	task = {
		spawn = function(fn, ...) fn(...) return nil end,
		defer = function(fn, ...) fn(...) return nil end,
		wait = function(t) relogio += (t or 1 / 60); return t or 1 / 60 end,
		delay = function() return nil end,
	},
	os = { clock = function() return relogio end, time = os.time },
	warn = function(...)
		local partes = {}
		for _, x in { ... } do table.insert(partes, tostring(x)) end
		table.insert(avisos, table.concat(partes, " "))
	end,
	print = print, tostring = tostring, tonumber = tonumber, type = type, pairs = pairs, ipairs = ipairs,
	next = next, select = select, pcall = pcall, xpcall = xpcall, error = error, assert = assert,
	setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
	math = math, table = table, string = string, utf8 = utf8,
}
local Criatura = luau.load(fs.readFile(ARQ_CRIATURA), { debugName = "Criatura", environment = env, injectGlobals = false })()

-- ===== jogadores falsos com rota =====
local function chaoEm(x, z)
	local p = { RespectCanCollide = true, FilterType = Enum.RaycastFilterType.Include, FilterDescendantsInstances = { mapa } }
	local hit = raycast(V3.new(x, 6, z), V3.new(0, -14, 0), p)
	return if hit then hit.Position.Y else 0
end
local function novoJogador(id, x, z, olhar)
	local char = novo("Model", { Name = "Jogador" .. id })
	local y = chaoEm(x, z) + 3
	local root = novo("Part", { Name = "HumanoidRootPart", Size = V3.new(2, 2, 1),
		CFrame = CF.lookAt(V3.new(x, y, z), V3.new(x + olhar.X, y, z + olhar.Z)), AssemblyLinearVelocity = V3.zero })
	root.Parent = char
	local hum = novo("Humanoid", { FloorMaterial = Enum.Material.Concrete })
	hum.Parent = char
	char.Parent = Workspace
	local attrs = {}
	local j = { Name = "Jogador" .. id, UserId = id, Character = char, Parent = Players, rota = {}, i = 1,
		folego = 6, root = root, hum = hum }
	function j:GetAttribute(k) return attrs[k] end
	function j:SetAttribute(k, v) attrs[k] = v end
	table.insert(jogadores, j)
	return j
end
local function moverJogador(j, dt)
	local alvo = j.rota[j.i]
	if not alvo or j.hum.Health <= 0 or j.root.Anchored == true then
		j.root.AssemblyLinearVelocity = V3.zero
		j:SetAttribute("Sprinting", false)
		return
	end
	local pos = j.root.CFrame.Position
	local plano = V3.new(alvo.X - pos.X, 0, alvo.Z - pos.Z)
	local correr = alvo.correr == true and j.folego > 0
	local vel = if correr then 18 else 10
	if correr then j.folego -= dt else j.folego = math.min(6, j.folego + dt * 0.3) end
	j:SetAttribute("Sprinting", correr)
	if plano.Magnitude < 0.5 then j.i += 1; return end
	local passo = math.min(plano.Magnitude, vel * dt)
	local nova = pos + plano.Unit * passo
	local y = chaoEm(nova.X, nova.Z) + 3
	nova = V3.new(nova.X, y, nova.Z)
	j.root.CFrame = CF.lookAt(nova, nova + plano.Unit)
	j.root.AssemblyLinearVelocity = plano.Unit * vel
end

-- ===== eixo dos corredores (mesmo do Criatura) para medir o quanto sai do eixo =====
local NODES = {
	V3.new(0,0,-260), V3.new(-58,0,-260), V3.new(58,0,-260),
	V3.new(0,0,-300), V3.new(0,0,-360), V3.new(0,0,-400), V3.new(0,0,-440),
	V3.new(-58,0,-440), V3.new(58,0,-440),
	V3.new(58,0,-300), V3.new(58,0,-338), V3.new(58,0,-400),
	V3.new(-58,0,-300), V3.new(-58,0,-338), V3.new(-58,0,-400),
}
local EDGES = {{1,2},{1,3},{1,4},{4,5},{5,6},{6,7},{7,8},{7,9},{3,10},{10,11},{11,12},{12,9},{2,13},{13,14},{14,15},{15,8}}
local function foraDoEixo(p)
	local q, melhor = V3.new(p.X, 0, p.Z), math.huge
	for _, e in EDGES do
		local a, b = NODES[e[1]], NODES[e[2]]
		local ab = b - a
		local t = math.clamp((q - a):Dot(ab) / ab:Dot(ab), 0, 1)
		melhor = math.min(melhor, (q - (a + ab * t)).Magnitude)
	end
	return melhor
end

-- ===== cenário =====
local function P(x, z, correr) return { X = x, Z = z, correr = correr } end
local FUGA = { P(0, -260), P(58, -260), P(58, -320), P(82, -320) } -- até dentro da oficina
local SUL = { P(58, -440), P(0, -440), P(0, -300), P(0, -260), P(-58, -260), P(-58, -440) }
local function correndo(rota)
	local r = {}
	for _, p in rota do table.insert(r, P(p.X, p.Z, true)) end
	return r
end
local duracao, reacao, gatilho, perto = 75, 0.6, "ver", 28
local reagiuEm = nil
local espera = {} -- o que cada cenário precisa ver acontecer
local j1, j2
if CENARIO == "anda" then
	-- parado olhando o monstro chegar; foge andando quando ele chega perto perseguindo
	j1 = novoJogador(101, 0, -300, V3.new(0, 0, -1))
	gatilho, espera = "perto", { chase = true, bote = true, captura = true }
elseif CENARIO == "corre" then
	j1 = novoJogador(101, 0, -300, V3.new(0, 0, -1))
	gatilho, espera = "perto", { chase = true }
	FUGA = correndo(FUGA)
elseif CENARIO == "foge_sul" then
	-- é visto de perto no anel leste e foge andando para longe da oficina
	j1 = novoJogador(101, 58, -300, V3.new(0, 0, 1))
	FUGA, espera = SUL, { chase = true, bote = true }
elseif CENARIO == "corre_sul" then
	j1 = novoJogador(101, 58, -300, V3.new(0, 0, 1))
	FUGA, espera = correndo(SUL), { chase = true }
elseif CENARIO == "oficina" then
	j1 = novoJogador(101, 58, -300, V3.new(0, 0, 1))
	FUGA = { P(58, -320), P(82, -320) }
	reacao = 0.3
	espera = { porta = true }
elseif CENARIO == "dois" then
	j1 = novoJogador(101, 0, -300, V3.new(0, 0, -1))
	j2 = novoJogador(202, -58, -300, V3.new(0, 0, 1))
	gatilho, espera = "perto", { chase = true }
else
	error("cenário desconhecido: " .. CENARIO)
end

local mundo = { estado = function(_, k) return if k == "porta_contencao" then "destravada" elseif k == "alarme" then "ligado" else nil end }
local api = Criatura.start({ world = historia, mundo = mundo, shared = compartilhado })

-- ===== laço =====
local dt = 1 / 60
local estados, ultimoEstado = {}, nil
local maxY, maxFora, entrouOficina, maxForaArea = 0, 0, false, false
local serialAtaque, serialGolpe, serialRugido, passos = 0, 0, 0, 0
local capturas, tocadas, ultimaAnim = 0, {}, nil
local presoDepois = false
local menorDist = math.huge
local fugiu = false
local t = 0
local altura = catalogo.heightStuds
local monstro = nil
local primeiroAtivo = nil
while t < duracao do
	t += dt
	relogio += dt
	local estadoM = monstro and monstro:GetAttribute("BastiaoState")
	local distM = monstro and monstro.PrimaryPart and (j1.root.CFrame.Position - monstro.PrimaryPart.CFrame.Position).Magnitude
	local viu = if gatilho == "ver" then (estadoM == "alert" or estadoM == "chase")
		else (estadoM == "chase" and distM ~= nil and distM < perto)
	if viu and not reagiuEm then reagiuEm = t end
	if not fugiu and ((reagiuEm and t >= reagiuEm + reacao) or t >= 40) then
		fugiu = true
		j1.rota = table.clone(FUGA)
		if j2 then j2.rota = { P(-58, -260), P(0, -260), P(58, -260), P(58, -320), P(82, -320) } end
	end
	for _, j in jogadores do moverJogador(j, dt) end
	avancarTrilhas(dt)
	Heartbeat:Fire(dt)
	local pasta = historia:FindFirstChild("Criatura")
	monstro = pasta and pasta:FindFirstChild("Bastiao731A")
	if monstro and monstro:GetAttribute("BastiaoReady") == true then
		primeiroAtivo = primeiroAtivo or t
		local root = monstro.PrimaryPart
		local pos = root.CFrame.Position
		local estado = monstro:GetAttribute("BastiaoState")
		if estado ~= ultimoEstado then
			table.insert(estados, string.format("%.1fs %s", t, tostring(estado)))
			ultimoEstado = estado
		end
		-- chão: o centro tem que ficar a altura/2 + 0.12 acima do chão do mapa
		local chao = chaoEm(pos.X, pos.Z)
		maxY = math.max(maxY, math.abs(pos.Y - (chao + altura / 2 + 0.12)))
		maxFora = math.max(maxFora, foraDoEixo(pos))
		local ponto = { x = pos.X, y = pos.Y, z = pos.Z }
		if CoreReal.inSafeZone(ponto) then entrouOficina = true end
		if not CoreReal.inEncounterArea(ponto) then maxForaArea = true end
		serialAtaque = monstro:GetAttribute("BastiaoAttackSerial") or serialAtaque
		serialGolpe = monstro:GetAttribute("BastiaoHitSerial") or serialGolpe
		serialRugido = monstro:GetAttribute("BastiaoRoarSerial") or serialRugido
		capturas = monstro:GetAttribute("BastiaoCapturaSerial") or capturas
		local anim = monstro:GetAttribute("BastiaoAnimation")
		if anim and anim ~= ultimaAnim then tocadas[anim] = (tocadas[anim] or 0) + 1; ultimaAnim = anim end
		if capturas > 0 and estado ~= "capture" and j1.root.Anchored == true and j1.hum.Health <= 0 then presoDepois = true end
		if monstro:GetAttribute("BastiaoMarkerName") and string.sub(monstro:GetAttribute("BastiaoMarkerName"), 1, 4) == "Foot" then
			passos = monstro:GetAttribute("BastiaoMarkerSerial") or passos
		end
		local d = (j1.root.CFrame.Position - pos).Magnitude
		menorDist = math.min(menorDist, d)
	end
end

local status = api.status
print(string.format("cenário %s | estado final do encontro: %s %s", CENARIO, tostring(status.state), tostring(status.error or "")))
print("estados do monstro:", table.concat(estados, " → "))
print(string.format("rugidos %d | botes %d | garras que acertaram %d | marcadores de passo %d",
	serialRugido, serialAtaque, serialGolpe, passos))
print(string.format("vida do jogador 1: %d | menor distância %.1f | chegou na oficina: %s",
	j1.hum.Health, menorDist, tostring(CoreReal.inSafeZone({ x = j1.root.CFrame.Position.X, y = j1.root.CFrame.Position.Y, z = j1.root.CFrame.Position.Z }))))
if j2 then print("vida do jogador 2:", j2.hum.Health) end
local nomes = {}
for n, q in tocadas do table.insert(nomes, n .. "×" .. q) end
table.sort(nomes)
print(string.format("capturas (jumpscare) %d | extras carregados: %s", capturas, tostring(monstro and monstro:GetAttribute("BastiaoExtras"))))
print("animações tocadas: " .. table.concat(nomes, " "))
print(string.format("pior altura fora do chão %.2f studs | pior saída do eixo %.2f studs | entrou na oficina: %s | saiu da área: %s",
	maxY, maxFora, tostring(entrouOficina), tostring(maxForaArea)))
for _, a in avisos do print("AVISO:", a) end
local falhas = {}
if status.state ~= "active" then table.insert(falhas, "encontro não ficou ativo: " .. tostring(status.error)) end
if entrouOficina then table.insert(falhas, "monstro entrou na oficina") end
if maxForaArea then table.insert(falhas, "monstro saiu da área do encontro") end
if maxY > 1.05 then table.insert(falhas, string.format("monstro fora do chão (%.2f)", maxY)) end
if maxFora > 2.6 then table.insert(falhas, string.format("monstro saiu do eixo (%.2f)", maxFora)) end
if serialRugido < 1 then table.insert(falhas, "não rugiu ao ver o jogador") end
local perseguiu = table.concat(estados, " "):find("chase") ~= nil
if espera.chase and not perseguiu then table.insert(falhas, "não perseguiu") end
if espera.bote and serialAtaque < 1 then table.insert(falhas, "não deu o bote no jogador andando") end
if espera.garra and (serialGolpe < 1 or j1.hum.Health >= 100) then table.insert(falhas, "a garra não acertou o jogador andando") end
if espera.captura and (capturas < 1 or j1.hum.Health > 0) then table.insert(falhas, "não pegou e matou com jumpscare quem foge andando") end
if presoDepois then table.insert(falhas, "vítima ficou presa (ancorada) depois do jumpscare") end
if espera.porta and not tocadas["17_ESMURRAR_PORTA"] then table.insert(falhas, "não esmurrou a porta da oficina") end
if CENARIO == "corre_sul" and not tocadas["03_FAREJAR"] then table.insert(falhas, "não farejou na busca") end
if espera.porta and (tocadas["17_ESMURRAR_PORTA"] or 0) < 3 then table.insert(falhas, "esmurrou a porta poucas vezes") end
if #falhas > 0 then
	print("FALHOU: " .. table.concat(falhas, "; "))
	process.exit(1)
end
print("PASS simulação " .. CENARIO)
