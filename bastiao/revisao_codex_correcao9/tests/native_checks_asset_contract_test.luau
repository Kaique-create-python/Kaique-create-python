-- Runs the native script's actual catalog validators; no native asset loads.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/teste_nuvem.luau")
local first = assert(string.find(source, "local function finito", 1, true))
local last = assert(string.find(source, "-- 4) servidor da etapa", first, true))
local validation = string.sub(source, first, last - 1)
local core = luau.load(fs.readFile("src/server/CriaturaCore.luau"), { injectGlobals = true })()

local function catalogFixture()
	local labels = {}
	for _, name in core.requiredClips do labels[tonumber(string.sub(name, 1, 2))] = name end
	local loops = { [1] = true, [2] = true, [7] = true, [8] = true }
	local monster = { version = 1, enabled = true, modelId = 999, heightStuds = 9.091193199157715,
		meshName = "Monster_Animated_18k", rootBone = "pelvis", visualFacingYawDegrees = 180, animations = {} }
	for i = 1, 35 do
		monster.animations[labels[i] or string.format("%02d_FIXTURE", i)] = { id = 1000 + i, duration = 1, loop = loops[i] == true, markers = {} }
	end
	monster.animations["06_RUGIDO"].markers = { { name = "Roar", time = 0.5 } }
	monster.animations["19_CLAW_LEFT"].markers = { { name = "Hit", time = 0.5 } }
	local audio = { ids = { voz_pt = 101, voz_en = 102, voz_ru = 103, efeitos = 104, lever_atlas = 601, room_atlas = 602 }, vozes = {},
		duracoes = { line = 2 }, sfx = { lever = { 3, 0.5, "lever_atlas" } }, loops = { room = { 4, 2, "room_atlas" } } }
	for _, locale in { "pt", "en", "ru" } do audio.vozes[locale] = { line = { 0, 2 } } end
	local extra = { version = 1, assets = { step = { id = 603, start = 2, finish = 2.5, duration = 0.5, category = "Foley", spatial = true, loop = false } } }
	return audio, extra, monster
end
local prefix = [[
local out = { passed = true, erros = {}, info = {} }
local function checar(name, fn)
    local ok, err = pcall(fn)
    if not ok then out.passed = false; table.insert(out.erros, name .. ": " .. tostring(err)) end
end
local Audio, AudioCatalog, MonsterCatalog = fixtureAudio, fixtureExtra, fixtureMonster
local Textos, CriaturaCore, MonsterImportContract = fixtureTexts, fixtureCore, fixtureContract
]]
-- Each run needs fresh globals: create its closure with the actual fixture inputs.
local function validate(mutator)
	local audio, extra, monster = catalogFixture()
	if mutator then mutator(audio, extra, monster) end
	local fn = luau.load(prefix .. validation .. "\nreturn out, audioPorId", { environment = {
		fixtureAudio = audio, fixtureExtra = extra, fixtureMonster = monster, fixtureCore = core,
		fixtureTexts = { IDIOMAS = { "pt", "en", "ru" }, FALANTE = { line = "PAVEL" } },
		fixtureContract = { MeshName = "Monster_Animated_18k", VisualFacingYawDegrees = 180, HeightStuds = 9.091193199157715 },
	}, injectGlobals = true })
	return fn()
end
local valid, regions = validate()
assert(valid.passed and valid.info.monster_catalog_clipes == 35, "valid real-ID catalog rejected")
assert(regions["601"].limite == 3.5 and regions["602"].limite == 6 and regions["603"].limite == 2.5,
	"per-segment atlas IDs must keep their own bounds")
local extraAnimation = validate(function(_, _, m)
    m.animations["36_CORRER_MEDONHO"] = { id=2000, duration=1, loop=true, markers={{name="Step",time=.3}} }
end)
assert(extraAnimation.passed and extraAnimation.info.monster_catalog_clipes == 36, "approved optional pursuit animation must survive validation")
local cases = 2
local function rejects(fn, fragment)
	local result = validate(fn)
	assert(result.passed == false, "invalid assets must fail")
	for _, err in result.erros do
		if string.find(err, fragment, 1, true) then cases += 1; return end
	end
	error("missing failure: " .. fragment)
end
rejects(function(a) a.ids.voz_pt = -1 end, "ID de áudio inválido")
rejects(function(a) a.vozes = {} end, "nenhuma voz gravada")
rejects(function(a) a.duracoes.line = 0.1 end, "duração da voz")
rejects(function(_, a) a.assets.step.id = 0 end, "ID real inválido")
rejects(function(_, a) a.assets.step.start = 0 / 0 end, "limites")
rejects(function(_, a) a.assets.step.finish = 8 end, "duração")
rejects(function(_, a) a.assets.step.loop = "true" end, "flag loop")
rejects(function(_, _, m) m.animations["35_FIXTURE"] = nil end, "esperados 35")
rejects(function(_, _, m) m.animations["07_ANDAR"] = nil end, "animacao_invalida")
rejects(function(_, _, m) m.animations["35_FIXTURE"].id = 1001 end, "ID de animação repetido")
rejects(function(_, _, m) m.animations["35_FIXTURE"].id = m.modelId end, "ModelId usado como AnimationId")
rejects(function(_, _, m) m.animations["19_CLAW_LEFT"].markers[1].time = 1.1 end, "marcador inválido")
rejects(function(_, _, m) m.rootBone = "root" end, "identidade do rig")
rejects(function(_, _, m) m.heightStuds = 10 end, "altura do catálogo")
print("PASS " .. cases .. " actual native catalog validator cases under Lune; engine asset readiness not executed")
