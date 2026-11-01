-- Prévias das cenas da abertura (personagens posicionados, rostos e reflexo do espelho)
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local V3 = roblox.Vector3.new
local CF = roblox.CFrame
local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
local Personagens = H.modulo("ReplicatedStorage/OI3/Personagens")
local Construtor = H.modulo("ReplicatedStorage/OI3/Construtor")
local ws = H.dm:GetService("Workspace")
local F = Mapa.L.F
local P = Mapa.pontos()

local mapaModelo = Mapa.construir(ws)
local vidro = mapaModelo:FindFirstChild("VidroEspelho", true)
local fundo = mapaModelo:FindFirstChild("FundoEspelho", true)

local function yaw(de, para)
	local d = V3(para.X - de.X, 0, para.Z - de.Z)
	return math.atan2(-d.X, -d.Z)
end

local function colocar(cod, pes, olhar, expr, pasta)
	local m = if cod == "CRIATURA" then Personagens.criarCriatura() else Personagens.criar(cod)
	m.Parent = pasta
	local s = m:GetAttribute("Escala") or 1
	local cf = CF.new(pes + V3(0, 3 * s, 0)) * CF.Angles(0, yaw(pes, olhar), 0)
	H.moverModelo(m, cf)
	if expr then
		Personagens.expressao(m, expr)
	end
	return m, cf
end

local function exportar(pasta)
	local lista = {}
	for _, m in pasta:GetChildren() do
		local rosto = m:FindFirstChild("Rosto")
		if rosto then
			rosto.Transparency = 0.97
		end
	end
	for _, p in H.exportarPecas(pasta) do
		table.insert(lista, p)
	end
	-- anexa o desenho do rosto
	local idx = 0
	for _, m in pasta:GetChildren() do
		local rosto = m:FindFirstChild("Rosto")
		if rosto then
			local sg = rosto:FindFirstChild("Desenho")
			for _, p in lista do
				if p.n == "Rosto" and math.abs(p.p[1] - rosto.CFrame.Position.X) < 1e-3 and math.abs(p.p[3] - rosto.CFrame.Position.Z) < 1e-3 and math.abs(p.p[2] - rosto.CFrame.Position.Y) < 1e-3 then
					local gw, gh = rosto.Size.X * 140, rosto.Size.Y * 140
					p.txt = { { w = rosto.Size.X, h = rosto.Size.Y, gw = gw, gh = gh, cmds = H.exportarGui(sg, gw, gh) } }
				end
			end
			idx += 1
		end
	end
	return lista
end

local mapaJson = H.exportarPecas(mapaModelo)
local lote = {}
local function cena(nome, pastaFn, camPos, camAlvo, fov, extraOpts)
	local pasta = roblox.Instance.new("Folder")
	pasta.Parent = ws
	pastaFn(pasta)
	local pecas = exportar(pasta)
	local arq = "oi3/tools/out/cena_" .. nome .. ".json"
	fs.writeFile(arq, serde.encode("json", pecas))
	local opts = { cam = { camPos.X, camPos.Y, camPos.Z }, alvo = { camAlvo.X, camAlvo.Y, camAlvo.Z }, fov = fov, lua = 0.45, ambiente = 0.55, hemi = 0.3, forcaLuz = 70, rotulo = "Prévia aproximada: " .. nome }
	for k, v in extraOpts or {} do
		opts[k] = v
	end
	table.insert(lote, { pecas = "oi3/tools/out/mapa_cena.json", extra = arq, saida = "oi3/tools/out/prev_cena_" .. nome .. ".png", opts = opts })
	pasta:Destroy()
end

-- vidro transparente (como durante a abertura)
vidro.Transparency = 0.9
vidro.Reflectance = 0
fundo.Transparency = 1
fs.writeFile("oi3/tools/out/mapa_cena.json", serde.encode("json", H.exportarPecas(mapaModelo)))

