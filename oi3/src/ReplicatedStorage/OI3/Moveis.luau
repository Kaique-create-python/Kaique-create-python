-- OI3 :: móveis e detalhes montados por código (usados no orfanato e no cenário do menu)

local Moveis = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local M = Enum.Material

Moveis.COR = {
	tijolo = RGB(86, 58, 50),
	pedra = RGB(70, 70, 74),
	pedraClara = RGB(112, 110, 106),
	madeiraEscura = RGB(52, 36, 27),
	madeira = RGB(88, 63, 44),
	madeiraClara = RGB(124, 92, 63),
	piso = RGB(74, 53, 38),
	assoalho = RGB(116, 80, 52), -- tábuas do assoalho (AJUSTE-5)
	gesso = RGB(118, 110, 98), -- teto de reboco (AJUSTE-5)
	telhado = RGB(36, 38, 44),
	moldura = RGB(168, 162, 148),
	vidro = RGB(36, 48, 62),
	papelDorm = RGB(62, 72, 64),
	papelCorredor = RGB(78, 44, 44),
	papelEspelho = RGB(52, 58, 74),
	papelHall = RGB(70, 61, 51),
	lambri = RGB(64, 45, 32),
	teto = RGB(44, 35, 29),
	lencol = RGB(194, 190, 180),
	ferro = RGB(26, 26, 30),
	ouro = RGB(150, 116, 62),
	ouroEscuro = RGB(104, 80, 44),
	vela = RGB(230, 222, 198),
	chama = RGB(255, 186, 92),
	luzVela = RGB(255, 168, 98),
	tecidoVermelho = RGB(98, 32, 34),
	cobertores = { RGB(98, 52, 52), RGB(58, 72, 96), RGB(76, 88, 60), RGB(104, 88, 56), RGB(70, 58, 88), RGB(60, 84, 84) },
}
local COR = Moveis.COR

