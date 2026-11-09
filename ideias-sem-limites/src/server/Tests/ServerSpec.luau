--!strict
-- Testes do servidor: executa de verdade cada conceito do catálogo, as
-- combinações e cenários de estresse, conferindo orçamento e limpeza.
-- Roda no Lune (offline, com eventos emulados) e na nuvem via Luau Execution
-- API (motor real do Roblox, sem jogadores conectados).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.IdeiasShared

local Spec = {}

export type Result = { passed: number, failed: number, failures: { string }, stats: { [string]: any } }

-- jogador simulado (a Luau Execution roda sem jogadores conectados)
local function fakePlayer(id: number): any
	local backpack = Instance.new("Folder")
	backpack.Name = "Backpack"
	local p: any = { UserId = id, DisplayName = "Teste" .. id, Name = "Teste" .. id, Character = nil, Parent = game, backpack = backpack }
	function p.FindFirstChildOfClass(_self: any, className: string): Instance?
		return if className == "Backpack" then backpack else nil
	end
	function p.FindFirstChild(_self: any, name: string): Instance?
		return if name == "Backpack" then backpack else nil
	end
	return p
end

function Spec.run(opts: { map: boolean?, quick: boolean? }?): Result
	local o = opts or {}
	local Catalog = require(Shared.Catalog)
	local Planner = require(Shared.Planner)
	local Config = require(Shared.Config)
	local Server = script.Parent.Parent
	local Bootstrap = require(Server.Core.Bootstrap)
	local EventManager = require(Server.Core.EventManager)
	local Budget = require(Server.Core.Budget)
	local RequestGate = require(Server.Core.RequestGate)
	local Requests = require(Server.Core.Requests)

	local result: Result = { passed = 0, failed = 0, failures = {}, stats = {} }
	local function check(name: string, ok: boolean, detail: string?)
		if ok then
			result.passed += 1
		else
			result.failed += 1
			table.insert(result.failures, name .. (if detail then " => " .. detail else ""))
		end
	end

	-- 1) inicialização completa (mapa incluso) --------------------------------------
	local t0 = os.clock()
	local okStart, errStart = pcall(Bootstrap.start, { map = o.map ~= false, remotes = false, progress = false })
	check("Bootstrap.start", okStart, if okStart then nil else tostring(errStart))
	result.stats.bootSeconds = os.clock() - t0
	result.stats.map = Bootstrap.mapStats
	local events = Workspace:FindFirstChild("IdeiasEventos")
	check("pasta IdeiasEventos", events ~= nil)
	if not events then
		return result
	end

	local function countChildren(): number
		return #events:GetChildren()
	end

	-- 2) cada conceito do catálogo é executado e limpo ----------------------------
	local perHandler: { [string]: number } = {}
	local tConcepts = os.clock()
	local owner = fakePlayer(101)
	for _, def in Catalog.Concepts do
		local plan = Planner.plan(def.label)
		local ok, res = pcall(EventManager.executePlan, plan, owner)
		local detail: string? = nil
		local good = ok and res.ok
		if not ok then
			detail = tostring(res)
		elseif not res.ok then
			detail = "não criado: " .. table.concat(res.notes, "; ")
		end
		-- utilitários terminam na hora, são aceitos sem registro
		if ok and not res.ok and (def.id == "clear" or def.id == "restore") then
			good = true
		end
		check("executar " .. def.id, good, detail)
		perHandler[def.handler] = (perHandler[def.handler] or 0) + 1
		EventManager.clearAll()
	end
	result.stats.conceptSeconds = os.clock() - tConcepts
	result.stats.perHandler = perHandler

	-- deixa tarefas atrasadas (task.delay) rodarem e limpa de novo
	task.wait(0.2)
	EventManager.clearAll()
	local used = Budget.used()
	check("orçamento zerado após limpeza", used.events == 0 and used.npcs == 0 and used.parts == 0 and used.effects == 0, string.format("events=%d npcs=%d parts=%d effects=%d dynamic=%d", used.events, used.npcs, used.parts, used.effects, used.dynamic))
	check("nenhuma pasta esquecida em IdeiasEventos", countChildren() == 0, tostring(countChildren()) .. " pastas")

	-- 3) combinações com vínculos -------------------------------------------------
	local combos = {
		"herói contra demônio",
		"dragão protegendo castelo",
		"zumbi no carro",
		"cavaleiro montando dragão",
		"lobo e ovelha",
		"robô e dinossauro",
		"tornado de tubarões",
		"chuva de pizzas",
		"chuva de gatos",
		"dragão de gelo gigante",
		"meteoro congelante",
		"invasão alienígena",
		"guerra medieval",
		"fogo e gelo",
		"xyzqwe palavra estranha",
		"arma que atira cachorro e o cachorro caga elefante que o elefante explode",
		"cachorro explode",
		"vaca que vira dragão",
		"dragão que cospe gelo",
		"zumbis que se multiplicam",
		"gato tubarão",
		"crocodilo avião",
		"macaco pizza",
		"goku contra freeza",
		"jesus contra demônio",
		"deus",
		"verity",
		"tung tung tung sahur e tralalero tralala",
		"bombardiro crocodilo",
		"saitama contra kaiju",
		"naruto",
	}
	for _, text in combos do
		local plan = Planner.plan(text)
		local ok, res = pcall(EventManager.executePlan, plan, owner)
		check("combinação '" .. text .. "'", ok and res.ok, if ok then table.concat(res.notes, "; ") else tostring(res))
		EventManager.clearAll()
	end

	-- 3b) cadeias, híbridos, nomes e personagens sagrados -------------------------
	do
		local Chains = require(script.Parent.Parent.Core.Chains)
		local Combat = require(script.Parent.Parent.Core.Combat)
		local Rng = require(ReplicatedStorage.IdeiasShared.Util.Rng)
		local Requests = require(script.Parent.Parent.Core.Requests)

		-- lançador: o elo "cachorro" nasce dentro do acontecimento da arma
		local plan = Planner.plan("arma que atira cachorro e o cachorro caga elefante que o elefante explode")
		local ok, res = pcall(EventManager.executePlan, plan, owner)
		local rec = ok and res.records[1]
		check("arma lançadora criada", rec ~= nil and rec.def.id == "blaster", if ok then table.concat(res.notes, "; ") else tostring(res))
		if rec then
			local node = plan.events[1].actions[1].node
			local ctx = { id = rec.id, record = rec, folder = rec.folder, manager = EventManager, rng = Rng.new(7), owner = owner, lifetime = 60, plan = plan, spec = rec.spec }
			local before = Budget.used().npcs
			local h = Chains.spawnNode(ctx, node, CFrame.new(0, 3, 20))
			check("elo da cadeia nasce (cachorro)", h ~= nil and h.npcs ~= nil and #h.npcs == 1)
			check("elo usa o orçamento de NPCs", Budget.used().npcs == before + 1, tostring(Budget.used().npcs) .. " vs " .. tostring(before + 1))
			check("elo fica na pasta da arma", rec.folder:FindFirstChild("Elo_dog") ~= nil)
			check("elo herda as ações (caga elefante)", h ~= nil and h.npcs[1].ctx ~= nil and node.actions ~= nil and #node.actions >= 1)
			local spawned = 0
			for _ = 1, 40 do
				if Chains.spawnNode(ctx, node, CFrame.new(0, 3, 20)) then
					spawned += 1
				end
			end
			check("limite de elos por cadeia", (rec.chain.total :: number) <= Chains.MAX_TOTAL and rec.chain.alive <= Chains.MAX_ALIVE, tostring(rec.chain.total))
			EventManager.remove(rec, "teste")
			check("remover a raiz remove os elos", Budget.used().npcs == 0 and countChildren() == 0, "npcs=" .. Budget.used().npcs)
		end
		EventManager.clearAll()

		-- híbridos
		local p2 = Planner.plan("gato tubarão")
		local ok2, res2 = pcall(EventManager.executePlan, p2, owner)
		local npc2 = ok2 and res2.records[1] and res2.records[1].handle.npcs and res2.records[1].handle.npcs[1]
		check("híbrido gato-tubarão montado", npc2 ~= nil and npc2.model:GetAttribute("Hibrido") == "shark")
		EventManager.clearAll()
		local p3 = Planner.plan("crocodilo avião")
		local ok3, res3 = pcall(EventManager.executePlan, p3, owner)
		local hasHybrid = false
		if ok3 and res3.records[1] then
			for _, d in res3.records[1].folder:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("Hibrido") == "crocodile" then
					hasHybrid = true
				end
			end
		end
		check("avião com cabeça de crocodilo", hasHybrid)
		EventManager.clearAll()

		-- nome digitado passa pelo filtro (offline: vira "Personagem Misterioso")
		local p4 = Planner.plan("verity")
		Requests.filterNames(p4, owner)
		check("nome filtrado antes de aparecer", p4.events[1].params.customName == "Personagem Misterioso" or p4.events[1].params.customName == "Verity", tostring(p4.events[1].params.customName))
		check("rótulo usa o nome filtrado", p4.label == p4.events[1].params.customName, p4.label)

		-- Jesus: aparece, cura, não pode ser atacado
		local p5 = Planner.plan("jesus")
		local ok5, res5 = pcall(EventManager.executePlan, p5, owner)
		local jesus = ok5 and res5.records[1] and res5.records[1].handle.npcs and res5.records[1].handle.npcs[1]
		check("Jesus aparece como personagem", jesus ~= nil and jesus.model.Name == "Jesus")
		if jesus then
			local hp = jesus.humanoid.Health
			local hurt = Combat.damage(jesus, 500, nil, "fire")
			check("Jesus não toma dano", hurt == false and jesus.humanoid.Health == hp)
		end
		EventManager.clearAll()
	end

	-- 4) estresse: orçamento nunca é ultrapassado ---------------------------------
	local maxEvents, maxNpcs = 0, 0
	local players = { fakePlayer(201), fakePlayer(202), fakePlayer(203), fakePlayer(204), fakePlayer(205) }
	local storm = { "100 zumbis", "dragão gigante", "chuva de meteoros", "exército de robôs", "tornado", "horda de esqueletos", "castelo", "kraken" }
	for round = 1, (if o.quick then 2 else 4) do
		for i, p in players do
			local text = storm[((round + i) % #storm) + 1]
			pcall(EventManager.executePlan, Planner.plan(text), p)
			local u = Budget.used()
			maxEvents = math.max(maxEvents, u.events)
			maxNpcs = math.max(maxNpcs, u.npcs)
		end
	end
	check("limite de acontecimentos respeitado", maxEvents <= Config.Budget.events, maxEvents .. " > " .. Config.Budget.events)
	check("limite de NPCs respeitado", maxNpcs <= Config.Budget.npcs, maxNpcs .. " > " .. Config.Budget.npcs)
	local perPlayerOk = true
	local counts: { [any]: number } = {}
	for _, rec in EventManager.active() do
		counts[rec.owner] = (counts[rec.owner] or 0) + 1
		if counts[rec.owner] > Config.Budget.perPlayer then
			perPlayerOk = false
		end
	end
	check("limite por jogador respeitado", perPlayerOk)
	result.stats.stressMaxEvents = maxEvents
	result.stats.stressMaxNpcs = maxNpcs
	EventManager.clearAll()
	task.wait(0.1)
	check("limpeza após estresse", countChildren() == 0 and Budget.used().events == 0, countChildren() .. " pastas")

	-- 5) porteiro de pedidos ------------------------------------------------------
	RequestGate.reset()
	local key = {}
	local v1 = RequestGate.check(key, "dragão", 100)
	check("pedido válido aceito", v1.ok)
	local v2 = RequestGate.check(key, "dragão", 101)
	check("recarga bloqueia", not v2.ok and v2.reason == "cooldown")
	local v3 = RequestGate.check(key, "dragão", 104)
	check("após recarga aceita", v3.ok)
	check("tipo inválido recusado", not RequestGate.check({}, 42 :: any, 200).ok)
	check("texto vazio recusado", RequestGate.check({}, "   ", 300).reason == "empty")
	check("texto gigante recusado", RequestGate.check({}, string.rep("a", 5000), 400).reason == "too_long")
	check("UTF-8 inválido recusado", not RequestGate.check({}, "abc\255\254", 500).ok)
	local spamKey = {}
	local blocked = false
	for i = 1, 12 do
		local v = RequestGate.check(spamKey, "x" .. i, 600 + i * 0.1)
		if v.reason == "spam" then
			blocked = true
		end
	end
	check("spam bloqueado", blocked)
	local cut = RequestGate.check({}, string.rep("dragão ", 40), 700)
	check("texto longo é cortado", cut.ok and utf8.len(cut.text or "") <= Config.Request.MaxTextLength)
	RequestGate.reset()

	-- 6) fluxo completo de um pedido (como o RemoteFunction chama) ---------------
	local requester = fakePlayer(301)
	local reply = Requests.handle(requester :: any, "dragão de fogo")
	check("Requests.handle responde ok", type(reply) == "table" and reply.ok == true, if type(reply) == "table" then tostring(reply.message) else "sem resposta")
	check("resposta traz rótulo", type(reply) == "table" and reply.label == "Dragão de Fogo", type(reply) == "table" and tostring(reply.label) or "")
	local again = Requests.handle(requester :: any, "dragão de fogo")
	check("segundo pedido imediato recebe recarga", type(again) == "table" and again.ok == false and again.reason == "cooldown")
	EventManager.clearAll()
	RequestGate.reset()

	result.stats.eventManager = table.clone(EventManager.stats)
	return result
end

return Spec
