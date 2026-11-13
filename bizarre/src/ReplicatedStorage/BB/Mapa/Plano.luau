-- BIZARRE BATTLEGROUNDS :: planta da "Vila Bizarra" (cidade quebrável)
-- Função pura: devolve a lista de peças (tamanho, posição, cor, material e se quebra).
-- O servidor monta a cidade com isso e lembra de cada peça para reconstruir depois.

local Plano = {}

local RGB = Color3.fromRGB

local function rng(semente: number)
	local s = semente
	return function(a: number?, b: number?): number
		s = (s * 1103515245 + 12345) % 2147483648
		local r = s / 2147483648
		if a and b then
			return a + (b - a) * r
		end
		return r
	end
end

-- paleta "bizarra" (cores vivas e pastéis)
local CORES_PREDIO = {
	RGB(240, 150, 190), -- rosa
	RGB(70, 182, 170), -- verde-água
	RGB(232, 190, 72), -- mostarda
	RGB(172, 140, 222), -- lavanda
	RGB(240, 122, 100), -- coral
	RGB(150, 220, 180), -- menta
	RGB(118, 178, 240), -- azul
	RGB(240, 226, 190), -- creme
	RGB(146, 92, 204), -- roxo
	RGB(242, 150, 62), -- laranja
}
Plano.CORES_PREDIO = CORES_PREDIO

local CORES_CARRO = { RGB(214, 40, 48), RGB(30, 90, 200), RGB(250, 210, 40), RGB(240, 240, 240), RGB(30, 30, 34), RGB(40, 170, 90), RGB(240, 120, 40) }

local CHAO_Y = 0
local CALCADA = 0.6
local ANDAR = 12
local ESPESSURA = 1.2

Plano.LIMITE = 214

