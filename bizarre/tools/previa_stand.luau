-- BIZARRE :: prévia do Stand (AJUSTE-10): posição do lado (parado) e a guarda na frente
-- uso (na raiz): lune run bizarre/tools/previa_stand.luau <pasta_saida>
-- gera cena_lado.json e cena_guarda.json (peças) para o renderizador three.js
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local H = require("./harness")

local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = H.modulo("ReplicatedStorage/BB/Rig")
local Animador = H.modulo("ReplicatedStorage/BB/Cliente/Animador")
local Poses = H.modulo("ReplicatedStorage/BB/Poses")

local saida = process.args[1]
fs.writeDir(saida)
local R6 = { RootJoint = "Root", Neck = "Neck", ["Left Shoulder"] = "LS", ["Right Shoulder"] = "RS", ["Left Hip"] = "LH", ["Right Hip"] = "RH" }

local function posar(m, pose, raizCF)
	m:FindFirstChild("HumanoidRootPart").CFrame = raizCF
	local p = Animador.paraR6(pose)
	local juntas = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") and R6[d.Name] then
			table.insert(juntas, d)
		end
	end
	table.sort(juntas, function(a, b)
		return (a.Name == "RootJoint" and 0 or 1) < (b.Name == "RootJoint" and 0 or 1)
	end)
	for _, j in juntas do
		local v = p[R6[j.Name]]
		local rot0 = j.C0 - j.C0.Position
		local alvo = if v then CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) else CFrame.new()
		local T = rot0:Inverse() * alvo * rot0
		j.Part1.CFrame = j.Part0.CFrame * j.C0 * T * j.C1:Inverse()
	end
end

-- os mesmos lugares do StandVisual (AJUSTE-10)
local COSTAS = CFrame.new(-2.35, 1.2, 1.25) * CFrame.Angles(0, math.rad(-10), 0)
local GUARDA = CFrame.new(0, 0.45, -2.3)
local chao = { n = "Chao", f = "Block", s = { 120, 1, 120 }, p = { 0, -0.5, 0 }, r = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, c = { 70, 66, 74 }, m = "Concrete", t = 0 }

for _, cena in { { "lado", Poses.P.guarda, Poses.P.cruzado_flutua, COSTAS }, { "guarda", Poses.P.bloqueio, Poses.P.stand_guarda, GUARDA } } do
	local dono = Rig.montarR6("Dono", { cabeca = Color3.fromRGB(245, 205, 48), torso = Color3.fromRGB(30, 34, 60), bracos = Color3.fromRGB(245, 205, 48), pernas = Color3.fromRGB(30, 30, 40) }, false)
	local stand = Rig.montarR6("Stand", { cabeca = Color3.fromRGB(150, 90, 230), torso = Color3.fromRGB(120, 60, 200), bracos = Color3.fromRGB(150, 90, 230), pernas = Color3.fromRGB(110, 50, 180) }, false)
	local raiz = CFrame.new(0, 3, 0)
	posar(dono, cena[2], raiz)
	posar(stand, cena[3], raiz * cena[4])
	local pecas = H.exportarPecas(dono)
	for _, p in H.exportarPecas(stand) do
		table.insert(pecas, p)
	end
	table.insert(pecas, chao)
	fs.writeFile(saida .. "/cena_" .. cena[1] .. ".json", serde.encode("json", pecas))
end
print("ok")
