--!strict
-- PROJETO BASTIÃO :: Checkpoint (CheckpointService do plano, versão desta etapa)
-- Guarda o último ponto seguro do servidor: uma cópia só de dados do estado da história,
-- o retrato do mundo e onde os jogadores renascem. Nesta etapa não há morte por monstro,
-- então o retrato serve para quem renasce ou entra depois não ficar do lado de fora da
-- oficina travada. Nada vai para DataStore: o progresso salvo dos jogadores não é tocado.

local Checkpoint = {}
Checkpoint.__index = Checkpoint

export type Ponto = { id: string, estado: any, retrato: { [string]: string }, spawn: CFrame? }

function Checkpoint.novo(spawns: { [string]: CFrame })
	local self = setmetatable({}, Checkpoint)
	self.spawns = spawns
	self.ultimoPonto = nil :: Ponto?
	self.ouvintes = {} :: { (p: Ponto) -> () }
	return self
end

function Checkpoint:salvar(id: string, estado: any, retrato: { [string]: string })
	local p: Ponto = { id = id, estado = estado, retrato = retrato, spawn = self.spawns[id] }
	-- um ponto sem lugar de renascer não apaga o lugar do ponto anterior
	if p.spawn == nil and self.ultimoPonto then
		p.spawn = self.ultimoPonto.spawn
	end
	self.ultimoPonto = p
	-- ouvintes não podem esperar aqui (quem precisa esperar abre a própria thread)
	for _, fn in self.ouvintes do
		pcall(fn, p)
	end
end

function Checkpoint:aoSalvar(fn: (p: Ponto) -> ())
	table.insert(self.ouvintes, fn)
end

function Checkpoint:ultimo(): Ponto?
	return self.ultimoPonto
end

function Checkpoint:spawn(): CFrame?
	return self.ultimoPonto and self.ultimoPonto.spawn
end

return Checkpoint
