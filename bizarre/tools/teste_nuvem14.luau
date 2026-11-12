-- AJ14: cfg é fornecido pelo instalador; nenhum SavePlaceAsync ou publicação neste script.
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local BB14 = assert(RS:FindFirstChild("BB"), "Pastas do Bizarre ausentes")
local Config14 = require(BB14:FindFirstChild("Config"))
local Perfil14 = require(BB14:FindFirstChild("PerfilCombate14"))
local Receitas14 = require(BB14:FindFirstChild("VFXReceitas"))
local Verificacao14 = require(BB14:FindFirstChild("Validacao14"))
local report14 = Verificacao14.executar(game,cfg,Config14,Receitas14,Perfil14)
if not report14.passed then return report14 end
-- Política real: janela única, sequência idempotente e exceção aérea isolada.
local policyOK,policyError = pcall(function()
 local Regras14 = require(BB14.Regras)
 local state = Regras14.novoEstado()
 local policy = Perfil14.novo()
 assert(Perfil14.sequencia(policy,1) and not Perfil14.sequencia(policy,1),"seq duplicada aceita")
 local action = Perfil14.iniciar(policy,state,"m1",4,10,"STAR_PLATINUM",1)
 local target = {}
 Perfil14.vincular(policy,action,target,10.16)
 assert(Perfil14.reservar(policy,state,10.33,"STAR_PLATINUM")==nil,"seguimento abriu cedo")
 assert(Perfil14.reservar(policy,state,10.34,"STAR_PLATINUM")~=nil,"seguimento nao abriu")
 assert(Perfil14.reservar(policy,state,10.35,"STAR_PLATINUM")==nil,"segundo seguimento aceito")
 state.m1ProntoEm=11.1
 Perfil14.seguimento(state,10.4)
 assert(state.m1ProntoEm>=11.1,"seguimento zerou a recarga original")
end)
if not policyOK then report14.passed=false;table.insert(report14.erros,"Politica de combate: "..tostring(policyError));return report14 end
report14.info.airlink="janela unica e recarga original verificadas no modulo do jogo"
-- BB14_LEGACY_BEGIN: mantém as verificações de mapa, seis kits, física e sessões originais.
local original = (function()
-- BIZARRE BATTLEGROUNDS :: teste isolado na nuvem (Luau Execution) numa versão SALVA (não publicada).
-- Monta tudo de verdade no servidor do Roblox e faz uma luta de teste com TODOS os golpes.
-- Se aparecer erro aqui, o instalador NÃO publica.

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")

local res = { ok = true, erros = {}, avisos = {}, info = {} }
local function falha(msg: string)
	res.ok = false
	table.insert(res.erros, msg)
end
local function aviso(msg: string)
	table.insert(res.avisos, msg)
end
local function checar(nome: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		falha(nome .. ": " .. tostring(err))
	end
	return ok
end

-- erros dos golpes (eles rodam em paralelo) aparecem no log: guardamos para o relatório
local logsRuins = {}
LogService.MessageOut:Connect(function(msg, tipo)
	if tipo == Enum.MessageType.MessageError or (tipo == Enum.MessageType.MessageWarning and string.find(msg, "[BB]", 1, true)) then
		if string.find(msg, "BB", 1, true) then
			table.insert(logsRuins, string.sub(msg, 1, 300))
		end
	end
end)

local BB = ReplicatedStorage:FindFirstChild("BB")
local SRV = ServerScriptService:FindFirstChild("BB_Servidor")
if not BB or not SRV then
	falha("pastas BB/BB_Servidor não existem no place")
	return HttpService:JSONEncode(res)
end

-- 1) todos os módulos carregam
local total = 0
for _, pasta in { BB, SRV } do
	for _, m in pasta:GetDescendants() do
		if m:IsA("ModuleScript") then
			total += 1
			checar("require " .. m:GetFullName(), function()
				require(m)
			end)
		end
	end
end
res.info.modulos = total
if not res.ok then
	return HttpService:JSONEncode(res)
end

local Config = require(BB.Config)
local Regras = require(BB.Regras)
local Stands = require(BB.Stands)
local Golpes = require(BB.Golpes)
local Sons = require(BB.Sons)
local Rig = require(BB.Rig)
local Lutadores = require(SRV.Lutadores)
local Fisica = require(SRV.Fisica)
local Mapa = require(SRV.Mapa)
local Combate = require(SRV.Combate)
local Executores = require(SRV.Executores)
local StandModelos = require(SRV.StandModelos)
res.info.revisao = Config.REVISAO

-- 2) o servidor do jogo ligou? (se não, ligamos o necessário aqui)
local t0 = os.clock()
while not workspace:GetAttribute("BB_Pronto") and os.clock() - t0 < 12 do
	task.wait(0.25)