-- Vela (base = centro do pé da vela). Retorna a chama (com luz, se pedido).
function Moveis.vela(c, base: Vector3, opts: { altura: number?, luz: boolean?, alcance: number?, brilho: number?, sombras: boolean?, prato: boolean? }?)
	local o = opts or {}
	local alt = o.altura or 0.6
	if o.prato ~= false then
		c:cilindro(CF(base + V3(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.08, 0.5, COR.ouroEscuro, M.Metal)
	end
	c:coluna(base + V3(0, 0.08, 0), alt, 0.2, COR.vela, M.SmoothPlastic)
	local chama = c:caixa(base + V3(0, 0.08 + alt + 0.13, 0), V3(0.12, 0.12, 0.12), COR.chama, M.Neon, { Name = "OI3_Chama" })
	local malha = Instance.new("SpecialMesh")
	malha.MeshType = Enum.MeshType.Sphere
	malha.Scale = V3(1, 2, 1)
	malha.Parent = chama
	if o.luz then
		c:luz(chama, "PointLight", {
			Range = o.alcance or 12,
			Brightness = o.brilho or 0.8,
			Color = COR.luzVela,
			Shadows = o.sombras or false,
		})
	end
	return chama
end

-- Quadro na parede: centro no plano da parede, normal apontando para dentro da sala
function Moveis.quadro(c, centro: Vector3, normal: Vector3, largura: number, altura: number, corTela: Color3?)
	local d = Vector3.yAxis:Cross(normal).Unit
	local cf = CFrame.fromMatrix(centro + normal * 0.08, d, Vector3.yAxis)
	c:bloco(cf, V3(largura + 0.3, altura + 0.3, 0.12), COR.madeiraEscura, M.Wood)
	c:bloco(cf + normal * 0.05, V3(largura, altura, 0.06), corTela or RGB(58, 52, 46), M.Fabric)
end

-- Porta falsa (fechada) encostada na parede
function Moveis.portaFechada(c, base: Vector3, normal: Vector3, cor: Color3?)
	local d = Vector3.yAxis:Cross(normal).Unit
	local corP = cor or COR.madeira
	local cf = CFrame.fromMatrix(base + Vector3.yAxis * 3.9 + normal * 0.14, d, Vector3.yAxis)
	c:bloco(cf, V3(4.6, 8, 0.12), COR.madeiraEscura, M.Wood) -- batente
	local folha = cf + normal * 0.1
	c:bloco(folha, V3(4, 7.6, 0.14), corP, M.Wood)
	c:bloco(folha * CF(0, 1.8, 0) + normal * 0.08, V3(3, 2.8, 0.06), COR.madeiraEscura, M.Wood)
	c:bloco(folha * CF(0, -1.8, 0) + normal * 0.08, V3(3, 2.8, 0.06), COR.madeiraEscura, M.Wood)
	c:bola((folha * CF(1.5, -0.2, 0)).Position + normal * 0.18, 0.3, COR.ouro, M.Metal)
end

-- Cama de orfanato. pe = direção da cabeceira para os pés. cabeca = ponto no chão encostado na parede.
function Moveis.cama(c, cabeca: Vector3, pe: Vector3, corCoberta: Color3)
	local d = pe.Unit
	local lado = Vector3.yAxis:Cross(d).Unit
	local comprimento, largura = 6.6, 3.4
	local centro = cabeca + d * (comprimento / 2)
	local cfBase = CFrame.fromMatrix(centro, lado, Vector3.yAxis)
	-- estrutura
	c:bloco(cfBase + V3(0, 1.05, 0), V3(largura, 0.3, comprimento), COR.madeira, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c:bloco(cfBase * CF(sx * (largura / 2 - 0.15), 0.6, sz * (comprimento / 2 - 0.15)), V3(0.3, 1.2, 0.3), COR.madeiraEscura, M.Wood)
		end
	end
	-- colchão, lençol, travesseiro, coberta
	c:bloco(cfBase + V3(0, 1.45, 0), V3(largura - 0.2, 0.5, comprimento - 0.2), COR.lencol, M.Fabric)
	c:bloco(cfBase * CF(0, 1.85, -(comprimento / 2 - 0.85)), V3(largura - 0.8, 0.35, 1.1), RGB(214, 210, 200), M.Fabric)
	c:bloco(cfBase * CF(0, 1.78, 0.9), V3(largura, 0.2, comprimento - 2.4), corCoberta, M.Fabric)
	c:bloco(cfBase * CF(0, 1.3, 0.9 + (comprimento - 2.4) / 2), V3(largura, 0.9, 0.16), corCoberta, M.Fabric)
	-- cabeceira e pezeira
	c:bloco(cfBase * CF(0, 1.7, -(comprimento / 2 - 0.1)), V3(largura + 0.2, 3.4, 0.25), COR.madeiraEscura, M.Wood)
	c:bloco(cfBase * CF(0, 3.45, -(comprimento / 2 - 0.1)), V3(largura + 0.5, 0.25, 0.4), COR.madeira, M.Wood)
	c:bloco(cfBase * CF(0, 1.35, comprimento / 2 - 0.1), V3(largura + 0.2, 1.8, 0.25), COR.madeiraEscura, M.Wood)
end

-- Criado-mudo
function Moveis.criado(c, base: Vector3, frente: Vector3)
	local d = Vector3.yAxis:Cross(frente).Unit
	local cf = CFrame.fromMatrix(base + V3(0, 1.1, 0), d, Vector3.yAxis)
	c:bloco(cf, V3(1.8, 2.2, 1.6), COR.madeira, M.Wood)
	c:bloco(cf + V3(0, 1.15, 0), V3(2, 0.12, 1.8), COR.madeiraEscura, M.Wood)
	c:bloco(cf * CF(0, 0.3, 0) + frente * 0.82, V3(1.4, 0.6, 0.06), COR.madeiraEscura, M.Wood)
	c:bola((cf * CF(0, 0.3, 0)).Position + frente * 0.9, 0.16, COR.ouro, M.Metal)
	return base + V3(0, 2.26, 0)
end

-- Cômoda com gavetas
function Moveis.comoda(c, base: Vector3, frente: Vector3, largura: number?)
	local L = largura or 4.4
	local d = Vector3.yAxis:Cross(frente).Unit
	local cf = CFrame.fromMatrix(base + V3(0, 1.7, 0), d, Vector3.yAxis)
	c:bloco(cf, V3(L, 3.4, 1.8), COR.madeira, M.Wood)
	c:bloco(cf + V3(0, 1.75, 0), V3(L + 0.25, 0.14, 2.0), COR.madeiraEscura, M.Wood)
	for i = 0, 2 do
		local y = 1.0 - i * 1.0
		c:bloco(cf * CF(0, y, 0) + frente * 0.92, V3(L - 0.5, 0.78, 0.07), COR.madeiraEscura, M.Wood)
		c:bola((cf * CF(-L * 0.22, y, 0)).Position + frente * 1.0, 0.16, COR.ouro, M.Metal)
		c:bola((cf * CF(L * 0.22, y, 0)).Position + frente * 1.0, 0.16, COR.ouro, M.Metal)
	end
	return base + V3(0, 3.48, 0)
end

-- Cadeira simples (frente = para onde a pessoa sentada olha)
function Moveis.cadeira(c, base: Vector3, frente: Vector3)
	local d = Vector3.yAxis:Cross(frente).Unit
	local cf = CFrame.fromMatrix(base, d, Vector3.yAxis)
	c:bloco(cf * CF(0, 1.6, 0), V3(1.9, 0.18, 1.9), COR.madeira, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c:bloco(cf * CF(sx * 0.8, 0.78, sz * 0.8), V3(0.18, 1.56, 0.18), COR.madeiraEscura, M.Wood)
		end
		c:bloco(cf * CF(sx * 0.8, 2.8, 0.85), V3(0.18, 2.3, 0.18), COR.madeiraEscura, M.Wood)
	end
	c:bloco(cf * CF(0, 3.3, 0.85), V3(1.6, 0.6, 0.12), COR.madeira, M.Wood)
	c:bloco(cf * CF(0, 2.5, 0.85), V3(1.6, 0.14, 0.1), COR.madeira, M.Wood)
end

-- Ursinho de pelúcia (sentado)
function Moveis.ursinho(c, base: Vector3, frente: Vector3)
	local marrom = RGB(112, 82, 58)
	local claro = RGB(150, 118, 86)
	local d = Vector3.yAxis:Cross(frente).Unit
	c:bola(base + V3(0, 0.42, 0), 0.8, marrom, M.Fabric)
	c:bola(base + V3(0, 1.05, 0), 0.6, marrom, M.Fabric)
	c:bola(base + V3(0, 1.02, 0) + frente * 0.26, 0.26, claro, M.Fabric)
	for _, s in { -1, 1 } do
		c:bola(base + V3(0, 1.36, 0) + d * (s * 0.22), 0.22, marrom, M.Fabric)
		c:bola(base + V3(0, 0.52, 0) + d * (s * 0.42) + frente * 0.12, 0.3, marrom, M.Fabric)
		c:bola(base + V3(0, 0.14, 0) + d * (s * 0.24) + frente * 0.32, 0.3, marrom, M.Fabric)
		c:bola(base + V3(0, 1.1, 0) + d * (s * 0.12) + frente * 0.27, 0.07, RGB(14, 12, 12), M.SmoothPlastic)
	end
end

-- Espelho antigo de parede.
-- centro = centro do vidro (no plano da frente do vidro), normal = para dentro da sala.
-- Retorna o vidro (peça) para controle de transparência.
function Moveis.espelho(c, centro: Vector3, normal: Vector3, largura: number, altura: number, nomeVidro: string?)
	local d = Vector3.yAxis:Cross(normal).Unit
	local cf = CFrame.fromMatrix(centro, d, Vector3.yAxis)
	local vidro = c:bloco(cf - normal * 0.05, V3(largura, altura, 0.1), RGB(14, 16, 20), M.Glass, {
		Name = nomeVidro or "VidroEspelho",
		Reflectance = 0.25,
		Transparency = 0,
		colisao = true,
	})
	local t = 0.5
	local prof = 0.5
	local frente = normal * (prof / 2 - 0.1)
	-- a moldura cobre um pouco a borda do vidro (esconde a espessura da parede no reflexo)
	largura -= 0.3
	altura -= 0.3
	c:bloco(cf * CF(0, altura / 2 + t / 2, 0) + frente, V3(largura + 2 * t, t, prof), COR.ouro, M.Metal)
	c:bloco(cf * CF(0, -altura / 2 - t / 2, 0) + frente, V3(largura + 2 * t, t, prof), COR.ouro, M.Metal)
	c:bloco(cf * CF(largura / 2 + t / 2, 0, 0) + frente, V3(t, altura, prof), COR.ouro, M.Metal)
	c:bloco(cf * CF(-largura / 2 - t / 2, 0, 0) + frente, V3(t, altura, prof), COR.ouro, M.Metal)
	-- filete interno escuro
	local f = normal * 0.12
	c:bloco(cf * CF(0, altura / 2 - 0.06, 0) + f, V3(largura, 0.12, 0.08), COR.ouroEscuro, M.Metal)
	c:bloco(cf * CF(0, -altura / 2 + 0.06, 0) + f, V3(largura, 0.12, 0.08), COR.ouroEscuro, M.Metal)
	c:bloco(cf * CF(largura / 2 - 0.06, 0, 0) + f, V3(0.12, altura, 0.08), COR.ouroEscuro, M.Metal)
	c:bloco(cf * CF(-largura / 2 + 0.06, 0, 0) + f, V3(0.12, altura, 0.08), COR.ouroEscuro, M.Metal)
	-- coroa (arco no topo) e enfeites
	local topo = cf * CF(0, altura / 2 + t, 0)
	c:cilindro(topo * CF(0, 0.15, 0) * CFrame.Angles(0, math.pi / 2, 0) + frente, prof, 2.2, COR.ouro, M.Metal)
	c:bloco(topo * CF(0, -0.3, 0) + frente, V3(2.6, 0.6, prof + 0.02), COR.ouro, M.Metal)
	c:bola((topo * CF(0, 1.35, 0)).Position + frente, 0.5, COR.ouro, M.Metal)
	for _, s in { -1, 1 } do
		c:bola((cf * CF(s * (largura / 2 + t / 2), altura / 2 + t / 2, 0)).Position + frente + normal * 0.1, 0.62, COR.ouro, M.Metal)
		c:bola((cf * CF(s * (largura / 2 + t / 2), -altura / 2 - t / 2, 0)).Position + frente + normal * 0.1, 0.62, COR.ouro, M.Metal)
		c:bola((topo * CF(s * 1.5, 0.2, 0)).Position + frente, 0.36, COR.ouro, M.Metal)
	end
	return vidro
end

-- Janela com moldura. centro = centro da abertura na linha central da parede.
-- d = direção ao longo da parede, fora = normal para o lado de fora.
function Moveis.janela(
	c,
	centro: Vector3,
	d: Vector3,
	fora: Vector3,
	largura: number,
	altura: number,
	opts: { acesa: boolean?, cortina: boolean?, cortinasTecido: boolean?, profundidade: number? }?
)
	local o = opts or {}
	local prof = o.profundidade or 1.12
	local cf = CFrame.fromMatrix(centro, d, Vector3.yAxis)
	c:bloco(cf, V3(largura, altura, 0.12), COR.vidro, M.Glass, { Transparency = 0.45, Reflectance = 0.06, colisao = true, Name = "Vidro" })
	local t = 0.32
	c:bloco(cf * CF(0, altura / 2 + t / 2, 0), V3(largura + 2 * t, t, prof), COR.moldura, M.Wood)
	c:bloco(cf * CF(0, -altura / 2 - t / 2, 0), V3(largura + 2 * t, t, prof), COR.moldura, M.Wood)
	c:bloco(cf * CF(largura / 2 + t / 2, 0, 0), V3(t, altura, prof), COR.moldura, M.Wood)
	c:bloco(cf * CF(-largura / 2 - t / 2, 0, 0), V3(t, altura, prof), COR.moldura, M.Wood)
	c:bloco(cf, V3(0.15, altura, 0.3), COR.moldura, M.Wood)
	c:bloco(cf * CF(0, altura * 0.18, 0), V3(largura, 0.15, 0.3), COR.moldura, M.Wood)
	-- peitoril de fora
	c:bloco(CFrame.fromMatrix(centro + fora * 0.62 - Vector3.yAxis * (altura / 2 + t + 0.1), d, Vector3.yAxis), V3(largura + 1, 0.26, 0.55), COR.pedraClara, M.Concrete)
	if o.acesa then
		c:bloco(cf - fora * 0.62, V3(largura, altura, 0.1), RGB(255, 170, 90), M.Neon, { Transparency = 0.45, Name = "JanelaAcesa" })
	end
	if o.cortina then
		c:bloco(cf - fora * 0.72, V3(largura + 0.2, altura + 0.2, 0.1), RGB(12, 10, 10), M.Fabric)
	end
	if o.cortinasTecido then
		for _, s in { -1, 1 } do
			c:bloco(cf * CF(s * (largura / 2 + 0.1), 0.2, 0) - fora * 0.75, V3(1.1, altura + 1.2, 0.15), COR.tecidoVermelho, M.Fabric)
		end
		c:bloco(cf * CF(0, altura / 2 + 0.75, 0) - fora * 0.8, V3(largura + 2.6, 0.18, 0.18), COR.ouroEscuro, M.Metal)
	end
end

-- Lustre simples com velas
function Moveis.lustre(c, centro: Vector3, raio: number?, brilho: number?)
	local r = raio or 1.6
	c:coluna(centro + V3(0, 0.2, 0), 2.6, 0.12, COR.ferro, M.Metal)
	c:cilindro(CF(centro) * CFrame.Angles(0, 0, math.pi / 2), 0.15, r * 2, COR.ferro, M.Metal)
	local principal = nil
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p = centro + V3(math.cos(a) * r * 0.85, 0.08, math.sin(a) * r * 0.85)
		local ch = Moveis.vela(c, p, { altura = 0.4, prato = false, luz = false })
		if i == 0 then
			principal = ch
		end
	end
	if principal then
		c:luz(principal, "PointLight", { Range = 26, Brightness = brilho or 0.35, Color = COR.luzVela, Shadows = true })
	end
end

-- Arandela de parede com vela
function Moveis.arandela(c, base: Vector3, normal: Vector3, brilho: number?)
	c:bloco(CFrame.lookAt(base, base + normal), V3(0.4, 0.8, 0.2), COR.ouroEscuro, M.Metal)
	c:bloco(CFrame.lookAt(base + normal * 0.45 - V3(0, 0.3, 0), base + normal * 2), V3(0.7, 0.12, 0.7), COR.ouroEscuro, M.Metal)
	return Moveis.vela(c, base + normal * 0.45 - V3(0, 0.24, 0), { altura = 0.5, prato = false, luz = true, alcance = 13, brilho = brilho or 0.55 })
end

---------------------------------------------------------------------------
-- AJUSTE-3: mais detalhes
---------------------------------------------------------------------------

local function marcarFX(obj: Instance)
	obj:SetAttribute("OI3_FX", true)
end
Moveis.marcarFX = marcarFX

local function quadroDe(base: Vector3, frente: Vector3): CFrame
	local d = Vector3.yAxis:Cross(frente).Unit
	return CFrame.fromMatrix(base, d, Vector3.yAxis) -- Z local = frente
end

-- Estante com livros (base = centro do pé encostado na parede, frente = para a sala)
function Moveis.estante(c, base: Vector3, frente: Vector3, largura: number?, altura: number?, semente: number?)
	local L = largura or 4
	local A = altura or 7
	local P = 1.3
	local cf = quadroDe(base + V3(0, A / 2, 0) + frente * (P / 2), frente)
	c:bloco(cf * CF(-L / 2 + 0.1, 0, 0), V3(0.2, A, P), COR.madeiraEscura, M.Wood)
	c:bloco(cf * CF(L / 2 - 0.1, 0, 0), V3(0.2, A, P), COR.madeiraEscura, M.Wood)
	c:bloco(cf * CF(0, 0, -P / 2 + 0.05), V3(L, A, 0.1), COR.madeira, M.Wood)
	c:bloco(cf * CF(0, A / 2 - 0.1, 0.05), V3(L + 0.2, 0.2, P + 0.1), COR.madeiraEscura, M.Wood)
	local andares = 4
	local alt = A / andares
	for i = 0, andares - 1 do
		c:bloco(cf * CF(0, -A / 2 + 0.08 + i * alt, 0), V3(L - 0.3, 0.16, P - 0.05), COR.madeiraEscura, M.Wood)
	end
	local rnd = Random.new(semente or 7)
	local cores = { RGB(92, 34, 32), RGB(46, 58, 44), RGB(40, 48, 70), RGB(110, 86, 52), RGB(70, 52, 40), RGB(128, 116, 92), RGB(58, 40, 56) }
	for andar = 0, andares - 2 do
		local x = -L / 2 + 0.3
		local yb = -A / 2 + 0.16 + andar * alt
		while x < L / 2 - 0.45 do
			if rnd:NextNumber() < 0.08 then
				x += rnd:NextNumber(0.3, 0.6) -- um vão
			else
				local w = rnd:NextNumber(0.13, 0.28)
				local h = math.min(rnd:NextNumber(0.85, 1.35), alt - 0.3)
				local cor = cores[rnd:NextInteger(1, #cores)]
				local inclinado = rnd:NextNumber() < 0.07
				local cfLivro = cf * CF(x + w / 2, yb + h / 2, 0.08)
				if inclinado then
					cfLivro = cfLivro * CFrame.Angles(0, 0, math.rad(14))
				end
				c:bloco(cfLivro, V3(w, h, P * 0.68), cor, M.Fabric)
				x += w + 0.015
			end
		end
	end
end

-- Lareira de pedra com fogo de verdade (base = centro do pé na parede, frente = para a sala)
function Moveis.lareira(c, base: Vector3, frente: Vector3, alturaTeto: number)
	local cf = quadroDe(base, frente)
	local pedra = RGB(84, 80, 78)
	c:bloco(cf * CF(-2.5, 2.3, 0.85), V3(1.3, 4.6, 1.7), pedra, M.Slate, { colisao = true })
	c:bloco(cf * CF(2.5, 2.3, 0.85), V3(1.3, 4.6, 1.7), pedra, M.Slate, { colisao = true })
	c:bloco(cf * CF(0, 4.0, 0.85), V3(3.7, 1.2, 1.7), pedra, M.Slate)
	c:bloco(cf * CF(0, 0.15, 1.05), V3(6.8, 0.3, 2.1), RGB(70, 66, 64), M.Slate, { colisao = true })
	c:bloco(cf * CF(0, 4.75, 0.95), V3(7.2, 0.3, 2.0), COR.madeiraEscura, M.Wood)
	c:bloco(cf * CF(0, 1.7, 0.18), V3(3.7, 3.4, 0.35), RGB(14, 11, 10), M.Slate)
	c:bloco(cf * CF(0, 4.9 + (alturaTeto - 4.9) / 2, 0.55), V3(5.4, alturaTeto - 4.9, 1.1), RGB(96, 64, 54), M.Brick)
	-- lenha
	local lenha = RGB(62, 42, 30)
	c:cilindro(cf * CF(-0.4, 0.55, 0.95) * CFrame.Angles(0, 0.25, 0), 2.2, 0.36, lenha, M.Wood)
	c:cilindro(cf * CF(0.45, 0.55, 1.05) * CFrame.Angles(0, -0.3, 0), 2.0, 0.34, lenha, M.Wood)
	c:cilindro(cf * CF(0, 0.86, 0.98) * CFrame.Angles(0, 0.06, 0), 1.8, 0.3, RGB(48, 32, 24), M.Wood)
	local brasa = c:bloco(cf * CF(0, 0.4, 0.95), V3(2.2, 0.12, 0.9), RGB(255, 110, 40), M.Neon, { Name = "OI3_Chama" })
	local fogo = Instance.new("Fire")
	fogo.Size = 3.6
	fogo.Heat = 6
	fogo.Color = RGB(255, 142, 52)
	fogo.SecondaryColor = RGB(255, 70, 24)
	fogo.Parent = brasa
	c:luz(brasa, "PointLight", { Range = 26, Brightness = 1.6, Color = RGB(255, 150, 82), Shadows = true })
	-- grade de ferro na frente
	for i = -3, 3 do
		c:bloco(cf * CF(i * 0.5, 0.9, 1.95), V3(0.07, 1.5, 0.07), COR.ferro, M.Metal)
	end
	c:bloco(cf * CF(0, 1.62, 1.95), V3(3.3, 0.08, 0.08), COR.ferro, M.Metal)
	return (cf * CF(0, 4.9, 1.0)).Position
end

-- Teia de aranha num canto do teto (canto + duas direções ao longo das paredes)
function Moveis.teia(c, canto: Vector3, dirA: Vector3, dirB: Vector3, tam: number?)
	local T = tam or 1.8
	local cor = RGB(196, 196, 202)
	local baixo = V3(0, -1, 0)
	local pontos = {
		canto + dirA * T,
		canto + (dirA + baixo * 0.6).Unit * T,
		canto + (dirA + dirB + baixo * 0.7).Unit * T * 1.05,
		canto + (dirB + baixo * 0.6).Unit * T,
		canto + dirB * T,
	}
	local function fio(a: Vector3, b: Vector3)
		local comp = (b - a).Magnitude
		if comp < 0.05 then
			return
		end
		c:bloco(CFrame.lookAt((a + b) / 2, b), V3(0.025, 0.025, comp), cor, M.SmoothPlastic, { Transparency = 0.45, Name = "Teia" })
	end
	for _, p in pontos do
		fio(canto, p)
	end
	for _, k in { 0.45, 0.8 } do
		for i = 1, #pontos - 1 do
			fio(canto + (pontos[i] - canto) * k, canto + (pontos[i + 1] - canto) * k)
		end
	end
end

-- Desenho de criança num papel preso na parede (normal = para a sala)
function Moveis.desenho(c, centro: Vector3, normal: Vector3, tipo: number)
	local d = Vector3.yAxis:Cross(normal).Unit
	local inclina = CFrame.Angles(0, 0, math.rad(((tipo * 37) % 9) - 4))
	local cf = CFrame.fromMatrix(centro + normal * 0.04, d, Vector3.yAxis) * inclina
	local papel = c:bloco(cf, V3(1.7, 1.25, 0.02), RGB(228, 222, 204), M.SmoothPlastic, { Name = "Desenho" })
	c:bloco(cf * CF(0, 0.56, 0.02), V3(0.18, 0.1, 0.02), RGB(170, 150, 110), M.SmoothPlastic) -- fita
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 90
	sg.LightInfluence = 1
	sg.Parent = papel
	local function linha(x: number, y: number, w: number, h: number, rot: number, cor: Color3, redondo: boolean?)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = rot
		f.BackgroundColor3 = cor
		f.BorderSizePixel = 0
		if redondo then
			local u = Instance.new("UICorner")
			u.CornerRadius = UDim.new(1, 0)
			u.Parent = f
		end
		f.Parent = sg
		return f
	end
	local giz = { RGB(196, 60, 52), RGB(60, 90, 170), RGB(70, 130, 70), RGB(220, 170, 50), RGB(40, 36, 40) }
	if tipo == 1 then
		-- casa, sol e quatro bonequinhos (o Vô e as crianças)
		linha(0.3, 0.55, 0.32, 0.32, 0, giz[1])
		linha(0.3, 0.55, 0.26, 0.26, 0, RGB(228, 222, 204))
		linha(0.22, 0.33, 0.24, 0.04, 35, giz[1])
		linha(0.38, 0.33, 0.24, 0.04, -35, giz[1])
		linha(0.85, 0.18, 0.12, 0.16, 0, giz[4], true)
		for i, x in { 0.56, 0.66, 0.74, 0.82 } do
			local alto = if i == 1 then 1.35 else 1
			local cor = giz[if i == 1 then 5 else (i % 3) + 1]
			linha(x, 0.88 - 0.36 * alto, 0.06, 0.08, 0, cor, true)
			linha(x, 0.88 - 0.2 * alto, 0.012, 0.22 * alto, 0, cor)
			linha(x, 0.85 - 0.22 * alto, 0.08, 0.012, 0, cor)
			linha(x - 0.02, 0.84, 0.012, 0.1, 20, cor)
			linha(x + 0.02, 0.84, 0.012, 0.1, -20, cor)
		end
	elseif tipo == 2 then
		-- árvore e balanço
		linha(0.35, 0.6, 0.05, 0.5, 0, RGB(110, 80, 50))
		linha(0.35, 0.3, 0.36, 0.36, 0, giz[3], true)
		linha(0.65, 0.42, 0.012, 0.36, 0, giz[5])
		linha(0.77, 0.42, 0.012, 0.36, 0, giz[5])
		linha(0.71, 0.24, 0.16, 0.012, 0, giz[5])
		linha(0.71, 0.62, 0.16, 0.035, 0, giz[1])
		linha(0.5, 0.92, 0.9, 0.02, 0, giz[3])
	else
		-- rabiscos
		for i = 1, 9 do
			linha(0.2 + (i % 3) * 0.3, 0.25 + math.floor(i / 3) * 0.22, 0.28, 0.018, (i * 47) % 180, giz[(i % 5) + 1])
		end
	end
	return papel
end

-- Boneca de pano (sentada, olhos de botão)
function Moveis.boneca(c, base: Vector3, frente: Vector3)
	local cf = quadroDe(base, frente)
	local vestido = RGB(120, 70, 86)
	c:bloco(cf * CF(0, 0.32, 0), V3(0.5, 0.55, 0.36), vestido, M.Fabric)
	c:bloco(cf * CF(0, 0.06, 0.12), V3(0.62, 0.12, 0.5), vestido, M.Fabric)
	c:bola((cf * CF(0, 0.78, 0)).Position, 0.44, RGB(232, 210, 186), M.Fabric)
	c:bola((cf * CF(0, 0.86, -0.06)).Position, 0.48, RGB(70, 42, 30), M.Fabric)
	c:bola((cf * CF(-0.09, 0.8, 0.2)).Position, 0.07, RGB(10, 10, 12), M.SmoothPlastic)
	c:bola((cf * CF(0.09, 0.8, 0.2)).Position, 0.07, RGB(10, 10, 12), M.SmoothPlastic)
	c:bloco(cf * CF(-0.3, 0.36, 0.05) * CFrame.Angles(0, 0, 0.3), V3(0.12, 0.4, 0.12), RGB(232, 210, 186), M.Fabric)
	c:bloco(cf * CF(0.3, 0.36, 0.05) * CFrame.Angles(0, 0, -0.3), V3(0.12, 0.4, 0.12), RGB(232, 210, 186), M.Fabric)
	c:bloco(cf * CF(-0.12, 0.08, 0.36), V3(0.13, 0.13, 0.4), RGB(232, 210, 186), M.Fabric)
	c:bloco(cf * CF(0.12, 0.08, 0.36), V3(0.13, 0.13, 0.4), RGB(232, 210, 186), M.Fabric)
end

-- Blocos de brinquedo espalhados
function Moveis.blocos(c, base: Vector3, semente: number?)
	local rnd = Random.new(semente or 3)
	local cores = { RGB(170, 60, 50), RGB(60, 100, 160), RGB(210, 170, 60), RGB(80, 140, 80) }
	local pos = { V3(0, 0.3, 0), V3(0.7, 0.3, 0.2), V3(0.3, 0.9, 0.08), V3(-0.6, 0.3, 0.6) }
	for i, p in pos do
		c:bloco(CF(base + p) * CFrame.Angles(0, rnd:NextNumber(-0.6, 0.6), 0), V3(0.6, 0.6, 0.6), cores[i], M.Wood)
	end
end

-- Postigos (janelas por fora): d = ao longo da parede, fora = normal para fora
function Moveis.postigos(c, centro: Vector3, d: Vector3, fora: Vector3, largura: number, altura: number)
	local cor = RGB(38, 50, 46)
	for _, s in { -1, 1 } do
		local p = centro + d * (s * (largura / 2 + 0.32 + 0.8)) + fora * 0.62
		local cf = CFrame.fromMatrix(p, d, Vector3.yAxis)
		c:bloco(cf, V3(1.5, altura + 0.4, 0.14), cor, M.Wood)
		c:bloco(cf * CF(0, altura * 0.3, 0) + fora * 0.06, V3(1.3, 0.14, 0.06), RGB(30, 40, 36), M.Wood)
		c:bloco(cf * CF(0, -altura * 0.3, 0) + fora * 0.06, V3(1.3, 0.14, 0.06), RGB(30, 40, 36), M.Wood)
	end
end

-- Feixe de luar entrando por uma janela (raio de luz + mancha no chão)
function Moveis.luar(c, janela: Vector3, chao: Vector3, comLuz: boolean?)
	local p0 = c:caixa(janela, V3(0.2, 0.2, 0.2), RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, Name = "LuarJanela" })
	p0.CFrame = CFrame.lookAt(janela, chao)
	local p1 = c:caixa(chao, V3(0.2, 0.2, 0.2), RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, Name = "LuarChao" })
	local a0 = Instance.new("Attachment")
	a0.Parent = p0
	local a1 = Instance.new("Attachment")
	a1.Parent = p1
	local b = Instance.new("Beam")
	b.Name = "OI3_Luar"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = 3.2
	b.Width1 = 5.5
	b.FaceCamera = true
	b.LightEmission = 0.55
	b.LightInfluence = 0
	b.Segments = 1
	b.Color = ColorSequence.new(RGB(150, 170, 222))
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(0.65, 0.91), NumberSequenceKeypoint.new(1, 1) })
	b.Parent = p0
	marcarFX(b)
	if comLuz then
		c:luz(p0, "SpotLight", { Brightness = 1.5, Range = 34, Angle = 50, Color = RGB(140, 160, 216), Face = Enum.NormalId.Front, Shadows = true })
	end
	return b
end

-- Poeira no ar: só aparece onde tem luz (ótima com a lanterna)
function Moveis.poeira(c, minimo: Vector3, maximo: Vector3, taxa: number?)
	local vol = c:entre(minimo, maximo, RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, colisao = false, CanQuery = false, CastShadow = false, Name = "VolumePoeira" })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "OI3_Poeira"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = taxa or 8
	pe.Lifetime = NumberRange.new(8, 14)
	pe.Speed = NumberRange.new(0.03, 0.18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.06)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(0.75, 0.45), NumberSequenceKeypoint.new(1, 1) })
	pe.LightEmission = 0.1
	pe.LightInfluence = 1
	pe.Color = ColorSequence.new(RGB(255, 246, 228))
	pe.Acceleration = V3(0.02, -0.01, 0.01)
	pe.Parent = vol
	marcarFX(pe)
	return pe
