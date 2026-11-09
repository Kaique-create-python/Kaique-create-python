--!strict
-- Quem ataca quem. Facções: hostile, ally, pet, neutral, player.
-- Vínculos de rivalidade/caça entre acontecimentos têm prioridade.

local Factions = {}

export type Actor = {
	faction: string,
	eventId: number?,
	enemies: { [number]: boolean }?, -- ids de acontecimentos rivais
	prey: { [number]: boolean }?, -- ids de acontecimentos caçados
	provokedBy: { [any]: number }?, -- atacantes recentes -> instante
	owner: Player?,
}

local now = os.clock

-- a é inimigo de b?
function Factions.hostileTo(a: Actor, b: Actor): boolean
	if a == b then
		return false
	end
	if a.eventId and b.eventId and a.eventId == b.eventId then
		return false
	end
	if b.eventId and a.enemies and a.enemies[b.eventId] then
		return true
	end
	if b.eventId and a.prey and a.prey[b.eventId] then
		return true
	end
	if a.provokedBy then
		local key: any = if b.eventId then b.eventId else b.owner
		local t = a.provokedBy[key]
		if t and now() - t < 12 then
			return true
		end
	end
	local fa, fb = a.faction, b.faction
	if fa == "hostile" then
		return fb == "player" or fb == "ally" or fb == "pet"
	elseif fa == "ally" or fa == "pet" then
		return fb == "hostile"
	end
	return false
end

-- registra provocação (neutros revidam por alguns segundos)
function Factions.provoke(victim: Actor, attacker: Actor)
	if victim.faction == "player" then
		return
	end
	victim.provokedBy = victim.provokedBy or {}
	local key: any = if attacker.eventId then attacker.eventId else attacker.owner
	if key then
		(victim.provokedBy :: any)[key] = now()
	end
end

return Factions
