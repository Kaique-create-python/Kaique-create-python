-- Gera JSON do menu (cenário + botões 3D posicionados) para várias telas
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local MenuCena = H.modulo("ReplicatedStorage/OI3/Cliente/MenuCena")
local B = H.modulo("ReplicatedStorage/OI3/Cliente/Botoes3D")
local ws = H.dm:GetService("Workspace")
local pasta = roblox.Instance.new("Folder")
pasta.Parent = ws
MenuCena.construirCenario(pasta)
local base = H.exportarPecas(pasta)
-- título no espelho (face de trás do vidro)
for _, p in base do
	if p.n == "VidroMenu" then
		p.txt = { { w = 5.0, h = 3.4, texto = "OI3", cor = "#e2dcd4", fonte = "Creepster, 'Rubik Wet Paint', Impact, fantasy", peso = 400, face = "Back", contorno = "#781010", escala = 0.85, alfa = 0.9 } }
	end
end
local RGB = roblox.Color3.fromRGB
local defs = {
	{ id = "jogar", texto = "JOGAR", cor = RGB(126, 20, 22), principal = true, aoClicar = function() end },
	{ id = "multi", texto = "MULTIPLAYER", cor = RGB(32, 28, 34), aoClicar = function() end },
	{ id = "config", texto = "CONFIGURAÇÕES", cor = RGB(32, 28, 34), aoClicar = function() end },
	{ id = "creditos", texto = "CRÉDITOS", cor = RGB(32, 28, 34), aoClicar = function() end },
}
local saidas = {}
for _, tela in { { 1280, 720, "pc" }, { 844, 390, "celular" }, { 390, 844, "retrato" } } do
	local vw, vh, nome = tela[1], tela[2], tela[3]
	local cam, fov = MenuCena.cameraBase(vw, vh)
	local lay = B.calcularLayout(#defs, vw, vh, fov)
	local pb = roblox.Instance.new("Folder")
	pb.Parent = ws
	local extras = {}
	for i, def in defs do
		local pecas = B.montarPecas(def, lay.L, lay.A)
		pecas.modelo.Parent = pb
		pecas.placaTexto.Transparency = 0.97
		-- posiciona: raiz no lugar, demais peças relativas (soldas não existem no Lune)
		local cfRaiz = cam * lay.locais[i]
		local antigo = pecas.raiz.CFrame
		for _, d in pecas.modelo:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = cfRaiz * antigo:Inverse() * d.CFrame
			end
		end
	end
	-- luz-chave dos botões (como no jogo)
	local luzB = pasta:FindFirstChild("LuzBotoes", true)
	if luzB then
		local paisagem = vw / vh >= 1.15
		local alvo = cam * (if paisagem then roblox.CFrame.new(-3.2, -0.4, -7) else roblox.CFrame.new(0, -1.8, -7))
		luzB.CFrame = roblox.CFrame.lookAt((cam * roblox.CFrame.new(-1.2, 2.2, -1.5)).Position, alvo.Position)
		luzB.Transparency = 0.97
		for _, x in H.exportarPecas(pasta) do
			if x.n == "LuzBotoes" then table.insert(extras, 1, x) end
		end
		luzB.Transparency = 1
	end
	local luzExtra = table.remove(extras, 1)
	local lista = H.exportarPecas(pb)
	if luzExtra then table.insert(lista, luzExtra) end
	for _, p in lista do
		if p.n == "PlacaTexto" then
			-- descobre qual botão pelo modelo: usa a ordem (4 placas na ordem dos defs)
			table.insert(extras, p)
		end
	end
	for i, p in extras do
		local def = defs[i]
		p.txt = { { w = p.s[1], h = p.s[2], texto = def.texto, cor = if i == 1 then "#f0e8d8" else "#e2d6c0", fonte = "Merriweather, Georgia, serif", peso = 900, contorno = "#140c0a", escala = 0.5 } }
	end
	local tudo = table.clone(base)
	for _, p in lista do
		table.insert(tudo, p)
	end
	local arq = "oi3/tools/out/menu_" .. nome .. ".json"
	fs.writeFile(arq, serde.encode("json", tudo))
	local pos = cam.Position
	local alvo = (cam * roblox.CFrame.new(0, 0, -10)).Position
	table.insert(saidas, { pecas = arq, saida = "oi3/tools/out/prev_menu_" .. nome .. ".png", opts = { w = vw, h = vh, cam = { pos.X, pos.Y, pos.Z }, alvo = { alvo.X, alvo.Y, alvo.Z }, fov = fov, lua = 0.25, ambiente = 0.45, hemi = 0.25, forcaLuz = 55, ceu = 1052688, rotulo = "Prévia aproximada do menu (" .. nome .. ")" } })
	pb:Destroy()
end
fs.writeFile("oi3/tools/out/lote_menu.json", serde.encode("json", saidas))
print("ok", #saidas)
