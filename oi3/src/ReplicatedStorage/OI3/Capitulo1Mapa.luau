-- OI3 :: objetos do começo do Capítulo 1 (AJUSTE-6): a mesa de jantar e os 5 detalhes estranhos.
-- Os nomes "OI3_*" são os pontos de interação que o cliente usa (Cliente/Capitulo1).
-- Nada aqui explica o mistério: são só coisas estranhas para o jogador reparar.

local Construtor = require(script.Parent.Construtor)
local Moveis = require(script.Parent.Moveis)

local Capitulo1Mapa = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local M = Enum.Material
local COR = Moveis.COR

local function ancora(c, nome: string, pos: Vector3, tamanho: Vector3?)
	return c:caixa(pos, tamanho or V3(1.2, 1.2, 1.2), RGB(0, 0, 0), M.SmoothPlastic, { Name = nome, Transparency = 1, colisao = false, CanQuery = true })
end

-- foto antiga desenhada (um prop): o grupo do orfanato, e o rosto de uma das crianças rabiscado
function Capitulo1Mapa.desenharFoto(pai: Instance)
	local fundo = Instance.new("Frame")
	fundo.Name = "Foto"
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BackgroundColor3 = RGB(176, 150, 112)
	fundo.BorderSizePixel = 0
	fundo.Parent = pai
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(RGB(214, 192, 150), RGB(140, 112, 80))
	grad.Rotation = 70
	grad.Parent = fundo
	local function forma(pos: UDim2, tam: UDim2, cor: Color3, redondo: boolean?, rot: number?)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = pos
		f.Size = tam
		f.BackgroundColor3 = cor
		f.BorderSizePixel = 0
		f.Rotation = rot or 0
		if redondo then
			local u = Instance.new("UICorner")
			u.CornerRadius = UDim.new(1, 0)
			u.Parent = f
		end
		f.Parent = fundo
		return f
	end
	local sombra = RGB(70, 52, 38)
	-- a casa ao fundo
	forma(UDim2.fromScale(0.5, 0.2), UDim2.fromScale(0.9, 0.28), RGB(120, 96, 70))
	-- o adulto à esquerda
	forma(UDim2.fromScale(0.15, 0.56), UDim2.fromScale(0.13, 0.4), sombra)
	forma(UDim2.fromScale(0.15, 0.32), UDim2.fromScale(0.09, 0.12), sombra, true)
	-- quatro crianças
	for i, x in { 0.36, 0.52, 0.68, 0.84 } do
		forma(UDim2.fromScale(x, 0.7), UDim2.fromScale(0.1, 0.26), sombra)
		forma(UDim2.fromScale(x, 0.52), UDim2.fromScale(0.08, 0.11), sombra, true)
		if i == 4 then
			-- rosto rabiscado
			for k = 1, 9 do
				forma(UDim2.fromScale(x + (k % 3 - 1) * 0.012, 0.52 + (k - 5) * 0.008), UDim2.fromScale(0.12, 0.012), RGB(14, 10, 8), false, (k * 37) % 160 - 80)
			end
		end
	end
	-- moldura interna
	local borda = Instance.new("UIStroke")
	borda.Thickness = 3
	borda.Color = RGB(236, 226, 204)
	borda.Parent = fundo
	return fundo
end

