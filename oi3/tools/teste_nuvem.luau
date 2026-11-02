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
	-- personagens: avatares do Roblox montados SÓ com IDs do catálogo (confere cada item de verdade)
	checar("personagens", function()
		local Atores = require(ServerScriptService.OI3_Servidor.Atores)
		local Animacoes = require(OI3.Animacoes)
		local Config = require(OI3.Config)
		local relatorio = {}
		local carregadas = 0
		for _, cod in { "VO", "KE", "NI", "ME" } do
			local m, erro = Atores.montar(cod)
			if not m then
				relatorio[cod] = "falhou: " .. tostring(erro)
				continue
			end
			local r = Config.ROUPAS[cod]
			local acessorios, roupas = 0, 0
			for _, x in m:GetChildren() do
				if x:IsA("Accessory") or (x:IsA("Folder") and x:GetAttribute("OI3_Rosto")) then
					acessorios += 1
				elseif x:IsA("Shirt") or x:IsA("Pants") then
					roupas += 1
				end
			end
			local esperados = #(r.cabelo or {}) + #(r.chapeu or {}) + #(r.rostoAcessorio or {})
			relatorio[cod] = string.format("roupas %d/2, acessórios %d/%d", roupas, acessorios, esperados)
			-- AJUSTE-8: o rosto tem que ficar NA FRENTE da cabeça (senão some e a cabeça fica só amarela)
			local Personagens = require(OI3.Personagens)
			local cabeca = m:FindFirstChild("Head")
			local function medir(pasta)
				local malha = pasta and pasta:FindFirstChild("RostoMalha")
				if not (cabeca and malha) then
					return "sem rosto"
				end
				local s = m:GetAttribute("Escala") or 1
				local frente = Personagens.frenteDoRosto(cabeca.CFrame:ToObjectSpace(malha.CFrame), malha.Size)
				return if frente <= -0.625 * s then "visível" else string.format("ESCONDIDO (%.2f)", frente)
			end
			if (r.rostoAcessorio and #r.rostoAcessorio > 0) then
				local base = nil
				for _, x in m:GetChildren() do
					if x:GetAttribute("OI3_Rosto") then
						base = x
					end
				end
				relatorio[cod] ..= ", rosto " .. medir(base)
			end
			if cod == "ME" then
				local reacoes = {}
				for nome, id in Config.ROSTOS_REACAO or {} do
					local a = Atores.montarRosto(id)
					if not a then
						table.insert(reacoes, nome .. " não carregou")
						continue
					end
					local pasta = Personagens.encaixarRosto(m, a, nil, "OI3_Reacao")
					table.insert(reacoes, nome .. " " .. medir(pasta))
					if pasta then
						pasta:Destroy()
					end
				end
				table.sort(reacoes)
				res.info.reacoes = table.concat(reacoes, ", ")
			end
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				local animador = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
				local a = Instance.new("Animation")
				a.AnimationId = Animacoes.andar
				if pcall(function()
					animador:LoadAnimation(a)
				end) then
					carregadas += 1
				end
			end
			m:Destroy()
		end
		res.info.atores = relatorio
		res.info.animacoesCarregadas = carregadas
	end)
	-- AJUSTE-8: os cenários das missões montam no Roblox de verdade (fontes, materiais, peças)
	checar("missoes", function()
		local MM = require(OI3.MissoesMapa)
		local M = require(OI3.Missoes)
		local total = 0
		for _, nome in MM.CENARIOS do
			local pasta = Instance.new("Folder")
			local modelo = MM.construir(nome, pasta)
			for _, d in modelo:GetDescendants() do
				if d:IsA("BasePart") then
					total += 1
				end
			end
			pasta:Destroy()
		end
		res.info.missoes = M.TOTAL
		res.info.pecasMissoes = total
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
