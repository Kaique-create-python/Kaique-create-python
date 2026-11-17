local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local V3, CF = roblox.Vector3, roblox.CFrame
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local partes = {}
for _, d in game:GetService("Workspace"):GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide ~= false and d.ClassName ~= "Terrain" then table.insert(partes, d) end
end
for _, item in serde.decode("json", fs.readFile(process.args[2])) do
	local p = roblox.Instance.new("Part"); p.Name = item.nome
	p.CFrame = CF.new(table.unpack(item.cf)); p.Size = V3.new(item.size[1], item.size[2], item.size[3])
	table.insert(partes, p)
end
local function sobrepoe(cfA, meia, parte)
	local cf, h = parte.CFrame, parte.Size / 2
	local A = { cfA.RightVector, cfA.UpVector, -cfA.LookVector }
	local B = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local ma, mb = { meia.X, meia.Y, meia.Z }, { h.X, h.Y, h.Z }
	local t = cf.Position - cfA.Position
	local eixos = {}
	for _, a in A do table.insert(eixos, a) end
	for _, b in B do table.insert(eixos, b) end
	for _, a in A do for _, b in B do local c = a:Cross(b); if c.Magnitude > 1e-6 then table.insert(eixos, c.Unit) end end end
	for _, ax in eixos do
		local ra, rb = 0, 0
		for i = 1, 3 do ra += ma[i] * math.abs(A[i]:Dot(ax)); rb += mb[i] * math.abs(B[i]:Dot(ax)) end
		if math.abs(t:Dot(ax)) > ra + rb then return false end
	end
	return true
end
local N = { V3.new(0,0,-260), V3.new(-58,0,-260), V3.new(58,0,-260), V3.new(0,0,-300), V3.new(0,0,-360), V3.new(0,0,-400), V3.new(0,0,-440),
	V3.new(-58,0,-440), V3.new(58,0,-440), V3.new(58,0,-300), V3.new(58,0,-338), V3.new(58,0,-400), V3.new(-58,0,-300), V3.new(-58,0,-338), V3.new(-58,0,-400) }
local E = {{1,2},{1,3},{1,4},{4,5},{5,6},{6,7},{7,8},{7,9},{3,10},{10,11},{11,12},{12,9},{2,13},{13,14},{14,15},{15,8}}
local meia = V3.new(4.35, 9.09, 2.19) / 2
local ruins = 0
for _, e in E do
	local a, b = N[e[1]], N[e[2]]
	local dir = (b - a).Unit
	local passos = math.ceil((b - a).Magnitude / 1.5)
	local bloqueio = nil
	for i = 0, passos do
		local p = a + (b - a) * (i / passos)
		local cf = CF.lookAt(p + V3.new(0, 4.67, 0), p + V3.new(0, 4.67, 0) + dir)
		for _, parte in partes do
			if sobrepoe(cf, meia, parte) then bloqueio = string.format("%s em %s", parte:GetFullName(), tostring(p)); break end
		end
		if bloqueio then break end
	end
	if bloqueio then ruins += 1 end
	print(string.format("%2d-%2d %s", e[1], e[2], bloqueio or "livre"))
end
print(if ruins == 0 then "PASS todos os trilhos livres" else ("FALHA " .. ruins .. " trilhos bloqueados"))
