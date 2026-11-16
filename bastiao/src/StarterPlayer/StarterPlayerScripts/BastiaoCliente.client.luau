-- PROJETO BASTIÃO :: cliente da Etapa 1
-- Liga a interface da história (objetivo, legendas, avisos, corte e cartão final), os
-- prompts no estilo da bodycam e o giro dos giroflexes. Não substitui nada do Sector7Client:
-- câmera, lanterna, fôlego e HUD da bodycam continuam os mesmos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local jogador = Players.LocalPlayer
local playerGui = jogador:WaitForChild("PlayerGui")
local modulo = ReplicatedStorage:WaitForChild("BastiaoCompartilhado")
local Compartilhado = require(modulo)
local Textos = require(modulo:WaitForChild("Textos"))
local Interface = require(script:WaitForChild("Interface"))
local Prompts = require(script:WaitForChild("Prompts"))
local Giroflex = require(script:WaitForChild("Giroflex"))

local ui = Interface.criar(playerGui, Textos)
Prompts.iniciar(playerGui)
Giroflex.iniciar(function()
	return modulo:GetAttribute(Compartilhado.ATR_ALARME) == true
end)

-- estado replicado: quem entra no meio da história vê o objetivo e o alerta atuais
local function objetivo()
	local chave = modulo:GetAttribute(Compartilhado.ATR_OBJETIVO)
	ui.objetivo(if type(chave) == "string" then chave else nil)
end
local function alarme()
	ui.alarme(modulo:GetAttribute(Compartilhado.ATR_ALARME) == true)
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
modulo:GetAttributeChangedSignal(Compartilhado.ATR_FIM):Connect(fim)
objetivo()
alarme()
fim()

local remotos = ReplicatedStorage:WaitForChild(Compartilhado.PASTA_REMOTOS, 60)
local apresentacao = remotos and remotos:WaitForChild(Compartilhado.REMOTO_APRESENTACAO, 60)
if not apresentacao then
	warn("[Bastiao] remoto de apresentação não apareceu; legendas desligadas")
	return
end
apresentacao.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.tipo == "fala" and type(msg.chave) == "string" then
		ui.fala(msg.chave, tonumber(msg.duracao) or 4)
	elseif msg.tipo == "som" and type(msg.chave) == "string" then
		ui.som(msg.chave, tonumber(msg.duracao) or 2.6)
	elseif msg.tipo == "aviso" and type(msg.texto) == "string" then
		ui.aviso(msg.texto)
	elseif msg.tipo == "corte" then
		ui.corte()
	end
end)
