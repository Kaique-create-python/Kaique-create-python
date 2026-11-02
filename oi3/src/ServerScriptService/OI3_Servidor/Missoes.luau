-- OI3 :: o resto do Capítulo 1 no SERVIDOR (AJUSTE-8)
-- O grupo (sozinho ou até 3) anda junto pelas missões. O servidor guarda o passo atual, confere as
-- interações (achar, ordem, código), roda o esconde-esconde com a sombra, a contagem das cadeiras,
-- a perseguição no porão e a fuga final, e salva o ponto (missão) de cada jogador para continuar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OI3 = ReplicatedStorage:WaitForChild("OI3")
local M = require(OI3:WaitForChild("Missoes"))
local MM = require(OI3:WaitForChild("MissoesMapa"))

local Servidor = {}

local remoto: RemoteEvent? = nil
local grupoDe: (Player) -> any = function()
	return nil
end
local salvar: ((Player, number) -> ())? = nil
local terminou: ((Player) -> ())? = nil

local VEL_PRESENCA = 15 -- quem corre (20) escapa; quem anda é pego
local DURACAO_PERSEGUICAO = 24

local function agora(): number
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return if ok then t else os.clock()
end

local function enviar(g, tipo: string, info: any)
	for _, p in g.membros do
		if p.Parent and remoto then
			remoto:FireClient(p, tipo, info)
		end
	end
end

local function valido(g, token: number): boolean
	return g.token ~= -1 and g.m ~= nil and g.m.token == token
end

local avancar: (any) -> ()

local function estadoPublico(g)
	local m = g.m
	return { n = m.n, i = m.i, feitos = m.feitos, extra = m.publico }
end

---------------------------------------------------------------------------
-- ESCONDE-ESCONDE (Missão 1)
---------------------------------------------------------------------------
local function esconde(g, token: number)
	local m = g.m
	local passo = M.passo(m.n, m.i)
	m.esc = { escondidos = {}, queimados = {}, rodada = 0, distraido = false, procurando = false }
	m.publico.rodada = 0
	local l = MM.layout("quarto")
	task.wait(4)
	while valido(g, token) and m.esc.rodada < (passo.rodadas or 3) do
		-- a Nina ouve os passos antes (o cliente dela avisa já; os outros, 4 s depois)
		enviar(g, "m_sombra_vem", { chega = agora() + 16 })
		task.wait(16)
		if not valido(g, token) then
			return
		end
		-- a sombra só confere os lugares usados na rodada anterior ("deixam de ser seguros")
		local checar = {}
		for id in m.esc.queimados do
			table.insert(checar, id)
		end
		table.sort(checar)
		m.esc.procurando = true
		enviar(g, "m_sombra", { inicio = agora() + 0.3, checar = checar })
		task.wait(9.5) -- o momento em que ela passa conferindo
		if not valido(g, token) then
			return
		end
		local pegos = {}
		local usados = {}
		for _, p in g.membros do
			if p.Parent then
				local spot = m.esc.escondidos[p]
				if spot then
					usados[spot] = true
				end
				if not m.esc.distraido and (not spot or m.esc.queimados[spot]) then
					table.insert(pegos, p.UserId)
				end
			end
		end
		m.esc.procurando = false
		task.wait(5.5)
		if not valido(g, token) then
			return
		end
		if #pegos > 0 then
			enviar(g, "m_pego", { ids = pegos })
		else
			m.esc.rodada += 1
			m.publico.rodada = m.esc.rodada
			m.esc.queimados = usados
			enviar(g, "m_rodada", { rodada = m.esc.rodada, total = passo.rodadas or 3 })
		end
		m.esc.distraido = false
		task.wait(4)
	end
	local _ = l
	if valido(g, token) then
		enviar(g, "m_fim_esconde", {})
		task.wait(2)
		avancar(g)
	end
end

---------------------------------------------------------------------------
-- AS TRÊS CADEIRAS (Missão 7): todos sentados, a voz conta até dez, ninguém olha para trás
---------------------------------------------------------------------------
local function todosSentados(g): boolean
	for _, p in g.membros do
		if p.Parent and not g.m.cad.sentados[p] then
			return false
		end
	end
	return true
end

local function contar(g, token: number)
	local cad = g.m.cad
	if cad.contando then
		return
	end
	cad.contando = true
	local k = 0
	while valido(g, token) and k < 10 do
		if not todosSentados(g) then
			cad.contando = false
			enviar(g, "m_recomeca", { motivo = "levantou" })
			return
		end
		if cad.recomecar then
			cad.recomecar = false
			k = 0
			enviar(g, "m_recomeca", { motivo = "olhou" })
			task.wait(2.5)
			continue
		end
		k += 1
		enviar(g, "m_conta", { k = k })
		task.wait(1.8)
	end
	if valido(g, token) and k >= 10 then
		cad.contando = false
		avancar(g)
	end
end

