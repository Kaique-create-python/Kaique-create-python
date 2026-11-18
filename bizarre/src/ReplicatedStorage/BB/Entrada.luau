-- BIZARRE BATTLEGROUNDS :: pedido de entrada na luta (AJUSTE7)
-- O celular manda um pedido com número; o servidor responde UMA vez pelo remoto privado
-- ("entrada": id, ok, motivo). O menu só fecha quando chega o "ok" daquele pedido.
-- Pedidos repetidos durante o carregamento não criam entradas nem bots duplicados.

local Entrada = {}

Entrada.ESPERA_MAXIMA = 25 -- segundos sem resposta: o botão volta a funcionar

local contador = 0
function Entrada.novoId(semente: number?): string
	contador += 1
	return string.format("e%d_%d", math.floor((semente or os.clock()) * 1000) % 100000000, contador)
end

-- servidor: decide se um pedido novo pode começar
-- estado = { pendente = {id, t}?, vivo = bool, emCombate = bool, adm = bool }
function Entrada.validar(estado: any, dados: any, agora: number, standValido: (any) -> boolean): (boolean, string?, string?)
	if type(dados) ~= "table" then
		return false, "pedido inválido", nil
	end
	local id = if type(dados.id) == "string" and #dados.id > 0 and #dados.id <= 40 then dados.id else nil
	if not standValido(dados.stand) then
		return false, "Stand inválido", id
	end
	local p = estado.pendente
	if p and agora - p.t < Entrada.ESPERA_MAXIMA then
		if id and p.id == id then
			return false, "duplicado", id -- o mesmo pedido de novo: ignora em silêncio
		end
		return false, "Aguarde: você já está entrando.", id
	end
	if estado.vivo and estado.emCombate and not estado.adm then
		return false, "Saia do combate por alguns segundos para trocar de Stand.", id
	end
	return true, nil, id
end

-- celular: guarda o pedido pendente e aceita só a primeira resposta com o mesmo id
function Entrada.novoCliente()
	local c = { pendente = nil :: any, respondidos = {} :: { [string]: boolean } }
	function c.pedir(agora: number): string?
		if c.pendente and agora - c.pendente.t < Entrada.ESPERA_MAXIMA then
			return nil -- já tem um pedido em andamento
		end
		local id = Entrada.novoId(agora)
		c.pendente = { id = id, t = agora }
		return id
	end
	-- devolve "ok", "recusado" ou nil (resposta velha/duplicada: ignorar)
	function c.resposta(msg: any): string?
		if type(msg) ~= "table" or type(msg.id) ~= "string" then
			return nil
		end
		if c.respondidos[msg.id] then
			return nil
		end
		if not c.pendente or c.pendente.id ~= msg.id then
			return nil
		end
		c.respondidos[msg.id] = true
		c.pendente = nil
		return if msg.ok then "ok" else "recusado"
	end
	function c.expirou(agora: number): boolean
		if c.pendente and agora - c.pendente.t >= Entrada.ESPERA_MAXIMA then
			c.pendente = nil
			return true
		end
		return false
	end
	return c
end

return Entrada
