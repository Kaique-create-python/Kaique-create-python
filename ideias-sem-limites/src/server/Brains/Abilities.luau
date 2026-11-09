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
	local boltColor = if npc.boltColor == "banana" then Color3.fromRGB(250, 220, 60) else elementColor(npc.element)
	Fx.bolt(from, aim, boltColor, speed, 0.5 + 0.2 * npc.scale)
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

-- PODERES DOS PERSONAGENS POR NOME --------------------------------------------------
local Status = require(script.Parent.Parent.Core.Status)

local function lineHit(npc: any, from: Vector3, to: Vector3, width: number, dmg: number, push: number)
	local ab = to - from
	local len2 = ab:Dot(ab)
	if len2 < 0.01 then
		return
	end
	for _, a in Actors.near((from + to) / 2, math.sqrt(len2) / 2 + width + 4) do
		if Factions.hostileTo(npc, a) then
			local t = math.clamp((a.root.Position - from):Dot(ab) / len2, 0, 1)
			if (a.root.Position - (from + ab * t)).Magnitude < width + (a.radius or 2) then
				Combat.damage(a, dmg, npc, npc.element)
				if push > 0 then
					Combat.push(a, ab.Unit * push + Vector3.new(0, push * 0.5, 0))
				end
			end
		end
	end
end

-- Guerreiro de Energia: carrega (aura) e solta um raio enorme
function impl.energy_beam(npc: any, target: any, dist: number, now: number): boolean
	if dist > 85 or dist < 6 then
		return false
	end
	mark(npc, "beam")
	face(npc, target.root.Position)
	local color = elementColor(npc.element)
	Fx.near(npc.root.Position, 450, "charge", { p = npc.root.Position, c = color, d = 0.9, s = npc.scale })
	npc.busyUntil = now + 1.7
	cooldown(npc, "energy_beam", now, 7)
	task.delay(0.9, function()
		if not Actors.alive(npc) or not Actors.alive(target) then
			return
		end
		local from = npc.root.Position + npc.root.CFrame.LookVector * (2 + npc.scale) + Vector3.new(0, 0.8, 0)
		local to = target.root.Position
		Fx.near(from, 500, "kame", { a = from, b = to, c = color, w = 2.2 * math.max(1, npc.scale) })
		Fx.shake(to, 0.7, 200)
		lineHit(npc, from, to, 3, npc.dmg * 2.2, 70)
	end)
	return true
end

-- Herói Careca: um soco que manda qualquer um para longe
function impl.super_punch(npc: any, target: any, dist: number, now: number): boolean
	local reach = (npc.reach or 5) + 1.5
	if dist > reach + (target.radius or 2) then
		return false
	end
	mark(npc, "punch")
	face(npc, target.root.Position)
	local dir = target.root.Position - npc.root.Position
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else npc.root.CFrame.LookVector
	Combat.damage(target, npc.dmg * 12, npc, nil)
	Combat.push(target, dir * 230 + Vector3.new(0, 120, 0))
	Fx.near(target.root.Position, 500, "punch", { p = target.root.Position, d = dir, s = 1.6 })
	Fx.shake(target.root.Position, 1.4, 260)
	cooldown(npc, "super_punch", now, 2.5)
	npc.busyUntil = now + 0.5
	return true
end

-- Ninja das Sombras: dois clones que lutam por 12 segundos
function impl.clones(npc: any, _target: any, dist: number, now: number): boolean
	if dist > 70 or npc.isClone or not npc.ctx then
		return false
	end
	cooldown(npc, "clones", now, 18)
	mark(npc, "clones")
	local Chains = require(script.Parent.Parent.Core.Chains)
	local p = table.clone(npc.params)
	p.isClone = true
	p.hp = math.floor((p.hp or 200) * 0.3)
	local atk = {}
	for _, a in npc.attacks do
		if a ~= "clones" then
			table.insert(atk, a)
		end
	end
	p.attacks = atk
	local node = { concept = npc.def, handler = "npc", params = p, count = 1, label = npc.def.label, mods = {} }
	for i = 1, 2 do
		local cf = npc.root.CFrame * CFrame.new(if i == 1 then -4 else 4, 0, 1)
		Fx.near(cf.Position, 300, "poof", { p = cf.Position, s = 1 })
		Chains.spawnNode(npc.ctx, node, CFrame.new(cf.Position), { ttl = 12 })
	end
	return false
