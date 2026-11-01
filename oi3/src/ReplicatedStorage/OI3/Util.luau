-- OI3 :: utilidades gerais (sem dependência de cliente/servidor)

local TweenService = game:GetService("TweenService")

local Util = {}

-- Cria uma instância com propriedades e filhos.
-- Util.novo("Part", { Size = ..., Parent = ... }, { filho1, filho2 })
function Util.novo(classe: string, props: { [string]: any }?, filhos: { Instance }?): any
	local inst = Instance.new(classe)
	local pai = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				pai = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if filhos then
		for _, f in filhos do
			f.Parent = inst
		end
	end
	if pai then
		inst.Parent = pai
	end
	return inst
end

function Util.tween(obj: Instance, tempo: number, props: { [string]: any }, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?): Tween
	local info = TweenInfo.new(tempo, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

function Util.clamp(x: number, a: number, b: number): number
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Suavizações usadas na câmera e nos atores
function Util.suave(t: number): number
	t = Util.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function Util.suaveForte(t: number): number
	t = Util.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Ruído simples e determinístico (para tremor de câmera e chamas)
function Util.ruido(x: number, semente: number?): number
	local s = semente or 0
	return math.noise(x, s * 1.37 + 0.5, 0.25)
end

-- Duração estimada de uma fala (quando não há áudio)
function Util.duracaoTexto(texto: string): number
	local n = utf8.len(texto) or #texto
	return math.max(1.6, n / 14 + 0.7)
end

-- Sinal minimalista (para eventos internos)
export type Sinal = {
	conectar: (self: Sinal, fn: (...any) -> ()) -> () -> (),
	disparar: (self: Sinal, ...any) -> (),
	limpar: (self: Sinal) -> (),
}

function Util.sinal(): Sinal
	local ouvintes: { [number]: ((...any) -> ())? } = {}
	local proximo = 0
	local s = {}
	function s:conectar(fn)
		proximo += 1
		local id = proximo
		ouvintes[id] = fn
		return function()
			ouvintes[id] = nil
		end
	end
	function s:disparar(...)
		for _, fn in ouvintes do
			if fn then
				task.spawn(fn, ...)
			end
		end
	end
	function s:limpar()
		table.clear(ouvintes)
	end
	return (s :: any) :: Sinal
end

-- Conjunto de conexões para desligar tudo de uma vez
function Util.faxina()
	local itens: { any } = {}
	local f = {}
	function f:add(x: any)
		table.insert(itens, x)
		return x
	end
	function f:limpar()
		for i = #itens, 1, -1 do
			local x = itens[i]
			local tipo = typeof(x)
			if tipo == "RBXScriptConnection" then
				x:Disconnect()
			elseif tipo == "Instance" then
				x:Destroy()
			elseif tipo == "function" then
				x()
			elseif tipo == "table" and x.Cancel then
				x:Cancel()
			end
			itens[i] = nil
		end
	end
	return f
end

return Util
