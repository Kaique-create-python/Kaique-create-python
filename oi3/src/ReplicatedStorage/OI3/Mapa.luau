-- OI3 :: o orfanato. Construído por código no servidor (e o quarto do espelho
-- também pode ser montado refletido no cliente, para o efeito do espelho).

local Construtor = require(script.Parent.Construtor)
local Moveis = require(script.Parent.Moveis)

local Mapa = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local M = Enum.Material
local COR = Moveis.COR

-- Medidas principais (studs)
local F = 1 -- altura do piso
local H = 13 -- pé-direito do térreo
local TETO = F + H
local H2 = 27 -- topo da fachada (2º andar só por fora)
local X0, X1 = -36, 36 -- prédio principal
local Z0, Z1 = -24, 12 -- Z1 = fachada (frente aponta para +Z)
local XDH = -12 -- parede dormitório | hall
local XHL = 12 -- parede hall | bloco leste
local ZC = 4 -- corredor entre -ZC e +ZC
local XQE = 56 -- parede corredor | quarto do espelho
local XL = 70.5 -- parede leste da ala
local ZA = 8.5 -- ala entre -ZA e +ZA
local XESP = 69.85 -- plano da frente do vidro do espelho
local ESP_L, ESP_A = 4.4, 7 -- tamanho do vidro
local ESP_Y = F + 1.3 + ESP_A / 2 -- centro do vidro

Mapa.L = {
	F = F,
	H = H,
	TETO = TETO,
	H2 = H2,
	XESP = XESP,
	ESP_L = ESP_L,
	ESP_A = ESP_A,
	ESP_Y = ESP_Y,
}

-- Pontos usados pela cutscene e pelo spawn
function Mapa.pontos()
	return {
		-- exterior
		camExtA = CFrame.lookAt(V3(-7, 4.2, 96), V3(0, 15, 0)),
		camExtB = CFrame.lookAt(V3(-3, 6.5, 50), V3(0, 16, 0)),
		porta = V3(0, F, 12),
		-- dormitório (posição dos pés)
		menino = V3(-26, F, -13.6),
		nina = V3(-20.6, F, -13.4),
		keko = V3(-31.5, F, 1.2),
		kekoPerto = V3(-23.3, F, -9.0),
		vo = V3(-14.6, F, -1.0),
		voSaida = V3(-5, F, 0.5),
		portaDorm = V3(XDH, F, 0),
		-- corredor
		corrIni = V3(14, F, 0),
		corrFim = V3(54.5, F, 0),
		-- quarto do espelho
		espMenino = V3(66.2, F, 0),
		espNina = V3(61.7, F, -3.1),
		espKeko = V3(61.3, F, 3.0),
		espelhoCentro = V3(XESP, ESP_Y, 0),
		espelhoNormal = V3(-1, 0, 0),
		-- exploração
		spawn = CFrame.new(-24, F + 3.5, -5) * CFrame.Angles(0, math.rad(90), 0),
	}
end

-- Reflexo do quarto do espelho (plano do vidro)
function Mapa.refletorEspelho(): (CFrame) -> CFrame
	return Construtor.refletorPlano(V3(XESP, 0, 0), V3(-1, 0, 0))
end

---------------------------------------------------------------------------
-- Paredes em camadas
---------------------------------------------------------------------------

type AbAbs = { c: number, w: number, y0: number, y1: number } -- abertura em coordenadas absolutas

local function infoParede(p1: Vector3, p2: Vector3)
	local a = V3(p1.X, 0, p1.Z)
	local b = V3(p2.X, 0, p2.Z)
	local d = (b - a).Unit
	local n = d:Cross(Vector3.yAxis)
	return a, b, d, n
end

local function relativas(aberturas: { AbAbs }?, yBase: number)
	local lista = {}
	for _, ab in aberturas or {} do
		table.insert(lista, { centro = ab.c, largura = ab.w, base = ab.y0 - yBase, topo = ab.y1 - yBase })
	end
	return lista
end

-- Camada de uma parede, deslocada para um dos lados da linha central
local function camada(c, p1, p2, lado, esp, yBase, altura, cor, mat, aberturas, extra)
	local a, b, _, n = infoParede(p1, p2)
	local off = n * (lado * esp / 2)
	return c:parede(a + off, b + off, yBase, altura, esp, cor, mat, relativas(aberturas, yBase), extra)
end

-- Face interna de uma sala: papel de parede + lambri + rodapé + friso
local function faceSala(c, p1, p2, lado, papel, aberturas, semLambri)
	local a, b, _, n = infoParede(p1, p2)
	local function em(dist, esp, y0, alt, cor, mat)
		local off = n * (lado * dist)
		c:parede(a + off, b + off, y0, alt, esp, cor, mat, relativas(aberturas, y0))
	end
	em(0.25, 0.5, F, H, papel, M.Fabric)
	if not semLambri then
		em(0.56, 0.12, F, 3.2, COR.lambri, M.WoodPlanks)
		em(0.62, 0.24, F + 3.2, 0.22, COR.madeiraEscura, M.Wood)
		em(0.62, 0.24, F, 0.45, COR.madeiraEscura, M.Wood)
	end
end

