-- Sons do bote e da garra do monstro (MonstroSom, do Antigravity) no harness, sem motor.
-- Com passos=false (como o BastiaoCliente liga) os passos ficam só com o Foley.
local Harness = require("./client_harness")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3

local function tocados(h, nome)
	local n = 0
	for _, p in h.played do if p.sound.Name == "BastiaoMonstro_" .. nome then n += 1 end end
	return n
end

local function monstro(h)
	local model = h:new("Model", "Bastiao731A")
	model:SetAttribute("BastiaoCreature", true)
	local root = h:new("Part", "HumanoidRootPart", model)
	root.Size = V3.new(6, 9, 4)
	model.Parent = h.story
	h:tick(0.5) -- o ligar() roda no task.spawn (e o relógio passa do intervalo mínimo entre passos)
	return model
end

for _, comPassos in { false, true } do
	local h = Harness.new()
	h.environment.TweenInfo = { new = function(...) return { ... } end }
	h.player.UserId = 101
	local MonstroSom = h:load("src/client/MonstroSom.luau")
	local api = MonstroSom.iniciar({ jogador = h.player, passos = comPassos })
	local m = monstro(h)
	assert(m:FindFirstChild("HumanoidRootPart"):FindFirstChild("BastiaoMonstroBoca"), "monstro não foi ligado")

	-- pé encostando no chão (marcador da animação)
	m:SetAttribute("BastiaoMarkerName", "Foot_L")
	m:SetAttribute("BastiaoMarkerSerial", 1)
	if comPassos then
		assert(tocados(h, "passo") == 1, "com passos=true o pé tem que tocar")
	else
		assert(tocados(h, "passo") == 0, "com passos=false os passos ficam só com o Foley (sem passo dobrado)")
	end

	-- bote em quem foi alcançado: rugido + grito no monstro e o rugido "dentro da cabeça"
	m:SetAttribute("BastiaoAttackVictim", 101)
	m:SetAttribute("BastiaoAttackSerial", 1)
	assert(tocados(h, "bote_rugido") == 1 and tocados(h, "bote_grito") == 1, "bote sem rugido/grito")
	assert(tocados(h, "bote_cabeca") == 1, "quem foi alcançado tem que ouvir o rugido na cabeça")
	-- o serial voltando a 0 (monstro novo) não toca nada
	m:SetAttribute("BastiaoAttackSerial", 0)
	assert(tocados(h, "bote_rugido") == 1, "serial zerado não pode tocar")

	-- garra que acertou outro jogador: impacto no monstro, não na cabeça deste
	m:SetAttribute("BastiaoHitVictim", 202)
	m:SetAttribute("BastiaoHitSerial", 1)
	assert(tocados(h, "golpe") == 1 and tocados(h, "golpe_cabeca") == 0, "golpe em outro jogador")
	m:SetAttribute("BastiaoHitVictim", 101)
	m:SetAttribute("BastiaoHitSerial", 2)
	assert(tocados(h, "golpe_cabeca") == 1, "golpe em mim tem que soar na cabeça")

	-- os sons somem sozinhos (fade + destroy) e nada fica tocando depois de parar
	for _ = 1, 40 do h:tick(0.1) end
	local sobrando = 0
	for _, d in h.workspace:GetDescendants() do if d.ClassName == "Sound" then sobrando += 1 end end
	for _, d in h.soundService:GetDescendants() do if d.ClassName == "Sound" then sobrando += 1 end end
	assert(sobrando == 0, "sons do monstro não foram apagados: " .. sobrando)
	api.parar()
	local antes = #h.played
	m:SetAttribute("BastiaoAttackSerial", 2)
	m:SetAttribute("BastiaoHitSerial", 3)
	assert(#h.played == antes, "depois de parar não pode tocar mais nada")
	assert(h.soundService:FindFirstChild("BastiaoMonstroSomLocal") == nil, "pasta local do som ficou para trás")
end
-- jumpscare (captura) e pancadas na porta da oficina
do
	local h = Harness.new()
	h.environment.TweenInfo = { new = function(...) return { ... } end }
	h.player.UserId = 101
	local pedidos = {}
	local MonstroSom = h:load("src/client/MonstroSom.luau")
	local api = MonstroSom.iniciar({ jogador = h.player, passos = true,
		efeito = function(chave) table.insert(pedidos, chave); return nil end })
	local m = monstro(h)
	m:SetAttribute("BastiaoCapturaVitima", 101)
	m:SetAttribute("BastiaoState", "capture")
	for i, nome in { "Grip", "Roar", "Impact" } do
		m:SetAttribute("BastiaoMarkerName", nome)
		m:SetAttribute("BastiaoMarkerSerial", 10 + i)
	end
	for _, nome in { "captura_agarra", "captura_rugido", "captura_grito", "captura_cabeca", "captura_golpe" } do
		assert(tocados(h, nome) == 1, "jumpscare sem o som " .. nome)
	end
	-- quem só assiste não ouve o rugido "na cabeça"
	m:SetAttribute("BastiaoCapturaVitima", 202)
	m:SetAttribute("BastiaoMarkerName", "Roar")
	m:SetAttribute("BastiaoMarkerSerial", 20)
	assert(tocados(h, "captura_cabeca") == 1, "rugido na cabeça tocou para quem não foi pego")
	-- porta: sem o som do ElevenLabs ainda, cai no baque grave da loja
	m:SetAttribute("BastiaoState", "search")
	m:SetAttribute("BastiaoAnimation", "17_ESMURRAR_PORTA")
	m:SetAttribute("BastiaoMarkerName", "DoorHit")
	m:SetAttribute("BastiaoMarkerSerial", 21)
	assert(table.find(pedidos, "impacto_porta") and tocados(h, "porta_pancada") == 1, "pancada na porta sem som")
	api.parar()
end
print("PASS MonstroSom: bote e garra (na cabeça de quem foi pego), passos opcionais, jumpscare e pancadas na porta, limpa tudo ao parar")
