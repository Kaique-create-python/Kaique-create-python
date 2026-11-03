-- BIZARRE BATTLEGROUNDS :: ADM (dono e quem ele escolher) para testar tudo rápido
-- Tudo é conferido aqui no servidor. Quem não é ADM é ignorado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Stands = require(BB:WaitForChild("Stands"))
local Regras = require(BB:WaitForChild("Regras"))

local Lutadores = require(script.Parent.Lutadores)
local Combate = require(script.Parent.Combate)
local Mapa = require(script.Parent.Mapa)
local Bots = require(script.Parent.Bots)

local Admin = {}

local extras: { [number]: boolean } = {}
local remoto: RemoteEvent? = nil
local ultimo: { [Player]: number } = {}

function Admin.ehId(userId: number, criador: number?, lista: { [number]: boolean }?): boolean
	if userId == Config.DONO_USERID then
		return true
	end
	if criador and criador > 0 and userId == criador then
		return true
	end
	for _, id in Config.ADMINS or {} do
		if id == userId then
			return true
		end
	end
	return (lista or extras)[userId] == true
end

function Admin.eh(p: Player): boolean
	local criador = if game.CreatorType == Enum.CreatorType.User then game.CreatorId else 0
	return Admin.ehId(p.UserId, criador, extras)
end

local function responder(p: Player, texto: string, ok: boolean?)
	if remoto then
		remoto:FireClient(p, "msg", { texto = texto, ok = ok ~= false })
	end
end

local function meu(p: Player)
	return Lutadores.doJogador(p)
end

local COMANDOS: { [string]: (Player, any) -> () } = {}

COMANDOS.bot = function(p, a)
	local lut = meu(p)
	local pos = if lut then lut.raiz.Position + lut.raiz.CFrame.LookVector * 20 else nil
	local stand = if Stands.valido(a.stand) then a.stand else nil
	local dif = if a.dificuldade == "facil" or a.dificuldade == "medio" or a.dificuldade == "dificil" then a.dificuldade else nil
	local b, erro = Bots.criar(pos, stand, dif, p)
	if b then
		responder(p, "Bot criado: " .. b.nome)
	else
		responder(p, "Não deu: " .. tostring(erro), false)
	end
end

COMANDOS.limparBots = function(p)
	Bots.limpar(nil)
	responder(p, "Bots removidos.")
end

COMANDOS.curar = function(p)
	local lut = meu(p)
	if lut then
		lut.hum.Health = lut.hum.MaxHealth
		responder(p, "Vida cheia.")
	end
end

COMANDOS.despertar = function(p)
	local lut = meu(p)
	if lut then
		lut.estado.despertar = Config.DESPERTAR.max
		Combate.sincronizar(lut)
		responder(p, "Barra de DESPERTAR cheia (aperte G / DESPERTAR).")
	end
end

COMANDOS.semRecarga = function(p, a)
	local lut = meu(p)
	if lut then
		lut.estado.semRecarga = a.ligar == true
		p:SetAttribute("BB_SemRecarga", lut.estado.semRecarga)
		responder(p, if lut.estado.semRecarga then "Sem recarga: LIGADO." else "Sem recarga: desligado.")
	end
end

COMANDOS.imortal = function(p, a)
	local lut = meu(p)
	if lut then
		lut.imortal = a.ligar == true
		p:SetAttribute("BB_Imortal", lut.imortal)
		responder(p, if lut.imortal then "Imortal: LIGADO." else "Imortal: desligado.")
	end
end

COMANDOS.restaurarMapa = function(p)
	local n = Mapa.restaurarTudo()
	responder(p, "Mapa restaurado (" .. n .. " peças voltaram).")
end

COMANDOS.quebrarTudo = function(p)
	local lut = meu(p)
	if lut then
		local n = Mapa.quebrarArea(lut.raiz.Position, 60, 9)
		responder(p, "BOOM: " .. n .. " peças quebradas em volta.")
	end
end

COMANDOS.stand = function(p, a)
	local lut = meu(p)
	if lut and Stands.valido(a.id) then
		Lutadores.trocarStand(lut, a.id)
		p:SetAttribute("BB_Stand", a.id)
		Combate.sincronizar(lut)
		responder(p, "Stand trocado para " .. Stands.get(a.id).nome .. ".")
	end
end

COMANDOS.matarBots = function(p)
	for _, b in Bots.lista() do
		b.hum.Health = 0
	end
	responder(p, "Bots derrubados.")
end

COMANDOS.daradm = function(p, a)
	if p.UserId ~= Config.DONO_USERID then
		responder(p, "Só o dono pode dar ADM.", false)
		return
	end
	local nome = if type(a.nome) == "string" then string.lower(a.nome) else ""
	for _, outro in Players:GetPlayers() do
		if string.lower(outro.Name) == nome or string.lower(outro.DisplayName) == nome then
			extras[outro.UserId] = true
			outro:SetAttribute("BB_Admin", true)
			responder(p, outro.DisplayName .. " agora é ADM.")
			responder(outro, "Você recebeu ADM do dono.")
			return
		end
	end
	responder(p, "Ninguém com esse nome.", false)
end

COMANDOS.info = function(p)
	local n = #Lutadores.todos()
	responder(p, string.format("%s · %d lutadores · %d peças quebradas · %s", Config.REVISAO, n, Mapa.totalQuebradas(), Regras and "ok" or ""))
end

function Admin.comando(p: Player, nome: any, args: any)
	if not Admin.eh(p) then
		return
	end
	local t = os.clock()
	if ultimo[p] and t - ultimo[p] < 0.3 then
		return
	end
	ultimo[p] = t
	local fn = if type(nome) == "string" then COMANDOS[nome] else nil
	if not fn then
		responder(p, "Comando desconhecido.", false)
		return
	end
	local ok, err = pcall(fn, p, if type(args) == "table" then args else {})
	if not ok then
		warn("[BB] ADM " .. tostring(nome) .. ": " .. tostring(err))
		responder(p, "Erro: " .. tostring(err), false)
	end
end

function Admin.iniciar(r: RemoteEvent)
	remoto = r
	r.OnServerEvent:Connect(Admin.comando)
	local function marcar(p: Player)
		p:SetAttribute("BB_Admin", Admin.eh(p))
	end
	Players.PlayerAdded:Connect(marcar)
	for _, p in Players:GetPlayers() do
		marcar(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		ultimo[p] = nil
	end)
end

Admin.COMANDOS = COMANDOS
return Admin
