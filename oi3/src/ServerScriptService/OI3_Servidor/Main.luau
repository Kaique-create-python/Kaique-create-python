-- OI3 :: servidor principal (monta o orfanato, remotos, dados, sala e spawn)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OI3 = ReplicatedStorage:WaitForChild("OI3")
local Config = require(OI3:WaitForChild("Config"))
local Mapa = require(OI3:WaitForChild("Mapa"))
local Dados = require(script.Parent:WaitForChild("Dados"))
local Sala = require(script.Parent:WaitForChild("Sala"))
local Atores = require(script.Parent:WaitForChild("Atores"))
local Historia = require(script.Parent:WaitForChild("Historia"))
local Missoes = require(script.Parent:WaitForChild("Missoes"))
local Admin = require(script.Parent:WaitForChild("Admin")) -- AJUSTE-10

local Main = {}

local remotos: { [string]: any } = {}
local limites: { [Player]: { [string]: number } } = {}
local modo: { [Player]: string } = {}

local function criarRemotos()
	local pasta = OI3:FindFirstChild("Remotos")
	if not pasta then
		pasta = Instance.new("Folder")
		pasta.Name = "Remotos"
	end
	local function ev(nome: string): RemoteEvent
		local r = pasta:FindFirstChild(nome)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = nome
			r.Parent = pasta
		end
		return r
	end
	local function fn(nome: string): RemoteFunction
		local r = pasta:FindFirstChild(nome)
		if not r then
			r = Instance.new("RemoteFunction")
			r.Name = nome
			r.Parent = pasta
		end
		return r
	end
	remotos.PedirDados = fn("PedirDados")
	remotos.SalvarConfig = ev("SalvarConfig")
	remotos.Entrar = ev("Entrar")
	remotos.Lanterna = ev("Lanterna")
	remotos.IntroVista = ev("IntroVista")
	remotos.Sala = ev("Sala")
	remotos.Historia = ev("Historia")
	remotos.Admin = ev("Admin") -- AJUSTE-10: comandos de ADM (o servidor confere quem pode)
	pasta.Parent = OI3
end

local function permitido(plr: Player, chave: string, intervalo: number): boolean
	local t = os.clock()
	local l = limites[plr]
	if not l then
		l = {}
		limites[plr] = l
	end
	local u = l[chave]
	if u and t - u < intervalo then
		return false
	end
	l[chave] = t
	return true
end

local function spawnar(plr: Player)
	if not plr.Parent then
		return
	end
	modo[plr] = "explorar"
	local ok, err = pcall(function()
		plr:LoadCharacter()
	end)
	if not ok then
		warn("[OI3] LoadCharacter falhou:", err)
		return
	end
	local char = plr.Character
	if char then
		local P = Mapa.pontos()
		local desloc = Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 5)
		char:PivotTo(P.spawn + desloc)
		Historia.personagemNasceu(plr) -- AJUSTE-6: vira a criança escolhida (itens do catálogo)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				task.wait(3)
				if modo[plr] == "explorar" and plr.Parent then
					spawnar(plr)
				end
			end)
		end
	end
end

local function despawnar(plr: Player)
	modo[plr] = "menu"
	Historia.sair(plr)
	local char = plr.Character
	if char then
		char:Destroy()
		plr.Character = nil
	end
end

local function lanterna(plr: Player, ligar: any)
	if type(ligar) ~= "boolean" or not permitido(plr, "lanterna", 0.2) then
		return
	end
	local char = plr.Character
	local cabeca = char and char:FindFirstChild("Head")
	if not cabeca then
		return
	end
	local luz = cabeca:FindFirstChild("OI3_Lanterna") :: SpotLight?
	if not luz then
		local nova = Instance.new("SpotLight")
		nova.Name = "OI3_Lanterna"
		nova.Brightness = 2.4
		nova.Range = 36
		nova.Angle = 50
		nova.Color = Color3.fromRGB(255, 236, 206)
		nova.Shadows = true
		nova.Face = Enum.NormalId.Front
		nova.Parent = cabeca
		luz = nova
	end
	(luz :: SpotLight).Enabled = ligar
end

local function aoEntrar(plr: Player)
	modo[plr] = "menu"
	task.spawn(Dados.carregar, plr)
end

function Main.iniciar()
	Players.CharacterAutoLoads = false
	criarRemotos()

	-- o orfanato (troca qualquer versão antiga)
	local okMapa, errMapa = pcall(function()
		local antigo = workspace:FindFirstChild("Orfanato")
		if antigo then
			antigo:Destroy()
		end
		Mapa.construir(workspace)
	end)
	if not okMapa then
		warn("[OI3] erro ao montar o mapa:", errMapa)
	end
	local okTerreno, errTerreno = pcall(function()
		Mapa.construirTerreno(workspace.Terrain)
	end)
	if not okTerreno then
		warn("[OI3] terreno:", errTerreno)
	end

	Atores.preparar() -- AJUSTE-6: personagens = avatares do Roblox só com IDs do catálogo
	Historia.iniciar(remotos.Historia, permitido, Atores.vestirJogador, {
		missao = Dados.missao,
		marcarMissao = Dados.marcarMissao,
		marcarFimCapitulo = Dados.marcarFimCapitulo,
	})
	Dados.iniciar()
	Sala.iniciar(remotos.Sala)
	Admin.iniciar(remotos.Admin, Historia, Missoes, Atores)

	remotos.PedirDados.OnServerInvoke = function(plr: Player)
		local d = Dados.obter(plr)
		return { config = d.config, viuIntro = d.viuIntro == true }
	end
	remotos.SalvarConfig.OnServerEvent:Connect(function(plr: Player, cfg: any)
		if permitido(plr, "config", 0.5) then
			Dados.definirConfig(plr, cfg)
		end
	end)
	remotos.IntroVista.OnServerEvent:Connect(function(plr: Player)
		if permitido(plr, "intro", 2) then
			Dados.marcarIntro(plr)
		end
	end)
	remotos.Entrar.OnServerEvent:Connect(function(plr: Player, para: any)
		if not permitido(plr, "entrar", 0.8) then
			return
		end
		if para == "explorar" then
			spawnar(plr)
		elseif para == "menu" then
			despawnar(plr)
		end
	end)
	remotos.Lanterna.OnServerEvent:Connect(lanterna)

	Players.PlayerAdded:Connect(aoEntrar)
	for _, plr in Players:GetPlayers() do
		aoEntrar(plr)
	end
	Players.PlayerRemoving:Connect(function(plr: Player)
		modo[plr] = nil
		limites[plr] = nil
		Dados.salvarESoltar(plr)
	end)

	workspace:SetAttribute("OI3_Revisao", Config.REVISAO)
	workspace:SetAttribute("OI3_Pronto", true)
end

return Main
