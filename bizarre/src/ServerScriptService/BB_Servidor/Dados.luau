-- BIZARRE BATTLEGROUNDS :: estatísticas salvas (abates, mortes, melhor sequência) e placar
-- NUNCA apaga nada: cada salvamento SOMA o que aconteceu na partida ao que já estava guardado.
-- AJUSTE7: salvamentos em fila (um por vez por jogador) e cada lote tem número: se o autosave,
-- a saída e o desligamento do servidor mandarem o mesmo lote, ele só soma UMA vez.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Dados = {}

local NOME_STORE = "BB_Jogadores_v1"
local store: any = nil
local sessao: { [any]: any } = {}
local jobId = tostring(game.JobId or "")
local servidorId = if jobId ~= "" then string.sub(jobId, 1, 12) else ("s" .. math.random(1, 1e9))
local contadorLote = 0
local LOTES_GUARDADOS = 30

-- soma um lote nos dados salvos, uma vez só (os números dos últimos lotes ficam guardados)
function Dados._aplicarLote(velho: any, lote: any): (any, boolean)
	local v = if type(velho) == "table" then velho else {}
	local lotes = if type(v.lotes) == "table" then v.lotes else {}
	for _, id in lotes do
		if id == lote.id then
			return v, false
		end
	end
	v.abates = (v.abates or 0) + lote.abates
	v.mortes = (v.mortes or 0) + lote.mortes
	v.dano = math.floor((v.dano or 0) + lote.dano)
	v.melhorSequencia = math.max(v.melhorSequencia or 0, lote.melhor)
	table.insert(lotes, lote.id)
	while #lotes > LOTES_GUARDADOS do
		table.remove(lotes, 1)
	end
	v.lotes = lotes
	v.versao = 2
	return v, true
end

-- testes: troca o DataStore por um falso e mexe na sessão
function Dados._usarStore(s: any)
	store = s
end
function Dados._sessao(jogador: any, s: any?)
	if s then
		sessao[jogador] = s
	end
	return sessao[jogador]
end

local function chave(jogador: Player): string
	return "u_" .. jogador.UserId
end

local function obterStore(): DataStore?
	if store then
		return store
	end
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(NOME_STORE)
	end)
	if ok then
		store = s
	end
	return store
end

local function placar(jogador: Player, s: any)
	local ls = jogador:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = jogador
	end
	local abates = ls:FindFirstChild("Abates") :: IntValue?
	if not abates then
		abates = Instance.new("IntValue")
		abates.Name = "Abates"
		abates.Parent = ls
	end
	local seq = ls:FindFirstChild("Sequência") :: IntValue?
	if not seq then
		seq = Instance.new("IntValue")
		seq.Name = "Sequência"
		seq.Parent = ls
	end
	abates.Value = (s.base.abates or 0) + s.delta.abates + (if s.pendente then s.pendente.abates else 0)
	seq.Value = s.sequencia
end

function Dados.carregar(jogador: Player)
	local s = {
		base = { abates = 0, mortes = 0, melhorSequencia = 0 },
		delta = { abates = 0, mortes = 0, dano = 0 },
		sequencia = 0,
		melhorSequencia = 0,
		carregou = false,
	}
	sessao[jogador] = s
	placar(jogador, s)
	task.spawn(function()
		local ds = obterStore()
		if not ds then
			return
		end
		for tentativa = 1, 3 do
			local ok, valor = pcall(function()
				return ds:GetAsync(chave(jogador))
			end)
			if ok then
				if type(valor) == "table" then
					s.base = valor
				end
				s.carregou = true
				if jogador.Parent then
					placar(jogador, s)
					jogador:SetAttribute("BB_MelhorSequencia", (valor and valor.melhorSequencia) or 0)
				end
				return
			end
			task.wait(tentativa * 2)
		end
	end)
end

function Dados.salvar(jogador: any)
	local s = sessao[jogador]
	if not s or not s.carregou then
		return
	end
	local ds = obterStore()
	if not ds then
		return
	end
	-- um salvamento por vez: quem chega no meio pede para salvar de novo no fim
	if s.salvando then
		s.deNovo = true
		return
	end
	s.salvando = true
	repeat
		s.deNovo = false
		-- lote que falhou antes vai primeiro, com o MESMO número (não duplica se já tinha entrado)
		local lote = s.pendente
		if not lote then
			local d = s.delta
			if d.abates == 0 and d.mortes == 0 and d.dano == 0 and s.melhorSequencia <= (s.base.melhorSequencia or 0) then
				break
			end
			contadorLote += 1
			lote = {
				id = string.format("%s:%s:%d", servidorId, tostring(jogador.UserId), contadorLote),
				abates = d.abates,
				mortes = d.mortes,
				dano = d.dano,
				melhor = s.melhorSequencia,
			}
			d.abates -= lote.abates
			d.mortes -= lote.mortes
			d.dano -= lote.dano
			s.pendente = lote
		end
		local ok = pcall(function()
			ds:UpdateAsync(chave(jogador), function(velho)
				local v, aplicou = Dados._aplicarLote(velho, lote)
				if not aplicou then
					return nil -- já estava somado: não escreve de novo
				end
				return v
			end)
		end)
		if ok then
			s.pendente = nil
			s.base.abates = (s.base.abates or 0) + lote.abates
			s.base.mortes = (s.base.mortes or 0) + lote.mortes
			s.base.melhorSequencia = math.max(s.base.melhorSequencia or 0, lote.melhor)
		else
			break -- fica pendente; o próximo salvamento manda o mesmo lote
		end
	until not s.deNovo
	s.salvando = false
end

-- espera os salvamentos em andamento terminarem (saída e desligamento)
local function esperarSalvar(jogador: any, limite: number)
	local inicio = os.clock()
	local s = sessao[jogador]
	while s and (s.salvando or s.pendente) and os.clock() - inicio < limite do
		if not s.salvando and s.pendente then
			Dados.salvar(jogador)
		end
		task.wait(0.5)
	end
end
Dados._esperarSalvar = esperarSalvar

function Dados.abate(jogador: Player): number
	local s = sessao[jogador]
	if not s then
		return 0
	end
	s.delta.abates += 1
	s.sequencia += 1
	s.melhorSequencia = math.max(s.melhorSequencia, s.sequencia)
	placar(jogador, s)
	return s.sequencia
end

function Dados.morte(jogador: Player)
	local s = sessao[jogador]
	if not s then
		return
	end
	s.delta.mortes += 1
	s.sequencia = 0
	placar(jogador, s)
end

function Dados.dano(jogador: Player, qtd: number)
	local s = sessao[jogador]
	if s then
		s.delta.dano += qtd
	end
end

function Dados.sequencia(jogador: Player): number
	local s = sessao[jogador]
	return if s then s.sequencia else 0
end

function Dados.iniciar()
	Players.PlayerAdded:Connect(Dados.carregar)
	for _, p in Players:GetPlayers() do
		if not sessao[p] then
			Dados.carregar(p)
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		task.spawn(function()
			Dados.salvar(p)
			esperarSalvar(p, 20)
			sessao[p] = nil
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in Players:GetPlayers() do
				pcall(Dados.salvar, p)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for p in sessao do
			task.spawn(pcall, Dados.salvar, p)
		end
		local inicio = os.clock()
		for p in sessao do
			esperarSalvar(p, math.max(1, 25 - (os.clock() - inicio)))
		end
	end)
end

return Dados