end

-- Herói Aranha: teia que prende o alvo
function impl.web(npc: any, target: any, dist: number, now: number): boolean
	if dist > 70 or dist < 5 then
		return false
	end
	mark(npc, "bolt")
	face(npc, target.root.Position)
	local from = npc.root.Position + Vector3.new(0, 1, 0)
	Fx.near(from, 400, "web", { a = from, b = target.root.Position })
	cooldown(npc, "web", now, 4)
	task.delay(dist / 140, function()
		if Actors.alive(target) then
			Status.apply(target.humanoid, "root", 2.5)
			Combat.damage(target, npc.dmg * 0.5, npc, nil)
		end
	end)
	return true
end

-- Olhos de laser (herói voador, armadura)
function impl.laser_eyes(npc: any, target: any, dist: number, now: number): boolean
	if dist > 75 or dist < 5 then
		return false
	end
	mark(npc, "beam")
	face(npc, target.root.Position)
	local head = npc.model:FindFirstChild("Cabeca") :: BasePart?
	local from = if head then head.Position else npc.root.Position + Vector3.new(0, 2, 0)
	local to = target.root.Position
	Fx.near(from, 400, "lasereyes", { a = from, b = to, c = if npc.element == "electric" then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(255, 60, 60) })
	lineHit(npc, from, to, 1.5, npc.dmg * 1.3, 0)
	cooldown(npc, "laser_eyes", now, 3.5)
	return true
end

-- Deus do Trovão / Ratinho Elétrico: raio do céu no alvo
function impl.lightning_call(npc: any, target: any, dist: number, now: number): boolean
	if dist > 90 then
		return false
	end
	mark(npc, "bolt")
	local pos = target.root.Position
	Fx.near(pos, 500, "lightning", { p = pos })
	Combat.areaEnemies(pos, 8 + 2 * npc.scale, npc.dmg * 1.3, npc, "electric", 30)
	cooldown(npc, "lightning_call", now, 4.5)
	return true
end

-- Crocodilo Bombardeiro: solta bombas por cima do alvo
function impl.bomb_drop(npc: any, target: any, dist: number, now: number): boolean
	local flat = Vector3.new(target.root.Position.X - npc.root.Position.X, 0, target.root.Position.Z - npc.root.Position.Z)
	if flat.Magnitude > 30 or dist > 70 then
		return false
	end
	mark(npc, "bomb")
	local from = npc.root.Position - Vector3.new(0, 1.5, 0)
	local to = target.root.Position
	Fx.bolt(from, to, Color3.fromRGB(40, 40, 45), 70, 1.4)
	cooldown(npc, "bomb_drop", now, 3)
	task.delay((to - from).Magnitude / 70, function()
		Fx.near(to, 500, "boom", { p = to, s = 1.3 })
		Fx.shake(to, 0.8, 200)
		if Actors.alive(npc) then
			Combat.areaEnemies(to, 11, npc.dmg * 1.4, npc, "fire", 60)
		end
	end)
	return false
end

-- Medusa: olhar que transforma em pedra por alguns segundos
function impl.petrify(npc: any, target: any, dist: number, now: number): boolean
	if dist > 40 then
		return false
	end
	mark(npc, "beam")
	face(npc, target.root.Position)
	Fx.near(target.root.Position, 300, "petrify", { p = target.root.Position })
	Status.apply(target.humanoid, "freeze", 3)
	Combat.damage(target, npc.dmg * 0.6, npc, nil)
	cooldown(npc, "petrify", now, 8)
	return true
end

