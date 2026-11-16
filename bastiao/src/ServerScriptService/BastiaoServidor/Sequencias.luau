--!strict
-- PROJETO BASTIÃO :: Sequencias (SequenceService do plano)
-- Toca uma sequência com tempo marcado: falas e sons viram mensagens para os clientes
-- (legendas), entidades mudam o mundo. Quando a última fala termina de ser lida, avisa
-- a missão com o evento "<id>_fim". O relógio é injetado para os testes rodarem sem esperar.

local Sequencias = {}
Sequencias.__index = Sequencias

local DURACAO_SOM = 2.6
local FOLGA_FIM = 0.6

export type Opcoes = {
	def: any, -- capítulo (usa def.sequences)
	textos: any, -- módulo Textos
	mundo: any,
	apresentar: (msg: { [string]: any }) -> (),
	aoTerminar: (id: string, execucao: number) -> (),
	agendar: (segundos: number, fn: () -> ()) -> any,
	cancelar: (handle: any) -> (),
	duracaoLeitura: (texto: string) -> number,
	log: ((string) -> ())?,
}

function Sequencias.novo(op: Opcoes)
	local self = setmetatable({}, Sequencias)
	self.op = op
	self.log = op.log or function(_m: string) end
	self.execucoes = {} :: { [number]: { handles: { any }, id: string } }
	self.contador = 0
	return self
end

-- quanto tempo uma deixa ocupa a tela
function Sequencias:duracaoDeixa(cue: any): number
	if cue.fala then
		local f = self.op.textos.falas[cue.fala]
		return if f then self.op.duracaoLeitura(f[2]) else 0
	elseif cue.som then
		return DURACAO_SOM
	end
	return 0
end

function Sequencias:duracao(id: string): number
	local s = self.op.def.sequences[id]
	local fim = 0
	for _, cue in s.cues do
		fim = math.max(fim, cue.t + self:duracaoDeixa(cue))
	end
	return fim + FOLGA_FIM
end

function Sequencias:_disparar(cue: any)
	local op = self.op
	if cue.fala then
		local f = op.textos.falas[cue.fala]
		if f then
			op.apresentar({ tipo = "fala", chave = cue.fala, duracao = op.duracaoLeitura(f[2]) })
		end
	elseif cue.som then
		op.apresentar({ tipo = "som", chave = cue.som, duracao = DURACAO_SOM })
	elseif cue.entidade then
		op.mundo:definir(cue.entidade, cue.estado)
	end
end

function Sequencias:tocar(id: string): number
	local s = self.op.def.sequences[id]
	assert(s, "sequência inexistente " .. tostring(id))
	self.contador += 1
	local execucao = self.contador
	local registro = { handles = {}, id = id }
	self.execucoes[execucao] = registro
	-- deixas na ordem de tempo (empate: ordem escrita no capítulo)
	local ordem = {}
	for i, cue in s.cues do
		table.insert(ordem, { i = i, cue = cue })
	end
	table.sort(ordem, function(a, b)
		if a.cue.t == b.cue.t then
			return a.i < b.i
		end
		return a.cue.t < b.cue.t
	end)
	for _, item in ordem do
		table.insert(
			registro.handles,
			self.op.agendar(item.cue.t, function()
				if self.execucoes[execucao] then
					local ok, err = pcall(self._disparar, self, item.cue)
					if not ok then
						self.log("[Bastiao] deixa falhou em " .. id .. ": " .. tostring(err))
					end
				end
			end)
		)
	end
	table.insert(
		registro.handles,
		self.op.agendar(self:duracao(id), function()
			if self.execucoes[execucao] then
				self.execucoes[execucao] = nil
				self.op.aoTerminar(id, execucao)
			end
		end)
	)
	return execucao
end

function Sequencias:tocando(): { string }
	local r = {}
	for _, reg in self.execucoes do
		table.insert(r, reg.id)
	end
	table.sort(r)
	return r
end

function Sequencias:cancelarTudo()
	for n, reg in self.execucoes do
		for _, h in reg.handles do
			pcall(self.op.cancelar, h)
		end
		self.execucoes[n] = nil
	end
end

return Sequencias
