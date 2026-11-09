--!strict
-- Orçamento global de desempenho. Cada acontecimento reserva um custo antes de
-- nascer e devolve ao ser removido. Nada nasce se o orçamento não comportar.

local Config = require(game:GetService("ReplicatedStorage").IdeiasShared.Config)

local Budget = {}

export type Cost = { events: number?, npcs: number?, dynamic: number?, effects: number?, parts: number? }

local KEYS = { "events", "npcs", "dynamic", "effects", "parts" }
local used: { [string]: number } = { events = 0, npcs = 0, dynamic = 0, effects = 0, parts = 0 }

function Budget.limits(): { [string]: number }
	return Config.Budget
end

function Budget.used(): { [string]: number }
	return table.clone(used)
end

function Budget.fits(cost: Cost): (boolean, string?)
	for _, k in KEYS do
		local need = (cost :: any)[k] or 0
		if need > 0 and used[k] + need > (Config.Budget :: any)[k] then
			return false, k
		end
	end
	return true, nil
end

-- quanto de "npcs"/"dynamic" ainda cabe (para reduzir quantidades)
function Budget.free(key: string): number
	return math.max(0, (Config.Budget :: any)[key] - used[key])
end

function Budget.reserve(cost: Cost)
	for _, k in KEYS do
		used[k] += (cost :: any)[k] or 0
	end
end

function Budget.release(cost: Cost)
	for _, k in KEYS do
		used[k] = math.max(0, used[k] - ((cost :: any)[k] or 0))
	end
end

function Budget.adjust(key: string, delta: number)
	used[key] = math.max(0, used[key] + delta)
end

function Budget.reset()
	for _, k in KEYS do
		used[k] = 0
	end
end

-- 0..1, usado no indicador de capacidade da interface
function Budget.load(): number
	local worst = 0
	for _, k in KEYS do
		worst = math.max(worst, used[k] / (Config.Budget :: any)[k])
	end
	return worst
end

return Budget
