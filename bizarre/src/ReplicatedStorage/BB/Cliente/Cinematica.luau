-- AJUSTE-14: cinema local curto; sem títulos, música, onomatopeias ou efeitos desenhados.
-- O tempo parado/voz continuam pertencendo ao combate (não à duração desta câmera).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = require(script.Parent:WaitForChild("Camera"))
local Cinematica = {}
local RGB = Color3.fromRGB
local DURACAO_MAX = 0.9
local rng = Random.new()
local tela: Frame? = nil
local barraCima: Frame? = nil
local barraBaixo: Frame? = nil
local sessao: any = nil

local function tamanhoBarras(altura: number)
	for _, barra in { barraCima, barraBaixo } do
		if barra then barra.Size = UDim2.fromScale(1, altura) end
	end
end

local function limparEfeitos(cena: any)
	if cena.cor then cena.cor:Destroy() cena.cor = nil end
	if cena.dof then cena.dof:Destroy() cena.dof = nil end
	cena.camera = nil
end

function Cinematica.cancelar()
	local cena = sessao
	if not cena then return end
	sessao = nil
	if cena.con then cena.con:Disconnect() end
	limparEfeitos(cena)
	tamanhoBarras(0)
	local atual = Camera.pertence(cena.token)
	local cam = workspace.CurrentCamera
	local final = cam and cam.CFrame
	Camera.devolver("cinema", cena.token)
	if atual and Camera.dono() == "jogo" and final then Camera.suavizarRetorno(final, 0.35) end
end

function Cinematica.iniciar(gui: ScreenGui)
	if tela and tela.Parent == gui then return end
	Cinematica.cancelar()
	if tela then tela:Destroy() end
	local f = Instance.new("Frame")
	f.Name, f.Size, f.BackgroundTransparency, f.ZIndex = "BB_Cinema", UDim2.fromScale(1, 1), 1, 40
	f.Parent = gui
	tela = f
	for i, nome in { "BarraCima", "BarraBaixo" } do
		local b = Instance.new("Frame")
		b.Name, b.BackgroundColor3, b.BorderSizePixel, b.ZIndex = nome, RGB(0, 0, 0), 0, 41
		b.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		b.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		b.Size, b.Parent = UDim2.fromScale(1, 0), f
		if i == 1 then barraCima = b else barraBaixo = b end
	end
end

function Cinematica.tocando(): boolean
	return sessao ~= nil and Camera.pertence(sessao.token) and os.clock() < sessao.fim
end

local function efeitosCamera(cena: any, cam: Camera, foco: number)
	if cena.camera ~= cam then
		limparEfeitos(cena)
		cena.camera = cam
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BB_Cinema14_Cor"
		cc.Contrast, cc.Saturation, cc.Brightness = 0.18, 0.13, -0.02
		cc.TintColor = RGB(255, 255, 255):Lerp(cena.tinta, 0.16)
		cc.Parent, cena.cor = cam, cc
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "BB_Cinema14_Foco"
		dof.NearIntensity, dof.FarIntensity, dof.InFocusRadius = 0, 0.16, 14
		dof.Enabled, dof.Parent, cena.dof = true, cam, dof
	end
	cena.dof.FocusDistance = foco
end

