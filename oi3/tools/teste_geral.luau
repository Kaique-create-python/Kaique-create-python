-- Testes offline (Lune): compila tudo, monta mapa, personagens e cenário do menu
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local falhas = 0
local function checar(nome, fn)
	local ok, err = pcall(fn)
	if ok then
		print("OK   " .. nome)
	else
		falhas += 1
		print("FALHA " .. nome .. ": " .. tostring(err))
	end
end

checar("compilar todos os .luau", function()
	local total, erros = H.compilarTudo()
	for _, e in erros do print("   ", e) end
	assert(#erros == 0, #erros .. " arquivo(s) com erro de sintaxe")
	print("    arquivos:", total)
end)

-- carrega todos os ModuleScripts (só require; não executa iniciar)
checar("require de todos os módulos", function()
	local function varrer(no, caminho)
		for nome, filho in rawget(no, "filhos") do
			local c = caminho .. "/" .. nome
			if rawget(filho, "fonte") and rawget(filho, "ClassName") == "ModuleScript" then
				local ok, err = pcall(H.require, filho)
				assert(ok, c .. ": " .. tostring(err))
			end
			varrer(filho, c)
		end
	end
	varrer(H.arvore, "")
end)

local ws = H.dm:GetService("Workspace")

checar("mapa do orfanato", function()
	local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
	local modelo = Mapa.construir(ws)
	local n = #modelo:GetDescendants()
	assert(n > 800 and n < 2500, "peças fora do esperado: " .. n)
	assert(modelo:FindFirstChild("VidroEspelho", true), "sem vidro do espelho")
	assert(modelo:FindFirstChild("FundoEspelho", true), "sem fundo do espelho")
	print("    instâncias no mapa:", n)
	local P = Mapa.pontos()
	for _, k in { "menino", "nina", "keko", "vo", "espMenino", "spawn", "camExtA" } do
		assert(P[k] ~= nil, "ponto faltando: " .. k)
	end
end)

checar("personagens R6 + rostos + expressões", function()
	local Personagens = H.modulo("ReplicatedStorage/OI3/Personagens")
	for _, cod in { "VO", "KE", "NI", "ME" } do
		local m = Personagens.criar(cod)
		m.Parent = ws
		for _, nome in { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Rosto" } do
			assert(m:FindFirstChild(nome), cod .. " sem " .. nome)
		end
		local juntas = 0
		for _, d in m:GetDescendants() do
			if d:IsA("Motor6D") then juntas += 1 end
		end
		assert(juntas == 6, cod .. " juntas=" .. juntas)
		for nome in Personagens.EXPRESSOES do
			Personagens.expressao(m, nome)
		end
	end
	local c = Personagens.criarCriatura()
	c.Parent = ws
	assert(c.PrimaryPart, "criatura sem raiz")
end)

checar("cenário do menu", function()
	local MenuCena = H.modulo("ReplicatedStorage/OI3/Cliente/MenuCena")
	local pasta = roblox.Instance.new("Folder")
	pasta.Name = "OI3_Menu"
	pasta.Parent = ws
	local refs = MenuCena.construirCenario(pasta)
	assert(refs.vidro and refs.titulo and refs.vela, "refs do menu incompletas")
	print("    peças do menu:", refs.contagem)
	fs.writeFile("oi3/tools/out/menu.json", serde.encode("json", H.exportarPecas(pasta)))
	for _, tela in { { 844, 390 }, { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 390, 844 } } do
		local cf, fov = MenuCena.cameraBase(tela[1], tela[2])
		assert(cf and fov, "sem câmera")
	end
end)

checar("layout dos botões 3D", function()
	local B = H.modulo("ReplicatedStorage/OI3/Cliente/Botoes3D")
	for _, tela in { { 844, 390 }, { 1920, 1080 }, { 1280, 720 }, { 1024, 768 }, { 390, 844 }, { 2400, 1080 } } do
		local fov = if tela[1] / tela[2] >= 1.15 then 52 else 72
		local lay = B.calcularLayout(4, tela[1], tela[2], fov)
		-- altura em pixels de cada botão
		local px = lay.A / (2 * lay.meiaA) * tela[2]
		local wpx = lay.L / (2 * lay.meiaL) * tela[1]
		print(string.format("    tela %dx%d: botão %.0fx%.0f px (%s)", tela[1], tela[2], wpx, px, lay.paisagem and "paisagem" or "retrato"))
		assert(px >= 44, "botão baixo demais para o dedo")
		-- dentro da tela (com margem)
		for _, cf in lay.locais do
			local x, y = cf.Position.X, cf.Position.Y
			assert(math.abs(x) + lay.L / 2 <= lay.meiaL * 1.001, "botão saiu na horizontal")
			assert(math.abs(y) + lay.A / 2 <= lay.meiaA * 1.001, "botão saiu na vertical")
		end
	end
end)

checar("configurações: sanitização", function()
	local Config = H.modulo("ReplicatedStorage/OI3/Config")
	local s = Config.sanitizarConfig({ musica = 5, efeitos = -1, brilho = 9, legendas = "sim", tremor = false, extra = 1 })
	assert(s.musica == 1 and s.efeitos == 0, "volumes não limitados")
	assert(s.brilho == Config.LIMITES.brilhoMax, "brilho não limitado")
	assert(s.legendas == true, "tipo errado aceito")
	assert(s.tremor == false, "valor válido perdido")
	assert(s.extra == nil, "campo estranho aceito")
	local d = Config.sanitizarConfig(nil)
	assert(d.musica == Config.PADRAO.musica, "padrão errado")
end)

checar("falas e mapa de áudio coerentes", function()
	local Dialogos = H.modulo("ReplicatedStorage/OI3/Dialogos")
	local AudioMapa = H.modulo("ReplicatedStorage/OI3/AudioMapa")
	for id, it in AudioMapa.itens do
		assert(type(it.inicio) == "number" and type(it.dur) == "number" and it.dur > 0, "item ruim " .. id)
		assert(table.find(AudioMapa.arquivos, it.arquivo), "arquivo desconhecido em " .. id)
	end
	for id, f in Dialogos.FALAS do
		assert(Dialogos.FALANTES[f.quem], "falante desconhecido em " .. id)
	end
end)

checar("áreas de toque dos botões (projeção na tela)", function()
	local B = H.modulo("ReplicatedStorage/OI3/Cliente/Botoes3D")
	local MenuCena = H.modulo("ReplicatedStorage/OI3/Cliente/MenuCena")
	local CF = roblox.CFrame
	local RGB = roblox.Color3.fromRGB
	for _, tela in { { 844, 390 }, { 1280, 720 }, { 2400, 1080 }, { 390, 844 } } do
		local W, Hh = tela[1], tela[2]
		local cam, fov = MenuCena.cameraBase(W, Hh)
		local lay = B.calcularLayout(4, W, Hh, fov)
		local tg = math.tan(math.rad(fov) / 2)
		local function projetar(p)
			local q = cam:PointToObjectSpace(p)
			assert(q.Z < 0, "ponto atrás da câmera")
			local x = (q.X / -q.Z) / (tg * W / Hh)
			local y = (q.Y / -q.Z) / tg
			return (x + 1) / 2 * W, (1 - y) / 2 * Hh
		end
		local rets = {}
		for i = 1, 4 do
			local pecas = B.montarPecas({ id = "t" .. i, texto = "T", cor = RGB(100, 30, 30), aoClicar = function() end }, lay.L, lay.A)
			local cf = cam * lay.locais[i] * CF.new(0, 0, pecas.frente)
			local mx, my = lay.L / 2 + lay.A * 0.08, lay.A / 2 + lay.A * 0.08
			local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
			for _, c in { CF.new(-mx, 0, 0), CF.new(mx, 0, 0), CF.new(0, my, 0), CF.new(0, -my, 0) } do
				local px, py = projetar((cf * c).Position)
				x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
			end
			assert(x0 >= -1 and y0 >= -1 and x1 <= W + 1 and y1 <= Hh + 1, "área fora da tela")
			assert(y1 - y0 >= 44, "área de toque baixa demais: " .. (y1 - y0))
			rets[i] = { x0, y0, x1, y1 }
			pecas.modelo:Destroy()
		end
		for i = 1, 3 do
			local a, b = rets[i], rets[i + 1]
			local sobrepoe = math.max(0, math.min(a[4], b[4]) - math.max(a[2], b[2]))
			assert(sobrepoe <= 2, string.format("botões %d e %d se sobrepõem %.0f px", i, i + 1, sobrepoe))
		end
		print(string.format("    %dx%d: JOGAR em x=%.0f..%.0f y=%.0f..%.0f", W, Hh, rets[1][1], rets[1][3], rets[1][2], rets[1][4]))
	end
end)

checar("lanterna da primeira pessoa (peças)", function()
	local PP = H.modulo("ReplicatedStorage/OI3/Cliente/PrimeiraPessoa")
	local m, lente = PP.montarLanterna(roblox.Color3.fromRGB(200, 160, 130))
	assert(m.PrimaryPart and lente, "lanterna incompleta")
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			assert(d.CanCollide == false and d.CastShadow == false, "peça da lanterna com colisão/sombra: " .. d.Name)
		end
	end
	print("    peças da lanterna:", n)
end)

checar("detalhes novos (efeitos marcados)", function()
	local ws2 = roblox.Instance.new("Folder")
	local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
	local modelo = Mapa.construir(ws2)
	local fx, fogo, luzes, sombras = 0, 0, 0, 0
	for _, d in modelo:GetDescendants() do
		if (d:IsA("ParticleEmitter") or d:IsA("Beam")) then
			assert(d:GetAttribute("OI3_FX"), "efeito sem marca: " .. d:GetFullName())
			fx += 1
		elseif d:IsA("Fire") then
			fogo += 1
		elseif d:IsA("Light") then
			luzes += 1
			if d.Shadows then
				sombras += 1
			end
		end
	end
	print(string.format("    efeitos: %d, fogo: %d, luzes: %d (com sombra: %d)", fx, fogo, luzes, sombras))
	assert(sombras <= 8, "luzes com sombra demais para celular")
end)

print(if falhas == 0 then "\nTUDO OK" else ("\nFALHAS: " .. falhas))
if falhas > 0 then
	error("testes falharam")
end
