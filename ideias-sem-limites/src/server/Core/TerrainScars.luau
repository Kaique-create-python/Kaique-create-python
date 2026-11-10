--!strict
-- Marcas no mapa: crateras de meteoro/nuke e rachaduras de terremoto cavadas
-- no Terrain de verdade. Antes de cavar, a região é copiada (CopyRegion) e
-- depois de alguns segundos é colada de volta (PasteRegion): o mapa se conserta
-- sozinho. Limite de marcas simultâneas para não pesar.

local Workspace = game:GetService("Workspace")

local TerrainScars = {}

TerrainScars.MAX_ACTIVE = 6
local active = 0

local function cell(v: Vector3): Vector3int16
	return Vector3int16.new(math.floor(v.X / 4), math.floor(v.Y / 4), math.floor(v.Z / 4))
end

-- executa `carve` dentro de uma caixa (centro ± half), restaurando depois de `restoreAfter`
function TerrainScars.scar(center: Vector3, half: Vector3, restoreAfter: number, carve: (Terrain) -> ()): boolean
	if active >= TerrainScars.MAX_ACTIVE then
		return false
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return false
	end
	local lo, hi = cell(center - half), cell(center + half)
	local ok, region = pcall(function()
		return terrain:CopyRegion(Region3int16.new(lo, hi))
	end)
	if not ok or not region then
		return false
	end
	active += 1
	pcall(carve, terrain)
	task.delay(restoreAfter, function()
		pcall(function()
			terrain:PasteRegion(region, lo, true)
		end)
		active -= 1
	end)
	return true
end

-- cratera redonda com fundo de lava (ou gelo)
function TerrainScars.crater(pos: Vector3, radius: number, element: string?, restoreAfter: number?): boolean
	local r = math.clamp(radius, 4, 48)
	return TerrainScars.scar(pos, Vector3.new(r + 8, r + 8, r + 8), restoreAfter or 45, function(t)
		t:FillBall(pos, r, Enum.Material.Air)
		local bottom = pos - Vector3.new(0, r * 0.75, 0)
		t:FillBall(bottom, r * 0.45, if element == "ice" then Enum.Material.Glacier else Enum.Material.CrackedLava)
		t:FillBall(pos - Vector3.new(0, r * 0.2, 0) + Vector3.new(r * 0.9, 0, 0), r * 0.25, Enum.Material.Basalt)
		t:FillBall(pos - Vector3.new(0, r * 0.2, 0) - Vector3.new(r * 0.9, 0, 0), r * 0.25, Enum.Material.Basalt)
	end)
end

-- rachaduras em linha saindo do centro (terremoto)
function TerrainScars.cracks(center: Vector3, count: number, length: number, rng: any, restoreAfter: number?): boolean
	local L = math.clamp(length, 20, 70)
	return TerrainScars.scar(center, Vector3.new(L + 8, 26, L + 8), restoreAfter or 40, function(t)
		for _ = 1, count do
			local a = rng:range(0, math.pi * 2)
			local len = rng:range(L * 0.5, L)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local mid = center + dir * (len / 2 + 4)
			local cf = CFrame.lookAt(mid, mid + dir)
			t:FillBlock(cf, Vector3.new(rng:range(3, 6), 16, len), Enum.Material.Air)
			t:FillBlock(cf * CFrame.new(0, -9, 0), Vector3.new(2, 3, len * 0.9), Enum.Material.CrackedLava)
		end
	end)
end

return TerrainScars
