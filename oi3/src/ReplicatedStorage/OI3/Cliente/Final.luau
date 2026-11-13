-- OI3 :: o FINAL do Capítulo 1 (AJUSTE-8) — "O avô"
-- Uma manhã de sol. O avô, vivo e bem vestido, conversa com uma mulher que acompanha duas crianças.
-- As três crianças (pálidas) observam escondidas. Uma das crianças entra no carro e vê, no banco de
-- trás, os brinquedos do Keko, da Nina e do terceiro menino. O rádio: "Oi..." / "Três..." e uma
-- risadinha. O sorriso do avô some por um segundo. Ele aumenta o volume. Tela preta. Três batidas.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local OI3 = script.Parent.Parent
local MissoesMapa = require(OI3.MissoesMapa)
local Ator = require(script.Parent.Ator)
local Cinema = require(script.Parent.Cinema)
local Som = require(script.Parent.Som)
local Iluminacao = require(script.Parent.Iluminacao)

local Final = {}

local V3 = Vector3.new
local RGB = Color3.fromRGB
local PALIDO = RGB(204, 212, 220)
local MEMBROS = { Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }

local ativo = false

function Final.ativo(): boolean
	return ativo
end

-- as três crianças: pálidas e um pouco transparentes (só sugerido; nada de sangue)
function Final.palido(modelo: Model)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			if MEMBROS[p.Name] then
				p.Color = PALIDO
			end
			p.Transparency = math.max(p.Transparency, 0.12)
		end
	end
end

