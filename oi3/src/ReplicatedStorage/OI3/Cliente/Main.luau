-- OI3 :: cliente principal (menu 3D → abertura → exploração)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")

local OI3 = script.Parent.Parent
local Config = require(OI3.Config)
local Interface = require(script.Parent.Interface)
local Som = require(script.Parent.Som)
local Chamas = require(script.Parent.Chamas)
local Ajustes = require(script.Parent.Ajustes)
local Cinema = require(script.Parent.Cinema)
local MenuCena = require(script.Parent.MenuCena)
local Botoes3D = require(script.Parent.Botoes3D)
local Paineis = require(script.Parent.Paineis)
local Cutscene = require(script.Parent.Cutscene)
local Exploracao = require(script.Parent.Exploracao)

local Main = {}

local RGB = Color3.fromRGB

local estadoJogo = "carregando"
local remotos: any = nil
local grupo: any = nil
local rotuloVersao: TextLabel? = nil

local function coreGui(tipo: Enum.CoreGuiType, ligado: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(tipo, ligado)
	end)
end

local function esperarRemotos()
	local pasta = OI3:WaitForChild("Remotos", 60)
	assert(pasta, "[OI3] remotos não encontrados")
	local r = {}
	for _, nome in { "PedirDados", "SalvarConfig", "Entrar", "Lanterna", "IntroVista", "Sala" } do
		r[nome] = pasta:WaitForChild(nome, 30)
	end
	return r
end

local irParaMenu: (boolean) -> ()

local function entrarExploracao()
	estadoJogo = "explorar"
	local lp = Players.LocalPlayer
	remotos.Entrar:FireServer("explorar")
	local t0 = os.clock()
	local char = nil
	while os.clock() - t0 < 15 do
		char = lp.Character
		if char and char:FindFirstChildOfClass("Humanoid") and char.PrimaryPart then
			break
		end
		task.wait(0.1)
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	coreGui(Enum.CoreGuiType.Chat, true)
	Cinema.escurecer(0, 1.2)
	Exploracao.entrar()
end

local function jogar(params: { inicio: number? }?)
	if estadoJogo ~= "menu" then
		return
	end
	estadoJogo = "cutscene"
	Paineis.fechar(true)
	if grupo then
		grupo:habilitar(false)
		grupo:esconder()
	end
	if rotuloVersao then
		rotuloVersao.Visible = false
	end
	Som.tocar("whoosh", { volume = 0.8 })
	Som.pararAmbientes(1.2)
	MenuCena.mergulhar(1.3)
	Cinema.escurecer(1, 1.2)
	task.wait(1.35)
	MenuCena.esconder()
	coreGui(Enum.CoreGuiType.Chat, false)
	Cutscene.tocar({
		inicio = params and params.inicio,
		aoTerminar = function()
			remotos.IntroVista:FireServer()
			entrarExploracao()
		end,
	})
end

local function abrirPainel(nome: string)
	if estadoJogo ~= "menu" then
		return
	end
	if grupo then
		grupo:habilitar(false)
	end
	Paineis.abrir(nome)
end

local function voltarAoMenu()
	if estadoJogo ~= "explorar" then
		return
	end
	estadoJogo = "trocando"
	Cinema.escurecer(1, 0.6)
	task.wait(0.65)
	Exploracao.sair()
	remotos.Entrar:FireServer("menu")
	irParaMenu(false)
end

irParaMenu = function(primeira: boolean)
	estadoJogo = "menu"
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	coreGui(Enum.CoreGuiType.PlayerList, false)
	MenuCena.mostrar(function()
		Som.tocar("sussurro", { volume = 0.35 })
	end)
	if grupo then
		grupo:habilitar(true)
		grupo:mostrar(if primeira then 1.0 else 0.4)
	end
	Som.ambiente("drone", 0.7, 2)
	Som.ambiente("relogio", 0.3, 2)
	Cinema.escurecer(0, if primeira then 1.8 else 0.9)
	if rotuloVersao then
		rotuloVersao.Visible = true
	end
end

