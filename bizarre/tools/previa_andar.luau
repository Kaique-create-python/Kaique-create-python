-- BIZARRE :: prévia do andar (R6) — gera quadros JSON para o renderizador three.js
-- uso (na raiz): lune run bizarre/tools/previa_andar.luau <pasta_saida> <STAND> <velocidade> <segundos> [lado]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local H = require("./harness")

local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = H.modulo("ReplicatedStorage/BB/Rig")
local Animador = H.modulo("ReplicatedStorage/BB/Cliente/Animador")

local saida, stand, vel, seg, lado = process.args[1], process.args[2] or "STAR_PLATINUM", tonumber(process.args[3]) or 16, tonumber(process.args[4]) or 1.5, tonumber(process.args[5]) or 0
fs.writeDir(saida)
local m = Rig.montarR6("Teste", {
	cabeca = Color3.fromRGB(245, 205, 48),
	torso = Color3.fromRGB(40, 50, 80),
	bracos = Color3.fromRGB(245, 205, 48),
	pernas = Color3.fromRGB(30, 30, 40),
}, false)
local R6 = { RootJoint = "Root", Neck = "Neck", ["Left Shoulder"] = "LS", ["Right Shoulder"] = "RS", ["Left Hip"] = "LH", ["Right Hip"] = "RH" }
local juntas = {}
for _, d in m:GetDescendants() do
	if d:IsA("Motor6D") and R6[d.Name] then
		local rot0 = d.C0 - d.C0.Position
		table.insert(juntas, { curto = R6[d.Name], motor = d, rot0 = rot0, inv = rot0:Inverse() })
	end
end
-- ordem de montagem: raiz -> tronco -> resto
table.sort(juntas, function(a, b)
	return (a.curto == "Root" and 0 or 1) < (b.curto == "Root" and 0 or 1)
end)
local raiz = m:FindFirstChild("HumanoidRootPart")
local function ang(v)
	return if v then CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) else CFrame.new()
end
local a = { fase = 0, modelo = { GetAttribute = function(_, n)
	return if n == "BB_Stand" then stand else nil
end } }
local dt = 1 / 30
local n = math.floor(seg / dt)
local pos = Vector3.new(0, 3, 0)
local chao = {
	n = "Chao", f = "Block", s = { 200, 1, 200 }, p = { 0, -0.5, 0 }, r = { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	c = { 70, 66, 74 }, m = "Concrete", t = 0,
}
local direcao = Vector3.new(lado, 0, -1).Unit
for q = 1, n do
	-- a velocidade sobe de 0 até "vel" no primeiro terço (para ver o começo do andar)
	local v = math.min(vel, vel * (q / (n * 0.25)))
	if q > n * 0.85 then
		v = vel * math.max(0, (n - q) / (n * 0.15))
	end
	pos += direcao * v * dt
	raiz.CFrame = CFrame.new(pos)
	local vLocal = Vector3.new(lado * v, 0, -v)
	local p = Animador.paraR6(Animador.andarJoJo(a, dt, v, false, vLocal, 0, 0))
	for _, j in juntas do
		local alvo = ang(p[j.curto])
		if j.curto == "Root" and p.RootPos then
			alvo = CFrame.new(p.RootPos[1], p.RootPos[2], p.RootPos[3]) * alvo
		end
		local T = j.inv * alvo * j.rot0
		j.motor.Part1.CFrame = j.motor.Part0.CFrame * j.motor.C0 * T * j.motor.C1:Inverse()
	end
	local pecas = H.exportarPecas(m)
	table.insert(pecas, chao)
	fs.writeFile(string.format("%s/q%03d.json", saida, q), serde.encode("json", pecas))
end
fs.writeFile(saida .. "/info.json", serde.encode("json", { n = n, fim = { pos.X, pos.Y, pos.Z } }))
print("quadros", n)
