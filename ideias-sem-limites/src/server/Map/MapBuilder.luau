--!strict
-- Gera o mundo inteiro de forma determinística (mesma semente = mesmo mapa).
-- Ilha cercada por oceano (terreno), regiões temáticas, estradas e decoração.
-- Pode ser chamado de novo para "reconstruir" o mapa (restauração completa).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.IdeiasShared
local Config = require(Shared.Config)
local Rng = require(Shared.Util.Rng)
local Hash = require(Shared.Util.Hash)
local MapLayout = require(Shared.MapLayout)
local MapKit = require(script.Parent.MapKit)

local Regions = script.Parent.Regions
local Outlands = require(Regions.Outlands)
local REGION_MODULES = {
	require(Regions.Hub),
	require(Regions.Forest),
	require(Regions.City),
	require(Regions.Glacier),
	require(Regions.Volcano),
	Outlands.Desert,
	Outlands.Beach,
	Outlands.Sky,
	Outlands.Arena,
}

local MapBuilder = {}

local function islandBase()
	local M = Enum.Material
	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(40, 140, 190)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.5
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 8
	-- oceano
	MapKit.fillBlock(CFrame.new(0, -12, 0), Vector3.new(1600, 16, 1600), M.Water)
	-- praia em volta e ilha
	MapKit.fillCylinder(CFrame.new(0, -11, 0), 16, 620, M.Sand)
	MapKit.fillCylinder(CFrame.new(0, -10, 0), 20, 585, M.Grass)
	-- leito do mar (fundo)
	MapKit.fillBlock(CFrame.new(0, -24, 0), Vector3.new(1600, 8, 1600), M.Sand)
end

local function roads(folder: Instance)
	local M = Enum.Material
	local Kit = require(script.Parent.Parent.Builders).Kit
	local b = Kit.new("Estradas", CFrame.identity, { anchored = true, collide = true })
	for _, r in MapLayout.Regions do
		if r.id ~= "hub" and r.id ~= "sky" and r.id ~= "arena" then
			local dir = Vector3.new(r.center.X, 0, r.center.Z).Unit
			local startD, endD = 96, (Vector3.new(r.center.X, 0, r.center.Z)).Magnitude - r.radius * 0.45
			local d = startD
			while d < endD do
				local p = dir * (d + 6)
				local y = MapKit.heightAt(p.X, p.Z)
				b:box(Vector3.new(12, 0.5, 12.4), CFrame.lookAt(Vector3.new(p.X, y + 0.2, p.Z), Vector3.new(p.X + dir.X, y + 0.2, p.Z + dir.Z)), Color3.fromRGB(165, 155, 140), { role = "fixed", material = M.Cobblestone })
				-- bordas e postes de luz a cada 48 studs
				if math.floor(d) % 48 < 12 then
					local side = dir:Cross(Vector3.yAxis)
					local lp = p + side * 8
					b:cylY(9, 0.5, CFrame.new(lp.X, y + 4.5, lp.Z), Color3.fromRGB(50, 50, 58), { role = "fixed", material = M.Metal })
					b:ball(1.4, CFrame.new(lp.X, y + 9.4, lp.Z), r.color, { role = "fixed", material = M.Neon })
				end
				d += 12
			end
		end
	end
	local m = b:finish()
	m.Parent = folder
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

export type Stats = { parts: number, regions: { [string]: number }, seconds: number, terrainOps: number? }

function MapBuilder.build(opts: { fast: boolean?, seed: number? }?): Stats
	local o = opts or {}
	local t0 = os.clock()
	local seed = o.seed or Config.WorldSeed
	MapKit.resetTerrain()
	local old = Workspace:FindFirstChild("Mapa")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Mapa"
	root.Parent = Workspace
	local destr = Instance.new("Model")
	destr.Name = "Destrutiveis"
	destr:AddTag("DestrutivelGrupo")
	destr.Parent = root

	islandBase()
	local stats: Stats = { parts = 0, regions = {}, seconds = 0 }
	for _, mod in REGION_MODULES do
		local region = MapLayout.ById[mod.id]
		local folder = Instance.new("Model")
		folder.Name = "Regiao_" .. mod.id
		folder:SetAttribute("Regiao", mod.id)
		folder.Parent = root
		local rng = Rng.new(seed + Hash.str(mod.id) % 100000)
		local ctx = MapKit.region(folder, destr, rng, region.center)
		local ok, err = pcall(mod.build, ctx)
		if not ok then
			warn("[Ideias] região " .. mod.id .. " falhou: " .. tostring(err))
		end
		stats.regions[mod.id] = ctx.parts
		stats.parts += ctx.parts
		if not o.fast then
			task.wait()
		end
	end
	local roadParts = roads(root)
	stats.regions.estradas = roadParts
	stats.parts += roadParts
	local destrCount = 0
	for _, d in destr:GetDescendants() do
		if d:IsA("BasePart") then
			destrCount += 1
		end
	end
	stats.regions.destrutiveis = destrCount
	stats.seconds = os.clock() - t0
	-- as plataformas iniciais do arquivo ficam sob o palco
	local spawn = Workspace:FindFirstChild("SpawnCentral") :: BasePart?
	if spawn then
		spawn.CFrame = CFrame.new(0, MapKit.heightAt(0, 34) + 1.4, 34)
	end
	return stats
end

return MapBuilder
