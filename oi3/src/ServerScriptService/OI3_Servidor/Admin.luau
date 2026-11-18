-- OI3 :: ADM (AJUSTE-10) — comandos para testar o jogo sem passar fase por fase
-- Quem é ADM: o dono do jogo (Config.DONO_USERID / quem criou a experiência) e quem estiver em
-- Config.ADMINS (ou receber ADM do dono durante a partida). TODO comando é conferido AQUI no servidor:
-- o painel do celular só pede; quem não é ADM é ignorado.
-- Pulos de fase do ADM rodam em "modo teste": NÃO salvam o progresso (o ponto salvo de verdade continua).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OI3 = ReplicatedStorage:WaitForChild("OI3")
local Config = require(OI3:WaitForChild("Config"))
local MissoesDados = require(OI3:WaitForChild("Missoes"))

local Admin = {}

local extras: { [number]: boolean } = {} -- ADM dado pelo dono nesta partida (some quando o servidor fecha)
local remoto: RemoteEvent? = nil
local historia: any = nil
local missoes: any = nil
local atores: any = nil
local ultimo: { [Player]: number } = {}

-- função pura (testável): este UserId é ADM?
function Admin.ehId(userId: number, criador: number?, extrasLista: { [number]: boolean }?): boolean
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
	return (extrasLista or extras)[userId] == true
end

function Admin.eh(plr: Player): boolean
	local criador = if game.CreatorType == Enum.CreatorType.User then game.CreatorId else 0
	return Admin.ehId(plr.UserId, criador, extras)
end