function Plano.gerar()
	local R = rng(20261103)
	local pecas = {}
	local nGrupo = 0
	local spawns = {}
	local predios = 0

	local function add(p)
		p.id = #pecas + 1
		table.insert(pecas, p)
		return p
	end
	local function grupo()
		nGrupo += 1
		return nGrupo
	end
	local function bloco(nome, tam, cf, cor, mat, extra)
		local p = { n = nome, s = tam, cf = cf, c = cor, m = mat or "SmoothPlastic", f = "Block" }
		if extra then
			for k, v in extra do
				p[k] = v
			end
		end
		return add(p)
	end
	local function clarear(c: Color3, k: number): Color3
		return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
	end

	----------------------------------------------------------------------------- chão
	bloco("Asfalto", Vector3.new(520, 4, 520), CFrame.new(0, CHAO_Y - 2, 0), RGB(58, 58, 64), "Asphalt", { k = "base" })
	-- praça central
	bloco("Praca", Vector3.new(100, CALCADA, 100), CFrame.new(0, CALCADA / 2, 0), RGB(232, 214, 176), "Pavement", { k = "base" })
	-- quarteirões (calçadas) em volta
	local faixas = { { -132, 116 }, { 0, 100 }, { 132, 116 } }
	for ix, fx in faixas do
		for iz, fz in faixas do
			if not (ix == 2 and iz == 2) then
				bloco("Calcada", Vector3.new(fx[2], CALCADA, fz[2]), CFrame.new(fx[1], CALCADA / 2, fz[1]), RGB(178, 176, 170), "Concrete", { k = "base" })
			end
		end
	end
	-- faixas das ruas (só enfeite, não colidem)
	for _, z in { -62, 62 } do
		for x = -200, 200, 14 do
			if math.abs(x) > 4 then
				bloco("Faixa", Vector3.new(7, 0.06, 0.6), CFrame.new(x, CHAO_Y + 0.03, z), RGB(250, 220, 90), "SmoothPlastic", { k = "enfeite", semColisao = true })
			end
		end
	end
	for _, x in { -62, 62 } do
		for z = -200, 200, 14 do
			if math.abs(z) > 4 then
				bloco("Faixa", Vector3.new(0.6, 0.06, 7), CFrame.new(x, CHAO_Y + 0.03, z), RGB(250, 220, 90), "SmoothPlastic", { k = "enfeite", semColisao = true })
			end
		end
	end
	-- faixas de pedestre na frente da praça
	for _, lado in { -1, 1 } do
		for i = -3, 3 do
			bloco("Zebra", Vector3.new(2.2, 0.06, 18), CFrame.new(i * 4, CHAO_Y + 0.03, lado * 62), RGB(240, 240, 240), "SmoothPlastic", { k = "enfeite", semColisao = true })
			bloco("Zebra", Vector3.new(18, 0.06, 2.2), CFrame.new(lado * 62, CHAO_Y + 0.03, i * 4), RGB(240, 240, 240), "SmoothPlastic", { k = "enfeite", semColisao = true })
		end
	end

	----------------------------------------------------------------------------- prédios
	-- prédio em painéis: cada painel quebra sozinho (2 fileiras por andar)
	local function predio(cx: number, cz: number, W: number, D: number, andares: number, cor: Color3, porta: string?)
		predios += 1
		local g = grupo()
		local y0 = CALCADA
		local escuro = clarear(cor, 0.82)
		local vidro = RGB(168, 214, 238)
		local function painel(cf, tam, ehVidro, ehBaixo)
			if ehVidro then
				bloco("Vidro", tam, cf, vidro, "Glass", { q = true, k = "vidro", t = 0.42, refl = 0.15, pred = g })
			else
				bloco("Parede", tam, cf, if ehBaixo then escuro else cor, "SmoothPlastic", { q = true, k = "parede", pred = g })
			end
		end
		local ladoPorta = porta or "frente"
		-- frente (-Z) e fundo (+Z)
		for _, face in { { "frente", -1 }, { "fundo", 1 } } do
			local n = math.max(2, math.floor(W / 6.4 + 0.5))
			local pw = W / n
			local z = cz + face[2] * (D / 2 - ESPESSURA / 2)
			for andar = 0, andares - 1 do
				for fila = 0, 1 do
					for i = 1, n do
						local x = cx - W / 2 + pw * (i - 0.5)
						local y = y0 + andar * ANDAR + fila * 6 + 3
						local meio = i == math.floor((n + 1) / 2)
						if andar == 0 and fila == 0 and meio and face[1] == ladoPorta then
							continue -- porta
						end
						local ehVidro = (fila == 1 and i % 2 == 0) or (andar == 0 and fila == 0 and face[1] == "frente" and i % 2 == 1 and not meio and n >= 4)
						painel(CFrame.new(x, y, z), Vector3.new(pw, 6, ESPESSURA), ehVidro, fila == 0)
					end
				end
			end
		end
		-- laterais (-X e +X), entre a frente e o fundo
		for _, face in { { "esquerda", -1 }, { "direita", 1 } } do
			local L = D - 2 * ESPESSURA
			local n = math.max(2, math.floor(L / 6.4 + 0.5))
			local pw = L / n
			local x = cx + face[2] * (W / 2 - ESPESSURA / 2)
			for andar = 0, andares - 1 do
				for fila = 0, 1 do
					for i = 1, n do
						local z = cz - L / 2 + pw * (i - 0.5)
						local y = y0 + andar * ANDAR + fila * 6 + 3
						local meio = i == math.floor((n + 1) / 2)
						if andar == 0 and fila == 0 and meio and face[1] == ladoPorta then
							continue
						end
						local ehVidro = fila == 1 and i % 2 == 0
						painel(CFrame.new(x, y, z), Vector3.new(ESPESSURA, 6, pw), ehVidro, fila == 0)
					end
				end
			end
		end
		-- pisos internos e telhado (não quebram)
		for andar = 1, andares - 1 do
			bloco("Piso", Vector3.new(W - 2 * ESPESSURA, 0.8, D - 2 * ESPESSURA), CFrame.new(cx, y0 + andar * ANDAR - 0.4, cz), RGB(150, 116, 86), "WoodPlanks", { k = "piso" })
		end
		local topo = y0 + andares * ANDAR
		bloco("Telhado", Vector3.new(W + 1.6, 1, D + 1.6), CFrame.new(cx, topo + 0.5, cz), clarear(cor, 0.62), "Slate", { k = "teto" })
		bloco("Platibanda", Vector3.new(W + 1.6, 1.4, 1), CFrame.new(cx, topo + 1.7, cz - D / 2 - 0.3), clarear(cor, 0.7), "SmoothPlastic", { k = "teto" })
		bloco("Platibanda", Vector3.new(W + 1.6, 1.4, 1), CFrame.new(cx, topo + 1.7, cz + D / 2 + 0.3), clarear(cor, 0.7), "SmoothPlastic", { k = "teto" })
		-- caixa d'água / ar-condicionado no telhado
		bloco("CaixaDagua", Vector3.new(4, 3, 4), CFrame.new(cx + W / 4, topo + 2.5, cz + D / 5), RGB(90, 120, 150), "Metal", { q = true, k = "adereco", g = grupo() })
		-- toldo colorido em cima da porta
		local zPorta = if ladoPorta == "frente" then cz - D / 2 - 1.6 elseif ladoPorta == "fundo" then cz + D / 2 + 1.6 else cz
		local xPorta = if ladoPorta == "esquerda" then cx - W / 2 - 1.6 elseif ladoPorta == "direita" then cx + W / 2 + 1.6 else cx
		local tamToldo = if ladoPorta == "frente" or ladoPorta == "fundo" then Vector3.new(8, 0.5, 3.4) else Vector3.new(3.4, 0.5, 8)
		bloco("Toldo", tamToldo, CFrame.new(xPorta, y0 + 6.6, zPorta), clarear(cor, 0.55), "Fabric", { q = true, k = "adereco", g = grupo() })
		return g
	end
	Plano.predio = predio

	----------------------------------------------------------------------------- adereços
	local function poste(x, z)
		local g = grupo()
		bloco("Poste", Vector3.new(14, 0.7, 0.7), CFrame.new(x, CALCADA + 7, z) * CFrame.Angles(0, 0, math.rad(90)), RGB(40, 44, 52), "Metal", { q = true, k = "adereco", g = g, f = "Cylinder" })
		bloco("Lampada", Vector3.new(1.6, 1.2, 1.6), CFrame.new(x, CALCADA + 14.4, z), RGB(255, 236, 170), "Neon", { q = true, k = "adereco", g = g, luz = true })
	end
	local function arvore(x, z, escala)
		local g = grupo()
		local e = escala or 1
		bloco("Tronco", Vector3.new(9 * e, 1.6 * e, 1.6 * e), CFrame.new(x, CALCADA + 4.5 * e, z) * CFrame.Angles(0, 0, math.rad(90)), RGB(110, 76, 50), "Wood", { q = true, k = "adereco", g = g, f = "Cylinder" })
		bloco("Folhas", Vector3.new(9 * e, 9 * e, 9 * e), CFrame.new(x, CALCADA + 10.5 * e, z), RGB(84, 168, 74), "Grass", { q = true, k = "adereco", g = g, f = "Ball" })
		bloco("Folhas", Vector3.new(6.5 * e, 6.5 * e, 6.5 * e), CFrame.new(x + 2.6 * e, CALCADA + 8.6 * e, z + 1.4 * e), RGB(104, 186, 84), "Grass", { q = true, k = "adereco", g = g, f = "Ball" })
	end
	local function banco(x, z, rotY)
		local g = grupo()
		local cf = CFrame.new(x, CALCADA, z) * CFrame.Angles(0, math.rad(rotY or 0), 0)
		bloco("Banco", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.8, 0), RGB(150, 96, 56), "WoodPlanks", { q = true, k = "adereco", g = g })
		bloco("Banco", Vector3.new(6, 2, 0.4), cf * CFrame.new(0, 3, 0.9), RGB(150, 96, 56), "WoodPlanks", { q = true, k = "adereco", g = g })
		bloco("PeBanco", Vector3.new(0.5, 1.6, 1.8), cf * CFrame.new(-2.6, 0.8, 0), RGB(40, 40, 44), "Metal", { q = true, k = "adereco", g = g })
		bloco("PeBanco", Vector3.new(0.5, 1.6, 1.8), cf * CFrame.new(2.6, 0.8, 0), RGB(40, 40, 44), "Metal", { q = true, k = "adereco", g = g })
	end
	local function carro(x, z, rotY, cor)
		local g = grupo()
		local cf = CFrame.new(x, CHAO_Y, z) * CFrame.Angles(0, math.rad(rotY or 0), 0)
		local c = cor or CORES_CARRO[math.floor(R(1, #CORES_CARRO + 0.999))]
		bloco("Carro", Vector3.new(6, 2.4, 12), cf * CFrame.new(0, 2.1, 0), c, "SmoothPlastic", { q = true, k = "carro", g = g })
		bloco("Cabine", Vector3.new(5.4, 2.2, 6), cf * CFrame.new(0, 4.4, 0.6), RGB(150, 200, 230), "Glass", { q = true, k = "carro", g = g, t = 0.3 })
		bloco("Teto", Vector3.new(5.6, 0.3, 6.2), cf * CFrame.new(0, 5.6, 0.6), c, "SmoothPlastic", { q = true, k = "carro", g = g })
		for _, w in { { -3, -3.8 }, { 3, -3.8 }, { -3, 3.8 }, { 3, 3.8 } } do
			bloco("Roda", Vector3.new(1, 2.4, 2.4), cf * CFrame.new(w[1], 1.2, w[2]), RGB(24, 24, 26), "Rubber", { q = true, k = "carro", g = g, f = "Cylinder" })
		end
		bloco("Farol", Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(-2, 2.4, -6.05), RGB(255, 250, 220), "Neon", { q = true, k = "carro", g = g })
		bloco("Farol", Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(2, 2.4, -6.05), RGB(255, 250, 220), "Neon", { q = true, k = "carro", g = g })
	end
	local function caixote(x, z, tam)
		local t = tam or 3
		bloco("Caixote", Vector3.new(t, t, t), CFrame.new(x, CALCADA + t / 2, z) * CFrame.Angles(0, math.rad(R(0, 40)), 0), RGB(170, 124, 72), "WoodPlanks", { q = true, k = "adereco" })
	end
	local function barril(x, z)
		bloco("Barril", Vector3.new(3.4, 2.4, 2.4), CFrame.new(x, CALCADA + 1.7, z) * CFrame.Angles(0, 0, math.rad(90)), RGB(150, 62, 40), "Wood", { q = true, k = "adereco", f = "Cylinder" })
	end
	local function barraca(x, z, rotY, cor1, cor2)
		local g = grupo()
		local cf = CFrame.new(x, CALCADA, z) * CFrame.Angles(0, math.rad(rotY or 0), 0)
		for _, p in { { -4, -2 }, { 4, -2 }, { -4, 2 }, { 4, 2 } } do
			bloco("Estaca", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(p[1], 3.5, p[2]), RGB(120, 84, 56), "Wood", { q = true, k = "adereco", g = g })
		end
		bloco("Balcao", Vector3.new(8.6, 3, 2.4), cf * CFrame.new(0, 1.5, -1), RGB(196, 150, 96), "WoodPlanks", { q = true, k = "adereco", g = g })
		for i = 0, 3 do
			bloco("Lona", Vector3.new(2.2, 0.4, 5), cf * CFrame.new(-3.3 + i * 2.2, 7.2, 0) * CFrame.Angles(math.rad(-8), 0, 0), if i % 2 == 0 then cor1 else cor2, "Fabric", { q = true, k = "adereco", g = g })
		end
		-- frutas no balcão
		for i = -1, 1 do
			bloco("Fruta", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(i * 2.4, 3.6, -1), if i == 0 then RGB(250, 200, 40) else RGB(220, 50, 40), "SmoothPlastic", { q = true, k = "adereco", g = g, f = "Ball" })
		end
	end
	local function cerca(x1, z1, x2, z2)
		local d = Vector3.new(x2 - x1, 0, z2 - z1)
		local n = math.max(1, math.floor(d.Magnitude / 6 + 0.5))
		for i = 0, n - 1 do
			local a = Vector3.new(x1, 0, z1) + d * ((i + 0.5) / n)
			local cf = CFrame.lookAt(Vector3.new(a.X, CALCADA + 1.6, a.Z), Vector3.new(a.X, CALCADA + 1.6, a.Z) + d.Unit)
			bloco("Cerca", Vector3.new(0.4, 3.2, d.Magnitude / n - 0.2), cf, RGB(214, 214, 220), "WoodPlanks", { q = true, k = "adereco" })
		end
	end

	----------------------------------------------------------------------------- praça central
	-- chafariz: borda em gomos (cada um quebra), água e coluna
	local gChafariz = grupo()
	bloco("Agua", Vector3.new(1.2, 19, 19), CFrame.new(0, CALCADA + 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(90, 170, 230), "Glass", { k = "enfeite", t = 0.35, f = "Cylinder", semColisao = true })
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local cf = CFrame.new(math.cos(a) * 10, CALCADA + 1.2, math.sin(a) * 10) * CFrame.Angles(0, -a, 0)
		bloco("BordaChafariz", Vector3.new(1.6, 2.4, 4.2), cf, RGB(214, 206, 196), "Marble", { q = true, k = "adereco" })
	end
	bloco("Coluna", Vector3.new(8, 2.2, 2.2), CFrame.new(0, CALCADA + 4, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(226, 218, 206), "Marble", { q = true, k = "adereco", g = gChafariz, f = "Cylinder" })
	bloco("Taca", Vector3.new(1, 8, 8), CFrame.new(0, CALCADA + 8.2, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(226, 218, 206), "Marble", { q = true, k = "adereco", g = gChafariz, f = "Cylinder" })
	bloco("Jato", Vector3.new(3, 1.4, 1.4), CFrame.new(0, CALCADA + 9.8, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(150, 210, 255), "Glass", { q = true, k = "adereco", g = gChafariz, f = "Cylinder", t = 0.3 })

	-- estátua dourada fazendo uma POSE (no lado norte da praça)
	local gEstatua = grupo()
	local base = CFrame.new(0, CALCADA, -34)
	bloco("Pedestal", Vector3.new(10, 6, 10), base * CFrame.new(0, 3, 0), RGB(206, 198, 186), "Marble", { k = "base" })
	bloco("Placa", Vector3.new(6, 1.6, 0.3), base * CFrame.new(0, 3.4, 5.05), RGB(180, 140, 60), "Metal", { k = "enfeite" })
	local ouro = RGB(232, 186, 66)
	local e = base * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(180), 0)
	local function pedaco(nome, tam, cf, forma)
		bloco(nome, tam, e * cf, ouro, "Foil", { q = true, k = "estatua", g = gEstatua, f = forma or "Block" })
	end
	pedaco("PernaE", Vector3.new(1.6, 6, 1.6), CFrame.new(-1.1, 3, 0) * CFrame.Angles(0, 0, math.rad(-8)))
	pedaco("PernaD", Vector3.new(1.6, 6, 1.6), CFrame.new(1.4, 3.2, 0.6) * CFrame.Angles(math.rad(-14), 0, math.rad(12)))
	pedaco("Tronco", Vector3.new(4.4, 5, 2.4), CFrame.new(0.2, 8.4, 0) * CFrame.Angles(0, math.rad(-24), math.rad(8)))
	pedaco("Cabeca", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0.9, 12, -0.2) * CFrame.Angles(0, math.rad(30), 0), "Ball")
	pedaco("BracoD", Vector3.new(1.4, 6, 1.4), CFrame.new(2.6, 12.4, -0.8) * CFrame.Angles(math.rad(10), 0, math.rad(-150)))
	pedaco("BracoE", Vector3.new(1.4, 5.4, 1.4), CFrame.new(-2.8, 8.6, 0.2) * CFrame.Angles(0, 0, math.rad(40)))
	pedaco("Chapeu", Vector3.new(3.4, 0.6, 3.4), CFrame.new(1, 13.4, -0.2) * CFrame.Angles(0, 0, math.rad(-12)))

	-- bancos, postes e árvores em volta da praça
	for _, p in { { -26, -26 }, { 26, -26 }, { -26, 26 }, { 26, 26 } } do
		arvore(p[1], p[2], 1.1)
		poste(p[1] * 1.55, p[2] * 0.6)
		poste(p[1] * 0.6, p[2] * 1.55)
	end
	for _, b in { { -18, -42, 0 }, { 18, -42, 0 }, { -42, 0, 90 }, { 42, 0, -90 }, { -18, 42, 180 }, { 18, 42, 180 } } do
		banco(b[1], b[2], b[3])
	end
	for _, p in { { -40, -40 }, { 40, -40 }, { -40, 40 }, { 40, 40 } } do
		caixote(p[1] + 3, p[2], 2.6)
	end
	table.insert(spawns, CFrame.new(-36, CALCADA + 3, 18))
	table.insert(spawns, CFrame.new(36, CALCADA + 3, -18))
	table.insert(spawns, CFrame.new(18, CALCADA + 3, 36))
	table.insert(spawns, CFrame.new(-18, CALCADA + 3, -24))

	----------------------------------------------------------------------------- quarteirões
	local cores = {}
	for i, c in CORES_PREDIO do
		cores[i] = c
	end
	local nc = 0
	local function proximaCor()
		nc += 1
		return cores[(nc - 1) % #cores + 1]
	end

	-- NORTE: torre do relógio + duas lojas
	do
		local cx, cz = 0, -132
		local W, D, andares = 22, 22, 6
		local cor = RGB(198, 120, 92)
		predio(cx, cz + 18, W, D, andares, cor, "fundo")
		-- relógio nas 4 faces do topo
		local topo = CALCADA + andares * ANDAR
		local gR = grupo()
		for _, f in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			local pos = Vector3.new(cx + f[1] * (W / 2 + 0.6), topo - 6, cz + 18 + f[2] * (D / 2 + 0.6))
			local cf = CFrame.lookAt(pos, pos + Vector3.new(f[1], 0, f[2]))
			bloco("Relogio", Vector3.new(1, 9, 9), cf * CFrame.Angles(0, math.rad(90), 0), RGB(250, 246, 232), "SmoothPlastic", { q = true, k = "adereco", g = gR, f = "Cylinder" })
			bloco("Ponteiro", Vector3.new(0.5, 3.6, 0.3), cf * CFrame.new(0, 1.4, -0.65), RGB(30, 30, 30), "SmoothPlastic", { q = true, k = "adereco", g = gR })
			bloco("Ponteiro", Vector3.new(0.5, 2.6, 0.3), cf * CFrame.new(1, 0.2, -0.65) * CFrame.Angles(0, 0, math.rad(-70)), RGB(30, 30, 30), "SmoothPlastic", { q = true, k = "adereco", g = gR })
		end
		-- telhado pontudo (cunhas)
		local h = topo + 1
		for i = 0, 3 do
			bloco("Cupula", Vector3.new(W + 1.6, 10, (W + 1.6) / 2), CFrame.new(cx, h + 5, cz + 18) * CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, 0, -(W + 1.6) / 4), RGB(110, 56, 70), "Slate", { k = "teto", f = "Wedge" })
		end
		predio(cx - 34, cz - 6, 26, 20, 2, proximaCor(), "fundo")
		predio(cx + 34, cz - 6, 26, 20, 3, proximaCor(), "fundo")
		poste(-14, -84)
		poste(14, -84)
		arvore(-34, -96, 0.9)
		arvore(34, -96, 0.9)
		table.insert(spawns, CFrame.new(0, CALCADA + 3, -90))
	end

	-- SUL: área de TREINO (cercada) + dojo
	local treino
	do
		local cx, cz = 0, 132
		predio(cx, cz + 34, 40, 22, 2, RGB(226, 70, 70), "frente")
		cerca(-44, 82, 44, 82)
		cerca(-44, 82, -44, 140)
		cerca(44, 82, 44, 140)
		bloco("TatameTreino", Vector3.new(80, 0.2, 52), CFrame.new(cx, CALCADA + 0.1, 112), RGB(70, 116, 200), "Fabric", { k = "base" })
		bloco("PlacaTreino", Vector3.new(16, 4, 0.6), CFrame.new(cx, CALCADA + 8, 81.6), RGB(250, 210, 50), "SmoothPlastic", { k = "enfeite", placa = "TREINO" })
		bloco("PostePlaca", Vector3.new(0.6, 6, 0.6), CFrame.new(cx - 6, CALCADA + 3, 81.6), RGB(40, 40, 44), "Metal", { k = "enfeite" })
		bloco("PostePlaca", Vector3.new(0.6, 6, 0.6), CFrame.new(cx + 6, CALCADA + 3, 81.6), RGB(40, 40, 44), "Metal", { k = "enfeite" })
		treino = {
			centro = CFrame.new(cx, CALCADA + 3, 112),
			bonecos = {
				CFrame.new(-20, CALCADA + 3, 120) * CFrame.Angles(0, math.rad(180), 0),
				CFrame.new(0, CALCADA + 3, 124) * CFrame.Angles(0, math.rad(180), 0),
				CFrame.new(20, CALCADA + 3, 120) * CFrame.Angles(0, math.rad(180), 0),
			},
			spawn = CFrame.new(0, CALCADA + 3, 96),
		}
		for _, p in { { -36, 136 }, { 36, 136 } } do
			barril(p[1], p[2])
		end
		table.insert(spawns, CFrame.new(-30, CALCADA + 3, 100))
	end

	-- OESTE: feira com barracas + prédio
	do
		local cx, cz = -132, 0
		predio(cx - 30, cz, 28, 40, 3, proximaCor(), "direita")
		local listras = { { RGB(230, 50, 60), RGB(250, 250, 250) }, { RGB(40, 140, 220), RGB(250, 250, 250) }, { RGB(250, 190, 40), RGB(40, 160, 90) } }
		for i = 0, 2 do
			local l = listras[i + 1]
			barraca(cx + 12, cz - 30 + i * 30, 90, l[1], l[2])
		end
		for i = 0, 4 do
			caixote(cx + 22 + R(-2, 2), cz - 38 + i * 17, R(2.4, 3.4))
		end
		barril(cx + 4, cz - 44)
		barril(cx + 4, cz + 44)
		table.insert(spawns, CFrame.new(cx + 30, CALCADA + 3, cz + 12))
	end

	-- LESTE: estacionamento com carros + hotel alto
	do
		local cx, cz = 132, 0
		predio(cx + 30, cz, 30, 46, 5, proximaCor(), "esquerda")
		for i = 0, 3 do
			carro(cx - 22, cz - 33 + i * 22, 90)
			carro(cx + 0, cz - 33 + i * 22, 90)
		end
		for i = 0, 3 do
			bloco("Vaga", Vector3.new(14, 0.06, 0.4), CFrame.new(cx - 11, CALCADA + 0.03, cz - 44 + i * 22), RGB(240, 240, 240), "SmoothPlastic", { k = "enfeite", semColisao = true })
		end
		table.insert(spawns, CFrame.new(cx - 36, CALCADA + 3, cz))
	end

	-- cantos: dois prédios cada + árvores e carros na rua
	local cantos = { { -132, -132 }, { 132, -132 }, { -132, 132 }, { 132, 132 } }
	for i, c in cantos do
		local cx, cz = c[1], c[2]
		local a1 = 2 + (i % 3)
		local a2 = 1 + ((i + 1) % 3)
		predio(cx - 26, cz - 20, 30, 28, a1, proximaCor(), if cz < 0 then "fundo" else "frente")
		predio(cx + 28, cz + 24, 26, 30, a2, proximaCor(), if cx < 0 then "direita" else "esquerda")
		arvore(cx + 26, cz - 30, 1)
		arvore(cx - 30, cz + 30, 1.05)
		caixote(cx + 4, cz + 4, 3)
		table.insert(spawns, CFrame.new(cx + 6, CALCADA + 3, cz - 4))
	end

	-- carros parados nas ruas
	carro(-62, -100, 0)
	carro(62, 104, 180)
	carro(-100, 62, 90)
	carro(108, -62, -90)
	carro(-176, -62, 90)
	carro(176, 62, -90)

	----------------------------------------------------------------------------- limites
	local L = Plano.LIMITE
	for _, w in { { 0, -L, 2 * L, 4 }, { 0, L, 2 * L, 4 }, { -L, 0, 4, 2 * L }, { L, 0, 4, 2 * L } } do
		bloco("Limite", Vector3.new(w[3], 200, w[4]), CFrame.new(w[1], 100, w[2]), RGB(255, 255, 255), "SmoothPlastic", { k = "invisivel", t = 1 })
	end
	-- prédios ao longe (silhueta da cidade, não colidem)
	-- sempre do lado de fora do quadrado jogável (nunca dentro da área de luta)
	for i = 0, 31 do
		local lado = i % 4
		local ao_longo = -300 + (math.floor(i / 4) + 0.5) * (600 / 8) + R(-12, 12)
		local fora = R(262, 320)
		local h = R(40, 120)
		local w = R(30, 56)
		local x, z = ao_longo, fora
		if lado == 1 then
			x, z = ao_longo, -fora
		elseif lado == 2 then
			x, z = fora, ao_longo
		elseif lado == 3 then
			x, z = -fora, ao_longo
		end
		bloco("Longe", Vector3.new(w, h, w), CFrame.new(x, h / 2, z), clarear(CORES_PREDIO[(i % #CORES_PREDIO) + 1], 0.66), "SmoothPlastic", { k = "enfeite", semColisao = true })
	end

	return {
		pecas = pecas,
		spawns = spawns,
		treino = treino,
		predios = predios,
		limite = L,
		-- câmeras do menu (de onde olha, para onde olha)
		vistas = {
			{ Vector3.new(70, 34, 70), Vector3.new(0, 10, 0) },
			{ Vector3.new(-60, 60, -150), Vector3.new(0, 30, -114) },
			{ Vector3.new(-100, 18, 40), Vector3.new(-132, 6, 0) },
			{ Vector3.new(96, 26, -50), Vector3.new(132, 8, 0) },
		},
	}
end

return Plano
