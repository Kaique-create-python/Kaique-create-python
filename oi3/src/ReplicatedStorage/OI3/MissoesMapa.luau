-- OI3 :: cenários do resto do Capítulo 1 (AJUSTE-8)
-- "Quando voltam, a porta do quarto está aberta, mas o corredor não parece mais o mesmo."
-- Depois do ritual, cada missão acontece num cenário próprio (uma parte do orfanato que a brincadeira
-- "abriu"). Os cenários ficam longe da casa e são montados NO APARELHO de cada jogador quando a missão
-- começa (e desmontados depois): pesa menos e todos do grupo veem a mesma coisa, porque a montagem é
-- sempre igual. O servidor só precisa das POSIÇÕES (layout), que saem daqui sem montar nada.

local Construtor = require(script.Parent.Construtor)
local Moveis = require(script.Parent.Moveis)

local MissoesMapa = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local M = Enum.Material
local COR = Moveis.COR
local F = 1 -- altura do piso (igual à casa)

MissoesMapa.ORIGEM = {
	quarto = V3(520, 0, 0),
	festa = V3(640, 0, 0),
	lavanderia = V3(760, 0, 0),
	espelhos = V3(890, 0, 0),
	quarto_trancado = V3(1030, 0, 0),
	escritorio = V3(1150, 0, 0),
	cadeiras = V3(1270, 0, 0),
	porao = V3(1400, 0, 0),
	rua = V3(1580, 0, 0),
}

local function L(O: Vector3, x: number, y: number, z: number): Vector3
	return V3(O.X + x, F + y, O.Z + z)
end

---------------------------------------------------------------------------
-- LAYOUT (só posições; o servidor e o cliente usam)
---------------------------------------------------------------------------
local LAYOUT: { [string]: (Vector3) -> any } = {}

LAYOUT.quarto = function(O)
	local camas = { -11, -4, 3, 10 }
	local esc = {}
	for i = 1, 3 do
		local x = camas[i]
		table.insert(esc, {
			id = "cama" .. i,
			tipo = "cama",
			pos = L(O, x, 0, -6.5),
			checar = L(O, x + 2.6, 0, -4.2),
			cam = CFrame.lookAt(L(O, x, 0.55, -6.2), L(O, x, 0.6, 2)),
		})
	end
	for i, x in { -8, 6 } do
		table.insert(esc, {
			id = "armario" .. i,
			tipo = "armario",
			pos = L(O, x, 0, 10.4),
			checar = L(O, x, 0, 6.8),
			cam = CFrame.lookAt(L(O, x, 4.6, 10.2), L(O, x, 4.0, 0)),
		})
	end
	table.insert(esc, {
		id = "bau",
		tipo = "bau",
		pos = L(O, -15, 0, 9.2),
		checar = L(O, -11.6, 0, 7.6),
		cam = CFrame.lookAt(L(O, -15.2, 1.7, 9.6), L(O, -6, 1.8, 2)),
	})
	return {
		spawn = L(O, 2, 0, 3),
		olhar = L(O, 2, 0, -8),
		pontos = {
			cama_ultima = L(O, 10, 0.8, -5.4),
			porta_saida = L(O, 16.2, 3, 0),
		},
		esconderijos = esc,
		-- a sombra entra pela porta escura do lado oeste, passa pelo quarto e volta
		entrada = L(O, -20.5, 0, -5),
		rota = { L(O, -20.5, 0, -5), L(O, -14, 0, -2), L(O, -6, 0, 0.5), L(O, 2, 0, 1.5), L(O, 9, 0, 1), L(O, 2, 0, 4), L(O, -6, 0, 4), L(O, -14, 0, -2), L(O, -20.5, 0, -5) },
		barulho = L(O, -13, 0, 8), -- para onde a sombra vai quando o Keko joga um brinquedo
	}
end

LAYOUT.festa = function(O)
	return {
		spawn = L(O, -11, 0, 0),
		olhar = L(O, 4, 0, 0),
		pontos = {
			bal_azul = L(O, -12.5, 2.5, -8.6),
			bal_vermelho = L(O, 12.6, 2.5, 8.5),
			bal_amarelo = L(O, 11.5, 2.5, -8.8),
			agulha = L(O, -4, 2.2, 9.6),
			toca_discos = L(O, 8.4, 3.4, -9.3),
			prato1 = L(O, -2.4, 3.1, -1.25),
			prato2 = L(O, 2.4, 3.1, -1.25),
			prato3 = L(O, -2.4, 3.1, 1.25),
			prato4 = L(O, 2.4, 3.1, 1.25),
			vela_a = L(O, -13.6, 1, 4.2),
			vela_b = L(O, 6.5, 0.4, 9.3),
			vela_c = L(O, 13.3, 1.2, -2),
			vela_d = L(O, -6.2, 3.6, -9.6),
			bolo_vermelha = L(O, -0.35, 4.2, -0.3),
			bolo_azul = L(O, 0.35, 4.2, -0.3),
			bolo_amarela = L(O, -0.35, 4.2, 0.3),
			bolo_verde = L(O, 0.35, 4.2, 0.3),
			teclado_lavanderia = L(O, 14.6, 4, 3.6),
		},
	}
end

LAYOUT.lavanderia = function(O)
	return {
		spawn = L(O, -10, 0, 4),
		olhar = L(O, 4, 0, -2),
		pontos = {
			registro = L(O, -11.6, 3.5, -8.4),
			maquina1 = L(O, -7.5, 3, -6.3),
			maquina2 = L(O, -2.5, 3, -6.3),
			maquina3 = L(O, 2.5, 3, -6.3),
			maquina4 = L(O, 7.5, 3, -6.3),
			valvula = L(O, 11, 1.6, -1.2),
			chave = L(O, 6, 0.6, 7.6),
			porta_servico = L(O, 12.6, 3.2, 5),
		},
		maquinas = { L(O, -7.5, 0, -7.6), L(O, -2.5, 0, -7.6), L(O, 2.5, 0, -7.6), L(O, 7.5, 0, -7.6) },
	}
end

LAYOUT.espelhos = function(O)
	-- corredor de -28 a +12 (x), z de -4 a 4; espelhos na parede norte (z = -4)
	-- quarto B (do último espelho): atrás da parede sul, de x -2 a 10, z de 4 a 16
	return {
		spawn = L(O, -25, 0, 0),
		olhar = L(O, 0, 0, 0),
		espelhos = { -22, -13, -4, 5 }, -- x de cada espelho (o 4º revela a passagem)
		pontos = {
			parede1 = L(O, -24, 3, 3.3),
			parede2 = L(O, -16, 3, 3.3),
			parede4 = L(O, -8, 3, 3.3),
			parede5 = L(O, -0.5, 3, 3.3),
			parede_certa = L(O, 4, 3, 3.3),
			parede6 = L(O, 10, 3, 3.3),
			ultimo_espelho = L(O, 4, 3.5, 12.6),
			porta_quarto = L(O, 9.2, 3.2, 10),
		},
		passagem = L(O, 4, 0, 4),
		quartoB = L(O, 4, 0, 10),
	}
end

LAYOUT.quarto_trancado = function(O)
	return {
		spawn = L(O, -7, 0, 4),
		olhar = L(O, 4, 0, -6),
		pontos = {
			bater1 = L(O, -11.3, 3.2, -2),
			bater2 = L(O, -6, 3.2, -8.3),
			bater3 = L(O, 11.3, 3.2, 3),
			bater4 = L(O, 0, 3.2, 8.3),
			parede_oca = L(O, 2.4, 3.2, -8.3),
			armario = L(O, 6.4, 3.4, -7),
			papel = L(O, 6.4, 3.4, -8.2),
			mecanismo = L(O, 6.4, 2.2, -8.2),
			passagem = L(O, 6.4, 1.4, -8.2),
			saida = L(O, 6.4, 1.2, -17.6),
		},
		esconderijo = L(O, 6.4, 0, -13), -- o espaço pequeno atrás da parede
		desenhoMuda = L(O, 3.45, 2.6, -14),
	}
end

LAYOUT.escritorio = function(O)
	return {
		spawn = L(O, -9, 0, 5),
		olhar = L(O, 6, 0, 0),
		pontos = {
			gaveta = L(O, -9.5, 2.4, -5.4),
			cabo1 = L(O, -2.4, 3.6, 9.1),
			cabo2 = L(O, -0.8, 3.6, 9.1),
			cabo3 = L(O, 0.8, 3.6, 9.1),
			chave_geral = L(O, 2.6, 4.2, 9.1),
			fita1987 = L(O, 3.2, 5.6, -9.1),
			fita1991 = L(O, -1, 3.8, -9.1),
			fita1994 = L(O, 6.8, 2.2, -9.1),
			lente = L(O, 1.8, 3.6, 0),
			escada = L(O, -5.5, 3.2, -9.2),
		},
		tela = L(O, 12.6, 5.5, 0),
	}
end

LAYOUT.cadeiras = function(O)
	return {
		spawn = L(O, 0, 0, 7),
		olhar = L(O, 0, 0, -8),
		cadeiras = { ke = L(O, -4, 0, 1.5), ni = L(O, 0, 0, 1.5), me = L(O, 4, 0, 1.5) },
		quarta = L(O, 9, 0, 7.5), -- a quarta cadeira aparece no canto, atrás de quem está sentado
		pontos = {
			cadeira_ke = L(O, -4, 2.4, 1.5),
			cadeira_ni = L(O, 0, 2.4, 1.5),
			cadeira_me = L(O, 4, 2.4, 1.5),
			porta_porao = L(O, 0, 3.4, -8.3),
		},
	}
end

