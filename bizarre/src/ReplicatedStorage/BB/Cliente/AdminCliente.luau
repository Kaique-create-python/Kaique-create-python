-- BIZARRE BATTLEGROUNDS :: painel ADM (só aparece para ADM; o servidor confere tudo)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local BB = script.Parent.Parent
local Stands = require(BB:WaitForChild("Stands"))
local UI = require(script.Parent:WaitForChild("Interface"))
local Animador = require(script.Parent:WaitForChild("Animador"))
local Som = require(script.Parent:WaitForChild("Som"))
local PreviaVFX14 = require(script.Parent:WaitForChild("PreviaVFX14"))

local AdminCliente = {}

local plr = Players.LocalPlayer
local remoto: RemoteEvent
local gui: ScreenGui
local painel: Frame
local resposta: TextLabel
local estado = { semRecarga = false, imortal = false }

local function enviar(nome: string, args: any?)
	remoto:FireServer(nome, args or {})
	Som.tocar("ui_clique", nil)
end

local function criar()
	gui = Instance.new("ScreenGui")
	gui.Name = "BB_Admin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = plr:WaitForChild("PlayerGui")
	UI.escalaTela(gui, 1100, 600, 0.55, 1.1)
	local abrir = UI.botao(gui, "ADM", UDim2.fromOffset(64, 34), UDim2.new(1, -78, 0, 8), UI.CORES.vermelho, { limite = 20 })
	painel = UI.frame(gui, UDim2.fromOffset(470, 380), UDim2.new(1, -484, 0, 48), UI.CORES.fundo, 0.05)
	UI.canto(painel, 14)
	UI.borda(painel, UI.CORES.vermelho, 2)
	painel.Visible = false
	UI.texto(painel, "PAINEL ADM", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 6), { cor = UI.CORES.vermelho })
	resposta = UI.texto(painel, "", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 1, -32), { fonte = UI.FONTE_TEXTO, limite = 15 })
	local botoes = {
		{ "BOT FÁCIL", function()
			enviar("bot", { dificuldade = "facil" })
		end },
		{ "BOT MÉDIO", function()
			enviar("bot", { dificuldade = "medio" })
		end },
		{ "BOT DIFÍCIL", function()
			enviar("bot", { dificuldade = "dificil" })
		end },
		{ "LIMPAR BOTS", function()
			enviar("limparBots")
		end },
		{ "CURAR", function()
			enviar("curar")
		end },
		{ "DESPERTAR", function()
			enviar("despertar")
		end },
		{ "SEM RECARGA", function()
			estado.semRecarga = not estado.semRecarga
			enviar("semRecarga", { ligar = estado.semRecarga })
		end },
		{ "IMORTAL", function()
			estado.imortal = not estado.imortal
			enviar("imortal", { ligar = estado.imortal })
		end },
		{ "RESTAURAR MAPA", function()
			enviar("restaurarMapa")
		end },
		{ "QUEBRAR TUDO", function()
			enviar("quebrarTudo")
		end },
		{ "DERRUBAR BOTS", function()
			enviar("matarBots")
		end },
		{ "INFO", function()
			enviar("info")
		end },
	}
	for i, b in botoes do
		local col = (i - 1) % 3
		local lin = math.floor((i - 1) / 3)
		local bt = UI.botao(painel, b[1], UDim2.fromOffset(144, 46), UDim2.fromOffset(12 + col * 152, 46 + lin * 54), Color3.fromRGB(90, 50, 140), { limite = 18 })
		bt.MouseButton1Click:Connect(b[2])
	end
	-- trocar de Stand na hora (mesmo em combate)
	for i, id in Stands.ORDEM do
		local s = Stands.get(id)
		local bt = UI.botao(painel, s.nome, UDim2.fromOffset(72, 30), UDim2.fromOffset(12 + (i - 1) * 76, 266), s.cor, { limite = 13 })
		bt.MouseButton1Click:Connect(function()
			enviar("stand", { id = id })
		end)
	end
 local selecionados={"SILVER_CHARIOT","MAGICIANS_RED","STAR_PLATINUM","THE_WORLD"}
 local indice=1
 local previa = UI.botao(painel, "PRÉVIA VFX", UDim2.fromOffset(144,30), UDim2.fromOffset(12,310), Color3.fromRGB(90,50,140), {limite=16})
 local selecionar=UI.botao(painel,"Silver Chariot",UDim2.fromOffset(144,30),UDim2.fromOffset(164,310),Color3.fromRGB(60,80,110),{limite=14})
 local parar=UI.botao(painel,"PARAR",UDim2.fromOffset(144,30),UDim2.fromOffset(316,310),Color3.fromRGB(110,50,60),{limite=16})
 selecionar.MouseButton1Click:Connect(function()
  PreviaVFX14.cancelar();indice=indice%#selecionados+1;selecionar.Text=Stands.get(selecionados[indice]).nome
 end)
 parar.MouseButton1Click:Connect(function()PreviaVFX14.cancelar();resposta.Text="Prévia encerrada"end)
 previa.MouseButton1Click:Connect(function()
  local h=PreviaVFX14.tocar(plr.Character,selecionados[indice])
  resposta.Text=if h then "Prévia local — "..Stands.get(selecionados[indice]).nome else "Catálogo VFX indisponível ou personagem ausente"
  resposta.TextColor3=if h then UI.CORES.verde else UI.CORES.vermelho
 end)

	abrir.MouseButton1Click:Connect(function()
		painel.Visible = not painel.Visible
	end)
	-- AJUSTE-11: DIAG = o que está acontecendo com a animação do seu personagem e com os VFX da loja
	local diagB = UI.botao(gui, "DIAG", UDim2.fromOffset(64, 34), UDim2.new(1, -150, 0, 8), Color3.fromRGB(60, 120, 200), { limite = 20 })
	-- AJUSTE-12: quadro maior e com rolagem (os nomes dos efeitos da loja não cabem numa tela só)
	local quadro = Instance.new("ScrollingFrame")
	quadro.Size = UDim2.fromOffset(600, 240)
	quadro.Position = UDim2.new(0.5, -300, 0, 50)
	quadro.BackgroundColor3 = UI.CORES.fundo
	quadro.BackgroundTransparency = 0.06
	quadro.BorderSizePixel = 0
	quadro.ScrollBarThickness = 8
	quadro.AutomaticCanvasSize = Enum.AutomaticSize.Y
	quadro.CanvasSize = UDim2.new()
	quadro.Parent = gui
	UI.canto(quadro, 12)
	UI.borda(quadro, Color3.fromRGB(60, 120, 200), 2)
	quadro.Visible = false
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.new(1, -24, 0, 0)
	txt.Position = UDim2.fromOffset(10, 8)
	txt.AutomaticSize = Enum.AutomaticSize.Y
	txt.Font = UI.FONTE_TEXTO
	txt.TextSize = 14
	txt.TextWrapped = true
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextYAlignment = Enum.TextYAlignment.Top
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.Text = ""
	txt.Parent = quadro
	diagB.MouseButton1Click:Connect(function()
		quadro.Visible = not quadro.Visible
		Som.tocar("ui_clique", nil)
		task.spawn(function()
			while quadro.Visible and quadro.Parent do
				local loja = game:GetService("ReplicatedStorage"):FindFirstChild("BB_VFXLoja")
				local textoLoja = if loja then tostring(loja:GetAttribute("Resumo") or "carregando...") .. "\n\nEFEITOS POR TIPO: " .. tostring(loja:GetAttribute("Nomes") or "...") else "o servidor ainda não carregou (ou é versão antiga)"
				txt.Text = "ANIMAÇÃO: " .. Animador.diagnostico(plr.Character) .. "\n\nVFX DA LOJA: " .. textoLoja
				task.wait(0.5)
			end
		end)
	end)
