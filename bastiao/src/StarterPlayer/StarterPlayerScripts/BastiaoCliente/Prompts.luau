--!strict
-- PROJETO BASTIÃO :: prompts de interação no estilo da bodycam (cliente)
-- Os ProximityPrompts da história usam Style = Custom; este módulo desenha a tecla e a ação
-- presas ao objeto, com barra de segurar quando a interação pede. No celular a etiqueta
-- inteira é o botão (segurar = segurar o dedo). O servidor valida tudo de novo.

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Prompts = {}

local WHITE = Color3.fromRGB(238, 238, 232)
local AMBER = Color3.fromRGB(244, 186, 88)
local BLACK = Color3.new(0, 0, 0)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local TAMANHO = 16
local AVANCO = 0.6

local function borda(pai: Instance, cor: Color3, transparencia: number, modo: Enum.ApplyStrokeMode)
	local s = Instance.new("UIStroke")
	s.Color = cor
	s.Thickness = 1
	s.Transparency = transparencia
	s.ApplyStrokeMode = modo
	s.Parent = pai
end

local function tecla(prompt: ProximityPrompt, tipo: Enum.ProximityPromptInputType): (string, string?)
	if tipo == Enum.ProximityPromptInputType.Touch then
		return "TOQUE", nil
	elseif tipo == Enum.ProximityPromptInputType.Gamepad then
		local ok, img = pcall(function()
			return UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		end)
		if ok and type(img) == "string" and img ~= "" then
			return "", img
		end
		return "X", nil
	end
	local ok, s = pcall(function()
		return UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	end)
	if ok and type(s) == "string" and s ~= "" then
		return string.upper(s), nil
	end
	return prompt.KeyboardKeyCode.Name, nil
end

function Prompts.iniciar(playerGui: Instance)
	local ativos: { [ProximityPrompt]: { gui: BillboardGui, conexoes: { RBXScriptConnection } } } = {}

	local function remover(prompt: ProximityPrompt)
		local a = ativos[prompt]
		if not a then
			return
		end
		ativos[prompt] = nil
		for _, c in a.conexoes do
			c:Disconnect()
		end
		a.gui:Destroy()
	end

	local function criar(prompt: ProximityPrompt, tipo: Enum.ProximityPromptInputType)
		remover(prompt)
		local parte = prompt.Parent
		if not parte or not parte:IsA("BasePart") then
			return
		end
		local textoTecla, imagem = tecla(prompt, tipo)
		local acao = prompt.ActionText
		local larguraAcao = math.ceil((utf8.len(acao) or #acao) * TAMANHO * AVANCO) + 4
		local larguraTecla = if imagem then 34 else math.max(34, math.ceil((utf8.len(textoTecla) or 1) * 13 * AVANCO) + 16)
		local largura = larguraTecla + 10 + larguraAcao

		local gui = Instance.new("BillboardGui")
		gui.Name = "BastiaoPrompt"
		gui.Adornee = parte
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.Size = UDim2.fromOffset(largura + 16, 48)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 1.0, 0)
		gui.Active = true
		gui.Parent = playerGui

		local caixaTecla = Instance.new("Frame")
		caixaTecla.Name = "Tecla"
		caixaTecla.AnchorPoint = Vector2.new(0, 0.5)
		caixaTecla.Position = UDim2.new(0, 8, 0.5, 0)
		caixaTecla.Size = UDim2.fromOffset(larguraTecla, 30)
		caixaTecla.BackgroundColor3 = BLACK
		caixaTecla.BackgroundTransparency = 0.45
		caixaTecla.BorderSizePixel = 0
		caixaTecla.Parent = gui
		local canto = Instance.new("UICorner")
		canto.CornerRadius = UDim.new(0, 4)
		canto.Parent = caixaTecla
		borda(caixaTecla, WHITE, 0.55, Enum.ApplyStrokeMode.Border)
		if imagem then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(0.8, 0.8)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Image = imagem
			img.Parent = caixaTecla
		else
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.FontFace = MONO
			t.TextSize = if #textoTecla > 2 then 12 else 15
			t.TextColor3 = WHITE
			t.Text = textoTecla
			t.Parent = caixaTecla
		end

		local rotulo = Instance.new("TextLabel")
		rotulo.Name = "Acao"
		rotulo.BackgroundTransparency = 1
		rotulo.AnchorPoint = Vector2.new(0, 0.5)
		rotulo.Position = UDim2.new(0, 8 + larguraTecla + 10, 0.5, -1)
		rotulo.Size = UDim2.fromOffset(larguraAcao, 22)
		rotulo.FontFace = MONO
		rotulo.TextSize = TAMANHO
		rotulo.TextColor3 = WHITE
		rotulo.TextXAlignment = Enum.TextXAlignment.Left
		rotulo.Text = acao
		borda(rotulo, BLACK, 0.3, Enum.ApplyStrokeMode.Contextual)
		rotulo.Parent = gui

		local barra = Instance.new("Frame")
		barra.Name = "Segurar"
		barra.BackgroundColor3 = WHITE
		barra.BorderSizePixel = 0
		barra.Position = UDim2.new(0, 8 + larguraTecla + 10, 0.5, 12)
		barra.Size = UDim2.fromOffset(0, 2)
		barra.Visible = prompt.HoldDuration > 0
		barra.Parent = gui

		local conexoes = {}
		local tweenBarra: Tween? = nil
		table.insert(
			conexoes,
			prompt.PromptButtonHoldBegan:Connect(function()
				if tweenBarra then
					tweenBarra:Cancel()
				end
				barra.Size = UDim2.fromOffset(0, 2)
				tweenBarra = TweenService:Create(barra, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(larguraAcao, 2) })
				tweenBarra:Play()
			end)
		)
		table.insert(
			conexoes,
			prompt.PromptButtonHoldEnded:Connect(function()
				if tweenBarra then
					tweenBarra:Cancel()
				end
				barra.Size = UDim2.fromOffset(0, 2)
			end)
		)
		table.insert(
			conexoes,
			prompt.Triggered:Connect(function()
				rotulo.TextColor3 = AMBER
				task.delay(0.35, function()
					if rotulo.Parent then
						rotulo.TextColor3 = WHITE
					end
				end)
			end)
		)

		-- celular: a etiqueta inteira é o botão
		if tipo == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
			local botao = Instance.new("TextButton")
			botao.Name = "Toque"
			botao.BackgroundTransparency = 1
			botao.Text = ""
			botao.AutoButtonColor = false
			botao.Size = UDim2.fromScale(1, 1)
			botao.Parent = gui
			table.insert(
				conexoes,
				botao.InputBegan:Connect(function(entrada: InputObject)
					if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
						prompt:InputHoldBegin()
					end
				end)
			)
			table.insert(
				conexoes,
				botao.InputEnded:Connect(function(entrada: InputObject)
					if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
						prompt:InputHoldEnd()
					end
				end)
			)
		end
		ativos[prompt] = { gui = gui, conexoes = conexoes }
	end

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, tipo: Enum.ProximityPromptInputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom and prompt:GetAttribute("Bastiao") == true then
			criar(prompt, tipo)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(remover)
end

return Prompts
