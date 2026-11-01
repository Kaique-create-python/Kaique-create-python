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

print(if falhas == 0 then "\nTUDO OK" else ("\nFALHAS: " .. falhas))
if falhas > 0 then
	error("testes falharam")
end
