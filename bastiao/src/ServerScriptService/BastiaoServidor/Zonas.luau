--!strict
-- PROJETO BASTIÃO :: Zonas
-- Gatilhos de chegada medidos no servidor (sem Touched): a cada verificação, se a etapa
-- atual espera a zona e algum jogador vivo está dentro dela, a missão recebe o evento.
-- Uma zona pode exigir uma condição extra (ex.: o Pavel já chegou à porta).

local Zonas = {}
Zonas.__index = Zonas

export type Forma = {
	centro: Vector3?,
	raio: number?,
	min: Vector3?,
	max: Vector3?,
	condicao: (() -> boolean)?,
}

export type Opcoes = {
	missao: any,
	jogadores: () -> { { jogador: any, pos: Vector3?, vivo: boolean } },
	log: ((string) -> ())?,
}

function Zonas.novo(op: Opcoes)
	local self = setmetatable({}, Zonas)
	self.op = op
	self.zonas = {} :: { [string]: Forma }
	self.serial = 0
	return self
end

function Zonas:registrar(nome: string, forma: Forma)
	assert(self.zonas[nome] == nil, "zona duplicada " .. nome)
	assert((forma.centro and forma.raio) or (forma.min and forma.max), "zona " .. nome .. " sem forma")
	self.zonas[nome] = forma
end

function Zonas.dentro(forma: Forma, p: Vector3): boolean
	if forma.centro and forma.raio then
		return (p - forma.centro).Magnitude <= forma.raio
	end
	local a, b = forma.min :: Vector3, forma.max :: Vector3
	return p.X >= a.X and p.X <= b.X and p.Y >= a.Y and p.Y <= b.Y and p.Z >= a.Z and p.Z <= b.Z
end

-- quem está dentro agora (útil para a trava da oficina e para testes)
function Zonas:quemDentro(nome: string): { any }
	local forma = self.zonas[nome]
	local r = {}
	if not forma then
		return r
	end
	for _, j in self.op.jogadores() do
		if j.vivo and j.pos and Zonas.dentro(forma, j.pos) then
			table.insert(r, j.jogador)
		end
	end
	return r
end

function Zonas:verificar()
	for nome, forma in self.zonas do
		if self.op.missao:espera(nome) and (forma.condicao == nil or forma.condicao()) then
			local quem = self:quemDentro(nome)
			if #quem > 0 then
				self.serial += 1
				self.op.missao:reportar({
					id = "zona:" .. nome .. ":" .. self.serial,
					kind = "zona",
					name = nome,
					actor = quem[1].UserId,
				})
			end
		end
	end
end

return Zonas
