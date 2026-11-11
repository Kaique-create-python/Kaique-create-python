--!nocheck
-- Regressões de carregamento com Theme/Hud/Drawer reais. Sem rede nem renderizador.
-- Lune: require("./media_ui_spec").run() ou lune run tests/lune/media_ui_spec.luau --run
-- VM oficial: luau-run tests/lune/media_ui_spec.luau (a partir da raiz do projeto).

local standalone = type(readfile) == "function"
local readSource, loadSource
if standalone then
	readSource = readfile
	loadSource = function(path, env)
		local chunk = assert(loadstring(readSource(path), path))
		setfenv(chunk, setmetatable(env, { __index = getfenv() }))
		return chunk()
	end
else
	local fs = require("@lune/fs")
	local luau = require("@lune/luau")
	standalone = require("@lune/process").args[1] == "--run"
	readSource = fs.readFile
	loadSource = function(path, env)
		return luau.load(readSource(path), { debugName = path, environment = env })()
	end
end

-- Somente a fronteira do motor é simulada: estados de download, sinais,
-- árvore de instâncias, tipos geométricos e relógio das animações.
local function signal()
	local callbacks = {}
	local s = {}
	function s:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect()
			c.Connected = false
			callbacks[c] = nil
		end
		callbacks[c] = fn
		return c
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function s:snapshot()
		local pending = {}
		for _, fn in callbacks do
			table.insert(pending, fn)
		end
		return function(...)
			for _, fn in pending do
				fn(...)
			end
		end
	end
	function s:Fire(...)
		self:snapshot()(...)
	end
	return s
end

local function enum()
	return setmetatable({}, { __index = function(t, key)
		local value = enum()
		rawset(t, key, value)
		return value
	end })
end

local function udim(scale, offset)
	return { Scale = scale, Offset = offset }
end
local function udim2(xs, xo, ys, yo)
	return { X = udim(xs, xo), Y = udim(ys, yo) }
