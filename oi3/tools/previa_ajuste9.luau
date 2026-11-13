-- Prévias do AJUSTE-9: os corredores atrás das portas (ninguém cai mais) e os detalhes novos
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
	{ "festa", "porta_leste", V3(6, 5, 3.6), V3(22, 3.2, 3.6) },
	{ "quarto", "porta_saida", V3(8, 5, 0), V3(24, 3.2, 0) },
	{ "lavanderia", "porta_oeste", V3(-6, 5, 4), V3(-22, 3.2, 4) },
	{ "cadeiras", "porta_sul", V3(0, 5, -2), V3(0, 3.2, 16) },
}
for _, v in vistas do
	local nome = v[1]
	local pasta = roblox.Instance.new("Folder")
	pasta.Parent = ws
	local modelo, l = MM.construir(nome, pasta)
	-- abre a porta (some com a folha) para ver o corredor atrás
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and (string.sub(d.Name, 1, 10) == "OI3_Porta_" or string.sub(d.Name, 1, 13) == "OI3_PortaDet_") then
			d:Destroy()
		end
	end
	local arq = "oi3/tools/out/cen9_" .. nome .. ".json"
	fs.writeFile(arq, serde.encode("json", H.exportarPecas(modelo)))
	local O = l.origem
	local cam, alvo = O + v[3] + V3(0, 1, 0), O + v[4] + V3(0, 1, 0)
	table.insert(lote, { pecas = arq, saida = "oi3/tools/out/prev9_" .. nome .. "_" .. v[2] .. ".png", opts = {
		w = 844, h = 390, cam = { cam.X, cam.Y, cam.Z }, alvo = { alvo.X, alvo.Y, alvo.Z }, fov = 70,
		lua = 0.5, ambiente = 1.1, hemi = 0.5, forcaLuz = 55, neblina = 0.002,
		ceu = 657936, sombras = true, variantes = variantes, rotulo = "AJUSTE-9: " .. nome .. " — corredor atrás da porta (porta aberta)" } })
	pasta:Destroy()
end
fs.writeFile("oi3/tools/out/lote9_cen.json", serde.encode("json", lote))
print("vistas", #lote)
