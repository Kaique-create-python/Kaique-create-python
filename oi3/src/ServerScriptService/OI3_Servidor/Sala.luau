-- OI3 :: sala multiplayer (no mesmo servidor). Quando todos estão prontos,
-- o servidor manda todos começarem a abertura no mesmo instante.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("OI3"):WaitForChild("Config"))

local Sala = {}

local remoto: RemoteEvent? = nil
local membros: { Player } = {}
local prontos: { [Player]: boolean } = {}
local contagem: number? = nil
local token = 0
local ultimo: { [Player]: number } = {}

function Sala.estado(mensagem: string?)
	local lista = {}
	for _, p in membros do
		table.insert(lista, { userId = p.UserId, nome = p.DisplayName, pronto = prontos[p] == true })
	end
	return { membros = lista, contagem = contagem, mensagem = mensagem, max = Config.SALA.maximoJogadores }
end

-- AJUSTE-7: um resumo vai para TODOS do servidor (o menu mostra "SALA 2/3 · ENTRAR")
function Sala.resumo()
	local ids = {}
	for _, p in membros do
		table.insert(ids, p.UserId)
	end
	return { n = #membros, max = Config.SALA.maximoJogadores, ids = ids }
end

local function transmitir(mensagem: string?)
	if not remoto then
		return
	end
	local e = Sala.estado(mensagem)
	for _, p in membros do
		(remoto :: RemoteEvent):FireClient(p, "estado", e)
	end
	(remoto :: RemoteEvent):FireAllClients("resumo", Sala.resumo())
end

function Sala.todosProntos(): boolean
	if #membros < Config.SALA.minimoJogadores then
		return false
	end
	for _, p in membros do
		if not prontos[p] then
			return false
		end
	end
	return true
end

local function comecar()
	local grupo = table.clone(membros)
	local inicio = workspace:GetServerTimeNow() + Config.SALA.atrasoInicio
	local ids = {}
	for _, p in grupo do
		table.insert(ids, p.UserId)
	end
	contagem = nil
	token += 1
	membros = {}
	prontos = {}
	for _, p in grupo do
		if remoto and p.Parent then
			(remoto :: RemoteEvent):FireClient(p, "iniciar", { inicio = inicio, membros = ids })
		end
	end
	if remoto then
		(remoto :: RemoteEvent):FireAllClients("resumo", Sala.resumo())
	end
	-- AJUSTE-6: a história do grupo começa pela escolha das crianças
	require(script.Parent:WaitForChild("Historia")).iniciarGrupo(grupo)
end

function Sala.verificar()
	if Sala.todosProntos() then
		if not contagem then
			token += 1
			local meu = token
			contagem = Config.SALA.contagem
			task.spawn(function()
				while contagem and meu == token do
					transmitir()
					task.wait(1)
					if meu ~= token or not contagem then
						return
					end
					contagem -= 1
					if contagem <= 0 then
						comecar()
						return
					end
				end
			end)
		end
	elseif contagem then
		contagem = nil
		token += 1
	end
	transmitir()
end

function Sala.entrar(plr: Player)
	if table.find(membros, plr) then
		transmitir()
		return
	end
	if #membros >= Config.SALA.maximoJogadores then
		if remoto then
			(remoto :: RemoteEvent):FireClient(plr, "estado", Sala.estado("Sala cheia. Tente de novo daqui a pouco."))
		end
		return
	end
	table.insert(membros, plr)
	prontos[plr] = false
	Sala.verificar()
end

function Sala.remover(plr: Player)
	ultimo[plr] = nil
	local i = table.find(membros, plr)
	if i then
		table.remove(membros, i)
		prontos[plr] = nil
		Sala.verificar()
	end
end

function Sala.pronto(plr: Player, valor: boolean)
	if table.find(membros, plr) then
		prontos[plr] = valor
		Sala.verificar()
	end
end

function Sala.iniciar(r: RemoteEvent)
	remoto = r
	r.OnServerEvent:Connect(function(plr: Player, acao: any, valor: any)
		local agora = os.clock()
		if ultimo[plr] and agora - ultimo[plr] < 0.2 then
			return
		end
		ultimo[plr] = agora
		if acao == "entrar" then
			Sala.entrar(plr)
		elseif acao == "sair" then
			Sala.remover(plr)
		elseif acao == "pronto" and type(valor) == "boolean" then
			Sala.pronto(plr, valor)
		end
	end)
	Players.PlayerRemoving:Connect(Sala.remover)
	Players.PlayerAdded:Connect(function(plr: Player)
		task.delay(3, function()
			if plr.Parent and remoto then
				(remoto :: RemoteEvent):FireClient(plr, "resumo", Sala.resumo())
			end
		end)
	end)
end

return Sala
