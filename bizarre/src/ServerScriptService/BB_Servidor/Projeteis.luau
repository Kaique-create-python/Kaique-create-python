-- BIZARRE BATTLEGROUNDS :: projéteis (rolamento, facas, ankh de fogo, rapieira, moeda, tanquinho...)
-- O servidor calcula o caminho e os acertos; os celulares desenham o mesmo caminho.
-- "guiado" (Sheer Heart Attack): vira devagar atrás do inimigo mais perto e avisa os celulares.

local RunService = game:GetService("RunService")

local Hitbox = require(script.Parent.Hitbox)
local Mapa = require(script.Parent.Mapa)

local Projeteis = {}

local ativos: { [number]: any } = {}
local proximoId = 0
local remoto: RemoteEvent? = nil
local aoAcertar: ((p: any, alvo: any, pos: Vector3) -> ())? = nil
local aoExplodir: ((p: any, pos: Vector3) -> ())? = nil
local contraDe: ((alvo: any, p: any) -> boolean)? = nil

local paramsRaio = RaycastParams.new()
paramsRaio.FilterType = Enum.RaycastFilterType.Include
pcall(function()
	paramsRaio.RespectCanCollide = true
end)

local function agora(): number
	return workspace:GetServerTimeNow()
end

function Projeteis.iniciar(efeito: RemoteEvent, acertar: any, explodir: any, contra: any)
	remoto = efeito
	aoAcertar = acertar
	aoExplodir = explodir
	contraDe = contra
	RunService.Heartbeat:Connect(function(dt)
		Projeteis.passo(dt)
	end)
end

function Projeteis.lancar(dono: any, def: any, origem: Vector3, dir: Vector3, golpeId: string?): number
	proximoId += 1
	local id = proximoId
	local p = {
		id = id,
		dono = dono,
		def = def,
		pos = origem,
		dir = dir.Unit,
		vel = def.vel or 80,
		raio = def.raio or 1.5,
		dist = 0,
		alcance = def.alcance or 80,
		acertou = {},
		golpe = golpeId,
		t0 = agora(),
		congeladoAte = 0,
		avisoT = 0,
	}
	ativos[id] = p
	if remoto then
		remoto:FireAllClients("proj", {
			id = id,
			dono = dono.modelo,
			visual = def.visual,
			origem = origem,
			dir = p.dir,
			vel = p.vel,
			alcance = p.alcance,
			raio = p.raio,
			t = p.t0,
			stand = dono.standId,
		})
	end
	return id
end

-- persegue o inimigo mais perto (só no plano do chão) virando no máximo "guiado" radianos/s
local function guiar(p: any, dt: number, t: number)
	local melhor, melhorD = nil, 70
	for _, l in Hitbox.esfera(p.pos, 70, p.dono) do
		local d = (l.raiz.Position - p.pos).Magnitude
		if d < melhorD then
			melhor, melhorD = l, d
		end
	end
	if not melhor then
		return
	end
	local quer = melhor.raiz.Position - p.pos
	quer = Vector3.new(quer.X, 0, quer.Z)
	if quer.Magnitude < 0.5 then
		return
	end
	quer = quer.Unit
	local atual = Vector3.new(p.dir.X, 0, p.dir.Z)
	if atual.Magnitude < 1e-3 then
		atual = quer
	end
	atual = atual.Unit
	local ang = math.acos(math.clamp(atual:Dot(quer), -1, 1))
	local maximo = p.def.guiado * dt
	local novo = quer
	if ang > maximo then
		local lado = if atual:Cross(quer).Y >= 0 then 1 else -1
		novo = CFrame.Angles(0, maximo * lado, 0):VectorToWorldSpace(atual)
	end
	p.dir = novo.Unit
	if remoto and t - p.avisoT >= 0.12 then
		p.avisoT = t
		remoto:FireAllClients("projVirar", { id = p.id, pos = p.pos, dir = p.dir, t = t, resta = math.max(0, p.alcance - p.dist) })
	end
end

local function terminar(p: any, pos: Vector3, explodiu: boolean)
	ativos[p.id] = nil
	if explodiu and p.def.explosao and aoExplodir then
		aoExplodir(p, pos)
	end
	if remoto then
		remoto:FireAllClients("projFim", { id = p.id, pos = pos, explodiu = explodiu })
	end
end

function Projeteis.congelar(ate: number, exceto: any?)
	for _, p in ativos do
		if p.dono ~= exceto then
			p.congeladoAte = ate
		end
	end
end

function Projeteis.passo(dt: number)
	local t = agora()
	paramsRaio.FilterDescendantsInstances = Mapa.filtro()
	for _, p in ativos do
		if t < p.congeladoAte then
			continue
		end
		if p.def.guiado then
			guiar(p, dt, t)
		end
		local passo = p.dir * p.vel * dt
		-- bateu no mapa?
		local hit = workspace:Raycast(p.pos, passo + p.dir * p.raio * 0.5, paramsRaio)
		if hit and hit.Instance.CanCollide then
			local parte = hit.Instance :: BasePart
			if Mapa.ehQuebravel(parte) then
				Mapa.quebrar(parte, p.dir, if p.def.explosao then p.def.explosao.quebra or 1 else 1)
			end
			terminar(p, hit.Position, true)
			continue
		end
		p.pos += passo
		p.dist += passo.Magnitude
		-- acertou alguém?
		local fim = false
		for _, alvo in Hitbox.esfera(p.pos, p.raio + 1.2, p.dono) do
			if p.acertou[alvo] then
				continue
			end
			p.acertou[alvo] = true
			-- contra-ataque que devolve projéteis (sombrinha do FREVO)
			if contraDe and contraDe(alvo, p) then
				p.dono = alvo
				p.dir = -p.dir
				p.acertou = { [alvo] = true }
				p.dist = 0
				if remoto then
					remoto:FireAllClients("projRefletir", { id = p.id, pos = p.pos, dir = p.dir, t = t, dono = alvo.modelo })
				end
				fim = false
				break
			end
			if p.def.explosao then
				terminar(p, p.pos, true)
				fim = true
				break
			end
			if aoAcertar then
				aoAcertar(p, alvo, p.pos)
			end
			if not p.def.perfura then
				terminar(p, p.pos, false)
				fim = true
				break
			end
		end
		if not fim and ativos[p.id] and p.dist >= p.alcance then
			terminar(p, p.pos, p.def.explodeNoFim == true)
		end
	end
end

function Projeteis.quantos(): number
	local n = 0
	for _ in ativos do
		n += 1
	end
	return n
end

return Projeteis
