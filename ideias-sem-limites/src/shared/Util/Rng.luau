--!strict
-- Gerador pseudoaleatório determinístico (Park–Miller "minimal standard").
-- Mesmo resultado no Roblox, no Lune e na Luau Execution API: o mapa e os
-- acontecimentos "surpresa" ficam reprodutíveis e testáveis.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

local MOD = 2147483647

function Rng.new(seed: number): Rng
	local s = math.floor(math.abs(seed)) % MOD
	if s == 0 then
		s = 1234567
	end
	local self = setmetatable({ state = s }, Rng)
	-- descarta os primeiros valores (sementes próximas geram saídas próximas)
	for _ = 1, 3 do
		self:nextInt()
	end
	return self
end

function Rng.nextInt(self: Rng): number
	self.state = (self.state * 16807) % MOD
	return self.state
end

-- [0, 1)
function Rng.float(self: Rng): number
	return (self:nextInt() - 1) / (MOD - 1)
end

function Rng.range(self: Rng, a: number, b: number): number
	return a + (b - a) * self:float()
end

-- inteiro em [a, b]
function Rng.int(self: Rng, a: number, b: number): number
	if b < a then
		return a
	end
	return a + math.floor(self:float() * (b - a + 1))
end

function Rng.chance(self: Rng, p: number): boolean
	return self:float() < p
end

function Rng.pick<T>(self: Rng, list: { T }): T
	return list[self:int(1, #list)]
end

function Rng.sign(self: Rng): number
	return if self:float() < 0.5 then -1 else 1
end

-- escolhe item de uma lista com pesos (campo weight, padrão 1)
function Rng.weighted<T>(self: Rng, list: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, item in list do
		total += math.max(0, weightOf(item))
	end
	local roll = self:float() * total
	for _, item in list do
		roll -= math.max(0, weightOf(item))
		if roll < 0 then
			return item
		end
	end
	return list[#list]
end

function Rng.fork(self: Rng, salt: number): Rng
	return Rng.new(self:nextInt() + salt * 7919)
end

function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
