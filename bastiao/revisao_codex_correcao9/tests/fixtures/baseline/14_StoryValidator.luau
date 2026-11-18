--!strict
-- PROJETO BASTIÃO :: StoryValidator (Tarefa 1)
-- Confere um capítulo antes de rodar e diz exatamente qual nó/campo está errado:
-- IDs, referências, tipos de efeito, entidades, sequências, flags do esquema, nós
-- inalcançáveis, nó sem saída que não é final e final acidental.

local Validator = {}

local EFEITOS = { objetivo = true, entidade = true, sequencia = true, checkpoint = true }

function Validator.Validate(def: any, entidades: { [string]: any }?): { ok: boolean, erros: { string } }
	local erros = {}
	local function erro(msg: string)
		table.insert(erros, msg)
	end
	if type(def) ~= "table" or type(def.id) ~= "string" or type(def.nodes) ~= "table" then
		return { ok = false, erros = { "definição sem id/nodes" } }
	end
	if not def.nodes[def.start] then
		erro("start aponta para nó ausente: " .. tostring(def.start))
	end
	local esquema = def.flagSchema or {}
	local function conferirCondicao(c: any, onde: string)
		if c == nil then
			return
		end
		if c.All or c.Any then
			for _, x in c.All or c.Any do
				conferirCondicao(x, onde)
			end
		elseif c.Not then
			conferirCondicao(c.Not, onde)
		elseif c.Flag then
			if esquema[c.Flag[1]] == nil then
				erro(onde .. ": flag fora do esquema " .. tostring(c.Flag[1]))
			end
		else
			erro(onde .. ": condição desconhecida")
		end
	end
	local function conferirEfeitos(lista: { any }?, onde: string)
		for i, e in lista or {} do
			local aqui = onde .. ".efeito[" .. i .. "]"
			if not EFEITOS[e.tipo] then
				erro(aqui .. ": tipo não registrado " .. tostring(e.tipo))
			elseif e.tipo == "entidade" then
				if type(e.id) ~= "string" or type(e.estado) ~= "string" then
					erro(aqui .. ": entidade precisa de id e estado")
				elseif entidades and not entidades[e.id] then
					erro(aqui .. ": entidade inexistente " .. e.id)
				elseif entidades and entidades[e.id].estados and not entidades[e.id].estados[e.estado] then
					erro(aqui .. ": estado " .. e.estado .. " não existe em " .. e.id)
				end
			elseif e.tipo == "sequencia" then
				if not (def.sequences and def.sequences[e.id]) then
					erro(aqui .. ": sequência inexistente " .. tostring(e.id))
				end
			elseif e.tipo == "objetivo" then
				if e.texto ~= nil and type(e.texto) ~= "string" then
					erro(aqui .. ": objetivo precisa de texto")
				end
			end
		end
	end
	for id, no in def.nodes do
		local onde = "nodes." .. id
		conferirEfeitos(no.onEnter, onde .. ".onEnter")
		if not no.final and (no.exits == nil or #no.exits == 0) then
			erro(onde .. ": nó sem saída que não é final")
		end
		if no.final and no.exits and #no.exits > 0 then
			erro(onde .. ": final com saídas")
		end
		local eventos = {}
		for i, s in no.exits or {} do
			local aqui = onde .. ".exits[" .. i .. "]"
			if not def.nodes[s.to] then
				erro(aqui .. ": destino ausente " .. tostring(s.to))
			end
			if type(s.event) ~= "string" then
				erro(aqui .. ": evento sem nome")
			end
			if eventos[s.event] and s.requires == nil then
				erro(aqui .. ": evento repetido sem condição " .. tostring(s.event))
			end
			eventos[s.event] = true
			for k in s.set or {} do
				if esquema[k] == nil then
					erro(aqui .. ": flag fora do esquema " .. k)
				end
			end
			conferirCondicao(s.requires, aqui)
			conferirEfeitos(s.effects, aqui)
		end
	end
	for id, seq in def.sequences or {} do
		for i, cue in seq.cues or {} do
			if cue.entidade and entidades and not entidades[cue.entidade] then
				erro("sequences." .. id .. ".cues[" .. i .. "]: entidade inexistente " .. cue.entidade)
			end
		end
	end
	-- alcance: todo nó precisa ser alcançável a partir do início, e algum final precisa existir
	local vistos = {}
	local fila = { def.start }
	while #fila > 0 do
		local id = table.remove(fila, 1)
		if not vistos[id] and def.nodes[id] then
			vistos[id] = true
			for _, s in def.nodes[id].exits or {} do
				table.insert(fila, s.to)
			end
		end
	end
	local temFinal = false
	for id, no in def.nodes do
		if not vistos[id] then
			erro("nodes." .. id .. ": inalcançável")
		end
		if no.final and vistos[id] then
			temFinal = true
		end
	end
	if not temFinal then
		erro("nenhum final alcançável")
	end
	table.sort(erros)
	return { ok = #erros == 0, erros = erros }
end

return Validator
