-- Regression suite for the real story InteractionService; no gameplay substitute.
-- Run from etapa3: lune run tests/server_interactions_test.luau [source-path]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local sourcePath = process.args[1] or "src/server/Interacoes.luau"
local Interacoes = luau.load(fs.readFile(sourcePath), { debugName = sourcePath })()
local V = roblox.Vector3.new
local I = roblox.Instance.new

local function fixture(duration)
    local f = { now = 0, pos = V(0, 3, 0), target = V(3, 3, 0), alive = true,
        visible = true, expected = true, world = "disponivel", accepted = 0,
        reports = {}, warnings = {}, member = true }
    f.players = I("Folder")
    f.player = I("Player")
    f.player.UserId = 101
    f.player.Parent = f.players
    f.other = I("Player")
    f.other.UserId = 102
    f.other.Parent = f.players
    f.part = I("Part")
    f.part.Parent = I("Model")
    f.prompt = I("ProximityPrompt")
    f.prompt.Enabled = true
    f.prompt.HoldDuration = duration or 0.8
    f.prompt.Parent = f.part
    f.service = Interacoes.novo({
        missao = {
            espera = function(_, event) return event == "pegar" and f.expected end,
            reportar = function(_, event)
                table.insert(f.reports, event)
                f.expected = false
            end,
        },
        mundo = { estado = function(_, id) return if id == "bateria" then f.world else nil end },
        localizar = function(_) return f.pos, f.alive end,
        agora = function() return f.now end,
        validarJogador = function(j) return f.member and j.Parent == f.players end,
        visivel = function(_, _, origem, alvo)
            assert(typeof(origem) == "Vector3" and typeof(alvo) == "Vector3", "LOS receives measured positions")
            return f.visible
        end,
        aviso = function(_, message, args) table.insert(f.warnings, { chave = message, args = args }) end,
    })
    f.record = {
        posicao = function() return f.target end, alcance = 10, prompt = f.prompt,
        evento = "pegar", requer = { { "bateria", "disponivel" } },
        aoAceitar = function(_) f.accepted += 1 end,
    }
    f.service:registrar("pegar", f.record)
    return f
end
local function accept(ok, why)
    assert(ok == true, "expected acceptance; got " .. tostring(why))
end
local function reject(why, ok, actual)
    assert(ok == false, "expected rejection " .. why .. "; interaction was accepted")
    assert(actual == why, "expected rejection " .. why .. "; got " .. tostring(actual))
end
local function begin(f, player, prompt)
    assert(type(f.service.iniciarSegurar) == "function", "server hold start is not implemented")
    return f.service:iniciarSegurar(player or f.player, prompt or f.prompt)
end
local function release(f, player, prompt)
    assert(type(f.service.terminarSegurar) == "function", "server hold release is not implemented")
    f.service:terminarSegurar(player or f.player, prompt or f.prompt)
