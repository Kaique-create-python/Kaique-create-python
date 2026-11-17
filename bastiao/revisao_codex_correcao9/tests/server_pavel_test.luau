-- Pavel: veste o uniforme do catálogo (roupa e depois chapéu, sem perder o rosto), anda pela rota,
-- aponta ao chegar, acena para quem chega perto (uma vez) e varia o parado. Ambiente falso com
-- agendador de tarefas de verdade (task.wait cede), sem motor.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Harness = require("./client_harness")
local V3, CF = roblox.Vector3, roblox.CFrame

local h = Harness.new()
-- ===== agendador: task.spawn/delay criam corrotinas, task.wait cede até o tempo chegar =====
local fila = {}
local function agendar(co, at, ...)
	table.insert(fila, { co = co, at = at, args = table.pack(...) })
end
local taskLib = h.environment.task
taskLib.spawn = function(fn, ...)
	local co = coroutine.create(fn)
	agendar(co, h.now, ...)
	return co
end
taskLib.defer = taskLib.spawn
taskLib.delay = function(t, fn, ...)
	local co = coroutine.create(fn)
	agendar(co, h.now + t, ...)
	return co
end
taskLib.wait = function(t)
	local co = coroutine.running()
	agendar(co, h.now + (t or 0.03))
	coroutine.yield()
	return t or 0.03
end
local function rodar(ate)
	while true do
		table.sort(fila, function(a, b) return a.at < b.at end)
		local item = fila[1]
		if not item or item.at > ate then break end
		table.remove(fila, 1)
		h.now = math.max(h.now, item.at)
		local ok, erro = coroutine.resume(item.co, table.unpack(item.args, 1, item.args.n))
		assert(ok, "erro no Pavel: " .. tostring(erro))
	end
	h.now = ate
end

-- ===== rig R6 falso =====
local function metodo(no, nome, fn) no._p[nome] = fn end
local tocadas = {}
local function rigFalso()
	local rig = h:new("Model", "StarterCharacter")
	local raiz = h:new("Part", "HumanoidRootPart", rig)
	raiz.CFrame = CF.new()
	local cabeca = h:new("Part", "Head", rig)
	local rosto = h:new("Decal", "face", cabeca)
	rosto.Texture = "rbxasset://textures/face.png"
	h:new("BodyColors", "Body Colors", rig)
	local hum = h:new("Humanoid", "Humanoid", rig)
	hum.Running = h:signal()
	metodo(hum, "SetStateEnabled", function() end)
	metodo(hum, "MoveTo", function(_, alvo)
		-- anda na hora (o teste não simula física): começa a andar e já chega (Running 15, depois 0)
		local longe = (V3.new(alvo.X, 0, alvo.Z) - V3.new(raiz.Position.X, 0, raiz.Position.Z)).Magnitude > 0.5
		if longe then hum.Running:Fire(15) end
		raiz.Position = V3.new(alvo.X, 3, alvo.Z)
		raiz.CFrame = CF.new(raiz.Position)
		hum.Running:Fire(0)
	end)
	metodo(rig, "PivotTo", function(_, cf) raiz.CFrame = cf; raiz.Position = cf.Position end)
	metodo(raiz, "SetNetworkOwner", function() end)
	return rig, hum, cabeca
end
local base = rigFalso()
local rig, hum, cabeca = rigFalso()
metodo(base, "Clone", function() return rig end)
local descricoes = {}
metodo(hum, "ApplyDescription", function(_, d)
	table.insert(descricoes, { shirt = d.Shirt, pants = d.Pants, hat = d.HatAccessory })
	-- o ApplyDescription troca o rosto: o Pavel tem que devolver o do jogo
	local f = cabeca:FindFirstChildOfClass("Decal")
	if f then f:Destroy() end
end)
h.services.StarterPlayer = h:new("StarterPlayer", "StarterPlayer")
base.Parent = h.services.StarterPlayer
local grupos = {}
h.services.PhysicsService = {
	RegisterCollisionGroup = function(_, nome) grupos[nome] = true end,
}
h.environment.CFrame = CF
h.environment.math = math
h.environment.Instance = { new = function(classe)
	local no = h:new(classe)
	if classe == "Animator" then
		metodo(no, "LoadAnimation", function(_, anim)
			local t = { IsPlaying = false, Looped = true, Priority = nil, id = anim.AnimationId }
			function t:Play() self.IsPlaying = true; table.insert(tocadas, self.id) end
			function t:Stop() self.IsPlaying = false end
			function t:AdjustSpeed() end
			return t
		end)
	end
	return no
end }

local Pavel = luau.load(fs.readFile("src/server/Pavel.luau"), { environment = h.environment, injectGlobals = true })()
local logs = {}
local p = Pavel.criar(h.story, function(m) table.insert(logs, m) end)
assert(grupos.BastiaoNPC == true, "Pavel precisa registrar o grupo no PhysicsService antes de usá-lo")
rodar(h.now + 0.1)
assert(p.rig == rig and rig.Parent == h.story, "Pavel não foi criado")
assert(#descricoes == 2, "uniforme: esperava roupa e depois chapéu, veio " .. #descricoes)
assert(descricoes[1].shirt == 6865584651 and descricoes[1].pants == 6866147363 and (descricoes[1].hat or "") == "", "roupa errada")
assert(descricoes[2].hat == "46348897", "chapéu errado")
local rosto = cabeca:FindFirstChildOfClass("Decal")
assert(rosto and rosto.Texture == "rbxasset://textures/face.png", "o Pavel perdeu o rosto ao vestir")
local function contou(id)
	local n = 0
	for _, t in tocadas do if t == id then n += 1 end end
	return n
end
assert(contou("rbxassetid://180435571") >= 1, "parado não tocou")
-- anda até o arsenal e aponta ao chegar
p:ir("arsenal", false)
rodar(h.now + 3)
assert(p:chegou(), "não chegou no arsenal")
assert(contou("rbxassetid://180426354") >= 1, "andar não tocou")
assert(contou("rbxassetid://128853357") == 1, "não apontou ao chegar")
-- alguém chega perto pela primeira vez: acena uma vez só
local ana = h:character("Ana", h.workspace)
ana:FindFirstChild("HumanoidRootPart").Position = rig:FindFirstChild("HumanoidRootPart").Position + V3.new(6, 0, 0)
local jogador = h.player
jogador.Character = ana
jogador.UserId = 101
rodar(h.now + 2.5)
assert(contou("rbxassetid://128777973") == 1, "não acenou para quem chegou")
rodar(h.now + 5)
assert(contou("rbxassetid://128777973") == 1, "acenou de novo para a mesma pessoa")
-- parado por um tempo: olha em volta de vez em quando
rodar(h.now + 40)
assert(contou("rbxassetid://180435792") >= 1, "não variou o parado")
p.vivo = false
rodar(h.now + 1)
-- Um StarterCharacter incompleto não pode derrubar a construção da história.
local incompleto = h:new("Model", "IncompleteStarterCharacter")
metodo(base, "Clone", function() return incompleto end)
local ok, semRig = pcall(Pavel.criar, h.story, function(m) table.insert(logs, m) end)
assert(ok and semRig.rig == nil and semRig:chegou(), "rig incompleto deve deixar a missão prosseguir sem Pavel")
assert(incompleto.Parent == nil, "rig incompleto não deve ficar na cena")
print("PASS Pavel: uniforme do catálogo (roupa, chapéu, rosto mantido), anda, aponta ao chegar, acena uma vez e varia o parado")
