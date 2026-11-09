--!strict
-- Trajetórias determinísticas dos desastres que se movem.
-- O servidor usa estas funções para aplicar dano/empurrões; os clientes usam
-- as MESMAS funções para desenhar o visual localmente (suave e sem tráfego).
-- Parâmetros vêm dos atributos da pasta do acontecimento (FxPos, FxVel, FxT0...).

local FxPaths = {}

export type Spec = {
	pos: Vector3,
	vel: Vector3,
	t0: number,
	dur: number,
	radius: number,
	height: number,
	seed: number,
	power: number,
}

function FxPaths.fromFolder(folder: Instance): Spec
	return {
		pos = folder:GetAttribute("FxPos") :: Vector3 or Vector3.zero,
		vel = folder:GetAttribute("FxVel") :: Vector3 or Vector3.zero,
		t0 = folder:GetAttribute("FxT0") :: number or 0,
		dur = folder:GetAttribute("FxDur") :: number or 10,
		radius = folder:GetAttribute("FxRadius") :: number or 10,
		height = folder:GetAttribute("FxHeight") :: number or 40,
		seed = folder:GetAttribute("FxSeed") :: number or 0,
		power = folder:GetAttribute("FxPower") :: number or 1,
	}
end

function FxPaths.write(folder: Instance, kind: string, spec: Spec, element: string?)
	folder:SetAttribute("FxKind", kind)
	folder:SetAttribute("FxPos", spec.pos)
	folder:SetAttribute("FxVel", spec.vel)
	folder:SetAttribute("FxT0", spec.t0)
	folder:SetAttribute("FxDur", spec.dur)
	folder:SetAttribute("FxRadius", spec.radius)
	folder:SetAttribute("FxHeight", spec.height)
	folder:SetAttribute("FxSeed", spec.seed)
	folder:SetAttribute("FxPower", spec.power)
	if element then
		folder:SetAttribute("FxElement", element)
	end
end

-- tornado: avança na direção de vel e serpenteia lateralmente
function FxPaths.tornado(s: Spec, t: number): Vector3
	local dt = math.clamp(t - s.t0, 0, s.dur)
	local dir = if s.vel.Magnitude > 0.01 then s.vel.Unit else Vector3.xAxis
	local perp = Vector3.new(-dir.Z, 0, dir.X)
	return s.pos + s.vel * dt + perp * math.sin(dt * 0.55 + s.seed) * 22
end

-- tsunami: frente da onda avançando em linha reta
function FxPaths.wave(s: Spec, t: number): Vector3
	local dt = math.clamp(t - s.t0, 0, s.dur)
	return s.pos + s.vel * dt
end

-- meteoro: queda em linha reta de pos (céu) até pos+vel (alvo) em dur segundos
function FxPaths.meteor(s: Spec, t: number): (Vector3, number)
	local a = math.clamp((t - s.t0) / s.dur, 0, 1)
	-- leve aceleração no fim
	local eased = a * a * 0.35 + a * 0.65
	return s.pos:Lerp(s.pos + s.vel, eased), a
end

-- progresso 0..1 de um efeito estático (buraco negro, explosão)
function FxPaths.progress(s: Spec, t: number): number
	return math.clamp((t - s.t0) / s.dur, 0, 1)
end

return FxPaths
