-- OI3 :: história do Capítulo 1 no servidor (AJUSTE-6)
-- Grupo = quem joga junto (sozinho = 1 jogador; sala = até 3). O servidor manda em tudo que precisa
-- ficar igual para o grupo: a escolha das crianças (sem repetir), a tarde, a hora em que o Vô chama
-- para o jantar e o começo do ritual (sincronizado).

local Players = game:GetService("Players")

local Historia = {}

local CRIANCAS = { "KE", "NI", "ME" }
Historia.CRIANCAS = CRIANCAS
Historia.DETALHES = { "foto", "trancado", "tv", "brinquedos", "porao" }
local TEMPO_TARDE = 240 -- segundos de tarde antes do Vô chamar (se não acharem 3 coisas antes)
local DETALHES_PARA_JANTAR = 3
local ESPERA_ESCOLHA = 25
local ESPERA_MESA = 25
local DURACAO_JANTAR = 14 -- a cena do jantar no cliente

local remoto: RemoteEvent? = nil
local grupoDe: { [Player]: any } = {}
local aoVestir: ((Player, string) -> ())? = nil

local function enviar(g, tipo: string, info: any)
	for _, p in g.membros do
		if p.Parent and remoto then
			remoto:FireClient(p, tipo, info)
		end
	end
end

-- função pura (testável): crianças ainda livres no grupo
function Historia.livres(escolhas: { [any]: string }): { string }
	local usados = {}
	for _, c in escolhas do
		usados[c] = true
	end
	local l = {}
	for _, c in CRIANCAS do
		if not usados[c] then
			table.insert(l, c)
		end
	end
	return l
end

-- AJUSTE-7: quem escolheu cada criança (o cartão mostra "COM <nome>" para o grupo)
local function quemEscolheu(g): { [string]: string }
	local q = {}
	for p, c in g.escolhas do
		q[c] = p.DisplayName
	end
	return q
end

local function comecarTarde(g)
	if g.fase ~= "escolha" then
		return
	end
	for _, p in g.membros do
		if not g.escolhas[p] then
			g.escolhas[p] = Historia.livres(g.escolhas)[1] or "KE"
		end
	end
	g.fase = "tarde"
	local mapa = {}
	for p, c in g.escolhas do
		mapa[tostring(p.UserId)] = c
	end
	enviar(g, "tarde", { escolhas = mapa, total = #Historia.DETALHES })
	local token = g.token
	task.delay(TEMPO_TARDE, function()
		if g.token == token and g.fase == "tarde" then
			Historia.chamarJantar(g)
		end
	end)
end

function Historia.iniciarGrupo(membros: { Player })
	local g = { membros = table.clone(membros), fase = "escolha", escolhas = {}, achados = {}, naMesa = {}, token = os.clock() }
	for _, p in membros do
		local antigo = grupoDe[p]
		if antigo then
			antigo.token = -1
		end
		grupoDe[p] = g
	end
	enviar(g, "escolher", { livres = Historia.livres(g.escolhas), tempo = ESPERA_ESCOLHA, grupo = #membros })
	local token = g.token
	task.delay(ESPERA_ESCOLHA, function()
		if g.token == token then
			comecarTarde(g)
		end
	end)
	return g
end

function Historia.escolher(plr: Player, codigo: any)
	local g = grupoDe[plr]
	if not g or g.fase ~= "escolha" or type(codigo) ~= "string" or not table.find(CRIANCAS, codigo) then
		return
	end
	for p, c in g.escolhas do
		if c == codigo and p ~= plr then
			if remoto then
				remoto:FireClient(plr, "ocupado", { livres = Historia.livres(g.escolhas), quem = quemEscolheu(g) })
			end
			return
		end
	end
	g.escolhas[plr] = codigo
	enviar(g, "escolhas", { livres = Historia.livres(g.escolhas), quem = quemEscolheu(g) })
	for _, p in g.membros do
		if p.Parent and not g.escolhas[p] then
			return
		end
	end
	comecarTarde(g)
end

function Historia.codigoDe(plr: Player): string?
	local g = grupoDe[plr]
	return g and g.escolhas[plr] or nil
end

function Historia.chamarJantar(g)
	if g.fase ~= "tarde" then
		return
	end
	g.fase = "jantar"
	enviar(g, "jantar", {})
	local token = g.token
	task.delay(120, function()
		if g.token == token and g.fase == "jantar" then
			Historia.iniciarRitual(g)
		end
	end)
end

function Historia.detalhe(plr: Player, nome: any)
	local g = grupoDe[plr]
	if not g or g.fase ~= "tarde" or type(nome) ~= "string" or not table.find(Historia.DETALHES, nome) or g.achados[nome] then
		return
	end
	g.achados[nome] = true
	local total = 0
	for _ in g.achados do
		total += 1
	end
	enviar(g, "achado", { nome = nome, total = total, de = plr.UserId })
	if total >= DETALHES_PARA_JANTAR then
		local token = g.token
		task.delay(10, function()
			if g.token == token then
				Historia.chamarJantar(g)
			end
		end)
	end
end

function Historia.naMesa(plr: Player)
	local g = grupoDe[plr]
	if not g or g.fase ~= "jantar" then
		return
	end
	g.naMesa[plr] = true
	for _, p in g.membros do
		if p.Parent and not g.naMesa[p] then
			if not g.esperandoMesa then
				g.esperandoMesa = true
				local token = g.token
				task.delay(ESPERA_MESA, function()
					if g.token == token and g.fase == "jantar" then
						Historia.iniciarRitual(g)
					end
				end)
			end
			return
		end
	end
	Historia.iniciarRitual(g)
end

function Historia.iniciarRitual(g)
	if g.fase ~= "jantar" then
		return
	end
	g.fase = "ritual"
	enviar(g, "ritual", { inicio = workspace:GetServerTimeNow() + DURACAO_JANTAR })
end

function Historia.sair(plr: Player)
	local g = grupoDe[plr]
	grupoDe[plr] = nil
	if g then
		local i = table.find(g.membros, plr)
		if i then
			table.remove(g.membros, i)
		end
		g.escolhas[plr] = nil
		g.naMesa[plr] = nil
		if #g.membros == 0 then
			g.token = -1
		end
	end
end

-- chamado quando o personagem do jogador nasce: veste como a criança escolhida
function Historia.personagemNasceu(plr: Player)
	local cod = Historia.codigoDe(plr)
	if cod and aoVestir then
		task.spawn(aoVestir, plr, cod)
	end
end

function Historia.iniciar(r: RemoteEvent, permitido: (Player, string, number) -> boolean, vestir: (Player, string) -> ())
	remoto = r
	aoVestir = vestir
	r.OnServerEvent:Connect(function(plr: Player, tipo: any, valor: any)
		if not permitido(plr, "historia", 0.25) then
			return
		end
		if tipo == "solo" then
			Historia.iniciarGrupo({ plr })
		elseif tipo == "escolher" then
			Historia.escolher(plr, valor)
		elseif tipo == "detalhe" then
			Historia.detalhe(plr, valor)
		elseif tipo == "naMesa" then
			Historia.naMesa(plr)
		end
	end)
	Players.PlayerRemoving:Connect(Historia.sair)
end

return Historia
