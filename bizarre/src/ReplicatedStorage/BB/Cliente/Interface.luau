-- BIZARRE BATTLEGROUNDS :: peças de interface reaproveitadas (botões, cantos, textos com contorno)

local TweenService = game:GetService("TweenService")

local UI = {}

UI.FONTE = Enum.Font.Bangers
UI.FONTE_TEXTO = Enum.Font.GothamBold
UI.CORES = {
	fundo = Color3.fromRGB(16, 12, 28),
	fundo2 = Color3.fromRGB(34, 24, 58),
	roxo = Color3.fromRGB(150, 70, 230),
	dourado = Color3.fromRGB(255, 206, 64),
	rosa = Color3.fromRGB(255, 90, 170),
	branco = Color3.fromRGB(255, 255, 255),
	vermelho = Color3.fromRGB(230, 50, 60),
	verde = Color3.fromRGB(70, 220, 120),
	azul = Color3.fromRGB(90, 170, 255),
}

function UI.canto(pai: Instance, raio: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, raio or 10)
	c.Parent = pai
	return c
end

function UI.circulo(pai: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = pai
	return c
end

function UI.borda(pai: Instance, cor: Color3?, espessura: number?, transp: number?)
	local s = Instance.new("UIStroke")
	s.Color = cor or Color3.fromRGB(0, 0, 0)
	s.Thickness = espessura or 2
	s.Transparency = transp or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = pai
	return s
end

function UI.gradiente(pai: Instance, a: Color3, b: Color3, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = pai
	return g
end

function UI.frame(pai: Instance, tam: UDim2, pos: UDim2, cor: Color3?, transp: number?): Frame
	local f = Instance.new("Frame")
	f.Size = tam
	f.Position = pos
	f.BackgroundColor3 = cor or UI.CORES.fundo
	f.BackgroundTransparency = transp or 0
	f.BorderSizePixel = 0
	f.Parent = pai
	return f
end

function UI.texto(pai: Instance, texto: string, tam: UDim2, pos: UDim2, opcoes: any?): TextLabel
	local o = opcoes or {}
	local t = Instance.new("TextLabel")
	t.Size = tam
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Text = texto
	t.Font = o.fonte or UI.FONTE
	t.TextColor3 = o.cor or UI.CORES.branco
	t.TextScaled = o.escalado ~= false
	t.TextSize = o.tamanho or 18
	t.TextXAlignment = o.alinhar or Enum.TextXAlignment.Center
	t.TextYAlignment = o.alinharY or Enum.TextYAlignment.Center
	t.TextWrapped = o.quebrar == true
	t.RichText = o.rico == true
	t.ZIndex = o.z or 1
	if o.contorno ~= false then
		local s = Instance.new("UIStroke")
		s.Thickness = o.contornoEsp or 1.6
		s.Color = o.contornoCor or Color3.fromRGB(10, 6, 20)
		s.Parent = t
	end
	if o.limite then
		local lim = Instance.new("UITextSizeConstraint")
		lim.MaxTextSize = o.limite
		lim.Parent = t
	end
	t.Parent = pai
	return t
end

-- botão com pulinho ao tocar
function UI.botao(pai: Instance, texto: string, tam: UDim2, pos: UDim2, cor: Color3?, opcoes: any?): TextButton
	local o = opcoes or {}
	local b = Instance.new("TextButton")
	b.Size = tam
	b.Position = pos
	b.AnchorPoint = o.ancora or Vector2.new(0, 0)
	b.BackgroundColor3 = cor or UI.CORES.roxo
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = o.z or 2
	b.Parent = pai
	if o.redondo then
		UI.circulo(b)
	else
		UI.canto(b, o.raio or 12)
	end
	UI.borda(b, o.borda or Color3.fromRGB(10, 6, 20), o.bordaEsp or 2.5)
	UI.gradiente(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190), 90)
	local t = UI.texto(b, texto, UDim2.fromScale(0.86, 0.7), UDim2.fromScale(0.07, 0.15), { cor = o.corTexto, z = (o.z or 2) + 1, limite = o.limite or 34 })
	t.Name = "Rotulo"
	local escala = Instance.new("UIScale")
	escala.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
	end)
	local function soltar()
		TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(soltar)
	b.MouseLeave:Connect(soltar)
	return b
end

function UI.escalaTela(gui: ScreenGui, larguraBase: number, alturaBase: number, minimo: number?, maximo: number?): UIScale
	local esc = Instance.new("UIScale")
	esc.Parent = gui
	local function atualizar()
		local tam = gui.AbsoluteSize
		if tam.X < 10 then
			return
		end
		esc.Scale = math.clamp(math.min(tam.X / larguraBase, tam.Y / alturaBase), minimo or 0.55, maximo or 1.3)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(atualizar)
	atualizar()
	return esc
end

return UI
