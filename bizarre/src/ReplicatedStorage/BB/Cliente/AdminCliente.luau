-- BIZARRE BATTLEGROUNDS :: painel ADM (só aparece para ADM; o servidor confere tudo)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local BB = script.Parent.Parent
local Stands = require(BB:WaitForChild("Stands"))
local UI = require(script.Parent:WaitForChild("Interface"))
local Som = require(script.Parent:WaitForChild("Som"))

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
	abrir.MouseButton1Click:Connect(function()
		painel.Visible = not painel.Visible
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