function Main.iniciar()
	local lp = Players.LocalPlayer
	coreGui(Enum.CoreGuiType.Backpack, false)
	coreGui(Enum.CoreGuiType.Health, false)
	coreGui(Enum.CoreGuiType.PlayerList, false)
	coreGui(Enum.CoreGuiType.EmotesMenu, false)

	Cinema.iniciar()
	Cinema.escurecer(1, 0)
	remotos = esperarRemotos()

	-- dados salvos
	local dados: any = { config = Config.PADRAO, viuIntro = false }
	local ok, resposta = pcall(function()
		return remotos.PedirDados:InvokeServer()
	end)
	if ok and type(resposta) == "table" then
		dados = resposta
	end
	Ajustes.iniciar(dados.config, function(cfg)
		remotos.SalvarConfig:FireServer(cfg)
	end)
	Som.iniciar(Ajustes.valores)
	Cinema.legendas(Ajustes.valores.legendas)
	Cutscene.configurar({ tremor = Ajustes.valores.tremor })
	Ajustes.aoMudar(function(chave, valor)
		if chave == "musica" or chave == "efeitos" or chave == "vozes" then
			Som.volumes(Ajustes.valores)
		elseif chave == "legendas" then
			Cinema.legendas(valor)
		elseif chave == "efeitosLeves" then
			Chamas.modoLeve(valor)
			MenuCena.modoLeve(valor)
		elseif chave == "tremor" then
			Cutscene.configurar({ tremor = valor })
		end
	end)

	-- chamas do orfanato e do menu
	Chamas.iniciar()
	local orfanato = workspace:WaitForChild("Orfanato", 30)
	if orfanato then
		Chamas.registrar(orfanato)
	end
	MenuCena.construir()
	local pastaMenu = MenuCena.pasta()
	if pastaMenu then
		Chamas.registrar(pastaMenu)
	end
	Chamas.modoLeve(Ajustes.valores.efeitosLeves)
	MenuCena.modoLeve(Ajustes.valores.efeitosLeves)

	-- botões 3D
	local corSec = RGB(54, 47, 62)
	grupo = Botoes3D.grupo(pastaMenu, {
		{ id = "jogar", texto = "JOGAR", cor = RGB(150, 30, 30), principal = true, aoClicar = function()
			task.spawn(jogar, nil)
		end },
		{ id = "multi", texto = "MULTIPLAYER", cor = corSec, aoClicar = function()
			abrirPainel("multi")
		end },
		{ id = "config", texto = "CONFIGURAÇÕES", cor = corSec, aoClicar = function()
			abrirPainel("config")
		end },
		{ id = "creditos", texto = "CRÉDITOS", cor = corSec, aoClicar = function()
			abrirPainel("creditos")
		end },
	})
	grupo.aoApertar = function()
		Som.tocar("clique", { volume = 0.9 })
	end
	MenuCena.definirBotoes(grupo)

	-- painéis e sala multiplayer
	local sala = {
		entrar = function()
			remotos.Sala:FireServer("entrar")
		end,
		sair = function()
			remotos.Sala:FireServer("sair")
		end,
		pronto = function(v: boolean)
			remotos.Sala:FireServer("pronto", v == true)
		end,
		convidar = function()
			local okC, pode = pcall(function()
				return SocialService:CanSendGameInviteAsync(lp)
			end)
			if okC and pode then
				pcall(function()
					SocialService:PromptGameInvite(lp)
				end)
			else
				Paineis.atualizarSala({ membros = {}, mensagem = "Convites não estão disponíveis agora." })
			end
		end,
	}
	Paineis.iniciar({ ajustes = Ajustes, sala = sala })
	Paineis.aoFechar(function()
		if estadoJogo == "menu" and grupo then
			grupo:habilitar(true)
		end
	end)
	remotos.Sala.OnClientEvent:Connect(function(tipo: string, info: any)
		if tipo == "estado" then
			Paineis.atualizarSala(info)
		elseif tipo == "iniciar" and type(info) == "table" then
			if estadoJogo == "menu" then
				task.spawn(jogar, { inicio = info.inicio })
			end
		end
	end)

	Exploracao.iniciar(remotos, function()
		task.spawn(voltarAoMenu)
	end)

	-- rótulo discreto com a revisão
	local telaV = Interface.tela("OI3_Versao", 5, true)
	rotuloVersao = Interface.texto(telaV, {
		Text = Config.JOGO .. " · " .. Config.REVISAO,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -6),
		Size = UDim2.fromOffset(160, 18),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Interface.COR.textoFraco,
		TextTransparency = 0.45,
	})

	irParaMenu(true)
	lp:SetAttribute("OI3_Pronto", true)
end

return Main
