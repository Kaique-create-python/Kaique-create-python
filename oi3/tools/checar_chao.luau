-- Diagnóstico: o que está por cima do assoalho em vários pontos da casa (Lune)
local H = require("./harness")
local roblox = require("@lune/roblox")
local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
local ws = H.dm:GetService("Workspace")
local modelo = Mapa.construir(ws)
local F = Mapa.L.F
local pecas = {}
for _, d in modelo:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.9 then
		table.insert(pecas, d)
	end
end
local function topoEm(x, z)
	local melhor, alto = nil, -math.huge
	for _, p in pecas do
		local cf, s = p.CFrame, p.Size
		local q = cf:PointToObjectSpace(roblox.Vector3.new(x, cf.Position.Y, z))
		if math.abs(q.X) <= s.X / 2 and math.abs(q.Y) <= s.Y / 2 + 0.01 and math.abs(q.Z) <= s.Z / 2 then
			-- topo aproximado (peça sem giro grande)
			local topo = cf.Position.Y + math.abs(cf.UpVector.Y) * s.Y / 2
			if topo > alto and topo < F + 0.6 and topo > F - 0.6 then
				melhor, alto = p, topo
			end
		end
	end
	return melhor, alto
end
local cont = {}
for x = -30, 70, 2.5 do
	for z = -22, 22, 2.5 do
		local p, t = topoEm(x + 0.31, z + 0.17)
		local k = if p then string.format("%s | %s | %s | %s", p.Name, tostring(p.Material), p.MaterialVariant, tostring(p.Color)) else "NADA"
		cont[k] = (cont[k] or 0) + 1
	end
end
local lista = {}
for k, n in cont do table.insert(lista, { k, n }) end
table.sort(lista, function(a, b) return a[2] > b[2] end)
for i, e in lista do if i <= 6 then print(e[2], e[1]) end end
print("--- tapetes (tecido no chão)")
for _, p in pecas do
	local topo = p.CFrame.Position.Y + p.Size.Y / 2
	if p.Material == roblox.Enum.Material.Fabric and topo > F - 0.2 and topo < F + 0.4 and p.Size.X * p.Size.Z > 4 then
		print(string.format("  %s em (%.1f, %.1f) tam %.1f x %.1f topo %.2f cor %s pai %s", p.Name, p.CFrame.Position.X, p.CFrame.Position.Z, p.Size.X, p.Size.Z, topo, tostring(p.Color), p.Parent and p.Parent.Name or "?"))
	end
end
print("--- tecido perto do piso (qualquer forma)")
for _, p in pecas do
	local y = p.CFrame.Position.Y
	local maior = math.max(p.Size.X, p.Size.Y, p.Size.Z)
	if p.Material == roblox.Enum.Material.Fabric and y > F - 0.3 and y < F + 0.3 and maior > 3 then
		print(string.format("  %s %s em (%.1f, %.2f, %.1f) tam %.1f x %.1f x %.1f cor %d,%d,%d", p.Name, p.ClassName, p.CFrame.Position.X, y, p.CFrame.Position.Z, p.Size.X, p.Size.Y, p.Size.Z, p.Color.R * 255, p.Color.G * 255, p.Color.B * 255))
	end
end
print("--- pontos onde a laje escura aparece (sem tábua por cima)")
local n = 0
local saida = {}
for x = -30, 70, 2.5 do
	for z = -22, 22, 2.5 do
		local p = topoEm(x + 0.31, z + 0.17)
		if p and p.Material == roblox.Enum.Material.SmoothPlastic and n < 40 then
			n += 1
			table.insert(saida, string.format("(%.1f, %.1f)", x + 0.31, z + 0.17))
		end
	end
end
print(table.concat(saida, " "))
