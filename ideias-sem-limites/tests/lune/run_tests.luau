--!nocheck
-- Executa a suíte offline: lune run tests/lune/run_tests.luau <arquivo.rbxl> [grupo]
-- grupos: parser | builders | map | all (padrão)

local process = require("@lune/process")
local Harness = require("./harness")

local placePath = process.args[1] or "build/IdeiasSemLimites_V3.rbxl"
local group = process.args[2] or "all"

local env = Harness.load(placePath)
local totalFailed = 0

local function section(title)
	print("\n== " .. title .. " ==")
end

if group == "syntax" or group == "all" then
	section("Sintaxe de todos os scripts (compilador Luau)")
	local luau = require("@lune/luau")
	local n, bad = 0, 0
	for _, d in env.game:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			n += 1
			local ok, err = pcall(luau.compile, d.Source)
			if not ok then
				bad += 1
				print("  FALHOU: " .. d:GetFullName() .. ": " .. tostring(err))
			end
		end
	end
	print(string.format("  %d scripts compilados, %d com erro", n, bad))
	totalFailed += bad
end

if group == "parser" or group == "all" then
	section("Interpretador de palavras")
	local shared = env.find("ReplicatedStorage.IdeiasShared")
	local Spec = env.require(shared.Tests.ParserSpec)
	local t0 = os.clock()
	local result = Spec.run({
		Planner = env.require(shared.Planner),
		Catalog = env.require(shared.Catalog),
		Lexicon = env.require(shared.Lexicon),
	})
	for _, f in result.failures do
		print("  FALHOU: " .. f)
	end
	print(string.format("  %d passaram, %d falharam (%.2fs)", result.passed, result.failed, os.clock() - t0))
	totalFailed += result.failed
end

if group == "builders" or group == "all" then
	local ok, Suite = pcall(require, "./builders_spec")
	if ok then
		section("Construtores de modelos")
		local r = Suite.run(env, Harness)
		totalFailed += r.failed
	end
end

if group == "map" or group == "all" then
	local ok, Suite = pcall(require, "./map_spec")
	if ok then
		section("Mapa procedural")
		local r = Suite.run(env, Harness)
		totalFailed += r.failed
	end
end

if #Harness.warnings > 0 then
	print(string.format("\n%d avisos (warn) durante os testes; primeiros:", #Harness.warnings))
	for i = 1, math.min(5, #Harness.warnings) do
		print("  " .. Harness.warnings[i])
	end
end

print(if totalFailed == 0 then "\nRESULTADO: TUDO OK" else string.format("\nRESULTADO: %d FALHAS", totalFailed))
process.exit(if totalFailed == 0 then 0 else 1)
