--!strict
-- Montagem de "rigs" de criaturas: partes soltas (não ancoradas) ligadas por
-- Motor6D a uma raiz. Cada junta animada recebe atributos que o cliente lê
-- para animar localmente (Motor6D.Transform), sem tráfego de rede:
--   Anim  = leg | arm | wing | tail | head | jaw | fin | tentacle | spin | bob | cape | segment
--   AnimAxis = X | Y | Z, AnimAmp (rad), AnimPhase (rad), AnimSpeed (multiplicador)
-- Coordenadas locais: origem no chão, +Y para cima, frente = -Z.

local Kit = require(script.Parent.Kit)

local Rig = {}
Rig.__index = Rig

export type AnimSpec = { kind: string, axis: string?, amp: number?, phase: number?, speed: number? }

export type RigResult = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	hipHeight: number,
	height: number,
	mouth: Attachment?,
	head: BasePart?,
	flying: boolean,
	radius: number,
	builder: any,
}

function Rig.new(name: string, origin: CFrame, params: { [string]: any }): any
	local p = table.clone(params)
	p.anchored = false
	p.collide = false
	local b = Kit.new(name, origin, p)
	local self = setmetatable({ b = b, root = nil, head = nil, mouth = nil, joints = 0 }, Rig)
	return self
end

-- raiz invisível (HumanoidRootPart). centerY = altura do centro em escala 1
function Rig.makeRoot(self: any, size: Vector3, centerY: number, collide: boolean?): BasePart
	local root = self.b:box(size, CFrame.new(0, centerY, 0), Color3.new(1, 1, 1), {
		role = "fixed",
		transparency = 1,
		collide = if collide == nil then true else collide,
		name = "HumanoidRootPart",
		shadow = false,
	})
	self.root = root
	self.rootSize = size
	self.centerY = centerY
	return root
end

-- liga `part` a `parent`. Com anim: Motor6D na posição local `joint`; sem: solda rígida.
function Rig.join(self: any, part: BasePart, parent: BasePart, joint: Vector3?, anim: AnimSpec?): Instance
	self.joints += 1
	if anim and joint then
		local jointCf = self.b:at(CFrame.new(joint))
		local m = Instance.new("Motor6D")
		m.Name = anim.kind .. tostring(self.joints)
		m.Part0 = parent
		m.Part1 = part
		m.C0 = parent.CFrame:Inverse() * jointCf
		m.C1 = part.CFrame:Inverse() * jointCf
		m:SetAttribute("Anim", anim.kind)
		m:SetAttribute("AnimAxis", anim.axis or "X")
		m:SetAttribute("AnimAmp", anim.amp or 0.5)
		m:SetAttribute("AnimPhase", anim.phase or 0)
		m:SetAttribute("AnimSpeed", anim.speed or 1)
		m.Parent = parent
		return m
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = part
	w.Parent = part
	return w
end

-- solda várias partes a uma mesma base
function Rig.weld(self: any, parts: { BasePart }, base: BasePart)
	for _, p in parts do
		if p ~= base then
			self:join(p, base)
		end
	end
end

-- grava as partes criadas a partir de um índice (para agrupar membros)
function Rig.mark(self: any): number
	return #self.b.parts
end

function Rig.since(self: any, mark: number): { BasePart }
	local out = {}
	for i = mark + 1, #self.b.parts do
		table.insert(out, self.b.parts[i])
	end
	return out
end

-- cria um grupo de partes já posicionadas: a primeira vira a base do grupo e as
-- demais são soldadas nela; a base é ligada ao pai pela junta animada.
function Rig.group(self: any, mark: number, parent: BasePart, joint: Vector3?, anim: AnimSpec?): BasePart?
	local parts = self:since(mark)
	local base = parts[1]
	if not base then
		return nil
	end
	for i = 2, #parts do
		self:join(parts[i], base)
	end
	self:join(base, parent, joint, anim)
	return base
end

function Rig.setMouth(self: any, part: BasePart, localOffset: Vector3)
	self.mouth = self.b:attachment(part, "Boca", localOffset)
end

function Rig.finish(self: any, opts: { hp: number, speed: number, hipHeight: number, height: number, flying: boolean?, radius: number? }): RigResult
	local b = self.b
	local model: Model = b:finish(self.root)
	local s = b.s
	local h = Instance.new("Humanoid")
	h.RigType = Enum.HumanoidRigType.R15
	h.MaxHealth = opts.hp
	h.Health = opts.hp
	h.WalkSpeed = opts.speed
	h.HipHeight = opts.hipHeight * s
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.BreakJointsOnDeath = false
	h.RequiresNeck = false
	h.UseJumpPower = true
	h.JumpPower = 45
	h.Parent = model
	-- massa: só a raiz pesa (física estável para o Humanoid)
	for _, p in b.parts do
		if p ~= self.root then
			p.Massless = true
			p.CanQuery = true
		end
	end
	model:SetAttribute("Altura", opts.height * s)
	return {
		model = model,
		root = self.root,
		humanoid = h,
		hipHeight = opts.hipHeight * s,
		height = opts.height * s,
		mouth = self.mouth,
		head = self.head,
		flying = opts.flying == true,
		radius = (opts.radius or 2) * s,
		builder = b,
	}
end

return Rig
