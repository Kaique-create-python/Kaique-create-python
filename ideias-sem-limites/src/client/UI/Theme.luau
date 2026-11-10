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
		if Theme.onClick then
			Theme.onClick()
		end
	end)
	return b
end

-- definido pela HUD: toca o som de clique em todos os botões
Theme.onClick = nil :: (() -> ())?

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
