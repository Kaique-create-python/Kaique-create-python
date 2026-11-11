--!strict
-- Tema visual e utilitários de interface (criação declarativa, animações).

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	bg = Color3.fromRGB(16, 18, 28),
	bg2 = Color3.fromRGB(26, 29, 44),
	panel = Color3.fromRGB(22, 24, 38),
	stroke = Color3.fromRGB(70, 80, 120),
	text = Color3.fromRGB(240, 244, 255),
	muted = Color3.fromRGB(160, 170, 200),
	accent = Color3.fromRGB(90, 210, 255),
	accent2 = Color3.fromRGB(180, 110, 255),
	good = Color3.fromRGB(110, 235, 150),
	warn = Color3.fromRGB(255, 200, 90),
	bad = Color3.fromRGB(255, 100, 100),
	gold = Color3.fromRGB(255, 210, 80),
}

Theme.Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Theme.FontBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Theme.FontHeavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

-- cria instância com propriedades e filhos
function Theme.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.corner(radius: number?): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.stroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(px: number): UIPadding
	return Theme.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function Theme.gradient(a: Color3, b: Color3, rotation: number?): UIGradient
	return Theme.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 0 })
end

function Theme.label(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.text,
		FontFace = Theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for k, v in props do
		p[k] = v
	end
	return Theme.new("TextLabel", p)
end

function Theme.button(props: { [string]: any }): TextButton
	local p = {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.bg2,
		TextColor3 = Theme.Colors.text,
		FontFace = Theme.FontBold,
		TextSize = 16,
	}
	for k, v in props do
		p[k] = v
	end
	local b = Theme.new("TextButton", p, { Theme.corner(10) })
	local base = b.BackgroundColor3
	-- volume: luz em cima, sombra embaixo, contorno suave
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215))
	grad.Parent = b
	if not b:FindFirstChildOfClass("UIStroke") then
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Color = Color3.new(1, 1, 1)
		st.Transparency = 0.82
		st.Thickness = 1
		st.Parent = b
	end
	local scale = Instance.new("UIScale")
	scale.Name = "Aperto"
	scale.Parent = b
	b.MouseEnter:Connect(function()
		Theme.tween(b, 0.12, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.1) })
		Theme.tween(scale, 0.15, { Scale = 1.04 })
	end)
	b.MouseLeave:Connect(function()
		Theme.tween(b, 0.12, { BackgroundColor3 = base })
		Theme.tween(scale, 0.15, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		Theme.tween(b, 0.06, { BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.15) })
		Theme.tween(scale, 0.07, { Scale = 0.9 })
	end)
	b.MouseButton1Up:Connect(function()
		Theme.tween(b, 0.1, { BackgroundColor3 = base })
		Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.Activated:Connect(function()
		Theme.clickPop(b)
		if Theme.onClick then
			Theme.onClick()
		end
	end)
	return b
end

-- definido pela HUD: toca o som de clique em todos os botões
Theme.onClick = nil :: (() -> ())?

local Config = require(game:GetService("ReplicatedStorage").IdeiasShared.Config)

-- A instância pode existir antes do download. Troca a alternativa pela arte
-- somente quando carregou, sem bloquear a construção da interface.
function Theme.imageFallback(img: ImageLabel, onLoaded: ((boolean) -> ())?)
	local active = true
	local changed: RBXScriptConnection? = nil
	local destroying: RBXScriptConnection? = nil
	local function update()
		if not active then
			return
		end
		local loaded = img.IsLoaded
		img.Visible = loaded
		if onLoaded then
			onLoaded(loaded)
		end
	end
	changed = img:GetPropertyChangedSignal("IsLoaded"):Connect(update)
	destroying = img.Destroying:Connect(function()
		active = false
		onLoaded = nil
		if changed then
			changed:Disconnect()
		end
		if destroying then
			destroying:Disconnect()
		end
	end)
	update()
end

-- Ícone recortado da folha do Canva. Sem ID/célula devolve nil; o retorno
-- indica a instância, e onLoaded informa se a arte já pode substituir o emoji.
function Theme.icon(name: string, size: number, parent: Instance, onLoaded: ((boolean) -> ())?): ImageLabel?
	local id = Config.UiImages and Config.UiImages.Icons or 0
	local cell = Config.IconSheet.Cells[name]
	if id == 0 or cell == nil then
		return nil
	end
	local c = Config.IconSheet.Cell
	local col = cell % Config.IconSheet.Columns
	local row = cell // Config.IconSheet.Columns
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Visible = false
	img.Image = "rbxassetid://" .. tostring(id)
	img.ImageRectOffset = Vector2.new(col * c, row * c)
	img.ImageRectSize = Vector2.new(c, c)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromOffset(size, size)
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = (parent :: any).ZIndex + 1
	img.Parent = parent
	Theme.imageFallback(img, onLoaded)
	return img
end

-- Estilo da referência: contorno quase preto, texto branco grosso com borda preta
Theme.Ink = Color3.fromRGB(27, 18, 14)

function Theme.outlined(label: GuiObject, thickness: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Color = Color3.new(0, 0, 0)
	st.Thickness = thickness or 2
	st.Parent = label
	return st
end

-- cores dos azulejos (as mesmas da folha de ícones desenhada à mão)
Theme.TileColors = {
	ideias = Color3.fromRGB(247, 179, 43),
	favoritos = Color3.fromRGB(236, 79, 122),
	historico = Color3.fromRGB(76, 141, 240),
	progresso = Color3.fromRGB(242, 138, 34),
	loja = Color3.fromRGB(163, 93, 224),
	ajustes = Color3.fromRGB(111, 125, 153),
	creature = Color3.fromRGB(66, 185, 91),
	disaster = Color3.fromRGB(229, 72, 58),
	vehicle = Color3.fromRGB(34, 183, 199),
	building = Color3.fromRGB(124, 108, 240),
	food = Color3.fromRGB(140, 198, 63),
	power = Color3.fromRGB(210, 76, 217),
}

-- A alternativa (cor + contorno escuro + emoji) aparece também enquanto a
-- folha carrega ou permanece indisponível; a arte pronta a substitui.
function Theme.tile(name: string, emoji: string, size: number, parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Azulejo"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	local face = Instance.new("Frame")
	face.BackgroundColor3 = Theme.TileColors[name] or Theme.Colors.bg2
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = face
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Theme.Ink
	st.Thickness = 3
	st.Parent = face
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185))
	grad.Parent = face
	local e = Instance.new("TextLabel")
	e.BackgroundTransparency = 1
	e.Size = UDim2.fromScale(1, 1)
	e.Text = emoji
	e.TextScaled = true
	e.FontFace = Theme.FontBold
	e.TextColor3 = Color3.new(1, 1, 1)
	e.Parent = face
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.16, 0)
	pad.PaddingRight = UDim.new(0.16, 0)
	pad.PaddingTop = UDim.new(0.16, 0)
	pad.PaddingBottom = UDim.new(0.16, 0)
	pad.Parent = e
	Theme.icon(name, size, holder, function(loaded)
		face.Visible = not loaded
	end)
	return holder
