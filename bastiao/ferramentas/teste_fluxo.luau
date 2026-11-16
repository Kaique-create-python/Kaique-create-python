-- PROJETO BASTIÃO :: fluxo completo da Etapa 1 no Lune
-- Monta o cenário de verdade (sem o mapa), liga Mundo + Missao + Sequencias + Interacoes +
-- Zonas + Checkpoint como o servidor faz e joga a abertura inteira com dois jogadores falsos.
-- O relógio é falso (avança na hora), então 25 s de sequência rodam instantaneamente.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local raiz = if fs.isDir("bastiao/src") then "bastiao/src/" else "src/"
local G = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	Font = roblox.Font,
}
local function carregar(caminho: string)
	return luau.load(fs.readFile(raiz .. caminho), { debugName = caminho, environment = G })()
end
local V, CF = roblox.Vector3.new, roblox.CFrame.new

local Runner = carregar("ServerScriptService/BastiaoServidor/StoryRunner.luau")
local Validator = carregar("ServerScriptService/BastiaoServidor/StoryValidator.luau")
local Cap = carregar("ServerScriptService/BastiaoServidor/Capitulo01.luau")
local Mundo = carregar("ServerScriptService/BastiaoServidor/Mundo.luau")
local Missao = carregar("ServerScriptService/BastiaoServidor/Missao.luau")
local Sequencias = carregar("ServerScriptService/BastiaoServidor/Sequencias.luau")
local Interacoes = carregar("ServerScriptService/BastiaoServidor/Interacoes.luau")
local Zonas = carregar("ServerScriptService/BastiaoServidor/Zonas.luau")
local Checkpoint = carregar("ServerScriptService/BastiaoServidor/Checkpoint.luau")
local Cenario = carregar("ServerScriptService/BastiaoServidor/Cenario.luau")
local Textos = carregar("ReplicatedStorage/BastiaoCompartilhado/Textos.luau")
local Compartilhado = carregar("ReplicatedStorage/BastiaoCompartilhado.luau")

local function pass(nome: string)
	print("[Fluxo] PASS " .. nome)
end
local function falhar(msg: string)
	error("[Fluxo] FALHA " .. msg, 2)
end
local function confere(cond: any, msg: string)
	if not cond then
		falhar(msg)
	end
end