-- Os quatro legados conservam o trajeto AJ13. SP revela o Stand pelo ombro esquerdo;
-- TW entra em contra-plongée e aproxima a mão/cabeça antes de abrir o quadro.
local function enquadrar(base: CFrame, rosto: Vector3, t: number, cena: any): (Vector3, Vector3)
	local lado = cena.lado
	local p1 = (base * CFrame.new(0.9 * lado, 0.9, -5.2)).Position
	local p2 = (base * CFrame.new(6.5 * lado, 2.2, -1.5)).Position
	local p3 = (base * CFrame.new(1.6 * lado, 2.6, 9.5)).Position
	local revelar = (base * CFrame.new(0, 1.5, 2.5)).Position
	if cena.id == "STAR_PLATINUM" then
		p1 = (base * CFrame.new(1.1, -0.6, -5.4)).Position
		p2 = (base * CFrame.new(-6.2, 1.4, -1.0)).Position
		revelar = (base * CFrame.new(-1.4, 1.6, 1.6)).Position
	elseif cena.id == "THE_WORLD" then
		p1 = (base * CFrame.new(-0.7, -1.3, -4.2)).Position
		p2 = (base * CFrame.new(4.8, 0.4, -2.4)).Position
		revelar = (base * CFrame.new(0.6, 1.5, -0.6)).Position
	elseif cena.baixo then
		p1 = (base * CFrame.new(0.4 * lado, -1.6, -6)).Position
	end
	if t < 0.42 then
		local e = 1 - (1 - t / 0.42) ^ 3
		return p1:Lerp(p2, e * 0.25), rosto
	elseif t < 0.8 then
		local k = (t - 0.42) / 0.38
		local e = k * k * (3 - 2 * k)
		return p1:Lerp(p2, 0.25 + e * 0.75), rosto:Lerp(revelar, e)
	else
		local k = (t - 0.8) / 0.2
		local e = k * k * (3 - 2 * k)
		return p2:Lerp(p3, e), revelar:Lerp((base * CFrame.new(0, 1.5, -20)).Position, e)
	end
end

local function comecar(modelo: Model, s: any, dur: number, baixo: boolean)
	if modelo ~= Players.LocalPlayer.Character or Camera.dono() == "menu" then return end
	if Camera.dono() ~= "jogo" and Camera.dono() ~= "cinema" then return end
	local raiz = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cabeca = modelo:FindFirstChild("Head") :: BasePart?
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if not raiz or not cabeca or not hum or hum.Health <= 0 then return end
	Cinematica.cancelar()
	local id = s and s.id
	local cena = {
		token = Camera.assumir("cinema"), modelo = modelo, t0 = os.clock(), fim = os.clock() + dur,
		dur = dur, baixo = baixo, id = id, lado = if rng:NextNumber() < 0.5 then -1 else 1,
		tinta = if id == "STAR_PLATINUM" then RGB(157, 167, 255) elseif id == "THE_WORLD" then RGB(255, 209, 125) else (s and s.aura or RGB(170, 90, 230)),
	}
	sessao = cena
	cena.con = RunService.RenderStepped:Connect(function()
		if sessao ~= cena then return end
		if not Camera.pertence(cena.token) or Players.LocalPlayer.Character ~= modelo or not modelo.Parent
			or not raiz.Parent or not cabeca.Parent or hum.Health <= 0 or os.clock() >= cena.fim then
			Cinematica.cancelar()
			return
		end
		-- CurrentCamera pode ser substituída por respawn/engine; nunca capturar a antiga no callback.
		local cam = workspace.CurrentCamera
		if not cam then return end
		cam.CameraType = Enum.CameraType.Scriptable
		local t = math.clamp((os.clock() - cena.t0) / cena.dur, 0, 1)
		local pos, olhar = enquadrar(raiz.CFrame, cabeca.Position, t, cena)
		cam.CFrame = CFrame.lookAt(pos, olhar)
		efeitosCamera(cena, cam, (pos - olhar).Magnitude)
		local entrada = math.clamp(t / 0.18, 0, 1)
		local saida = math.clamp((1 - t) / 0.16, 0, 1)
		tamanhoBarras(0.105 * math.min(entrada, saida))
		-- Pulso breve, sem estourar o branco nem esconder o adversário.
		if id == "STAR_PLATINUM" or id == "THE_WORLD" then
			local fov = if id == "STAR_PLATINUM" then 61 - math.sin(t * math.pi) * 5
				else 57 - math.sin(t * math.pi) * 4
			Camera.fovCinema(cena.token, fov)
		end
	end)
end

function Cinematica.ult(dono: Model?, s: any, g: any)
	if not dono or not g then return end
	local dur = math.clamp(g.cinema or DURACAO_MAX, 0.5, DURACAO_MAX)
	comecar(dono, s, dur, s ~= nil and (s.id == "THE_WORLD" or s.id == "KILLER_QUEEN"))
end
function Cinematica.despertar(dono: Model?, s: any)
	if dono and s then comecar(dono, s, DURACAO_MAX, true) end
end

return Cinematica
