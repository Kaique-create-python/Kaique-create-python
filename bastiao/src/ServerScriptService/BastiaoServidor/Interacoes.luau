--!strict
-- PROJETO BASTIÃO :: Interacoes (InteractionService do plano)
-- Toda interação passa pelo servidor antes de virar evento da história:
--   jogador ainda no jogo e vivo -> alcance medido no servidor -> sem repetição rápida ->
--   entidade no estado certo -> a etapa atual espera esse evento -> regra própria (ex.: só
--   quem carrega o módulo encaixa). O ProximityPrompt é só a porta de entrada; o cliente
--   nunca decide nada.

local Interacoes = {}
Interacoes.__index = Interacoes

local INTERVALO_MIN = 0.4 -- segundos entre duas tentativas do mesmo jogador na mesma interação

export type Registro = {
	posicao: () -> Vector3,
	alcance: number,
	evento: string?, -- evento da história; nil = ação local (ex.: pegar de volta o módulo)
	requer: { { string } }?, -- { {entidade, estado}, ... }
	disponivel: (() -> boolean)?, -- para ações locais: quando o prompt aparece
	validar: ((jogador: any) -> (boolean, string?))?,
	aoAceitar: ((jogador: any) -> ())?,
	prompt: any?,
}

export type Opcoes = {
	missao: any,
	mundo: any,
	localizar: (jogador: any) -> (Vector3?, boolean),
	agora: () -> number,
	aviso: ((jogador: any, texto: string) -> ())?,
	log: ((string) -> ())?,
}

function Interacoes.novo(op: Opcoes)
	local self = setmetatable({}, Interacoes)
	self.op = op
	self.log = op.log or function(_m: string) end
	self.registros = {} :: { [string]: Registro }
	self.ordem = {} :: { string }
	self.ultimo = {} :: { [string]: number }
	self.serial = 0
	return self
end

function Interacoes:registrar(nome: string, r: Registro)
	assert(self.registros[nome] == nil, "interação duplicada " .. nome)
	assert(type(r.posicao) == "function" and type(r.alcance) == "number", "interação " .. nome .. " sem posição/alcance")
	self.registros[nome] = r
	table.insert(self.ordem, nome)
end

-- nomes ligados a um mesmo prompt, na ordem em que foram registrados
function Interacoes:doPrompt(prompt: any): { string }
	local r = {}
	for _, nome in self.ordem do
		if self.registros[nome].prompt == prompt then
			table.insert(r, nome)
		end
	end
	return r
end

-- um prompt pode servir a mais de uma interação (ex.: pegar o módulo pela primeira vez ou
-- pegar de volta do carregador); vale a primeira que for possível agora
function Interacoes:acionar(jogador: any, prompt: any): (boolean, string?)
	local motivo = "indisponivel"
	for _, nome in self:doPrompt(prompt) do
		if self:possivel(nome) then
			return self:tentar(jogador, nome)
		end
	end
	return false, motivo
end

function Interacoes:_estadoOk(r: Registro): boolean
	for _, par in r.requer or {} do
		if self.op.mundo:estado(par[1]) ~= par[2] then
			return false
		end
	end
	return true
end

-- o prompt aparece só quando a interação é possível agora (o servidor valida de novo)
function Interacoes:possivel(nome: string): boolean
	local r = self.registros[nome]
	if not r or not self:_estadoOk(r) then
		return false
	end
	if r.evento then
		return self.op.missao:espera(r.evento)
	end
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
		if p.Enabled ~= quer then
			p.Enabled = quer
		end
	end
end

local function chaveJogador(jogador: any): string
	return tostring(jogador and jogador.UserId or jogador)
end

function Interacoes:tentar(jogador: any, nome: string): (boolean, string?)
	local r = self.registros[nome]
	if not r then
		return false, "desconhecida"
	end
	if jogador == nil or jogador.Parent == nil then
		return false, "jogador_invalido"
	end
	local pos, vivo = self.op.localizar(jogador)
	if not vivo or pos == nil then
		return false, "morto"
	end
	local distancia = (pos - r.posicao()).Magnitude
	if distancia > r.alcance then
		return false, "longe"
	end
	local chave = chaveJogador(jogador) .. "|" .. nome
	local agora = self.op.agora()
	local anterior = self.ultimo[chave]
	if anterior and agora - anterior < INTERVALO_MIN then
		return false, "repetido"
	end
	self.ultimo[chave] = agora
	if not self:_estadoOk(r) then
		return false, "estado"
	end
	if r.evento and not self.op.missao:espera(r.evento) then
		return false, "fora_de_ordem"
	end
	if r.evento == nil and r.disponivel and not r.disponivel() then
		return false, "indisponivel"
	end
	if r.validar then
		local ok, motivo = r.validar(jogador)
		if not ok then
			if motivo and self.op.aviso then
				self.op.aviso(jogador, motivo)
			end
			return false, motivo or "regra"
		end
	end
	if r.aoAceitar then
		r.aoAceitar(jogador)
	end
	if r.evento then
		self.serial += 1
		self.op.missao:reportar({
			id = "int:" .. nome .. ":" .. chaveJogador(jogador) .. ":" .. self.serial,
			kind = "interacao",
			name = r.evento,
			actor = jogador.UserId,
		})
	end
	self:atualizar()
	return true, nil
end

-- limpa o controle de repetição de quem saiu (sem vazamento em servidores longos)
function Interacoes:esquecer(jogador: any)
	local prefixo = chaveJogador(jogador) .. "|"
	for chave in self.ultimo do
		if string.sub(chave, 1, #prefixo) == prefixo then
			self.ultimo[chave] = nil
		end
	end
end

return Interacoes
