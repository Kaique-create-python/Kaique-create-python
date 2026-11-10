-- BIZARRE BATTLEGROUNDS :: celular (liga tudo do lado do jogador)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
local BB = ReplicatedStorage:WaitForChild("BB")
local Cliente = BB:WaitForChild("Cliente")
local pastaRemotos = ReplicatedStorage:WaitForChild("BB_Remotos")
local remotos = {}
for _, nome in { "Acao", "Efeito", "Privado", "Entrar", "Admin" } do
	remotos[nome] = pastaRemotos:WaitForChild(nome)
end

for _, tipo in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(tipo, false)
	end)
end

local Som = require(Cliente:WaitForChild("Som"))
local Animador = require(Cliente:WaitForChild("Animador"))
local Camera = require(Cliente:WaitForChild("Camera"))
local HUD = require(Cliente:WaitForChild("HUD"))
local Efeitos = require(Cliente:WaitForChild("Efeitos"))
local StandVisual = require(Cliente:WaitForChild("StandVisual"))
local Acoes = require(Cliente:WaitForChild("Acoes"))
local Jogador = require(Cliente:WaitForChild("Jogador"))
local Controles = require(Cliente:WaitForChild("Controles"))
local Menu = require(Cliente:WaitForChild("Menu"))
local AdminCliente = require(Cliente:WaitForChild("AdminCliente"))
local UI = require(Cliente:WaitForChild("Interface"))

Som.iniciar()
Animador.iniciar()
HUD.iniciar(Jogador)
Efeitos.iniciar(HUD.gui())
local Cinematica = require(Cliente:WaitForChild("Cinematica"))
Cinematica.iniciar(HUD.gui())
-- correndo: poeirinha a cada passo
Animador.aoPasso = function(modelo: Model, forca: number)
	local r = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r and Efeitos.altaQualidade() then
		Efeitos.poeira(r.Position - Vector3.new(0, 2.7, 0) - r.CFrame.LookVector * 0.6, 0.9 + forca * 0.3, nil, 2)
	end
end
Camera.iniciar()
StandVisual.iniciar()
Jogador.iniciar(remotos, {
	aviso = HUD.aviso,
	combo = HUD.combo,
	cd = HUD.atualizarCds,
	entrada = function(d)
		Menu.respostaEntrada(d)
	end,
})
Controles.iniciar(Jogador, HUD)
AdminCliente.iniciar(remotos.Admin)

-------------------------------------------------------------------------------- efeitos do servidor
local TRATADORES = {
	acao = function(d)
		Acoes.tocar(d.quem, d)
	end,
	acerto = Efeitos.acerto,
	quebra = Efeitos.quebra,
	restaura = Efeitos.restaura,
	proj = Efeitos.proj,
	projFim = Efeitos.projFim,
	projRefletir = Efeitos.projRefletir,
	projVirar = Efeitos.projVirar,
	rolo = Efeitos.rolo,
	rebobinar = Efeitos.rebobinar,
	rebobinarFim = Efeitos.rebobinarFim,
	buff = Efeitos.buff,
	area = Efeitos.area,
	explosao = Efeitos.explosao,
	onda = Efeitos.onda,
	sol = Efeitos.sol,
	tempo = Efeitos.tempo,
	tempoVolta = Efeitos.tempoVolta,
	clash = Efeitos.clash,
	despertar = Efeitos.despertar,
	cura = Efeitos.cura,
	teleporte = Efeitos.teleporte,
	contra = Efeitos.contra,
	marca = Efeitos.marca,
	agarrao = Efeitos.agarrao,
	paredao = Efeitos.paredao,
	pulso = Efeitos.pulso,
	baile = Efeitos.baile,
	reconstruir = Efeitos.reconstruir,
	esquiva = Efeitos.esquiva,
	morte = HUD.morte,
	anuncio = function(d)
		HUD.anuncio(d.texto, d.cor)
	end,
}
remotos.Efeito.OnClientEvent:Connect(function(tipo, d)
	local fn = TRATADORES[tipo]
	if fn and type(d) == "table" then
		local ok, err = pcall(fn, d)
		if not ok then
			warn("[BB] efeito " .. tostring(tipo) .. ": " .. tostring(err))
		end
	end
end)

