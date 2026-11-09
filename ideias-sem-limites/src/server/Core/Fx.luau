--!strict
-- Efeitos visuais enviados aos clientes próximos (UnreliableRemoteEvent "Fx").
-- O servidor decide o que acontece; os clientes desenham (rastros, ondas de
-- choque, tremor de câmera, empurrões no próprio personagem).
-- Mantém o tráfego baixo: só jogadores dentro do raio recebem.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fx = {}

local remote: any = nil
local function getRemote(): any
	if remote then
		return remote
	end
	local folder = ReplicatedStorage:FindFirstChild("IdeiasRemotes")
	remote = folder and folder:FindFirstChild("Fx")
	return remote
end

Fx.sent = 0

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- envia para jogadores a até `radius` studs de `pos` (radius nil = todos)
function Fx.near(pos: Vector3?, radius: number?, kind: string, data: { [string]: any })
	local r = getRemote()
	if not r then
		return
	end
	data.k = kind
	for _, player in Players:GetPlayers() do
		local ok = true
		if pos and radius then
			local root = rootOf(player)
			ok = root ~= nil and (root.Position - pos).Magnitude <= radius
		end
		if ok then
			-- pcall: o jogador pode ter saído entre a checagem e o envio
			if pcall(r.FireClient, r, player, data) then
				Fx.sent += 1
			end
		end
	end
end

function Fx.to(player: Player, kind: string, data: { [string]: any })
	local r = getRemote()
	if r then
		data.k = kind
		if pcall(r.FireClient, r, player, data) then
			Fx.sent += 1
		end
	end
end

-- atalhos ---------------------------------------------------------------------
function Fx.shockwave(pos: Vector3, radius: number, color: Color3)
	Fx.near(pos, 400, "ring", { p = pos, r = radius, c = color })
end

function Fx.shake(pos: Vector3, intensity: number, radius: number)
	Fx.near(pos, radius, "shake", { p = pos, i = intensity })
end

function Fx.flash(pos: Vector3, color: Color3, size: number)
	Fx.near(pos, 500, "flash", { p = pos, c = color, s = size })
end

function Fx.bolt(from: Vector3, to: Vector3, color: Color3, speed: number, width: number?)
	Fx.near(from, 350, "bolt", { a = from, b = to, c = color, v = speed, w = width or 0.6 })
end

function Fx.zap(from: Vector3, to: Vector3, color: Color3)
	Fx.near(from, 400, "zap", { a = from, b = to, c = color })
end

-- empurra personagens de jogadores (o cliente aplica no próprio corpo)
function Fx.impulse(player: Player, velocity: Vector3, mode: string?)
	Fx.to(player, "push", { v = velocity, m = mode or "add" })
end

function Fx.blind(player: Player, color: Color3, duration: number)
	Fx.to(player, "tint", { c = color, d = duration })
end

return Fx