end

-- aperto com "pulo" (Back), anel de luz no alvo e som de clique
function Theme.pressable(b: GuiButton, popTarget: GuiObject?)
	local scale = Instance.new("UIScale")
	scale.Name = "Aperto"
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.07, { Scale = 0.9 })
	end)
	b.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.MouseLeave:Connect(function()
		Theme.tween(scale, 0.15, { Scale = 1 })
	end)
	b.Activated:Connect(function()
		Theme.clickPop(popTarget or b)
		if Theme.onClick then
			Theme.onClick()
		end
	end)
end

-- anel de luz que cresce e some a partir do botão apertado
function Theme.clickPop(b: GuiObject)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.9, 0.9)
	ring.BackgroundTransparency = 1
	ring.ZIndex = b.ZIndex + 3
	ring.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(150, 240, 255)
	st.Thickness = 3
	st.Transparency = 0
	st.Parent = ring
	Theme.tween(ring, 0.4, { Size = UDim2.fromScale(1.6, 1.6) })
	Theme.tween(st, 0.4, { Transparency = 1, Thickness = 0.5 })
	game:GetService("Debris"):AddItem(ring, 0.45)
end

function Theme.tween(inst: Instance, t: number, goals: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goals)
	tw:Play()
	return tw
end

-- "pulo" curto de escala para dar retorno ao toque
function Theme.pop(inst: GuiObject)
	local scale = inst:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = inst })
	scale.Scale = 0.92
	Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Theme.shake(inst: GuiObject)
	local origin = inst.Position
	task.spawn(function()
		for i = 1, 6 do
			inst.Position = origin + UDim2.fromOffset(if i % 2 == 0 then 6 else -6, 0)
			task.wait(0.03)
		end
		inst.Position = origin
	end)
end

return Theme
