--!strict
-- PROJETO BASTIÃO :: Interacoes
-- O prompt pede uma ação; só o servidor mede o hold e decide se ela pode acontecer.
-- Rádio/terminal continuam instantâneos (HoldDuration = 0), com as mesmas validações.

local Interacoes = {}
Interacoes.__index = Interacoes

local INTERVALO_MIN = 0.4
local INTERVALO_INICIO = 0.35
local TOLERANCIA_HOLD = 0.05 -- diferença de ordem/frame, nunca um relógio do cliente
local VALIDADE_HOLD = 12
local GRACA_FIM = 2 -- HoldEnded pode chegar antes de Triggered na conclusão legítima

export type Registro = {
	posicao: () -> Vector3,
	alcance: number,
	evento: string?,
	requer: { { string } }?,
	disponivel: (() -> boolean)?,
	validar: ((jogador: any) -> (boolean, string?, { any }?))?, -- motivo = chave de Textos.avisos
	aoAceitar: ((jogador: any) -> ())?,
	prompt: any?,
}

export type Opcoes = {
	missao: any,
	mundo: any,
	localizar: (jogador: any) -> (Vector3?, boolean),
	agora: () -> number,
	validarJogador: ((jogador: any) -> boolean)?,
	visivel: ((jogador: any, registro: Registro, origem: Vector3, alvo: Vector3) -> boolean)?,
	aviso: ((jogador: any, chave: string, args: { any }?) -> ())?,
	log: ((string) -> ())?,
}

type Hold = { nome: string, prompt: any, inicio: number, duracao: number, fim: number? }

