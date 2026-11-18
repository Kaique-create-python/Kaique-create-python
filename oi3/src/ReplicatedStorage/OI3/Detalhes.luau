-- OI3 :: detalhes extras do orfanato (AJUSTE-3): vigas, cortinas, lareira, estantes,
-- brinquedos, desenhos, teias, raios de luar, poeira, névoa, postigos, mata ao longe...
-- Tudo longe dos caminhos dos personagens da abertura.

local Construtor = require(script.Parent.Construtor)
local Moveis = require(script.Parent.Moveis)

local Detalhes = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local M = Enum.Material
local COR = Moveis.COR

function Detalhes.construir(pai: Instance, L: { [string]: number })
	local F, TETO = L.F, L.TETO
	local pasta = Instance.new("Folder")
	pasta.Name = "Detalhes"
	pasta.Parent = pai
	local c = Construtor.novo(pasta)

	-------------------------------------------------------------------
	-- Dormitório (x -36..-12, z -24..12)
	for _, x in { -30, -24, -18 } do
		c:entre(V3(x - 0.4, TETO - 0.75, -23.5), V3(x + 0.4, TETO, 11.5), COR.madeiraEscura, M.Wood)
	end
	-- cortinas nas janelas (acima das cabeceiras)
	local function cortinas(centro: Vector3, d: Vector3, dentro: Vector3)
		for _, s in { -1, 1 } do
			c:bloco(CFrame.fromMatrix(centro + d * (s * 2.35) + dentro * 0.25 + V3(0, 0.2, 0), d, Vector3.yAxis), V3(1.1, 7.1, 0.14), COR.tecidoVermelho, M.Fabric)
		end
		c:bloco(CFrame.fromMatrix(centro + dentro * 0.32 + V3(0, 3.85, 0), d, Vector3.yAxis), V3(6.2, 0.16, 0.16), COR.ouroEscuro, M.Metal)
	end
	for _, z in { -12, 0 } do
		cortinas(V3(-35.4, F + 7.2, z), V3(0, 0, 1), V3(1, 0, 0))
	end
	for _, x in { -30, -20 } do
		cortinas(V3(x, F + 7.2, 11.4), V3(1, 0, 0), V3(0, 0, -1))
		cortinas(V3(x, F + 7.2, -23.4), V3(1, 0, 0), V3(0, 0, 1))
	end
	-- arandelas dos lados da porta
	Moveis.arandela(c, V3(-12.62, F + 6.8, -6), V3(-1, 0, 0), 0.45)
	Moveis.arandela(c, V3(-12.62, F + 6.8, 4.2), V3(-1, 0, 0), 0.45)
	-- desenhos das crianças
	Moveis.desenho(c, V3(-12.55, F + 5.2, -10), V3(-1, 0, 0), 1)
	Moveis.desenho(c, V3(-12.55, F + 5.4, 9.4), V3(-1, 0, 0), 2)
	Moveis.desenho(c, V3(-25, F + 6.2, -23.42), V3(0, 0, 1), 3)
	-- brinquedos
	Moveis.blocos(c, V3(-18.6, F, -8.2), 5)
	Moveis.boneca(c, V3(-20.2, F + 1.95, -21.8), V3(0, 0, 1))
	-- luar entrando pelas janelas do oeste
	Moveis.luar(c, V3(-35.2, F + 8.5, 0), V3(-28.5, F, 2.2), true)
	Moveis.luar(c, V3(-35.2, F + 8.5, -12), V3(-28.5, F, -10), false)
	Moveis.poeira(c, V3(-35, F + 0.5, -23), V3(-13, TETO - 1, 11), 10)
	Moveis.teia(c, V3(-35.4, TETO - 0.05, -23.4), V3(1, 0, 0), V3(0, 0, 1), 2.2)
	Moveis.teia(c, V3(-12.6, TETO - 0.05, 11.4), V3(-1, 0, 0), V3(0, 0, -1), 1.8)

	-------------------------------------------------------------------
	-- Hall (x -12..12)
	for _, z in { -18, -10, -2, 6 } do
		c:entre(V3(-11.5, TETO - 0.75, z - 0.4), V3(11.5, TETO, z + 0.4), COR.madeiraEscura, M.Wood)
	end
	local topoLareira = Moveis.lareira(c, V3(-11.45, F, 6.0), V3(1, 0, 0), TETO - F)
	Moveis.vela(c, topoLareira + V3(0, 0, -2.4), { altura = 0.7, luz = true, alcance = 10, brilho = 0.45 })
	Moveis.vela(c, topoLareira + V3(0, 0, 2.2), { altura = 0.45 })
	c:bloco(CF(topoLareira + V3(0.1, 0.45, 0.2)), V3(0.5, 0.9, 1.1), COR.madeiraEscura, M.Wood) -- reloginho
	Moveis.quadro(c, V3(-10.32, F + 8.8, 6.0), V3(1, 0, 0), 2.6, 3.0, RGB(54, 46, 40))
	Moveis.estante(c, V3(11.45, F, -19.5), V3(-1, 0, 0), 5, 8.5, 11)
	Moveis.banco(c, V3(-11.2, F, -6), V3(1, 0, 0))
	-- porta-guarda-chuva
	c:coluna(V3(6.4, F, 10.6), 1.8, 0.9, RGB(60, 52, 44), M.Metal)
	c:bloco(CF(6.3, F + 2.1, 10.6) * CFrame.Angles(0, 0, 0.12), V3(0.12, 2.8, 0.12), RGB(28, 28, 32), M.SmoothPlastic)
	c:bloco(CF(6.55, F + 2.0, 10.5) * CFrame.Angles(0.1, 0, -0.1), V3(0.12, 2.6, 0.12), RGB(90, 30, 30), M.SmoothPlastic)
	-- luar pelas janelas da frente do hall
	Moveis.luar(c, V3(-8, F + 8.6, 11.3), V3(-6, F, 5.5), false)
	Moveis.luar(c, V3(8, F + 8.6, 11.3), V3(6, F, 5.5), false)
	Moveis.poeira(c, V3(-11, F + 0.5, -23), V3(11, TETO - 1, 11), 9)
	Moveis.teia(c, V3(11.4, TETO - 0.05, -23.4), V3(-1, 0, 0), V3(0, 0, 1), 2.4)

	-------------------------------------------------------------------
	-- Corredor (x 12..56, z -4..4)
	for _, x in { 20, 30, 40, 50 } do
		c:entre(V3(x - 0.35, TETO - 0.6, -3.5), V3(x + 0.35, TETO, 3.5), COR.madeiraEscura, M.Wood)
	end
	Moveis.arandela(c, V3(33, F + 7, -3.38), V3(0, 0, 1), 0.4)
	Moveis.arandela(c, V3(52, F + 7, 3.38), V3(0, 0, -1), 0.4)
	-- aparador com vaso, encostado na parede (longe do caminho)
	c:entre(V3(20.5, F, -3.5), V3(22.5, F + 2.6, -2.4), COR.madeira, M.Wood)
	c:entre(V3(20.4, F + 2.6, -3.55), V3(22.6, F + 2.75, -2.3), COR.madeiraEscura, M.Wood)
	c:coluna(V3(21.5, F + 2.75, -2.95), 1.1, 0.6, RGB(70, 84, 96), M.SmoothPlastic)
	for i = 1, 3 do
		c:bloco(CF(21.5 + (i - 2) * 0.12, F + 4.1, -2.95) * CFrame.Angles(0, 0, (i - 2) * 0.35), V3(0.05, 1.4, 0.05), RGB(70, 54, 40), M.Wood)
	end
	Moveis.poeira(c, V3(13, F + 0.5, -3.2), V3(55, TETO - 1, 3.2), 7)
	Moveis.teia(c, V3(55.4, TETO - 0.05, 3.4), V3(-1, 0, 0), V3(0, 0, -1), 1.6)
	Moveis.teia(c, V3(12.6, TETO - 0.05, -3.4), V3(1, 0, 0), V3(0, 0, 1), 1.6)

	-------------------------------------------------------------------
	-- Exterior
	local ce = Construtor.novo(pasta)
	-- postigos nas janelas da frente
	for _, x in { -30, -20, -8, 8, 20, 30 } do
		Moveis.postigos(ce, V3(x, F + 7, 12), V3(1, 0, 0), V3(0, 0, 1), 3.6, 6.8)
		Moveis.postigos(ce, V3(x, 20.3, 12), V3(1, 0, 0), V3(0, 0, 1), 3.4, 6.6)
	end
	-- calha e canos
	ce:cilindro(CF(0, 26.7, 13.9), 75, 0.45, RGB(40, 42, 46), M.Metal)
	for _, x in { -37, 37 } do
		ce:coluna(V3(x, 0, 13.6), 26.8, 0.32, RGB(40, 42, 46), M.Metal)
	end
	-- pedras do caminho
	local rnd = Random.new(99)
	local z = 22
	local lado = 1
	while z < 62 do
		ce:bloco(CF(lado * rnd:NextNumber(0.4, 1.3), 0.05, z) * CFrame.Angles(0, rnd:NextNumber(-0.5, 0.5), 0), V3(rnd:NextNumber(1.3, 1.9), 0.18, rnd:NextNumber(1.0, 1.4)), RGB(96, 94, 92), M.Slate)
		z += rnd:NextNumber(1.5, 2.0)
		lado = -lado
	end
	-- postes no caminho (com mariposas)
	for _, p in { V3(-4.4, 0, 33), V3(4.4, 0, 48) } do
		ce:coluna(p, 8.5, 0.4, COR.ferro, M.Metal)
		ce:caixa(p + V3(0, 8.9, 0), V3(1, 0.22, 1), COR.ferro, M.Metal)
		local lamp = ce:caixa(p + V3(0, 8.35, 0), V3(0.6, 0.8, 0.6), RGB(255, 210, 150), M.Neon, { Name = "OI3_Lampada" })
		ce:luz(lamp, "PointLight", { Range = 18, Brightness = 0.9, Color = RGB(255, 204, 148), Shadows = true })
		Moveis.mariposas(ce, p + V3(0, 8.3, 0))
	end
	Moveis.mariposas(ce, V3(7.4, 8.8, 66.2))
	Moveis.poco(ce, V3(-34, 0, 30))
	Moveis.banco(ce, V3(22, 0, 30), V3(-1, 0, 0))
	-- névoa rasteira
	Moveis.nevoa(ce, V3(0, 1, 40), V3(130, 1, 46), 2.2)
	Moveis.nevoa(ce, V3(-52, 1, -8), V3(30, 1, 80), 1.2)
	Moveis.nevoa(ce, V3(84, 1, 24), V3(28, 1, 80), 1.2)
	-- mata escura ao longe (silhuetas)
	local r2 = Random.new(7)
	local function linha(a: Vector3, b: Vector3, passo: number)
		local n = math.floor((b - a).Magnitude / passo)
		for i = 0, n do
			local p = a:Lerp(b, i / math.max(n, 1)) + V3(r2:NextNumber(-3, 3), 0, r2:NextNumber(-3, 3))
			Moveis.pinheiro(ce, p, r2:NextNumber(24, 38), r2:NextNumber(4, 6.5))
		end
	end
	linha(V3(-86, 0, -66), V3(-86, 0, 70), 11)
	linha(V3(116, 0, -66), V3(116, 0, 70), 11)
	linha(V3(-80, 0, -70), V3(110, 0, -70), 12)
	-- na frente fica bem longe (atrás da câmera da abertura) e com uma abertura no meio
	linha(V3(-90, 0, 118), V3(-34, 0, 118), 12)
	linha(V3(34, 0, 118), V3(116, 0, 118), 12)

	return pasta
