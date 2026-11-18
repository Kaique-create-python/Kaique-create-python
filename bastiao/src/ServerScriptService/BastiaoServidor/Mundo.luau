--!strict
-- PROJETO BASTIÃO :: Mundo (WorldStateService do plano)
-- Guarda o estado desejado de cada entidade da história e chama quem desenha esse estado.
--   * definir() é idempotente: pedir o mesmo estado duas vezes não refaz nada;
--   * entidade ou estado desconhecido nunca derruba o servidor: vira aviso no log;
--   * restaurar() reaplica um retrato inteiro (checkpoint) sem animação.
-- Nada aqui toca no mapa Sector7World: cada entidade só mexe nas peças que o Cenario criou.

local Mundo = {}
Mundo.__index = Mundo

export type Definicao = {
	estados: { [string]: boolean },
	aplicar: (estado: string, instantaneo: boolean) -> (),
	pronto: (() -> boolean)?, -- a entidade terminou a transição? (ex.: o Pavel chegou)
}

function Mundo.novo(log: ((string) -> ())?)
	local self = setmetatable({}, Mundo)
	self.entidades = {} :: { [string]: Definicao }
	self.atual = {} :: { [string]: string }
	self.log = log or function(_m: string) end
	self.ouvintes = {} :: { (id: string, estado: string) -> () }
	return self
end

function Mundo:registrar(id: string, def: Definicao)
	assert(type(id) == "string" and id ~= "", "entidade sem id")
	assert(type(def) == "table" and type(def.estados) == "table" and type(def.aplicar) == "function", "entidade " .. id .. " sem estados/aplicar")
	assert(self.entidades[id] == nil, "entidade registrada duas vezes: " .. id)
	self.entidades[id] = def
end

-- registro no formato que o StoryValidator entende
function Mundo:registro(): { [string]: { estados: { [string]: boolean } } }
	local r = {}
	for id, def in self.entidades do
		r[id] = { estados = def.estados }
	end
	return r
end

function Mundo:estado(id: string): string?
	return self.atual[id]
end

function Mundo:pronto(id: string): boolean
	local def = self.entidades[id]
	if not def or not def.pronto then
		return def ~= nil
	end
	local ok, r = pcall(def.pronto)
	return ok and r == true
end

function Mundo:aoMudar(fn: (id: string, estado: string) -> ())
	table.insert(self.ouvintes, fn)
end

-- devolve true quando o estado mudou de fato
function Mundo:definir(id: string, estado: string, instantaneo: boolean?): boolean
	local def = self.entidades[id]
	if not def then
		self.log("[Bastiao] entidade desconhecida: " .. tostring(id))
		return false
	end
	if not def.estados[estado] then
		self.log("[Bastiao] estado " .. tostring(estado) .. " não existe em " .. id)
		return false
	end
	if self.atual[id] == estado then
		return false
	end
	self.atual[id] = estado
	local ok, err = pcall(def.aplicar, estado, instantaneo == true)
	if not ok then
		self.log("[Bastiao] falha ao aplicar " .. id .. "=" .. estado .. ": " .. tostring(err))
	end
	for _, fn in self.ouvintes do
		local okO, errO = pcall(fn, id, estado)
		if not okO then
			self.log("[Bastiao] ouvinte do mundo falhou: " .. tostring(errO))
		end
	end
	return true
end

-- retrato de um checkpoint: reaplica tudo sem animação, mesmo o que já estava igual
function Mundo:restaurar(retrato: { [string]: string })
	for id, estado in retrato do
		self.atual[id] = nil
		self:definir(id, estado, true)
	end
end

function Mundo:retrato(): { [string]: string }
	local r = {}
	for id, estado in self.atual do
		r[id] = estado
	end
	return r
end

return Mundo
