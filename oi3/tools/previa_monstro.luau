-- Prévia do MONSTRO (AJUSTE-9): poses calculadas pelo módulo Cliente/Monstro num manequim R15 de blocos.
-- (O corpo de verdade vem do catálogo do Roblox; aqui só conferimos se as poses fazem sentido:
--  andar de dinossauro, contorção, e a cabeça chegando na fresta de cada esconderijo.)
-- Fora do Roblox as juntas não se mexem sozinhas, então aplicamos a cadeia das juntas à mão (FK).
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3.new
local CF = roblox.CFrame.new
local RGB = roblox.Color3.fromRGB

H.prepararAtores()
local ws = H.dm:GetService("Workspace")

-- manequim R15 (proporções de um corpo alto e magro), altura total 8.4
local S = 8.4 / 5.2
local function manequim(): any
	local m = roblox.Instance.new("Model")
	m.Name = "CRIATURA"
	local partes = {}
	local function parte(nome: string, tam: any, centro: any, cor: any)
		local p = roblox.Instance.new("Part")
		p.Name = nome
		p.Size = tam * S
		p.CFrame = CF(centro * S)
		p.Color = cor or RGB(70, 70, 76)
		p.Material = roblox.Enum.Material.SmoothPlastic
		p.Parent = m
		partes[nome] = p
		return p
	end
	local raiz = parte("HumanoidRootPart", V3(2, 2, 1), V3(0, 3.0, 0))
	raiz.Transparency = 1
	parte("LowerTorso", V3(1.5, 0.4, 0.8), V3(0, 2.2, 0))
	parte("UpperTorso", V3(1.6, 1.6, 0.8), V3(0, 3.2, 0))
	parte("Head", V3(1.1, 1.2, 1.1), V3(0, 4.6, 0))
	for _, lado in { { "Left", -1 }, { "Right", 1 } } do
		local n, sx = lado[1], lado[2]
		parte(n .. "UpperArm", V3(0.5, 1.15, 0.5), V3(sx * 1.05, 3.42, 0))
		parte(n .. "LowerArm", V3(0.45, 1.1, 0.45), V3(sx * 1.05, 2.3, 0))
		parte(n .. "Hand", V3(0.45, 0.5, 0.3), V3(sx * 1.05, 1.5, 0), RGB(110, 60, 60))
		parte(n .. "UpperLeg", V3(0.55, 0.9, 0.55), V3(sx * 0.42, 1.55, 0))
		parte(n .. "LowerLeg", V3(0.5, 0.85, 0.5), V3(sx * 0.42, 0.67, 0))
		parte(n .. "Foot", V3(0.5, 0.25, 0.9), V3(sx * 0.42, 0.125, -0.15))
	end
	-- "rosto" (para ver para onde a cara aponta): boca vermelha e dois olhos brancos na frente
	local boca = parte("Boca", V3(0.7, 0.18, 0.1), V3(0, 4.35, -0.58), RGB(200, 30, 30))
	local olhoE = parte("OlhoE", V3(0.2, 0.2, 0.1), V3(-0.25, 4.75, -0.58), RGB(250, 250, 250))
	local olhoD = parte("OlhoD", V3(0.2, 0.2, 0.1), V3(0.25, 4.75, -0.58), RGB(250, 250, 250))
	local function junta(nome: string, p0: string, p1: string, pivo: any)
		local mt = roblox.Instance.new("Motor6D")
		mt.Name = nome
		mt.Part0 = partes[p0]
		mt.Part1 = partes[p1]
		local w = CF(pivo * S)
		mt.C0 = partes[p0].CFrame:Inverse() * w
		mt.C1 = partes[p1].CFrame:Inverse() * w
		mt.Parent = partes[p1]
	end
	junta("Root", "HumanoidRootPart", "LowerTorso", V3(0, 2.2, 0))
	junta("Waist", "LowerTorso", "UpperTorso", V3(0, 2.4, 0))
	junta("Neck", "UpperTorso", "Head", V3(0, 4.0, 0))
	for _, lado in { { "Left", -1 }, { "Right", 1 } } do
		local n, sx = lado[1], lado[2]
		junta(n .. "Shoulder", "UpperTorso", n .. "UpperArm", V3(sx * 1.05, 3.95, 0))
		junta(n .. "Elbow", n .. "UpperArm", n .. "LowerArm", V3(sx * 1.05, 2.85, 0))
		junta(n .. "Wrist", n .. "LowerArm", n .. "Hand", V3(sx * 1.05, 1.75, 0))
		junta(n .. "Hip", "LowerTorso", n .. "UpperLeg", V3(sx * 0.42, 2.0, 0))
		junta(n .. "Knee", n .. "UpperLeg", n .. "LowerLeg", V3(sx * 0.42, 1.1, 0))
		junta(n .. "Ankle", n .. "LowerLeg", n .. "Foot", V3(sx * 0.42, 0.25, 0))
	end
	for _, p in { boca, olhoE, olhoD } do
		local mt = roblox.Instance.new("Motor6D")
		mt.Name = "Rosto_" .. p.Name
		mt.Part0 = partes.Head
		mt.Part1 = p
		mt.C0 = partes.Head.CFrame:Inverse() * p.CFrame
		mt.C1 = CF()
		mt.Parent = p
	end
	local hum = roblox.Instance.new("Humanoid")
	hum.Parent = m
	m.PrimaryPart = raiz
	m:SetAttribute("Escala", S)
	m:SetAttribute("Codigo", "CRIATURA")
	return m
