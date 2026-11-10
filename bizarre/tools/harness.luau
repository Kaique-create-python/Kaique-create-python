-- BIZARRE :: ambiente de teste com Lune (simula o require do Roblox e serviços básicos)
-- Usa @lune/roblox para Instance/Vector3/CFrame reais (propriedades validadas).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local H = {}
H.extras = {} :: { [string]: any }

local RAIZ = "bizarre/src"

-- Árvore virtual de módulos: { Name, Parent, filhos = {}, fonte = string? }
local function novoNo(nome: string, pai: any?)
	local no = { Name = nome, Parent = pai, filhos = {}, ClassName = "Folder" }
	setmetatable(no, {
		__index = function(t, k)
			local f = rawget(t, "filhos")[k]
			if f then
				return f
			end
			if k == "WaitForChild" or k == "FindFirstChild" then
				return function(self, n)
					return rawget(self, "filhos")[n]
				end
			end
			if k == "GetChildren" then
				return function(self)
					local l = {}
					for _, v in rawget(self, "filhos") do
						table.insert(l, v)
					end
					return l
				end
			end
			if k == "IsA" then
				return function(self, c)
					return rawget(self, "ClassName") == c
				end
			end
			if k == "GetFullName" then
				return function(self)
					local p = self
					local partes = {}
					while p do
						table.insert(partes, 1, rawget(p, "Name"))
						p = rawget(p, "Parent")
					end
					return table.concat(partes, ".")
				end
			end
			return nil
		end,
	})
	if pai then
		rawget(pai, "filhos")[nome] = no
	end
	return no
end

local arvore = novoNo("game", nil)

local function carregarPasta(caminho: string, no)
	for _, nome in fs.readDir(caminho) do
		local completo = caminho .. "/" .. nome
		if fs.isDir(completo) then
			local filho = rawget(no, "filhos")[nome] or novoNo(nome, no)
			carregarPasta(completo, filho)
		elseif string.sub(nome, -5) == ".luau" then
			local base = string.gsub(nome, "%.luau$", "")
			local classe = "ModuleScript"
			if string.find(base, "%.server$") then
				classe = "Script"
				base = string.gsub(base, "%.server$", "")
			elseif string.find(base, "%.client$") then
				classe = "LocalScript"
				base = string.gsub(base, "%.client$", "")
			end
			local filho = rawget(no, "filhos")[base] or novoNo(base, no)
			rawset(filho, "fonte", fs.readFile(completo))
			rawset(filho, "ClassName", classe)
			rawset(filho, "caminho", completo)
		end
	end
end

carregarPasta(RAIZ, arvore)
H.arvore = arvore

-- Stubs de serviços com comportamento
local function sinalFalso()
	local s = {}
	function s:Connect(fn)
		return { Disconnect = function() end, Connected = true }
	end
	function s:Once(fn)
		return { Disconnect = function() end }
	end
	function s:Wait()
		return nil
	end
	return s
end
H.sinalFalso = sinalFalso

local TweenServiceFalso = {
	Create = function(_, obj, info, props)
		return {
			Play = function()
				for k, v in props do
					pcall(function()
						obj[k] = v
					end)
				end
			end,
			Cancel = function() end,
			Pause = function() end,
			Completed = sinalFalso(),
		}
	end,
}

local RunServiceFalso = {
	Heartbeat = sinalFalso(),
	RenderStepped = sinalFalso(),
	Stepped = sinalFalso(),
	PreRender = sinalFalso(),
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsStudio = function()
		return false
	end,
	BindToRenderStep = function() end,
	UnbindFromRenderStep = function() end,
}

local dm = roblox.Instance.new("DataModel")
H.dm = dm

local servicosFalsos = {
	TweenService = TweenServiceFalso,
	RunService = RunServiceFalso,
	UserInputService = {
		TouchEnabled = true,
		KeyboardEnabled = false,
		GamepadEnabled = false,
		MouseEnabled = false,
		InputBegan = sinalFalso(),
		InputEnded = sinalFalso(),
		InputChanged = sinalFalso(),
		GetLastInputType = function()
			return roblox.Enum.UserInputType.Touch
		end,
	},
	ContentProvider = { PreloadAsync = function() end },
	HttpService = {
		JSONEncode = function(_, t)
			return "{}"
		end,
		JSONDecode = function()
			return {}
		end,
		GenerateGUID = function()
			return "guid"
		end,
	},
	CollectionService = {
		GetTagged = function()
			return {}
		end,
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
		HasTag = function(_, inst, tag)
			return inst:HasTag(tag)
		end,
	},
	GuiService = { GetGuiInset = function()
		return roblox.Vector2.new(0, 36), roblox.Vector2.new(0, 0)
	end },
	DataStoreService = {},
	SocialService = {},
	TextChatService = {},
}