end
local function color(r, g, b)
	return { R = r, G = g, B = b, Lerp = function(self, other, t)
		return color(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
	end }
end

local function harness(options)
	options = options or {}
	local state = {}
	local methods = {}
	local events = { Destroying = true, Activated = true, MouseEnter = true, MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true, FocusLost = true }
	local function new(class)
		local props = { ClassName = class, Name = class, Visible = true, ZIndex = 1, Text = "", TextTransparency = 0, ImageTransparency = 0, IsLoaded = options.loaded == true }
		local record = { props = props, children = {}, signals = {}, dead = false }
		local obj = setmetatable({}, {
			__index = function(_, key)
				if methods[key] then return methods[key] end
				if events[key] then
					record.signals[key] = record.signals[key] or signal()
					return record.signals[key]
				end
				return props[key]
			end,
			__newindex = function(self, key, value)
				assert(not record.dead, "escrita após Destroy: " .. class .. "." .. key)
				local old = props[key]
				if key == "Parent" then
					if old then table.remove(state[old].children, table.find(state[old].children, self)) end
					if value then table.insert(state[value].children, self) end
				end
				props[key] = value
				if old ~= value and record.signals[key] then record.signals[key]:Fire() end
			end,
		})
		state[obj] = record
		return obj
	end
	function methods:GetChildren() return table.clone(state[self].children) end
	function methods:GetDescendants()
		local result = {}
		for _, child in self:GetChildren() do
			table.insert(result, child)
			for _, descendant in child:GetDescendants() do table.insert(result, descendant) end
		end
		return result
	end
	function methods:FindFirstChild(name)
		for _, child in self:GetChildren() do if child.Name == name then return child end end
		return nil
	end
	function methods:FindFirstChildOfClass(class)
		for _, child in self:GetChildren() do if child.ClassName == class then return child end end
		return nil
	end
	function methods:IsA(class) return self.ClassName == class end
	function methods:GetPropertyChangedSignal(key)
		state[self].signals[key] = state[self].signals[key] or signal()
		return state[self].signals[key]
	end
	function methods:Destroy()
		if state[self].dead then return end
		self.Destroying:Fire()
		for _, child in self:GetChildren() do child:Destroy() end
		self.Parent = nil
		state[self].dead = true
	end
	function methods:Play() end

	local now, jobs = 0, {}
	local function resume(thread, ...)
		local ok, delay = coroutine.resume(thread, ...)
		assert(ok, delay)
		if coroutine.status(thread) ~= "dead" then table.insert(jobs, { at = now + delay, thread = thread }) end
	end
	local tasks = {
		spawn = function(fn, ...) resume(coroutine.create(fn), ...) end,
		wait = function(seconds) return coroutine.yield(seconds or 0) end,
		delay = function(seconds, fn) table.insert(jobs, { at = now + seconds, thread = coroutine.create(fn) }) end,
	}
	local function advance(seconds)
		local target = now + seconds
		for _ = 1, 10000 do
			table.sort(jobs, function(a, b) return a.at < b.at end)
			if not jobs[1] or jobs[1].at > target then now = target; return end
			local job = table.remove(jobs, 1)
			now = job.at
			resume(job.thread)
		end
		error("animação sem avanço do relógio")
	end
	local Shared = { Config = { key = "Config" }, Planner = { key = "Planner" }, Catalog = { key = "Catalog", Progression = { key = "Progression" } } }
	local replicated = { IdeiasShared = Shared, WaitForChild = function(_, name) return assert(name == "IdeiasShared" and Shared) end }
	local tweenService = { Create = function(_, inst, _, goals)
		return { Completed = signal(), Play = function() for key, value in goals do inst[key] = value end end }
	end }
	local services = { TweenService = tweenService, ReplicatedStorage = replicated, Players = { LocalPlayer = {} }, SoundService = new("SoundService"), GuiService = {}, RunService = { RenderStepped = signal() } }
	local client = { Settings = { key = "Settings" } }
	local ui = { Parent = client }
	for _, name in { "Theme", "Hud", "Drawer" } do ui[name] = { key = name, Parent = ui } end
	local config = loadSource("src/shared/Config.luau", {})
	config.UiImages.Icons = if options.icons == nil then 777777 else options.icons
	config.UiImages.Logo = if options.logo == nil then 888888 else options.logo
	local cache = {
		Config = config,
		Settings = { values = { sounds = false, uiScale = 1 }, onChanged = function() end },
		Planner = {},
		Progression = {},
		Catalog = { Concepts = {}, CategoryInfo = {
			creature = { icon = "🐉", label = "Criaturas", order = 1 },
			disaster = { icon = "🌋", label = "Desastres", order = 2 },
			unknown = { icon = "🌍", label = "Mundo", order = 3 },
		} },
	}
	local globals = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		workspace = {}, Instance = { new = new }, Enum = enum(),
		Color3 = { new = color, fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end },
		Font = { new = function(...) return { ... } end }, UDim = { new = udim },
		UDim2 = { new = udim2, fromOffset = function(x, y) return udim2(0, x, 0, y) end, fromScale = function(x, y) return udim2(x, 0, y, 0) end },
		Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		ColorSequence = { new = function(...) return { ... } end }, TweenInfo = { new = function(...) return { ... } end }, task = tasks,
	}
	local function requireModule(ref)
		local name = assert(ref and ref.key, "módulo sem fixture")
		if cache[name] == nil then
			local env = table.clone(globals)
			env.script = assert(ui[name], name)
			env.require = requireModule
			cache[name] = loadSource("src/client/UI/" .. name .. ".luau", env)
		end
		return cache[name]
	end
	local function setLoaded(image, loaded)
		state[image].props.IsLoaded = loaded
		image:GetPropertyChangedSignal("IsLoaded"):Fire()
	end
	return { Theme = requireModule(ui.Theme), Hud = requireModule(ui.Hud), Drawer = requireModule(ui.Drawer), new = new, setLoaded = setLoaded, advance = advance, config = config }
end

local function find(root, predicate)
	for _, descendant in root:GetDescendants() do if predicate(descendant) then return descendant end end
	return nil
end
local function image(root) return assert(find(root, function(x) return x.ClassName == "ImageLabel" end), "imagem ausente") end
local function text(root, value) return find(root, function(x) return x.ClassName == "TextLabel" and x.Text == value end) end
local function visible(obj)
	if not obj then return false end
	local current = obj
	while current do
		if current.Visible == false then return false end
		current = current.Parent
	end
	return obj.TextTransparency ~= 1 and obj.ImageTransparency ~= 1
end
local function size(obj, xs, xo, ys, yo)
	assert(obj.Size.X.Scale == xs and obj.Size.X.Offset == xo and obj.Size.Y.Scale == ys and obj.Size.Y.Offset == yo, "dimensões alteradas")