end

-- troca o manequim R6 do teste pelo R15
local atores = H.prepararAtores()
local antigo = atores:FindFirstChild("CRIATURA")
if antigo then
	antigo:Destroy()
end
manequim().Parent = atores

local ORDEM = {
	"Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist",
	"LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle", "Rosto_Boca", "Rosto_OlhoE", "Rosto_OlhoD",
}
local function fk(modelo)
	for _, n in ORDEM do
		local mt = modelo:FindFirstChild(n, true)
		if mt then
			local ok, t = pcall(function()
				return mt.Transform
			end)
			mt.Part1.CFrame = mt.Part0.CFrame * mt.C0 * (if ok then t else CF()) * mt.C1:Inverse()
		end
	end
end

local Monstro = H.modulo("ReplicatedStorage/OI3/Cliente/Monstro")
local MC = H.modulo("ReplicatedStorage/OI3/Cliente/MissoesCliente")
local MM = H.modulo("ReplicatedStorage/OI3/MissoesMapa")

local lote = {}
local function exportar(modelos: { any }, arq: string)
	local tudo = {}
	for _, m in modelos do
		for _, p in H.exportarPecas(m) do
			table.insert(tudo, p)
		end
	end
	fs.writeFile(arq, serde.encode("json", tudo))
end

-- 1) fila de poses: parado, andando (4 fases), contorcendo (2), investida
local pasta = roblox.Instance.new("Folder")
pasta.Parent = ws
local fila = {}
local function novo(x: number, z: number)
	local m = Monstro.novo(pasta, V3(x, 0, z), V3(x, 0, z - 10))
	table.insert(fila, m)
	return m
end
local chao = roblox.Instance.new("Part")
chao.Size = V3(120, 1, 40)
chao.CFrame = CF(30, -0.5, 0)
chao.Color = RGB(96, 70, 50)
chao.Parent = pasta
local parado = novo(0, 0)
parado:aplicar(0)
fk(parado.modelo)
for i, fase in { 0, math.pi / 2, math.pi, 3 * math.pi / 2 } do
	local m = novo(i * 7, 0)
	m.fase = fase
	m.ampAndar = 1
	m.andandoExterno = true
	m:aplicar(0)
	fk(m.modelo)
end
for i = 1, 2 do
	local m = novo(30 + i * 7, 0)
	m.contorcendoAte = os.clock() + 10
	for _ = 1, 8 + i * 5 do
		m:aplicar(1 / 15)
		fk(m.modelo)
	end
end
local inv = novo(51, 0)
inv.olharCabeca = V3(51, 6, -12)
inv.poseAnterior = "investida"
inv.poseNome = "investida"
inv.misturaPose = 1
for _ = 1, 30 do
	inv:aplicar(1 / 30)
	fk(inv.modelo)
end
local modelos = { chao }
for _, m in fila do
	table.insert(modelos, m.modelo)
end
exportar(modelos, "oi3/tools/out/monstro_fila.json")
local LUZ = { lua = 2.4, ambiente = 1.3, hemi = 1.0, forcaLuz = 30, neblina = 0, ceu = 3355443, sombras = true }
local function opts(cam, alvo, rotulo, w, h, fov)
	local o = { w = w or 1280, h = h or 560, cam = { cam.X, cam.Y, cam.Z }, alvo = { alvo.X, alvo.Y, alvo.Z }, fov = fov or 45, rotulo = rotulo }
	for k, v in LUZ do
		o[k] = v
	end
	return o
end
table.insert(lote, { pecas = "oi3/tools/out/monstro_fila.json", saida = "oi3/tools/out/prev9_monstro_lado.png",
	opts = opts(V3(26, 7, -34), V3(26, 3.5, 0), "Monstro (manequim): parado · andando (4 fases) · contorcendo (2) · investida", 1400, 520, 50) })