-- ===== relógio falso =====
local agora = 0
local fila = {}
local function agendar(t: number, fn: () -> ())
	local h = { em = agora + t, fn = fn, vivo = true, seq = #fila + 1 }
	table.insert(fila, h)
	return h
end
local function cancelar(h: any)
	h.vivo = false
end
local function avancar(dt: number)
	local alvo = agora + dt
	while true do
		local proximo, idx = nil, nil
		for i, h in fila do
			if h.vivo and h.em <= alvo and (proximo == nil or h.em < proximo.em) then
				proximo, idx = h, i
			end
		end
		if not proximo then
			break
		end
		table.remove(fila, idx)
		agora = math.max(agora, proximo.em)
		proximo.fn()
	end
	agora = alvo
end

-- ===== Pavel falso: chega quando o teste mandar =====
local pavelFalso = { estado = "tunel", chegouFlag = true, historico = {} }
function pavelFalso:ir(estado: string, instantaneo: boolean)
	self.estado = estado
	self.chegouFlag = instantaneo == true
	table.insert(self.historico, estado)
end
function pavelFalso:chegou()
	return self.chegouFlag
end

-- ===== jogadores falsos com personagem R6 mínimo =====
local pastaPersonagens = roblox.Instance.new("Folder")
local function novoJogador(id: number, nome: string)
	local c = roblox.Instance.new("Model")
	c.Name = nome
	local raizP = roblox.Instance.new("Part")
	raizP.Name = "HumanoidRootPart"
	raizP.CFrame = CF(0, 3, 12)
	raizP.Parent = c
	local braco = roblox.Instance.new("Part")
	braco.Name = "Right Arm"
	braco.CFrame = CF(1.5, 3, 12)
	braco.Parent = c
	c.Parent = pastaPersonagens
	return { UserId = id, Name = nome, DisplayName = nome, Parent = pastaPersonagens, Character = c, vivo = true }
end
local ana = novoJogador(101, "Ana")
local bia = novoJogador(202, "Bia")
local jogadores = { ana, bia }
local function mover(j: any, p: any)
	j.Character.HumanoidRootPart.CFrame = CF(p.X, p.Y, p.Z)
	j.Character["Right Arm"].CFrame = CF(p.X + 1.5, p.Y, p.Z)
end
local function localizar(j: any)
	local r = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
	if not r then
		return nil, false
	end
	return r.CFrame.Position, j.vivo
end

-- ===== montagem igual ao servidor =====
local pasta = roblox.Instance.new("Folder")
pasta.Name = "BastiaoHistoria"
local log = {}
local mundo = Mundo.novo(function(m)
	table.insert(log, m)
end)
local tags = {}
local cena = Cenario.construir({
	pasta = pasta,
	textos = Textos,
	mundo = mundo,
	servicos = {
		tween = function(inst, _t, alvo)
			for k, v in alvo do
				(inst :: any)[k] = v
			end
		end,
		atrasar = function(t, fn)
			agendar(t, fn)
		end,
		marcar = function(inst, tag)
			tags[tag] = (tags[tag] or 0) + 1
			inst:AddTag(tag)
		end,
		agora = function()
			return agora
		end,
	},
	jogadores = function()
		return table.clone(jogadores)
	end,
	criarPavel = function()
		return pavelFalso
	end,
	log = function(m)
		table.insert(log, m)
	end,
})

local rel = Validator.Validate(Cap, mundo:registro())
confere(rel.ok, "capítulo não valida com as entidades do cenário:\n" .. table.concat(rel.erros, "\n"))
confere(tags.BastiaoGiroflex == #Cenario.POS.giroflex, "giroflex sem tag")
pass("cenario_registra_entidades_validas")

local atributos = { objetivo = "", alarme = false, fim = 0 }
local mensagens = {}
local avisos = {}
local checkpoint = Checkpoint.novo(cena.spawns)
local interacoes
local missao = Missao.novo({
	def = Cap,
	runner = Runner,
	mundo = mundo,
	objetivo = function(chave)
		atributos.objetivo = chave or ""
	end,
	checkpoint = function(id, estado, retrato)
		checkpoint:salvar(id, estado, retrato)
	end,
	aoAvancar = function()
		if interacoes then
			interacoes:atualizar()
		end
	end,
	aoFinal = function()
		atributos.fim = agora
	end,
	log = function(m)
		table.insert(log, m)
	end,
})
local sequencias = Sequencias.novo({
	def = Cap,
	textos = Textos,
	mundo = mundo,
	apresentar = function(msg)
		table.insert(mensagens, msg)
	end,
	aoTerminar = function(id, n)
		missao:reportar({ id = "seq:" .. id .. ":" .. n, kind = "sequencia", name = id .. "_fim" })
	end,
	agendar = agendar,
	cancelar = cancelar,
	duracaoLeitura = Compartilhado.duracaoLeitura,
})
missao:ligarSequencias(sequencias)
interacoes = Interacoes.novo({
	missao = missao,
	mundo = mundo,
	localizar = localizar,
	agora = function()
		return agora
	end,
	aviso = function(j, texto)
		table.insert(avisos, { j = j, texto = texto })
	end,
})
for _, def in cena.interacoes do
	interacoes:registrar(def.nome, def)
end
mundo:aoMudar(function(id, estado)
	if id == "alarme" then
		atributos.alarme = estado == "ligado"
	end
	interacoes:atualizar()
end)
local zonas = Zonas.novo({
	missao = missao,
	jogadores = function()
		local r = {}
		for _, j in jogadores do
			local p, vivo = localizar(j)
			table.insert(r, { jogador = j, pos = p, vivo = vivo })
		end
		return r
	end,
})
for nome, forma in cena.zonas do
	zonas:registrar(nome, forma)
end
local prompts = {}
for _, def in cena.interacoes do
	prompts[def.nome] = def.prompt
end
local function promptLigado(nome: string): boolean
	return prompts[nome].Enabled == true
end
local function nenhumPromptLigado(): boolean
	for _, p in prompts do
		if p.Enabled then
			return false
		end
	end
	return true
end

-- ===== 1) começo: nada aceso, objetivo recolhido =====
missao:iniciar()
interacoes:atualizar()
confere(missao:no() == "rotina", "nó inicial")
confere(atributos.objetivo == "", "objetivo deveria começar recolhido")
confere(nenhumPromptLigado(), "nenhum prompt deveria aparecer no começo")
confere(mundo:estado("porta_oficina") == "aberta" and mundo:estado("alarme") == "desligado", "estado inicial do mundo")
pass("inicio_recolhido")

-- ===== 2) cena 1: chegar perto do Pavel começa a conversa =====
zonas:verificar()
confere(missao:no() == "rotina", "a zona não deveria disparar com o jogador no spawn (10.4 studs)")
mover(ana, V(2, 3, 7))
zonas:verificar()
confere(missao:no() == "radio", "chegar perto do Pavel deveria disparar a cena 1")
avancar(4)
confere(missao:no() == "radio" and not promptLigado("pegar_radio"), "o rádio só aparece depois das falas")
avancar(8)
confere(missao:no() == "radio_ordem" and atributos.objetivo == "radio", "objetivo do rádio")
confere(promptLigado("pegar_radio"), "prompt do rádio deveria aparecer")
local falas = 0
for _, m in mensagens do
	if m.tipo == "fala" then
		falas += 1
	end
