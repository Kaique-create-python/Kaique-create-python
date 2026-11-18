-- Executes the received chapter, mission and runner with the real sequence scheduler.
-- This measures message timelines locally; it does not claim audible Roblox playback.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local sourceRoot = "tests/fixtures/baseline/"
local function original(name) return luau.load(fs.readFile(sourceRoot .. name .. ".luau"))() end
local sequencePath = process.args[1] or "src/server/Sequencias.luau"
local Sequencias = luau.load(fs.readFile(sequencePath), { environment = { Vector3 = roblox.Vector3 } })()
local chapter = original("4_Capitulo01")
local Textos = original("3_Textos")
local Audio = original("2_Audio")
local shared = original("0_BastiaoCompartilhado")
local Runner = original("13_StoryRunner")
local Missao = original("8_Missao")
local Mundo = original("9_Mundo")
local function fixture()
    local f = { now = 0, callbacks = {}, serial = 0, messages = {}, finished = {}, worldEvents = {} }
    f.mundo = Mundo.novo(function(message) error(message) end)
    -- Rendering/physics are outside this test; the real Mundo still enforces its state registry.
    local states = {
        pavel = { "tunel", "arsenal", "enfermaria", "porta_oficina", "oficina" },
        relogio = { "0249" }, radio = { "guardado", "oferecido", "entregue" },
        bateria = { "no_carregador", "disponivel", "carregada", "encaixada" },
        terminal_enfermaria = { "sem_energia", "ligado", "autorizado" },
        porta_contencao = { "trancada", "vazando", "destravada" },
        alarme = { "desligado", "ligado" }, acesso_externo = { "aberto", "bloqueado" },
        porta_oficina = { "aberta", "trancada", "travada" },
        terminal_oficina = { "apagado", "aguardando", "lista" }, fim = { "oculto", "visivel" },
    }
    for id, names in states do
        local allowed = {}
        for _, name in names do allowed[name] = true end
        f.mundo:registrar(id, { estados = allowed, aplicar = function(state)
            table.insert(f.worldEvents, { id = id, state = state, at = f.now })
        end })
    end
    local function schedule(delay, fn)
        f.serial += 1
        local handle = { at = f.now + delay, fn = fn, serial = f.serial, canceled = false }
        table.insert(f.callbacks, handle)
        return handle
    end
    function f.advance(target)
        local count = 0
        while true do
            local nextIndex, nextCallback = nil, nil
            for index, callback in f.callbacks do
                if callback.at <= target and (not nextCallback or callback.at < nextCallback.at
                    or (callback.at == nextCallback.at and callback.serial < nextCallback.serial)) then
                    nextIndex, nextCallback = index, callback
                end
            end
            if not nextCallback then break end
            table.remove(f.callbacks, nextIndex)
            f.now = nextCallback.at
            if not nextCallback.canceled then nextCallback.fn() end
            count += 1
            assert(count < 300, "sequence callback queue did not settle")
        end
        f.now = target
    end
    function f.drain()
        local rounds = 0
        while #f.callbacks > 0 do
            local last = f.now
            for _, callback in f.callbacks do last = math.max(last, callback.at) end
            f.advance(last)
            rounds += 1
            assert(rounds < 30, "chapter sequence queue did not settle")
        end
    end
    f.mission = Missao.novo({ def = chapter, runner = Runner, mundo = f.mundo,
        objetivo = function() end, log = function(message)
            if string.find(message, "falhou", 1, true) then error(message) end
        end })
    f.sequences = Sequencias.novo({ def = chapter, textos = Textos, mundo = f.mundo,
        apresentar = function(message) table.insert(f.messages, { at = f.now, msg = message }) end,
        aoTerminar = function(id, execution)
            table.insert(f.finished, { id = id, execution = execution, at = f.now })
            f.mission:reportar({ id = "seq:" .. id .. ":" .. execution,
                kind = "sequencia", name = id .. "_fim" })
        end,
        agendar = schedule, cancelar = function(handle) handle.canceled = true end,
        duracaoLeitura = shared.duracaoLeitura, duracoes = Audio.duracoes,
        agora = function() return f.now end,
        log = function(message) error(message) end,
    })
    f.mission:ligarSequencias(f.sequences)
    function f.report(name, kind)
        f.serial += 1
        f.mission:reportar({ id = "event:" .. f.serial, name = name, kind = kind, actor = 101 })
    end
    return f