-- workspace "falso": tempo do servidor e consultas espaciais (força bruta nas peças do filtro)
local wsReal = dm:GetService("Workspace")

local function caixaDe(p)
	local cf, sz = p.CFrame, p.Size / 2
	local r = cf.Rotation
	local ex = math.abs(r.XVector.X) * sz.X + math.abs(r.YVector.X) * sz.Y + math.abs(r.ZVector.X) * sz.Z
	local ey = math.abs(r.XVector.Y) * sz.X + math.abs(r.YVector.Y) * sz.Y + math.abs(r.ZVector.Y) * sz.Z
	local ez = math.abs(r.XVector.Z) * sz.X + math.abs(r.YVector.Z) * sz.Y + math.abs(r.ZVector.Z) * sz.Z
	return cf.Position, roblox.Vector3.new(ex, ey, ez)
end

local function partesDoFiltro(params)
	local l = {}
	if not params or params.FilterType ~= roblox.Enum.RaycastFilterType.Include then
		return l
	end
	for _, raiz in params.FilterDescendantsInstances or {} do
		if raiz:IsA("BasePart") then
			table.insert(l, raiz)
		end
		for _, d in raiz:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(l, d)
			end
		end
	end
	return l
end

local function naCaixa(cf, tam, params)
	local r = {}
	local meia = tam / 2
	for _, p in partesDoFiltro(params) do
		if p.CanQuery ~= false then
			local c, e = caixaDe(p)
			local rel = cf:PointToObjectSpace(c)
			if math.abs(rel.X) <= meia.X + e.X and math.abs(rel.Y) <= meia.Y + e.Y and math.abs(rel.Z) <= meia.Z + e.Z then
				table.insert(r, p)
			end
		end
	end
	return r
end

local function noRaio(centro, raio, params)
	local r = {}
	for _, p in partesDoFiltro(params) do
		if p.CanQuery ~= false then
			local c, e = caixaDe(p)
			local d = c - centro
			local fx = math.max(0, math.abs(d.X) - e.X)
			local fy = math.max(0, math.abs(d.Y) - e.Y)
			local fz = math.max(0, math.abs(d.Z) - e.Z)
			if fx * fx + fy * fy + fz * fz <= raio * raio then
				table.insert(r, p)
			end
		end
	end
	return r
end
local wsProxy = setmetatable({}, {
	__index = function(_, k)
		if k == "GetServerTimeNow" then
			return function()
				return os.clock() + 1000
			end
		elseif k == "GetPartBoundsInBox" then
			return function(_, cf, tam, params)
				return naCaixa(cf, tam, params)
			end
		elseif k == "GetPartBoundsInRadius" then
			return function(_, centro, raio, params)
				return noRaio(centro, raio, params)
			end
		elseif k == "GetPartsInPart" then
			return function()
				return {}
			end
		elseif k == "Raycast" then
			return function()
				return nil
			end
		end
		local v = (wsReal :: any)[k]
		if type(v) == "function" then
			return function(_, ...)
				return v(wsReal, ...)
			end
		end
		return v
	end,
})
H.workspace = wsProxy

local gameFalso = {}
local VIRTUAIS = { ReplicatedStorage = true, ServerScriptService = true, ReplicatedFirst = true, StarterPlayerScripts = true }
function gameFalso:GetService(nome: string)
	if servicosFalsos[nome] then
		return servicosFalsos[nome]
	end
	if VIRTUAIS[nome] and rawget(arvore, "filhos")[nome] then
		return rawget(arvore, "filhos")[nome]
	end
	return dm:GetService(nome)
end
gameFalso.Workspace = wsProxy
H.game = gameFalso
H.servicos = servicosFalsos

