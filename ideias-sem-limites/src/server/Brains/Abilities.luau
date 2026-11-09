--!strict
-- Habilidades de ataque e suporte dos NPCs. Cada habilidade tem alcance,
-- recarga e efeito; o Brain chama tryUse() a cada "pensamento".

local Combat = require(script.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Core.Actors)
local Factions = require(script.Parent.Parent.Core.Factions)
local Fx = require(script.Parent.Parent.Core.Fx)
local Kit = require(script.Parent.Parent.Builders.Kit)

local Abilities = {}

local function elementColor(element: string?): Color3
	local e = element and Kit.Elements[element]
	return if e then e.color else Color3.fromRGB(255, 255, 255)
end

local function ready(npc: any, name: string, now: number): boolean
	npc.cd = npc.cd or {}
	return (npc.cd[name] or 0) <= now
end

local function cooldown(npc: any, name: string, now: number, seconds: number)
	npc.cd[name] = now + seconds * (0.85 + math.random() * 0.3)
end

local function face(npc: any, target: Vector3)
	if npc.flying then
		return -- orientação dos voadores é controlada pelo Brain
	end
	local pos = npc.root.Position
	local flat = Vector3.new(target.X, pos.Y, target.Z)
	if (flat - pos).Magnitude > 0.5 then
		npc.root.CFrame = CFrame.lookAt(pos, flat)
	end
end

local function mark(npc: any, kind: string)
	-- o cliente usa este atributo para animar o golpe
	npc.model:SetAttribute("Golpe", kind)
	npc.model:SetAttribute("GolpeEm", workspace:GetServerTimeNow())
end

local impl = {}

function impl.melee(npc: any, target: any, dist: number, now: number): boolean
	local reach = npc.reach or 5
	if dist > reach + (target.radius or 2) then
		return false
	end
	mark(npc, "melee")
	Combat.damage(target, npc.dmg, npc, if npc.faction == "hostile" then npc.element else nil)
	if npc.scale > 1.6 then
		Combat.push(target, (target.root.Position - npc.root.Position).Unit * 25 * math.min(npc.scale, 3) + Vector3.new(0, 18, 0))
	end
	cooldown(npc, "melee", now, 1.1)
	return true
end

function impl.breath(npc: any, target: any, dist: number, now: number): boolean
	local range = 16 + 14 * npc.scale
	if dist > range then
		return false
	end
	mark(npc, "breath")
	face(npc, target.root.Position)
	local emitter = npc.breathEmitter
	if emitter then
		emitter.Enabled = true
	end
	cooldown(npc, "breath", now, 6)
	npc.busyUntil = now + 1.2
	task.spawn(function()
		for _ = 1, 4 do
			if not Actors.alive(npc) then
				break
			end
			local origin = if npc.mouth then npc.mouth.WorldPosition else npc.root.Position
			local look = npc.root.CFrame.LookVector
			for _, a in Actors.near(origin, range) do
				if Factions.hostileTo(npc, a) then
					local to = a.root.Position - origin
					if to.Magnitude > 0.1 and look:Dot(to.Unit) > 0.75 then
						Combat.damage(a, npc.dmg * 0.45, npc, npc.element or "fire")
					end
				end
			end
			task.wait(0.3)
		end
		if emitter and emitter.Parent then
			emitter.Enabled = false
		end
	end)
	return true
end

function impl.bolt(npc: any, target: any, dist: number, now: number): boolean
	if dist > 95 or dist < 4 then
		return false
	end
	mark(npc, "bolt")
	face(npc, target.root.Position)
	local from = (if npc.mouth then npc.mouth.WorldPosition else npc.root.Position + Vector3.new(0, 2, 0))
	local aim = target.root.Position
	local speed = 130
	Fx.bolt(from, aim, elementColor(npc.element), speed, 0.5 + 0.2 * npc.scale)
	cooldown(npc, "bolt", now, 2.2)
	task.delay(dist / speed, function()
		if Actors.alive(target) and (target.root.Position - aim).Magnitude < 7 then
			Combat.damage(target, npc.dmg * 0.8, npc, npc.element)
		end
	end)
	return true
end

