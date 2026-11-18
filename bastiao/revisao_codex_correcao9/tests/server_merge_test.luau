-- Executes BastiaoServidor itself; only the Roblox engine and unrelated services are adapted.
-- Run from etapa3: lune run tests/server_merge_test.luau [server-source-path] [interactions-source-path]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serverPath = process.args[1] or "src/server/BastiaoServidor.luau"
local serverSource = fs.readFile(serverPath)
local interactionPath = process.args[2] or "src/server/Interacoes.luau"
local Interacoes = luau.load(fs.readFile(interactionPath), { debugName = "Interacoes" })()
local I, V = roblox.Instance.new, roblox.Vector3.new
local signals, workspaces, remoteMessages = {}, {}, {}
local sourceRoot = "tests/fixtures/baseline/"
local Compartilhado = luau.load(fs.readFile(sourceRoot .. "0_BastiaoCompartilhado.luau"))()
local Textos = luau.load(fs.readFile(sourceRoot .. "3_Textos.luau"))()
local Audio = luau.load(fs.readFile(sourceRoot .. "2_Audio.luau"))()
local preferenceSource = fs.readFile(sourceRoot .. "11_Preferencias.luau")

local function signal(instance, name)
    signals[instance] = signals[instance] or {}
    if not signals[instance][name] then
        local listeners = {}
        signals[instance][name] = {
            Connect = function(_, fn)
                local entry = { fn = fn, connected = true }
                table.insert(listeners, entry)
                return { Disconnect = function() entry.connected = false end }
            end,
            Fire = function(_, ...)
                for _, entry in table.clone(listeners) do
                    if entry.connected then entry.fn(...) end
                end
            end,
        }
    end
    return signals[instance][name]
