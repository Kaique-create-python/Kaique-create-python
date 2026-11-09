--!strict
-- Dano, cura e empurrões com regras de facção e PvP.
-- Todo dano passa por aqui: assim cooldowns, créditos de abate e status ficam
-- consistentes e o cliente nunca decide quem tomou dano.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.IdeiasShared.Config)
local Actors = require(script.Parent.Actors)
local Factions = require(script.Parent.Factions)
local Status = require(script.Parent.Status)
local Fx = require(script.Parent.Fx)

local Combat = {}

local killListeners: { (victim: any, attacker: any?) -> () } = {}

function Combat.onKill(fn: (victim: any, attacker: any?) -> ())
	table.insert(killListeners, fn)
end

local function creditOwner(attacker: any?): Player?
	if not attacker then
		return nil
	end
	if attacker.kind == "player" then
		return attacker.player
	end
	return attacker.owner
end

function Combat.canHurt(attacker: any?, victim: any): boolean
	if not victim or not victim.humanoid then
		return false
	end
	if attacker == victim then
		return false
	end
	if attacker and attacker.faction == "player" and victim.faction == "player" then
		return Config.Combat.PvP
	end
	-- NPCs de um jogador nunca machucam o próprio dono
	if attacker and victim.faction == "player" and attacker.owner == victim.player and attacker.faction ~= "hostile" then
		return false
	end
	return true
end

function Combat.damage(victim: any, amount: number, attacker: any?, element: string?): boolean
	if not victim or not Actors.alive(victim) then
		return false
	end
	if not Combat.canHurt(attacker, victim) then
		return false
	end
	local h: Humanoid = victim.humanoid
	if attacker then
		Factions.provoke(victim, attacker)
	end
	local scale = if victim.faction == "player" then Config.Combat.PlayerDamageScale else 1
	-- luz causa dano extra em mortos-vivos e sombras
	if element == "light" and victim.def and victim.def.tagSet and (victim.def.tagSet.undead or victim.def.tagSet.evil) then
		scale *= 1.6
	end
	local before = h.Health
	h:TakeDamage(amount * scale)
	if element then
		Status.applyElement(h, element)
	end
	local owner = creditOwner(attacker)
	if owner then
		h:SetAttribute("UltimoAtacante", owner.UserId)
	end
	if before > 0 and h.Health <= 0 and not h:GetAttribute("Abatido") then
		h:SetAttribute("Abatido", true)
		for _, fn in killListeners do
			task.spawn(fn, victim, attacker)
		end
	end
	return true
end

function Combat.heal(victim: any, amount: number)
	if victim and Actors.alive(victim) then
		local h: Humanoid = victim.humanoid
		h.Health = math.min(h.MaxHealth, h.Health + amount)
	end
end

-- empurrão: jogadores recebem o impulso pelo cliente (dono da física do personagem)
function Combat.push(victim: any, velocity: Vector3)
	if not victim or not Actors.alive(victim) then
		return
	end
	if victim.kind == "player" then
		Fx.impulse(victim.player, velocity)
	else
		local root: BasePart = victim.root
		if not root.Anchored then
			root.AssemblyLinearVelocity += velocity
		end
	end
end

-- dano em área com queda linear por distância
function Combat.area(pos: Vector3, radius: number, amount: number, attacker: any?, element: string?, knock: number?, filter: ((any) -> boolean)?): number
	local hits = 0
	for _, a in Actors.near(pos, radius) do
		if (not filter or filter(a)) and (not attacker or attacker == nil or a ~= attacker) then
			local d = (a.root.Position - pos).Magnitude
			local f = 1 - math.clamp(d / radius, 0, 1) * 0.6
			if Combat.damage(a, amount * f, attacker, element) then
				hits += 1
				if knock and knock > 0 then
					local dir = (a.root.Position - pos)
					dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.yAxis
					Combat.push(a, (dir + Vector3.new(0, 0.6, 0)).Unit * knock * f)
				end
			end
		end
	end
	return hits
end

-- dano em área só contra inimigos do atacante (para NPCs e ferramentas)
function Combat.areaEnemies(pos: Vector3, radius: number, amount: number, attacker: any, element: string?, knock: number?): number
	return Combat.area(pos, radius, amount, attacker, element, knock, function(a)
		if attacker.kind == "player" then
			return a.kind == "npc" and a.faction ~= "pet" and a.owner ~= attacker.player
		end
		return Factions.hostileTo(attacker, a)
	end)
end

return Combat