end
confere(falas == 2, "a cena 1 tem duas falas do Pavel")
pass("cena1_pavel_e_radio")

-- ===== 3) alcance medido no servidor + cena 3 =====
mover(ana, V(-20, 3, 1.3))
local ok, motivo = interacoes:tentar(ana, "pegar_radio")
confere(not ok and motivo == "longe", "rádio longe deveria ser recusado: " .. tostring(motivo))
avancar(1)
mover(ana, V(4.5, 3, 3))
ok, motivo = interacoes:acionar(ana, prompts.pegar_radio)
confere(ok, "pegar o rádio de perto: " .. tostring(motivo))
confere(missao:no() == "ordem" and mundo:estado("radio") == "entregue", "rádio entregue")
confere(not promptLigado("pegar_radio"), "prompt do rádio some")
ok, motivo = interacoes:tentar(bia, "pegar_radio")
confere(not ok, "segundo rádio não existe")
avancar(30)
confere(missao:no() == "buscar_bateria" and atributos.objetivo == "bateria", "depois da ordem: buscar o módulo")
confere(pavelFalso.estado == "arsenal", "Pavel vai na frente para o arsenal")
confere(mundo:estado("bateria") == "disponivel" and promptLigado("pegar_bateria"), "módulo disponível")
pass("cena3_ordem_e_lista")

-- ===== 4) módulo: quem pega carrega; outro jogador não encaixa =====
local carregador = cena.interacoes[2].posicao()
mover(ana, carregador + V(0, -0.6, -2))
ok, motivo = interacoes:acionar(ana, prompts.pegar_bateria)
confere(ok, "pegar o módulo: " .. tostring(motivo))
confere(cena.bateria.portador == ana, "Ana carrega o módulo")
confere(ana.Character:FindFirstChild("ModuloNaMao") ~= nil, "cópia do módulo soldada na mão")
confere(atributos.objetivo == "terminal" and pavelFalso.estado == "enfermaria", "objetivo do terminal e Pavel indo")
local encaixe
for _, d in cena.interacoes do
	if d.nome == "encaixar_bateria" then
		encaixe = d.posicao()
	end