end

-- Névoa rasteira (lá fora)
function Moveis.nevoa(c, centro: Vector3, tamanho: Vector3, taxa: number?)
	local vol = c:caixa(centro, tamanho, RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, colisao = false, CanQuery = false, CastShadow = false, Name = "VolumeNevoa" })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "OI3_Nevoa"
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Rate = taxa or 1.6
	pe.Lifetime = NumberRange.new(14, 22)
	pe.Speed = NumberRange.new(0.3, 1.0)
	pe.SpreadAngle = Vector2.new(180, 8)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 24) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.87), NumberSequenceKeypoint.new(0.7, 0.89), NumberSequenceKeypoint.new(1, 1) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-6, 6)
	pe.LightEmission = 0
	pe.LightInfluence = 1
	pe.Color = ColorSequence.new(RGB(170, 184, 206))
	pe.Acceleration = V3(0.25, 0, 0.08)
	pe.Parent = vol
	marcarFX(pe)
	return pe
end

-- Mariposas voando perto de uma lâmpada
function Moveis.mariposas(c, centro: Vector3)
	local vol = c:caixa(centro, V3(1.5, 1.5, 1.5), RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, colisao = false, CanQuery = false, CastShadow = false, Name = "VolumeMariposas" })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "OI3_Mariposas"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 3
	pe.Lifetime = NumberRange.new(1.5, 3)
	pe.Speed = NumberRange.new(1.5, 3.5)
	pe.SpreadAngle = Vector2.new(360, 360)
	pe.Size = NumberSequence.new(0.09)
	pe.Drag = 2
	pe.LightEmission = 0.4
	pe.Color = ColorSequence.new(RGB(240, 232, 210))
	pe.Parent = vol
	marcarFX(pe)