---------------------------------------------------------------------------
-- Quarto do espelho (parte que pode ser refletida)
---------------------------------------------------------------------------

-- reflexo = true: monta piso/teto próprios e corta tudo antes do plano do espelho
function Mapa.construirQuartoEspelho(c, reflexo: boolean?)
	local xFim = if reflexo then 69.7 else XL
	local refs = {}
	if reflexo then
		c:laje(XQE, -ZA, xFim, ZA, F, 0.6, COR.piso, M.WoodPlanks, { colisao = false })
		c:laje(XQE, -ZA, xFim, ZA, TETO + 0.5, 0.5, COR.teto, M.Wood, { colisao = false })
		-- "corredor" escuro atrás da porta refletida
		c:entre(V3(XQE - 4.5, F, -3), V3(XQE - 0.6, F + 9, 3), RGB(4, 4, 6), M.SmoothPlastic, { colisao = false })
	end
	-- paredes (faces internas)
	faceSala(c, V3(XQE, 0, ZA), V3(XQE, 0, -ZA), 1, COR.papelEspelho, { { c = ZA, w = 4.5, y0 = F, y1 = F + 8 } })
	faceSala(c, V3(XQE, 0, ZA), V3(xFim, 0, ZA), -1, COR.papelEspelho, { { c = 63 - XQE, w = 3.2, y0 = F + 3.6, y1 = F + 10 } })
	faceSala(c, V3(xFim, 0, -ZA), V3(XQE, 0, -ZA), -1, COR.papelEspelho, nil)
	-- batente da porta
	local cfPorta = CF(XQE + 0.62, F, 0)
	c:bloco(cfPorta * CF(0, 8.2, 0), V3(0.3, 0.4, 5.3), COR.madeiraEscura, M.Wood)
	c:bloco(cfPorta * CF(0, 4, 2.45), V3(0.3, 8, 0.4), COR.madeiraEscura, M.Wood)
	c:bloco(cfPorta * CF(0, 4, -2.45), V3(0.3, 8, 0.4), COR.madeiraEscura, M.Wood)
	-- janela da parede norte (lado +Z) com cortinas
	if not reflexo then
		Moveis.janela(c, V3(63, F + 6.8, ZA), V3(1, 0, 0), V3(0, 0, 1), 3.2, 6.4, { cortinasTecido = true })
	else
		-- só a parte de dentro (cortinas)
		for _, s in { -1, 1 } do
			c:bloco(CF(63 + s * 1.7, F + 7, ZA - 0.75), V3(1.1, 7.6, 0.15), COR.tecidoVermelho, M.Fabric)
		end
		c:entre(V3(61.4, F + 3.6, ZA - 0.3), V3(64.6, F + 10, ZA - 0.2), RGB(8, 10, 16), M.SmoothPlastic, { colisao = false })
	end
	-- cômoda com vela (luz principal da cena)
	local topo = Moveis.comoda(c, V3(64.5, F, -ZA + 1.5), V3(0, 0, 1), 4.6)
	refs.vela = Moveis.vela(c, topo + V3(-1.2, 0, 0), { luz = true, alcance = 18, brilho = 0.9, sombras = true })
	Moveis.vela(c, topo + V3(0.9, 0, 0.1), { altura = 0.35 })
	-- cadeira no canto
	Moveis.cadeira(c, V3(58.6, F, 6.2), V3(0.6, 0, -1).Unit)
	-- tapete redondo
	c:cilindro(CF(63, F + 0.04, 0) * CFrame.Angles(0, 0, math.pi / 2), 0.08, 8, RGB(70, 36, 38), M.Fabric)
	c:cilindro(CF(63, F + 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), 0.08, 6.6, RGB(92, 52, 46), M.Fabric)
	-- quadro antigo
	Moveis.quadro(c, V3(60, F + 7.5, -ZA + 0.5), V3(0, 0, 1), 2.6, 3.2, RGB(46, 50, 46))
	return refs
end

---------------------------------------------------------------------------
-- Construção completa
---------------------------------------------------------------------------