-- Random simples (o Lune não tem Random do Roblox)
local RandomFalso = {}
RandomFalso.__index = RandomFalso
function RandomFalso.new(semente: number?)
	local s = (semente or 1) % 2147483647
	if s <= 0 then
		s = s + 2147483646
	end
	return setmetatable({ s = s }, RandomFalso)
end
function RandomFalso:proximo()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function RandomFalso:NextNumber(a: number?, b: number?)
	local x = self:proximo()
	if a and b then
		return a + (b - a) * x
	end
	return x
end
function RandomFalso:NextInteger(a: number, b: number)
	return math.floor(a + (b - a + 1) * self:proximo())
end

local cache = {}
local requireFalso

local function ambiente(no)
	local env = {
		script = no,
		require = function(m)
			return requireFalso(m)
		end,
		game = gameFalso,
		workspace = wsProxy,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Ray = roblox.Ray,
		Font = roblox.Font,
		Enum = roblox.Enum,
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		Random = RandomFalso,
		OverlapParams = { new = function()
			return { FilterDescendantsInstances = {}, MaxParts = 0, FilterType = roblox.Enum.RaycastFilterType.Exclude }
		end },
		RaycastParams = { new = function()
			return { FilterDescendantsInstances = {}, FilterType = roblox.Enum.RaycastFilterType.Exclude }
		end },
		task = task,
		typeof = roblox.typeof or typeof,
		print = print,
		warn = function(...)
			print("[warn]", ...)
		end,
		tick = os.clock,
		time = os.clock,
		os = os,
		math = math,
		string = string,
		table = table,
		utf8 = utf8,
		coroutine = coroutine,
		pcall = pcall,
		xpcall = xpcall,
		error = error,
		assert = assert,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		select = select,
		tostring = tostring,
		tonumber = tonumber,
		type = type,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		unpack = table.unpack,
		buffer = buffer,
		bit32 = bit32,
		debug = debug,
	}
	-- ferramentas (prévia da interface) podem trocar peças do ambiente: Instance, workspace, game...
	for k, v in H.extras do
		env[k] = v
	end
	return env
end

requireFalso = function(no)
	if cache[no] then
		return cache[no]
	end
	local fonte = rawget(no, "fonte")
	assert(fonte, "módulo sem fonte: " .. tostring(rawget(no, "Name")))
	local fn = luau.load(fonte, { debugName = rawget(no, "caminho"), environment = ambiente(no) })
	local resultado = fn()
	cache[no] = resultado
	return resultado
end

H.require = requireFalso

-- carrega uma cópia nova de um módulo (estado zerado), usando as dependências já carregadas
function H.moduloNovo(caminho: string)
	local no = arvore
	for parte in string.gmatch(caminho, "[^/]+") do
		no = rawget(no, "filhos")[parte]
		assert(no, "não achei " .. caminho)
	end
	local fonte = rawget(no, "fonte")
	local fn = luau.load(fonte, { debugName = rawget(no, "caminho"), environment = ambiente(no) })
	return fn()
end

function H.modulo(caminho: string)
	local no = arvore
	for parte in string.gmatch(caminho, "[^/]+") do
		no = rawget(no, "filhos")[parte]
		assert(no, "não achei " .. caminho)
	end
	return requireFalso(no)
end

-- Compila todos os arquivos .luau (só sintaxe)
function H.compilarTudo(): (number, { string })
	local erros = {}
	local total = 0
	local function varrer(caminho)
		for _, nome in fs.readDir(caminho) do
			local completo = caminho .. "/" .. nome
			if fs.isDir(completo) then
				varrer(completo)
			elseif string.sub(nome, -5) == ".luau" then
				total += 1
				local ok, err = pcall(luau.compile, fs.readFile(completo))
				if not ok then
					table.insert(erros, completo .. ": " .. tostring(err))
				end
			end
		end
	end
	varrer(RAIZ)
	return total, erros
end

