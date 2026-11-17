--!strict
-- PROJETO BASTIÃO :: Pavel (Sgt. Pavel Antonov, NPC da abertura)
-- Clone do StarterCharacter R6 do próprio jogo, vestido com um uniforme soviético do catálogo
-- (jaqueta e calça Afghanka cáqui + ushanka; se o catálogo falhar, fica com as cores de antes,
-- diferentes das dos jogadores). Anda pelos eixos dos corredores medidos no mapa, usa as
-- animações R6 padrão do Roblox (as mesmas do Animate do jogo): parado (com a variação de olhar
-- em volta), andar, apontar ao chegar num lugar e acenar quando alguém chega perto pela primeira
-- vez. Parado, vira o corpo para o jogador mais perto. Não morre, não atravessa portas fechadas
-- e não colide com jogadores (grupo próprio).

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local PhysicsService = game:GetService("PhysicsService")

local Pavel = {}
Pavel.__index = Pavel

local V = Vector3.new
local VELOCIDADE = 15
local ALTURA_RAIZ = 3 -- R6 em pé: raiz 3 studs acima do chão
local ANIM_PARADO = "rbxassetid://180435571" -- animações R6 padrão do Roblox
local ANIM_ANDAR = "rbxassetid://180426354"
local ANIM_PARADO_OLHAR = "rbxassetid://180435792" -- variação do parado (olha em volta)
local ANIM_APONTAR = "rbxassetid://128853357"
local ANIM_ACENAR = "rbxassetid://128777973"
-- uniforme do catálogo (itens públicos; IDs conferidos na API do catálogo do Roblox)
local ROUPA = {
	camisa = 6865584651, -- "Soviet Afghanka Jacket" (Zairian Military Industries)
	calca = 6866147363, -- "Soviet Afghanka Trousers" (Zairian Military Industries)
	chapeu = "46348897", -- "Soviet Ushanka" (Roblox)
}
Pavel.GRUPO = "BastiaoNPC"

-- onde ele fica em cada estado e para onde olha quando não há ninguém perto
Pavel.LUGARES = {
	tunel = { pos = V(3.4, 0, 2.2), olhar = V(0, 0, 12) },
	arsenal = { pos = V(-82.5, 0, -203.5), olhar = V(-66, 0, -220) },
	enfermaria = { pos = V(-58.5, 0, -310.5), olhar = V(-65, 0, -320) },
	porta_oficina = { pos = V(60.0, 0, -311.0), olhar = V(65, 0, -320) },
	oficina = { pos = V(71.5, 0, -304.5), olhar = V(66, 0, -318) },
}

-- pontos no eixo dos corredores (cruzamentos em z -80 e -260; anéis de serviço em x ±58)
Pavel.ROTAS = {
	["tunel>arsenal"] = { V(2.5, 0, -12), V(0.5, 0, -78), V(-56.5, 0, -81.5), V(-58, 0, -212), V(-69, 0, -219) },
	["arsenal>enfermaria"] = { V(-70, 0, -220), V(-58, 0, -228), V(-58, 0, -298) },
	["enfermaria>porta_oficina"] = { V(-58, 0, -262), V(0, 0, -260), V(57.5, 0, -261), V(58, 0, -300) },
	["porta_oficina>oficina"] = { V(61, 0, -318.5), V(68, 0, -319), V(77, 0, -314), V(77, 0, -305) },
}

local CORES = {
	pele = Color3.fromRGB(176, 148, 122),
	tronco = Color3.fromRGB(112, 104, 76), -- túnica cáqui: os jogadores usam oliva
	pernas = Color3.fromRGB(52, 56, 44),
}

