--!strict
-- Inicialização do servidor. Também usado pelos testes na nuvem
-- (Luau Execution), que não executam Scripts automaticamente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.IdeiasShared
local Catalog = require(Shared.Catalog)
local Lexicon = require(Shared.Lexicon)

local Core = script.Parent
local Server = Core.Parent
local EventManager = require(Core.EventManager)
local Status = require(Core.Status)
local Ambience = require(Core.Ambience)
local Destruction = require(Core.Destruction)
local Reactions = require(Core.Reactions)
local Requests = require(Core.Requests)
local RequestGate = require(Core.RequestGate)
local Combat = require(Core.Combat)
local PropActions = require(Core.PropActions)
local Brain = require(Server.Brains.Brain)

local Bootstrap = {}
Bootstrap.started = false
Bootstrap.mapStats = nil :: any

function Bootstrap.start(opts: { map: boolean?, remotes: boolean?, progress: boolean? }?)
	if Bootstrap.started then
		return
	end
	Bootstrap.started = true
	local o = opts or {}
	local errors = Catalog.validate()
	for _, e in errors do
		warn("[Ideias] catálogo: " .. e)
	end
	for _, c in Lexicon.collisions() do
		warn("[Ideias] vocabulário: " .. c)
	end

	if o.map ~= false then
		local MapBuilder = require(Server.Map.MapBuilder)
		local ok, stats = pcall(MapBuilder.build, {})
		if ok then
			Bootstrap.mapStats = stats
		else
			warn("[Ideias] falha ao gerar o mapa: " .. tostring(stats))
		end
	end

	Ambience.start()
	Status.start()
	Destruction.start()
	Brain.start()
	EventManager.init()
	Reactions.start(EventManager)

	local remotes = ReplicatedStorage:FindFirstChild("IdeiasRemotes")
	local estado = remotes and remotes:FindFirstChild("Estado") :: RemoteEvent?

	if o.progress ~= false then
		local Progress = require(Server.Progress.Progress)
		Progress.start(estado)
		Requests.progress = Progress
		PropActions.rewardHook = Progress.reward
		Combat.onKill(function(_victim, attacker)
			local owner = attacker and (if attacker.kind == "player" then attacker.player else attacker.owner)
			if owner and owner.Parent then
				Progress.onKill(owner)
			end
		end)
	end

	if o.remotes ~= false and remotes then
		local criar = remotes:FindFirstChild("Criar") :: RemoteFunction
		local acao = remotes:FindFirstChild("Acao") :: RemoteEvent
		criar.OnServerInvoke = function(player: Player, text: any)
			local ok, res = pcall(Requests.handle, player, text)
			if ok then
				return res
			end
			warn("[Ideias] erro no pedido: " .. tostring(res))
			return { ok = false, reason = "invalid", message = "Algo deu errado. Tente outra ideia." }
		end
		-- ações da interface: no máximo 10 a cada 5 s por jogador
		local actionHits: { [Player]: { number } } = {}
		Players.PlayerRemoving:Connect(function(p)
			actionHits[p] = nil
		end)
		acao.OnServerEvent:Connect(function(player: Player, action: any, arg: any)
			local hits = actionHits[player] or {}
			actionHits[player] = hits
			local now = os.clock()
			while hits[1] and now - hits[1] > 5 do
				table.remove(hits, 1)
			end
			if #hits >= 10 then
				return
			end
			table.insert(hits, now)
			if Requests.progress then
				pcall(Requests.progress.action, player, action, arg)
			end
		end)
		-- capacidade do mundo para a interface
		task.spawn(function()
			local last = ""
			while true do
				task.wait(1)
				local cap = EventManager.capacity()
				local key = cap.events .. "/" .. cap.npcs .. "/" .. math.floor(cap.load * 20)
				if key ~= last and estado then
					last = key
					estado:FireAllClients("capacidade", cap)
				end
			end
		end)
		Players.PlayerRemoving:Connect(function(player)
			RequestGate.forget(player)
			EventManager.removeOwnedBy(player)
		end)
	end
	print(string.format("[Ideias Sem Limites] servidor pronto: %d conceitos, %d palavras no vocabulário", #Catalog.Concepts, Lexicon.size()))
end

return Bootstrap