function Capitulo1Mapa.construir(pai: Instance, L: any)
	local F = L.F
	local Z0 = -24
	local modelo = Instance.new("Model")
	modelo.Name = "Capitulo1"
	modelo.Parent = pai
	local c = Construtor.novo(modelo)

	-- mesa de jantar no hall, embaixo do lustre
	c:entre(V3(-1.7, F + 2.45, -1.6), V3(1.7, F + 2.7, 5.6), COR.madeira, M.Wood, { Name = "OI3_MesaJantar", colisao = true })
	c:entre(V3(-1.85, F + 2.7, -1.75), V3(1.85, F + 2.74, 5.75), RGB(214, 206, 190), M.Fabric)
	for _, sx in { -1.45, 1.45 } do
		for _, z in { -1.35, 5.35 } do
			c:coluna(V3(sx, F, z), 2.45, 0.28, COR.madeiraEscura, M.Wood)
		end
	end
	for _, z in { -0.2, 2, 4.2 } do
		Moveis.cadeira(c, V3(-2.55, F, z), V3(1, 0, 0))
		Moveis.cadeira(c, V3(2.55, F, z), V3(-1, 0, 0))
		for _, sx in { -1, 1 } do
			c:cilindro(CF(sx * 1.05, F + 2.77, z) * CFrame.Angles(0, 0, math.pi / 2), 0.05, 0.9, RGB(232, 228, 218), M.SmoothPlastic)
			c:cilindro(CF(sx * 1.35, F + 2.95, z + 0.55) * CFrame.Angles(0, 0, math.pi / 2), 0.36, 0.22, RGB(196, 206, 214), M.Glass)
		end
	end
	-- panela de sopa e pão
	c:cilindro(CF(0, F + 3.05, 2) * CFrame.Angles(0, 0, math.pi / 2), 0.6, 1.1, RGB(58, 56, 60), M.Metal)
	c:cilindro(CF(0, F + 3.38, 2) * CFrame.Angles(0, 0, math.pi / 2), 0.08, 1.16, RGB(70, 68, 72), M.Metal)
	c:caixa(V3(0, F + 2.9, 4.6), V3(0.7, 0.32, 1.1), RGB(176, 126, 70), M.SmoothPlastic)
	Moveis.vela(c, V3(0, F + 2.74, 0.4), { altura = 0.55 })
	Moveis.vela(c, V3(0, F + 2.74, 3.6), { altura = 0.5 })

	-- 1) a foto (mesinha lateral do hall)
	local foto = c:caixa(V3(8.75, F + 3.05, 6.55), V3(0.1, 0.8, 1.0), RGB(60, 40, 28), M.Wood, { Name = "OI3_Foto" })
	foto.CFrame = CF(8.75, F + 3.05, 6.55) * CFrame.Angles(0, 0, math.rad(-8))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Left
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 160
	sg.LightInfluence = 1
	sg.Parent = foto
	Capitulo1Mapa.desenharFoto(sg)

	-- 2) o quarto sempre trancado (porta do corredor)
	ancora(c, "OI3_PortaTrancada", V3(29, F + 3.9, -3.05), V3(3, 6, 0.6))

	-- 3) a TV que liga sozinha (canto do hall)
	c:entre(V3(-10.6, F, -22.8), V3(-7.4, F + 1.9, -21.0), COR.madeiraEscura, M.Wood, { colisao = true })
	c:caixa(V3(-9, F + 2.95, -21.95), V3(2.6, 2.1, 1.8), RGB(52, 46, 40), M.Wood, { Name = "OI3_TV", colisao = true })
	c:caixa(V3(-9.25, F + 3.0, -21.02), V3(1.85, 1.5, 0.06), RGB(18, 22, 20), M.Glass, { Name = "OI3_TVTela" })
	for _, y in { 3.4, 2.75 } do
		c:cilindro(CF(-8.0, F + y, -21.0) * CFrame.Angles(0, math.pi / 2, 0), 0.08, 0.22, RGB(170, 160, 140), M.Metal)
	end
	for _, s in { -1, 1 } do
		c:bloco(CF(-9 + s * 0.35, F + 4.5, -22.1) * CFrame.Angles(0, 0, math.rad(s * -24)), V3(0.05, 1.4, 0.05), RGB(150, 150, 156), M.Metal)
	end
	-- o fio solto, desligado da tomada
	c:bloco(CF(-10.9, F + 0.04, -21.7) * CFrame.Angles(0, math.rad(30), 0), V3(1.6, 0.05, 0.05), RGB(20, 20, 22), M.SmoothPlastic)

	-- 4) três brinquedos iguais numa caixa (dormitório)
	c:entre(V3(-35.3, F, -5.3), V3(-33.4, F + 1.2, -2.7), COR.madeiraClara, M.Wood, { Name = "OI3_CaixaBrinquedos", colisao = true })
	c:bloco(CF(-35.1, F + 1.75, -4.0) * CFrame.Angles(0, 0, math.rad(-16)), V3(0.12, 1.2, 2.6), COR.madeiraClara, M.Wood)
	for i, z in { -4.7, -4.0, -3.3 } do
		local base = V3(-34.35, F + 1.25, z)
		c:bola(base + V3(0, 0.22, 0), 0.62, RGB(150, 104, 62), M.Fabric)
		c:bola(base + V3(0, 0.66, 0), 0.48, RGB(150, 104, 62), M.Fabric)
		c:bola(base + V3(0, 0.88, -0.17), 0.17, RGB(150, 104, 62), M.Fabric)
		c:bola(base + V3(0, 0.88, 0.17), 0.17, RGB(150, 104, 62), M.Fabric)
		c:bola(base + V3(0.22, 0.68, -0.08), 0.06, RGB(12, 10, 10), M.SmoothPlastic)
		c:bola(base + V3(0.22, 0.68, 0.08), 0.06, RGB(12, 10, 10), M.SmoothPlastic)
		c:caixa(base + V3(0.27, 0.42, 0), V3(0.04, 0.08, 0.32), RGB(140, 30, 34), M.Fabric)
		if i == 2 then
			c:caixa(base + V3(0.3, 0.55, 0), V3(0.03, 0.04, 0.12), RGB(24, 20, 20), M.SmoothPlastic)
		end
	end

	-- 5) a porta do porão (o Vô nunca deixa abrir): correntes e cadeado
	Moveis.portaFechada(c, V3(8, F, Z0 + 0.62), V3(0, 0, 1), RGB(54, 40, 32))
	for _, a in { 28, -28 } do
		c:bloco(CF(8, F + 3.7, Z0 + 0.98) * CFrame.Angles(0, 0, math.rad(a)), V3(4.2, 0.12, 0.08), RGB(88, 86, 82), M.Metal)
	end
	c:caixa(V3(8, F + 3.7, Z0 + 1.05), V3(0.42, 0.5, 0.16), RGB(120, 96, 50), M.Metal)
	ancora(c, "OI3_PortaPorao", V3(8, F + 3.9, Z0 + 1.2), V3(3.4, 6, 0.6))
	return modelo
end

return Capitulo1Mapa
