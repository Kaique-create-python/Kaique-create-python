-- Executes only report/destination/source/preservation boundaries under Lune.
-- This does not emulate native asset, GUI, physics, or animation results.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local source = fs.readFile("src/teste_nuvem.luau")

local function node(name, kind, contents)
	local obj = { Name = name, ClassName = kind, children = contents or {} }
	function obj:GetChildren() return self.children end
	function obj:GetDescendants()
		local result = {}
		for _, child in self.children do
			table.insert(result, child)
			for _, descendant in child:GetDescendants() do table.insert(result, descendant) end
		end
		return result
	end
	function obj:FindFirstChild(query)
		for _, child in self.children do if child.Name == query then return child end end
		return nil
	end
	function obj:IsA(kindToCheck) return self.ClassName == kindToCheck end
	return obj
end
local function config()
	return { package = "BASTIAO-ETAPA-3", stage = 3, universe = 10776462844, place = 89520940302906,
		hashes = { { path = { "ReplicatedStorage", "Sample" }, class = "ModuleScript", bytes = 1, hash = "0002b61d" } } }
end
local function execute(cfg, options)
	options = options or {}
	local sample = node("Sample", "ModuleScript")
	sample.Source = options.changed and "y" or "x"
	local storage = node("ReplicatedStorage", "ReplicatedStorage", { sample })
	if options.duplicate then table.insert(storage.children, sample) end
	local server = node("ServerScriptService", "ServerScriptService")
	local player = node("StarterPlayer", "StarterPlayer")
	local map = node("Sector7World", "Model")
	function map:GetDescendants() return table.create(if options.smallMap then 7999 else 8000, true) end
	local workspace = node("Workspace", "Workspace", if options.missingMap then {} else { map })
	local game = node("game", "DataModel", { storage, server, player })
	game.GameId, game.PlaceId = options.gameId or 10776462844, options.placeId or 89520940302906
	local services = {
		HttpService = { JSONEncode = function(_, value) return serde.encode("json", value) end },
		LogService = {}, ReplicatedStorage = storage, ServerScriptService = server,
		StarterPlayer = player, TweenService = {}, CollectionService = {},
	}
	function game:GetService(name) assert(services[name], name); return services[name] end
	-- Pass cfg as a global through a one-line local rather than serialize Luau.
	local code = "local cfg = providedConfig\n" .. source
	local result = luau.load(code, { environment = { providedConfig = cfg, game = game, workspace = workspace }, injectGlobals = true })()
	return serde.decode("json", result)
end
local cases = 0
local function hasError(result, phrase)
	assert(result.passed == false, "an incomplete native run must never pass")
	for _, err in result.erros do if string.find(err, phrase, 1, true) then cases += 1; return end end
	error("expected report error: " .. phrase)
end
local wrongStage = config()
wrongStage.stage = 2
hasError(execute(wrongStage), "Destino/pacote incorreto")
hasError(execute(config(), { gameId = 1 }), "não pertence ao universo/place")
hasError(execute(config(), { placeId = 1 }), "não pertence ao universo/place")
local noHashes = config()
noHashes.hashes = {}
hasError(execute(noHashes), "Mapa de hashes obrigatório está vazio")
hasError(execute(config(), { changed = true }), "Fonte divergiu do pacote")
hasError(execute(config(), { duplicate = true }), "Fonte ausente, ambígua ou de outra classe")
local absent = config()
absent.hashes[1].path = { "ReplicatedStorage", "Missing" }
hasError(execute(absent), "Fonte ausente, ambígua ou de outra classe")
local wrongClass = config()
wrongClass.hashes[1].class = "Script"
hasError(execute(wrongClass), "Fonte ausente, ambígua ou de outra classe")
local validated = execute(config())
assert(validated.info.fontes == 1, "valid source/hash should be counted")
hasError(validated, "Parte do jogo base ausente")
hasError(execute(config(), { missingMap = true }), "Sector7World ausente")
hasError(execute(config(), { smallMap = true }), "Sector7World incompleto")
print("PASS " .. cases .. " native report boundary cases under Lune; engine-only checks not executed")