end
local function unchanged(f)
    assert(f.accepted == 0 and #f.reports == 0, "rejected request changed the story")
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed += 1
        print("PASS", name)
    else
        failed += 1
        print("FAIL", name, tostring(err))
    end
end

test("forged Triggered cannot grant a held interaction", function()
    local f = fixture()
    reject("sem_hold", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("direct tentar cannot bypass a held interaction", function()
    local f = fixture()
    reject("sem_hold", f.service:tentar(f.player, "pegar"))
    unchanged(f)
end)
test("an observed complete hold advances the original story event exactly once", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.8
    accept(f.service:acionar(f.player, f.prompt))
    assert(f.accepted == 1 and #f.reports == 1)
    assert(f.reports[1].name == "pegar" and f.reports[1].kind == "interacao" and f.reports[1].actor == 101)
    assert(f.service:acionar(f.player, f.prompt) == false)
    assert(f.accepted == 1 and #f.reports == 1)
end)
test("HoldEnded before Triggered can complete during the ordering grace", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.8
    release(f)
    f.now = 0.85
    accept(f.service:acionar(f.player, f.prompt))
end)
test("ending early and waiting does not manufacture a hold", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.1
    release(f)
    f.now = 0.8
    reject("hold_curto", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("a short hold without HoldEnded cannot complete", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.4
    reject("hold_curto", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("a positive hold shorter than frame tolerance still requires measured time", function()
    local f = fixture(0.02)
    accept(begin(f))
    reject("hold_curto", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("an old begin cannot be saved and replayed", function()
    local f = fixture()
    accept(begin(f))
    f.now = 13
    reject("hold_expirado", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("an old completed release cannot be replayed after the grace", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.8
    release(f)
    f.now = 3
    reject("hold_expirado", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("a wall prevents starting the server hold", function()
    local f = fixture()
    f.visible = false
    reject("sem_visao", begin(f))
    unchanged(f)
end)
test("a wall at completion consumes and rejects the hold", function()
    local f = fixture()
    accept(begin(f))
    f.now, f.visible = 0.8, false
    reject("sem_visao", f.service:acionar(f.player, f.prompt))
    f.now, f.visible = 1.3, true
    reject("sem_hold", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("instant radio and terminal actions retain instant behavior with visibility validation", function()
    local blocked = fixture(0)
    blocked.visible = false
    reject("sem_visao", blocked.service:acionar(blocked.player, blocked.prompt))
    unchanged(blocked)
    local f = fixture(0)
    accept(f.service:acionar(f.player, f.prompt))
    assert(f.accepted == 1 and #f.reports == 1)
end)
test("player and target non-finite coordinates cannot pass the distance check", function()
    for _, bad in { V(0/0, 3, 0), V(0, math.huge, 0), V(0, 3, -math.huge) } do
        for _, field in { "pos", "target" } do
            local f = fixture(0)
            f[field] = bad
            reject("posicao_invalida", f.service:acionar(f.player, f.prompt))
            unchanged(f)
        end
    end
end)
test("a table or wrong Instance cannot impersonate a Player", function()
    for _, bad in { {}, { Parent = true, UserId = 101 }, "101", false, I("Folder") } do
        local f = fixture(0)
        reject("jogador_invalido", f.service:acionar(bad, f.prompt))
        unchanged(f)
    end
    local f = fixture(0)
    reject("jogador_invalido", f.service:acionar(nil, f.prompt))
end)
test("a Player outside the live Players service cannot interact", function()
    local f = fixture(0)
    f.member = false
    reject("jogador_invalido", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("distance and life are checked both before and after the hold", function()
    local far = fixture()
    far.pos = V(14, 3, 0)
    reject("longe", begin(far))
    local moved = fixture()
    accept(begin(moved))
    moved.now, moved.pos = 0.8, V(14, 3, 0)
    reject("longe", moved.service:acionar(moved.player, moved.prompt))
    unchanged(moved)
    local dead = fixture()
    dead.alive = false
    reject("morto", begin(dead))
    local died = fixture()
    accept(begin(died))
    died.now, died.alive = 0.8, false
    reject("morto", died.service:acionar(died.player, died.prompt))
    unchanged(died)
end)
test("disabled and removed prompts cannot complete", function()
    local f = fixture()
    f.prompt.Enabled = false
    reject("indisponivel", begin(f))
    f.prompt.Enabled = true
    f.now = 0.4
    accept(begin(f))
    f.now, f.prompt.Parent = 1.2, nil
    reject("indisponivel", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("required world state and expected mission event are checked at completion", function()
    local state = fixture()
    accept(begin(state))
    state.now, state.world = 0.8, "carregada"
    reject("estado", state.service:acionar(state.player, state.prompt))
    unchanged(state)
    local mission = fixture()
    accept(begin(mission))
    mission.now, mission.expected = 0.8, false
    reject("fora_de_ordem", mission.service:acionar(mission.player, mission.prompt))
    unchanged(mission)
end)
test("story revision invalidation removes old holds even when the same event is available again", function()
    local f = fixture()
    accept(begin(f))
    assert(type(f.service.invalidar) == "function", "story invalidation is not implemented")
    f.service:invalidar()
    f.now = 0.8
    reject("sem_hold", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("a reused prompt cannot transfer an old hold to its newly available action", function()
    local f = fixture()
    f.service:registrar("repegar", {
        prompt = f.prompt, posicao = function() return f.target end, alcance = 10,
        requer = { { "bateria", "carregada" } },
        disponivel = function() return true end,
        aoAceitar = function() f.accepted += 10 end,
    })
    accept(begin(f))
    f.now, f.world = 0.8, "carregada"
    reject("hold_diferente", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("begin requests have a per-player cooldown which release cannot erase", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.01
    release(f)
    f.now = 0.08
    reject("repetido", begin(f))
    accept(begin(f, f.other))
    f.now = 0.4
    accept(begin(f))
end)
test("one player's Triggered cannot consume another player's hold", function()
    local f = fixture()
    accept(begin(f))
    f.now = 0.8
    reject("sem_hold", f.service:acionar(f.other, f.prompt))
    accept(f.service:acionar(f.player, f.prompt))
    assert(f.accepted == 1)
end)
test("character removal clears the hold while preserving the request cooldown", function()
    local f = fixture()
    accept(begin(f))
    assert(type(f.service.cancelar) == "function", "character hold cleanup is not implemented")
    f.service:cancelar(f.player)
    f.now = 0.08
    reject("repetido", begin(f))
    f.now = 0.8
    reject("sem_hold", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("leaving removes the hold and request history", function()
    local f = fixture()
    accept(begin(f))
    f.service:esquecer(f.player)
    f.now = 0.08
    accept(begin(f))
    f.now = 0.88
    accept(f.service:acionar(f.player, f.prompt))
end)
test("invalid clocks and backwards time cannot complete a hold", function()
    for _, bad in { 0/0, math.huge, -math.huge, -1 } do
        local f = fixture(0)
        f.now = bad
        reject("tempo_invalido", f.service:acionar(f.player, f.prompt))
        unchanged(f)
    end
    local f = fixture()
    f.now = 1
    accept(begin(f))
    f.now = 0.5
    reject("tempo_invalido", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("server registration captures hold duration so a later property change cannot waive it", function()
    local f = fixture()
    f.prompt.HoldDuration = 0
    reject("sem_hold", f.service:acionar(f.player, f.prompt))
    unchanged(f)
end)
test("an own rule still denies completion and preserves its original warning", function()
    local f = fixture()
    accept(begin(f))
    f.record.validar = function() return false, "módulo com outro jogador" end
    f.now = 0.8
    reject("módulo com outro jogador", f.service:acionar(f.player, f.prompt))
    unchanged(f)
    assert(f.warnings[1].chave == "módulo com outro jogador")
end)
test("unknown interaction and unknown prompt cannot change the story", function()
    local f = fixture()
    reject("desconhecida", f.service:tentar(f.player, "ausente"))
    reject("indisponivel", f.service:acionar(f.player, I("ProximityPrompt")))
    reject("indisponivel", f.service:acionar(f.player, nil))
    unchanged(f)
end)
test("malformed cleanup identities cannot throw or remove another player's hold", function()
    local f = fixture()
    accept(begin(f))
    for _, bad in { 0/0, math.huge, -math.huge, {}, "101", false } do
        local ok = pcall(function()
            f.service:cancelar(bad)
            f.service:esquecer(bad)
            f.service:acionar(bad, nil)
        end)
        assert(ok, "malformed cleanup identity raised an exception")
    end
    f.now = 0.8
    accept(f.service:acionar(f.player, f.prompt))
    assert(f.accepted == 1)
end)

test("localized rule warning keeps its key and interpolation arguments", function()
    local f = fixture(0)
    f.record.validar = function() return false, "modulo_com", { "BIA" } end
    reject("modulo_com", f.service:acionar(f.player, f.prompt))
    unchanged(f)
    assert(f.warnings[1].chave == "modulo_com")
    assert(f.warnings[1].args and f.warnings[1].args[1] == "BIA", "localized warning lost its arguments")
end)

print(string.format("Interacoes: %d passed, %d failed", passed, failed))
assert(failed == 0, "interaction regressions failed")