end
local function tile(h, name, emoji) return h.Theme.tile(name or "ideias", emoji or "💡", 50, h.new("Frame")) end
local function hud(h) return h.Hud.build(h.new("PlayerGui")) end
local function drawer(h)
	local root = h.new("ScreenGui")
	h.Drawer.build(root)
	return root
end

local Spec = {}
function Spec.run()
	local passed, failures = 0, {}
	local function test(name, fn)
		local ok, err = pcall(fn)
		if ok then passed += 1 else table.insert(failures, name .. ": " .. tostring(err)) end
	end
	-- Quebra detectada: existência da instância era confundida com download pronto.
	test("azulejo pendente mostra fallback imediatamente", function()
		local h = harness()
		local root = tile(h)
		assert(visible(text(root, "💡")), "fallback apagado antes do carregamento")
		assert(not visible(image(root)), "arte pendente deve ficar oculta")
	end)
	test("falha permanente mantém alternativa sem timeout bloqueante", function()
		local h = harness()
		local root = tile(h)
		h.advance(60)
		assert(visible(text(root, "💡")) and not visible(image(root)), "falha deixou azulejo vazio")
	end)
	test("sucesso tardio troca fallback pela arte sem mexer no layout", function()
		local h = harness()
		local root = tile(h)
		local art = image(root)
		h.setLoaded(art, true)
		assert(visible(art) and not visible(text(root, "💡")), "fallback não foi substituído")
		size(root, 0, 50, 0, 50)
		size(art, 0, 50, 0, 50)
		assert(art.AnchorPoint.X == 0.5 and art.Position.X.Scale == 0.5 and art.BackgroundTransparency == 1)
		h.setLoaded(art, false)
		assert(visible(text(root, "💡")) and not visible(art), "recarregamento deixou conteúdo vazio")
	end)
	test("imagem em cache já pronta dispensa fallback", function()
		local h = harness({ loaded = true })
		local root = tile(h)
		assert(visible(image(root)) and not visible(text(root, "💡")))
	end)
	test("ID zero e célula desconhecida usam alternativa sem imagem", function()
		for _, options in { { icons = 0 }, {} } do
			local h = harness(options)
			local root = tile(h, if options.icons == 0 then "ideias" else "desconhecido")
			assert(visible(text(root, "💡")))
			assert(not find(root, function(x) return x.ClassName == "ImageLabel" end))
		end
	end)
	test("atlas conserva URI original e os doze recortes de 256 pixels", function()
		local h = harness()
		for _, fixture in {
			{ "ideias", 0, 0 }, { "favoritos", 256, 0 }, { "historico", 512, 0 }, { "progresso", 768, 0 },
			{ "loja", 0, 256 }, { "ajustes", 256, 256 }, { "creature", 512, 256 }, { "disaster", 768, 256 },
			{ "vehicle", 0, 512 }, { "building", 256, 512 }, { "food", 512, 512 }, { "power", 768, 512 },
		} do
			local art = h.Theme.icon(fixture[1], 26, h.new("Frame"))
			assert(art.Image == "rbxassetid://777777", "atlas substituído por miniatura")
			assert(art.ImageRectOffset.X == fixture[2] and art.ImageRectOffset.Y == fixture[3])
			assert(art.ImageRectSize.X == 256 and art.ImageRectSize.Y == 256)
		end
	end)
	test("destruição ignora evento de download que já estava na fila", function()
		local h = harness()
		local root = tile(h)
		local art = image(root)
		local deliver = art:GetPropertyChangedSignal("IsLoaded"):snapshot()
		root:Destroy()
		deliver()
	end)
	test("HUD mantém símbolo enquanto carrega e troca apenas após sucesso", function()
		local h = harness()
		local root = hud(h)
		local bar = root:FindFirstChild("Barra")
		local symbol = assert(text(bar, "💡"), "HUD apagou o símbolo pendente")
		local art = image(bar)
		assert(visible(symbol) and not visible(art))
		h.setLoaded(art, true)
		assert(visible(art) and not visible(symbol))
		size(symbol, 0, 44, 0, 52)
		size(art, 0, 40, 0, 40)
		h.setLoaded(art, false)
		assert(visible(symbol) and not visible(art))
	end)
	test("logo pendente usa título e conserva a duração da abertura", function()
		local h = harness()
		local root = hud(h)
		local splash = assert(root:FindFirstChild("Abertura"))
		assert(visible(text(splash, "IDEIAS SEM LIMITES")), "abertura ficou sem logo nem título")
		assert(not visible(image(splash)))
		h.advance(2.5)
		assert(visible(text(splash, "IDEIAS SEM LIMITES")))
		h.advance(0.9)
		assert(not root:FindFirstChild("Abertura"), "abertura não foi descartada")
	end)
	test("logo tardio mantém miniatura e geometria e descarta observador", function()
		local h = harness()
		local root = hud(h)
		local splash = assert(root:FindFirstChild("Abertura"))
		local art = image(splash)
		assert(art.Image == "rbxthumb://type=Asset&id=888888&w=420&h=420")
		size(art, 0.5, 0, 0.5, 0)
		assert(art.Position.X.Scale == 0.5 and art.Position.Y.Scale == 0.45 and art.BackgroundTransparency == 1)
		h.setLoaded(art, true)
		assert(visible(art) and not visible(text(splash, "IDEIAS SEM LIMITES")))
		local deliver = art:GetPropertyChangedSignal("IsLoaded"):snapshot()
		h.advance(3.4)
		deliver()
	end)
	test("logo sem ID mostra título e não solicita imagem", function()
		local h = harness({ logo = 0 })
		local splash = hud(h):FindFirstChild("Abertura")
		assert(visible(text(splash, "IDEIAS SEM LIMITES")))
		assert(not find(splash, function(x) return x.ClassName == "ImageLabel" end))
	end)
	test("dock esquerdo mantém seis alternativas e nomes até carregar", function()
		local h = harness()
		local dock = drawer(h):FindFirstChild("Dock")
		for _, fixture in { { "ideias", "💡", "Ideias" }, { "historico", "🕘", "Histórico" }, { "favoritos", "⭐", "Favoritos" }, { "progresso", "🏆", "Progresso" }, { "loja", "🛍️", "Loja" }, { "ajustes", "⚙️", "Ajustes" } } do
			local button = assert(dock:FindFirstChild(fixture[1]))
			assert(visible(text(button, fixture[2])), "dock sem alternativa: " .. fixture[1])
			assert(visible(text(button, fixture[3])))
			local art = image(button)
			h.setLoaded(art, true)
			assert(visible(art) and not visible(text(button, fixture[2])))
			size(button, 0, 160, 0, 50)
			size(button:FindFirstChild("Azulejo"), 0, 50, 0, 50)
		end
	end)
	test("categoria conserva emoji pendente e arte alinhada à esquerda", function()
		local h = harness()
		local root = drawer(h)
		h.Drawer.show("ideias")
		local button = assert(find(root, function(x) return x.ClassName == "TextButton" and string.find(x.Text, "Criaturas", 1, true) end))
		assert(button.Text == "🐉 Criaturas", "categoria apagou emoji pendente")
		local art = image(button)
		assert(not visible(art))
		assert(art.AnchorPoint.X == 0 and art.AnchorPoint.Y == 0.5 and art.Position.X.Offset == 6 and art.Position.Y.Scale == 0.5)
		h.setLoaded(art, true)
		assert(visible(art) and button.Text == "     Criaturas")
		h.setLoaded(art, false)
		assert(not visible(art) and button.Text == "🐉 Criaturas")
		size(button, 0, 130, 0, 34)
		local deliver = art:GetPropertyChangedSignal("IsLoaded"):snapshot()
		h.Drawer.show("historico")
		deliver()
	end)
	test("categorias sem ID e sem célula conservam texto completo", function()
		for _, options in { { icons = 0 }, {} } do
			local h = harness(options)
			local root = drawer(h)
			h.Drawer.show("ideias")
			local wanted = if options.icons == 0 then "🐉 Criaturas" else "🌍 Mundo"
			local button = assert(find(root, function(x) return x.ClassName == "TextButton" and x.Text == wanted end))
			assert(not find(button, function(x) return x.ClassName == "ImageLabel" end))
		end
	end)
	for _, failure in failures do print("  FALHOU: " .. failure) end
	print(string.format("  UI de mídias: %d passaram, %d falharam", passed, #failures))
	return { passed = passed, failed = #failures, failures = failures }
end

if standalone then
	local result = Spec.run()
	assert(result.failed == 0, string.format("UI de mídias: %d falhas", result.failed))
end
return Spec
