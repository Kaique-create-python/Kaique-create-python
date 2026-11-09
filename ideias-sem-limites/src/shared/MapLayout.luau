--!strict
-- Disposição das regiões do mapa (compartilhado entre servidor e cliente).
-- Coordenadas em studs. O mapa é uma ilha de ~1250 studs de diâmetro cercada
-- por oceano; o centro de criação fica na origem.

local MapLayout = {}

export type Region = {
	id: string,
	label: string,
	center: Vector3,
	radius: number,
	color: Color3,
	ambient: string,
}

MapLayout.IslandRadius = 600
MapLayout.SeaLevel = -3

MapLayout.Regions = {
	{ id = "hub", label = "Centro de Criação", center = Vector3.new(0, 0, 0), radius = 95, color = Color3.fromRGB(90, 200, 255), ambient = "hub" },
	{ id = "forest", label = "Floresta Encantada", center = Vector3.new(0, 0, -370), radius = 175, color = Color3.fromRGB(110, 220, 120), ambient = "forest" },
	{ id = "city", label = "Cidade Neon", center = Vector3.new(370, 0, 0), radius = 170, color = Color3.fromRGB(255, 80, 220), ambient = "city" },
	{ id = "glacier", label = "Região Glacial", center = Vector3.new(0, 0, 370), radius = 175, color = Color3.fromRGB(170, 230, 255), ambient = "glacier" },
	{ id = "volcano", label = "Região Vulcânica", center = Vector3.new(-370, 0, 0), radius = 175, color = Color3.fromRGB(255, 110, 40), ambient = "volcano" },
	{ id = "desert", label = "Deserto das Ruínas", center = Vector3.new(300, 0, -300), radius = 120, color = Color3.fromRGB(240, 200, 120), ambient = "desert" },
	{ id = "beach", label = "Praia dos Coqueiros", center = Vector3.new(-310, 0, 310), radius = 120, color = Color3.fromRGB(255, 230, 160), ambient = "beach" },
	{ id = "sky", label = "Ilhas Flutuantes", center = Vector3.new(-290, 190, -290), radius = 110, color = Color3.fromRGB(200, 170, 255), ambient = "sky" },
	{ id = "arena", label = "Arena Subterrânea", center = Vector3.new(300, -120, 300), radius = 70, color = Color3.fromRGB(255, 70, 70), ambient = "arena" },
} :: { Region }

MapLayout.ById = {} :: { [string]: Region }
for _, r in MapLayout.Regions do
	MapLayout.ById[r.id] = r
end

-- região mais próxima de uma posição (para missões "visite..." e música ambiente)
function MapLayout.regionAt(pos: Vector3): Region
	local best, bestD = MapLayout.Regions[1], math.huge
	for _, r in MapLayout.Regions do
		local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(r.center.X, 0, r.center.Z)).Magnitude / r.radius
		if r.id == "sky" then
			d = if pos.Y > 120 then d * 0.5 else math.huge
		elseif r.id == "arena" then
			d = if pos.Y < -60 then 0 else math.huge
		end
		if d < bestD then
			best, bestD = r, d
		end
	end
	return best
end

return MapLayout