pasta:Destroy()

-- perfil: três monstros enfileirados no Z (vistos de lado)
local pasta2 = roblox.Instance.new("Folder")
pasta2.Parent = ws
local perfil = {}
for i, cfg in { "parado", "andando", "contorcendo" } do
	local z = (i - 2) * 9
	local m = Monstro.novo(pasta2, V3(0, 0, z), V3(0, 0, z - 10))
	if cfg == "andando" then
		m.fase = math.pi / 2
		m.ampAndar = 1
		m.andandoExterno = true
		m:aplicar(0)
	elseif cfg == "contorcendo" then
		m.contorcendoAte = os.clock() + 10
		for _ = 1, 12 do
			m:aplicar(1 / 15)
			fk(m.modelo)
		end
	else
		m:aplicar(0)
	end
	fk(m.modelo)
	table.insert(perfil, m.modelo)
end
local chao2 = roblox.Instance.new("Part")
chao2.Size = V3(40, 1, 40)
chao2.CFrame = CF(0, -0.5, 0)
chao2.Color = RGB(96, 70, 50)
chao2.Parent = pasta2
table.insert(perfil, chao2)
exportar(perfil, "oi3/tools/out/monstro_perfil.json")
table.insert(lote, { pecas = "oi3/tools/out/monstro_perfil.json", saida = "oi3/tools/out/prev9_monstro_perfil.png",
	opts = opts(V3(30, 5, 0), V3(0, 3.5, 0), "De lado: parado · andando · contorcendo (o rosto vermelho/branco é a FRENTE)", 1200, 560, 50) })
pasta2:Destroy()

-- 2) espiando os esconderijos do quarto (vista de fora e vista de quem está escondido)
local cen = roblox.Instance.new("Folder")
cen.Parent = ws
local quarto, l = MM.construir("quarto", cen)
local quartoArq = "oi3/tools/out/monstro_quarto.json"
fs.writeFile(quartoArq, serde.encode("json", H.exportarPecas(quarto)))
local LUZ_QUARTO = { lua = 0.9, ambiente = 1.0, hemi = 0.7, forcaLuz = 50, neblina = 0.002, ceu = 657936, sombras = true }
for _, id in { "armario1", "cama2", "bau" } do
	local e
	for _, x in l.esconderijos do
		if x.id == id then
			e = x
		end
	end
	local alvo, olhar, pes = MC.pontoEspiada(e, 1.1 * S / 2)
	local m = Monstro.novo(cen, pes, alvo)
	m:posicionar(pes, V3(alvo.X, pes.Y, alvo.Z))
	local tipo = if e.tipo == "cama" then "chao" elseif e.tipo == "bau" then "bau" else "fresta"
	m:espiar(alvo, olhar, tipo, 30)
	for _ = 1, 140 do
		m:aplicar(1 / 30)
		fk(m.modelo)
	end
	local cab = m.cabecaParte.CFrame.Position
	print(string.format("%s: cabeça em (%.2f, %.2f, %.2f), alvo (%.2f, %.2f, %.2f), erro %.2f", id, cab.X, cab.Y, cab.Z, alvo.X, alvo.Y, alvo.Z, (cab - alvo).Magnitude))
	local arq = "oi3/tools/out/monstro_" .. id .. ".json"
	exportar({ m.modelo }, arq)
	local camDentro = e.cam
	local olhando = camDentro.Position + camDentro.LookVector * 10
	local o1 = { w = 844, h = 390, cam = { camDentro.Position.X, camDentro.Position.Y, camDentro.Position.Z }, alvo = { olhando.X, olhando.Y, olhando.Z }, fov = 70, rotulo = "Escondido (" .. id .. "): o monstro na fresta" }
	local fora = pes + V3(0, 0, 0) + (pes - alvo) * 0 + V3(7, 6, if e.tipo == "cama" then 8 else -8)
	local o2 = { w = 844, h = 390, cam = { fora.X, fora.Y, fora.Z }, alvo = { alvo.X, alvo.Y - 1, alvo.Z }, fov = 55, rotulo = "De fora (" .. id .. ")" }
	for k, v in LUZ_QUARTO do
		o1[k] = v
		o2[k] = v
	end
	table.insert(lote, { pecas = quartoArq, extra = arq, saida = "oi3/tools/out/prev9_espia_" .. id .. "_dentro.png", opts = o1 })
	table.insert(lote, { pecas = quartoArq, extra = arq, saida = "oi3/tools/out/prev9_espia_" .. id .. "_fora.png", opts = o2 })
	m:destruir()
end
fs.writeFile("oi3/tools/out/lote9_monstro.json", serde.encode("json", lote))
print("vistas", #lote)