end
local mainRodou = workspace:GetAttribute("BB_Pronto") == true
res.info.servidorLigou = mainRodou
local efeitoFalso = Instance.new("RemoteEvent")
if not mainRodou then
	checar("ligar sistemas", function()
		local remotos = { Efeito = efeitoFalso, Privado = Instance.new("RemoteEvent"), Acao = Instance.new("RemoteEvent") }
		Fisica.iniciar(remotos.Privado)
		Mapa.construir(workspace)
		Mapa.iniciar(remotos.Efeito)
		Executores.iniciar(remotos)
		Combate.iniciar(remotos, Executores, function() end)
	end)
end

-- 3) a cidade (Morioh, do ChatGPT)
checar("mapa", function()
	local morioh = workspace:FindFirstChild("Morioh")
	assert(morioh, "o mapa Morioh não está no place")
	assert(Mapa.modo == "morioh", "o servidor não entrou no modo Morioh")
	local destrutiveis = CollectionService:GetTagged("MoriohDestructible")
	res.info.quebraveis = #destrutiveis
	res.info.spawns = #Mapa.spawns()
	assert(#destrutiveis > 50000, "poucas peças quebráveis: " .. #destrutiveis)
	assert(#Mapa.spawns() >= 8 and Mapa.treino(), "spawns/treino")
	res.info.streaming = workspace.StreamingEnabled
	if (workspace:GetAttribute("BB_MapaRemovidas") or 0) == 0 and (workspace:GetAttribute("BB_MapaSemSombra") or 0) == 0 then
		res.info.simplificado = "mapa intacto: nada removido, sombras originais (AJUSTE-10)"
	else
		res.info.simplificado = string.format("%s enfeites sem colisão retirados, %s sem sombra", tostring(workspace:GetAttribute("BB_MapaRemovidas")), tostring(workspace:GetAttribute("BB_MapaSemSombra")))
	end
end)

-- 4) os Stands (corpos do catálogo)
checar("stands", function()
	local t1 = os.clock()
	while not workspace:GetAttribute("BB_StandsProntos") and os.clock() - t1 < 45 do
		task.wait(0.5)
	end
	if not workspace:GetAttribute("BB_StandsProntos") then
		StandModelos.preparar()
	end
	local pasta = ReplicatedStorage:FindFirstChild("BB_Stands")
	assert(pasta, "BB_Stands não existe")
	local rel = {}
	for _, id in Stands.ORDEM do
		local m = pasta:FindFirstChild(id)
		assert(m, "Stand sem corpo: " .. id)
		local juntas = 0
		for _, d in m:GetDescendants() do
			if d:IsA("Motor6D") then
				juntas += 1
			end
		end
		rel[id] = string.format("%s, juntas %d", tostring(m:GetAttribute("Origem")), juntas)
		if juntas < 6 then
			falha("Stand " .. id .. " com poucas juntas (" .. juntas .. ")")
		end
		if not m:FindFirstChild("Torso") then
			aviso("Stand " .. id .. " não é R6")
		end
	end
	res.info.stands = rel
end)

-- 5) luta de teste: dois bonecos no meio da praça
local pastaTeste = Instance.new("Folder")
pastaTeste.Name = "BB_TesteNuvem"
pastaTeste.Parent = workspace
local function lutador(nome: string, pos: Vector3, olhar: Vector3, stand: string)
	local m = Rig.montarR6(nome, nil, true)
	m:PivotTo(CFrame.lookAt(pos, pos + olhar))
	m.Parent = pastaTeste
	pcall(function()
		(m:FindFirstChild("HumanoidRootPart") :: BasePart):SetNetworkOwner(nil)
	end)
	Fisica.grupo(m, Fisica.GRUPOS.lutador)
	local l = Lutadores.criar(m, nil, stand, { bot = true, nome = nome })
	l.estado.semRecarga = true
	return l
end

-- numa rua de Morioh (asfalto em Y = 0, conferido sem nada em volta)
local A_POS = Vector3.new(0, 3.2, 45.5)
local V_POS = Vector3.new(0, 3.2, 40)
local atk = lutador("TesteAtacante", A_POS, Vector3.new(0, 0, -1), Stands.ORDEM[1])
local vit = lutador("TesteVitima", V_POS, Vector3.new(0, 0, 1), Stands.ORDEM[1])
vit.imortal = true