LAYOUT.porao = function(O)
	-- corredor estreito de x -26 a +24 (z de -2 a 2); salas ao norte: A (x -14), B (x 0), C (x +14)
	return {
		spawn = L(O, 21, 0, 0),
		olhar = L(O, 0, 0, 0),
		pontos = {
			peca_gaveta = L(O, -16.5, 2.4, -9),
			peca_quadro = L(O, -11, 4, -11.3),
			peca_caixa = L(O, 2.5, 1.5, -9.5),
			simbolo_circulo = L(O, 11.6, 4.6, -2.3),
			simbolo_olho = L(O, 13, 4.6, -2.3),
			simbolo_espiral = L(O, 14.4, 4.6, -2.3),
			simbolo_tres = L(O, 15.8, 4.6, -2.3),
			mecanismo = L(O, 17, 3, -2.3),
			documentos = L(O, 10.5, 3.2, -9),
			foto_apagada = L(O, 18.4, 4, -11.6),
			gravador = L(O, 18, 3.2, -6.4),
			lugar_carrinho = L(O, 12.8, 3.2, -10.6),
			lugar_boneca = L(O, 14, 3.2, -10.6),
			lugar_ursinho = L(O, 15.2, 3.2, -10.6),
		},
		-- a presença corre pelo corredor (de oeste para leste)
		inicioPresenca = L(O, -25, 0, 0),
		corredor = { L(O, -25, 0, 0), L(O, -14, 0, 0), L(O, 0, 0, 0), L(O, 14, 0, 0), L(O, 23, 0, 0) },
		saida = L(O, 24, 0, 0),
		retorno = L(O, 20, 0, 0), -- onde volta quem é pego
		espelho = L(O, 14, 4.5, -12.5),
	}
end

LAYOUT.rua = function(O)
	return {
		carro = L(O, 6, 0, 3),
		vo = L(O, 1, 0.3, -3),
		mulher = L(O, -2.2, 0.3, -3.4),
		filho1 = L(O, -3.4, 0.3, -2.2),
		filho2 = L(O, -1.4, 0.3, -1.9),
		escondidos = { L(O, -16, 0, -9), L(O, -14.5, 0, -9.6), L(O, -13, 0, -9) },
	}
end

function MissoesMapa.layout(nome: string): any
	local f = LAYOUT[nome]
	assert(f, "cenário desconhecido: " .. tostring(nome))
	local l = f(MissoesMapa.ORIGEM[nome])
	l.origem = MissoesMapa.ORIGEM[nome]
	l.nome = nome
	return l
end

---------------------------------------------------------------------------
-- MONTAGEM (só no aparelho do jogador)
---------------------------------------------------------------------------

-- sala fechada: piso de tábuas, teto, paredes com aberturas (portas)
-- portas = { { lado = "N"/"S"/"O"/"L", centro = distância a partir do canto oeste/norte, largura, altura } }
local function sala(c, O: Vector3, w: number, d: number, h: number, opts: any?)
	local o = opts or {}
	local x0, x1, z0, z1 = O.X - w / 2, O.X + w / 2, O.Z - d / 2, O.Z + d / 2
	c:laje(x0 - 0.6, z0 - 0.6, x1 + 0.6, z1 + 0.6, F - 0.05, 0.6, RGB(14, 9, 7), M.SmoothPlastic)
	if o.piso == "pedra" then
		c:laje(x0, z0, x1, z1, F, 0.06, RGB(66, 64, 62), M.Slate)
	else
		Moveis.assoalho(c, x0, z0, x1, z1, F, o.corPiso or COR.assoalho)
	end
	c:laje(x0 - 0.6, z0 - 0.6, x1 + 0.6, z1 + 0.6, F + h + 0.5, 0.5, o.corTeto or COR.gesso, M.Plaster, { Name = "Teto" })
	local ab = { N = {}, S = {}, O = {}, L = {} }
	for _, p in o.portas or {} do
		table.insert(ab[p.lado], { centro = p.centro, largura = p.largura or 4.4, base = p.base or 0, topo = p.altura or 8 })
	end
	local cor = o.corParede or COR.papelDorm
	local mat = o.matParede or M.Fabric
	local nome = if mat == M.Fabric then "Papel" else "Parede"
	c:parede(V3(x0 - 0.3, 0, z0), V3(x1 + 0.3, 0, z0), F, h, 0.6, cor, mat, ab.N, { Name = nome })
	c:parede(V3(x0 - 0.3, 0, z1), V3(x1 + 0.3, 0, z1), F, h, 0.6, cor, mat, ab.S, { Name = nome })
	c:parede(V3(x0, 0, z0), V3(x0, 0, z1), F, h, 0.6, cor, mat, ab.O, { Name = nome })
	c:parede(V3(x1, 0, z0), V3(x1, 0, z1), F, h, 0.6, cor, mat, ab.L, { Name = nome })
	-- rodapé escuro
	if not o.semRodape then
		local r = COR.lambri
		c:entre(V3(x0 + 0.3, F, z0 + 0.3), V3(x1 - 0.3, F + 0.5, z0 + 0.42), r, M.Wood)
		c:entre(V3(x0 + 0.3, F, z1 - 0.42), V3(x1 - 0.3, F + 0.5, z1 - 0.3), r, M.Wood)
		c:entre(V3(x0 + 0.3, F, z0 + 0.3), V3(x0 + 0.42, F + 0.5, z1 - 0.3), r, M.Wood)
		c:entre(V3(x1 - 0.42, F, z0 + 0.3), V3(x1 - 0.3, F + 0.5, z1 - 0.3), r, M.Wood)
	end
	return x0, x1, z0, z1
end

-- ponto de interação (peça invisível onde o botão INTERAGIR aparece)
local function ancora(c, id: string, pos: Vector3)
	return c:caixa(pos, V3(1.6, 1.6, 1.6), RGB(0, 0, 0), M.SmoothPlastic, {
		Name = "OI3_P_" .. id,
		Transparency = 1,
		colisao = false,
		CanQuery = true,
	})
end

-- folha de porta (fechada) numa abertura; o cliente gira pela dobradiça quando abre
local function folhaPorta(c, id: string, centroBase: Vector3, dirLargura: Vector3, largura: number?, cor: Color3?)
	local lw = largura or 4.2
	local d = dirLargura.Unit
	local cf = CFrame.fromMatrix(centroBase + V3(0, 3.85, 0), d, Vector3.yAxis)
	local folha = c:bloco(cf, V3(lw, 7.7, 0.25), cor or COR.madeira, M.Wood, { Name = "OI3_Porta_" .. id, colisao = true })
	folha:SetAttribute("Dobradica", centroBase - d * (lw / 2))
	c:bloco(cf * CF(0, 1.7, 0.16), V3(lw - 1, 2.6, 0.06), COR.madeiraEscura, M.Wood, { Name = "OI3_PortaDet_" .. id })
	c:bloco(cf * CF(0, -1.8, 0.16), V3(lw - 1, 2.6, 0.06), COR.madeiraEscura, M.Wood, { Name = "OI3_PortaDet_" .. id })
	c:bola((cf * CF(lw / 2 - 0.5, -0.3, 0.2)).Position, 0.3, COR.ouro, M.Metal, { Name = "OI3_PortaDet_" .. id })
	return folha
end