-- Cena 2: o Vô dá boa noite (com lamparina acesa simulada)
cena("dormitorio", function(pasta)
	colocar("ME", P.menino, P.vo, "neutro", pasta)
	colocar("NI", P.nina, P.vo, "neutro", pasta)
	colocar("KE", P.keko, P.vo, "serio", pasta)
	local vo = colocar("VO", P.vo, V3(-25, F, -7), "feliz", pasta)
	local luz = roblox.Instance.new("Part")
	luz.Anchored = true
	luz.Size = V3(0.2, 0.2, 0.2)
	luz.Material = roblox.Enum.Material.Neon
	luz.Color = roblox.Color3.fromRGB(255, 186, 92)
	luz.CFrame = vo.PrimaryPart.CFrame * CF.new(1.7, -2.2, -0.3)
	local pl = roblox.Instance.new("PointLight")
	pl.Range = 17
	pl.Brightness = 1.1
	pl.Color = roblox.Color3.fromRGB(255, 168, 98)
	pl.Parent = luz
	luz.Parent = pasta
end, V3(-34.5, F + 7.5, -21.5), V3(-19, F + 3, -2), 62)

-- Cena 3: o convite do Keko (close)
cena("convite", function(pasta)
	colocar("ME", P.menino, P.kekoPerto, "nervoso", pasta)
	colocar("NI", P.nina, P.kekoPerto, "curioso", pasta)
	colocar("KE", P.kekoPerto, V3(-23.3, F, -13.5), "sapeca", pasta)
end, V3(-23.6, F + 4.5, -12.4), P.kekoPerto + V3(0, 4.05, 0), 48)

-- Cena 5/6: o espelho (com reflexo e a silhueta só no ponto de vista do menino)
cena("espelho_pov", function(pasta)
	local refletir = Mapa.refletorEspelho()
	Mapa.construirQuartoEspelho(Construtor.novo(pasta, { refletir = refletir }), true)
	local alvo = V3(Mapa.L.XESP, F, 0)
	local menino, cfM = colocar("ME", P.espMenino, alvo, "medo", pasta)
	local _, cfN = colocar("NI", P.espNina, V3(66, F, -0.5), "nervoso", pasta)
	local _, cfK = colocar("KE", P.espKeko, V3(66, F, 0.5), "serio", pasta)
	-- reflexos
	for _, par in { { "ME", cfM, "medo" }, { "NI", cfN, "nervoso" }, { "KE", cfK, "serio" } } do
		local r = Personagens.criar(par[1])
		r.Parent = pasta
		Personagens.expressao(r, par[3])
		H.moverModelo(r, refletir(par[2]))
	end
	local posC = V3(2 * Mapa.L.XESP - 63.8, F, 0.95)
	colocar("CRIATURA", posC, V3(50, F, 0.95), nil, pasta)
end, P.espMenino + V3(0.7, 4.1, 0), V3(Mapa.L.XESP, F + 3.9, 0), 60)

-- Cena 7: as risadas (vista lateral, sem a silhueta)
cena("risadas", function(pasta)
	local refletir = Mapa.refletorEspelho()
	Mapa.construirQuartoEspelho(Construtor.novo(pasta, { refletir = refletir }), true)
	colocar("ME", V3(63.6, F, 0), V3(Mapa.L.XESP, F, 0), "medo", pasta)
	colocar("NI", P.espNina, V3(63.6, F, 0), "rindo", pasta)
	colocar("KE", P.espKeko, V3(63.6, F, 0), "rindo", pasta)
end, (function()
	local d = (V3(63.6, 0, 0) - V3(P.espKeko.X, 0, P.espKeko.Z)).Unit
	local perp = V3(-d.Z, 0, d.X)
	return P.espKeko + V3(0, 0.9 * 4.5, 0) + d * 2.6 + perp * 1.6 + V3(0, 0.25, 0)
end)(), P.espKeko + V3(0, 0.9 * 4.5, 0), 50)

fs.writeFile("oi3/tools/out/lote_cenas.json", serde.encode("json", lote))
print("cenas:", #lote)