function Mapa.construir(pai: Instance)
	local modelo = Instance.new("Model")
	modelo.Name = "Orfanato"
	local estrutura = Instance.new("Folder")
	estrutura.Name = "Estrutura"
	estrutura.Parent = modelo
	local interior = Instance.new("Folder")
	interior.Name = "Interior"
	interior.Parent = modelo
	local exterior = Instance.new("Folder")
	exterior.Name = "Exterior"
	exterior.Parent = modelo

	local c = Construtor.novo(estrutura)
	local ci = Construtor.novo(interior)
	local ce = Construtor.novo(exterior)
	local refs = {}

	-------------------------------------------------------------------
	-- Chão de segurança (fica escondido sob o terreno)
	ce:entre(V3(-120, -6, -90), V3(150, -0.15, 140), RGB(40, 46, 36), M.Ground, { Name = "ChaoBase" })

	-- Fundação e pisos
	c:entre(V3(X0 - 0.7, -1, Z0 - 0.7), V3(X1 + 0.7, F - 0.35, Z1 + 0.7), COR.pedra, M.Slate)
	c:entre(V3(36, -1, -ZA - 0.7), V3(XL + 0.7, F - 0.35, ZA + 0.7), COR.pedra, M.Slate)
	c:laje(X0, Z0, X1, Z1, F, 0.4, COR.piso, M.WoodPlanks)
	c:laje(36, -ZA, XL, ZA, F, 0.4, COR.piso, M.WoodPlanks)
	-- tetos
	c:laje(X0, Z0, X1, Z1, TETO + 0.5, 0.5, COR.teto, M.Wood)
	c:laje(36, -ZA, XL, ZA, TETO + 0.5, 0.5, COR.teto, M.Wood)

	-------------------------------------------------------------------
	-- Paredes externas do prédio principal (camada de tijolo por fora)
	local janelasFrenteTerreo = { -30, -20, -8, 8, 20, 30 }
	local janelasFrente2 = { -30, -20, -8, 8, 20, 30 }
	local abFrente: { AbAbs } = { { c = 36, w = 6, y0 = F, y1 = F + 9 } }
	for _, x in janelasFrenteTerreo do
		table.insert(abFrente, { c = x + 36, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 })
	end
	for _, x in janelasFrente2 do
		table.insert(abFrente, { c = x + 36, w = 3.4, y0 = 17, y1 = 23.6 })
	end
	camada(c, V3(X0 - 0.5, 0, Z1), V3(X1 + 0.5, 0, Z1), 1, 0.5, 0, H2, COR.tijolo, M.Brick, abFrente)

	local abFundo: { AbAbs } = {}
	for _, x in { -30, -20 } do
		table.insert(abFundo, { c = 36.5 - x, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 })
	end
	for _, x in { -30, -20, 20, 30 } do
		table.insert(abFundo, { c = 36.5 - x, w = 3.4, y0 = 17, y1 = 23.6 })
	end
	camada(c, V3(X1 + 0.5, 0, Z0), V3(X0 - 0.5, 0, Z0), 1, 0.5, 0, H2, COR.tijolo, M.Brick, abFundo)

	local abOeste: { AbAbs } = {}
	for _, z in { -12, 0 } do
		table.insert(abOeste, { c = z - Z0, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 })
		table.insert(abOeste, { c = z - Z0, w = 3.4, y0 = 17, y1 = 23.6 })
	end
	camada(c, V3(X0, 0, Z0), V3(X0, 0, Z1), 1, 0.5, 0, H2, COR.tijolo, M.Brick, abOeste)

	camada(c, V3(X1, 0, Z1), V3(X1, 0, Z0), 1, 0.5, 0, H2, COR.tijolo, M.Brick, {
		{ c = Z1, w = 7, y0 = F, y1 = F + 9.5 },
		{ c = Z1 + 18, w = 3.4, y0 = 17, y1 = 23.6 },
	})
	-- camada de dentro do bloco leste (vazio) na parede leste, com passagem do corredor
	camada(c, V3(X1, 0, Z1), V3(X1, 0, Z0), -1, 0.5, F, H, COR.papelCorredor, M.Fabric, { { c = Z1, w = 7, y0 = F, y1 = F + 9.5 } })

	-- faixas de pedra na fachada (frisos)
	c:entre(V3(X0 - 0.75, TETO, Z1 + 0.5), V3(X1 + 0.75, TETO + 0.7, Z1 + 0.85), COR.pedraClara, M.Concrete)
	c:entre(V3(X0 - 0.75, H2 - 0.6, Z1 + 0.5), V3(X1 + 0.75, H2, Z1 + 0.95), COR.pedraClara, M.Concrete)
	c:entre(V3(X0 - 0.85, TETO, Z0 - 0.85), V3(X0 - 0.5, TETO + 0.7, Z1 + 0.85), COR.pedraClara, M.Concrete)

	-- janelas do prédio principal
	for _, x in janelasFrenteTerreo do
		local vazio = (x == 20 or x == 30)
		Moveis.janela(ce, V3(x, F + 7, Z1), V3(1, 0, 0), V3(0, 0, 1), 3.6, 6.8, { cortina = vazio })
	end
	for _, x in janelasFrente2 do
		Moveis.janela(ce, V3(x, 20.3, Z1), V3(1, 0, 0), V3(0, 0, 1), 3.4, 6.6, { acesa = (x == -20), cortina = (x ~= -20) })
	end
	for _, x in { -30, -20 } do
		Moveis.janela(ce, V3(x, F + 7, Z0), V3(-1, 0, 0), V3(0, 0, -1), 3.6, 6.8, {})
	end
	for _, x in { -30, -20, 20, 30 } do
		Moveis.janela(ce, V3(x, 20.3, Z0), V3(-1, 0, 0), V3(0, 0, -1), 3.4, 6.6, { cortina = true })
	end
	for _, z in { -12, 0 } do
		Moveis.janela(ce, V3(X0, F + 7, z), V3(0, 0, 1), V3(-1, 0, 0), 3.6, 6.8, {})
		Moveis.janela(ce, V3(X0, 20.3, z), V3(0, 0, 1), V3(-1, 0, 0), 3.4, 6.6, { cortina = true })
	end
	Moveis.janela(ce, V3(X1, 20.3, -6), V3(0, 0, -1), V3(1, 0, 0), 3.4, 6.6, { cortina = true })

	-------------------------------------------------------------------
	-- Ala leste (corredor + quarto do espelho), térrea
	camada(c, V3(36, 0, ZA), V3(XL + 0.5, 0, ZA), 1, 0.5, 0, TETO + 0.6, COR.tijolo, M.Brick, {
		{ c = 63 - 36, w = 3.2, y0 = F + 3.6, y1 = F + 10 },
	})
	camada(c, V3(XL + 0.5, 0, -ZA), V3(36, 0, -ZA), 1, 0.5, 0, TETO + 0.6, COR.tijolo, M.Brick, nil)
	camada(c, V3(XL, 0, -ZA - 0.5), V3(XL, 0, ZA + 0.5), -1, 0.5, 0, TETO + 0.6, COR.tijolo, M.Brick, {
		{ c = ZA + 0.5, w = ESP_L, y0 = F + 1.3, y1 = F + 1.3 + ESP_A },
	})
	-- camadas internas da ala (vazios ao lado do corredor)
	camada(c, V3(36, 0, ZA), V3(XQE, 0, ZA), -1, 0.5, F, H, COR.papelCorredor, M.Fabric, nil)
	camada(c, V3(XQE, 0, -ZA), V3(36, 0, -ZA), -1, 0.5, F, H, COR.papelCorredor, M.Fabric, nil)
	-- parede leste: face interna do quarto do espelho (com a abertura do espelho)
	faceSala(c, V3(XL, 0, -ZA), V3(XL, 0, ZA), 1, COR.papelEspelho, { { c = ZA, w = ESP_L, y0 = F + 1.3, y1 = F + 1.3 + ESP_A } })
	-- fundo escuro atrás do espelho (quando não há reflexo, o vidro fica opaco)
	c:entre(V3(XL + 0.55, F + 1.2, -ESP_L / 2 - 0.2), V3(XL + 0.7, F + 1.4 + ESP_A, ESP_L / 2 + 0.2), RGB(6, 6, 8), M.SmoothPlastic, { Name = "FundoEspelho" })

	-------------------------------------------------------------------
	-- Paredes internas
	-- dormitório | hall (porta em z=0)
	local abDH = { { c = 12, w = 4.5, y0 = F, y1 = F + 8 } }
	faceSala(ci, V3(XDH, 0, Z1), V3(XDH, 0, Z0), -1, COR.papelDorm, abDH)
	faceSala(ci, V3(XDH, 0, Z1), V3(XDH, 0, Z0), 1, COR.papelHall, abDH)
	-- hall | bloco leste (passagem do corredor)
	local abHL = { { c = 12, w = 7, y0 = F, y1 = F + 9.5 } }
	faceSala(ci, V3(XHL, 0, Z1), V3(XHL, 0, Z0), -1, COR.papelHall, abHL)
	camada(c, V3(XHL, 0, Z1), V3(XHL, 0, Z0), 1, 0.5, F, H, COR.papelCorredor, M.Fabric, abHL)
	-- corredor
	faceSala(ci, V3(XHL, 0, ZC), V3(XQE, 0, ZC), -1, COR.papelCorredor, nil)
	faceSala(ci, V3(XQE, 0, -ZC), V3(XHL, 0, -ZC), -1, COR.papelCorredor, nil)
	camada(c, V3(XHL, 0, ZC), V3(XQE, 0, ZC), 1, 0.5, F, H, COR.papelCorredor, M.Fabric, nil)
	camada(c, V3(XQE, 0, -ZC), V3(XHL, 0, -ZC), 1, 0.5, F, H, COR.papelCorredor, M.Fabric, nil)
	faceSala(ci, V3(XQE, 0, -ZC), V3(XQE, 0, ZC), 1, COR.papelCorredor, { { c = ZC, w = 4.5, y0 = F, y1 = F + 8 } })
	-- faces internas das paredes externas
	faceSala(ci, V3(X0, 0, Z1), V3(XDH, 0, Z1), -1, COR.papelDorm, { { c = 6, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 }, { c = 16, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 } })
	faceSala(ci, V3(XDH, 0, Z1), V3(XHL, 0, Z1), -1, COR.papelHall, {
		{ c = 12, w = 6, y0 = F, y1 = F + 9 },
		{ c = 4, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 },
		{ c = 20, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 },
	})
	faceSala(ci, V3(XDH, 0, Z0), V3(X0, 0, Z0), -1, COR.papelDorm, { { c = 18, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 }, { c = 8, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 } })
	faceSala(ci, V3(XHL, 0, Z0), V3(XDH, 0, Z0), -1, COR.papelHall, nil)
	faceSala(ci, V3(X0, 0, Z0), V3(X0, 0, Z1), -1, COR.papelDorm, { { c = 12, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 }, { c = 24, w = 3.6, y0 = F + 3.6, y1 = F + 10.4 } })

	-- quarto do espelho
	local refsQ = Mapa.construirQuartoEspelho(ci, false)
	refs.velaEspelho = refsQ.vela
	refs.vidroEspelho = Moveis.espelho(ci, V3(XESP, ESP_Y, 0), V3(-1, 0, 0), ESP_L, ESP_A, "VidroEspelho")

	-------------------------------------------------------------------
	-- Telhados
	local function telhadoDuasAguas(xa: number, xb: number, za: number, zb: number, yBeiral: number, subida: number, beiral: number, oitoes: { number })
		local zm = (za + zb) / 2
		local run = (zb - za) / 2 + beiral
		local comp = math.sqrt(run * run + subida * subida)
		local largura = (xb - xa) + 2 * beiral
		local xm = (xa + xb) / 2
		for _, s in { -1, 1 } do
			local beiralP = V3(xm, yBeiral, zm + s * run)
			local cume = V3(xm, yBeiral + subida, zm)
			local centro = (beiralP + cume) / 2
			local cf = CFrame.lookAt(centro, cume)
			c:bloco(cf * CF(0, 0.4, 0), V3(largura, 0.8, comp + 0.6), COR.telhado, M.Slate)
		end
		c:bloco(CF(xm, yBeiral + subida + 0.35, zm), V3(largura + 0.2, 0.6, 1.2), COR.madeiraEscura, M.Wood)
		-- oitões (triângulos)
		local meioRun = (zb - za) / 2
		for _, x in oitoes do
			c:cunha(CF(x, yBeiral + subida / 2, zm + meioRun / 2) * CFrame.Angles(0, math.pi, 0), V3(1, subida, meioRun), COR.tijolo, M.Brick)
			c:cunha(CF(x, yBeiral + subida / 2, zm - meioRun / 2), V3(1, subida, meioRun), COR.tijolo, M.Brick)
		end
	end
	telhadoDuasAguas(X0, X1, Z0, Z1, H2, 11, 1.6, { X0, X1 })
	telhadoDuasAguas(36, XL, -ZA, ZA, TETO + 0.6, 4.5, 1.2, { XL })
	-- chaminé
	c:caixa(V3(18, H2 + 8, -14), V3(3.2, 12, 3.2), COR.tijolo, M.Brick)
	c:caixa(V3(18, H2 + 14.2, -14), V3(3.8, 0.6, 3.8), COR.pedraClara, M.Concrete)
	-- janela redonda no oitão da frente? (sótão) — na lateral oeste
	ce:cilindro(CF(X0 - 0.55, H2 + 4.5, -6), 0.3, 3, COR.moldura, M.Wood)
	ce:cilindro(CF(X0 - 0.62, H2 + 4.5, -6), 0.2, 2.4, RGB(10, 10, 14), M.Glass)

	-------------------------------------------------------------------
	-- Porta da frente (aberta), varanda e escada
	local pf = CF(0, F, Z1)
	c:bloco(pf * CF(0, 9.3, 0.62), V3(7.4, 0.6, 0.5), COR.madeiraEscura, M.Wood)
	c:bloco(pf * CF(-3.4, 4.5, 0.62), V3(0.6, 9, 0.5), COR.madeiraEscura, M.Wood)
	c:bloco(pf * CF(3.4, 4.5, 0.62), V3(0.6, 9, 0.5), COR.madeiraEscura, M.Wood)
	for _, s in { -1, 1 } do
		local folha = CF(s * 2.95, F + 4.5, Z1 - 1.9)
		c:bloco(folha, V3(0.3, 9, 3), COR.madeira, M.Wood)
		c:bloco(folha * CF(-s * 0.18, 1.8, 0), V3(0.06, 2.8, 2.2), COR.madeiraEscura, M.Wood)
		c:bloco(folha * CF(-s * 0.18, -1.8, 0), V3(0.06, 2.8, 2.2), COR.madeiraEscura, M.Wood)
	end
	-- varanda
	c:entre(V3(-8, 0, Z1 + 0.5), V3(8, F, 18), COR.madeira, M.WoodPlanks)
	for i = 1, 3 do
		c:entre(V3(-4, 0, 18 + (i - 1) * 1.1), V3(4, F - i * 0.33, 18 + i * 1.1), COR.pedraClara, M.Concrete)
	end
	for _, x in { -7.3, 7.3 } do
		c:coluna(V3(x, F, 17.3), 10.5, 0.9, COR.moldura, M.Wood)
		c:caixa(V3(x, F + 0.3, 17.3), V3(1.3, 0.6, 1.3), COR.moldura, M.Wood)
	end
	c:bloco(CF(0, F + 11.3, 15.3) * CFrame.Angles(math.rad(12), 0, 0), V3(17.5, 0.6, 6.4), COR.telhado, M.Slate)
	c:caixa(V3(0, F + 10.6, 17.4), V3(16.2, 0.5, 0.5), COR.moldura, M.Wood)
	-- grade da varanda
	for _, s in { -1, 1 } do
		c:caixa(V3(s * 5.6, F + 2.6, 17.4), V3(3.2, 0.25, 0.25), COR.moldura, M.Wood)
		for k = 0, 3 do
			c:caixa(V3(s * (4.4 + k * 0.8), F + 1.3, 17.4), V3(0.18, 2.6, 0.18), COR.moldura, M.Wood)
		end
	end
	-- luz da varanda (fraca)
	local lampVar = c:caixa(V3(4.4, F + 8, Z1 + 0.9), V3(0.5, 0.7, 0.5), RGB(255, 196, 120), M.Neon, { Name = "OI3_Chama" })
	c:luz(lampVar, "PointLight", { Range = 14, Brightness = 0.7, Color = RGB(255, 180, 110), Shadows = false })

	-------------------------------------------------------------------
	-- Interior: dormitório
	local camasNorte = { -32, -26, -20 }
	for i, x in camasNorte do
		Moveis.cama(ci, V3(x, F, Z0 + 0.6), V3(0, 0, 1), COR.cobertores[i])
		Moveis.cama(ci, V3(x, F, Z1 - 0.6), V3(0, 0, -1), COR.cobertores[i + 3])
	end
	local topoCriado = Moveis.criado(ci, V3(-23, F, Z0 + 1.6), V3(0, 0, 1))
	refs.velaDorm = Moveis.vela(ci, topoCriado + V3(0, 0, 0.2), { luz = true, alcance = 16, brilho = 0.7, sombras = true })
	Moveis.criado(ci, V3(-29, F, Z0 + 1.6), V3(0, 0, 1))
	Moveis.criado(ci, V3(-29, F, Z1 - 1.6), V3(0, 0, -1))
	Moveis.criado(ci, V3(-23, F, Z1 - 1.6), V3(0, 0, -1))
	Moveis.ursinho(ci, V3(-26.6, F + 2.0, Z0 + 2.4), V3(0, 0, 1))
	-- guarda-roupa na parede oeste
	ci:entre(V3(X0 + 0.6, F, -8.4), V3(X0 + 3.6, F + 9, -3.6), COR.madeira, M.Wood)
	ci:entre(V3(X0 + 3.6, F + 0.4, -8.2), V3(X0 + 3.7, F + 8.6, -6.1), COR.madeiraEscura, M.Wood)
	ci:entre(V3(X0 + 3.6, F + 0.4, -5.9), V3(X0 + 3.7, F + 8.6, -3.8), COR.madeiraEscura, M.Wood)
	ci:entre(V3(X0 + 0.4, F + 9, -8.6), V3(X0 + 3.9, F + 9.4, -3.4), COR.madeiraEscura, M.Wood)
	-- baú de brinquedos
	ci:entre(V3(-17.4, F, -6.5), V3(-14.6, F + 2, -3.5), COR.madeiraClara, M.Wood)
	ci:entre(V3(-17.5, F + 2, -6.6), V3(-14.5, F + 2.25, -3.4), COR.madeiraEscura, M.Wood)
	-- tapete do corredor central
	ci:entre(V3(-33, F, -15), V3(-15, F + 0.06, 3), RGB(70, 40, 40), M.Fabric)
	-- quadros
	Moveis.quadro(ci, V3(XDH - 0.5, F + 7.5, -14), V3(-1, 0, 0), 3, 2.2, RGB(70, 76, 64))
	Moveis.quadro(ci, V3(XDH - 0.5, F + 7.5, 7), V3(-1, 0, 0), 2.2, 2.8, RGB(80, 64, 54))

	-------------------------------------------------------------------
	-- Interior: hall
	-- escada até um patamar com porta fechada
	local degraus = 8
	for i = 1, degraus do
		local zIni = -7 - (i - 1) * 1.6
		ci:entre(V3(-4, F, zIni - 1.6), V3(4, F + i * 0.75, zIni), COR.madeira, M.WoodPlanks)
	end
	ci:entre(V3(-4, F, Z0 + 0.6), V3(4, F + degraus * 0.75, -7 - degraus * 1.6), COR.madeira, M.WoodPlanks)
	for _, s in { -1, 1 } do
		for i = 0, degraus do
			local z = -7 - i * 1.6
			local yb = F + math.max(i, 1) * 0.75
			ci:coluna(V3(s * 4.2, yb, z - 0.8), 3, 0.25, COR.madeiraEscura, M.Wood)
		end
		local a = V3(s * 4.2, F + 0.75 + 3, -7.8)
		local b = V3(s * 4.2, F + degraus * 0.75 + 3, -7 - degraus * 1.6 - 0.8)
		ci:bloco(CFrame.lookAt((a + b) / 2, b), V3(0.4, 0.3, (b - a).Magnitude + 0.4), COR.madeira, M.Wood)
	end
	Moveis.portaFechada(ci, V3(0, F + degraus * 0.75, Z0 + 0.62), V3(0, 0, 1))
	-- relógio de pêndulo
	local rel = CF(XDH + 1.6, F, -12)
	ci:bloco(rel * CF(0, 4.5, 0), V3(1.6, 9, 2.2), COR.madeiraEscura, M.Wood)
	ci:bloco(rel * CF(0.82, 7.4, 0), V3(0.05, 1.6, 1.6), RGB(206, 196, 170), M.SmoothPlastic, { Name = "MostradorRelogio" })
	ci:bloco(rel * CF(0.82, 3.6, 0), V3(0.05, 4, 1.2), RGB(20, 16, 14), M.Glass, { Transparency = 0.3 })
	ci:bloco(rel * CF(0, 9.2, 0), V3(1.9, 0.4, 2.5), COR.madeira, M.Wood)
	refs.pendulo = ci:bloco(rel * CF(0.7, 3.4, 0), V3(0.1, 2.6, 0.2), COR.ouro, M.Metal, { Name = "Pendulo" })
	-- lustre
	Moveis.lustre(ci, V3(0, TETO - 2.9, 2), 1.7, 0.32)
	-- tapete e mesa lateral
	ci:entre(V3(-4.5, F, -5), V3(4.5, F + 0.06, 9.5), RGB(62, 46, 60), M.Fabric)
	ci:entre(V3(8.2, F, 6), V3(10.6, F + 2.6, 8.2), COR.madeira, M.Wood)
	ci:bola(V3(9.4, F + 3.2, 7.1), 1, RGB(84, 92, 100), M.SmoothPlastic)
	-- cabideiro
	ci:coluna(V3(-9.5, F, 9.5), 6, 0.3, COR.madeiraEscura, M.Wood)
	ci:caixa(V3(-9.5, F + 5.6, 9.5), V3(1.4, 0.2, 0.2), COR.madeiraEscura, M.Wood)
	ci:caixa(V3(-9.5, F + 4.2, 9.5), V3(0.9, 1.8, 0.6), RGB(46, 42, 52), M.Fabric)
	Moveis.quadro(ci, V3(XHL - 0.5, F + 7.6, -14), V3(-1, 0, 0), 2.6, 3.4, RGB(60, 52, 46))

	-------------------------------------------------------------------
	-- Interior: corredor
	ci:entre(V3(XHL + 1, F, -1.6), V3(XQE - 0.8, F + 0.06, 1.6), RGB(78, 30, 30), M.Fabric)
	for _, x in { 18, 40 } do
		Moveis.portaFechada(ci, V3(x, F, ZC - 0.62), V3(0, 0, -1))
	end
	for _, x in { 29, 49 } do
		Moveis.portaFechada(ci, V3(x, F, -ZC + 0.62), V3(0, 0, 1))
	end
	refs.arandela1 = Moveis.arandela(ci, V3(24, F + 7, ZC - 0.62), V3(0, 0, -1), 0.5)
	refs.arandela2 = Moveis.arandela(ci, V3(44, F + 7, -ZC + 0.62), V3(0, 0, 1), 0.45)
	Moveis.quadro(ci, V3(34, F + 7.4, ZC - 0.62), V3(0, 0, -1), 2.4, 3, RGB(52, 48, 58))
	Moveis.quadro(ci, V3(37, F + 7.2, -ZC + 0.62), V3(0, 0, 1), 3.2, 2.2, RGB(66, 58, 44))

	-------------------------------------------------------------------
	-- Exterior: grade, portão, árvores, poste, cerca viva
	local zG = 64
	local function grade(xa: number, xb: number)
		local n = math.floor((xb - xa) / 2.4)
		for i = 0, n do
			local x = xa + i * (xb - xa) / n
			ce:caixa(V3(x, 3, zG), V3(0.22, 6, 0.22), COR.ferro, M.Metal, { colisao = true })
			ce:caixa(V3(x, 6.25, zG), V3(0.36, 0.5, 0.36), COR.ferro, M.Metal)
		end
		ce:entre(V3(xa, 5.2, zG - 0.12), V3(xb, 5.45, zG + 0.12), COR.ferro, M.Metal, { colisao = true })
		ce:entre(V3(xa, 0.8, zG - 0.12), V3(xb, 1.05, zG + 0.12), COR.ferro, M.Metal, { colisao = true })
	end
	grade(-70, -5.4)
	grade(5.4, 100)
	for _, x in { -4.8, 4.8 } do
		ce:caixa(V3(x, 4, zG), V3(1.6, 8, 1.6), COR.pedra, M.Slate)
		ce:caixa(V3(x, 8.25, zG), V3(2, 0.5, 2), COR.pedraClara, M.Concrete)
		ce:bola(V3(x, 9, zG), 1.1, COR.pedraClara, M.Concrete)
	end
	-- portão aberto
	for _, s in { -1, 1 } do
		local base = V3(s * 4, 0, zG)
		for k = 0, 4 do
			ce:caixa(base + V3(0, 3.2, 0) + V3(-s * 0.15, 0, -0.7 - k * 0.8), V3(0.18, 6.2, 0.18), COR.ferro, M.Metal)
		end
		ce:caixa(base + V3(-s * 0.15, 5.8, -2.3), V3(0.18, 0.25, 3.4), COR.ferro, M.Metal)
		ce:caixa(base + V3(-s * 0.15, 1, -2.3), V3(0.18, 0.25, 3.4), COR.ferro, M.Metal)
	end
	-- poste de luz (pisca)
	ce:coluna(V3(7.4, 0, zG + 2.2), 9, 0.45, COR.ferro, M.Metal)
	ce:caixa(V3(7.4, 9.4, zG + 2.2), V3(1.1, 0.25, 1.1), COR.ferro, M.Metal)
	local lampada = ce:caixa(V3(7.4, 8.8, zG + 2.2), V3(0.7, 0.9, 0.7), RGB(255, 210, 150), M.Neon, { Name = "OI3_Lampada" })
	ce:luz(lampada, "PointLight", { Range = 22, Brightness = 1.1, Color = RGB(255, 206, 150), Shadows = false })
	refs.lampada = lampada
	-- cercas vivas (limites)
	local folhas = RGB(30, 40, 30)
	ce:entre(V3(-74, 0, -52), V3(-70, 8, zG), folhas, M.LeafyGrass)
	ce:entre(V3(100, 0, -52), V3(104, 8, zG), folhas, M.LeafyGrass)
	ce:entre(V3(-74, 0, -56), V3(104, 8, -52), folhas, M.LeafyGrass)
	-- paredes invisíveis (impedem sair do terreno)
	local inv = { Transparency = 1, colisao = true, CanQuery = false, CastShadow = false, Name = "Limite" }
	ce:entre(V3(-70, 0, -52), V3(-69, 40, 72), RGB(0, 0, 0), M.SmoothPlastic, inv)
	ce:entre(V3(99, 0, -52), V3(100, 40, 72), RGB(0, 0, 0), M.SmoothPlastic, inv)
	ce:entre(V3(-70, 0, 71), V3(100, 40, 72), RGB(0, 0, 0), M.SmoothPlastic, inv)
	ce:entre(V3(-70, 0, -53), V3(100, 40, -52), RGB(0, 0, 0), M.SmoothPlastic, inv)
	ce:entre(V3(-70, 39, -53), V3(100, 40, 72), RGB(0, 0, 0), M.SmoothPlastic, inv)
	-- árvores secas
	local function arvore(base: Vector3, altura: number, semente: number)
		local tronco = RGB(48, 40, 36)
		ce:coluna(base, altura, 1.6, tronco, M.Wood, { colisao = true })
		local rnd = Random.new(semente)
		for i = 1, 5 do
			local h = altura * (0.45 + i * 0.1)
			local ang = rnd:NextNumber(0, math.pi * 2)
			local inc = rnd:NextNumber(0.5, 0.9)
			local comp = rnd:NextNumber(3.5, 6.5) * (1.1 - i * 0.1)
			local dir = V3(math.cos(ang) * math.sin(inc), math.cos(inc), math.sin(ang) * math.sin(inc))
			local ini = base + V3(0, h, 0)
			local fim = ini + dir * comp
			ce:bloco(CFrame.lookAt((ini + fim) / 2, fim), V3(0.5, 0.5, comp), tronco, M.Wood)
			local ang2 = ang + rnd:NextNumber(-1, 1)
			local dir2 = V3(math.cos(ang2) * 0.7, 0.7, math.sin(ang2) * 0.7).Unit
			local fim2 = fim + dir2 * comp * 0.5
			ce:bloco(CFrame.lookAt((fim + fim2) / 2, fim2), V3(0.3, 0.3, comp * 0.5), tronco, M.Wood)
		end
	end
	arvore(V3(-40, 0, 40), 18, 11)
	arvore(V3(34, 0, 46), 15, 23)
	arvore(V3(-58, 0, -12), 20, 37)
	arvore(V3(88, 0, 30), 16, 41)
	arvore(V3(-24, 0, 56), 12, 53)
	-- arbustos na frente da casa
	for _, x in { -32, -25, -14, 14, 25, 32 } do
		ce:bola(V3(x, 1.2, Z1 + 2.2), 3.2, RGB(34, 46, 34), M.LeafyGrass)
	end
	-- balanço velho (lado leste do pátio)
	local bx, bz = 48, 36
	for _, s in { -1, 1 } do
		local topo = V3(bx + s * 4, 9, bz)
		for _, t in { -1, 1 } do
			local pe = V3(bx + s * 4, 0, bz + t * 2.6)
			ce:bloco(CFrame.lookAt((pe + topo) / 2, topo), V3(0.4, 0.4, (topo - pe).Magnitude), COR.ferro, M.Metal)
		end
	end
	ce:cilindro(CF(bx, 9, bz), 8.4, 0.4, COR.ferro, M.Metal)
	for _, s in { -1.6, 1.6 } do
		for _, t in { -0.7, 0.7 } do
			ce:caixa(V3(bx + s + t, 5.3, bz), V3(0.08, 7.4, 0.08), RGB(70, 66, 60), M.Metal)
		end
		ce:caixa(V3(bx + s, 1.55, bz), V3(1.8, 0.18, 0.8), COR.madeira, M.Wood)
	end

	modelo.Parent = pai
	return modelo, refs
end

-- Terreno (grama, caminho de terra). Separado porque só funciona dentro do Roblox.
function Mapa.construirTerreno(terreno: Terrain)
	terreno:FillBlock(CF(15, -4, 10), V3(260, 8, 260), Enum.Material.Grass)
	terreno:FillBlock(CF(0, -1.9, 42), V3(8, 4, 48), Enum.Material.Mud)
	terreno:FillBlock(CF(0, -1.9, 70), V3(8, 4, 14), Enum.Material.Mud)
	pcall(function()
		terreno:SetMaterialColor(Enum.Material.Grass, RGB(52, 62, 44))
		terreno:SetMaterialColor(Enum.Material.Mud, RGB(58, 46, 38))
		terreno.Decoration = false
	end)
end

return Mapa