end

-- Detalhes do quarto do espelho (entram também no reflexo)
function Detalhes.quartoEspelho(c, F: number, TETO: number, reflexo: boolean?)
	-- baú velho no canto perto da porta
	c:entre(V3(56.8, F, -7.9), V3(59.4, F + 1.8, -6.1), RGB(70, 50, 36), M.Wood)
	c:entre(V3(56.7, F + 1.8, -8.0), V3(59.5, F + 2.1, -6.0), RGB(54, 38, 28), M.Wood)
	c:entre(V3(57.9, F + 1.2, -6.05), V3(58.3, F + 1.6, -5.98), COR.ouro, M.Metal)
	-- pilha de livros e vela no chão perto da cadeira
	for i = 0, 2 do
		c:bloco(CF(60.6, F + 0.13 + i * 0.26, 7.35) * CFrame.Angles(0, i * 0.3, 0), V3(1.1, 0.24, 0.8), ({ RGB(80, 34, 30), RGB(44, 56, 70), RGB(100, 84, 56) })[i + 1], M.Fabric)
	end
	Moveis.vela(c, V3(61.8, F, 7.3), { altura = 0.5, luz = true, alcance = 9, brilho = 0.4 })
	if not reflexo then
		Moveis.teia(c, V3(56.6, TETO - 0.05, -8.0), V3(1, 0, 0), V3(0, 0, 1), 1.8)
		Moveis.poeira(c, V3(56.6, F + 0.5, -7.8), V3(68.5, TETO - 1, 7.8), 6)
	end
end

return Detalhes