end

-- Pinheiro escuro (silhueta da mata ao longe)
function Moveis.pinheiro(c, base: Vector3, altura: number, raio: number)
	local escuro = RGB(16, 22, 18)
	c:coluna(base, altura * 0.25, raio * 0.18, RGB(26, 20, 16), M.Wood, { sombra = false })
	for i = 0, 3 do
		local y = altura * (0.2 + i * 0.2)
		local r = raio * (1 - i * 0.22)
		c:coluna(base + V3(0, y, 0), altura * 0.24, r * 2, escuro, M.LeafyGrass, { sombra = false, colisao = false })
	end
end

-- Poço antigo
function Moveis.poco(c, base: Vector3)
	local pedra = RGB(92, 88, 84)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = base + V3(math.cos(a) * 1.9, 1.1, math.sin(a) * 1.9)
		c:bloco(CFrame.lookAt(p, base + V3(0, 1.1, 0)), V3(1.7, 2.2, 0.6), pedra, M.Cobblestone, { colisao = true })
	end
	c:cilindro(CF(base + V3(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), 0.1, 3.4, RGB(6, 6, 8), M.SmoothPlastic)
	for _, s in { -1, 1 } do
		c:coluna(base + V3(s * 2.0, 2.2, 0), 3.6, 0.3, COR.madeiraEscura, M.Wood)
	end
	c:cunha(CF(base + V3(0, 6.3, 0.9)) * CFrame.Angles(0, math.pi, 0), V3(5, 1.2, 1.8), COR.telhado, M.Slate)
	c:cunha(CF(base + V3(0, 6.3, -0.9)), V3(5, 1.2, 1.8), COR.telhado, M.Slate)
	c:cilindro(CF(base + V3(0, 4.8, 0)), 4.2, 0.25, COR.madeira, M.Wood)
	c:bloco(CF(base + V3(0.3, 3.7, 0)), V3(0.05, 2.2, 0.05), RGB(120, 100, 70), M.Fabric)
	c:coluna(base + V3(0.3, 2.3, 0), 0.6, 0.55, RGB(80, 60, 40), M.Wood)
end

-- Banco de madeira
function Moveis.banco(c, base: Vector3, frente: Vector3)
	local cf = quadroDe(base, frente)
	c:bloco(cf * CF(0, 1.5, 0), V3(4.4, 0.2, 1.4), COR.madeira, M.WoodPlanks)
	c:bloco(cf * CF(0, 2.6, -0.65) * CFrame.Angles(math.rad(-10), 0, 0), V3(4.4, 1.2, 0.18), COR.madeira, M.WoodPlanks)
	for _, s in { -1.9, 1.9 } do
		c:bloco(cf * CF(s, 0.75, 0), V3(0.25, 1.5, 1.2), COR.ferro, M.Metal)
	end
end

---------------------------------------------------------------------------
-- AJUSTE-5: assoalho de tábuas de verdade (cada tábua é uma peça, com emendas
-- desencontradas, frestas escuras e cor variando). É determinístico: a mesma
-- tábua sai igual em qualquer recorte, então o reflexo do espelho bate com o chão.
---------------------------------------------------------------------------
Moveis.VARIANTE = {
	tabua = "OI3_Tabua",
	madeira = "OI3_Madeira",
	papel = "OI3_Papel",
	tecido = "OI3_Tecido",
	tijolo = "OI3_Tijolo",
	pedra = "OI3_Pedra",
	gesso = "OI3_Gesso",
	telhado = "OI3_Telhado",
}

local LARGURA_TABUA = 0.9
local FRESTA = 0.05
local X_GLOBAL_MIN, X_GLOBAL_MAX = -90, 100

function Moveis.assoalho(c, x0: number, z0: number, x1: number, z1: number, y: number, corBase: Color3?): number
	local base = corBase or RGB(118, 82, 54)
	local h, sat, v = base:ToHSV()
	local n = 0
	local fila = math.floor(z0 / LARGURA_TABUA)
	while fila * LARGURA_TABUA < z1 do
		local zA = fila * LARGURA_TABUA + FRESTA / 2
		local zB = (fila + 1) * LARGURA_TABUA - FRESTA / 2
		local za, zb = math.max(zA, z0), math.min(zB, z1)
		local g = Random.new(fila * 7919 + 1301)
		local x = X_GLOBAL_MIN + g:NextNumber(0, 9)
		while x < X_GLOBAL_MAX do
			local comp = g:NextNumber(7, 15)
			local tom = g:NextNumber(-1, 1)
			local gasto = g:NextNumber(0, 1)
			local xa, xb = math.max(x, x0), math.min(x + comp - FRESTA, x1)
			if zb - za > 0.05 and xb - xa > 0.1 then
				local cor = Color3.fromHSV(
					(h + tom * 0.012) % 1,
					math.clamp(sat * (1 + tom * 0.12), 0, 1),
					math.clamp(v * (1 + tom * 0.16 - (if gasto > 0.85 then 0.18 else 0)), 0, 1)
				)
				c:entre(Vector3.new(xa, y - 0.12, za), Vector3.new(xb, y, zb), cor, M.Wood, {
					colisao = false,
					CastShadow = false,
					MaterialVariant = Moveis.VARIANTE.tabua,
					Name = "Tabua",
				})
				n += 1
			end
			x += comp
		end
		fila += 1
	end
	return n
end

-- Aplica as texturas realistas (MaterialVariant) em todas as peças de um modelo.
-- Se o instalador não conseguiu enviar uma textura, o nome não existe no MaterialService
-- e o Roblox simplesmente usa o material normal da peça.
function Moveis.aplicarVariantes(raiz: Instance): number
	local V = Moveis.VARIANTE
	local n = 0
	for _, p in raiz:GetDescendants() do
		if p:IsA("BasePart") and p.MaterialVariant == "" and p.Transparency < 0.95 then
			local m = p.Material
			local nome = nil
			if m == M.Wood then
				nome = V.madeira
			elseif m == M.Fabric then
				nome = if p.Name == "Papel" then V.papel else V.tecido
			elseif m == M.Brick then
				nome = V.tijolo
			elseif m == M.Slate then
				nome = if p.Name == "Telhado" then V.telhado else V.pedra
			elseif m == M.Plaster then
				nome = V.gesso
			end
			if nome then
				p.MaterialVariant = nome
				n += 1
			end
		end
	end
	return n
end

return Moveis