-- Arbusto-Bomba: chega perto, chia e explode
function impl.self_destruct(npc: any, target: any, dist: number, now: number): boolean
	if dist > 8 + (target.radius or 2) or npc.fusing then
		return false
	end
	npc.fusing = true
	cooldown(npc, "self_destruct", now, 99)
	npc.model:SetAttribute("Pavio", workspace:GetServerTimeNow())
	Fx.near(npc.root.Position, 300, "fuse", { p = npc.root.Position, d = 1.3 })
	npc.busyUntil = now + 1.4
	task.delay(1.3, function()
		if not Actors.alive(npc) then
			return
		end
		local pos = npc.root.Position
		Fx.near(pos, 500, "boom", { p = pos, s = 1.4 })
		Fx.shake(pos, 1, 200)
		Combat.areaEnemies(pos, 12, npc.dmg, npc, "fire", 80)
		npc.silentDeath = true
		npc.humanoid.Health = 0
	end)
	return true
end

-- Tronco Tum-Tum: "tum tum tum" que derruba quem está perto
function impl.drum(npc: any, target: any, dist: number, now: number): boolean
	local radius = 14 + 4 * npc.scale
	if dist > radius then
		return false
	end
	mark(npc, "stomp")
	local pos = npc.root.Position - Vector3.new(0, npc.hipHeight or 2, 0)
	Fx.near(pos, 400, "drum", { p = pos, r = radius })
	for k = 0, 2 do
		task.delay(k * 0.35, function()
			if Actors.alive(npc) then
				Fx.shockwave(pos, radius * (0.6 + k * 0.2), Color3.fromRGB(200, 150, 90))
				Combat.areaEnemies(pos, radius, npc.dmg * 0.45, npc, nil, 35)
			end
		end)
	end
	cooldown(npc, "drum", now, 6)
	npc.busyUntil = now + 1.1
	return true
end

-- Cantar: notas musicais que fazem os inimigos perto dançarem um pouco
function impl.sing(npc: any, _target: any, dist: number, now: number): boolean
	if dist > 30 then
		return false
	end
	mark(npc, "sing")
	local pos = npc.root.Position
	Fx.near(pos, 300, "notes", { p = pos + Vector3.new(0, npc.height or 4, 0), d = 3 })
	for _, a in Actors.near(pos, 22) do
		if a.kind == "npc" and Factions.hostileTo(npc, a) then
			a.calmUntil = os.clock() + 3.5
			a.model:SetAttribute("Dancando", true)
			task.delay(3.5, function()
				if a.model and a.model.Parent and a.behavior ~= "dance" then
					a.model:SetAttribute("Dancando", false)
				end
			end)
		end
	end
	cooldown(npc, "sing", now, 9)
	return false
end

-- "dragão que atira tubarões": lança o elo da cadeia no alvo
function impl.launch(npc: any, target: any, dist: number, now: number): boolean
	if not npc.launchNode or not npc.ctx or dist > 75 or dist < 6 then
		return false
	end
	mark(npc, "bolt")
	face(npc, target.root.Position)
	local from = if npc.mouth then npc.mouth.WorldPosition else npc.root.Position + Vector3.new(0, 2, 0)
	local to = target.root.Position
	local t = math.clamp(dist / 55, 0.35, 1.4)
	Fx.near(from, 400, "launch", { a = from, b = to, t = t, c = elementColor(npc.element) })
	cooldown(npc, "launch", now, 5)
	task.delay(t, function()
		if Actors.alive(npc) then
			local Chains = require(script.Parent.Parent.Core.Chains)
			Chains.spawnNode(npc.ctx, npc.launchNode, CFrame.new(to + Vector3.new(0, 1, 0)))
		end
	end)
	return true
end

-- suporte: cura aliados e jogadores próximos (não precisa de alvo inimigo)
function Abilities.support(npc: any, now: number)
	local attacks = npc.attacks
	if npc.calmAura and ready(npc, "calm", now) then
		for _, a in Actors.near(npc.root.Position, npc.calmAura) do
			if a.kind == "npc" and a.faction == "hostile" then
				a.calmUntil = os.clock() + 3
			end
		end
		npc.cd.calm = now + 1
	end
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
	if table.find(attacks, "bolt") or table.find(attacks, "beam") or table.find(attacks, "energy_beam") or table.find(attacks, "laser_eyes") or table.find(attacks, "web") or table.find(attacks, "lightning_call") or table.find(attacks, "launch") then
		return 28
	end
	return 0
end

return Abilities
