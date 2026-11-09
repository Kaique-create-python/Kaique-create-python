-- Testes na nuvem: enviado pela Luau Execution API para uma versão SALVA do
-- lugar. Roda no motor real do Roblox (sem jogadores). Scripts do lugar não
-- iniciam sozinhos nessa execução, então os testes ligam o servidor.
-- Retorna um resumo em JSON (lido pelo ideias.sh).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function trim(r)
	if type(r) ~= "table" then
		return { erro = tostring(r) }
	end
	local failures = {}
	for i, f in r.failures or {} do
		if i > 40 then
			table.insert(failures, string.format("... e mais %d", #r.failures - 40))
			break
		end
		table.insert(failures, f)
	end
	return { passou = r.passed, falhou = r.failed, falhas = failures }
end

local out = { ok = false }
local t0 = os.clock()

local shared = ReplicatedStorage:WaitForChild("IdeiasShared", 15)
local server = ServerScriptService:WaitForChild("IdeiasServer", 15)
if not shared or not server then
	out.erro = "IdeiasShared/IdeiasServer não encontrados nesta versão do lugar"
	return out
end

local okP, parser = pcall(function()
	local Spec = require(shared.Tests.ParserSpec)
	return Spec.run({
		Planner = require(shared.Planner),
		Catalog = require(shared.Catalog),
		Lexicon = require(shared.Lexicon),
	})
end)
out.interpretador = if okP then trim(parser) else { erro = tostring(parser) }
print(string.format("[nuvem] interpretador: %s", if okP then (parser.passed .. " ok / " .. parser.failed .. " falhas") else tostring(parser)))

local okS, srv = pcall(function()
	local Spec = require(server.Tests.ServerSpec)
	return Spec.run({ quick = false, map = true })
end)
out.servidor = if okS then trim(srv) else { erro = tostring(srv) }
if okS then
	out.estatisticas = {
		inicioSegundos = srv.stats.bootSeconds,
		conceitosSegundos = srv.stats.conceptSeconds,
		mapa = srv.stats.map,
		porExecutor = srv.stats.perHandler,
		estresseMaxAcontecimentos = srv.stats.stressMaxEvents,
		estresseMaxNpcs = srv.stats.stressMaxNpcs,
		gerenciador = srv.stats.eventManager,
	}
	print(string.format("[nuvem] servidor: %d ok / %d falhas", srv.passed, srv.failed))
end
out.segundos = os.clock() - t0
out.ok = okP and okS and parser.failed == 0 and srv.failed == 0
return out