end
local passed, failed = 0, 0
local function test(name, fn)
    local ok, message = pcall(fn)
    if ok then passed += 1; print("PASS", name)
    else failed += 1; print("FAIL", name, tostring(message)) end
end
local function close(a, b) return math.abs(a - b) < 0.00001 end

test("the received chapter cannot overlap voices when workshop actions finish promptly", function()
    local f = fixture()
    f.mission:iniciar()
    f.report("pavel_perto", "zona"); f.drain()
    assert(f.mission:no() == "radio_ordem")
    f.report("pegar_radio", "interacao"); f.drain()
    assert(f.mission:no() == "buscar_bateria")
    f.report("pegar_bateria", "interacao")
    f.report("encaixar_bateria", "interacao"); f.drain()
    assert(f.mission:no() == "ir_oficina")
    f.messages = {}
    f.report("chegou_oficina", "zona")
    f.advance(f.now + 0.6) -- the real Cenario hold duration for FecharTrava
    f.report("fechar_trava", "interacao")
    f.report("ler_terminal", "interacao") -- another player can already stand by this instant prompt
    f.drain()
    assert(f.mission:final(), "chapter stopped advancing after workshop events")
    local previous, seen = nil, {}
    for _, event in f.messages do
        local message = event.msg
        if message.tipo == "fala" then
            if previous then
                assert(event.at >= previous.at + previous.msg.duracao + 0.299,
                    previous.msg.chave .. " overlaps " .. message.chave .. " across real chapter sequences")
            end
            previous = event
            assert(not seen[message.chave], "sequence reservation replayed a voice")
            seen[message.chave] = true
        end
    end
    for _, key in { "pavel_entra", "pavel_silencio", "elena_placa", "pavel_731", "elena_nome", "pavel_registro", "pavel_sinal" } do
        assert(seen[key], "sequence reservation dropped " .. key)
    end
end)
test("legacy measured voice duration pushes later cues within the same sequence", function()
    local f = fixture()
    local timeline = f.sequences:agenda("s3_ordem")
    local times = {}
    for _, item in timeline do
        if item.cue.fala then times[item.cue.fala] = item.t end
    end
    assert(close(times.orlov_ordem, 4.8))
    assert(close(times.pavel_lista1, 13.71), "Orlov's 8.26s recording did not leave its voice and breath margin")
    assert(times.pavel_lista2 > times.pavel_lista1)
end)
test("queued speech preserves following world effects and positioned noises", function()
    local f = fixture()
    f.sequences:tocar("s3_ordem")
    f.sequences:tocar("s4_chamada")
    f.drain()
    local recording, noise, pressure, open
    for _, event in f.messages do
        if event.msg.tipo == "fala" and event.msg.chave == "gravacao_sokolov" then recording = event end
        if event.msg.tipo == "som" and event.msg.chave == "inspiracao" then noise = event end
        if event.msg.tipo == "som" and event.msg.chave == "pressurizacao" then pressure = event end
    end
    for _, event in f.worldEvents do
        if event.id == "porta_contencao" and event.state == "destravada" then open = event end
    end
    assert(recording and noise and pressure and open)
    assert(close(noise.at - recording.at, 4.4), "speech delay detached the following spatial sound")
    assert(close(pressure.at - recording.at, 7.8) and close(open.at - recording.at, 13.3))
    assert(noise.msg.pos == roblox.Vector3.new(-64.4, 4.2, -320))
    assert(pressure.msg.pos == roblox.Vector3.new(-64.6, 0.8, -320))
end)
test("canceling all sequences cancels their messages and frees the voice window", function()
    local f = fixture()
    f.sequences:tocar("s3_ordem")
    f.sequences:cancelarTudo()
    f.sequences:tocar("s1_pavel")
    f.advance(0)
    assert(#f.messages == 1 and f.messages[1].msg.chave == "pavel_cafe", "canceled dialogue kept a future voice reservation")
    f.drain()
    assert(#f.messages == 2 and #f.finished == 1 and f.finished[1].id == "s1_pavel")
end)
test("expired reservations do not delay later dialogue after idle time", function()
    local f = fixture()
    f.sequences:tocar("s1_pavel"); f.drain()
    f.advance(200)
    f.messages = {}
    f.sequences:tocar("s3_ordem")
    f.advance(200)
    assert(#f.messages == 1 and f.messages[1].msg.chave == "pavel_canal")
end)
print(string.format("Sequencias: %d passed, %d failed", passed, failed))
assert(failed == 0, "sequence timeline regressions failed")