end

local function chat()
	local mapa = {
		["/bot"] = function()
			enviar("bot", {})
		end,
		["/limpar"] = function()
			enviar("limparBots")
		end,
		["/curar"] = function()
			enviar("curar")
		end,
		["/despertar"] = function()
			enviar("despertar")
		end,
		["/semcd"] = function()
			estado.semRecarga = not estado.semRecarga
			enviar("semRecarga", { ligar = estado.semRecarga })
		end,
		["/imortal"] = function()
			estado.imortal = not estado.imortal
			enviar("imortal", { ligar = estado.imortal })
		end,
		["/mapa"] = function()
			enviar("restaurarMapa")
		end,
		["/quebrar"] = function()
			enviar("quebrarTudo")
		end,
	}
	pcall(function()
		for texto, fn in mapa do
			local cmd = Instance.new("TextChatCommand")
			cmd.Name = "BB_" .. string.sub(texto, 2)
			cmd.PrimaryAlias = texto
			cmd.Triggered:Connect(function()
				fn()
			end)
			cmd.Parent = TextChatService
		end
	end)
end

function AdminCliente.iniciar(r: RemoteEvent)
	remoto = r
	r.OnClientEvent:Connect(function(tipo, d)
		if tipo == "msg" and resposta then
			resposta.Text = d.texto
			resposta.TextColor3 = if d.ok then UI.CORES.verde else UI.CORES.vermelho
		end
	end)
	local function talvez()
		if plr:GetAttribute("BB_Admin") and not gui then
			criar()
			chat()
		end
	end
	plr:GetAttributeChangedSignal("BB_Admin"):Connect(talvez)
	talvez()
end

return AdminCliente
