-- Ideias Sem Limites V3 — cliente.
-- Liga interface, efeitos, clima/animação, movimento e a comunicação com o
-- servidor. O cliente nunca decide o que é criado: só envia o texto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("IdeiasRemotes")
local criar = remotes:WaitForChild("Criar")
local estado = remotes:WaitForChild("Estado")
local acao = remotes:WaitForChild("Acao")
local fx = remotes:WaitForChild("Fx")

local root = script.Parent
local Settings = require(root.Settings)
local Hud = require(root.UI.Hud)
local Drawer = require(root.UI.Drawer)
local Effects = require(root.FX.Effects)
local Disasters = require(root.FX.Disasters)
local Ambient = require(root.FX.Ambient)
local Movement = require(root.FX.Movement)

Settings.init()
local gui = Hud.build(playerGui)
Drawer.build(gui)
Movement.init(gui)
Effects.init(Hud, Movement)
task.spawn(Disasters.init)
task.spawn(Ambient.init)

local busy = false
Hud.onSubmit = function(text)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, res = pcall(function()
			return criar:InvokeServer(text)
		end)
		busy = false
		if ok then
			Hud.result(res)
			-- câmera cinemática: olha para a ideia criada por alguns segundos
			if type(res) == "table" and res.ok and Settings.values.camera == "cinematica" then
				local cam = Workspace.CurrentCamera
				local char = player.Character
				local head = char and char:FindFirstChild("Head")
				if cam and head then
					local look = (head :: BasePart).CFrame.LookVector
					local target = (head :: BasePart).Position + look * 25
					cam.CameraType = Enum.CameraType.Scriptable
					local from = (head :: BasePart).Position - look * 18 + Vector3.new(0, 12, 0)
					cam.CFrame = CFrame.lookAt(from, target)
					task.delay(3.5, function()
						cam.CameraType = Enum.CameraType.Custom
					end)
				end
			end
		else
			Hud.result({ ok = false, message = "Conexão instável, tente de novo" })
		end
	end)
end

Drawer.sendAction = function(action, arg)
	acao:FireServer(action, arg)
end

estado.OnClientEvent:Connect(function(kind, data)
	if kind == "capacidade" then
		Hud.capacity(data)
	elseif kind == "feed" then
		Hud.toast(string.format("%s %s criou: %s", data.icon or "💡", data.name, data.label))
	elseif kind == "perfil" then
		Drawer.profile = data
		Drawer.refresh()
	elseif kind == "conquista" then
		Hud.banner("🏆 " .. data.title, data.desc .. "  +" .. data.reward .. " ✨")
		Effects.cue("achievement", nil, 1)
	elseif kind == "segredo" then
		Hud.banner("🔮 Combinação secreta: " .. data.title, data.hint .. "  +" .. data.reward .. " ✨")
		Effects.cue("achievement", nil, 1)
	elseif kind == "missao" then
		Hud.toast("🎯 Missão cumprida: " .. data.title .. "  +" .. data.reward .. " ✨", Color3.fromRGB(255, 220, 110))
	elseif kind == "regiao" then
		Hud.toast("🗺️ Nova região: " .. data.label, Color3.fromRGB(150, 230, 255))
	end
end)

fx.OnClientEvent:Connect(Effects.handle)

Hud.toast("Bem-vindo ao Ideias Sem Limites! Digite qualquer coisa e toque em CRIAR ✨", Color3.fromRGB(150, 230, 255))
