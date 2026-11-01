-- OI3 :: dados salvos do jogador (DataStore). Nunca apaga: só mescla campos.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("OI3"):WaitForChild("Config"))

local Dados = {}

type Entrada = { dados: { [string]: any }, carregado: boolean, sujo: boolean, falhou: boolean }

local loja: DataStore? = nil
local cache: { [Player]: Entrada } = {}

local function padrao(): { [string]: any }
	return { versao = 1, config = table.clone(Config.PADRAO), viuIntro = false }
end

local function chaveDe(plr: Player): string
	return "u_" .. tostring(plr.UserId)
end

function Dados.iniciar()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE)
	end)
	if ok then
		loja = ds
	else
		warn("[OI3] DataStore indisponível; configurações não serão salvas nesta sessão.")
	end
	game:BindToClose(function()
		for plr in cache do
			Dados.salvar(plr)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for plr in cache do
				Dados.salvar(plr)
			end
		end
	end)
end

function Dados.carregar(plr: Player)
	local entrada: Entrada = { dados = padrao(), carregado = false, sujo = false, falhou = false }
	cache[plr] = entrada
	if not loja then
		entrada.carregado = true
		return
	end
	for tentativa = 1, 3 do
		local ok, valor = pcall(function()
			return (loja :: DataStore):GetAsync(chaveDe(plr))
		end)
		if ok then
			if type(valor) == "table" then
				local d = padrao()
				for k, v in valor do
					d[k] = v
				end
				d.config = Config.sanitizarConfig(valor.config)
				d.viuIntro = valor.viuIntro == true
				entrada.dados = d
			end
			entrada.carregado = true
			return
		end
		task.wait(1.5 * tentativa)
	end
	-- falhou: usa padrão mas NÃO salva por cima (protege o progresso existente)
	entrada.falhou = true
	entrada.carregado = true
end

function Dados.obter(plr: Player): { [string]: any }
	local t0 = os.clock()
	while (not cache[plr] or not cache[plr].carregado) and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	local e = cache[plr]
	if not e then
		return padrao()
	end
	return e.dados
end

function Dados.definirConfig(plr: Player, cfg: any)
	local e = cache[plr]
	if not e or not e.carregado then
		return
	end
	e.dados.config = Config.sanitizarConfig(cfg)
	e.sujo = true
end

function Dados.marcarIntro(plr: Player)
	local e = cache[plr]
	if e and e.carregado and not e.dados.viuIntro then
		e.dados.viuIntro = true
		e.sujo = true
	end
end

function Dados.salvar(plr: Player)
	local e = cache[plr]
	if not e or not loja or not e.sujo or e.falhou then
		return
	end
	local copia = {
		versao = 1,
		config = table.clone(e.dados.config),
		viuIntro = e.dados.viuIntro == true,
	}
	local ok, err = pcall(function()
		(loja :: DataStore):UpdateAsync(chaveDe(plr), function(antigo)
			local novo = if type(antigo) == "table" then antigo else {}
			for k, v in copia do
				novo[k] = v
			end
			return novo
		end)
	end)
	if ok then
		e.sujo = false
	else
		warn("[OI3] não consegui salvar:", err)
	end
end

function Dados.salvarESoltar(plr: Player)
	Dados.salvar(plr)
	cache[plr] = nil
end

return Dados
