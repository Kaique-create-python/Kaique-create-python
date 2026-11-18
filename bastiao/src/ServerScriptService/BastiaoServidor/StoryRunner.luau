--!strict
-- PROJETO BASTIÃO :: StoryRunner (Tarefa 1 do plano mestre)
-- Núcleo determinístico da história: recebe o estado e UM evento do servidor e devolve o novo
-- estado, a lista de efeitos e o resultado. Não toca no mundo, na rede nem em DataStore.
--   * o mesmo eventId aplicado duas vezes não avança duas vezes (resultado "repetido");
--   * evento que a etapa atual não espera não muda a revisão (resultado "ignorado");
--   * cada efeito tem uma chave única: reaplicar não duplica recompensa nem estado.

local StoryRunner = {}

local MAX_VISTOS = 256

export type Evento = { id: string, kind: string?, name: string, actor: number? }

local function copiaProfunda(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[k] = copiaProfunda(x)
	end
	return t
end
StoryRunner.copia = copiaProfunda

-- Condições: lista fechada (All, Any, Not, Flag). Qualquer outra coisa é erro de conteúdo.
local function avaliar(cond: any, estado: any): boolean
	if cond == nil then
		return true
	end
	if cond.All then
		for _, c in cond.All do
			if not avaliar(c, estado) then
				return false
			end
		end
		return true
	elseif cond.Any then
		for _, c in cond.Any do
			if avaliar(c, estado) then
				return true
			end
		end
		return false
	elseif cond.Not then
		return not avaliar(cond.Not, estado)
	elseif cond.Flag then
		return estado.flags[cond.Flag[1]] == cond.Flag[2]
	end
	error("condição desconhecida")
end
StoryRunner.avaliar = avaliar

function StoryRunner.novo(def: any): any
	local estado = {
		campanha = def.id,
		versao = def.version,
		revisao = 0,
		no = def.start,
		flags = copiaProfunda(def.initialFlags or {}),
		mundo = {}, -- entidade -> estado desejado (para restaurar um checkpoint igual)
		objetivo = nil :: string?,
		feitos = {}, -- chaves de efeito já emitidas
		vistos = {}, -- eventIds já processados
		ordemVistos = {},
		final = false,
	}
	return estado
end

-- efeitos de entrada do nó inicial (o servidor chama uma vez ao começar a partida)
function StoryRunner.iniciar(def: any, estado: any): (any, { any })
	local novo = copiaProfunda(estado)
	local efeitos = {}
	StoryRunner._emitir(novo, efeitos, def.nodes[novo.no].onEnter, novo.no .. ":entrada")
	return novo, efeitos
end

function StoryRunner._emitir(estado: any, efeitos: { any }, lista: { any }?, prefixo: string)
	for i, e in lista or {} do
		local chave = e.key or (prefixo .. "#" .. i)
		if not estado.feitos[chave] then
			estado.feitos[chave] = true
			local efeito = copiaProfunda(e)
			efeito.key = chave
			-- o estado guarda o que precisa ser recomposto num checkpoint
			if efeito.tipo == "entidade" then
				estado.mundo[efeito.id] = efeito.estado
			elseif efeito.tipo == "objetivo" then
				estado.objetivo = efeito.texto
			end
			table.insert(efeitos, efeito)
		end
	end
end

-- O nó atual espera este evento? (o servidor só reporta zonas/interações esperadas)
function StoryRunner.espera(def: any, estado: any, nome: string): boolean
	if estado.final then
		return false
	end
	for _, s in def.nodes[estado.no].exits or {} do
		if s.event == nome and avaliar(s.requires, estado) then
			return true
		end
	end
	return false
end

function StoryRunner.Step(def: any, estado: any, evento: any): (any, { any }, string)
	if type(evento) ~= "table" or type(evento.id) ~= "string" or type(evento.name) ~= "string" then
		return estado, {}, "invalido"
	end
	if estado.vistos[evento.id] then
		return estado, {}, "repetido"
	end
	local novo = copiaProfunda(estado)
	novo.vistos[evento.id] = true
	table.insert(novo.ordemVistos, evento.id)
	if #novo.ordemVistos > MAX_VISTOS then
		novo.vistos[table.remove(novo.ordemVistos, 1)] = nil
	end
	if novo.final then
		return novo, {}, "ignorado"
	end
	local saida = nil
	for _, s in def.nodes[novo.no].exits or {} do
		if s.event == evento.name and (s.kind == nil or s.kind == evento.kind) and avaliar(s.requires, novo) then
			saida = s
			break
		end
	end
	if not saida then
		-- fora de ordem: não avança capítulo nem muda a revisão
		return novo, {}, "ignorado"
	end
	local efeitos = {}
	for k, v in saida.set or {} do
		novo.flags[k] = v
	end
	StoryRunner._emitir(novo, efeitos, saida.effects, novo.no .. ">" .. saida.to)
	novo.no = saida.to
	novo.revisao += 1
	local destino = def.nodes[saida.to]
	StoryRunner._emitir(novo, efeitos, destino.onEnter, saida.to .. ":entrada")
	if destino.final then
		novo.final = true
	end
	return novo, efeitos, "avancou"
end

return StoryRunner
