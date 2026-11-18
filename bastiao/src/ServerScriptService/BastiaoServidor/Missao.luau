--!strict
-- PROJETO BASTIÃO :: Missao (MissionService do plano)
-- Dono único do estado da história no servidor. Recebe eventos de zonas, interações e
-- sequências numa fila serial, passa cada um pelo StoryRunner e aplica os efeitos:
--   entidade -> Mundo, objetivo -> atributo replicado, sequencia -> Sequencias,
--   checkpoint -> retrato guardado. Nenhum evento é processado em paralelo com outro.

local Missao = {}
Missao.__index = Missao

local MAX_HISTORICO = 40

export type Opcoes = {
	def: any,
	runner: any,
	mundo: any,
	objetivo: (chave: string?) -> (),
	checkpoint: ((id: string, estado: any, retrato: { [string]: string }) -> ())?,
	aoAvancar: ((estado: any) -> ())?,
	aoFinal: ((estado: any) -> ())?,
	log: ((string) -> ())?,
}

function Missao.novo(op: Opcoes)
	local self = setmetatable({}, Missao)
	self.op = op
	self.log = op.log or function(_m: string) end
	self.estado = nil :: any
	self.fila = {} :: { any }
	self.processando = false
	self.historico = {} :: { any }
	self.sequencias = nil :: any
	return self
end

function Missao:ligarSequencias(seq: any)
	self.sequencias = seq
end

function Missao:_aplicar(efeitos: { any }, instantaneo: boolean)
	local op = self.op
	for _, e in efeitos do
		local ok, err = pcall(function()
			if e.tipo == "entidade" then
				op.mundo:definir(e.id, e.estado, instantaneo)
			elseif e.tipo == "objetivo" then
				op.objetivo(e.texto)
			elseif e.tipo == "sequencia" then
				assert(self.sequencias, "sequências não ligadas")
				self.sequencias:tocar(e.id)
			elseif e.tipo == "checkpoint" then
				if op.checkpoint then
					op.checkpoint(e.id, op.runner.copia(self.estado), op.mundo:retrato())
				end
			end
		end)
		if not ok then
			self.log("[Bastiao] efeito " .. tostring(e.key) .. " falhou: " .. tostring(err))
		end
	end
end

function Missao:iniciar()
	local op = self.op
	local estado = op.runner.novo(op.def)
	local efeitos
	estado, efeitos = op.runner.iniciar(op.def, estado)
	self.estado = estado
	self:_aplicar(efeitos, true)
	if op.aoAvancar then
		op.aoAvancar(self.estado)
	end
end

function Missao:espera(nome: string): boolean
	return self.estado ~= nil and self.op.runner.espera(self.op.def, self.estado, nome)
end

function Missao:no(): string?
	return self.estado and self.estado.no
end

function Missao:final(): boolean
	return self.estado ~= nil and self.estado.final == true
end

function Missao:_processar(ev: any)
	local op = self.op
	local antesFinal = self.estado.final
	local novo, efeitos, res = op.runner.Step(op.def, self.estado, ev)
	self.estado = novo
	table.insert(self.historico, { id = ev.id, nome = ev.name, res = res, no = novo.no })
	if #self.historico > MAX_HISTORICO then
		table.remove(self.historico, 1)
	end
	if res == "avancou" then
		self.log(string.format("[Bastiao] %s -> %s (rev %d)", tostring(ev.name), novo.no, novo.revisao))
		self:_aplicar(efeitos, false)
		if op.aoAvancar then
			op.aoAvancar(self.estado)
		end
		if novo.final and not antesFinal and op.aoFinal then
			op.aoFinal(self.estado)
		end
	end
	return res
end

-- fila serial: um evento reportado durante outro só roda quando o primeiro termina
function Missao:reportar(ev: any)
	if self.estado == nil then
		return
	end
	table.insert(self.fila, ev)
	if self.processando then
		return
	end
	self.processando = true
	while #self.fila > 0 do
		local proximo = table.remove(self.fila, 1)
		local ok, err = pcall(self._processar, self, proximo)
		if not ok then
			self.log("[Bastiao] evento " .. tostring(proximo and proximo.name) .. " falhou: " .. tostring(err))
		end
	end
	self.processando = false
end

return Missao