---------------------------------------------------------------------------
-- PERSEGUIÇÃO NO PORÃO (Missão 8): curta e imprevisível
---------------------------------------------------------------------------
local function perseguir(g, token: number)
	local l = MM.layout("porao")
	local O = l.origem
	local x = l.inicioPresenca.X - O.X
	local fim = os.clock() + DURACAO_PERSEGUICAO
	enviar(g, "m_presenca", { x = x, comecou = true })
	task.wait(1.5)
	while valido(g, token) and os.clock() < fim do
		local dt = 0.1
		-- persegue quem estiver mais perto, dentro do corredor
		local alvo, melhor = nil, math.huge
		for _, p in g.membros do
			local raiz = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") then
				local pos = raiz.Position - O
				if math.abs(pos.Z) < 3 and pos.X > -27 and pos.X < 25 then
					local dist = math.abs(pos.X - x)
					if dist < melhor then
						alvo, melhor = p, dist
					end
				end
			end
		end
		if alvo then
			local raiz = (alvo.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
			local px = raiz.Position.X - O.X
			x += math.clamp(px - x, -VEL_PRESENCA * dt, VEL_PRESENCA * dt)
			if math.abs(px - x) < 2.4 then
				if remoto then
					remoto:FireClient(alvo, "m_pego_perseguicao", { volta = l.retorno })
				end
				x = l.inicioPresenca.X - O.X
				enviar(g, "m_presenca", { x = x, pulo = true })
				task.wait(1.2)
				continue
			end
		end
		enviar(g, "m_presenca", { x = x })
		task.wait(dt)
	end
	if g.m then
		enviar(g, "m_presenca_fim", {})
	end
end

---------------------------------------------------------------------------
-- FUGA (o orfanato desmorona)
---------------------------------------------------------------------------
local function final(g)
	g.fase = "final"
	g.m.token += 1
	enviar(g, "m_final", { inicio = agora() + 1.5 })
	for _, p in g.membros do
		if terminou then
			terminou(p)
		end
	end
end

local function fuga(g, token: number, dur: number)
	enviar(g, "m_fuga", { fim = agora() + dur })
	local l = MM.layout("porao")
	local fim = os.clock() + dur
	while valido(g, token) and os.clock() < fim do
		for _, p in g.membros do
			local raiz = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") then
				local d = Vector3.new(raiz.Position.X - l.saida.X, 0, raiz.Position.Z - l.saida.Z).Magnitude
				if d < 5 then
					final(g)
					return
				end
			end
		end
		task.wait(0.25)
	end
	if valido(g, token) then
		final(g) -- ninguém fica preso para sempre: o fim acontece de qualquer jeito
	end
end

---------------------------------------------------------------------------
local function iniciarPasso(g)
	local m = g.m
	m.token += 1
	local token = m.token
	m.feitos = {}
	m.seq = {}
	local passo = M.passo(m.n, m.i)
	enviar(g, "m_passo", estadoPublico(g))
	if not passo then
		return
	end
	if passo.tipo == "evento" then
		enviar(g, "m_evento", { nome = passo.evento, inicio = agora() + 0.4, dur = passo.dur })
		task.delay(passo.dur or 5, function()
			if valido(g, token) then
				avancar(g)
			end
		end)
	elseif passo.tipo == "esconder" then
		task.spawn(esconde, g, token)
	elseif passo.tipo == "cadeiras" then
		m.cad = { sentados = {}, contando = false, recomecar = false }
	elseif passo.tipo == "fuga" then
		task.spawn(fuga, g, token, passo.dur or 60)
	end
end

function Servidor.iniciar(g, n: number)
	local missao = M.missao(n)
	if not missao then
		return
	end
	g.fase = "missao"
	g.m = { n = n, i = 1, feitos = {}, seq = {}, token = (g.m and g.m.token or 0) + 1, publico = {} }
	for _, p in g.membros do
		if salvar then
			salvar(p, n)
		end
	end
	enviar(g, "m_missao", { n = n, cenario = missao.cenario })
	-- dá tempo dos aparelhos montarem o cenário e levarem o personagem até lá
	local token = g.m.token
	task.delay(3, function()
		if valido(g, token) then
			iniciarPasso(g)
		end
	end)
end

avancar = function(g)
	local m = g.m
	if not m then
		return
	end
	local n2, i2 = M.proximo(m.n, m.i)
	if not n2 then
		final(g)
	elseif n2 ~= m.n then
		Servidor.iniciar(g, n2)
	else
		m.i = i2 :: number
		iniciarPasso(g)
	end
end

local function feito(g, plr: Player, ponto: string)
	local m = g.m
	m.feitos[ponto] = true
	local passo = M.passo(m.n, m.i)
	enviar(g, "m_feito", { ponto = ponto, por = plr.UserId, objetivo = M.objetivo(passo, m.feitos, m.publico) })
end

-- interação com um ponto (botão INTERAGIR)
function Servidor.acao(plr: Player, ponto: any, valor: any)
	local g = grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m or type(ponto) ~= "string" then
		return
	end
	local m = g.m
	local passo = M.passo(m.n, m.i)
	if not passo then
		return
	end
	if passo.tipo == "achar" then
		if table.find(passo.falsos or {}, ponto) then
			enviar(g, "m_falso", { ponto = ponto })
			return
		end
		if not M.infoPonto(passo, ponto) or m.feitos[ponto] then
			return
		end
		if passo.respostas and passo.respostas[ponto] ~= valor then
			enviar(g, "m_errou", { ponto = ponto, motivo = "dono" })
			return
		end
		feito(g, plr, ponto)
		if passo.perseguicao and not m.perseguindo then
			local n = 0
			for _ in m.feitos do
				n += 1
			end
			if n == 2 then
				m.perseguindo = true
				task.spawn(perseguir, g, m.token)
			end
		end
		for _, p in passo.pontos do
			if not m.feitos[p.id] then
				return
			end
		end
		local token = m.token
		task.delay(1.4, function()
			if valido(g, token) then
				avancar(g)
			end
		end)
	elseif passo.tipo == "ordem" then
		if not M.infoPonto(passo, ponto) or m.feitos[ponto] then
			return
		end
		table.insert(m.seq, ponto)
		local r = M.conferirOrdem(passo, m.seq)
		if r == "errado" then
			m.seq = {}
			m.feitos = {}
			enviar(g, "m_errou", { ponto = ponto, motivo = "ordem" })
		else
			feito(g, plr, ponto)
			if r == "certo" then
				local token = m.token
				task.delay(1.4, function()
					if valido(g, token) then
						avancar(g)
					end
				end)
			end
		end
	end
end

function Servidor.codigo(plr: Player, ponto: any, texto: any)
	local g = grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m or type(texto) ~= "string" then
		return
	end
	local m = g.m
	local passo = M.passo(m.n, m.i)
	if not passo or passo.tipo ~= "codigo" or not passo.ponto or passo.ponto.id ~= ponto or m.feitos[ponto] then
		return
	end
	if string.sub(texto, 1, 8) == passo.codigo then
		feito(g, plr, ponto)
		local token = m.token
		task.delay(1.2, function()
			if valido(g, token) then
				avancar(g)
			end
		end)
	else
		if remoto then
			remoto:FireClient(plr, "m_errou", { ponto = ponto, motivo = "codigo" })
		end
	end
end

function Servidor.esconder(plr: Player, spot: any)
	local g = grupoDe(plr)
	if not g or not g.m or not g.m.esc then
		return
	end
	if spot == nil then
		g.m.esc.escondidos[plr] = nil
	elseif type(spot) == "string" then
		g.m.esc.escondidos[plr] = spot
	end
end

function Servidor.distrair(plr: Player)
	local g = grupoDe(plr)
	if not g or not g.m or not g.m.esc or g.m.esc.distraido then
		return
	end
	if g.escolhas and g.escolhas[plr] ~= "KE" then
		return -- só o Keko joga brinquedos para distrair
	end
	g.m.esc.distraido = true
	enviar(g, "m_distraido", { por = plr.UserId })
end

function Servidor.sentar(plr: Player, sentado: any)
	local g = grupoDe(plr)
	if not g or not g.m or not g.m.cad then
		return
	end
	local cad = g.m.cad
	if sentado == true then
		cad.sentados[plr] = true
	else
		cad.sentados[plr] = nil
	end
	local mapa = {}
	for p in cad.sentados do
		if g.escolhas and g.escolhas[p] then
			mapa[g.escolhas[p]] = p.UserId
		end
	end
	enviar(g, "m_sentados", { mapa = mapa })
	if todosSentados(g) and not cad.contando then
		task.spawn(contar, g, g.m.token)
	end
end

function Servidor.olhou(plr: Player)
	local g = grupoDe(plr)
	if g and g.m and g.m.cad and g.m.cad.contando then
		g.m.cad.recomecar = true
	end
end

-- reenvia tudo para quem acabou de (re)nascer no meio de uma missão
function Servidor.sincronizar(plr: Player)
	local g = grupoDe(plr)
	if not g or g.fase ~= "missao" or not g.m or not remoto then
		return
	end
	local missao = M.missao(g.m.n)
	remoto:FireClient(plr, "m_missao", { n = g.m.n, cenario = missao.cenario, reentrada = true })
	task.delay(2, function()
		if remoto and plr.Parent and g.m then
			remoto:FireClient(plr, "m_passo", estadoPublico(g))
		end
	end)
end

function Servidor.configurar(r: RemoteEvent, achar: (Player) -> any, aoSalvar: (Player, number) -> (), aoTerminar: (Player) -> ())
	remoto = r
	grupoDe = achar
	salvar = aoSalvar
	terminou = aoTerminar
end

local _ = Players
return Servidor