function impl.stomp(npc: any, target: any, dist: number, now: number): boolean
	local radius = 12 + 6 * npc.scale
	if dist > radius then
		return false
	end
	mark(npc, "stomp")
	local pos = npc.root.Position - Vector3.new(0, npc.hipHeight or 2, 0)
	Fx.shockwave(pos, radius, Color3.fromRGB(200, 180, 140))
	Fx.shake(pos, 0.6 * math.min(npc.scale, 3), radius * 4)
	Combat.areaEnemies(pos, radius, npc.dmg * 1.1, npc, nil, 55)
	cooldown(npc, "stomp", now, 5)
	npc.busyUntil = now + 0.6
	return true
end

function impl.charge(npc: any, target: any, dist: number, now: number): boolean
	if dist < 8 or dist > 50 then
		return false
	end
	mark(npc, "charge")
	npc.chargeUntil = now + 1.1
	cooldown(npc, "charge", now, 6)
	return false -- não bloqueia o movimento: o Brain acelera durante a investida
end

function impl.beam(npc: any, target: any, dist: number, now: number): boolean
	if dist > 70 then
		return false
	end
	mark(npc, "beam")
	Fx.near(npc.root.Position, 300, "beam", { a = npc.root.Position, b = target.root.Position, c = elementColor(npc.element), d = 1.6 })
	Combat.push(target, Vector3.new(0, 55, 0))
	Combat.damage(target, npc.dmg, npc, nil)
	cooldown(npc, "beam", now, 7)
	return true
end

function impl.whirlwind(npc: any, _target: any, dist: number, now: number): boolean
	if dist > 26 then
		return false
	end
	mark(npc, "whirlwind")
	local pos = npc.root.Position
	Fx.near(pos, 300, "whirl", { p = pos, r = 18, d = 3 })
	for _, a in Actors.near(pos, 22) do
		if Factions.hostileTo(npc, a) or a.faction == "player" then
			local away = a.root.Position - pos
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			Combat.push(a, away * 40 + Vector3.new(0, 50, 0))
			Combat.damage(a, npc.dmg * 0.5, npc, nil)
		end
	end
	cooldown(npc, "whirlwind", now, 9)
	return true
end

-- suporte: cura aliados e jogadores próximos (não precisa de alvo inimigo)
function Abilities.support(npc: any, now: number)
	local attacks = npc.attacks
	if table.find(attacks, "heal") and ready(npc, "heal", now) then
		local healed = 0
		for _, a in Actors.near(npc.root.Position, 28) do
			local friendly = (a.faction == "player" and npc.faction ~= "hostile") or (a.kind == "npc" and not Factions.hostileTo(npc, a) and a ~= npc)
			if friendly and a.humanoid.Health < a.humanoid.MaxHealth then
				Combat.heal(a, 14)
				healed += 1
			end
		end
		if healed > 0 then
			mark(npc, "heal")
			Fx.shockwave(npc.root.Position, 14, Color3.fromRGB(120, 255, 160))
		end
		cooldown(npc, "heal", now, 3.5)
	end
	if table.find(attacks, "gift") and ready(npc, "gift", now) and npc.spawnGift then
		npc.gifts = (npc.gifts or 0)
		if npc.gifts < 4 then
			local nearest, best = nil, 45
			for _, a in Actors.players() do
				local d = (a.root.Position - npc.root.Position).Magnitude
				if d < best then
					nearest, best = a, d
				end
			end
			if nearest then
				npc.gifts += 1
				mark(npc, "gift")
				npc.spawnGift(npc, nearest.root.Position)
			end
		end
		cooldown(npc, "gift", now, 11)
	end
end

-- tenta usar uma habilidade ofensiva; retorna true se deve parar de andar
function Abilities.tryUse(npc: any, target: any, dist: number, now: number): boolean
	for _, name in npc.attacks do
		local f = impl[name]
		if f and ready(npc, name, now) then
			if f(npc, target, dist, now) then
				return true
			end
		end
	end
	return false
end

-- alcance preferido (atiradores mantêm distância)
function Abilities.preferredRange(npc: any): number
	local attacks = npc.attacks
	if table.find(attacks, "melee") or table.find(attacks, "stomp") or table.find(attacks, "charge") then
		return 0
	end
	if table.find(attacks, "breath") then
		return 10 + 8 * npc.scale
	end
	if table.find(attacks, "bolt") or table.find(attacks, "beam") then
		return 28
	end
	return 0
end

return Abilities