-- texto pintado/escrito numa superfície (bilhetes, mensagens na parede)
local function escrita(c, cf: CFrame, tam: Vector2, texto: string, cor: Color3, fonte: Font, nome: string?, fundo: Color3?)
	local p = c:bloco(cf, V3(tam.X, tam.Y, 0.04), fundo or RGB(0, 0, 0), M.SmoothPlastic, {
		Name = nome or "Escrita",
		Transparency = if fundo then 0 else 1,
		colisao = false,
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.6
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Name = "Texto"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.TextWrapped = true
	t.Text = texto
	t.TextColor3 = cor
	t.FontFace = fonte
	t.Parent = sg
	return p
end

local GIZ = Font.new("rbxasset://fonts/families/PermanentMarker.json")
local MAQUINA = Font.new("rbxasset://fonts/families/SpecialElite.json")
local GIZ_CORES = { RGB(196, 60, 52), RGB(60, 90, 170), RGB(220, 170, 50), RGB(70, 130, 70), RGB(40, 36, 40) }

local function lampada(c, pos: Vector3, brilho: number?, alcance: number?, cor: Color3?)
	c:bloco(CF(pos + V3(0, 1.2, 0)), V3(0.06, 2.4, 0.06), COR.ferro, M.Metal)
	local b = c:bola(pos, 0.5, RGB(255, 226, 170), M.Neon, { Name = "OI3_Lampada" })
	c:luz(b, "PointLight", { Range = alcance or 16, Brightness = brilho or 0.7, Color = cor or RGB(255, 214, 160), Shadows = false })
	return b
end

-- cadeira com encosto para TRÁS de quem senta (olhar = para onde a pessoa olha)
local function cadeira(c, base: Vector3, olhar: Vector3, nome: string?)
	local f = V3(olhar.X, 0, olhar.Z).Unit
	local d = Vector3.yAxis:Cross(f).Unit
	local cf = CFrame.fromMatrix(base, d, Vector3.yAxis) -- Z local = olhar
	local extra = { Name = nome or "Cadeira" }
	c:bloco(cf * CF(0, 1.6, 0), V3(1.9, 0.18, 1.9), COR.madeira, M.Wood, extra)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c:bloco(cf * CF(sx * 0.8, 0.78, sz * 0.8), V3(0.18, 1.56, 0.18), COR.madeiraEscura, M.Wood, extra)
		end
		c:bloco(cf * CF(sx * 0.8, 2.8, -0.85), V3(0.18, 2.3, 0.18), COR.madeiraEscura, M.Wood, extra)
	end
	c:bloco(cf * CF(0, 3.3, -0.85), V3(1.6, 0.6, 0.12), COR.madeira, M.Wood, extra)
	c:bloco(cf * CF(0, 2.5, -0.85), V3(1.6, 0.14, 0.1), COR.madeira, M.Wood, extra)
	return cf
end

-- desenho de criança (papel na parede) feito com quadrinhos coloridos; "cena" escolhe o desenho
local function papelDesenho(c, centro: Vector3, normal: Vector3, cena: string, nome: string?)
	local d = Vector3.yAxis:Cross(normal).Unit
	local cf = CFrame.fromMatrix(centro + normal * 0.05, d, Vector3.yAxis)
	local papel = c:bloco(cf, V3(2.2, 1.6, 0.03), RGB(230, 224, 206), M.SmoothPlastic, { Name = nome or "Desenho", colisao = false })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Arte"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 80
	sg.LightInfluence = 1
	sg.Parent = papel
	MissoesMapa.desenhar(sg, cena)
	return papel
end

-- arte dos desenhos (também usada nas telas de "lembrança" do cliente)
function MissoesMapa.desenhar(pai: Instance, cena: string)
	for _, x in pai:GetChildren() do
		if x:IsA("GuiObject") then
			x:Destroy()
		end
	end
	local function q(x: number, y: number, w: number, h: number, cor: Color3, rot: number?, redondo: boolean?)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = rot or 0
		f.BackgroundColor3 = cor
		f.BorderSizePixel = 0
		if redondo then
			local u = Instance.new("UICorner")
			u.CornerRadius = UDim.new(1, 0)
			u.Parent = f
		end
		f.Parent = pai
		return f
	end
	local function boneco(x: number, chao: number, alto: number, cor: Color3, cabeloCor: Color3?)
		q(x, chao - alto * 0.78, alto * 0.24, alto * 0.24 * 1.4, cor, 0, true)
		if cabeloCor then
			q(x, chao - alto * 0.88, alto * 0.26, alto * 0.08, cabeloCor)
		end
		q(x, chao - alto * 0.42, alto * 0.06, alto * 0.48, cor)
		q(x, chao - alto * 0.5, alto * 0.34, alto * 0.05, cor)
		q(x - alto * 0.06, chao - alto * 0.08, alto * 0.05, alto * 0.22, cor, 18)
		q(x + alto * 0.06, chao - alto * 0.08, alto * 0.05, alto * 0.22, cor, -18)
	end
	local preto = GIZ_CORES[5]
	if cena == "embaixo_cama" then
		-- três crianças escondidas embaixo de uma cama
		q(0.5, 0.36, 0.86, 0.06, RGB(110, 80, 50))
		q(0.08, 0.6, 0.04, 0.5, RGB(110, 80, 50))
		q(0.92, 0.6, 0.04, 0.5, RGB(110, 80, 50))
		for i, x in { 0.32, 0.5, 0.68 } do
			q(x, 0.62, 0.1, 0.13, GIZ_CORES[i], 0, true)
			q(x, 0.74, 0.14, 0.06, GIZ_CORES[i])
		end
		q(0.5, 0.92, 0.9, 0.02, preto)
	elseif cena == "mao_porta" then
		-- a porta e uma mão ADULTA segurando a porta
		q(0.42, 0.55, 0.3, 0.76, RGB(110, 80, 50))
		q(0.52, 0.55, 0.03, 0.08, GIZ_CORES[3], 0, true)
		q(0.66, 0.42, 0.24, 0.07, RGB(214, 186, 150), -8)
		for i = 0, 3 do
			q(0.55 + i * 0.012, 0.36 + i * 0.025, 0.09, 0.03, RGB(214, 186, 150), -8)
		end
		q(0.86, 0.45, 0.18, 0.12, RGB(80, 60, 44), -8)
		q(0.2, 0.86, 0.06, 0.08, GIZ_CORES[1], 0, true)
		q(0.28, 0.86, 0.06, 0.08, GIZ_CORES[2], 0, true)
	elseif cena == "vo_atras" or cena == "vo_mao" then
		-- três crianças e o Vô (alto, cabelo cinza, casaco marrom) atrás delas
		boneco(0.3, 0.9, 0.36, GIZ_CORES[1], preto)
		boneco(0.47, 0.9, 0.34, GIZ_CORES[2], RGB(40, 30, 24))
		boneco(0.64, 0.9, 0.36, GIZ_CORES[4], RGB(90, 60, 30))
		local vx = if cena == "vo_mao" then 0.76 else 0.5
		boneco(vx, 0.86, 0.7, RGB(110, 80, 56), RGB(170, 170, 170))
		if cena == "vo_mao" then
			-- o braço do Vô descendo até a mão de uma das crianças
			q(0.7, 0.62, 0.16, 0.035, RGB(110, 80, 56), 30)
		end
		q(0.5, 0.94, 0.9, 0.02, GIZ_CORES[4])
	elseif cena == "velas" then
		-- quatro crianças, cada uma com uma vela colorida e um número
		local ordem = { GIZ_CORES[1], GIZ_CORES[2], GIZ_CORES[3], GIZ_CORES[4] }
		for i = 1, 4 do
			local x = 0.14 + (i - 1) * 0.24
			boneco(x, 0.9, 0.32, preto)
			q(x + 0.07, 0.55, 0.03, 0.14, ordem[i])
			q(x + 0.07, 0.46, 0.035, 0.05, GIZ_CORES[3], 0, true)
			local n = Instance.new("TextLabel")
			n.BackgroundTransparency = 1
			n.AnchorPoint = Vector2.new(0.5, 0.5)
			n.Position = UDim2.fromScale(x, 0.18)
			n.Size = UDim2.fromScale(0.16, 0.24)
			n.TextScaled = true
			n.Text = tostring(i)
			n.TextColor3 = ordem[i]
			n.FontFace = GIZ
			n.Parent = pai
		end
	elseif cena == "carrinho" or cena == "boneca" or cena == "ursinho" then
		-- foto de criança com o brinquedo (pista da Missão 7)
		q(0.5, 0.5, 1, 1, RGB(150, 130, 104))
		local cabelo = if cena == "carrinho" then RGB(20, 20, 22) elseif cena == "boneca" then RGB(16, 14, 16) else RGB(84, 52, 30)
		q(0.4, 0.38, 0.24, 0.28, RGB(240, 200, 60), 0, true)
		q(0.4, 0.27, 0.26, 0.09, cabelo)
		q(0.4, 0.74, 0.32, 0.36, if cena == "carrinho" then RGB(30, 30, 34) elseif cena == "boneca" then RGB(190, 160, 220) else RGB(130, 176, 220))
		if cena == "carrinho" then
			q(0.72, 0.8, 0.22, 0.1, RGB(170, 30, 30))
			q(0.66, 0.86, 0.06, 0.06, preto, 0, true)
			q(0.78, 0.86, 0.06, 0.06, preto, 0, true)
		elseif cena == "boneca" then
			q(0.72, 0.62, 0.1, 0.1, RGB(232, 210, 186), 0, true)
			q(0.72, 0.76, 0.14, 0.2, RGB(120, 70, 86))
		else
			q(0.72, 0.66, 0.16, 0.16, RGB(112, 82, 58), 0, true)
			q(0.72, 0.8, 0.2, 0.18, RGB(112, 82, 58), 0, true)
		end
	elseif cena == "foto_apagada" then
		-- foto do terceiro menino com o rosto completamente apagado
		q(0.5, 0.5, 1, 1, RGB(150, 130, 104))
		q(0.5, 0.4, 0.3, 0.34, RGB(230, 224, 206), 0, true)
		q(0.5, 0.78, 0.42, 0.36, RGB(130, 176, 220))
		for k = 1, 8 do
			q(0.5 + ((k * 7) % 5 - 2) * 0.02, 0.4 + ((k * 3) % 5 - 2) * 0.03, 0.34, 0.02, RGB(236, 232, 220), (k * 41) % 170)
		end
	elseif cena == "simbolos" then
		-- símbolos inventados pelo avô (não são de religião nenhuma)
		q(0.25, 0.5, 0.3, 0.42, RGB(110, 20, 20), 0, true)
		q(0.25, 0.5, 0.24, 0.34, RGB(28, 22, 22), 0, true)
		q(0.25, 0.5, 0.04, 0.42, RGB(110, 20, 20))
		q(0.6, 0.5, 0.36, 0.04, RGB(110, 20, 20))
		q(0.6, 0.5, 0.04, 0.36, RGB(110, 20, 20))
		q(0.6, 0.5, 0.14, 0.18, RGB(110, 20, 20), 0, true)
		for i = 0, 2 do
			q(0.86, 0.32 + i * 0.18, 0.12, 0.03, RGB(110, 20, 20), 12)
		end
	end
end

---------------------------------------------------------------------------
local CONSTRUIR: { [string]: (any, any) -> () } = {}

-- MISSÃO 1: o quarto (camas, armários e o baú) e a porta escura de onde a sombra vem
CONSTRUIR.quarto = function(c, l)
	local O = l.origem
	sala(c, O, 34, 24, 11, {
		corParede = COR.papelDorm,
		portas = { { lado = "L", centro = 12, largura = 4.4 }, { lado = "O", centro = 7, largura = 4.4 } },
	})
	-- porta trancada (leste) e o vão escuro (oeste) com um "corredor" preto
	folhaPorta(c, "saida", L(O, 17, 0, 0), V3(0, 0, 1))
	c:entre(L(O, -25, -1, -9), L(O, -17.3, 9, -1), RGB(2, 2, 3), M.SmoothPlastic, { Name = "Vao", colisao = false })
	c:entre(L(O, -25, -1.05, -9), L(O, -17, 0, -1), RGB(10, 8, 7), M.Wood)
	for i, x in { -11, -4, 3, 10 } do
		Moveis.cama(c, L(O, x, 0, -11.7), V3(0, 0, 1), COR.cobertores[(i % #COR.cobertores) + 1])
	end
	Moveis.criado(c, L(O, -7.5, 0, -11), V3(0, 0, 1))
	Moveis.criado(c, L(O, 6.5, 0, -11), V3(0, 0, 1))
	-- armários (dá para entrar)
	for _, x in { -8, 6 } do
		local cf = CFrame.fromMatrix(L(O, x, 4.6, 10.6), V3(1, 0, 0), Vector3.yAxis)
		c:bloco(cf * CF(0, 0, 0.9), V3(4.4, 9.2, 0.2), COR.madeiraEscura, M.Wood)
		for _, s in { -1, 1 } do
			c:bloco(cf * CF(s * 2.1, 0, 0), V3(0.2, 9.2, 2), COR.madeiraEscura, M.Wood)
		end
		c:bloco(cf * CF(0, 4.6, 0), V3(4.6, 0.25, 2.2), COR.madeira, M.Wood)
		for _, s in { -1, 1 } do
			c:bloco(cf * CF(s * 1.05, 0.2, -0.95), V3(2, 8.4, 0.12), COR.madeira, M.Wood)
			for k = 0, 5 do
				c:bloco(cf * CF(s * 1.05, 1.8 + k * 0.35, -1.02), V3(1.6, 0.08, 0.04), COR.madeiraEscura, M.Wood)
			end
		end
	end
	-- baú grande no canto
	c:entre(L(O, -17, 0, 7.4), L(O, -12.8, 2.6, 10.6), COR.madeira, M.Wood)
	c:entre(L(O, -17.1, 2.6, 7.3), L(O, -12.7, 2.9, 10.7), COR.madeiraEscura, M.Wood)
	-- brinquedos, cômoda, janela tapada e luz fraca
	Moveis.ursinho(c, L(O, -13, 0, 6.6), V3(1, 0, 0))
	Moveis.blocos(c, L(O, 0, 0, 7), 11)
	Moveis.comoda(c, L(O, 14.6, 0, -8), V3(-1, 0, 0), 4)
	Moveis.tapete(c, -6 + O.X, -2 + O.Z, 4 + O.X, 4 + O.Z, F, RGB(70, 40, 62), RGB(168, 140, 102))
	for k = 0, 3 do
		c:bloco(CFrame.new(L(O, -2 + k * 1.3, 6.2, 11.7)) * CFrame.Angles(0, 0, math.rad(k * 7 - 10)), V3(1.1, 4, 0.2), COR.madeira, M.Wood)
	end
	lampada(c, L(O, 0, 8.6, 0), 0.35, 20)
	Moveis.vela(c, L(O, -7.5, 2.26, -11), { altura = 0.5, luz = true, alcance = 10, brilho = 0.6 })
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
	for _, e in l.esconderijos do
		ancora(c, e.id, e.pos + V3(0, 1.4, 0))
	end
	-- desenho das crianças embaixo da última cama (só aparece no fim)
	papelDesenho(c, L(O, 10, 0.2, -6), V3(0, 1, 0.001), "embaixo_cama", "OI3_X_DesenhoCama")
end

-- MISSÃO 2: a festa (mesa para QUATRO, bolo, toca-discos, balões, desenhos com a ordem das velas)
CONSTRUIR.festa = function(c, l)
	local O = l.origem
	sala(c, O, 30, 22, 11, {
		corParede = RGB(86, 64, 70),
		portas = { { lado = "O", centro = 11, largura = 4.4 }, { lado = "L", centro = 14.6, largura = 4.4 } },
	})
	folhaPorta(c, "lavanderia", L(O, 15, 0, 3.6), V3(0, 0, 1))
	-- bandeirinhas
	for i = 0, 18 do
		local x = -14 + i * 1.55
		c:cunha(CFrame.new(L(O, x, 9.2, -10.6)) * CFrame.Angles(math.pi, 0, 0), V3(0.05, 0.9, 0.9), GIZ_CORES[(i % 4) + 1], M.Fabric)
		c:cunha(CFrame.new(L(O, x, 9.2, 10.6)) * CFrame.Angles(math.pi, 0, 0), V3(0.05, 0.9, 0.9), GIZ_CORES[((i + 2) % 4) + 1], M.Fabric)
	end
	-- mesa comprida, toalha e quatro lugares
	c:entre(L(O, -4.5, 2.6, -2.4), L(O, 4.5, 2.85, 2.4), COR.madeira, M.Wood)
	c:entre(L(O, -4.7, 2.85, -2.6), L(O, 4.7, 2.9, 2.6), RGB(232, 214, 214), M.Fabric)
	for _, sx in { -4, 4 } do
		for _, sz in { -2, 2 } do
			c:coluna(L(O, sx, 0, sz), 2.6, 0.3, COR.madeiraEscura, M.Wood)
		end
	end
	for i, p in { { -2.4, -1 }, { 2.4, -1 }, { -2.4, 1 }, { 2.4, 1 } } do
		local sx, sz = p[1], p[2]
		cadeira(c, L(O, sx, 0, sz * 3.9), V3(0, 0, -sz), "OI3_X_Cadeira" .. i)
		-- prato e copo (fora do lugar até arrumar)
		c:cilindro(CF(L(O, sx + 0.8, 3.0, sz * 1.6)) * CFrame.Angles(0, 0, math.pi / 2), 0.06, 1.0, RGB(230, 228, 220), M.SmoothPlastic, { Name = "OI3_X_Prato" .. i })
		c:coluna(L(O, sx + 1.4, 2.9, sz * 2.0), 0.5, 0.3, RGB(196, 206, 214), M.Glass, { Name = "OI3_X_Copo" .. i, Transparency = 0.4 })
	end
	-- bolo com 4 velas apagadas
	c:coluna(L(O, 0, 2.9, 0), 0.9, 2.2, RGB(232, 200, 196), M.SmoothPlastic)
	c:coluna(L(O, 0, 3.8, 0), 0.08, 2.3, RGB(196, 60, 80), M.SmoothPlastic)
	for id, cor in { bolo_vermelha = GIZ_CORES[1], bolo_azul = GIZ_CORES[2], bolo_amarela = GIZ_CORES[3], bolo_verde = GIZ_CORES[4] } do
		local pos = l.pontos[id]
		c:coluna(V3(pos.X, F + 3.88, pos.Z), 0.42, 0.12, cor, M.SmoothPlastic, { Name = "OI3_X_VelaBolo_" .. id })
		local chama = c:caixa(V3(pos.X, F + 4.42, pos.Z), V3(0.1, 0.16, 0.1), COR.chama, M.Neon, { Name = "OI3_X_Chama_" .. id, Transparency = 1 })
		c:luz(chama, "PointLight", { Range = 7, Brightness = 0, Color = COR.luzVela, Shadows = false, Name = "Luz" })
	end
	-- toca-discos numa mesinha
	c:entre(L(O, 7, 0, -10.2), L(O, 9.8, 2.6, -8.4), COR.madeira, M.Wood)
	c:entre(L(O, 7.4, 2.6, -10), L(O, 9.4, 3.1, -8.6), RGB(60, 40, 30), M.Wood)
	c:cilindro(CF(L(O, 8.4, 3.16, -9.3)) * CFrame.Angles(0, 0, math.pi / 2), 0.04, 1.3, RGB(16, 16, 18), M.SmoothPlastic, { Name = "OI3_X_Disco" })
	c:bloco(CF(L(O, 9.1, 3.3, -9.0)) * CFrame.Angles(0, math.rad(30), 0), V3(0.08, 0.08, 0.9), RGB(170, 170, 176), M.Metal)
	-- armário com gavetas (a agulha)
	Moveis.comoda(c, L(O, -4, 0, 10.4), V3(0, 0, -1), 4)
	-- balões murchos/escondidos (cada um com um número escrito)
	for id, cor in { bal_azul = GIZ_CORES[2], bal_vermelho = GIZ_CORES[1], bal_amarelo = GIZ_CORES[3] } do
		local pos = l.pontos[id]
		local b = c:bola(pos + V3(0, -1.2, 0), V3(1.1, 1.3, 1.1), cor, M.SmoothPlastic, { Name = "OI3_X_Balao_" .. id })
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 60
		sg.Parent = b
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.FontFace = GIZ
		t.TextColor3 = RGB(250, 246, 236)
		t.Text = (require(script.Parent.Missoes) :: any).DIGITOS_BALOES[id]
		t.Parent = sg
	end
	-- velas soltas pela sala
	for _, id in { "vela_a", "vela_b", "vela_c", "vela_d" } do
		c:coluna(l.pontos[id] + V3(0, -0.3, 0), 0.5, 0.14, COR.vela, M.SmoothPlastic, { Name = "OI3_X_" .. id })
	end
	-- desenhos com a ordem das velas (parede oeste) e as mensagens (parede norte)
	papelDesenho(c, L(O, -14.65, 5, -4), V3(1, 0, 0), "velas", "Desenho")
	escrita(c, CFrame.fromMatrix(L(O, 0, 6.8, -10.65), V3(1, 0, 0), Vector3.yAxis), Vector2.new(16, 2.2), "A FESTA NÃO PODE COMEÇAR SEM TODOS.", RGB(150, 26, 26), GIZ, "OI3_X_Msg1")
	escrita(c, CFrame.fromMatrix(L(O, 0, 4.4, -10.65), V3(1, 0, 0), Vector3.yAxis), Vector2.new(14, 2.2), "VOCÊS ESQUECERAM DELE.", RGB(170, 20, 20), GIZ, "OI3_X_Msg2")
	escrita(c, CFrame.fromMatrix(L(O, 14.65, 4.6, 6.2), V3(0, 0, 1), Vector3.yAxis), Vector2.new(1.4, 1.8), "[ _ _ _ ]", RGB(220, 210, 190), MAQUINA, "Teclado", RGB(30, 28, 30))
	lampada(c, L(O, 0, 8.2, 0), 0.25, 18, RGB(255, 190, 150))
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- MISSÃO 3: a lavanderia (máquinas, canos, varal com roupinhas, ralo, água no chão)
CONSTRUIR.lavanderia = function(c, l)
	local O = l.origem
	sala(c, O, 26, 20, 10, {
		corParede = RGB(92, 98, 96),
		matParede = M.Concrete,
		piso = "pedra",
		portas = { { lado = "O", centro = 14, largura = 4.4 }, { lado = "L", centro = 15, largura = 4.4 } },
	})
	folhaPorta(c, "servico", L(O, 13, 0, 5), V3(0, 0, 1), 4.2, RGB(70, 74, 72))
	for i, base in l.maquinas do
		local cf = CF(base + V3(0, 2, 0))
		c:bloco(cf, V3(3.6, 4, 3.2), RGB(214, 214, 206), M.SmoothPlastic, { Name = "OI3_X_Maquina" .. i, colisao = true })
		c:cilindro(cf * CF(0, 0.2, 1.62) * CFrame.Angles(0, math.pi / 2, 0), 0.1, 2.2, RGB(90, 96, 100), M.Metal)
		c:cilindro(cf * CF(0, 0.2, 1.68) * CFrame.Angles(0, math.pi / 2, 0), 0.06, 1.7, RGB(30, 40, 48), M.Glass, { Name = "OI3_X_Janela" .. i, Transparency = 0.25 })
		local luz = c:caixa((cf * CF(1.2, 1.7, 1.62)).Position, V3(0.22, 0.22, 0.08), RGB(220, 40, 30), M.Neon, { Name = "OI3_X_LuzMaquina" .. i })
		c:luz(luz, "PointLight", { Range = 5, Brightness = 0.6, Color = RGB(255, 60, 40), Shadows = false })
		escrita(c, CFrame.fromMatrix((cf * CF(-1.1, 1.55, 1.63)).Position, V3(1, 0, 0), Vector3.yAxis), Vector2.new(0.7, 0.7), tostring(i), RGB(30, 30, 34), MAQUINA)
	end
	-- o bilhete com a ordem
	escrita(c, CFrame.fromMatrix(L(O, -4, 5.8, -9.65), V3(1, 0, 0), Vector3.yAxis), Vector2.new(3.6, 2.2), "DESLIGAR:\n3 - 1 - 4 - 2", RGB(40, 34, 30), MAQUINA, "Bilhete", RGB(226, 220, 196))
	-- canos e o registro
	for _, y in { 7.6, 8.4 } do
		c:cilindro(CF(L(O, 0, y, -9.4)), 25, 0.5, RGB(110, 90, 70), M.Metal)
	end
	c:cilindro(CF(L(O, -12.4, 4, -9.2)) * CFrame.Angles(0, 0, math.pi / 2), 8, 0.6, RGB(110, 90, 70), M.Metal)
	c:cilindro(CF(L(O, -11.8, 3.5, -8.6)) * CFrame.Angles(0, math.pi / 2, 0), 0.2, 1.4, RGB(170, 40, 30), M.Metal, { Name = "OI3_X_Registro" })
	-- espaço apertado (a válvula fica atrás dele)
	c:entre(L(O, 9, 2.6, -4), L(O, 13, 3.4, 2), RGB(80, 84, 82), M.Concrete)
	c:cilindro(CF(L(O, 11, 3.0, -1)), 4, 1.2, RGB(110, 90, 70), M.Metal)
	c:cilindro(CF(L(O, 12.4, 1.2, -1.2)) * CFrame.Angles(0, math.pi / 2, 0), 0.2, 1.1, RGB(170, 40, 30), M.Metal, { Name = "OI3_X_Valvula" })
	-- varal com roupinhas
	c:cilindro(CF(L(O, 0, 7.2, 4)), 24, 0.06, RGB(200, 196, 186), M.SmoothPlastic)
	for i = 0, 7 do
		local x = -10 + i * 2.8
		c:bloco(CF(L(O, x, 6.3, 4)) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 5)), V3(1.3, 1.6, 0.08), GIZ_CORES[(i % 4) + 1]:Lerp(RGB(220, 220, 210), 0.4), M.Fabric)
	end
	-- o ralo com a chave presa numa roupinha
	c:entre(L(O, 5, 0.01, 7), L(O, 7, 0.06, 8.2), RGB(40, 40, 42), M.DiamondPlate)
	c:bloco(CF(L(O, 6, 0.15, 7.6)) * CFrame.Angles(0, math.rad(20), math.rad(80)), V3(0.08, 1.1, 1), RGB(150, 176, 210), M.Fabric)
	c:bloco(CF(L(O, 6.2, 0.3, 7.5)), V3(0.5, 0.08, 0.16), COR.ouro, M.Metal, { Name = "OI3_X_Chave" })
	-- água no chão (abaixa quando fecha a válvula)
	c:entre(L(O, -12.7, 0, -9.7), L(O, 12.7, 0.3, 9.7), RGB(40, 64, 70), M.Glass, { Name = "OI3_X_Agua", Transparency = 0.55, colisao = false })
	lampada(c, L(O, 0, 7.5, 0), 0.25, 16, RGB(200, 230, 255))
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- MISSÃO 4: corredor dos espelhos. Atrás de cada espelho há uma "versão" do corredor (o reflexo)
-- com as portas em lugares diferentes; só uma parede é passagem de verdade.
CONSTRUIR.espelhos = function(c, l)
	local O = l.origem
	local h = 11
	-- corredor A: x -28..12, z -4..4
	c:laje(O.X - 28.6, O.Z - 4.6, O.X + 12.6, O.Z + 4.6, F - 0.05, 0.6, RGB(14, 9, 7), M.SmoothPlastic)
	Moveis.assoalho(c, O.X - 28, O.Z - 4, O.X + 12, O.Z + 4, F, COR.assoalho)
	c:laje(O.X - 28.6, O.Z - 4.6, O.X + 12.6, O.Z + 4.6, F + h + 0.5, 0.5, COR.gesso, M.Plaster, { Name = "Teto" })
	local papel = RGB(70, 52, 60)
	local abN = {}
	for _, x in l.espelhos do
		table.insert(abN, { centro = x + 28.3, largura = 4.6, base = 1.2, topo = 8.4 })
	end
	c:parede(L(O, -28.3, -1, -4), L(O, 12.3, -1, -4), F, h, 0.6, papel, M.Fabric, abN, { Name = "Papel" })
	c:parede(L(O, -28, -1, -4), L(O, -28, -1, 4), F, h, 0.6, papel, M.Fabric, nil, { Name = "Papel" })
	c:parede(L(O, 12, -1, -4), L(O, 12, -1, 4), F, h, 0.6, papel, M.Fabric, nil, { Name = "Papel" })
	-- parede sul com a passagem escondida (fechada por um painel que desliza)
	c:parede(L(O, -28.3, -1, 4), L(O, 12.3, -1, 4), F, h, 0.6, papel, M.Fabric, { { centro = 32.3, largura = 4.4, base = 0, topo = 8 } }, { Name = "Papel" })
	c:entre(L(O, 1.8, 0, 3.7), L(O, 6.2, 8, 4.3), papel, M.Fabric, { Name = "OI3_X_Passagem", colisao = true })
	-- portas pintadas (falsas) no corredor
	Moveis.portaFechada(c, L(O, -24, 0, 3.7), V3(0, 0, -1))
	Moveis.portaFechada(c, L(O, 10, 0, 3.7), V3(0, 0, -1))
	-- os espelhos (vidro meio transparente) e os "reflexos" atrás deles
	for i, x in l.espelhos do
		local centro = L(O, x, 4.8, -4.35)
		c:bloco(CF(centro), V3(4.6, 7.2, 0.1), RGB(150, 160, 170), M.Glass, { Name = "OI3_X_Espelho" .. i, Transparency = 0.42, Reflectance = 0.12, colisao = true })
		c:entre(L(O, x - 2.7, 0.9, -4.6), L(O, x + 2.7, 1.2, -4.1), COR.ouro, M.Metal)
		c:entre(L(O, x - 2.7, 8.4, -4.6), L(O, x + 2.7, 8.7, -4.1), COR.ouro, M.Metal)
		c:entre(L(O, x - 2.7, 1.2, -4.6), L(O, x - 2.4, 8.4, -4.1), COR.ouro, M.Metal)
		c:entre(L(O, x + 2.4, 1.2, -4.6), L(O, x + 2.7, 8.4, -4.1), COR.ouro, M.Metal)
		-- o "reflexo": um pedaço do corredor espelhado (z de -12 a -4)
		local zr0, zr1 = O.Z - 12, O.Z - 4.6
		local r = 3.8 -- meia largura do reflexo (sem encostar no reflexo vizinho)
		c:entre(V3(O.X + x - r, F - 0.6, zr0), V3(O.X + x + r, F - 0.05, zr1), RGB(14, 9, 7), M.SmoothPlastic)
		Moveis.assoalho(c, O.X + x - r, zr0, O.X + x + r, zr1, F, COR.assoalho)
		c:entre(V3(O.X + x - r, F + h, zr0), V3(O.X + x + r, F + h + 0.5, zr1), COR.gesso, M.Plaster)
		c:entre(V3(O.X + x - r - 0.4, F, zr0 - 0.6), V3(O.X + x + r + 0.4, F + h, zr0), papel, M.Fabric)
		c:entre(V3(O.X + x - r - 0.4, F, zr0), V3(O.X + x - r, F + h, zr1), papel, M.Fabric)
		c:entre(V3(O.X + x + r, F, zr0), V3(O.X + x + r + 0.4, F + h, zr1), papel, M.Fabric)
		-- o que cada reflexo mostra na parede "do fundo" (= a parede sul refletida)
		if i == 1 then
			Moveis.portaFechada(c, V3(O.X - 24, F, zr0 + 0.3), V3(0, 0, 1)) -- igual à real (não ajuda)
		elseif i == 4 then
			-- o reflexo mostra uma porta onde a parede real é lisa: É A PASSAGEM
			Moveis.portaFechada(c, V3(O.X + 4, F, zr0 + 0.3), V3(0, 0, 1), RGB(110, 80, 56))
			c:entre(V3(O.X + 1.6, F, zr0 + 0.2), V3(O.X + 6.4, F + 8.2, zr0 + 0.35), RGB(255, 210, 140), M.Neon, { Name = "OI3_X_Revela", Transparency = 0.92 })
		end
		lampada(c, V3(O.X + x, F + 9, zr0 + 3), 0.18, 12)
	end
	-- o "duplo" que anda sozinho aparece no reflexo 2 (o cliente coloca o ator lá)
	-- QUARTO B: atrás da passagem, com o último espelho na parede sul e a porta do quarto trancado
	local B = l.quartoB
	c:laje(B.X - 6.6, B.Z - 6.6, B.X + 6.6, B.Z + 6.6, F - 0.05, 0.6, RGB(14, 9, 7), M.SmoothPlastic)
	Moveis.assoalho(c, B.X - 6, B.Z - 6, B.X + 6, B.Z + 6, F, COR.assoalho)
	c:laje(B.X - 6.6, B.Z - 6.6, B.X + 6.6, B.Z + 6.6, F + h + 0.5, 0.5, COR.gesso, M.Plaster, { Name = "Teto" })
	c:parede(V3(B.X - 6, 0, B.Z - 6), V3(B.X - 6, 0, B.Z + 6), F, h, 0.6, papel, M.Fabric, nil, { Name = "Papel" })
	c:parede(V3(B.X + 6, 0, B.Z - 6), V3(B.X + 6, 0, B.Z + 6), F, h, 0.6, papel, M.Fabric, { { centro = 6, largura = 4.4, base = 0, topo = 8 } }, { Name = "Papel" })
	folhaPorta(c, "quarto", V3(B.X + 6, F, B.Z), V3(0, 0, 1), 4.2, RGB(70, 50, 40))
	c:parede(V3(B.X - 6.3, 0, B.Z + 6), V3(B.X + 6.3, 0, B.Z + 6), F, h, 0.6, papel, M.Fabric, { { centro = 6.3, largura = 6, base = 1, topo = 9 } }, { Name = "Papel" })
	c:bloco(CF(V3(B.X, F + 5, B.Z + 6.35)), V3(6, 8, 0.1), RGB(150, 160, 170), M.Glass, { Name = "OI3_X_UltimoEspelho", Transparency = 0.4, Reflectance = 0.12, colisao = true })
	c:entre(V3(B.X - 3.4, F + 0.7, B.Z + 6.1), V3(B.X + 3.4, F + 1.0, B.Z + 6.6), COR.ouro, M.Metal)
	c:entre(V3(B.X - 3.4, F + 9.0, B.Z + 6.1), V3(B.X + 3.4, F + 9.3, B.Z + 6.6), COR.ouro, M.Metal)
	-- o reflexo do último espelho (onde as três crianças aparecem)
	c:entre(V3(B.X - 7, F - 0.6, B.Z + 6.6), V3(B.X + 7, F - 0.05, B.Z + 16), RGB(14, 9, 7), M.SmoothPlastic)
	Moveis.assoalho(c, B.X - 7, B.Z + 6.6, B.X + 7, B.Z + 16, F, COR.assoalho)
	c:entre(V3(B.X - 7.6, F, B.Z + 16), V3(B.X + 7.6, F + h, B.Z + 16.6), papel, M.Fabric)
	c:entre(V3(B.X - 7.6, F, B.Z + 6.6), V3(B.X - 7, F + h, B.Z + 16), papel, M.Fabric)
	c:entre(V3(B.X + 7, F, B.Z + 6.6), V3(B.X + 7.6, F + h, B.Z + 16), papel, M.Fabric)
	c:entre(V3(B.X - 7, F + h, B.Z + 6.6), V3(B.X + 7, F + h + 0.5, B.Z + 16), COR.gesso, M.Plaster)
	lampada(c, V3(B.X, F + 9, B.Z + 11), 0.3, 14, RGB(200, 210, 255))
	lampada(c, L(O, -10, 9, 0), 0.22, 18)
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- MISSÃO 5: o quarto trancado (paredes que batem, armário, papel solto, a passagem minúscula)
CONSTRUIR.quarto_trancado = function(c, l)
	local O = l.origem
	sala(c, O, 24, 18, 10, {
		corParede = RGB(110, 120, 140),
		portas = { { lado = "O", centro = 13, largura = 4.4 }, { lado = "N", centro = 18.7, largura = 3.2, altura = 4.2 } },
	})
	-- tampa da passagem (some quando o mecanismo abre)
	c:entre(L(O, 4.8, 0, -9.3), L(O, 8, 4.2, -8.7), RGB(110, 120, 140), M.Fabric, { Name = "OI3_X_Tampa", colisao = true })
	-- o armário na frente da parede oca (desliza)
	local arm = c:entre(L(O, 4.2, 0, -8.7), L(O, 8.6, 8.4, -6.6), COR.madeiraEscura, M.Wood, { Name = "OI3_X_Armario", colisao = true })
	arm:SetAttribute("Deslizar", Vector3.new(5, 0, 0))
	-- papel de parede solto e os desenhos colados por baixo
	local papelSolto = c:entre(L(O, 4.6, 1, -8.68), L(O, 8.2, 7, -8.62), RGB(124, 132, 150), M.Fabric, { Name = "OI3_X_PapelSolto" })
	papelSolto:SetAttribute("Deslizar", Vector3.new(0, 0, 0))
	papelDesenho(c, L(O, 6.4, 4.6, -8.7), V3(0, 0, 1), "vo_atras", "DesenhoMecanismo")
	-- uma cama pequena, brinquedos, marcas de altura e desenhos
	Moveis.cama(c, L(O, -8, 0, -8.3), V3(0, 0, 1), RGB(120, 70, 86))
	Moveis.boneca(c, L(O, -3, 0, -7), V3(0, 0, 1))
	Moveis.blocos(c, L(O, 0, 0, 2), 23)
	Moveis.desenho(c, L(O, -11.6, 5, 2), V3(1, 0, 0), 1)
	Moveis.desenho(c, L(O, 11.6, 5, -3), V3(-1, 0, 0), 2)
	-- o espaço minúsculo atrás da parede (z de -17 a -9.3)
	local E = l.esconderijo
	c:entre(V3(E.X - 3, F - 0.6, E.Z - 4.6), V3(E.X + 3, F, E.Z + 3.8), RGB(60, 44, 32), M.Wood)
	c:entre(V3(E.X - 3, F + 5, E.Z - 4.6), V3(E.X + 3, F + 5.4, E.Z + 3.8), RGB(50, 40, 30), M.Wood)
	c:entre(V3(E.X - 3.6, F, E.Z - 4.6), V3(E.X - 3, F + 5, E.Z + 3.8), RGB(90, 80, 70), M.Wood)
	c:entre(V3(E.X + 3, F, E.Z - 4.6), V3(E.X + 3.6, F + 5, E.Z + 3.8), RGB(90, 80, 70), M.Wood)
	c:entre(V3(E.X - 3, F, E.Z - 5.2), V3(E.X + 3, F + 5, E.Z - 4.6), RGB(90, 80, 70), M.Wood)
	for i, alt in { 2.2, 2.6, 3.1 } do
		c:entre(V3(E.X + 2.9, F + alt, E.Z - 2 + i * 0.6), V3(E.X + 2.98, F + alt + 0.05, E.Z - 1.4 + i * 0.6), GIZ_CORES[i], M.SmoothPlastic)
	end
	Moveis.ursinho(c, V3(E.X - 2, F, E.Z - 3.6), V3(0.5, 0, 1).Unit)
	Moveis.blocos(c, V3(E.X + 1, F, E.Z - 3), 31)
	papelDesenho(c, l.desenhoMuda, V3(1, 0, 0), "vo_atras", "OI3_X_DesenhoMuda")
	lampada(c, L(O, 0, 7.4, 0), 0.3, 16, RGB(220, 230, 255))
	Moveis.vela(c, V3(E.X + 1.8, F, E.Z - 4), { altura = 0.4, luz = true, alcance = 8, brilho = 0.5 })
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- MISSÃO 6: o escritório do avô (mesa, estante de fitas, projetor, tela, caixa de energia)
CONSTRUIR.escritorio = function(c, l)
	local O = l.origem
	sala(c, O, 26, 20, 10, {
		corParede = RGB(66, 58, 50),
		matParede = M.Wood,
		portas = { { lado = "O", centro = 13, largura = 4.4 }, { lado = "N", centro = 7.8, largura = 4.4 } },
	})
	folhaPorta(c, "escada", L(O, -5.5, 0, -10), V3(1, 0, 0), 4.2, COR.madeiraEscura)
	-- mesa com gaveta
	c:entre(L(O, -11.6, 2.6, -7.6), L(O, -7.4, 2.85, -4.2), COR.madeira, M.Wood)
	c:entre(L(O, -11.4, 0, -7.4), L(O, -10.6, 2.6, -4.4), COR.madeiraEscura, M.Wood)
	c:entre(L(O, -8.4, 0, -7.4), L(O, -7.6, 2.6, -4.4), COR.madeiraEscura, M.Wood)
	c:entre(L(O, -10.4, 1.9, -5.2), L(O, -8.6, 2.5, -4.3), COR.madeira, M.Wood, { Name = "OI3_X_Gaveta" })
	cadeira(c, L(O, -9.5, 0, -2.6), V3(0, 0, -1))
	-- estante com fitas (cada uma com a data escrita)
	Moveis.estante(c, L(O, 3, 0, -9.7), V3(0, 0, 1), 10, 8, 5)
	for id, ano in { fita1987 = "1987", fita1991 = "1991", fita1994 = "1994" } do
		local pos = l.pontos[id]
		c:cilindro(CF(pos + V3(0, 0, 0.3)) * CFrame.Angles(0, math.pi / 2, 0), 0.3, 1.1, RGB(30, 30, 34), M.Metal, { Name = "OI3_X_" .. id })
		escrita(c, CFrame.fromMatrix(pos + V3(0, -0.85, 0.5), V3(1, 0, 0), Vector3.yAxis), Vector2.new(1.4, 0.45), ano, RGB(240, 230, 200), MAQUINA, nil, RGB(60, 50, 40))
	end
	-- projetor num pedestal, apontando para a tela (parede leste)
	c:coluna(L(O, 1.8, 0, 0), 2.8, 0.5, COR.ferro, M.Metal)
	c:entre(L(O, 0.8, 2.8, -0.7), L(O, 2.8, 4, 0.7), RGB(40, 40, 44), M.Metal, { Name = "OI3_X_Projetor" })
	for _, s in { -1, 1 } do
		c:cilindro(CF(L(O, 1.6, 4.6, s * 0.55)) * CFrame.Angles(0, math.pi / 2, 0), 0.1, 1.1, RGB(30, 30, 34), M.Metal)
	end
	c:cilindro(CF(L(O, 3.1, 3.4, 0)), 0.6, 0.5, RGB(60, 60, 66), M.Metal)
	local luzP = c:caixa(L(O, 3.45, 3.4, 0), V3(0.05, 0.4, 0.4), RGB(255, 240, 200), M.Neon, { Name = "OI3_X_LuzProjetor", Transparency = 1 })
	c:luz(luzP, "SpotLight", { Range = 14, Brightness = 0, Angle = 30, Face = Enum.NormalId.Right, Color = RGB(255, 236, 200), Shadows = false, Name = "Luz" })
	-- a tela (a imagem do filme aparece numa SurfaceGui do cliente)
	c:entre(L(O, 12.3, 2.6, -4.4), L(O, 12.6, 8.4, 4.4), RGB(214, 210, 198), M.SmoothPlastic, { Name = "OI3_X_Tela" })
	-- caixa de energia com três tomadas e a chave geral (parede sul)
	c:entre(L(O, -3.4, 2.4, 9.4), L(O, 3.6, 5.4, 9.75), RGB(70, 76, 74), M.Metal)
	for i, cor in { RGB(180, 40, 40), RGB(50, 80, 170), RGB(210, 170, 50) } do
		c:entre(L(O, -3.0 + (i - 1) * 1.6, 3.3, 9.2), L(O, -1.8 + (i - 1) * 1.6, 3.9, 9.4), cor, M.SmoothPlastic, { Name = "OI3_X_Tomada" .. i })
	end
	c:entre(L(O, 2.2, 3.6, 9.15), L(O, 3.0, 4.8, 9.4), RGB(30, 30, 30), M.Metal, { Name = "OI3_X_ChaveGeral" })
	lampada(c, L(O, -6, 7.4, 0), 0, 16, RGB(255, 220, 170))
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- MISSÃO 7: a sala das três cadeiras diante da porta do porão (três travas)
CONSTRUIR.cadeiras = function(c, l)
	local O = l.origem
	sala(c, O, 22, 18, 10, {
		corParede = RGB(78, 70, 62),
		portas = { { lado = "S", centro = 11, largura = 4.4 }, { lado = "N", centro = 11, largura = 4.4 } },
	})
	folhaPorta(c, "porao", L(O, 0, 0, -9), V3(1, 0, 0), 4.2, RGB(56, 40, 30))
	for i = 1, 3 do
		c:entre(L(O, 1.6, 1.8 + i * 1.4, -8.6), L(O, 2.3, 2.5 + i * 1.4, -8.4), COR.ferro, M.Metal, { Name = "OI3_X_Trava" .. i })
	end
	for cod, pos in l.cadeiras do
		local cf = cadeira(c, pos, V3(0, 0, -1), "OI3_X_Cadeira_" .. cod)
		local nome = if cod == "ke" then "KEKO" elseif cod == "ni" then "NINA" else "?"
		escrita(c, cf * CF(0, 3.3, -0.95) * CFrame.Angles(0, math.pi, 0), Vector2.new(1.4, 0.5), nome, RGB(230, 220, 196), MAQUINA)
	end
	-- fotos-pista na parede oeste: quem brinca com o quê
	for i, cena in { "carrinho", "boneca", "ursinho" } do
		local p = papelDesenho(c, L(O, -10.65, 5, -4 + (i - 1) * 3), V3(1, 0, 0), cena, "Foto")
		local nome = if cena == "carrinho" then "Keko" elseif cena == "boneca" then "Nina" else ""
		if nome ~= "" then
			escrita(c, CFrame.fromMatrix(L(O, -10.62, 3.8, -4 + (i - 1) * 3), V3(0, 0, -1), Vector3.yAxis), Vector2.new(1.4, 0.4), nome, RGB(40, 34, 30), GIZ)
		end
		p.Name = "Foto"
	end
	-- caixa com os três brinquedos
	c:entre(L(O, 7.4, 0, -7.6), L(O, 10.2, 1.8, -5.4), COR.madeira, M.Wood)
	-- a quarta cadeira (escondida até a contagem começar)
	cadeira(c, l.quarta, V3(-1, 0, -1), "OI3_X_QuartaCadeira")
	-- marcas de mãos pequenas no assento (aparecem no final)
	local mao = c:caixa(l.quarta + V3(0, 1.72, 0), V3(1.2, 0.02, 1.2), RGB(0, 0, 0), M.SmoothPlastic, { Name = "OI3_X_Maos", Transparency = 1 })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.Enabled = false
	sg.Parent = mao
	for k, p in { { 0.35, 0.4, -15 }, { 0.62, 0.55, 20 } } do
		local palma = Instance.new("Frame")
		palma.AnchorPoint = Vector2.new(0.5, 0.5)
		palma.Position = UDim2.fromScale(p[1], p[2])
		palma.Size = UDim2.fromScale(0.16, 0.2)
		palma.Rotation = p[3]
		palma.BackgroundColor3 = RGB(30, 22, 20)
		palma.BackgroundTransparency = 0.25
		palma.BorderSizePixel = 0
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(0.5, 0)
		u.Parent = palma
		palma.Parent = sg
		for dedo = 0, 3 do
			local d = Instance.new("Frame")
			d.AnchorPoint = Vector2.new(0.5, 1)
			d.Position = UDim2.fromScale(0.15 + dedo * 0.24, 0.02)
			d.Size = UDim2.fromScale(0.16, 0.5)
			d.BackgroundColor3 = palma.BackgroundColor3
			d.BackgroundTransparency = 0.25
			d.BorderSizePixel = 0
			d.Parent = palma
		end
		local _ = k
	end
	lampada(c, L(O, 0, 7.6, 2), 0.3, 18)
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- MISSÃO 8: o porão (corredor estreito e três salas: fotos, brinquedos e a sala trancada)
CONSTRUIR.porao = function(c, l)
	local O = l.origem
	local h = 9
	local pedra = RGB(72, 70, 66)
	-- corredor x -26..24, z -2..2
	c:laje(O.X - 26.6, O.Z - 2.6, O.X + 25.6, O.Z + 2.6, F - 0.05, 0.6, RGB(14, 9, 7), M.SmoothPlastic)
	c:laje(O.X - 26, O.Z - 2, O.X + 25, O.Z + 2, F, 0.06, RGB(58, 56, 54), M.Slate)
	c:laje(O.X - 26.6, O.Z - 2.6, O.X + 25.6, O.Z + 2.6, F + h + 0.5, 0.5, RGB(50, 46, 42), M.Concrete, { Name = "Teto" })
	local portasNorte = {}
	for _, x in { -14, 0, 14 } do
		table.insert(portasNorte, { centro = x + 26.3, largura = 4, base = 0, topo = 7.6 })
	end
	c:parede(L(O, -26.3, -1, -2), L(O, 25.3, -1, -2), F, h, 0.6, pedra, M.Cobblestone, portasNorte, { Name = "Parede" })
	c:parede(L(O, -26.3, -1, 2), L(O, 25.3, -1, 2), F, h, 0.6, pedra, M.Cobblestone, nil, { Name = "Parede" })
	c:parede(L(O, -26, -1, -2), L(O, -26, -1, 2), F, h, 0.6, pedra, M.Cobblestone, nil, { Name = "Parede" })
	-- marcas riscadas na parede (a quantidade dá a ordem dos símbolos)
	local simbolos = { { -20, 1 }, { 6, 2 }, { -6, 3 }, { 20, 4 } }
	for _, s in simbolos do
		for k = 1, s[2] do
			c:entre(L(O, s[1] + k * 0.35, 3.6, 1.66), L(O, s[1] + k * 0.35 + 0.06, 5.0, 1.7), RGB(200, 196, 186), M.SmoothPlastic)
		end
	end
	local nomesSimbolos = { "circulo", "olho", "espiral", "tres" }
	for i, s in simbolos do
		escrita(c, CFrame.fromMatrix(L(O, s[1] + 0.8, 6, 1.66), V3(-1, 0, 0), Vector3.yAxis), Vector2.new(1.1, 1.1), ({ "○", "◉", "@", "≡" })[i], RGB(140, 30, 30), GIZ)
		local _ = nomesSimbolos
	end
	-- salas ao norte (A: fotos/documentos, B: brinquedos/roupas, C: trancada)
	for i, x in { -14, 0, 14 } do
		local c0 = V3(O.X + x, 0, O.Z - 7.5)
		c:laje(c0.X - 6.6, c0.Z - 5.6, c0.X + 6.6, c0.Z + 5.2, F - 0.05, 0.6, RGB(14, 9, 7), M.SmoothPlastic)
		c:laje(c0.X - 6, c0.Z - 5, c0.X + 6, c0.Z + 5.2, F, 0.06, RGB(58, 56, 54), M.Slate)
		c:laje(c0.X - 6.6, c0.Z - 5.6, c0.X + 6.6, c0.Z + 5.2, F + h + 0.5, 0.5, RGB(50, 46, 42), M.Concrete)
		local abFundo = if i == 3 then { { centro = 6, largura = 5, base = 1.5, topo = 7.5 } } else nil
		c:parede(V3(c0.X - 6, 0, c0.Z - 5), V3(c0.X + 6, 0, c0.Z - 5), F, h, 0.6, pedra, M.Cobblestone, abFundo, { Name = "Parede" })
		c:parede(V3(c0.X - 6, 0, c0.Z - 5), V3(c0.X - 6, 0, c0.Z + 5.5), F, h, 0.6, pedra, M.Cobblestone, nil, { Name = "Parede" })
		c:parede(V3(c0.X + 6, 0, c0.Z - 5), V3(c0.X + 6, 0, c0.Z + 5.5), F, h, 0.6, pedra, M.Cobblestone, nil, { Name = "Parede" })
		lampada(c, V3(c0.X, F + 7, c0.Z), if i == 3 then 0.12 else 0.2, 14, RGB(255, 200, 150))
	end
	-- a saída (escada para cima) no fim leste
	c:entre(L(O, 25, -1, -2.6), L(O, 25.6, h, 2.6), pedra, M.Cobblestone)
	for k = 0, 5 do
		c:entre(L(O, 20.6 + k * 0.7, 0, -1.8), L(O, 25, (k + 1) * 0.55, 1.8), RGB(70, 52, 38), M.WoodPlanks)
	end
	c:entre(L(O, 23.8, 4.2, -1.9), L(O, 24.9, 8.2, 1.9), RGB(255, 236, 200), M.Neon, { Name = "OI3_X_LuzSaida", Transparency = 0.6 })
	-- sala A: gaveteiro e quadro de fotos
	c:entre(L(O, -18.4, 0, -10.2), L(O, -14.6, 3, -8.6), COR.madeira, M.Wood)
	c:entre(L(O, -13.6, 2.8, -12.25), L(O, -8.4, 6.4, -11.95), RGB(150, 120, 80), M.Wood, { Name = "Quadro" })
	for k = 0, 5 do
		papelDesenho(c, L(O, -12.9 + (k % 3) * 1.8, 3.8 + math.floor(k / 3) * 1.6, -11.9), V3(0, 0, 1), if k == 4 then "foto_apagada" else "carrinho", "Foto")
	end
	-- sala B: caixas, roupas penduradas e brinquedos
	for k = 0, 3 do
		c:entre(L(O, -3.5 + k * 1.9, 0, -11.4), L(O, -2 + k * 1.9, 1.6 + (k % 2) * 0.6, -9.6), RGB(120, 96, 66), M.Cardboard)
	end
	c:cilindro(CF(L(O, 0, 6.5, -6)), 9, 0.08, COR.ferro, M.Metal)
	for k = 0, 4 do
		c:bloco(CF(L(O, -3.4 + k * 1.7, 5.6, -6)), V3(1.2, 1.7, 0.08), GIZ_CORES[(k % 4) + 1]:Lerp(RGB(200, 196, 186), 0.5), M.Fabric)
	end
	Moveis.boneca(c, L(O, 4, 0, -10.6), V3(0, 0, 1))
	Moveis.ursinho(c, L(O, -4.8, 0, -7.2), V3(1, 0, 0))
	-- sala C: a porta com os quatro símbolos e o mecanismo
	c:entre(L(O, 11.8, 0, -2.4), L(O, 16.2, 7.6, -1.9), RGB(48, 44, 40), M.Metal, { Name = "OI3_X_PortaC", colisao = true })
	for i, x in { 11.6, 13, 14.4, 15.8 } do
		escrita(c, CFrame.fromMatrix(L(O, x, 4.6, -1.85), V3(1, 0, 0), Vector3.yAxis), Vector2.new(1.1, 1.1), ({ "○", "◉", "@", "≡" })[i], RGB(170, 160, 140), GIZ, "Simbolo", RGB(36, 32, 30))
	end
	-- dentro da sala C: símbolos inventados nas paredes, fotos, objetos, documentos, gravador e o espelho
	for k = 0, 2 do
		papelDesenho(c, L(O, 8.6, 5, -9 + k * 2.4), V3(1, 0, 0), "simbolos", "Simbolos")
	end
	c:entre(L(O, 9, 0, -10.2), L(O, 12, 2.7, -8), COR.madeira, M.Wood)
	escrita(c, CFrame.new(L(O, 10.5, 2.76, -9.1)) * CFrame.Angles(math.rad(-90), 0, 0), Vector2.new(2.4, 1.6), "FICHA DE ENTRADA\nKEKO — NINA", RGB(40, 34, 30), MAQUINA, "Documentos", RGB(226, 220, 196))
	papelDesenho(c, L(O, 18.4, 4, -12.15), V3(0, 0, 1), "foto_apagada", "FotoApagada")
	c:entre(L(O, 17, 0, -7), L(O, 19.4, 2.7, -5.8), COR.madeira, M.Wood)
	c:entre(L(O, 17.4, 2.7, -6.8), L(O, 18.8, 3.3, -6.0), RGB(50, 46, 42), M.Metal, { Name = "OI3_X_Gravador" })
	c:entre(L(O, 12.2, 0, -11.2), L(O, 15.8, 2.7, -10.2), COR.madeiraEscura, M.Wood)
	c:bloco(CF(l.espelho), V3(5, 6, 0.1), RGB(150, 160, 170), M.Glass, { Name = "OI3_X_EspelhoPorao", Transparency = 0.45, Reflectance = 0.12, colisao = true })
	-- reflexo do espelho do porão (as lembranças aparecem aqui)
	local E = l.espelho
	c:entre(V3(E.X - 6, F - 0.6, E.Z - 9), V3(E.X + 6, F - 0.05, E.Z - 0.35), RGB(14, 9, 7), M.SmoothPlastic)
	c:entre(V3(E.X - 6, F, E.Z - 9), V3(E.X + 6, F + 0.06, E.Z - 0.35), RGB(58, 56, 54), M.Slate)
	c:entre(V3(E.X - 6.6, F, E.Z - 9.6), V3(E.X + 6.6, F + h, E.Z - 9), pedra, M.Cobblestone)
	c:entre(V3(E.X - 6.6, F, E.Z - 9), V3(E.X - 6, F + h, E.Z - 0.35), pedra, M.Cobblestone)
	c:entre(V3(E.X + 6, F, E.Z - 9), V3(E.X + 6.6, F + h, E.Z - 0.35), pedra, M.Cobblestone)
	c:entre(V3(E.X - 6, F + h, E.Z - 9), V3(E.X + 6, F + h + 0.5, E.Z - 0.35), RGB(50, 46, 42), M.Concrete)
	lampada(c, V3(E.X, F + 7, E.Z - 5), 0.2, 12, RGB(190, 200, 255))
	lampada(c, L(O, -5, 7.6, 0), 0.15, 16)
	lampada(c, L(O, 12, 7.6, 0), 0.15, 16)
	for id, pos in l.pontos do
		ancora(c, id, pos)
	end
end

-- FINAL: a rua numa manhã de sol, o carro do avô
CONSTRUIR.rua = function(c, l)
	local O = l.origem
	-- chão: asfalto, calçadas, grama
	c:entre(L(O, -60, -1.2, -40), L(O, 60, 0, 40), RGB(70, 110, 60), M.Grass)
	c:entre(L(O, -60, -1.1, 0.5), L(O, 60, 0.02, 9), RGB(54, 54, 58), M.Asphalt)
	c:entre(L(O, -60, -1.1, -6), L(O, 60, 0.3, 0.5), RGB(176, 172, 164), M.Concrete)
	c:entre(L(O, -60, -1.1, 9), L(O, 60, 0.3, 14), RGB(176, 172, 164), M.Concrete)
	for k = -10, 10 do
		c:entre(L(O, k * 6, 0.02, 4.6), L(O, k * 6 + 3, 0.04, 4.9), RGB(230, 226, 210), M.SmoothPlastic)
	end
	-- fachadas de casas do outro lado
	local cores = { RGB(214, 196, 170), RGB(170, 190, 200), RGB(220, 214, 196), RGB(196, 170, 160) }
	for k = -4, 4 do
		local x = k * 13
		local cor = cores[(k % 4) + 1]
		c:entre(L(O, x - 5.5, 0, 16), L(O, x + 5.5, 11, 24), cor, M.SmoothPlastic)
		c:cunha(CF(L(O, x, 13, 20)), V3(11.6, 4, 8.6), RGB(140, 70, 60), M.Slate)
		for _, wx in { -2.6, 2.6 } do
			c:entre(L(O, x + wx - 1.2, 4, 15.9), L(O, x + wx + 1.2, 7, 16), RGB(150, 190, 220), M.Glass)
		end
		c:entre(L(O, x - 1, 0, 15.9), L(O, x + 1, 4, 16), RGB(110, 76, 50), M.Wood)
	end
	-- árvores e a cerca viva onde as crianças se escondem
	for k = -5, 5 do
		local base = L(O, k * 11 + 3, 0, -9)
		c:coluna(base, 4, 0.7, RGB(80, 60, 40), M.Wood)
		c:bola(base + V3(0, 6, 0), V3(6, 5, 6), RGB(70, 120, 60), M.LeafyGrass)
	end
	c:entre(L(O, -20, 0, -8.2), L(O, -9, 2.6, -7.2), RGB(60, 104, 52), M.LeafyGrass, { Name = "Cerca" })
	-- o carro do avô (sedã antigo, alto) — num modelo próprio para poder ir embora
	local carroModelo = Instance.new("Model")
	carroModelo.Name = "OI3_X_Carro"
	carroModelo.Parent = c.pai
	local cc = Construtor.novo(carroModelo)
	local C = l.carro
	local cf = CF(C)
	local corCarro = RGB(118, 24, 30)
	local corpo = cc:bloco(cf * CF(0, 1.6, 0), V3(11, 1.8, 4.6), corCarro, M.SmoothPlastic, { Name = "Corpo" })
	carroModelo.PrimaryPart = corpo
	cc:bloco(cf * CF(-0.4, 3.8, 0), V3(5.6, 2.6, 4.2), corCarro, M.SmoothPlastic, { Transparency = 0.0, Name = "Cabine" })
	cc:bloco(cf * CF(-0.4, 3.85, 0), V3(5.4, 2.2, 4.3), RGB(110, 150, 170), M.Glass, { Transparency = 0.45 })
	cc:bloco(cf * CF(-0.4, 3.85, 0), V3(5.7, 2.2, 3.9), RGB(110, 150, 170), M.Glass, { Transparency = 0.45 })
	for _, sx in { -3.6, 3.6 } do
		for _, sz in { -2.2, 2.2 } do
			cc:cilindro(cf * CF(sx, 0.95, sz) * CFrame.Angles(0, math.pi / 2, 0), 0.7, 1.9, RGB(20, 20, 22), M.SmoothPlastic)
			cc:cilindro(cf * CF(sx, 0.95, sz * 1.08) * CFrame.Angles(0, math.pi / 2, 0), 0.1, 1.0, RGB(190, 190, 196), M.Metal)
		end
	end
	for _, sz in { -1.6, 1.6 } do
		cc:bloco(cf * CF(5.55, 1.8, sz), V3(0.1, 0.5, 0.8), RGB(255, 250, 220), M.Neon)
		cc:bloco(cf * CF(-5.55, 1.8, sz), V3(0.1, 0.4, 0.7), RGB(200, 40, 30), M.Neon)
	end
	cc:bloco(cf * CF(1.9, 4.7, -0.9), V3(0.1, 0.35, 0.9), RGB(30, 30, 34), M.SmoothPlastic, { Name = "Retrovisor" })
	-- banco de trás com os brinquedos das três crianças
	cc:bloco(cf * CF(-1.8, 2.75, 0), V3(1.4, 0.5, 3.8), RGB(70, 60, 50), M.Fabric)
	cc:bloco(cf * CF(-2.5, 3.6, 0), V3(0.3, 1.5, 3.8), RGB(70, 60, 50), M.Fabric)
	Moveis.ursinho(cc, (cf * CF(-1.8, 3.0, 1.2)).Position, V3(1, 0, 0))
	Moveis.boneca(cc, (cf * CF(-1.8, 3.0, 0)).Position, V3(1, 0, 0))
	local carrinho = cf * CF(-1.8, 3.15, -1.2)
	cc:bloco(carrinho, V3(0.9, 0.3, 0.45), RGB(170, 30, 30), M.SmoothPlastic)
	cc:bloco(carrinho * CF(0, 0.22, 0), V3(0.45, 0.2, 0.4), RGB(170, 30, 30), M.SmoothPlastic)
	for _, sx in { -0.3, 0.3 } do
		for _, sz in { -0.22, 0.22 } do
			cc:cilindro(carrinho * CF(sx, -0.15, sz) * CFrame.Angles(0, math.pi / 2, 0), 0.06, 0.2, RGB(20, 20, 22), M.SmoothPlastic)
		end
	end
	-- banco da frente (o avô dirige)
	cc:bloco(cf * CF(1.1, 2.75, -1.0), V3(1.4, 0.5, 1.6), RGB(70, 60, 50), M.Fabric)
	cc:cilindro(cf * CF(2.4, 3.4, -1.0) * CFrame.Angles(0, 0, math.rad(60)), 0.12, 1.1, RGB(30, 30, 32), M.SmoothPlastic)
	for id, pos in l.pontos or {} do
		ancora(c, id, pos)
	end
end

-- Monta o cenário (no cliente). Devolve o modelo e o layout.
function MissoesMapa.construir(nome: string, pai: Instance): (Model, any)
	local l = MissoesMapa.layout(nome)
	local modelo = Instance.new("Model")
	modelo.Name = "OI3_Cenario_" .. nome
	local c = Construtor.novo(modelo)
	CONSTRUIR[nome](c, l)
	Moveis.aplicarVariantes(modelo)
	modelo.Parent = pai
	return modelo, l
end

MissoesMapa.CENARIOS = { "quarto", "festa", "lavanderia", "espelhos", "quarto_trancado", "escritorio", "cadeiras", "porao", "rua" }

return MissoesMapa