local function arrumar()
	for _, l in { atk, vit } do
		-- Invalida a acao anterior antes de substituir seu estado no boneco de teste.
		Combate.cancelar(l)
		Fisica.soltar(l)
		Fisica.limparEmpurroes(l.raiz)
		l.modelo:SetAttribute("BB_Ragdoll", 0)
		l.modelo:SetAttribute("BB_Congelado", nil)
		l.modelo:SetAttribute("BB_Pedra", nil)
		l.modelo:SetAttribute("BB_Preso", nil)
		l.agarradoPor = nil
		l.congeladoPor = nil
		l.filaTempo = nil
		local sem = l.estado.semRecarga
		local desp = l.estado.despertoAte
		l.estado = Regras.novoEstado()
		l.estado.semRecarga = sem
		l.estado.despertoAte = desp
		l.hum.Health = l.hum.MaxHealth
		pcall(function()
			l.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
	atk.modelo:PivotTo(CFrame.lookAt(A_POS, A_POS + Vector3.new(0, 0, -1)))
	vit.modelo:PivotTo(CFrame.lookAt(V_POS, V_POS + Vector3.new(0, 0, 1)))
	atk.dir = Vector3.new(0, 0, -1)
	atk.dirT = workspace:GetServerTimeNow()
	task.wait(0.15)
end

checar("combo de M1", function()
	arrumar()
	for _ = 1, 4 do
		Combate.m1(atk, {})
		task.wait(Config.M1.intervalo + 0.05)
	end
	task.wait(0.2)
	local dano = vit.hum.MaxHealth - vit.hum.Health
	res.info.m1 = string.format("%.1f de dano, ragdoll %s", dano, tostring((vit.modelo:GetAttribute("BB_Ragdoll") or 0) > 0))
	if dano <= 0 then
		aviso("M1 não acertou o boneco de teste (posição?)")
	end
end)

checar("bloqueio e parry", function()
	arrumar()
	Combate.bloquear(vit, true)
	task.wait(0.4)
	local r = Combate.acertar(atk, vit, { dano = 5, tipo = "melee", atordoar = 0.5 }, { dir = Vector3.new(0, 0, -1) })
	assert(r == "bloqueado", "bloqueio de frente deu " .. tostring(r))
	Combate.bloquear(vit, false)
	task.wait(0.05)
	Combate.bloquear(vit, true)
	local p = Combate.acertar(atk, vit, { dano = 5, tipo = "melee", atordoar = 0.5 }, { dir = Vector3.new(0, 0, -1) })
	assert(p == "parry", "parry deu " .. tostring(p))
	Combate.bloquear(vit, false)
end)

-- todos os golpes de todos os Stands
local golpesInfo = {}
local erroAntes = #logsRuins
for _, id in Stands.ORDEM do
	local s = Stands.get(id)
	checar("trocar para " .. id, function()
		Lutadores.trocarStand(atk, id)
		atk.estado.semRecarga = true
	end)
	for _, slot in { 1, 2, 3, 4, "ult" } do
		local g, gid = Golpes.doSlot(s, slot)
		if not g or not gid then
			falha(id .. ": slot " .. tostring(slot) .. " sem golpe")
			continue
		end
		checar("golpe " .. gid, function()
			arrumar()
			if slot == "ult" then
				atk.estado.despertar = Config.DESPERTAR.max
				Regras.despertar(atk.estado, workspace:GetServerTimeNow())
			end
			-- a cura precisa de vida faltando
			if g.tipo == "cura" then
				atk.hum.Health = 50
			end
			local antes = #logsRuins
			Combate.golpe(atk, slot, {})
			-- AJUSTE-8: espera o golpe inteiro (rajadas e tempo parado duram o som do anime) e vê se o
			-- boneco ficou parado no tempo
			local espera = math.min(8.5, (g.trava or 1) + 0.9 + ((g.tempo and (g.tempo.t + g.tempo.duracao)) or 0))
			local congelou = false
			local fimEspera = os.clock() + espera
			while os.clock() < fimEspera do
				if vit.modelo:GetAttribute("BB_Congelado") then
					congelou = true
				end
				task.wait(0.1)
			end
			local dano = vit.hum.MaxHealth - vit.hum.Health
			local curou = if g.tipo == "cura" then atk.hum.Health - 50 else 0
			golpesInfo[gid] = if g.tipo == "cura" then string.format("curou %.0f", curou) elseif congelou then string.format("%.1f (parou o tempo)", dano) else string.format("%.1f", dano)
			if #logsRuins > antes then
				falha("golpe " .. gid .. " deu erro: " .. logsRuins[#logsRuins])
			end
			if g.tipo ~= "cura" and dano <= 0 and not congelou and g.tipo ~= "contra" and g.tipo ~= "buff" then
				aviso(gid .. " não acertou o boneco de teste")
			end
			atk.estado.despertoAte = 0
		end)
	end
end
res.info.golpes = golpesInfo
local _ = erroAntes

-- contra-ataque de verdade: ativa a postura e alguém bate
checar("contra-ataque", function()
	Lutadores.trocarStand(atk, "SILVER_CHARIOT")
	atk.estado.semRecarga = true
	arrumar()
	Combate.golpe(atk, 3, {})
	task.wait(0.2)
	local r = Combate.acertar(vit, atk, { dano = 5, tipo = "melee", atordoar = 0.5 }, { dir = Vector3.new(0, 0, 1) })
	assert(r == "contra", "a postura de contra não pegou: " .. tostring(r))
	task.wait(0.6)
end)

-- AJUSTE7: duas rajadas de frente se anulam (ORA x MUDA)
checar("clash de rajadas", function()
	Lutadores.trocarStand(atk, "STAR_PLATINUM")
	Lutadores.trocarStand(vit, "THE_WORLD")
	atk.estado.semRecarga = true
	arrumar()
	vit.estado.semRecarga = true
	vit.dir = Vector3.new(0, 0, 1)
	vit.dirT = workspace:GetServerTimeNow()
	Combate.golpe(atk, 1, {})
	Combate.golpe(vit, 1, {})
	local inicioClash = os.clock()
	task.wait(1.3)
	local danoV = vit.hum.MaxHealth - vit.hum.Health
	local danoA = atk.hum.MaxHealth - atk.hum.Health
	res.info.clash = string.format("durante o clash: %.1f e %.1f de dano", danoA, danoV)
	if danoA > 1 or danoV > 1 then
		aviso("clash: as rajadas não se anularam (" .. res.info.clash .. ")")
	end
	-- AJUSTE-8: as rajadas duram o som do anime: espera as duas acabarem antes do próximo teste
	local fimRajadas = math.max(Golpes.get("STAR_PLATINUM_1").trava, Golpes.get("THE_WORLD_1").trava) + 0.6
	task.wait(math.max(0.2, fimRajadas - (os.clock() - inicioClash)))
end)

-- AJUSTE7: dois tempos parados ao mesmo tempo (donos longe um do outro, um alvo no meio)
checar("congelamentos sobrepostos", function()
	arrumar()
	local agoraS = workspace.GetServerTimeNow
	local terc = lutador("TesteDio", Vector3.new(0, 3.2, -150), Vector3.new(0, 0, 1), "THE_WORLD")
	local meio = lutador("TesteMeio", Vector3.new(0, 3.2, -50), Vector3.new(0, 0, 1), "CRAZY_DIAMOND")
	meio.imortal = true
	Lutadores.trocarStand(atk, "STAR_PLATINUM")
	atk.estado.semRecarga = true
	for _, l in { atk, terc } do
		l.estado.despertar = Config.DESPERTAR.max
		Regras.despertar(l.estado, agoraS(workspace))
	end
	-- AJUSTE-8: os tempos vêm dos golpes (o tempo para junto com o som do anime)
	local tp1 = Golpes.get("STAR_PLATINUM_ULT").tempo
	local tp2 = Golpes.get("THE_WORLD_ULT").tempo
	local t0 = os.clock()
	local function ate(t: number)
		local falta = t0 + t - os.clock()
		if falta > 0 then
			task.wait(falta)
		end
	end
	Combate.golpe(atk, "ult", {}) -- 1ª: para o tempo em tp1.t por tp1.duracao
	ate(1)
	Combate.golpe(terc, "ult", {}) -- 2ª: começa 1 s depois
	ate(tp1.t + 0.3)
	local s1 = meio.modelo:GetAttribute("BB_SessaoTempo")
	assert((meio.modelo:GetAttribute("BB_Congelado") or 0) > agoraS(workspace) and s1, "o alvo do meio devia estar parado pela 1ª ULT")
	ate(1 + tp2.t + 0.4) -- a 2ª ULT já começou: o alvo continua sendo da 1ª
	assert(meio.modelo:GetAttribute("BB_SessaoTempo") == s1, "a 2ª ULT sobrescreveu o alvo da 1ª")
	assert(tp1.t + tp1.duracao + 0.5 < 1 + tp2.t + tp2.duracao, "teste: a 1ª ULT precisa acabar antes da 2ª")
	ate(tp1.t + tp1.duracao + 0.5) -- a 1ª acabou; a 2ª continua
	assert(meio.modelo:GetAttribute("BB_Congelado") == nil and not meio.raiz.Anchored, "o alvo da 1ª ULT não foi solto quando ela acabou")
	ate(1 + tp2.t + tp2.duracao + 0.8)
	for _, l in { atk, vit, terc, meio } do
		assert(l.modelo:GetAttribute("BB_Congelado") == nil and not l.raiz.Anchored, l.nome .. " ficou preso no tempo")
	end
	res.info.congelamentos = "2 tempos parados juntos: cada um soltou só os alvos dele"
	for _, l in { terc, meio } do
		Lutadores.remover(l.modelo)
		l.modelo:Destroy()
	end
end)

-- AJ14: foco em funcionalidade/visuais; benchmark de FPS fica para outra etapa.

-- 6) o mapa quebra e volta
checar("mapa quebra e reconstrói", function()
	-- casa dos Higashikata
	local n = Mapa.quebrarArea(Vector3.new(-600, 8, -360), 18, 9)
	assert(n > 0, "nada quebrou num prédio")
	assert(n <= Config.MAPA.maxPorImpacto, "quebrou peças demais de uma vez: " .. n)
	local v = Mapa.restaurarTudo()
	assert(v >= n, "não reconstruiu tudo")
	res.info.quebraTeste = string.format("%d peças quebraram e %d voltaram", n, v)
end)

-- 7) alguns sons da biblioteca carregam?
checar("sons", function()
	local lista = {}
	for nome, s in Sons.LISTA do
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://" .. s.ids[1]
		snd.Name = nome
		snd.Parent = pastaTeste
		table.insert(lista, snd)
	end
	pcall(function()
		ContentProvider:PreloadAsync(lista)
	end)
	local okN = 0
	local falhos = {}
	for _, snd in lista do
		if snd.TimeLength > 0 then
			okN += 1
		else
			table.insert(falhos, snd.Name)
		end
	end
	res.info.sons = string.format("%d/%d", okN, #lista)
	if okN == 0 then
		aviso("nenhum som carregou no servidor de teste (normal em alguns servidores de teste)")
	elseif #falhos > 0 then
		aviso("sons que não carregaram: " .. table.concat(falhos, ", "))
	end
end)

-- 8) vozes dos Stands (só informação: se o áudio ainda não foi liberado, toca o grito de reserva)
checar("vozes", function()
	local v = ReplicatedStorage:FindFirstChild("BB_Vozes")
	local id = v and string.match(v.Value, "^%s*(%d+)")
	res.info.vozes = if id then "áudio " .. id else "sem áudio (usa o grito da biblioteca)"
	local va = ReplicatedStorage:FindFirstChild("BB_VozesAnime")
	local ida = va and string.match(va.Value, "^%s*(%d+)")
	res.info.vozesAnime = if ida and ida ~= "0" then "áudio " .. ida else "sem os sons do anime (usa as vozes geradas)"
	local im = ReplicatedStorage:FindFirstChild("BB_Imagens")
	local n = 0
	for id in string.gmatch(if im then im.Value else "", "%d+") do
		if id ~= "0" then
			n += 1
		end
	end
	res.info.imagens = n .. " de 3 artes do Canva no place"
end)

-- 9) AJUSTE-11: VFX da loja (os pacotes que o dono pegou). Só informação: se não carregar, o jogo
-- segue com os VFX próprios.
checar("VFX da loja", function()
	local inicio = os.clock()
	local loja = ReplicatedStorage:FindFirstChild("BB_VFXLoja")
	while os.clock() - inicio < 20 and not (loja and loja:GetAttribute("Pronto")) do
		task.wait(1)
		loja = ReplicatedStorage:FindFirstChild("BB_VFXLoja")
	end
	if not loja then
		aviso("VFX da loja: o servidor não criou a pasta")
		return
	end
	res.info.vfxLoja = string.sub(tostring(loja:GetAttribute("Resumo")), 1, 900)
	local tipos = {}
	for _, pasta in loja:GetChildren() do
		local nomes = {}
		for i, e in pasta:GetChildren() do
			if i <= 3 then
				table.insert(nomes, tostring(e:GetAttribute("Caminho")))
			end
		end
		table.insert(tipos, pasta.Name .. " " .. #pasta:GetChildren() .. " [" .. table.concat(nomes, "; ") .. "]")
	end
	if #tipos > 0 then
		res.info.vfxLoja ..= " | tipos: " .. string.sub(table.concat(tipos, " · "), 1, 900)
	end
	-- AJUSTE-13: a descrição de cada efeito (texturas, cores, tamanhos) volta para o instalador, que
	-- salva num arquivo para o dono mandar no chat
	local mod = SRV and SRV:FindFirstChild("VFXLoja")
	if mod then
		local ok, desc = pcall(function()
			return require(mod).descrever()
		end)
		if ok and desc then
			res.vfxDetalhes = desc
		end
	end
end)

-- 10) AJUSTE-13: o áudio dos socos do dono (BB_SFX) entrou no place
checar("sons de golpe do dono", function()
	local v = ReplicatedStorage:FindFirstChild("BB_SFX")
	local id = v and string.match(v.Value, "^%s*(%d+)")
	res.info.sfx = if id and id ~= "0" then ("áudio " .. id .. " no place") else "ainda não (o jogo usa os socos da biblioteca)"
end)

