-- OI3 :: teste isolado na nuvem (Luau Execution). Roda numa versão SALVA (não publicada).
-- Se algo falhar aqui, o instalador NÃO publica.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local res = { ok = true, erros = {}, info = {} }
local function falha(msg)
	res.ok = false
	table.insert(res.erros, msg)
end
local function checar(nome, fn)
	local ok, err = pcall(fn)
	if not ok then
		falha(nome .. ": " .. tostring(err))
	end
end

local OI3 = ReplicatedStorage:FindFirstChild("OI3")
if not OI3 then
	falha("ReplicatedStorage.OI3 não existe")
else
	checar("config", function()
		local Config = require(OI3:FindFirstChild("Config"))
		res.info.revisao = Config.REVISAO
	end)
	-- compila e carrega todos os módulos
	local total = 0
	for _, m in OI3:GetDescendants() do
		if m:IsA("ModuleScript") then
			total += 1
			checar("require " .. m:GetFullName(), function()
				require(m)
			end)
		end
	end
	local srv = ServerScriptService:FindFirstChild("OI3_Servidor")
	if not srv then
		falha("ServerScriptService.OI3_Servidor não existe")
	else
		for _, m in srv:GetChildren() do
			if m:IsA("ModuleScript") then
				total += 1
				checar("require " .. m:GetFullName(), function()
					require(m)
				end)
			end
		end
	end
	res.info.modulos = total
	-- monta o orfanato numa pasta de teste
	checar("mapa", function()
		local Mapa = require(OI3.Mapa)
		local pasta = Instance.new("Folder")
		pasta.Name = "OI3_TesteMapa"
		pasta.Parent = workspace
		local modelo = Mapa.construir(pasta)
		res.info.pecasMapa = #modelo:GetDescendants()
		local P = Mapa.pontos()
		assert(P.spawn and P.espMenino, "pontos do mapa")
		pasta:Destroy()
	end)
	-- terreno
	checar("terreno", function()
		require(OI3.Mapa).construirTerreno(workspace.Terrain)
	end)
	-- personagens e animações R6
	checar("personagens", function()
		local Personagens = require(OI3.Personagens)
		local Animacoes = require(OI3.Animacoes)
		local carregadas = 0
		for _, cod in { "VO", "KE", "NI", "ME" } do
			local m = Personagens.criar(cod)
			m.Parent = workspace
			local hum = m:FindFirstChildOfClass("Humanoid")
			local animador = hum and hum:FindFirstChildOfClass("Animator")
			assert(animador, cod .. " sem Animator")
			local a = Instance.new("Animation")
			a.AnimationId = Animacoes.andar
			local ok = pcall(function()
				animador:LoadAnimation(a)
			end)
			if ok then
				carregadas += 1
			end
			m:Destroy()
		end
		res.info.animacoesCarregadas = carregadas
		local c = Personagens.criarCriatura()
		c:Destroy()
	end)
	-- cenário do menu (só as peças)
	checar("menu", function()
		local MenuCena = require(OI3.Cliente.MenuCena)
		local pasta = Instance.new("Folder")
		local refs = MenuCena.construirCenario(pasta)
		res.info.pecasMenu = refs.contagem
		pasta:Destroy()
	end)
	checar("botoes", function()
		local B = require(OI3.Cliente.Botoes3D)
		local lay = B.calcularLayout(4, 844, 390, 52)
		local p = B.montarPecas({ id = "t", texto = "T", cor = Color3.new(1, 0, 0), aoClicar = function() end }, lay.L, lay.A)
		p.modelo:Destroy()
	end)
	-- lanterna da primeira pessoa (só as peças; a luz liga no celular do jogador)
	checar("lanterna", function()
		local PP = require(OI3.Cliente.PrimeiraPessoa)
		local m = PP.montarLanterna()
		res.info.pecasLanterna = #m:GetDescendants()
		m:Destroy()
	end)
	-- sons: cada áudio carrega no Roblox? "_controle" é um som público do próprio Roblox:
	-- se ele carrega e o nosso não, o áudio está bloqueado (falta liberar para o jogo)
	checar("sons", function()
		local R = require(OI3.Recursos)
		local lista = { _controle = "rbxassetid://12222216" }
		if type(R.audio) == "table" then
			for chave, id in R.audio do
				local n = tonumber(id)
				if n and n > 0 then
					lista[chave] = "rbxassetid://" .. n
				end
			end
		end
		local sons = {}
		for chave, id in lista do
			local s = Instance.new("Sound")
			s.Name = "OI3_TesteSom_" .. chave
			s.SoundId = id
			s.Volume = 0
			s.Parent = workspace
			sons[chave] = s
		end
		local t0 = os.clock()
		while os.clock() - t0 < 20 do
			local todos = true
			for _, s in sons do
				if not s.IsLoaded then
					todos = false
					break
				end
			end
			if todos then
				break
			end
			task.wait(0.25)
		end
		local saida = {}
		for chave, s in sons do
			saida[chave] = if s.IsLoaded then math.floor(s.TimeLength * 10 + 0.5) / 10 else -1
			s:Destroy()
		end
		res.info.sons = saida
	end)
	checar("recursos", function()
		local R = require(OI3.Recursos)
		res.info.audio = R.audio
		res.info.recursosRevisao = R.revisao
	end)
	-- o script do servidor costuma rodar junto: só informa
	res.info.remotos = OI3:FindFirstChild("Remotos") ~= nil
	res.info.orfanato = workspace:FindFirstChild("Orfanato") ~= nil
end

return HttpService:JSONEncode(res)
