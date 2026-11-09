--!nocheck
-- Exporta peças (forma, CFrame, tamanho, cor, material) para JSON, para
-- pré-visualizar modelos e o mapa fora do Roblox (renderizador three.js).
-- Uso:
--   lune run tools/dev/exportar_cena.luau <place.rbxl> modelos id1,id2,... > cena.json
--   lune run tools/dev/exportar_cena.luau <place.rbxl> mapa > mapa.json

local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Harness = require("../../tests/lune/harness")

local placePath = process.args[1]
local mode = process.args[2] or "modelos"
local env = Harness.load(placePath)

local shapes = {}
local function export(inst)
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			local shape = "Block"
			if d.ClassName == "Part" then
				shape = d.Shape.Name
				local sm = d:FindFirstChildOfClass("SpecialMesh")
				if sm and sm.MeshType == roblox.Enum.MeshType.Sphere then
					shape = "Ellipsoid"
				end
			elseif d.ClassName == "WedgePart" then
				shape = "Wedge"
			elseif d.ClassName == "CornerWedgePart" then
				shape = "CornerWedge"
			end
			local cf = d.CFrame
			local c = { cf:GetComponents() }
			local col = d.Color
			table.insert(shapes, {
				s = shape,
				cf = c,
				z = { d.Size.X, d.Size.Y, d.Size.Z },
				c = { math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255) },
				m = d.Material.Name,
				t = d.Transparency,
			})
		end
	end
end

local shared = env.find("ReplicatedStorage.IdeiasShared")
local server = env.find("ServerScriptService.IdeiasServer")

if mode == "modelos" then
	local Catalog = env.require(shared.Catalog)
	local Planner = env.require(shared.Planner)
	local Rng = env.require(shared.Util.Rng)
	local Builders = env.require(server.Builders)
	local ids = {}
	for id in string.gmatch(process.args[3] or "dragon", "[^,]+") do
		table.insert(ids, id)
	end
	local mods = {}
	for id in string.gmatch(process.args[4] or "", "[^,]+") do
		table.insert(mods, env.require(shared.Catalog).ModifierById[id])
	end
	local cols = math.ceil(math.sqrt(#ids))
	local spacing = tonumber(process.args[5]) or 24
	for i, id in ids do
		local def = Catalog.ById[id]
		if def then
			local accepted = {}
			for _, m in mods do
				if def.axes[m.axis] then
					table.insert(accepted, m)
				end
			end
			local params = Planner.applyMods(def, accepted)
			params.rng = Rng.new(i * 77)
			local x = ((i - 1) % cols) * spacing
			local z = math.floor((i - 1) / cols) * spacing
			local model = Builders.any(def, roblox.CFrame.new(x, 0, z) * roblox.CFrame.Angles(0, math.pi * 0.85, 0), params)
			if model then
				model.Name = id
				export(model)
			end
		end
	end
elseif mode == "mapa" then
	local Map = env.require(server.Map.MapBuilder)
	local ws = env.game:GetService("Workspace")
	Map.build({ fast = true })
	export(ws)
	print(serde.encode("json", { parts = shapes, terrain = Harness.terrainLog }))
	return
end

print(serde.encode("json", { parts = shapes }))
