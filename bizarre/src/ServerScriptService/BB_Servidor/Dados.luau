-- BIZARRE BATTLEGROUNDS :: estatísticas salvas (abates, mortes, melhor sequência) e placar
-- NUNCA apaga nada: cada salvamento SOMA o que aconteceu na partida ao que já estava guardado.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Dados = {}

local NOME_STORE = "BB_Jogadores_v1"
local store: DataStore? = nil
local sessao: { [Player]: any } = {}

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
	abates.Value = (s.base.abates or 0) + s.delta.abates
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

function Dados.salvar(jogador: Player)
	local s = sessao[jogador]
	if not s or not s.carregou then
		return
	end
	local ds = obterStore()
	if not ds then
		return
	end
	local d = s.delta
	if d.abates == 0 and d.mortes == 0 and d.dano == 0 and s.melhorSequencia <= (s.base.melhorSequencia or 0) then
		return
	end
	local enviado = { abates = d.abates, mortes = d.mortes, dano = d.dano }
	local melhor = s.melhorSequencia
	local ok = pcall(function()
		ds:UpdateAsync(chave(jogador), function(velho)
			local v = if type(velho) == "table" then velho else {}
			v.abates = (v.abates or 0) + enviado.abates
			v.mortes = (v.mortes or 0) + enviado.mortes
			v.dano = math.floor((v.dano or 0) + enviado.dano)
			v.melhorSequencia = math.max(v.melhorSequencia or 0, melhor)
			v.versao = 1
			return v
		end)
	end)
	if ok then
		d.abates -= enviado.abates
		d.mortes -= enviado.mortes
		d.dano -= enviado.dano
		s.base.abates = (s.base.abates or 0) + enviado.abates
		s.base.mortes = (s.base.mortes or 0) + enviado.mortes
		s.base.melhorSequencia = math.max(s.base.melhorSequencia or 0, melhor)
	end
end

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
		Dados.salvar(p)
		sessao[p] = nil
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
		for _, p in Players:GetPlayers() do
			pcall(Dados.salvar, p)
		end
	end)
end

return Dados
