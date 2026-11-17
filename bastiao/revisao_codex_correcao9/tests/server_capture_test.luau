-- Executa as closures reais de captura/limpeza. Somente as fronteiras do motor
-- (rig, animação e jogador) são falsas; não é um playtest do Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Harness = require("./client_harness")
local Core = require("../src/server/CriaturaCore")
local source = fs.readFile("src/server/Criatura.luau")
local function trecho(de, ate)
	local a = assert(string.find(source, de, 1, true))
	local b = assert(string.find(source, ate, a, true))
	return string.sub(source, a, b - 1)
end
local lifecycle = trecho("    local function stopNavigation", "    local function fail")
local capture = trecho("    local function capturar", "    local function alvoNaOficina")
local function caso(anchored)
	local h = Harness.new()
	local character, root, human = h:character("Victim")
	h.player.Parent = h.workspace
	h.player.Character = character
	root.CFrame = roblox.CFrame.new(0, 3, -301)
	root.Position = root.CFrame.Position
	root.Anchored = anchored
	human.WalkSpeed, human.JumpPower, human.JumpHeight = 12, 55, 7
	local model = h:new("Model", "Creature", h.story)
	local creatureRoot = h:new("Part", "Root", model)
	creatureRoot.CFrame = roblox.CFrame.new(0, 5, -298)
	creatureRoot.Position = creatureRoot.CFrame.Position
	local tracks = {}
	for _, name in {"30_JUMPSCARE_FRONTAL_GRAB", "31_JUMPSCARE_FROM_BEHIND"} do
		tracks[name] = {IsPlaying = true, Stop = function() end, Destroy = function() end}
	end
	local clip = {duration=3, markers={{name="Impact", time=2}}}
	local c = {root=creatureRoot, human={MoveTo=function() end}, ready=true,
		model=model, nav={serial=0}, connections={}, tracks=tracks, state=Core.new(0),
		catalog={animations={ ["30_JUMPSCARE_FRONTAL_GRAB"]=clip, ["31_JUMPSCARE_FROM_BEHIND"]=clip }},
		mover={}}
	local env = table.clone(h.environment)
	env.CFrame, env.Core, env.V = roblox.CFrame, Core, roblox.Vector3.new
	env.CAPTURA = {frente="30_JUMPSCARE_FRONTAL_GRAB", costas="31_JUMPSCARE_FROM_BEHIND"}
	env.flat = function(v) return roblox.Vector3.new(v.X, 0, v.Z) end
	env.vitimaValida = function() return h.player, root, human end
	env.play = function(creature, name) creature.animation=name end
	local build = luau.load("return function(c) local active=c\n" .. lifecycle .. capture
		.. "return {capture=capturar, release=soltarCaptura, update=atualizarCaptura, clear=clearCreature} end",
		{environment=env, injectGlobals=true})()
	return h, c, root, human, build(c)
end

local h, c, root, human, api = caso(false)
assert(api.capture(c, 123, 0), "captura deveria iniciar")
assert(root.Anchored and human.WalkSpeed == 0, "captura deve prender a vítima")
api.clear()
assert(root.Anchored == false, "remover criatura durante jumpscare deve soltar a vítima")
assert(human.WalkSpeed == 12 and human.JumpPower == 55 and human.JumpHeight == 7,
	"interrupção deve restaurar movimento anterior")
assert(human.Health == 100, "limpeza não deve matar a vítima")
assert(h.player:GetAttribute("BastiaoCapturaTipo") == nil and h.player:GetAttribute("BastiaoCapturaAnimacao") == nil,
	"limpeza deve apagar os atributos ativos de captura")

h, c, root, human, api = caso(true)
api.capture(c, 123, 0)
api.release(c, 0.5)
assert(root.Anchored == true, "soltar deve respeitar estado ancorado anterior")

h, c, root, human, api = caso(false)
api.capture(c, 123, 0)
h.player.Parent = nil
api.update(c, 2.1)
assert(human.Health == 100 and root.Anchored == false, "saída do jogador deve cancelar antes do golpe fatal")

h, c, root, human, api = caso(false)
api.capture(c, 123, 0)
h.player.Character = h:character("Respawn")
api.update(c, 2.1)
assert(human.Health == 100 and root.Anchored == false, "troca de personagem cancela captura antiga")

-- As duas variantes e a morte no Impact continuam disponíveis.
for _, tipo in {"frente", "costas"} do
	h, c, root, human, api = caso(false)
	root.CFrame = roblox.CFrame.new(0, 3, -301) * roblox.CFrame.Angles(0, if tipo == "frente" then math.pi else 0, 0)
	api.capture(c, 123, 0)
	assert(h.player:GetAttribute("BastiaoCapturaTipo") == tipo, "variante de jumpscare incorreta")
	api.update(c, 2)
	assert(human.Health == 0, "ambas variantes devem continuar fatais no Impact")
end

h, c, root, human, api = caso(false)
api.capture(c, 123, 0)
api.update(c, 1.9)
assert(human.Health == 100, "jumpscare não mata antes do Impact")
api.update(c, 2)
assert(human.Health == 0, "jumpscare válido continua fatal no Impact")
api.update(c, 3.2)
assert(root.Anchored == false and c.captura == nil, "fim do jumpscare libera corpo")
print("PASS captura: limpeza recupera vítima; saída cancela golpe; Impact continua fatal")
