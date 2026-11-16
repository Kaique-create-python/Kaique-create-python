-- PROJETO BASTIÃO :: specs do núcleo da história (Tarefa 1 do plano), rodando no Lune.
-- Imprime [StorySpecs] PASS <nome> por caso e falha explicitamente se algo esperado faltar.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local raiz = if fs.isDir("bastiao/src") then "bastiao/src/" else "src/"
local function carregar(caminho: string, env: any?)
	return luau.load(fs.readFile(raiz .. caminho), { debugName = caminho, environment = env or {} })()
end
local Runner = carregar("ServerScriptService/BastiaoServidor/StoryRunner.luau")
local Validator = carregar("ServerScriptService/BastiaoServidor/StoryValidator.luau")
local Cap = carregar("ServerScriptService/BastiaoServidor/Capitulo01.luau")
local Textos = carregar("ReplicatedStorage/BastiaoCompartilhado/Textos.luau")

local function pass(nome: string)
	print("[StorySpecs] PASS " .. nome)
end

-- entidades e seus estados válidos (mesma lista que o Cenario registra)
local ENT = {
	pavel = { estados = { tunel = true, arsenal = true, enfermaria = true, porta_oficina = true, oficina = true } },
	relogio = { estados = { ["0249"] = true } },
	radio = { estados = { guardado = true, oferecido = true, entregue = true } },
	bateria = { estados = { no_carregador = true, disponivel = true, carregada = true, encaixada = true } },
	terminal_enfermaria = { estados = { sem_energia = true, ligado = true, autorizado = true } },
	porta_contencao = { estados = { trancada = true, vazando = true, destravada = true } },
	alarme = { estados = { desligado = true, ligado = true } },
	acesso_externo = { estados = { aberto = true, bloqueado = true } },
	porta_oficina = { estados = { aberta = true, trancada = true, travada = true } },
	terminal_oficina = { estados = { apagado = true, aguardando = true, lista = true } },
	fim = { estados = { oculto = true, visivel = true } },
}

-- 1) o capítulo real passa na validação
local rel = Validator.Validate(Cap, ENT)
assert(rel.ok, "capítulo inválido:\n" .. table.concat(rel.erros, "\n"))
pass("capitulo01_valido")

-- 2) todo texto referenciado existe (fala, som, objetivo)
for id, s in Cap.sequences do
	for _, c in s.cues do
		if c.fala then assert(Textos.falas[c.fala], "fala ausente " .. c.fala .. " em " .. id) end
		if c.som then assert(Textos.sons[c.som], "som ausente " .. c.som .. " em " .. id) end
	end
end
for id, no in Cap.nodes do
	local function conf(lista)
		for _, e in lista or {} do
			if e.tipo == "objetivo" and e.texto then assert(Textos.objetivos[e.texto], "objetivo ausente " .. e.texto .. " em " .. id) end
		end
	end
	conf(no.onEnter)
	for _, s in no.exits or {} do conf(s.effects) end
end
pass("textos_referenciados_existem")

-- 3) validação acusa erros com caminho do campo
local ruim = Runner.copia(Cap)
ruim.nodes.radio.exits[1].to = "nao_existe"
ruim.nodes.orfao = { exits = { { event = "x", to = "rotina" } } }
ruim.nodes.buscar_bateria.exits[1].effects[1] = { tipo = "entidade", id = "bateria", estado = "voando" }
ruim.nodes.ordem.exits[1].set = { flag_inventada = true }
local r2 = Validator.Validate(ruim, ENT)
local texto = table.concat(r2.erros, "\n")
assert(not r2.ok, "validação aceitou capítulo quebrado")
assert(string.find(texto, "nodes.radio.exits[1]: destino ausente nao_existe", 1, true), texto)
assert(string.find(texto, "nodes.orfao: inalcançável", 1, true), texto)
assert(string.find(texto, "estado voando não existe em bateria", 1, true), texto)
assert(string.find(texto, "flag fora do esquema flag_inventada", 1, true), texto)
pass("invalid_reference_com_caminho")

-- 4) caminho completo do capítulo: eventos na ordem levam ao final, com as flags do plano
local function ev(n: number, kind: string, name: string)
	return { id = "e" .. n, kind = kind, name = name }
