-- Prévias dos cenários das missões (AJUSTE-8)
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3.new
local MM = H.modulo("ReplicatedStorage/OI3/MissoesMapa")
local ws = H.dm:GetService("Workspace")
local variantes = {}
for _, t in serde.decode("json", fs.readFile("oi3/assets/texturas/texturas.json")) do
	local base = "../../assets/texturas/"
	variantes[t.nome] = { nome = t.nome, cor = base .. t.mapas.cor, normal = base .. t.mapas.normal, rug = base .. t.mapas.rugosidade, studs = t.studs }
end
local lote = {}
local vistas = {
	{ "quarto", V3(16, 6.5, 10), V3(-6, 1, -6) },
	{ "festa", V3(-13, 6.5, 8), V3(4, 2, -3) },
	{ "lavanderia", V3(-11, 6, 8), V3(3, 2, -7) },
	{ "espelhos", V3(-26, 5.5, 2.5), V3(6, 4, -5) },
	{ "quarto_trancado", V3(-10, 6, 7), V3(6, 3, -8) },
	{ "escritorio", V3(-11, 6.5, 8), V3(8, 3, -2) },
	{ "cadeiras", V3(8, 7, 8), V3(-2, 1.5, -6) },
	{ "porao", V3(23, 5, 1), V3(-10, 3, -1) },
	{ "rua", V3(-22, 7, -16), V3(6, 2, 3) },
}
for _, v in vistas do
	local nome = v[1]
	local pasta = roblox.Instance.new("Folder")
	pasta.Parent = ws
	local modelo, l = MM.construir(nome, pasta)
	local arq = "oi3/tools/out/cen8_" .. nome .. ".json"
	fs.writeFile(arq, serde.encode("json", H.exportarPecas(modelo)))
	local O = l.origem
	local cam, alvo = O + v[2] + V3(0, 1, 0), O + v[3] + V3(0, 1, 0)
	local dia = nome == "rua"
	table.insert(lote, { pecas = arq, saida = "oi3/tools/out/prev8_cen_" .. nome .. ".png", opts = {
		w = 844, h = 390, cam = { cam.X, cam.Y, cam.Z }, alvo = { alvo.X, alvo.Y, alvo.Z }, fov = 72,
		lua = if dia then 2.2 else 0.5, ambiente = if dia then 1.4 else 0.75, hemi = if dia then 0.9 else 0.35, forcaLuz = 55, neblina = 0.002,
		ceu = if dia then 9028334 else 657936, sombras = true, variantes = variantes, rotulo = "Prévia aproximada: " .. nome } })
	pasta:Destroy()
end
fs.writeFile("oi3/tools/out/lote8b.json", serde.encode("json", lote))
print("vistas", #lote)