-- AJ16: these assertions execute in the isolated Roblox engine, never during upload.
if cfg.stage==16 then
 checar("AJ16 prisao e tempo parado",function()
  arrumar();Lutadores.trocarStand(atk,"CRAZY_DIAMOND")
  local Vinculos=require(SRV.Vinculos16)
  local clock=workspace:GetServerTimeNow()
  Vinculos.prender(atk,vit,.05,"BB_Preso")
  vit.estado.congeladoAte=clock+.2
  task.wait(.08);Vinculos.passo()
  assert(vit.raiz.Anchored,"prisao liberou o tempo parado")
  vit.estado.congeladoAte=0;Vinculos.passo()
  assert(not vit.raiz.Anchored and not vit.modelo:GetAttribute("BB_Preso"),"prisao deixou alvo preso")
 end)
 checar("AJ16 restauracao sem destrocos",function()
  arrumar();Lutadores.trocarStand(atk,"CRAZY_DIAMOND")
  Mapa.restaurarPerto(atk.raiz.Position,45,true)
  local hp=vit.hum.Health
  Combate.golpe(atk,3,{})
  task.wait(.7)
  assert(vit.hum.Health<hp,"restauracao sem destrocos nao acertou")
 end)
 checar("AJ16 poses R6",function()
  local P=require(ReplicatedStorage.BB.Poses)
  for _,id in {"CRAZY_DIAMOND","KILLER_QUEEN","STAR_PLATINUM","THE_WORLD"}do
   local name=P.clipe15(id,id=="KILLER_QUEEN"and"conjurar"or"barragem")
   local clip=assert(P.C[name],"clipe ausente")
   for _,t in {0,.05,.27,.35,.8}do
    local pose=clip.proc and P.aj16Proc(clip.proc,t)or P.amostrar(clip,t)
    assert(pose and pose.RS and pose.LS,"pose sem bracos")
    for _,angles in pose do for _,n in angles do assert(n==n and math.abs(n)<1000,"pose invalida")end end
   end
  end
 end)
 res.info.ajuste16="seis perfis; prisao/tempo/restauracao/poses verificados no motor"
end

-- limpeza
for _, l in { atk, vit } do
	Lutadores.remover(l.modelo)
end
pastaTeste:Destroy()
res.info.logs = #logsRuins
if #logsRuins > 0 and res.ok then
	for i = 1, math.min(5, #logsRuins) do
		aviso("log: " .. logsRuins[i])
	end
end
return HttpService:JSONEncode(res)

end)()
local gameplay = if type(original)=="string" then Http:JSONDecode(original) else original
if type(gameplay)~="table" or gameplay.ok~=true then
 report14.passed=false
 for _,msg in (gameplay and gameplay.erros) or {"Teste de gameplay sem relatorio valido"} do table.insert(report14.erros,tostring(msg)) end
end
report14.gameplay=gameplay
for _,msg in (gameplay and gameplay.avisos) or {} do table.insert(report14.avisos,tostring(msg)) end
report14.info.revisao=Config14.REVISAO
report14.info.visual="Catalogo real e referencias conferidos; aparencia/camera exigem cliente Roblox."
return report14