function Final.tocar(params: { inicio: number?, aoTerminar: () -> () })
	ativo = true
	local cam = workspace.CurrentCamera
	local inicio = params.inicio or workspace:GetServerTimeNow()
	local espera = inicio - workspace:GetServerTimeNow()
	if espera > 0 and espera < 6 then
		task.wait(espera)
	end
	Cinema.escurecer(1, 0.8)
	task.wait(0.9)
	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_Final"
	pasta.Parent = workspace
	local okC, _, l = pcall(MissoesMapa.construir, "rua", pasta)
	if not okC then
		l = MissoesMapa.layout("rua")
	end
	local O = l.origem
	local carro = pasta:FindFirstChild("OI3_X_Carro", true) :: Model?
	Iluminacao.manha(0)
	cam.CameraType = Enum.CameraType.Scriptable
	-- o próprio personagem some da cena
	local char = Players.LocalPlayer.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		raiz.Anchored = true
	end
	if char then
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 1
			end
		end
	end

	local atores = {}
	local function ator(cod: string, pos: Vector3, olhar: Vector3?)
		local ok, a = pcall(Ator.novo, cod, pasta, pos, olhar)
		if ok and a then
			table.insert(atores, a)
			return a
		end
		return nil
	end
	local vo = ator("VO", l.vo, l.mulher)
	local mu = ator("MU", l.mulher, l.vo)
	local f1 = ator("C1", l.filho1, l.vo)
	local f2 = ator("C2", l.filho2, l.vo)
	local fantasmas = {}
	for i, cod in { "KE", "NI", "ME" } do
		local a = ator(cod, l.escondidos[i], l.vo)
		if a then
			Final.palido(a.modelo)
			table.insert(fantasmas, a)
		end
	end
	local conexao = RunService.RenderStepped:Connect(function()
		for _, a in atores do
			a:passo()
		end
	end)
	local function corte(cf: CFrame, fov: number?)
		cam.CFrame = cf
		cam.FieldOfView = fov or 50
	end
	local function mover(a: CFrame, b: CFrame, dur: number, fov: number?)
		local t0 = os.clock()
		cam.FieldOfView = fov or 50
		while os.clock() - t0 < dur do
			local k = (os.clock() - t0) / dur
			k = k * k * (3 - 2 * k)
			cam.CFrame = a:Lerp(b, k)
			RunService.RenderStepped:Wait()
		end
		cam.CFrame = b
	end
	local function legenda(id: string, dur: number)
		if Som.disponivel(id) then
			Som.tocar(id, { grupo = "Vozes" })
			Cinema.legenda(id, dur)
		else
			Cinema.legenda(id, dur, true)
		end
	end

	local ok, err = pcall(function()
		Cinema.faixas(true, 0.6)
		-- 1) a rua numa manhã de sol
		Som.ambiente("vento", 0.12, 1)
		local largoA = CFrame.lookAt(O + V3(-30, 10, -22), O + V3(0, 3, 0))
		local largoB = CFrame.lookAt(O + V3(-24, 8, -18), O + V3(2, 3, 0))
		corte(largoA, 55)
		Cinema.escurecer(0, 1.8)
		mover(largoA, largoB, 4.5, 55)
		-- 2) as três crianças escondidas atrás da cerca viva, observando
		local e = l.escondidos[2]
		corte(CFrame.lookAt(e + V3(1.5, 5.2, -6), e + V3(0, 4.2, 0)), 42)
		for _, a in fantasmas do
			a:virar(l.vo, 0.6)
		end
		task.wait(3.6)
		-- 3) o avô oferece ajuda à mulher
		corte(CFrame.lookAt(l.vo + V3(-6, 4.6, 9), l.vo + V3(-1.2, 4.2, 0)), 40)
		if vo then
			vo:gesto("acenar", 0.8)
		end
		legenda("VO_9", 4.6)
		task.wait(4.6)
		legenda("MU_1", 3.8)
		task.wait(4)
		-- 4) uma das crianças aceita e vai até o carro
		local porta = l.carro + V3(-1.8, 0, -3.2)
		if f1 then
			f1:andar(porta, 4)
		end
		corte(CFrame.lookAt(l.carro + V3(-8, 4.5, -9), porta + V3(0, 3, 0)), 45)
		task.wait(3.2)
		if f1 then
			f1:visivel(false)
		end
		-- 5) antes de fechar a porta, ela olha para o banco de trás: os brinquedos dos três
		local banco = l.carro + V3(-1.8, 3.2, 0)
		corte(CFrame.lookAt(l.carro + V3(0.2, 4.6, -1.6), banco), 48)
		Som.tocar("coracao", { volume = 0.5 })
		task.wait(3.6)
		-- 6) o avô liga o carro; no rádio, vozes de criança
		if vo then
			vo:posicionar(l.carro + V3(1.2, -0.9, -1.0), l.carro + V3(8, -0.9, -1.0))
		end
		if mu then
			mu:visivel(false)
		end
		if f2 then
			f2:visivel(false)
		end
		local rosto = l.carro + V3(1.2, 4.2, -1.0)
		corte(CFrame.lookAt(l.carro + V3(3.4, 4.3, 0.6), rosto), 38)
		Som.tocar("partida", { volume = 0.9 })
		task.wait(1.6)
		local motor = Som.tocar("motor", { volume = 0.45, loop = true })
		local radio = Som.tocar("radio", { volume = 0.35, loop = true })
		task.wait(1.2)
		legenda("KE_8", 1.6)
		task.wait(2)
		if Som.disponivel("CONTA_3") then
			Som.tocar("CONTA_3", { grupo = "Vozes", volume = 0.8 })
		end
		Cinema.legenda("CONTA_3_RADIO", 1.6, true)
		task.wait(2)
		if Som.disponivel("RISADA_RADIO") then
			Som.tocar("RISADA_RADIO", { grupo = "Vozes" })
		end
		Cinema.legenda("RISADA_RADIO", 1.8, true)
		task.wait(1.6)
		-- 7) o retrovisor: por um segundo, o sorriso desaparece
		corte(CFrame.lookAt(l.carro + V3(2.3, 4.25, -0.2), rosto), 30)
		task.wait(1.2)
		local decal = vo and vo.modelo:FindFirstChild("Head") and vo.modelo.Head:FindFirstChildOfClass("Decal")
		if decal then
			decal.Transparency = 1
		end
		task.wait(1.3)
		if decal then
			decal.Transparency = 0
		end
		task.wait(0.8)
		-- ele não se assusta: só aumenta o volume do rádio
		Som.mudarVolume(radio, 0.9)
		task.wait(1.4)
		-- 8) o carro vai embora
		Som.mudarVolume(motor, 0.7)
		local largo = CFrame.lookAt(l.carro + V3(-18, 7, -16), l.carro + V3(6, 2, 2))
		corte(largo, 50)
		if vo then
			vo:visivel(false)
		end
		if carro and carro.PrimaryPart then
			local de = carro:GetPivot()
			local t0 = os.clock()
			while os.clock() - t0 < 4 do
				local k = (os.clock() - t0) / 4
				carro:PivotTo(de * CFrame.new(k * k * 34, 0, 0))
				RunService.RenderStepped:Wait()
			end
		else
			task.wait(4)
		end
		if motor then
			motor:Destroy()
		end
		if radio then
			radio:Destroy()
		end
		-- 9) tela preta... três batidas
		Cinema.escurecer(1, 0.3)
		Som.pararAmbientes(0.3)
		task.wait(1.4)
		Som.tocar("tres_batidas", { volume = 1 })
		task.wait(3.6)
		Cinema.titulo("FIM DO CAPÍTULO 1", true, 1.2)
		Cinema.rodape("OI TRÊS", true)
		task.wait(4.5)
		Cinema.titulo("FIM DO CAPÍTULO 1", false, 1)
		Cinema.rodape("OI TRÊS", false)
		task.wait(1.2)
	end)
	if not ok then
		warn("[OI3] erro no final:", err)
	end
	conexao:Disconnect()
	for _, a in atores do
		a:destruir()
	end
	pasta:Destroy()
	Cinema.faixas(false, 0.4)
	Cinema.limparLegenda()
	Iluminacao.noite(0)
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	if raiz and raiz.Parent and raiz:IsA("BasePart") then
		raiz.Anchored = false
	end
	ativo = false
	params.aoTerminar()
end

return Final