local function horizontal(a: Vector3, b: Vector3): number
	return V(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function criarRig(): Model?
	local base = StarterPlayer:FindFirstChild("StarterCharacter")
	if base and base:IsA("Model") then
		return base:Clone()
	end
	local ok, r = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	return if ok then r else nil
end

function Pavel.criar(pasta: Instance, log: ((string) -> ())?): any
	local self = setmetatable({}, Pavel)
	self.log = log or function(_m: string) end
	self.geracao = 0
	self.estado = nil :: string?
	self.chegouFlag = false
	self.vivo = true

	local rig = criarRig()
	if not rig then
		self.log("[Bastiao] não foi possível criar o Pavel (sem StarterCharacter)")
		self.rig = nil
		return self
	end
	rig.Name = "Pavel"
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local raiz = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hum or not raiz or not raiz:IsA("BasePart") then
		self.log("[Bastiao] Pavel indisponível: StarterCharacter sem Humanoid ou HumanoidRootPart válido")
		rig:Destroy()
		self.rig = nil
		return self
	end
	rig.PrimaryPart = raiz
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.NameDisplayDistance = 0
	hum.WalkSpeed = VELOCIDADE
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.MaxHealth = 100
	hum.Health = 100
	for _, est in {
		Enum.HumanoidStateType.Dead,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Jumping,
	} do
		hum:SetStateEnabled(est, false)
	end
	local cores = rig:FindFirstChildOfClass("BodyColors")
	if cores then
		cores.HeadColor3 = CORES.pele
		cores.LeftArmColor3 = CORES.pele
		cores.RightArmColor3 = CORES.pele
		cores.TorsoColor3 = CORES.tronco
		cores.LeftLegColor3 = CORES.pernas
		cores.RightLegColor3 = CORES.pernas
	end
	-- o grupo pode já existir (o boot registra); registrar de novo só dá erro, então pcall
	pcall(function()
		PhysicsService:RegisterCollisionGroup(Pavel.GRUPO)
	end)
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = Pavel.GRUPO
			d.CanTouch = false
		end
	end
	rig:SetAttribute("BastiaoNPC", true)
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local inicio = Pavel.LUGARES.tunel
	rig:PivotTo(CFrame.lookAt(inicio.pos + V(0, ALTURA_RAIZ, 0), V(inicio.olhar.X, ALTURA_RAIZ, inicio.olhar.Z)))
	rig.Parent = pasta
	pcall(function()
		raiz:SetNetworkOwner(nil)
	end)
	-- uniforme do catálogo: primeiro roupa, depois o chapéu (se o chapéu falhar, a roupa fica)
	task.spawn(function()
		local cabeca = rig:FindFirstChild("Head")
		local rosto = cabeca and cabeca:FindFirstChildOfClass("Decal")
		local textura = rosto and rosto.Texture
		local function descricao(comChapeu: boolean): HumanoidDescription
			local d = Instance.new("HumanoidDescription")
			d.Shirt = ROUPA.camisa
			d.Pants = ROUPA.calca
			if comChapeu then
				d.HatAccessory = ROUPA.chapeu
			end
			d.HeadColor, d.LeftArmColor, d.RightArmColor = CORES.pele, CORES.pele, CORES.pele
			d.TorsoColor, d.LeftLegColor, d.RightLegColor = CORES.tronco, CORES.pernas, CORES.pernas
			return d
		end
		local vestiu = false
		for _, comChapeu in { false, true } do
			local ok, erro = pcall(function()
				hum:ApplyDescription(descricao(comChapeu))
			end)
			if ok then
				vestiu = true
			else
				self.log("[Bastiao] uniforme do Pavel " .. (if comChapeu then "(chapéu)" else "(roupa)") .. " falhou: " .. tostring(erro))
			end
		end
		-- o ApplyDescription pode trocar o rosto: devolve o rosto do personagem do jogo
		if vestiu and textura and cabeca and cabeca.Parent then
			local atual = cabeca:FindFirstChildOfClass("Decal")
			if not atual then
				atual = Instance.new("Decal")
				atual.Name = "face"
				atual.Face = Enum.NormalId.Front
				atual.Parent = cabeca
			end
			atual.Texture = textura
		end
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = Pavel.GRUPO
				d.CanTouch = false
			end
		end
	end)

	-- animações padrão R6 tocadas pelo servidor (replicam para todos)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local function faixa(id: string, prioridade: Enum.AnimationPriority, repetir: boolean?): AnimationTrack?
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, t = pcall(function()
			return (animator :: Animator):LoadAnimation(a)
		end)
		if not ok then
			self.log("[Bastiao] animação do Pavel falhou: " .. tostring(t))
			return nil
		end
		t.Looped = repetir ~= false
		t.Priority = prioridade
		return t
	end
	local parado = faixa(ANIM_PARADO, Enum.AnimationPriority.Idle)
	local andar = faixa(ANIM_ANDAR, Enum.AnimationPriority.Movement)
	local paradoOlhar = faixa(ANIM_PARADO_OLHAR, Enum.AnimationPriority.Idle, false)
	self.apontar = faixa(ANIM_APONTAR, Enum.AnimationPriority.Action, false)
	self.acenar = faixa(ANIM_ACENAR, Enum.AnimationPriority.Action, false)
	self.gestoAte = 0
	self.cumprimentados = {}
	if parado then
		parado:Play(0.2)
	end
	hum.Running:Connect(function(velocidade: number)
		if velocidade > 0.6 then
			if andar and not andar.IsPlaying then
				andar:Play(0.2)
			end
			if andar then
				andar:AdjustSpeed(velocidade / 14.5)
			end
			if parado and parado.IsPlaying then
				parado:Stop(0.2)
			end
		else
			if parado and not parado.IsPlaying then
				parado:Play(0.25)
			end
			if andar and andar.IsPlaying then
				andar:Stop(0.25)
			end
		end
	end)

	-- girar parado sem empurrar: AlignOrientation só no eixo do corpo
	local olho = Instance.new("Attachment")
	olho.Name = "Olhar"
	olho.Parent = raiz
	local giro = Instance.new("AlignOrientation")
	giro.Name = "VirarCorpo"
	giro.Mode = Enum.OrientationAlignmentMode.OneAttachment
	giro.Attachment0 = olho
	giro.Responsiveness = 10
	giro.MaxTorque = 400000
	giro.RigidityEnabled = false
	giro.Enabled = false
	giro.Parent = raiz

	self.rig = rig
	self.hum = hum
	self.raiz = raiz
	self.giro = giro
	self.estado = "tunel"
	self.chegouFlag = true
	self:_parar(inicio.olhar)

	-- de vez em quando, parado, olha em volta (variação do parado do Roblox)
	task.spawn(function()
		while self.vivo and rig.Parent do
			task.wait(9 + math.random() * 8)
			if paradoOlhar and self.chegouFlag and os.clock() > self.gestoAte and not (andar and andar.IsPlaying) then
				paradoOlhar:Play(0.3)
			end
		end
	end)

	-- olhar para quem está perto (4 vezes por segundo)
	task.spawn(function()
		while self.vivo and rig.Parent do
			task.wait(0.25)
			if self.chegouFlag and self.estado and os.clock() > self.gestoAte then
				local alvo = Pavel.LUGARES[self.estado].olhar
				local melhor = 16
				for _, p in Players:GetPlayers() do
					local c = p.Character
					local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
					local h = c and c:FindFirstChildOfClass("Humanoid")
					if r and h and h.Health > 0 then
						local d = (r.Position - raiz.Position).Magnitude
						if d < melhor then
							melhor = d
							alvo = r.Position
						end
						-- primeira vez que alguém chega perto: acena
						if d < 12 and not self.cumprimentados[p.UserId] then
							self.cumprimentados[p.UserId] = true
							self:_gesto(self.acenar, 1.6)
						end
					end
				end
				self:_olhar(alvo)
			end
		end
	end)
	return self
end

function Pavel:_olhar(alvo: Vector3)
	local raiz = self.raiz :: BasePart
	local dir = V(alvo.X - raiz.Position.X, 0, alvo.Z - raiz.Position.Z)
	if dir.Magnitude > 0.2 then
		self.giro.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit)
	end
