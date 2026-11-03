-- BIZARRE BATTLEGROUNDS :: empurrões, ragdoll, prender e mover lutadores
-- O personagem do jogador é simulado pelo celular dele: o servidor cria um LinearVelocity dentro
-- dele (isso vai junto para o celular) e marca BB_Ragdoll; o celular do dono deita o personagem.

local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Fisica = {}

Fisica.GRUPOS = {
	lutador = "BB_Lutadores",
	voando = "BB_Voando",
	quebravel = "BB_Quebravel",
	destrocos = "BB_Destrocos",
	efeito = "BB_Efeitos",
}

local remotoPrivado: RemoteEvent? = nil

function Fisica.iniciar(privado: RemoteEvent?)
	remotoPrivado = privado
	local G = Fisica.GRUPOS
	for _, nome in { G.lutador, G.voando, G.quebravel, G.destrocos, G.efeito } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(nome)
		end)
	end
	pcall(function()
		-- lutadores não se empurram (ninguém fica entalado no meio de uma rajada)
		PhysicsService:CollisionGroupSetCollidable(G.lutador, G.lutador, false)
		PhysicsService:CollisionGroupSetCollidable(G.lutador, G.voando, false)
		PhysicsService:CollisionGroupSetCollidable(G.voando, G.voando, false)
		-- quem está voando atravessa (e quebra) as paredes
		PhysicsService:CollisionGroupSetCollidable(G.voando, G.quebravel, false)
		-- destroços não empurram ninguém
		PhysicsService:CollisionGroupSetCollidable(G.destrocos, G.lutador, false)
		PhysicsService:CollisionGroupSetCollidable(G.destrocos, G.voando, false)
		PhysicsService:CollisionGroupSetCollidable(G.destrocos, G.destrocos, false)
		-- efeitos não colidem com nada
		for _, outro in { "Default", G.lutador, G.voando, G.quebravel, G.destrocos, G.efeito } do
			PhysicsService:CollisionGroupSetCollidable(G.efeito, outro, false)
		end
	end)
end

function Fisica.grupo(modelo: Model, nome: string)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = nome
		end
	end
end

local function anexo(raiz: BasePart): Attachment
	local a = raiz:FindFirstChild("RootAttachment") or raiz:FindFirstChild("BB_Anexo")
	if a and a:IsA("Attachment") then
		return a
	end
	local novo = Instance.new("Attachment")
	novo.Name = "BB_Anexo"
	novo.Parent = raiz
	return novo
end

function Fisica.limparEmpurroes(raiz: BasePart)
	for _, f in raiz:GetChildren() do
		if f.Name == "BB_Empurrao" then
			f:Destroy()
		end
	end
end

-- empurra o lutador com velocidade constante por "dur" segundos
function Fisica.empurrar(lut: any, vel: Vector3, dur: number)
	local raiz: BasePart = lut.raiz
	if raiz.Anchored then
		return
	end
	Fisica.limparEmpurroes(raiz)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "BB_Empurrao"
	lv.Attachment0 = anexo(raiz)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e7
	lv.VectorVelocity = vel
	lv.Parent = raiz
	Debris:AddItem(lv, math.max(0.04, dur))
	if not lut.jogador then
		pcall(function()
			raiz.AssemblyLinearVelocity = vel
		end)
	end
end

-- ragdoll: marca, troca o grupo de colisão (atravessa paredes quebráveis) e deita
function Fisica.derrubar(lut: any, ate: number)
	local m = lut.modelo
	m:SetAttribute("BB_Ragdoll", ate)
	Fisica.grupo(m, Fisica.GRUPOS.voando)
	if not lut.jogador then
		pcall(function()
			lut.hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
		for _, nome in { "UpperTorso", "LowerTorso", "Head", "Torso" } do
			local p = m:FindFirstChild(nome) :: BasePart?
			if p then
				p.CanCollide = true
			end
		end
	end
end

function Fisica.levantar(lut: any)
	local m = lut.modelo
	m:SetAttribute("BB_Ragdoll", 0)
	Fisica.grupo(m, Fisica.GRUPOS.lutador)
	if not lut.jogador and lut.hum.Health > 0 then
		pcall(function()
			lut.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
end

-- o próprio lutador se move (investidas e saltos dos bots; jogadores fazem isso no celular)
function Fisica.impulsoProprio(lut: any, dir: Vector3, frente: number, cima: number, dur: number)
	if lut.jogador then
		return
	end
	local v = Vector3.new(dir.X, 0, dir.Z)
	if v.Magnitude > 1e-3 then
		v = v.Unit
	end
	Fisica.empurrar(lut, v * frente + Vector3.new(0, cima, 0), dur)
end

-- teleporta (jogador: pede para o celular dele; bot: move direto)
function Fisica.moverPara(lut: any, cf: CFrame)
	if lut.jogador then
		if remotoPrivado then
			remotoPrivado:FireClient(lut.jogador, "mover", { cf = cf })
		end
	end
	-- o servidor também move: quem está olhando já vê no lugar novo
	pcall(function()
		lut.modelo:PivotTo(cf)
	end)
end

-- prende no lugar (tempo parado, agarrão, preso na parede)
function Fisica.prender(lut: any)
	Fisica.limparEmpurroes(lut.raiz)
	lut.raiz.Anchored = true
end

function Fisica.soltar(lut: any)
	if lut.raiz and lut.raiz.Parent then
		lut.raiz.Anchored = false
	end
end

-- avisa o celular do dono para parar uma investida/dash agora
function Fisica.pararMovimento(lut: any)
	if lut.jogador and remotoPrivado then
		remotoPrivado:FireClient(lut.jogador, "parar", {})
	else
		Fisica.limparEmpurroes(lut.raiz)
	end
end

return Fisica
