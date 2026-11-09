--!strict
-- Executor de objetos, comidas e natureza.

local Builders = require(script.Parent.Parent.Builders)
local Fx = require(script.Parent.Parent.Core.Fx)
local PropActions = require(script.Parent.Parent.Core.PropActions)

local H = { name = "prop" }

function H.estimate(spec: any): { [string]: number }
	local p = spec.params
	local n = spec.count * (p.cluster or 1)
	return { events = 1, parts = 20 * n, dynamic = if p.physics then n else 0, effects = if p.elementMod then n * 2 else 1 }
end

function H.spawn(ctx: any): any
	local params = ctx.params
	local models = {}
	local n = ctx.count * (params.cluster or 1)
	local first: BasePart? = nil
	local scale = params.scale or 1
	for i = 1, n do
		local origin = ctx.origin
		if n > 1 then
			local ring = 6 * scale + i * 1.5
			local ang = i * 2.39
			origin = ctx.origin * CFrame.new(math.cos(ang) * ring, 0, math.sin(ang) * ring)
		end
		if params.physics then
			origin += Vector3.new(0, 4 * scale, 0)
		end
		if params.float then
			origin += Vector3.new(0, 6, 0)
		end
		local p2 = table.clone(params)
		p2.rng = ctx.rng:fork(i)
		local r = Builders.prop(origin * CFrame.Angles(0, ctx.rng:range(-0.4, 0.4), 0), p2)
		r.model.Name = ctx.def.label
		r.model.Parent = ctx.folder
		if params.physics then
			pcall(function()
				r.main:SetNetworkOwner(nil)
			end)
		end
		if params.float then
			r.model:AddTag("IdeiasFlutuar")
		end
		PropActions.elementize(r.main, params)
		PropActions.attach(r.model, r.main, params.interact, params, ctx)
		table.insert(models, r.model)
		first = first or r.main
	end
	Fx.near(ctx.origin.Position, 300, "spawn", { p = ctx.origin.Position, s = scale, c = Color3.fromRGB(255, 220, 120) })
	return {
		models = models,
		model = models[1],
		anchor = first,
		position = ctx.origin.Position,
		radius = 4 * scale,
		elements = { params.element },
		tags = ctx.def.tagSet,
	}
end

return H
