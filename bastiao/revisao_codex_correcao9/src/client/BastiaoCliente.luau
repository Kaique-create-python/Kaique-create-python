-- PROJETO BASTIÃO :: cliente (Etapa 1 + Etapa 2)
-- Liga a interface da história (objetivo, legendas, avisos, corte e cartão final), os
-- prompts no estilo da bodycam, o giro dos giroflexes, as telas dos terminais, o som
-- (vozes, rádio, eco, passos, ambiente) e o seletor de língua PT · EN · RU no menu da bodycam.
-- Não substitui nada do Sector7Client: câmera, lanterna, fôlego e HUD continuam os mesmos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local jogador = Players.LocalPlayer
local playerGui = jogador:WaitForChild("PlayerGui")
local modulo = ReplicatedStorage:WaitForChild("BastiaoCompartilhado")
local Compartilhado = require(modulo)
local Textos = require(modulo:WaitForChild("Textos"))
local okAudio, Audio = pcall(function()
	return require(modulo:WaitForChild("Audio", 10))
end)
if not okAudio or type(Audio) ~= "table" then
	Audio = { ids = {}, vozes = {}, sfx = {}, loops = {}, duracoes = {} }
end
local Interface = require(script:WaitForChild("Interface"))
local Prompts = require(script:WaitForChild("Prompts"))
local Giroflex = require(script:WaitForChild("Giroflex"))
local Idioma = require(script:WaitForChild("Idioma"))
local Telas = require(script:WaitForChild("Telas"))
local Som = require(script:WaitForChild("Som"))
local Foley = require(script:WaitForChild("Foley"))
-- Efeitos visuais (menu 3D, lanterna, perseguição) são opcionais: se faltarem ou falharem,
-- o resto do cliente segue normal.
local efeitosCarregou, Efeitos = pcall(function()
	return require(script:WaitForChild("Efeitos", 10) :: any)
end)
-- Sons do bote e da garra do monstro (MonstroSom, do Antigravity): também opcionais.
local monstroSomCarregou, MonstroSom = pcall(function()
	return require(script:WaitForChild("MonstroSom", 10) :: any)
end)
local catalogo = nil
local moduloCatalogo = modulo:FindFirstChild("AudioCatalog")
if moduloCatalogo then
	local ok, valor = pcall(require, moduloCatalogo)
	if ok then catalogo = valor else warn("[Bastiao] AudioCatalog inválido: " .. tostring(valor)) end
end

-- os remotos são criados no início do servidor (antes de qualquer jogador entrar)
local remotos = ReplicatedStorage:WaitForChild(Compartilhado.PASTA_REMOTOS, 30)
local remotoIdioma = remotos and remotos:WaitForChild(Compartilhado.REMOTO_IDIOMA, 10)
local apresentacao = remotos and remotos:WaitForChild(Compartilhado.REMOTO_APRESENTACAO, 10)

local idioma = Idioma.iniciar({
	textos = Textos,
	atributo = Compartilhado.ATR_IDIOMA,
	remoto = if remotoIdioma and remotoIdioma:IsA("RemoteEvent") then remotoIdioma else nil,
	playerGui = playerGui,
})
local ui = Interface.criar(playerGui, Textos, idioma.atual)
Prompts.iniciar(playerGui, { textos = Textos, idioma = idioma.atual, aoMudar = idioma.aoMudar })
Telas.iniciar({ playerGui = playerGui, textos = Textos, idioma = idioma.atual, aoMudar = idioma.aoMudar })
local function alarmeLigado(): boolean
	return modulo:GetAttribute(Compartilhado.ATR_ALARME) == true
end
Giroflex.iniciar(alarmeLigado)
local som = Som.iniciar({
	audio = Audio,
	textos = Textos,
	idioma = idioma.atual,
	alarme = alarmeLigado,
	acessoBloqueado = function()
		return modulo:GetAttribute(Compartilhado.ATR_ACESSO) == "bloqueado"
	end,
})
local foley = Foley.start(jogador, catalogo, {
	grupo = som.grupoEfeitos,
	aoPassosMudar = som.passosExternos,
})
local efeitos = { destroy = function() end }
if efeitosCarregou and type(Efeitos) == "table" and type(Efeitos.iniciar) == "function" then
	local criou, criado = pcall(Efeitos.iniciar, {
		jogador = jogador,
		playerGui = playerGui,
		efeito = function(chave: string)
			return som.efeito(chave)
		end,
		ui = function(chave: string)
			foley.ui(chave)
		end,
	})
	if criou and type(criado) == "table" and type(criado.destroy) == "function" then
		efeitos = criado
	else
		warn("[Bastiao] efeitos visuais desligados:", criado)
	end