end
mover(bia, encaixe + V(2.5, 0.2, 0))
ok, motivo = interacoes:tentar(bia, "encaixar_bateria")
confere(not ok and string.find(tostring(motivo), "ANA", 1, true), "Bia não encaixa o módulo da Ana: " .. tostring(motivo))
confere(#avisos >= 1 and avisos[#avisos].j == bia, "Bia recebe o aviso")
pass("modulo_tem_portador")

-- ===== 5) quem carrega morre: o módulo volta e qualquer um pega de novo =====
-- igual ao soltarModulo do servidor: solta e atualiza os prompts
confere(cena.bateria.soltar(ana, "morte"), "soltar o módulo da Ana")
interacoes:atualizar()
confere(not cena.bateria.soltar(ana, "morte"), "soltar de novo não faz nada (idempotente)")
confere(cena.bateria.portador == nil and ana.Character:FindFirstChild("ModuloNaMao") == nil, "cópia removida")
confere(promptLigado("repegar_bateria"), "o módulo pode ser pego de novo no carregador")
confere(missao:no() == "levar_bateria", "a história não volta atrás")
mover(bia, carregador + V(0, -0.6, -2))
ok, motivo = interacoes:acionar(bia, prompts.repegar_bateria)
confere(ok and cena.bateria.portador == bia, "Bia pega de volta: " .. tostring(motivo))
confere(bia.Character:FindFirstChild("ModuloNaMao") ~= nil, "módulo na mão da Bia")
pass("portador_saiu_nao_trava")

-- ===== 6) cena 4 e 5: encaixe, chamada, isolamento =====
avancar(1) -- a recusa anterior da Bia ainda conta no anti-spam (0.4 s)
mover(bia, encaixe + V(2.5, 0.2, 0))
ok, motivo = interacoes:acionar(bia, prompts.encaixar_bateria)
confere(ok, "encaixar: " .. tostring(motivo))
confere(mundo:estado("bateria") == "encaixada" and mundo:estado("terminal_enfermaria") == "ligado", "terminal ligado")
confere(atributos.objetivo == "", "objetivo recolhido durante a chamada")
avancar(20)
confere(missao:no() == "isolamento", "depois da chamada: isolamento")
confere(mundo:estado("porta_contencao") == "destravada" and mundo:estado("terminal_enfermaria") == "autorizado", "autorização remota separada da bateria")
confere(atributos.alarme == true, "alarme ligado no começo do isolamento")
avancar(30)
confere(missao:no() == "ir_oficina" and atributos.objetivo == "oficina", "objetivo da oficina")
confere(mundo:estado("porta_oficina") == "trancada" and pavelFalso.estado == "porta_oficina", "porta trancada, Pavel indo à porta")
pass("cena4_cena5")

-- ===== 7) cena 7: a zona da porta espera o Pavel; a trava exige estar dentro =====
mover(bia, V(59, 3, -316))
zonas:verificar()
confere(missao:no() == "ir_oficina", "sem o Pavel na porta, a zona não dispara")
pavelFalso.chegouFlag = true
zonas:verificar()
confere(missao:no() == "fechar_trava" and mundo:estado("porta_oficina") == "aberta", "Pavel abre a porta")
confere(pavelFalso.estado == "oficina" and not pavelFalso:chegou(), "Pavel entra")
local trava
for _, d in cena.interacoes do
	if d.nome == "fechar_trava" then
		trava = d.posicao()
	end
end
mover(bia, V(trava.X + 2.2, 3, trava.Z))
ok, motivo = interacoes:acionar(bia, prompts.fechar_trava)
confere(not ok and motivo == Textos.avisos.espere_pavel, "esperar o Pavel entrar: " .. tostring(motivo))
pavelFalso.chegouFlag = true
avancar(1)
mover(bia, V(trava.X - 2.0, 3, trava.Z)) -- do lado de fora da parede (x < 65.9)
ok, motivo = interacoes:acionar(bia, prompts.fechar_trava)
confere(not ok and motivo == Textos.avisos.entre_oficina, "fechar a trava de fora é recusado: " .. tostring(motivo))
avancar(1)
mover(bia, V(trava.X + 2.2, 3, trava.Z))
ok, motivo = interacoes:acionar(bia, prompts.fechar_trava)
confere(ok, "fechar a trava de dentro: " .. tostring(motivo))
confere(mundo:estado("porta_oficina") == "travada", "porta travada")
local ponto = checkpoint:ultimo()
confere(ponto and ponto.id == "oficina_segura" and ponto.spawn ~= nil, "checkpoint com lugar de renascer")
confere(ponto.estado.flags.maintenance_reached == true and ponto.retrato.porta_oficina == "travada", "retrato do checkpoint")
pass("cena7_trava")

