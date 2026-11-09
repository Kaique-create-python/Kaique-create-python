--!strict
-- Ponto de entrada dos pedidos: RemoteFunction "Criar" -> porteiro ->
-- interpretador -> gerenciador -> progressão -> resposta ao cliente.
-- Para os outros jogadores só vão rótulos do catálogo e o DisplayName (já
-- filtrado pelo Roblox): nenhum texto livre digitado é retransmitido.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.IdeiasShared
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Planner = require(Shared.Planner)
local RequestGate = require(script.Parent.RequestGate)
local EventManager = require(script.Parent.EventManager)

local Requests = {}

Requests.progress = nil :: any
Requests.log = {} :: { any }

local function icon(plan: any): string
	local first = plan.events[1]
	local info = first and Catalog.CategoryInfo[first.concept.category]
	return if info then info.icon else "💡"
end

function Requests.handle(player: Player, raw: any): { [string]: any }
	local verdict = RequestGate.check(player, raw)
	if not verdict.ok then
		return {
			ok = false,
			reason = verdict.reason,
			wait = verdict.wait,
			message = RequestGate.Messages[verdict.reason or "invalid"] or "Não foi possível criar.",
		}
	end
	local okPlan, plan = pcall(Planner.plan, verdict.text :: string)
	if not okPlan then
		warn("[Ideias] interpretador falhou: " .. tostring(plan))
		return { ok = false, reason = "invalid", message = "Não entendi essa ideia." }
	end
	local result = EventManager.executePlan(plan, player)
	if #Requests.log > 50 then
		table.remove(Requests.log, 1)
	end
	table.insert(Requests.log, { user = player.UserId, label = plan.label, ok = result.ok, t = os.time() })
	if not result.ok then
		return {
			ok = false,
			reason = result.reason or "full",
			message = RequestGate.Messages[result.reason or "full"] or "O mundo está cheio.",
			notes = result.notes,
		}
	end
	local prog = { discovered = {}, secrets = {} }
	if Requests.progress then
		local okP, res = pcall(Requests.progress.onPlan, player, plan)
		if okP then
			prog = res
		end
	end
	-- avisa todo mundo (só textos do catálogo)
	local estado = ReplicatedStorage.IdeiasRemotes:FindFirstChild("Estado") :: RemoteEvent?
	if estado then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				estado:FireClient(other, "feed", { name = player.DisplayName, label = plan.label, icon = icon(plan) })
			end
		end
	end
	local notes = table.clone(plan.notes)
	for _, n in result.notes do
		table.insert(notes, n)
	end
	return {
		ok = true,
		label = plan.label,
		icon = icon(plan),
		surprise = plan.surprise,
		notes = notes,
		cooldown = Config.Request.Cooldown,
		discovered = prog.discovered,
		secrets = prog.secrets,
		corrected = #plan.corrections > 0,
	}
end

return Requests