else
	warn("[Bastiao] efeitos visuais desligados:", Efeitos)
end
local monstroSom = { parar = function() end }
if monstroSomCarregou and type(MonstroSom) == "table" and type(MonstroSom.iniciar) == "function" then
	-- passos=true: o baque grave da loja soma com o passo do ElevenLabs (Foley), os dois no pé.
	local criou, criado = pcall(MonstroSom.iniciar, {
		jogador = jogador, grupo = som.grupoEfeitos, passos = true,
		efeito = function(chave: string, pos: Vector3?)
			return som.efeito(chave, pos)
		end,
	})
	if criou and type(criado) == "table" and type(criado.parar) == "function" then
		monstroSom = criado
	else
		warn("[Bastiao] sons do bote desligados:", criado)
	end
else
	warn("[Bastiao] sons do bote desligados:", MonstroSom)
end
ui.definirSom(function(chave: string)
	som.efeito(chave)
end)
local ativo = true
local conexoes = {}
local ultimoPrompt: number? = nil
local function recente(): boolean
	return ultimoPrompt ~= nil and os.clock() - ultimoPrompt <= 1.2
end
table.insert(conexoes, script.Destroying:Connect(function()
	if not ativo then return end
	ativo = false
	for _, conexao in conexoes do conexao:Disconnect() end
	-- Restaura os sons padrão antes de desmontar o dono dos grupos/reverb.
	foley.destroy()
	pcall(efeitos.destroy)
	pcall(monstroSom.parar)
	som.parar()
end))
table.insert(conexoes, ProximityPromptService.PromptTriggered:Connect(function(prompt, quem)
	if quem ~= nil and quem ~= jogador then return end
	if prompt:GetAttribute("Bastiao") ~= true then return end
	ultimoPrompt = os.clock()
	foley.ui("ui_click")
end))
idioma.aoMudar(function()
	if not ativo then return end
	ui.idioma()
	som.precarregar()
end)

-- estado replicado: quem entra no meio da história vê o objetivo e o alerta atuais
local function objetivo()
	local chave = modulo:GetAttribute(Compartilhado.ATR_OBJETIVO)
	ui.objetivo(if type(chave) == "string" then chave else nil)
	if recente() then
		foley.ui("ui_confirm")
		ultimoPrompt = nil
	end
end
local function alarme()
	ui.alarme(alarmeLigado())
	som.estado()
end
local function fim()
	local quando = modulo:GetAttribute(Compartilhado.ATR_FIM)
	-- só mostra o cartão para quem estava lá (não repete para quem entra muito depois)
	if type(quando) == "number" and quando > 0 and workspace:GetServerTimeNow() - quando < 20 then
		ui.fim()
	end
end
table.insert(conexoes, modulo:GetAttributeChangedSignal(Compartilhado.ATR_OBJETIVO):Connect(objetivo))
table.insert(conexoes, modulo:GetAttributeChangedSignal(Compartilhado.ATR_ALARME):Connect(alarme))
table.insert(conexoes, modulo:GetAttributeChangedSignal(Compartilhado.ATR_ACESSO):Connect(som.estado))
table.insert(conexoes, modulo:GetAttributeChangedSignal(Compartilhado.ATR_FIM):Connect(fim))
objetivo()
alarme()
fim()

if not apresentacao or not apresentacao:IsA("RemoteEvent") then
	warn("[Bastiao] remoto de apresentação não apareceu; legendas e vozes desligadas")
	return
end
table.insert(conexoes, apresentacao.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" or type(msg.tipo) ~= "string" then
		return
	end
	local chave = if type(msg.chave) == "string" then msg.chave else nil
	local pos = if typeof(msg.pos) == "Vector3" then msg.pos else nil
	if msg.tipo == "fala" and chave then
		ui.fala(chave, tonumber(msg.duracao) or 4)
		som.fala(chave)
	elseif msg.tipo == "som" and chave then
		som.som(chave, pos)
	elseif msg.tipo == "ruido" and chave then
		som.ruido(chave, pos)
	elseif msg.tipo == "aviso" and chave then
		ui.aviso(chave, if type(msg.args) == "table" then msg.args else nil)
		if recente() then
			foley.ui("ui_denied")
			ultimoPrompt = nil
		end
	elseif msg.tipo == "corte" then
		ui.corte()
	end
end))
