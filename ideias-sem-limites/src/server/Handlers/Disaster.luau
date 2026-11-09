--!strict
-- Despachante de desastres: escolhe a implementação pelo params.kind.

local Impact = require(script.Parent.Disasters.Impact)
local Storms = require(script.Parent.Disasters.Storms)
local Ground = require(script.Parent.Disasters.Ground)
local Cosmic = require(script.Parent.Disasters.Cosmic)

local H = { name = "disaster" }

local KINDS: { [string]: (any) -> any } = {
	meteor = Impact.meteor,
	rockfall = Impact.rockfall,
	laser_storm = Impact.laser_storm,
	explosion = Impact.explosion,
	tornado = Storms.tornado,
	tsunami = Storms.tsunami,
	lightning = Storms.lightning,
	blizzard = Storms.blizzard,
	acid_rain = Storms.acid_rain,
	sandstorm = Storms.sandstorm,
	wind = Storms.wind,
	gravity = Storms.gravity,
	earthquake = Ground.earthquake,
	volcano = Ground.volcano,
	fire = Ground.fire,
	ice = Ground.ice,
	lava = Ground.lava,
	black_hole = Cosmic.black_hole,
	chaos = Cosmic.chaos,
}

H.Kinds = KINDS

function H.estimate(spec: any): { [string]: number }
	local k = spec.params.kind
	if k == "meteor" then
		return { events = 1, dynamic = 4, effects = 6, parts = 12 * math.min((spec.params.count or 1) * spec.count, 14) }
	elseif k == "volcano" then
		return { events = 1, effects = 6, parts = 20 }
	elseif k == "fire" then
		return { events = 1, effects = 14, parts = 20 }
	elseif k == "ice" then
		return { events = 1, effects = 2, parts = 30 }
	elseif k == "chaos" then
		return { events = 1 }
	end
	return { events = 1, effects = 6, parts = 10 }
end

function H.spawn(ctx: any): any
	local f = KINDS[ctx.params.kind]
	if not f then
		error("desastre desconhecido: " .. tostring(ctx.params.kind))
	end
	return f(ctx)
end

return H
