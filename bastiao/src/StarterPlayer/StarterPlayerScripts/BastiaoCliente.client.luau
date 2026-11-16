-- PROJETO BASTIÃO :: cliente (Etapa 1 + Etapa 2)
-- Liga a interface da história (objetivo, legendas, avisos, corte e cartão final), os
-- prompts no estilo da bodycam, o giro dos giroflexes, as telas dos terminais, o som
-- (vozes, rádio, eco, passos, ambiente) e o seletor de língua PT · EN · RU no menu da bodycam.
-- Não substitui nada do Sector7Client: câmera, lanterna, fôlego e HUD continuam os mesmos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
idioma.aoMudar(function()
	ui.idioma()
	som.precarregar()
end)

-- estado replicado: quem entra no meio da história vê o objetivo e o alerta atuais
local function objetivo()
	local chave = modulo:GetAttribute(Compartilhado.ATR_OBJETIVO)
	ui.objetivo(if type(chave) == "string" then chave else nil)
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
modulo:GetAttributeChangedSignal(Compartilhado.ATR_OBJETIVO):Connect(objetivo)
modulo:GetAttributeChangedSignal(Compartilhado.ATR_ALARME):Connect(alarme)
modulo:GetAttributeChangedSignal(Compartilhado.ATR_ACESSO):Connect(som.estado)
modulo:GetAttributeChangedSignal(Compartilhado.ATR_FIM):Connect(fim)
objetivo()
alarme()
fim()

if not apresentacao or not apresentacao:IsA("RemoteEvent") then
	warn("[Bastiao] remoto de apresentação não apareceu; legendas e vozes desligadas")
	return
end
apresentacao.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" or type(msg.tipo) ~= "string" then
		return
	end
	local chave = if type(msg.chave) == "string" then msg.chave else nil
	local pos = if typeof(msg.pos) == "Vector3" then msg.pos else nil
	if msg.tipo == "fala" and chave then
		ui.fala(chave, tonumber(msg.duracao) or 4)
		som.fala(chave)
	elseif msg.tipo == "som" and chave then
		ui.som(chave, tonumber(msg.duracao) or 2.6)
		som.som(chave, pos)
	elseif msg.tipo == "ruido" and chave then
		som.ruido(chave, pos)
	elseif msg.tipo == "aviso" and chave then
		ui.aviso(chave, if type(msg.args) == "table" then msg.args else nil)
	elseif msg.tipo == "corte" then
		ui.corte()
	end
end)
