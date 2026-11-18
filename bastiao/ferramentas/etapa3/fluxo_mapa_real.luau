-- Roda o trecho "abertura inteira" do teste na nuvem (o texto real do teste) no Lune, com o
-- mapa Sector7World de verdade e raycast de verdade contra as peças (caixas orientadas).
-- Como na nuvem: sem Player (jogadores falsos), tweens e task.delay não andam durante o fluxo.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

-- uso: lune run fluxo_mapa_real.luau <pasta do pacote> <place.rbxl> [pavel|semPavel] [duracoes.json]
local PACOTE, PLACE = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(PLACE))
local workspace = game:GetService("Workspace")
local V3, CF = roblox.Vector3, roblox.CFrame

-- ===== fontes: base da Etapa 2 + substituições da Etapa 3 =====
local base = serde.decode("json", fs.readFile(PACOTE .. "/BASE_CLAUDE_ETAPA2.json"))
local fontes = {}
for _, row in base do fontes[table.concat(row.path, "/")] = row.source end
fontes["ServerScriptService/BastiaoServidor/Interacoes"] = fs.readFile(PACOTE .. "/src/server/Interacoes.luau")
fontes["ServerScriptService/BastiaoServidor/Sequencias"] = fs.readFile(PACOTE .. "/src/server/Sequencias.luau")

-- ===== serviços falsos (o que o fluxo usa) =====
local TweenService = { Create = function() return { Play = function() end, Cancel = function() end } end }
local CollectionService = {
	AddTag = function(_, inst, tag) inst:AddTag(tag) end,
	HasTag = function(_, inst, tag) return inst:HasTag(tag) end,
	GetTagged = function() return {} end,
	GetInstanceAddedSignal = function() return { Connect = function() return { Disconnect = function() end } end } end,
	GetInstanceRemovedSignal = function() return { Connect = function() return { Disconnect = function() end } end } end,
}
local servicos = { TweenService = TweenService, CollectionService = CollectionService, Workspace = workspace }
local gameFalso = { GetService = function(_, nome) return servicos[nome] or setmetatable({}, { __index = function() return function() end end }) end }
local tarefas = { delay = function() end, spawn = function(fn, ...) fn(...) end, defer = function() end, wait = function() return 0 end }

-- Instance sem Player (a nuvem não deixa criar Player)
local InstanceSemPlayer = {
	new = function(classe, pai)
		if classe == "Player" then error("The current thread cannot create 'Player' (lacking capability WritePlayer)") end
		local i = roblox.Instance.new(classe)
		if classe == "Humanoid" then
			-- o Lune não tem valor padrão para Health; no Roblox um Humanoid novo nasce com 100
			i.MaxHealth = 100
			i.Health = 100
		end
		if pai then i.Parent = pai end
		return i
	end,
}

-- ===== raycast real contra caixas orientadas =====
local estaticas = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then table.insert(estaticas, d) end
end
local function excluido(p, lista)
	for _, ex in lista do
		if p == ex or p:IsDescendantOf(ex) then return true end
	end
	return false
end
local function raioCaixa(origem, dir, parte)
	local cf, h = parte.CFrame, parte.Size / 2
	local o = cf:PointToObjectSpace(origem)
	local d = cf:VectorToObjectSpace(dir)
	local t0, t1 = -math.huge, math.huge
	for _, eixo in { "X", "Y", "Z" } do
		local oo, dd, hh = o[eixo], d[eixo], h[eixo]
		if math.abs(dd) < 1e-9 then
			if oo < -hh or oo > hh then return nil end
		else
			local a, b = (-hh - oo) / dd, (hh - oo) / dd
			if a > b then a, b = b, a end
			t0, t1 = math.max(t0, a), math.min(t1, b)
			if t0 > t1 then return nil end
		end
	end
	if t0 < 0 or t0 > 1 then return nil end -- começa dentro da peça: o Roblox não acerta essa peça
	return t0
end
local acertos = {}
local function raycast(origem, dir, params)
	local lista = params and params.FilterDescendantsInstances or {}
	local melhor, peca = math.huge, nil
	local todas = table.clone(estaticas)
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and not table.find(estaticas, d) then table.insert(todas, d) end
	end
	for _, p in todas do
		if p.CanQuery ~= false and not excluido(p, lista) then
			local t = raioCaixa(origem, dir, p)
			if t and t < melhor then melhor, peca = t, p end
		end
	end
	if peca then
		table.insert(acertos, string.format("%s (%s) em %s, raio de %s", peca:GetFullName(), peca.ClassName,
			tostring(origem + dir * melhor), tostring(origem)))
		return { Instance = peca, Position = origem + dir * melhor }
	end
	return nil
end
local RaycastParams = { new = function() return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false } end }

-- ===== ambiente dos módulos =====
local function achatar(t, ...)
	local r = {}
	for _, fonte in { ... } do for k, v in fonte do r[k] = v end end
	for k, v in t do r[k] = v end
	return r
end
local env = achatar({
	Instance = InstanceSemPlayer, Vector3 = V3, CFrame = CF, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Enum = roblox.Enum,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Font = roblox.Font, BrickColor = roblox.BrickColor,
	TweenInfo = { new = function(...) return { ... } end }, RaycastParams = RaycastParams,
	game = gameFalso, workspace = workspace, task = tarefas,
})
local cache = {}
local function modulo(caminho)
	if cache[caminho] == nil then
		local fonte = assert(fontes[caminho], "fonte ausente: " .. caminho)
		cache[caminho] = luau.load(fonte, { debugName = caminho, environment = env })()
	end
	return cache[caminho]
