-- BIZARRE BATTLEGROUNDS :: prévias da cidade (three.js). Uso (na raiz):
--   lune run bizarre/tools/previa.luau && node bizarre/tools/preview/shot.js bizarre/tools/out/lote.json
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3.new

local Mapa = H.modulo("ServerScriptService/BB_Servidor/Mapa")
local Plano = H.modulo("ReplicatedStorage/BB/Mapa/Plano")
local Rig = H.modulo("ReplicatedStorage/BB/Rig")
local Stands = H.modulo("ReplicatedStorage/BB/Stands")

fs.writeDir("bizarre/tools/out")
local ws = H.dm:GetService("Workspace")
local pasta = roblox.Instance.new("Folder")
pasta.Parent = ws
local plano = Plano.gerar()
local modelo = Mapa.construir(pasta, plano)

-- "luta" no meio da praça: buracos num prédio da esquina (como se alguém tivesse voado através)
local quebraveis = modelo:FindFirstChild("Quebraveis")
local alvos = { { V3(-143, 4, -152), 6.5 }, { V3(-143, 10, -146), 5 }, { V3(-150, 7, -138), 6 }, { V3(-165, 3, -138), 4 } }
local n = 0
for _, p in quebraveis:GetChildren() do
	for _, a in alvos do
		if (p.CFrame.Position - a[1]).Magnitude < a[2] then
			if Mapa.quebrar(p, nil, 9) then
				n += 1
			end
			break
		end
	end
end
print("peças quebradas na prévia:", n)
-- quem está quebrado fica de fora da foto
for _, p in quebraveis:GetChildren() do
	if p.Transparency >= 1 then
		p:Destroy()
	end
end

local pecas = H.exportarPecas(pasta)
-- tira as paredes invisíveis e os prédios "longe" demais
local filtradas = {}
for _, p in pecas do
	if p.n ~= "Limite" then
		table.insert(filtradas, p)
	end
end
fs.writeFile("bizarre/tools/out/cidade.json", serde.encode("json", filtradas))

local dia = { lua = 2.6, luaCor = 16774620, luaPos = { -220, 330, 160 }, ambiente = 0.75, ambienteCor = 13421823, hemi = 0.8, hemiCeu = 12117247, hemiChao = 6636321, ceu = 10473712, neblina = 0.0016, sombras = true, sombraRaio = 240, exposicao = 1.05, neon = 1.3, maxLuzes = 0 }
local function vista(nome: string, cam, alvoV, rotulo: string, fov: number?)
	local o = {}
	for k, v in dia do
		o[k] = v
	end
	o.w = 1280
	o.h = 720
	o.cam = { cam.X, cam.Y, cam.Z }
	o.alvo = { alvoV.X, alvoV.Y, alvoV.Z }
	o.fov = fov or 60
	o.rotulo = rotulo
	return { pecas = "bizarre/tools/out/cidade.json", saida = "bizarre/previas/" .. nome .. ".png", opts = o }
end
local lote = {
	vista("1_cidade_de_cima", V3(150, 175, 230), V3(-10, 0, -10), "BIZARRE BATTLEGROUNDS — a Vila Bizarra vista de cima (14 prédios quebráveis)", 55),
	vista("2_praca", V3(46, 16, 62), V3(-4, 9, -10), "A praça: chafariz, estátua fazendo pose e a torre do relógio no fundo", 62),
	vista("3_destruicao", V3(-150, 20, -103), V3(-156, 7, -140), "Prédio depois que alguém voou através dele (as paredes voltam sozinhas em 30 s)", 60),
	vista("4_feira_e_carros", V3(-64, 22, -44), V3(-120, 4, 4), "Feira com barracas e o estacionamento: tudo quebra", 62),
}
fs.writeFile("bizarre/tools/out/lote.json", serde.encode("json", lote))
print("peças exportadas:", #filtradas, "vistas:", #lote)