end
for class, names in {
    Instance = { "DescendantAdded", "Destroying" },
    Players = { "PlayerAdded", "PlayerRemoving" },
    RemoteEvent = { "OnServerEvent" },
    Player = { "CharacterAdded", "CharacterRemoving" },
    Humanoid = { "Died" },
    RunService = { "Heartbeat" },
    ProximityPrompt = { "Triggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
} do
    for _, event in names do
        roblox.implementProperty(class, event, function(instance) return signal(instance, event) end)
    end
end
roblox.implementMethod("Instance", "WaitForChild", function(instance, name)
    return instance:FindFirstChild(name)
end)
roblox.implementMethod("Players", "GetPlayers", function(instance)
    local found = {}
    for _, child in instance:GetChildren() do
        if child:IsA("Player") then table.insert(found, child) end
    end
    return found
end)
roblox.implementMethod("RemoteEvent", "FireClient", function(remote, player, message)
    remoteMessages[remote] = remoteMessages[remote] or {}
    table.insert(remoteMessages[remote], { player = player, msg = message })
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(remote, message)
    remoteMessages[remote] = remoteMessages[remote] or {}
    table.insert(remoteMessages[remote], { msg = message })
end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function(instance) return workspaces[instance].now end)

-- Small AABB ray adapter: real decisions come from the production filter/direction.
local function intersection(origin, direction, part)
    local low, high = 0, 1
    local half = part.Size / 2
    for _, axis in { "X", "Y", "Z" } do
        local a, d = origin[axis], direction[axis]
        local left, right = part.Position[axis] - half[axis], part.Position[axis] + half[axis]
        if math.abs(d) < 1e-8 then
            if a < left or a > right then return nil end
        else
            local enter, leave = (left - a) / d, (right - a) / d
            if enter > leave then enter, leave = leave, enter end
            low, high = math.max(low, enter), math.min(high, leave)
            if low > high then return nil end
        end
    end
    return low
end
roblox.implementMethod("Workspace", "Raycast", function(instance, origin, direction, params)
    local f = workspaces[instance]
    local result, closest = nil, math.huge
    for _, part in f.blockers do
        local ignored = false
        for _, excluded in params.FilterDescendantsInstances or {} do
            if part == excluded or part:IsDescendantOf(excluded) then ignored = true end
        end
        if not ignored and part.Parent then
            local t = intersection(origin, direction, part)
            if t and t < closest then
                closest = t
                result = { Instance = part, Position = origin + direction * t }
            end
        end
    end
    return result
end)

local function child(class, name, parent)
    local instance = I(class)
    instance.Name, instance.Parent = name, parent
    return instance
end
local function fixture(options)
    options = options or {}
    local f = { now = 0, accepted = 0, expected = true, world = "disponivel", blockers = {},
        stored = { u101 = { idioma = "ru", v = 1 } }, scheduled = {}, lifecycle = {}, creatureStopped = 0 }
    f.workspace = I("Workspace")
    workspaces[f.workspace] = f
    local storage = I("ReplicatedStorage")
    f.storage = storage
    f.players = I("Players")
    local services = {
        Players = f.players, ReplicatedStorage = storage,
        RunService = I("RunService"), TweenService = I("TweenService"), CollectionService = I("CollectionService"),
    }
    child("Folder", "Sector7World", f.workspace)
    f.player = child("Player", "Jogador", f.players)
    f.player.UserId = 101
    f.player.LocaleId = "pt-br"
    f.character = child("Model", "Personagem", f.workspace)
    f.player.Character = f.character
    f.root = child("Part", "HumanoidRootPart", f.character)
    f.root.Position, f.root.Size = V(0, 3, 0), V(1, 2, 1)
    f.head = child("Part", "Head", f.character)
    f.head.Position = V(0, 4.5, 0)
    f.humanoid = child("Humanoid", "Humanoid", f.character)
    f.humanoid.Health = 100
    table.insert(f.blockers, f.root)
    local scriptInstance = I("Script")
    f.script = scriptInstance
    local modules = {}
    local function module(name, value, parent)
        local instance = child("ModuleScript", name, parent or scriptInstance)
        modules[instance] = value
        return instance
    end
    local shared = module("BastiaoCompartilhado", Compartilhado, storage)
    f.shared = shared
    module("Textos", Textos, shared)
    module("Audio", Audio, shared)
    local preferences = luau.load(preferenceSource, { environment = {
        game = { GetService = function(_, service)
            assert(service == "DataStoreService")
            return { GetDataStore = function(_, name)
                assert(name == "BastiaoPreferencias_v1")
                return {
                    GetAsync = function(_, key) return f.stored[key] end,
                    SetAsync = function(_, key, value) f.stored[key] = value end,
                }
            end }
        end },
        os = { clock = function() return f.now end },
        task = {
            spawn = function(fn, ...) fn(...) end,
            delay = function(delay, fn)
                table.insert(f.scheduled, { at = f.now + delay, fn = fn })
            end,
        },
    } })()
    module("Preferencias", preferences)
    module("Criatura", { start = function(op)
        table.insert(f.lifecycle, "criatura")
        assert(op.world == f.story and op.cena == f.scene and op.mundo == f.mundo and op.shared == shared,
            "creature was given a different scene or world")
        f.creatureFolder = child("Folder", "Criatura", op.world)
        return { status = { state = "dormant" }, destroy = function()
            f.creatureStopped += 1
            f.creatureFolder:Destroy()
        end }
    end })
    module("StoryRunner", {})
    module("StoryValidator", { Validate = function()
        table.insert(f.lifecycle, "validar")
        return { ok = not options.invalidChapter, erros = { "fixture inválida" } }
    end })
    module("Capitulo01", { id = "capitulo_01", version = 1 })
    module("Interacoes", Interacoes)
    module("Pavel", { GRUPO = "Pavel" })
    module("Mundo", { novo = function()
        f.mundo = {
            estado = function() return f.world end,
            registro = function() return {} end,
            aoMudar = function(_, fn) f.worldChanged = fn end,
        }
        return f.mundo
    end })
    module("Missao", { novo = function(op)
        f.missionOptions = op
        return {
            espera = function(_, event) return f.expected and event == "pegar" end,
            reportar = function(_, event)
                assert(event.name == "pegar" and event.actor == 101)
                f.accepted += 1
                f.expected = false
            end,
            ligarSequencias = function() end,
            iniciar = function() op.aoAvancar() end,
        }
    end })
    module("Sequencias", { novo = function(op)
        f.sequenceOptions = op
        return {}
    end })
    module("Checkpoint", { novo = function()
        return { spawn = function() return nil end, aoSalvar = function() end, salvar = function() end }
    end })
    module("Zonas", { novo = function()
        return { registrar = function() end, verificar = function() end }
    end })
    module("Cenario", { construir = function(op)
        table.insert(f.lifecycle, "cenario")
        f.scenarioOptions = op
        f.story = op.pasta
        f.prop = child("Model", "ModuloBateria", f.story)
        f.target = child("Part", "Corpo", f.prop)
        f.target.Position = V(3, 3, 0)
        f.cover = child("Part", "Alca", f.prop)
        f.cover.Position, f.cover.Size = V(1.5, 3.6, 0), V(0.3, 2, 1)
        table.insert(f.blockers, f.cover)
        table.insert(f.blockers, f.target)
        local function prompt(name, duration)
            local p = child("ProximityPrompt", name, f.target)
            p.HoldDuration, p.Enabled = duration, false
            return p
        end
        f.prompt = prompt("Segurar", 0.8)
        f.instant = prompt("Radio", 0)
        local function definition(name, p)
            return { nome = name, prompt = p, posicao = function() return f.target.Position end,
                alcance = 10, evento = "pegar", requer = { { "bateria", "disponivel" } },
                validar = function()
                    if f.deny then return false, "modulo_com", { "BIA" } end
                    return true
                end }
        end
        f.scene = {
            interacoes = { definition("pegar", f.prompt), definition("radio", f.instant) },
            spawns = {}, zonas = {}, bateria = { soltar = function() return f.dropModule == true end },
            dentroOficina = function() return true end,
        }
        return f.scene
    end })
    local environment = {
        game = { GetService = function(_, name) return services[name] end },
        workspace = f.workspace, script = scriptInstance, Instance = roblox.Instance,
        Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum,
        RaycastParams = { new = function() return {} end }, TweenInfo = { new = function() return {} end },
        os = { clock = function() return f.now end },
        task = { spawn = function(fn, ...) fn(...) end, delay = function() return {} end, cancel = function() end },
        require = function(instance)
            assert(modules[instance] ~= nil, "unadapted module " .. tostring(instance))
            return modules[instance]
        end,
        warn = function() end, print = function() end,
    }
    luau.load(serverSource, { debugName = serverPath, environment = environment })()
    local remotes = storage:FindFirstChild(Compartilhado.PASTA_REMOTOS)
    f.presentation = remotes and remotes:FindFirstChild(Compartilhado.REMOTO_APRESENTACAO)
    f.language = remotes and remotes:FindFirstChild(Compartilhado.REMOTO_IDIOMA)
    f.messages = remoteMessages[f.presentation] or {}
    local function readMessages()
        f.messages = remoteMessages[f.presentation] or {}
        return f.messages
    end
    f.readMessages = readMessages
    return f
end
local function wall(f, parent)
    local part = child("Part", "Parede", parent or f.workspace)
    part.Position, part.Size = V(2, 3.6, 0), V(0.2, 4, 4)
    table.insert(f.blockers, part)
    return part
end
local function start(f) f.prompt.PromptButtonHoldBegan:Fire(f.player) end
local function trigger(f) f.now = 0.8; f.prompt.Triggered:Fire(f.player) end
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed += 1; print("PASS", name)
    else failed += 1; print("FAIL", name, tostring(err)) end
end

test("real server wiring accepts HoldBegan then a measured Triggered", function()
    local f = fixture()
    start(f)
    trigger(f)
    assert(f.accepted == 1, "full server did not connect/accept the observed hold")
end)
test("real server wiring records early HoldEnded before a late Triggered", function()
    local f = fixture()
    start(f)
    f.now = 0.1
    f.prompt.PromptButtonHoldEnded:Fire(f.player)
    trigger(f)
    assert(f.accepted == 0, "early release was lost by server wiring")
end)
test("instant actions still accept through their own prop and character", function()
    local f = fixture()
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 1, "raycast rejected the player's own body or target decoration")
end)
test("a wall at begin prevents a hold even if removed before Triggered", function()
    local f = fixture()
    local blocker = wall(f)
    start(f)
    blocker.Parent = nil
    trigger(f)
    assert(f.accepted == 0, "server did not check visibility when the hold began")
end)
test("a wall at completion rejects a hold that began in sight", function()
    local f = fixture()
    start(f)
    wall(f)
    trigger(f)
    assert(f.accepted == 0, "server did not check visibility when Triggered arrived")
end)
test("a wall behind the target's own trim still obstructs its center", function()
    local f = fixture()
    wall(f)
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 0, "hitting the prop's trim hid a wall before the target")
end)
test("another story model is still an obstacle", function()
    local f = fixture()
    wall(f, child("Model", "PortaOficina", f.story))
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 0, "raycast excluded the entire story folder")
end)
test("vision starts at the server character head", function()
    local f = fixture()
    local blocker = wall(f)
    blocker.Position, blocker.Size = V(1.5, 3, 0), V(0.2, 0.6, 2)
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 1, "a low obstacle blocked the root but not the head-to-target ray")
end)
test("mission advancement invalidates a hold even if its event becomes available again", function()
    local f = fixture()
    start(f)
    f.missionOptions.aoAvancar()
    trigger(f)
    assert(f.accepted == 0, "mission callback did not invalidate the stale hold")
end)
test("a world transition invalidates the old hold", function()
    local f = fixture()
    start(f)
    f.worldChanged("alarme", "ligado")
    trigger(f)
    assert(f.accepted == 0, "world callback did not invalidate the stale hold")
end)
test("death then revival cannot reuse the old body hold", function()
    local f = fixture()
    start(f)
    f.humanoid.Health = 0
    f.humanoid.Died:Fire()
    f.humanoid.Health = 100
    trigger(f)
    assert(f.accepted == 0, "death did not cancel the player's hold")
end)
test("CharacterRemoving cannot leave a usable hold", function()
    local f = fixture()
    start(f)
    f.player.CharacterRemoving:Fire(f.character)
    trigger(f)
    assert(f.accepted == 0, "CharacterRemoving did not cancel the player's hold")
end)
test("leaving cannot leave a usable hold", function()
    local f = fixture()
    start(f)
    f.players.PlayerRemoving:Fire(f.player)
    trigger(f)
    assert(f.accepted == 0, "PlayerRemoving did not clear hold history")
end)
test("a wrongly typed character root rejects cleanly", function()
    local f = fixture()
    f.root:Destroy()
    child("Folder", "HumanoidRootPart", f.character)
    local ok = pcall(function() f.instant.Triggered:Fire(f.player) end)
    assert(ok, "server threw for a character root that is not a BasePart")
    assert(f.accepted == 0, "non-part root was accepted")
end)
test("non-finite health cannot qualify as alive", function()
    local f = fixture()
    f.humanoid.Health = math.huge
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 0, "infinite health was accepted")
end)
test("non-finite head coordinates do not reach the raycast", function()
    local f = fixture()
    f.head.Position = V(0/0, 4, 0)
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 0, "invalid ray origin was accepted")
end)
test("the new language remote applies and saves the player's language preference", function()
    local f = fixture()
    assert(f.player:GetAttribute("BastiaoIdioma") == "ru", "saved language was not loaded")
    assert(f.language and f.language:IsA("RemoteEvent"), "new language remote was lost")
    f.language.OnServerEvent:Fire(f.player, "en")
    assert(f.player:GetAttribute("BastiaoIdioma") == "en", "language menu choice did not reach preferences")
    f.players.PlayerRemoving:Fire(f.player)
    assert(f.stored.u101.idioma == "en", "language choice was not flushed on exit")
end)
test("localized interaction warnings retain interpolation arguments", function()
    local f = fixture()
    f.deny = true
    f.instant.Triggered:Fire(f.player)
    assert(f.accepted == 0)
    local messages = f.readMessages()
    assert(#messages == 1)
    local message = messages[1]
    assert(message.player == f.player and message.msg.tipo == "aviso" and message.msg.chave == "modulo_com")
    assert(message.msg.args and message.msg.args[1] == "BIA", "localized warning lost its arguments in server wiring")
end)
test("module drop sends a localized broadcast without resolving the viewer's language", function()
    local f = fixture()
    f.dropModule = true
    f.humanoid.Died:Fire()
    local messages = f.readMessages()
    assert(#messages == 1 and messages[1].msg.tipo == "aviso" and messages[1].msg.chave == "modulo_voltou")
    assert(messages[1].msg.texto == nil)
end)
test("scene sound and sequence services retain audio duration and spatial messages", function()
    local f = fixture()
    assert(f.sequenceOptions.duracoes == Audio.duracoes, "legacy Audio.duracoes was not passed to Sequencias")
    assert(type(f.sequenceOptions.agora) == "function" and f.sequenceOptions.agora() == f.now,
        "sequence reservations did not receive the server's monotonic clock")
    local position = V(7, 8, -310)
    f.scenarioOptions.servicos.ruido("modulo_encaixe", position)
    f.sequenceOptions.apresentar({ tipo = "som", chave = "toques_longe", pos = position, duracao = 2.6 })
    local messages = f.readMessages()
    assert(#messages == 2)
    assert(messages[1].msg.tipo == "ruido" and messages[1].msg.chave == "modulo_encaixe" and messages[1].msg.pos == position)
    assert(messages[2].msg.tipo == "som" and messages[2].msg.pos == position)
end)
test("world state keeps alarm and outdoor-access replication", function()
    local f = fixture()
    assert(f.shared:GetAttribute("BastiaoAcessoExterno") == "aberto")
    f.worldChanged("acesso_externo", "bloqueado")
    f.worldChanged("alarme", "ligado")
    assert(f.shared:GetAttribute("BastiaoAcessoExterno") == "bloqueado")
    assert(f.shared:GetAttribute("BastiaoAlarme") == true)
end)
test("creature starts in the validated existing scene and is removed once with its owner", function()
    local f = fixture()
    assert(table.concat(f.lifecycle, ",") == "cenario,validar,criatura", "creature did not start after scene validation")
    assert(f.creatureFolder and f.creatureFolder.Parent == f.story)
    f.story.Destroying:Fire()
    assert(f.creatureStopped == 1 and f.creatureFolder.Parent == nil, "owned story destruction leaked the creature runtime")
    f.script.Destroying:Fire()
    assert(f.creatureStopped == 1, "creature runtime cleanup ran twice")
end)
test("an invalid chapter cannot start a creature runtime", function()
    local f = fixture({ invalidChapter = true })
    assert(table.concat(f.lifecycle, ",") == "cenario,validar")
    assert(not f.creatureFolder and f.shared:GetAttribute("BastiaoErro") == "capitulo_invalido")
end)

print(string.format("BastiaoServidor interactions: %d passed, %d failed", passed, failed))
assert(failed == 0, "server interaction regressions failed")