-- ===== 8) cena 8: terminal com a lista do turno (com os nomes de quem está no servidor) =====
avancar(8)
confere(promptLigado("ler_terminal") and atributos.objetivo == "terminal_oficina", "terminal aguardando")
local monitor
for _, d in cena.interacoes do
	if d.nome == "ler_terminal" then
		monitor = d.posicao()
	end
end
mover(ana, monitor + V(0, -0.75, -2.8))
ok, motivo = interacoes:acionar(ana, prompts.ler_terminal)
confere(ok, "ler o terminal: " .. tostring(motivo))
local texto = (pasta:FindFirstChild("TerminalOficina") :: any).Visor.Tela.Fundo.Texto.Text
confere(string.find(texto, "KEDR-1", 1, true) and string.find(texto, "ANA", 1, true) and string.find(texto, "BIA", 1, true), "lista com os jogadores:\n" .. texto)
confere(string.find(texto, "SOKOLOV", 1, true) and string.find(texto, "02:31", 1, true), "lista com Sokolov e o registro")
avancar(30)
confere(missao:final() and missao:no() == "fim_etapa", "chegou ao fim da etapa")
confere(atributos.objetivo == "piso" and atributos.fim > 0, "objetivo final e cartão")
confere(checkpoint:ultimo().id == "fim_etapa1", "checkpoint final")
pass("cena8_lista_e_fim")

-- ===== 9) depois do fim nada reabre =====
confere(nenhumPromptLigado(), "nenhum prompt depois do fim")
ok = interacoes:tentar(ana, "ler_terminal")
confere(not ok, "terminal não repete")
pass("fim_estavel")

-- ===== 10) alcance exato: 10 aceita, 10.1 recusa (fixture do plano) =====
local fixtureMundo = Mundo.novo()
fixtureMundo:registrar("x", { estados = { a = true }, aplicar = function() end })
fixtureMundo:definir("x", "a")
local relatos = {}
local fixture = Interacoes.novo({
	missao = {
		espera = function()
			return true
		end,
		reportar = function(_, ev)
			table.insert(relatos, ev)
		end,
	},
	mundo = fixtureMundo,
	localizar = localizar,
	agora = function()
		return agora
	end,
})
fixture:registrar("alvo", {
	posicao = function()
		return V(0, 0, 0)
	end,
	alcance = 10,
	evento = "alvo",
	requer = { { "x", "a" } },
})
mover(ana, V(10, 0, 0))
ok = fixture:tentar(ana, "alvo")
confere(ok and #relatos == 1, "10 studs aceita")
mover(bia, V(10.1, 0, 0))
ok, motivo = fixture:tentar(bia, "alvo")
confere(not ok and motivo == "longe" and #relatos == 1, "10.1 studs recusa")
ok, motivo = fixture:tentar(ana, "alvo")
confere(not ok and motivo == "repetido", "repetição rápida recusada")
ana.vivo = false
avancar(1)
ok, motivo = fixture:tentar(ana, "alvo")
confere(not ok and motivo == "morto", "morto não interage")
ana.vivo = true
ana.Parent = nil
ok, motivo = fixture:tentar(ana, "alvo")
confere(not ok and motivo == "jogador_invalido", "quem saiu não interage")
ana.Parent = pastaPersonagens
pass("alcance_10_aceita_10_1_recusa")

-- ===== 11) legendas: cada fala tem tempo de leitura antes da próxima =====
for id, s in Cap.sequences do
	local fs2 = {}
	for _, c in s.cues do
		if c.fala then
			table.insert(fs2, c)
		end
	end
	table.sort(fs2, function(a, b)
		return a.t < b.t
	end)
	for i = 1, #fs2 - 1 do
		local d = Compartilhado.duracaoLeitura(Textos.falas[fs2[i].fala][2])
		local janela = fs2[i + 1].t - fs2[i].t
		confere(janela >= d * 0.95, string.format("%s: %s tem %.1fs para %.1fs de leitura", id, fs2[i].fala, janela, d))
	end
end
pass("legendas_com_tempo_de_leitura")

-- ===== 12) nada de erro escondido no log =====
for _, m in log do
	confere(not string.find(m, "falh", 1, true) and not string.find(m, "desconhecid", 1, true), "log com erro: " .. m)
end
pass("log_limpo")

print("[Fluxo] TUDO OK")