local function finito(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

local function posicaoValida(p: any): boolean
	return typeof(p) == "Vector3" and finito(p.X) and finito(p.Y) and finito(p.Z)
end

function Interacoes.novo(op: Opcoes)
	local self = setmetatable({}, Interacoes)
	self.op = op
	self.log = op.log or function(_m: string) end
	self.registros = {} :: { [string]: Registro }
	self.ordem = {} :: { string }
	self.duracoes = {} :: { [string]: number }
	self.ultimo = {} :: { [any]: { [string]: number } }
	self.inicios = {} :: { [any]: number }
	self.holds = {} :: { [any]: Hold }
	self.serial = 0
	return self
end

function Interacoes:registrar(nome: string, r: Registro)
	assert(type(nome) == "string" and nome ~= "", "interação sem nome")
	assert(self.registros[nome] == nil, "interação duplicada " .. nome)
	assert(type(r.posicao) == "function" and finito(r.alcance) and r.alcance > 0, "interação " .. nome .. " sem posição/alcance válido")
	local duracao = 0
	if r.prompt ~= nil then
		assert(typeof(r.prompt) == "Instance" and r.prompt:IsA("ProximityPrompt"), "interação " .. nome .. " sem ProximityPrompt")
		duracao = r.prompt.HoldDuration
	end
	assert(finito(duracao) and duracao >= 0 and duracao <= 10, "hold inválido em " .. nome)
	-- Capturada da definição do servidor; nunca da requisição ou mudança local.
	self.duracoes[nome] = duracao
	self.registros[nome] = r
	table.insert(self.ordem, nome)
end

function Interacoes:doPrompt(prompt: any): { string }
	local r = {}
	if prompt == nil then return r end
	for _, nome in self.ordem do
		if self.registros[nome].prompt == prompt then table.insert(r, nome) end
	end
	return r
end

function Interacoes:_estadoOk(r: Registro): boolean
	for _, par in r.requer or {} do
		if self.op.mundo:estado(par[1]) ~= par[2] then return false end
	end
	return true
end

function Interacoes:possivel(nome: string): boolean
	local r = self.registros[nome]
	if not r or not self:_estadoOk(r) then return false end
	if r.evento then return self.op.missao:espera(r.evento) == true end
	return r.disponivel == nil or r.disponivel() == true
end

function Interacoes:atualizar()
	local ligado = {}
	for _, nome in self.ordem do
		local r = self.registros[nome]
		if r.prompt then
			local ok, quer = pcall(self.possivel, self, nome)
			ligado[r.prompt] = ligado[r.prompt] == true or (ok and quer == true)
		end
	end
	for p, quer in ligado do
		if p.Enabled ~= quer then p.Enabled = quer end
	end
end

function Interacoes:_jogadorOk(jogador: any): boolean
	if typeof(jogador) ~= "Instance" or not jogador:IsA("Player") or jogador.Parent == nil then return false end
	if not finito(jogador.UserId) or jogador.UserId % 1 ~= 0 then return false end
	if self.op.validarJogador then return self.op.validarJogador(jogador) == true end
	return jogador.Parent:IsA("Players")
end

function Interacoes:_verificar(jogador: any, r: Registro): (boolean, string?)
	if r.prompt and (r.prompt.Parent == nil or r.prompt.Enabled ~= true) then return false, "indisponivel" end
	local pos, vivo = self.op.localizar(jogador)
	if vivo ~= true or pos == nil then return false, "morto" end
	local alvo = r.posicao()
	if not posicaoValida(pos) or not posicaoValida(alvo) then return false, "posicao_invalida" end
	local distancia = (pos - alvo).Magnitude
	if not finito(distancia) then return false, "posicao_invalida" end
	if distancia > r.alcance then return false, "longe" end
	if not self:_estadoOk(r) then return false, "estado" end
	if r.evento and not self.op.missao:espera(r.evento) then return false, "fora_de_ordem" end
	if r.evento == nil and r.disponivel and r.disponivel() ~= true then return false, "indisponivel" end
	-- Prompt sem adaptador de raycast falha fechado; ações internas sem prompt
	-- continuam possíveis sem exigir uma peça no mundo.
	if self.op.visivel then
		if self.op.visivel(jogador, r, pos, alvo) ~= true then return false, "sem_visao" end
	elseif r.prompt then
		return false, "sem_visao"
	end
	return true, nil
end

-- Um prompt compartilhado só seleciona a ação atualmente esperada. O primeiro
-- nome serve de fallback para retornar a recusa específica quando nada é possível.
function Interacoes:_nomeDoPrompt(prompt: any): string?
	local nomes = self:doPrompt(prompt)
	for _, nome in nomes do
		if self:possivel(nome) then return nome end
	end
	return nomes[1]
end

function Interacoes:iniciarSegurar(jogador: any, prompt: any): (boolean, string?)
	if not self:_jogadorOk(jogador) then return false, "jogador_invalido" end
	local agora = self.op.agora()
	if not finito(agora) or agora < 0 then
		self.holds[jogador] = nil
		return false, "tempo_invalido"
	end
	local anterior = self.inicios[jogador]
	if anterior and agora < anterior then
		self.holds[jogador] = nil
		return false, "tempo_invalido"
	end
	if anterior and agora - anterior < INTERVALO_INICIO then return false, "repetido" end
	self.inicios[jogador] = agora
	self.holds[jogador] = nil
	local nome = self:_nomeDoPrompt(prompt)
	if not nome then return false, "indisponivel" end
	local r = self.registros[nome]
	local ok, motivo = self:_verificar(jogador, r)
	if not ok then return false, motivo end
	self.holds[jogador] = { nome = nome, prompt = prompt, inicio = agora, duracao = self.duracoes[nome] }
	return true, nil
end

function Interacoes:terminarSegurar(jogador: any, prompt: any)
	local hold = self.holds[jogador]
	if not hold or hold.prompt ~= prompt or hold.fim ~= nil then return end
	local agora = self.op.agora()
	if not finito(agora) or agora < hold.inicio then
		self.holds[jogador] = nil
		return
	end
	-- Manter o fim medido: liberação curta não se torna longa com uma espera.
	hold.fim = agora
end

function Interacoes:acionar(jogador: any, prompt: any): (boolean, string?)
	local nome = self:_nomeDoPrompt(prompt)
	if not nome then
		self:cancelar(jogador)
		return false, "indisponivel"
	end
	return self:tentar(jogador, nome)
end

function Interacoes:tentar(jogador: any, nome: string): (boolean, string?)
	local r = self.registros[nome]
	if not r then return false, "desconhecida" end
	if not self:_jogadorOk(jogador) then return false, "jogador_invalido" end
	-- Consumir antes de validar/aplicar: falha, reentrada ou replay não reutilizam o hold.
	local hold = self.holds[jogador]
	self.holds[jogador] = nil
	local agora = self.op.agora()
	if not finito(agora) or agora < 0 or (hold and agora < hold.inicio) then return false, "tempo_invalido" end
	local ultimos = self.ultimo[jogador]
	local anterior = ultimos and ultimos[nome]
	if anterior and agora < anterior then return false, "tempo_invalido" end
	if anterior and agora - anterior < INTERVALO_MIN then return false, "repetido" end
	if not ultimos then
		ultimos = {}
		self.ultimo[jogador] = ultimos
	end
	ultimos[nome] = agora
	local ok, motivo = self:_verificar(jogador, r)
	if not ok then return false, motivo end
	if self.duracoes[nome] > 0 then
		if not hold then return false, "sem_hold" end
		if hold.nome ~= nome or hold.prompt ~= r.prompt then return false, "hold_diferente" end
		if agora - hold.inicio > VALIDADE_HOLD or (hold.fim and agora - hold.fim > GRACA_FIM) then return false, "hold_expirado" end
		local tolerancia = math.min(TOLERANCIA_HOLD, hold.duracao * 0.1)
		if (hold.fim or agora) - hold.inicio < hold.duracao - tolerancia then return false, "hold_curto" end
	end
	if r.validar then
		local permitido, recusa, args = r.validar(jogador)
		if permitido ~= true then
			if recusa and self.op.aviso then self.op.aviso(jogador, recusa, args) end
			return false, recusa or "regra"
		end
	end
	if r.aoAceitar then r.aoAceitar(jogador) end
	if r.evento then
		self.serial += 1
		self.op.missao:reportar({
			id = "int:" .. nome .. ":" .. tostring(jogador.UserId) .. ":" .. self.serial,
			kind = "interacao", name = r.evento, actor = jogador.UserId,
		})
	end
	self:atualizar()
	return true, nil
end

-- Missão/mundo mudaram, mesmo que depois voltem ao mesmo estado.
function Interacoes:invalidar()
	table.clear(self.holds)
end

-- Morte/respawn cancelam a ação sem reiniciar o limitador de tentativas.
function Interacoes:cancelar(jogador: any)
	if typeof(jogador) == "Instance" and jogador:IsA("Player") then self.holds[jogador] = nil end
end

function Interacoes:esquecer(jogador: any)
	if typeof(jogador) == "Instance" and jogador:IsA("Player") then
		self.holds[jogador] = nil
		self.inicios[jogador] = nil
		self.ultimo[jogador] = nil
	end
end

return Interacoes