-------------------------------------------------------------------------------- estados visuais
-- ragdoll, tempo parado, preso na pedra, queimando
local extras: { [Model]: any } = {}
local function estadoVisual(m: Model, agora: number)
	local a = Animador.de(m)
	if not a then
		local tipo = if m:GetAttribute("BB_Bot") or m:GetAttribute("BB_Boneco") then "npc" else "jogador"
		a = Animador.registrar(m, tipo)
	end
	local nJuntas = 0
	for _ in a.juntas do
		nJuntas += 1
	end
	if nJuntas < (if a.r6 then 6 else 15) and os.clock() - (a.relido or 0) > 0.5 then
		a.relido = os.clock()
		Animador.atualizarJuntas(m)
	end
	local ragdoll = (m:GetAttribute("BB_Ragdoll") or 0) > agora
	a.ragdoll = if ragdoll then 1 else 0
	local pedra = (m:GetAttribute("BB_Pedra") or 0) > agora
	local preso = (m:GetAttribute("BB_Preso") or 0) > agora
	-- AJUSTE7: quem está parado no tempo é o que o SERVIDOR marcou (cada sessão tem os seus alvos)
	local tempo = (m:GetAttribute("BB_Congelado") or 0) > agora
	local stun = (m:GetAttribute("BB_Stun") or 0) > agora
	local travado = tempo or pedra or preso
	a.congelado = travado
	local x = extras[m]
	if not x then
		x = {}
		extras[m] = x
	end
	-- atordoou, congelou ou caiu AGORA: o golpe, a voz e os efeitos dele param na mesma hora
	if (stun and not x.stun) or (travado and not x.travado) or (ragdoll and not x.ragdoll) then
		Acoes.interromper(m)
	end
	x.stun, x.travado, x.ragdoll = stun, travado, ragdoll
	-- pedra/preso: corpo cinza ou rosado
	local bomba = (m:GetAttribute("BB_Bomba") or 0) > agora -- a Killer Queen transformou em bomba
	local querCor = if pedra then Color3.fromRGB(130, 128, 124) elseif preso or bomba then Color3.fromRGB(255, 150, 210) else nil
	if querCor and not x.brilho then
		local h = Instance.new("Highlight")
		h.FillColor = querCor
		h.FillTransparency = if pedra then 0.05 else 0.45
		h.OutlineColor = Color3.fromRGB(40, 40, 40)
		h.Parent = m
		x.brilho = h
	elseif not querCor and x.brilho then
		x.brilho:Destroy()
		x.brilho = nil
	end
	-- queimando
	local queima = (m:GetAttribute("BB_Queima") or 0) > agora
	local torso = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
	if queima and not x.fogo and torso then
		local f = Instance.new("Fire")
		f.Size = 4
		f.Heat = 8
		f.Color = Color3.fromRGB(255, 120, 30)
		f.SecondaryColor = Color3.fromRGB(255, 220, 80)
		f.Parent = torso
		x.fogo = f
	elseif not queima and x.fogo then
		x.fogo:Destroy()
		x.fogo = nil
	end
	return travado
end

RunService.RenderStepped:Connect(function()
	local agora = workspace:GetServerTimeNow()
	local vistos = {}
	for _, m in StandVisual.donos() do
		vistos[m] = true
		if m.Parent then
			local congelado = estadoVisual(m, agora)
			local st = StandVisual.modelo(m)
			local an = st and Animador.de(st)
			if an then
				an.congelado = congelado
			end
		end
	end
	local bots = workspace:FindFirstChild("BB_Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("BB_Boneco") and not vistos[m] then
				vistos[m] = true
				estadoVisual(m, agora)
			end
		end
	end
	for m, x in extras do
		if not vistos[m] or not m.Parent then
			if x.brilho then
				x.brilho:Destroy()
			end
			if x.fogo then
				x.fogo:Destroy()
			end
			extras[m] = nil
		end
	end
end)

-------------------------------------------------------------------------------- menu
local function entrarNoJogo(entrou: boolean)
	HUD.mostrar(true)
	Controles.ativar(true)
	if entrou then
		Som.musica("luta")
	end
end
Menu.iniciar(remotos, entrarNoJogo)
HUD.mostrar(false)
Controles.ativar(false)

-- botão STANDS no topo (trocar de Stand durante o jogo)
local guiTopo = Instance.new("ScreenGui")
guiTopo.Name = "BB_Topo"
guiTopo.ResetOnSpawn = false
guiTopo.DisplayOrder = 7
guiTopo.Parent = plr:WaitForChild("PlayerGui")
UI.escalaTela(guiTopo, 1100, 600, 0.55, 1.1)
local botaoStands = UI.botao(guiTopo, "STANDS", UDim2.fromOffset(110, 36), UDim2.new(0.5, -55, 0, 6), UI.CORES.roxo, { limite = 22 })
botaoStands.Visible = false
botaoStands.MouseButton1Click:Connect(function()
	Controles.ativar(false)
	HUD.mostrar(false)
	Menu.abrir(true)
end)
RunService.Heartbeat:Connect(function()
	botaoStands.Visible = not Menu.aberto() and plr.Character ~= nil
end)

-- morreu: aviso com contagem
plr.CharacterAdded:Connect(function(c)
	local hum = c:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			HUD.aviso("Você caiu! Voltando em 4...")
			HUD.continua(true)
			Camera.travar(nil)
			Controles.soltarTudo()
			Acoes.interromper(c)
		end)
	end
	-- renasceu: tela normal e câmera de volta no personagem
	HUD.continua(false)
	Camera.recuperar()
end)

-- espera o mundo ficar pronto e abre o menu (a tela de carregamento some depois disso)
-- (sem "pronto" de mentira: se o servidor não ligar, a tela de carregamento avisa e oferece
-- tentar de novo; o menu só abre com o servidor de pé)
while not workspace:GetAttribute("BB_Pronto") do
	task.wait(0.2)
end
Menu.abrir(false)
plr:SetAttribute("BB_MenuPronto", true)
