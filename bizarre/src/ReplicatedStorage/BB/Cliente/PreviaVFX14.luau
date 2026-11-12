-- Local inspection of the approved SP/TW catalog. No combat, remote, audio or camera dependency.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Piloto = require(script.Parent:WaitForChild("VFXPiloto"))
local Receitas = require(script.Parent.Parent:WaitForChild("VFXReceitas"))
local Previa = {}
local token = 0
local atual: any = nil

local function vivo(handle: any): boolean
	local owner = handle.owner
	local hum = owner and owner:FindFirstChildOfClass("Humanoid")
	return handle.active and atual == handle and owner.Parent ~= nil
		and Players.LocalPlayer.Character == owner and hum ~= nil and hum.Health > 0
		and owner:FindFirstChild("HumanoidRootPart") ~= nil
end

function Previa.cancelar()
	local handle = atual
	if not handle then return end
	atual = nil
	handle.active = false
	if handle.connection then handle.connection:Disconnect() end
	for _, scope in handle.scopes do Piloto.cancelar(handle.owner, scope) end
end

function Previa.tocar(owner: Model?): any
	Previa.cancelar()
	local catalogo = RS:FindFirstChild("BB_VFXCatalogo14")
	if not catalogo then return false end
	for name in Receitas.templates() do
		if not catalogo:FindFirstChild(name) then return false end
	end
	if not owner or not owner.Parent or Players.LocalPlayer.Character ~= owner then return false end
	local hum = owner:FindFirstChildOfClass("Humanoid")
	local root = owner:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then return false end
	token += 1
	local prefix = "preview14:" .. tostring(token)
	local handle = { owner = owner, active = true, scopes = { prefix .. ":SP", prefix .. ":TW" }, token = token }
	atual = handle
	local bases = {
		root.CFrame:PointToWorldSpace(Vector3.new(-6, 0, -12)),
		root.CFrame:PointToWorldSpace(Vector3.new(6, 0, -12)),
	}
	local dir = root.CFrame.LookVector
	local function tocar(index: number, move: string, phase: string, dur: number?, variant: string?)
		if not vivo(handle) then
			if atual == handle then Previa.cancelar() end
			return
		end
		local stand = if index == 1 then "STAR_PLATINUM" else "THE_WORLD"
		local ok = pcall(Piloto.tocar, stand, move, phase, {
			owner = owner, pos = bases[index], dir = dir, actionId = handle.scopes[index],
			t = workspace:GetServerTimeNow(), dur = dur, variant = variant, n = 1,
		})
		if not ok and atual == handle then Previa.cancelar() end
	end
	local function depois(delay: number, callback: () -> ())
		task.delay(delay, function()
			if atual ~= handle then return end
			if not vivo(handle) then Previa.cancelar(); return end
			callback()
		end)
	end
	handle.cancelar = function()
		if atual == handle then Previa.cancelar() end
	end
	handle.connection = RunService.Heartbeat:Connect(function()
		if atual == handle and not vivo(handle) then Previa.cancelar() end
	end)
	for index = 1, 2 do tocar(index, "invocar", "inicio") end
	if not handle.active then return false end
	depois(0.65, function()
		for index = 1, 2 do tocar(index, "m1", "inicio") end
	end)
	depois(0.8, function()
		for index = 1, 2 do tocar(index, "m1", "contato") end
	end)
	depois(1.5, function()
		tocar(1, "STAR_PLATINUM_3", "inicio", 0.5, "antecipacao")
		tocar(2, "THE_WORLD_4", "inicio", 0.5, "antecipacao")
	end)
	depois(2, function()
		tocar(1, "STAR_PLATINUM_3", "contato")
		tocar(2, "THE_WORLD_4", "contato")
	end)
	depois(2.6, function()
		tocar(1, "STAR_PLATINUM_2", "inicio")
		tocar(2, "THE_WORLD_2", "inicio", 0.7, "projetil")
	end)
	depois(3.65, function()
		for index = 1, 2 do tocar(index, "tempo", "contato") end
	end)
	depois(4.5, function() tocar(2, "rolo", "inicio", 0.6) end)
	depois(5.1, function() tocar(2, "rolo", "final") end)
	depois(6.2, Previa.cancelar)
	return handle
end

return Previa