end
local S = "ServerScriptService/BastiaoServidor/"
-- Pavel com o corpo de verdade (clone do StarterCharacter do place), teleportado como o
-- teste faz (ir(estado, true)). O módulo real só é lido para pegar os lugares.
local COM_PAVEL = process.args[3] == "pavel"
local PavelReal = nil
local PavelFalso = {}
do
	local ok, m = pcall(function() return luau.load(fontes[S .. "Pavel"], { debugName = "Pavel", environment = env })() end)
	PavelReal = if ok then m else nil
	assert(PavelReal and PavelReal.LUGARES, "Pavel.LUGARES não carregou: " .. tostring(m))
end
function PavelFalso.criar(pasta)
	local base = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	assert(base, "place sem StarterCharacter")
	local rig = base:Clone()
	rig.Name = "Pavel"
	rig:SetAttribute("BastiaoNPC", true) -- como o Pavel.criar real
	local raiz = rig:FindFirstChild("HumanoidRootPart")
	local self = { rig = rig, raiz = raiz }
	local offsets = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then offsets[d] = raiz.CFrame:Inverse() * d.CFrame end
	end
	function self:ir(estado)
		local l = PavelReal.LUGARES[estado]
		if not l then return end
		local alvo = CF.lookAt(l.pos + V3.new(0, 3, 0), V3.new(l.olhar.X, 3, l.olhar.Z))
		for parte, off in offsets do parte.CFrame = alvo * off end
		self.estado = estado
	end
	function self:chegou() return true end
	self:ir("tunel")
	rig.Parent = pasta
	return self
end
local Compartilhado = modulo("ReplicatedStorage/BastiaoCompartilhado")
local audioLegado = serde.decode("json", fs.readFile(PACOTE .. "/legado/audio.json"))

-- ===== o trecho do teste na nuvem, sem mexer na lógica =====
local teste = fs.readFile(PACOTE .. "/src/teste_nuvem.luau")
local a = assert(string.find(teste, "-- 5) abertura inteira", 1, true))
local b = assert(string.find(teste, "-- 6) interface do cliente", 1, true))
local trecho = string.sub(teste, a, b - 1)
trecho = string.gsub(trecho, "workspace:Raycast%(", "__raycast(")
-- O Lune não guarda Position de peça (só CFrame): troca só as leituras/escritas de peças do trecho.
for _, troca in {
	{ "return r.Position, true", "return r.CFrame.Position, true" },
	{ "then head.Position else origem", "then head.CFrame.Position else origem" },
	{ "alvo.Position = Vector3.new(20000, 20003, 0)", "alvo.CFrame = CFrame.new(20000, 20003, 0)" },
	{ "parede.Position = alvo.Position + Vector3.new(0, 0, 2.5)", "parede.CFrame = CFrame.new(alvo.CFrame.Position + Vector3.new(0, 0, 2.5))" },
	{ "alvo.Position", "alvo.CFrame.Position" },
} do
	local antes = trecho
	trecho = string.gsub(trecho, troca[1]:gsub("%p", "%%%0"), (troca[2]:gsub("%%", "%%%%")))
	assert(trecho ~= antes, "troca não aplicada: " .. troca[1])
end
local out = { passed = true, erros = {}, avisos = {}, info = {} }
local function finito(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local envTeste = achatar({
	out = out,
	falha = function(m) out.passed = false; table.insert(out.erros, tostring(m)) end,
	aviso = function(m) table.insert(out.avisos, m) end,
	checar = function(nome, fn)
		local ok, err = pcall(fn)
		if not ok then out.passed = false; table.insert(out.erros, nome .. ": " .. tostring(err)) end
		return ok
	end,
	relatorio = function() return out end,
	finito = finito,
	__raycast = raycast,
	aoVivo = not COM_PAVEL, mundoDuplicado = nil,
	Compartilhado = Compartilhado,
	Textos = modulo("ReplicatedStorage/BastiaoCompartilhado/Textos"),
	Runner = modulo(S .. "StoryRunner"), Validator = modulo(S .. "StoryValidator"), Cap = modulo(S .. "Capitulo01"),
	Mundo = modulo(S .. "Mundo"), Missao = modulo(S .. "Missao"), Sequencias = modulo(S .. "Sequencias"),
	Interacoes = modulo(S .. "Interacoes"), Zonas = modulo(S .. "Zonas"), Checkpoint = modulo(S .. "Checkpoint"),
	Cenario = modulo(S .. "Cenario"), Pavel = PavelFalso,
	Telas = modulo("StarterPlayer/StarterPlayerScripts/BastiaoCliente/Telas"),
	Audio = { duracoes = if process.args[4] then serde.decode("json", fs.readFile(process.args[4])) else (audioLegado.duracoes or {}) },
	TweenService = TweenService, CollectionService = CollectionService,
}, env)
local fn = luau.load(trecho .. "\nreturn pasta", { debugName = "teste_nuvem:abertura", environment = envTeste })
local ok, pasta = pcall(fn)
print("trecho rodou:", ok, if ok then "" else tostring(pasta))
print("jogadores:", out.info.jogadores_do_teste, "| contraprovas:", out.info.contraprovas_interacoes,
	"| falas:", out.info.falas_apresentadas, "| nó final:", out.info.no_final, "| fluxo:", out.info.fluxo)
for _, e in out.erros do print("ERRO:", e) end
for _, a in out.avisos do print("aviso:", a) end
if #acertos > 0 then
	print("raios bloqueados (" .. #acertos .. "):")
	for i, t in acertos do if i <= 12 then print("  " .. t) end end
end
if not ok or not out.passed then process.exit(1) end
print("PASS abertura inteira com o mapa real e jogadores falsos")
