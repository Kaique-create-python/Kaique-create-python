--!strict
-- Áreas destrutíveis e regeneráveis do mapa. Peças com a tag "Destrutivel"
-- podem ser arremessadas por explosões, meteoros, tornados e ondas. Cada peça
-- guarda seu estado original e volta sozinha depois de alguns segundos
-- (ou na hora, com "restaurar").

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.IdeiasShared.Config)
local Budget = require(script.Parent.Budget)

local Destruction = {}

type Saved = { cf: CFrame, anchored: boolean, collide: boolean, restoreAt: number }
local saved: { [BasePart]: Saved } = {}
local loose = 0
local MAX_LOOSE = 160

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function refreshFilter()
	overlap.FilterDescendantsInstances = CollectionService:GetTagged("DestrutivelGrupo")
end

function Destruction.count(): number
	return loose
end

-- arremessa peças destrutíveis no raio
function Destruction.blast(pos: Vector3, radius: number, power: number, pull: boolean?)
	refreshFilter()
	overlap.MaxParts = 50
	local parts = Workspace:GetPartBoundsInRadius(pos, radius, overlap)
	local now = os.clock()
	for _, part in parts do
		if part:HasTag("Destrutivel") and loose < MAX_LOOSE then
			local s = saved[part]
			if not s then
				s = { cf = part.CFrame, anchored = part.Anchored, collide = part.CanCollide, restoreAt = 0 }
				saved[part] = s
				loose += 1
				Budget.adjust("dynamic", 1)
			end
			s.restoreAt = now + Config.World.RestoreDelay + math.random() * 6
			if part.Anchored then
				part.Anchored = false
				pcall(function()
					part:SetNetworkOwner(nil)
				end)
			end
			local dir = part.Position - pos
			dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.yAxis
			if pull then
				dir = -dir
			end
			local f = 1 - math.clamp((part.Position - pos).Magnitude / radius, 0, 1) * 0.5
			part.AssemblyLinearVelocity = (dir + Vector3.new(0, if pull then 0.2 else 0.8, 0)).Unit * power * f
			part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6
		end
	end
end

local function restore(part: BasePart, s: Saved, smooth: boolean)
	saved[part] = nil
	loose -= 1
	Budget.adjust("dynamic", -1)
	if not part.Parent then
		return
	end
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.CanCollide = s.collide
	if smooth and (part.Position - s.cf.Position).Magnitude < 400 then
		TweenService:Create(part, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = s.cf }):Play()
	else
		part.CFrame = s.cf
	end
	part.Anchored = s.anchored
end

function Destruction.restoreAll()
	for part, s in saved do
		restore(part, s, true)
	end
end

function Destruction.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for part, s in saved do
				if now >= s.restoreAt or part.Position.Y < -200 then
					restore(part, s, true)
				end
			end
		end
	end)
end

return Destruction
