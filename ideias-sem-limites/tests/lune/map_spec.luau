--!nocheck
-- Gera o mapa completo no Lune e verifica orçamento de peças por região,
-- operações de terreno e presença dos elementos principais.

local Spec = {}

local REGION_LIMIT = { hub = 1000, forest = 1700, city = 1700, glacier = 1500, volcano = 900, desert = 700, beach = 700, sky = 500, arena = 300, estradas = 900 }
local TOTAL_LIMIT = 9500

function Spec.run(env, Harness)
	local server = env.find("ServerScriptService.IdeiasServer")
	local MapBuilder = env.require(server.Map.MapBuilder)
	local failed = 0
	local function fail(msg)
		failed += 1
		print("  FALHOU: " .. msg)
	end
	local t0 = os.clock()
	local ok, stats = pcall(MapBuilder.build, { fast = true })
	if not ok then
		fail("geração do mapa: " .. tostring(stats))
		return { passed = 0, failed = failed }
	end
	print(string.format("  mapa gerado em %.2fs (offline), %d peças, %d operações de terreno", os.clock() - t0, stats.parts, #Harness.terrainLog))
	local names = {}
	for id, n in stats.regions do
		table.insert(names, string.format("%s=%d", id, n))
		local limit = REGION_LIMIT[id]
		if limit and n > limit then
			fail(string.format("região %s com %d peças (limite %d)", id, n, limit))
		end
		if id ~= "destrutiveis" and n < 20 then
			fail(string.format("região %s quase vazia (%d peças)", id, n))
		end
	end
	table.sort(names)
	print("  " .. table.concat(names, ", "))
	if stats.parts > TOTAL_LIMIT then
		fail(string.format("mapa com %d peças (limite %d para celular)", stats.parts, TOTAL_LIMIT))
	end
	local ws = env.game:GetService("Workspace")
	local mapa = ws:FindFirstChild("Mapa")
	if not mapa then
		fail("pasta Mapa ausente")
	else
		local tele, pads, hazards, lights = 0, 0, 0, 0
		for _, d in mapa:GetDescendants() do
			if d:HasTag("IdeiasTeleporte") then
				tele += 1
			end
			if d:HasTag("IdeiasPulo") then
				pads += 1
			end
			if d:HasTag("Perigo") then
				hazards += 1
			end
			if d:IsA("PointLight") or d:IsA("SpotLight") then
				lights += 1
			end
		end
		print(string.format("  teleportes=%d, saltos=%d, perigos=%d, luzes=%d", tele, pads, hazards, lights))
		if tele < 8 then
			fail("poucos teleportes: " .. tele)
		end
		if lights > 120 then
			fail("luzes demais para celular: " .. lights)
		end
	end
	return { passed = if failed == 0 then 1 else 0, failed = failed }
end

return Spec
