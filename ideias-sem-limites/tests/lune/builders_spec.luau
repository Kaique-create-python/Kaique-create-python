--!nocheck
-- Constrói TODOS os modelos do catálogo fora do Roblox (Lune) e verifica:
--   * nenhum erro de construção (propriedade inexistente, tipo errado...)
--   * quantidade de partes dentro do orçamento por categoria
--   * rigs de criaturas têm HumanoidRootPart, Humanoid e juntas válidas
--   * todas as variações de modificadores (escala, elemento, material) funcionam

local roblox = require("@lune/roblox")

local Spec = {}

local LIMITS = { creature = 140, vehicle = 160, building = 650, object = 90, food = 90, nature = 90 }

function Spec.run(env, Harness)
	local shared = env.find("ReplicatedStorage.IdeiasShared")
	local server = env.find("ServerScriptService.IdeiasServer")
	local Catalog = env.require(shared.Catalog)
	local Planner = env.require(shared.Planner)
	local Rng = env.require(shared.Util.Rng)
	local Builders = env.require(server.Builders)
	local ws = env.game:GetService("Workspace")

	local passed, failed = 0, 0
	local report = {}
	local partCounts = {}
	local function fail(msg)
		failed += 1
		print("  FALHOU: " .. msg)
	end

	local variants = {
		{},
		{ "giant" },
		{ "fire" },
		{ "gold" },
		{ "ice", "small" },
		{ "robotic" },
		{ "ghostly" },
		{ "rainbow" },
		{ "red" },
	}

	local t0 = os.clock()
	for _, def in Catalog.Concepts do
		if def.handler == "npc" or def.handler == "vehicle" or def.handler == "building" or def.handler == "prop" then
			for vi, modIds in variants do
				local mods = {}
				for _, id in modIds do
					local m = Catalog.ModifierById[id]
					if def.axes[m.axis] then
						table.insert(mods, m)
					end
				end
				local params = Planner.applyMods(def, mods)
				params.rng = Rng.new(vi * 1000 + #def.id)
				local origin = roblox.CFrame.new(vi * 50, 0, 0)
				local ok, model, height = pcall(Builders.any, def, origin, params)
				if not ok then
					fail(string.format("%s [%s]: %s", def.id, table.concat(modIds, "+"), tostring(model)))
				elseif not model then
					fail(def.id .. ": nenhum modelo")
				else
					local parts = 0
					local joints = 0
					local badJoint = false
					for _, d in model:GetDescendants() do
						if d:IsA("BasePart") then
							parts += 1
							if d.Size.X ~= d.Size.X or d.Size.X <= 0 then
								badJoint = true
							end
						elseif d:IsA("Motor6D") then
							joints += 1
							if not d.Part0 or not d.Part1 then
								badJoint = true
							end
						end
					end
					if vi == 1 then
						partCounts[def.id] = parts
					end
					local limit = LIMITS[def.category] or 120
					if parts > limit then
						fail(string.format("%s: %d partes (limite %d)", def.id, parts, limit))
					elseif parts < 3 then
						fail(string.format("%s: só %d partes", def.id, parts))
					elseif badJoint then
						fail(def.id .. ": junta ou parte inválida")
					elseif def.handler == "npc" and (not model:FindFirstChild("HumanoidRootPart") or not model:FindFirstChildOfClass("Humanoid")) then
						fail(def.id .. ": rig sem HumanoidRootPart/Humanoid")
					elseif def.handler == "npc" and joints < 1 then
						fail(def.id .. ": criatura sem juntas animadas")
					elseif not model.PrimaryPart then
						fail(def.id .. ": sem PrimaryPart")
					elseif type(height) ~= "number" or height <= 0 then
						fail(def.id .. ": altura inválida")
					else
						passed += 1
					end
					model.Parent = nil
				end
			end
		end
	end
	-- estatísticas
	local total, n, maxId, maxN = 0, 0, "", 0
	for id, c in partCounts do
		total += c
		n += 1
		if c > maxN then
			maxN, maxId = c, id
		end
	end
	print(string.format("  %d modelos construídos (%d variações), %d falhas, %.2fs", n, passed + failed, failed, os.clock() - t0))
	print(string.format("  média %.1f partes por modelo; maior: %s (%d)", total / math.max(n, 1), maxId, maxN))
	Spec.partCounts = partCounts
	return { passed = passed, failed = failed }
end

return Spec
