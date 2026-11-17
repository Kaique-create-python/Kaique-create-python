--!strict
-- PROJETO BASTIÃO :: Sequencias (SequenceService do plano)
-- Toca uma sequência com tempo marcado: falas e sons viram mensagens para os clientes (cada
-- um ouve e lê na própria língua), entidades mudam o mundo. As falas usam a duração real da
-- voz (a maior entre as 3 línguas): se uma fala atrasa, tudo o que vem depois anda junto e
-- nada se sobrepõe. Quando a última fala termina, avisa a missão com "<id>_fim".

local Sequencias = {}
Sequencias.__index = Sequencias

local DURACAO_SOM = 2.6
local FOLGA_FIM = 0.6
local RESPIRO_FALAS = 0.3 -- pausa mínima entre duas falas
local SOBRA_VOZ = 0.35 -- a legenda fica um pouco depois da voz acabar

export type Opcoes = {
	def: any, -- capítulo (usa def.sequences)
	textos: any, -- módulo Textos
	mundo: any,
	apresentar: (msg: { [string]: any }) -> (),
	aoTerminar: (id: string, execucao: number) -> (),
	agendar: (segundos: number, fn: () -> ()) -> any,
	cancelar: (handle: any) -> (),
	duracaoLeitura: (texto: string) -> number,
	duracoes: { [string]: number }?, -- duração da voz por fala (tabela Audio.duracoes)
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

-- tempo de leitura da legenda na língua mais longa (russo e inglês costumam passar o português)
function Sequencias:leitura(chave: string): number
	local textos = self.op.textos
	local maior = 0
	if textos.L and textos.IDIOMAS then
		for _, idioma in textos.IDIOMAS do
			local frase = textos.L[idioma] and textos.L[idioma].falas[chave]
			if type(frase) == "string" then
				-- o russo gasta 2 bytes por letra: conta letras, não bytes
				local letras = utf8.len(frase) or #frase
				maior = math.max(maior, self.op.duracaoLeitura(string.rep("x", letras)))
			end
		end
	end
	if maior == 0 then
		local f = textos.falas[chave]
		maior = if f then self.op.duracaoLeitura(f[2]) else 0
	end
	return maior
end

-- tempo que a fala ocupa: a voz (se existir) ou o tempo de leitura da legenda
function Sequencias:duracaoFala(chave: string): number
	local leitura = self:leitura(chave)
	local voz = self.op.duracoes and self.op.duracoes[chave]
	if type(voz) == "number" and voz > 0 then
		return math.max(voz + SOBRA_VOZ, leitura * 0.8, 1.6)
	end
	return leitura
end

function Sequencias:duracaoDeixa(cue: any): number
	if cue.fala then
		return self:duracaoFala(cue.fala)
	elseif cue.som then
		return DURACAO_SOM
	end
	return 0
end

-- horários de verdade de cada deixa e o fim da sequência
function Sequencias:agenda(id: string): ({ { t: number, cue: any } }, number)
	local s = self.op.def.sequences[id]
	assert(s, "sequência inexistente " .. tostring(id))
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
	local itens = {}
	local deslocamento = 0
	local fimFala = -math.huge
	local fim = 0
	for _, item in ordem do
		local cue = item.cue
		local t = cue.t + deslocamento
		if cue.fala then
			local inicio = math.max(t, fimFala + RESPIRO_FALAS)
			deslocamento += inicio - t
			t = inicio
			fimFala = t + self:duracaoFala(cue.fala)
			fim = math.max(fim, fimFala)
		else
			fim = math.max(fim, t + self:duracaoDeixa(cue))
		end
		table.insert(itens, { t = t, cue = cue })
	end
	return itens, fim + FOLGA_FIM
end

function Sequencias:duracao(id: string): number
	local _, fim = self:agenda(id)
	return fim
end

local function posicao(p: any): Vector3?
	if type(p) == "table" and #p == 3 then
		return Vector3.new(p[1], p[2], p[3])
	end
	return nil
end

function Sequencias:_disparar(cue: any)
	local op = self.op
	if cue.fala then
		if op.textos.falas[cue.fala] then
			op.apresentar({ tipo = "fala", chave = cue.fala, duracao = self:duracaoFala(cue.fala) })
		end
	elseif cue.som then
		op.apresentar({ tipo = "som", chave = cue.som, duracao = DURACAO_SOM, pos = posicao(cue.pos) })
	elseif cue.ruido then
		op.apresentar({ tipo = "ruido", chave = cue.ruido, pos = posicao(cue.pos) })
	elseif cue.entidade then
		op.mundo:definir(cue.entidade, cue.estado)
	end
end

function Sequencias:tocar(id: string): number
	local itens, fim = self:agenda(id)
	self.contador += 1
	local execucao = self.contador
	local registro = { handles = {}, id = id }
	self.execucoes[execucao] = registro
	for _, item in itens do
		table.insert(
			registro.handles,
			self.op.agendar(item.t, function()
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
		self.op.agendar(fim, function()
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