end
local estado = Runner.novo(Cap)
local efeitos
estado, efeitos = Runner.iniciar(Cap, estado)
assert(#efeitos >= 11 and estado.mundo.pavel == "tunel" and estado.objetivo == nil, "entrada do nó inicial")
local roteiro = {
	{ "zona", "pavel_perto" }, { "sequencia", "s1_pavel_fim" }, { "interacao", "pegar_radio" },
	{ "sequencia", "s3_ordem_fim" }, { "interacao", "pegar_bateria" }, { "interacao", "encaixar_bateria" },
	{ "sequencia", "s4_chamada_fim" }, { "sequencia", "s5_isolamento_fim" }, { "zona", "chegou_oficina" },
	{ "interacao", "fechar_trava" }, { "interacao", "ler_terminal" }, { "sequencia", "s8_lista_fim" },
}
local seqs = {}
for i, passo in roteiro do
	local res
	estado, efeitos, res = Runner.Step(Cap, estado, ev(i, passo[1], passo[2]))
	assert(res == "avancou", "passo " .. i .. " (" .. passo[2] .. ") não avançou: " .. res)
	for _, e in efeitos do
		if e.tipo == "sequencia" then table.insert(seqs, e.id) end
	end
end
assert(estado.final and estado.no == "fim_etapa", "não chegou ao final")
for _, f in { "radio_checked", "battery_collected", "medical_terminal_powered", "exercise_started", "maintenance_reached", "partial_roster_found" } do
	assert(estado.flags[f] == true, "flag não marcada: " .. f)
end
assert(table.concat(seqs, ",") == "s1_pavel,s3_ordem,s4_chamada,s5_isolamento,s7_trava,s7_travada,s8_lista", "ordem das sequências: " .. table.concat(seqs, ","))
assert(estado.mundo.porta_oficina == "travada" and estado.mundo.fim == "visivel" and estado.objetivo == "piso", "mundo final")
assert(estado.revisao == #roteiro, "revisão = número de transições")
pass("reachable_endings_caminho_completo")

-- 5) duplicate_event: o mesmo eventId duas vezes avança uma vez e não repete efeito
local e1 = Runner.novo(Cap)
e1 = Runner.iniciar(Cap, e1)
local a, ef1, r1 = Runner.Step(Cap, e1, ev(1, "zona", "pavel_perto"))
local b, ef2, rr = Runner.Step(Cap, a, ev(1, "zona", "pavel_perto"))
assert(r1 == "avancou" and rr == "repetido" and #ef2 == 0 and b.revisao == a.revisao, "evento repetido avançou de novo")
pass("duplicate_event")

-- 6) prerequisite_missing / fora de ordem: encaixar a bateria antes de pegar não muda nada
local c0 = Runner.novo(Cap)
c0 = Runner.iniciar(Cap, c0)
local c1, efc, rc = Runner.Step(Cap, c0, ev(9, "interacao", "encaixar_bateria"))
assert(rc == "ignorado" and #efc == 0 and c1.revisao == 0 and c1.no == "rotina" and not c1.flags.medical_terminal_powered, "evento fora de ordem avançou")
-- e o tipo do evento importa: uma interação com nome de zona não serve
local c2, _, rk = Runner.Step(Cap, c1, ev(10, "interacao", "pavel_perto"))
assert(rk == "ignorado" and c2.no == "rotina", "tipo do evento ignorado")
pass("prerequisite_missing")

-- 7) efeitos com chave: reaplicar a mesma transição de um snapshot não duplica (effectKey)
local base = Runner.novo(Cap)
base = Runner.iniciar(Cap, base)
local x1, efx = Runner.Step(Cap, base, ev(20, "zona", "pavel_perto"))
local chaves = {}
for _, e in efx do
	assert(not chaves[e.key], "chave de efeito repetida " .. e.key)
	chaves[e.key] = true
	assert(x1.feitos[e.key], "efeito sem registro")
end
local _, efy = Runner.Step(Cap, x1, ev(21, "zona", "pavel_perto"))
assert(#efy == 0, "efeito reaplicado")
pass("effect_keys_unicos")

-- 8) depois do final nada muda; espera() responde só ao que o nó atual aceita
local fimEstado = estado
local depois, efd, rd = Runner.Step(Cap, fimEstado, ev(99, "interacao", "pegar_radio"))
assert(rd == "ignorado" and #efd == 0 and depois.revisao == fimEstado.revisao, "final aceitou evento")
local inicio = Runner.iniciar(Cap, Runner.novo(Cap))
assert(Runner.espera(Cap, inicio, "pavel_perto") and not Runner.espera(Cap, inicio, "pegar_radio"), "espera()")
assert(not Runner.espera(Cap, fimEstado, "pavel_perto"), "espera() depois do final")
pass("final_e_espera")

-- 9) snapshot só com dados: cópia profunda não compartilha tabelas (checkpoint seguro)
local snap = Runner.copia(estado)
snap.flags.radio_checked = false
assert(estado.flags.radio_checked == true, "snapshot compartilha tabela com o estado vivo")
pass("snapshot_isolado")

print("[StorySpecs] TUDO OK")
