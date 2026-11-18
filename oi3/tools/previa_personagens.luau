-- Prévia dos 4 personagens lado a lado (rostos desenhados + cores; roupas e cabelos do
-- catálogo só aparecem dentro do Roblox)
local H = require("./harness")
H.prepararAtores()
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3.new
local CF = roblox.CFrame
local Personagens = H.modulo("ReplicatedStorage/OI3/Personagens")
local ws = H.dm:GetService("Workspace")

local pasta = roblox.Instance.new("Folder")
pasta.Parent = ws
local chao = roblox.Instance.new("Part")
chao.Name = "Chao"
chao.Size = V3(60, 1, 60)
chao.CFrame = CF.new(0, -0.5, 0)
chao.Color = roblox.Color3.fromRGB(86, 170, 70)
chao.Parent = pasta
for _, item in { { "ME", V3(-3.6, 0, 0.6) }, { "KE", V3(0, 0, 1.0) }, { "NI", V3(3.6, 0, 0.6) }, { "VO", V3(0.6, 0, -2.2) } } do
	local m = Personagens.criar(item[1])
	m.Parent = pasta
	local s = m:GetAttribute("Escala") or 1
	H.moverModelo(m, CF.new(item[2] + V3(0, 3 * s, 0)) * CF.Angles(0, math.rad(180), 0))
	local rosto = m:FindFirstChild("Rosto")
	if rosto then
		rosto.Transparency = 0.97
	end
end
local lista = H.exportarPecas(pasta)
for _, m in pasta:GetChildren() do
	local rosto = m:FindFirstChild("Rosto")
	if rosto then
		local sg = rosto:FindFirstChild("Desenho")
		for _, p in lista do
			if p.n == "Rosto" and math.abs(p.p[1] - rosto.CFrame.Position.X) < 1e-3 and math.abs(p.p[2] - rosto.CFrame.Position.Y) < 1e-3 then
				local gw, gh = rosto.Size.X * 140, rosto.Size.Y * 140
				p.txt = { { w = rosto.Size.X, h = rosto.Size.Y, gw = gw, gh = gh, cmds = H.exportarGui(sg, gw, gh) } }
			end
		end
	end
end
fs.writeFile("oi3/tools/out/personagens6.json", serde.encode("json", lista))
local opts = { w = 900, h = 640, cam = { 0.4, 4.6, 13.5 }, alvo = { 0.4, 3.6, 0 }, fov = 40, lua = 1.4, ambiente = 1.1, hemi = 0.9, forcaLuz = 30, ceu = 0x7fb6e8, rotulo = "Prévia: rostos e cores (roupas e cabelos do catálogo aparecem no Roblox)" }
fs.writeFile("oi3/tools/out/lote_personagens6.json", serde.encode("json", { { pecas = "oi3/tools/out/personagens6.json", saida = "oi3/tools/out/prev6_personagens.png", opts = opts } }))
print("ok", #lista)