end

-- gesto curto (apontar/acenar) sem girar o corpo no meio dele
function Pavel:_gesto(faixa: AnimationTrack?, duracao: number)
	if not faixa or not self.rig then
		return
	end
	self.gestoAte = os.clock() + duracao
	faixa:Play(0.15)
end

function Pavel:_parar(olhar: Vector3)
	if not self.rig then
		return
	end
	self.hum:MoveTo(self.raiz.Position)
	self.hum.AutoRotate = false
	self:_olhar(olhar)
	self.giro.Enabled = true
end

function Pavel:chegou(): boolean
	return self.rig == nil or self.chegouFlag
end

function Pavel:ir(estado: string, instantaneo: boolean)
	local lugar = Pavel.LUGARES[estado]
	if not lugar then
		return
	end
	self.geracao += 1
	local minha = self.geracao
	local anterior = self.estado
	self.estado = estado
	if not self.rig then
		self.chegouFlag = true
		return
	end
	local rig, hum, raiz = self.rig :: Model, self.hum :: Humanoid, self.raiz :: BasePart
	local rota = anterior and Pavel.ROTAS[anterior .. ">" .. estado]
	if instantaneo or anterior == estado or rota == nil then
		rig:PivotTo(CFrame.lookAt(lugar.pos + V(0, ALTURA_RAIZ, 0), V(lugar.olhar.X, ALTURA_RAIZ, lugar.olhar.Z)))
		self.chegouFlag = true
		self:_parar(lugar.olhar)
		return
	end
	self.chegouFlag = false
	self.giro.Enabled = false
	hum.AutoRotate = true
	local pontos = table.clone(rota)
	table.insert(pontos, lugar.pos)
	task.spawn(function()
		for _, p in pontos do
			if minha ~= self.geracao then
				return
			end
			local inicio = os.clock()
			local limite = horizontal(raiz.Position, p) / VELOCIDADE + 4
			local ultimoPedido = inicio
			hum:MoveTo(p)
			while minha == self.geracao do
				if horizontal(raiz.Position, p) < 1.8 then
					break
				end
				if os.clock() - inicio > limite then
					-- preso em algo: reposiciona no ponto e segue (não perde a cena)
					rig:PivotTo(CFrame.new(p + V(0, ALTURA_RAIZ, 0)) * raiz.CFrame.Rotation)
					break
				end
				if os.clock() - ultimoPedido > 3 then
					hum:MoveTo(p)
					ultimoPedido = os.clock()
				end
				task.wait(0.1)
			end
		end
		if minha == self.geracao then
			self.chegouFlag = true
			self:_parar(lugar.olhar)
			-- chegou: aponta para onde a turma tem que ir (já virado para lá)
			task.wait(0.35)
			if minha == self.geracao then
				self:_gesto(self.apontar, 1.8)
			end
		end
	end)
end

return Pavel