-- Exporta peças de uma pasta/modelo para JSON (prévia em three.js)
function H.exportarPecas(raiz): { any }
	local lista = {}
	for _, d in raiz:GetDescendants() do
		if d:IsA("BasePart") and (d.Transparency < 0.98 or d:FindFirstChildWhichIsA("Light")) then
			local cf = d.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			local forma = "Block"
			if d:IsA("WedgePart") then
				forma = "Wedge"
			elseif d:IsA("Part") then
				forma = d.Shape.Name
			end
			local malha = d:FindFirstChildOfClass("SpecialMesh")
			local luz = d:FindFirstChildWhichIsA("Light")
			table.insert(lista, {
				n = d.Name,
				f = forma,
				s = { d.Size.X, d.Size.Y, d.Size.Z },
				p = { x, y, z },
				r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				c = { math.floor(d.Color.R * 255), math.floor(d.Color.G * 255), math.floor(d.Color.B * 255) },
				m = d.Material.Name,
				t = d.Transparency,
				ms = if malha then { malha.MeshType.Name, malha.Scale.X, malha.Scale.Y, malha.Scale.Z } else nil,
				l = if luz
					then {
						luz.ClassName,
						math.floor(luz.Color.R * 255),
						math.floor(luz.Color.G * 255),
						math.floor(luz.Color.B * 255),
						luz.Brightness,
						luz.Range,
						if luz:IsA("SpotLight") then luz.Angle else 0,
						if luz:IsA("SpotLight") then luz.Face.Name else "",
						luz.Enabled,
					}
					else nil,
				fogo = d:FindFirstChildOfClass("Fire") ~= nil,
				mv = if d.MaterialVariant ~= "" then d.MaterialVariant else nil,
			})
		end
	end
	return lista
end

-- Exporta os quadros de uma SurfaceGui (rostos desenhados) como comandos de desenho
function H.exportarGui(sg, W: number, Hh: number)
	local cmds = {}
	local function cor(c)
		return { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }
	end
	local function visitar(obj, px, py, pw, ph, clip)
		for _, f in obj:GetChildren() do
			if f:IsA("GuiObject") and f.Visible then
				local w = pw * f.Size.X.Scale + f.Size.X.Offset
				local h = ph * f.Size.Y.Scale + f.Size.Y.Offset
				local x = px + pw * f.Position.X.Scale + f.Position.X.Offset - f.AnchorPoint.X * w
				local y = py + ph * f.Position.Y.Scale + f.Position.Y.Offset - f.AnchorPoint.Y * h
				local canto = f:FindFirstChildOfClass("UICorner")
				local circulo = canto and canto.CornerRadius.Scale >= 0.5
				local traco = f:FindFirstChildOfClass("UIStroke")
				if f.BackgroundTransparency < 1 or traco then
					table.insert(cmds, {
						x = x, y = y, w = w, h = h,
						rot = f.Rotation,
						circ = circulo == true,
						cor = cor(f.BackgroundColor3),
						alfa = 1 - f.BackgroundTransparency,
						traco = if traco then { cor(traco.Color), traco.Thickness } else nil,
						clip = clip,
					})
				end
				local novoClip = clip
				if f.ClipsDescendants then
					novoClip = { x, y, w, h }
				end
				visitar(f, x, y, w, h, novoClip)
			end
		end
	end
	visitar(sg, 0, 0, W, Hh, nil)
	return cmds
end

-- Move um modelo inteiro (sem física no Lune): raiz vai para cf, o resto acompanha
function H.moverModelo(modelo, cf)
	local raiz = modelo.PrimaryPart
	local antigo = raiz.CFrame
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * antigo:Inverse() * d.CFrame
		end
	end
end

-- Exporta os Beams (raios de luz) de uma pasta
function H.exportarBeams(raiz)
	local lista = {}
	for _, b in raiz:GetDescendants() do
		if b:IsA("Beam") and b.Attachment0 and b.Attachment1 then
			local p0 = (b.Attachment0.Parent.CFrame * b.Attachment0.CFrame).Position
			local p1 = (b.Attachment1.Parent.CFrame * b.Attachment1.CFrame).Position
			local cor = b.Color.Keypoints[1].Value
			table.insert(lista, {
				p0 = { p0.X, p0.Y, p0.Z },
				p1 = { p1.X, p1.Y, p1.Z },
				w0 = b.Width0,
				w1 = b.Width1,
				c = { math.floor(cor.R * 255), math.floor(cor.G * 255), math.floor(cor.B * 255) },
				t = b.Transparency.Keypoints[1].Value,
			})
		end
	end
	return lista
end

return H
