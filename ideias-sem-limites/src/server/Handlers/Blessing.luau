--!strict
-- Luz Celestial ("deus", "luz divina"...): acontecimento sagrado e respeitoso.
-- Coluna de luz suave, pombas, cura total de quem está perto e paz: monstros
-- próximos param de atacar por alguns segundos. Sem corpo, sem combate.

local Actors = require(script.Parent.Parent.Core.Actors)
local Combat = require(script.Parent.Parent.Core.Combat)
local Fx = require(script.Parent.Parent.Core.Fx)

local H = { name = "blessing" }

function H.estimate(_spec: any): { [string]: number }
	return { events = 1, effects = 3 }
end

function H.spawn(ctx: any): any
	local params = ctx.params
	local pos = ctx.origin.Position
	local radius = params.radius or 70
	local calm = params.calm or 20
	Fx.near(pos, 600, "holy", { p = pos, r = radius, d = math.min(ctx.lifetime or 14, 14) })
	local healed, calmed = 0, 0
	for _, a in Actors.near(pos, radius * 1.5) do
		if a.faction == "player" or a.faction == "ally" or a.faction == "pet" then
			if a.humanoid and a.humanoid.Health < a.humanoid.MaxHealth then
				Combat.heal(a, a.humanoid.MaxHealth)
				healed += 1
			end
		elseif a.kind == "npc" and a.faction == "hostile" then
			a.calmUntil = os.clock() + calm
			calmed += 1
			Fx.near(a.root.Position, 300, "calm", { p = a.root.Position })
		end
	end
	if ctx.owner then
		local msg = "✨ Paz e luz para todos!"
		if calmed > 0 then
			msg ..= string.format(" %d monstro(s) se acalmaram.", calmed)
		end
		Fx.to(ctx.owner, "toast", { t = msg, c = Color3.fromRGB(255, 240, 190) })
	end
	local endsAt = os.clock() + math.min(ctx.lifetime or 14, 14)
	return {
		position = pos,
		radius = radius,
		healed = healed,
		calmed = calmed,
		done = function()
			return os.clock() >= endsAt
		end,
	}
end

return H
