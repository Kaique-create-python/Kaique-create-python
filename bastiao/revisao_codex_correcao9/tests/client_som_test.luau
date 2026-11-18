-- Exercises actual Som sprite/language routing and handoff at service boundaries.
local Harness = require("./client_harness")
local h = Harness.new({ preload = true, autoLoad = true })
h.hit = { Material = h.environment.Enum.Material.Concrete, Position = h.environment.Vector3.zero }
local playerModel, root, _, running = h:character("Soldier")
h.player.Character = playerModel
local pavel = h:character("Pavel", h.story)
local head = h:new("Part", "Head", pavel)
local lang, alarm = "pt", false
local audio = {
	ids = { voz_pt = 101, voz_en = 102, voz_ru = 103, efeitos = 104, extra_voice = 105, extra_fx = 106 },
	vozes = {
		pt = { pavel_cafe = { 1, 2 }, nova_fala = { 4, 2, "extra_voice" }, radio = { 8, 2 }, pa = { 12, 2 } },
		en = { pavel_cafe = { 1, 2 } }, ru = {},
	},
	sfx = { toques_longe = { 1, 0.5 }, terminal_bip = { 2, 0.5, "extra_fx" }, squelch = { 2, 0.2 }, passo_concreto = { { 5, 0.5 } } },
	loops = { estatica = { 7, 1, "extra_fx" }, ambiente = { 10, 1, "extra_fx" }, alarme = { 12, 1, "extra_fx" } },
}
local texts = { FALANTE = { pavel_cafe = "PAVEL", nova_fala = "PAVEL", radio = "ORLOV_RADIO", pa = "SISTEMA" }, CANAL = { PAVEL = "pessoa", ORLOV_RADIO = "radio", SISTEMA = "pa" } }
local som = h:load("src/client/Som.luau").iniciar({ audio = audio, textos = texts, idioma = function() return lang end, alarme = function() return alarm end, acessoBloqueado = function() return false end })
assert(running.Volume == 0.65)
-- Preload has not finished; the old path used to mute solely because an ID existed.
h.heartbeat:Fire(0.1)
assert(running.Volume == 0.65, "legacy footsteps must not mute Running until the replacement asset loaded")
h:flush()
som.fala("nova_fala")
local function lastPlayed() return h.played[#h.played] end
assert(lastPlayed().sound.SoundId == "rbxassetid://105", "voice seg[3] must select the new atlas without replacing the eight original clips")
assert(lastPlayed().position == 4 and lastPlayed().region.Min == 4 and lastPlayed().region.Max == 6)
assert(lastPlayed().sound.Parent == head)
som.fala("pavel_cafe")
assert(lastPlayed().sound.SoundId == "rbxassetid://101")
lang = "en"; som.precarregar(); h:flush(); som.fala("pavel_cafe")
assert(lastPlayed().sound.SoundId == "rbxassetid://102")
local before = #h.played
lang = "ru"; som.precarregar(); h:flush(); som.fala("pavel_cafe")
assert(#h.played == before, "missing Russian audio must keep selected-language captions without substituting Portuguese audio")
lang = "pt"
som.som("tres_toques")
assert(lastPlayed().sound.SoundId == "rbxassetid://104")
som.ruido("terminal_bip")
assert(lastPlayed().sound.SoundId == "rbxassetid://106")
som.fala("radio")
local foundRadio = false
for _, play in h.played do if play.sound.SoundId == "rbxassetid://101" and play.position == 8 then foundRadio = play.sound.SoundGroup.Name == "BastiaoRadio" end end
assert(foundRadio)
som.fala("pa")
assert(lastPlayed().sound.SoundGroup.Name == "BastiaoPA")
assert(som.grupoEfeitos.Name == "BastiaoEfeitos")
local module = h:load("src/client/Som.luau")
assert(module.zona(h.environment.Vector3.new(88, 3, -320)) == "sala")
assert(module.zona(h.environment.Vector3.new(0, 3, -535)) == "galpao")
assert(module.zona(h.environment.Vector3.new(0, 3, -200)) == "corredor")
for i = 1, 8 do root.Position = h.environment.Vector3.new(i, 0, 0); h:tick(0.1) end
assert(running.Volume == 0)
local hadStep = false
for _, play in h.played do if play.sound.SoundId == "rbxassetid://104" and play.position == 5 then hadStep = true end end
assert(hadStep, "usable legacy recordings must remain the grounded fallback while Foley is unavailable")
som.passosExternos(true)
assert(running.Volume == 0.65, "handoff must restore legacy-suppressed Running before Foley takes ownership")
local afterHandoff = #h.played
for i = 9, 16 do root.Position = h.environment.Vector3.new(i, 0, 0); h:tick(0.1) end
assert(#h.played == afterHandoff, "Som must not duplicate Foley steps")
som.passosExternos(false)
h:tick(0.1)
assert(running.Volume == 0)
alarm = true; som.estado()
assert(lastPlayed().sound.SoundId == "rbxassetid://106" and lastPlayed().sound.Looped == true)
som.parar(); som.parar()
assert(running.Volume == 0.65)
for _, c in h.connections do assert(not c.Connected, "Som connection leaked") end
for _, node in h.nodes do if node:IsA("Sound") and node.Name ~= "Running" then assert(node._destroyed, "Som sound/probe leaked") end end
local endCount = #h.played
som.fala("pavel_cafe"); som.ruido("terminal_bip"); h:tick(10)
assert(#h.played == endCount, "delayed radio PTT must not play after cleanup")
for _, config in { { preload = false }, { preload = true, regions = false }, { preload = true, length = 0.8 } } do
	local failed = Harness.new(config)
	local character, _, _, stock = failed:character("Soldier")
	failed.player.Character = character
	local session = failed:load("src/client/Som.luau").iniciar({ audio = audio, textos = texts, idioma = function() return "pt" end, alarme = function() return false end, acessoBloqueado = function() return false end })
	failed:tick(0.1)
	assert(stock.Volume == 0.65, "failed legacy preload/regions/bounds cannot silence Roblox Running")
	session.parar()
end
local late = Harness.new({ preload = false, autoLoad = false })
local delayed = late:load("src/client/Som.luau").iniciar({ audio = audio, textos = texts, idioma = function() return "pt" end, alarme = function() return false end, acessoBloqueado = function() return false end })
delayed.fala("nova_fala")
assert(#late.played == 0, "Som cannot play an atlas from zero while waiting for Loaded")
local pending
for _, node in late.nodes do if node.SoundId == "rbxassetid://105" and node.Parent then pending = node end end
assert(pending)
pending.IsLoaded = true; pending.Loaded:Fire()
assert(#late.played == 1 and late.played[1].position == 4)
delayed.parar()
print("PASS Som legacy/new atlas routing, selected voice language, radio/PA, reverb zones, step handoff and cleanup (no audio engine)")
