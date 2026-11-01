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
		c:luz(principal, "PointLight", { Range = 26, Brightness = brilho or 0.35, Color = COR.luzVela, Shadows = false })
	end
end

-- Arandela de parede com vela
function Moveis.arandela(c, base: Vector3, normal: Vector3, brilho: number?)
	c:bloco(CFrame.lookAt(base, base + normal), V3(0.4, 0.8, 0.2), COR.ouroEscuro, M.Metal)
	c:bloco(CFrame.lookAt(base + normal * 0.45 - V3(0, 0.3, 0), base + normal * 2), V3(0.7, 0.12, 0.7), COR.ouroEscuro, M.Metal)
	return Moveis.vela(c, base + normal * 0.45 - V3(0, 0.24, 0), { altura = 0.5, prato = false, luz = true, alcance = 13, brilho = brilho or 0.55 })
end

return Moveis