-- função pura (testável): confere e normaliza um pedido de "ir para"
-- destinos: tarde, jantar, ritual, missao (n, i), final
function Admin.validarIr(destino: any, n: any, i: any, crianca: any): (string?, number?, number?, string?)
	if type(destino) ~= "string" then
		return nil
	end
	local cod = if type(crianca) == "string" and (crianca == "KE" or crianca == "NI" or crianca == "ME") then crianca else nil
	if destino == "tarde" or destino == "jantar" or destino == "ritual" or destino == "final" then
		return destino, nil, nil, cod
	end
	if destino == "missao" then
		local nn = tonumber(n)
		if not nn or nn ~= math.floor(nn) or not MissoesDados.missao(nn) then
			return nil
		end
		local ii = tonumber(i) or 1
		local m = MissoesDados.missao(nn)
		ii = math.clamp(math.floor(ii), 1, #m.passos)
		return "missao", nn, ii, cod
	end
	return nil
end

local function responder(plr: Player, texto: string, ok: boolean?)
	if remoto then
		remoto:FireClient(plr, "msg", { texto = texto, ok = ok ~= false })
	end
end

local function marcar(plr: Player)
	plr:SetAttribute("OI3_Admin", Admin.eh(plr))
end

local COMANDOS: { [string]: (Player, any) -> () } = {}

-- vai direto para uma parte da história (cria o grupo de teste se precisar)
COMANDOS.ir = function(plr, a)
	local destino, n, i, cod = Admin.validarIr(a.destino, a.n, a.i, a.crianca)
	if not destino then
		responder(plr, "Destino inválido.", false)
		return
	end
	historia.adminIr(plr, destino, n, i, cod)
	if destino == "missao" then
		local m = MissoesDados.missao(n :: number)
		responder(plr, string.format("Indo para a %s, passo %d (modo teste: não salva).", m.titulo, i :: number))
	else
		responder(plr, "Indo para: " .. destino .. " (modo teste: não salva).")
	end
end

-- completa o passo atual da missão (como se tivessem feito tudo)
COMANDOS.passo = function(plr)
	local g = historia.grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m then
		responder(plr, "Você não está numa missão.", false)
		return
	end
	g.teste = true
	missoes.adminPasso(g)
	responder(plr, "Passo pulado.")
end

COMANDOS.proxima = function(plr)
	local g = historia.grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m then
		responder(plr, "Você não está numa missão.", false)
		return
	end
	g.teste = true
	local n = g.m.n + 1
	if MissoesDados.missao(n) then
		missoes.adminIr(g, n, 1)
		responder(plr, "Próxima missão: " .. n)
	else
		missoes.adminFinal(g)
		responder(plr, "Era a última: indo para o final.")
	end
end

COMANDOS.anterior = function(plr)
	local g = historia.grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m then
		responder(plr, "Você não está numa missão.", false)
		return
	end
	g.teste = true
	local n = math.max(1, g.m.n - 1)
	missoes.adminIr(g, n, 1)
	responder(plr, "Missão anterior: " .. n)
end

COMANDOS.reiniciar = function(plr)
	local g = historia.grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m then
		responder(plr, "Você não está numa missão.", false)
		return
	end
	g.teste = true
	missoes.adminIr(g, g.m.n, g.m.i)
	responder(plr, "Passo reiniciado.")
end

-- o monstro não pega ninguém (esconde-esconde e porão)
COMANDOS.imortal = function(plr, a)
	local liga = a.ligar == true
	plr:SetAttribute("OI3_Imortal", liga)
	responder(plr, if liga then "Imortal: o monstro não te pega." else "Imortal desligado.")
end

-- chama a sombra AGORA (esconde-esconde da Missão 1)
COMANDOS.sombra = function(plr)
	local g = historia.grupoDe(plr)
	if not g or not g.m or not g.m.esc then
		responder(plr, "Só funciona no esconde-esconde (Missão 1).", false)
		return
	end
	g.teste = true
	g.m.esc.agora = true
	responder(plr, "A sombra vem agora.")
end

-- dá ADM para outra pessoa nesta partida (só o dono)
COMANDOS.daradm = function(plr, a)
	if plr.UserId ~= Config.DONO_USERID and not (game.CreatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId) then
		responder(plr, "Só o dono pode dar ADM.", false)
		return
	end
	local nome = if type(a.nome) == "string" then string.lower(a.nome) else ""
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == nome or string.lower(p.DisplayName) == nome then
			extras[p.UserId] = true
			marcar(p)
			responder(plr, p.DisplayName .. " agora é ADM (até o servidor fechar).")
			responder(p, "Você recebeu ADM do dono.")
			return
		end
	end
	responder(plr, "Ninguém com esse nome no servidor.", false)
end

-- troca o monstro (catálogo ou um da internet) e guarda a escolha para os próximos servidores
COMANDOS.monstro = function(plr, a)
	local chave = if type(a.chave) == "string" then a.chave else ""
	local nome = atores.usarMonstro(chave)
	if not nome then
		responder(plr, "Esse monstro não está disponível.", false)
		return
	end
	atores.salvarEscolhaMonstro(chave)
	responder(plr, "Monstro agora: " .. nome .. " (salvo para os próximos servidores).")
end

-- informações do estado atual (para o painel)
COMANDOS.info = function(plr)
	local g = historia.grupoDe(plr)
	local txt
	if not g then
		txt = "Sem grupo (menu)."
	elseif g.fase == "missao" and g.m then
		local m = MissoesDados.missao(g.m.n)
		txt = string.format("%s — %s · passo %d/%d", m.titulo, m.nome, g.m.i, #m.passos)
	else
		txt = "Fase: " .. tostring(g.fase)
	end
	if g and g.teste then
		txt ..= " · modo teste"
	end
	responder(plr, txt .. " · " .. Config.REVISAO)
end

function Admin.comando(plr: Player, nome: any, args: any)
	if not Admin.eh(plr) then
		return -- quem não é ADM é ignorado (sem resposta)
	end
	local t = os.clock()
	if ultimo[plr] and t - ultimo[plr] < 0.4 then
		return
	end
	ultimo[plr] = t
	local fn = if type(nome) == "string" then COMANDOS[nome] else nil
	if not fn then
		responder(plr, "Comando desconhecido.", false)
		return
	end
	local ok, err = pcall(fn, plr, if type(args) == "table" then args else {})
	if not ok then
		warn("[OI3] ADM " .. tostring(nome) .. ":", err)
		responder(plr, "Erro no comando: " .. tostring(err), false)
	end
end

function Admin.iniciar(r: RemoteEvent, h: any, m: any, at: any)
	remoto = r
	historia = h
	missoes = m
	atores = at
	r.OnServerEvent:Connect(Admin.comando)
	Players.PlayerAdded:Connect(marcar)
	for _, p in Players:GetPlayers() do
		marcar(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		ultimo[p] = nil
	end)
end

return Admin
