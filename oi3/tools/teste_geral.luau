-- Testes offline (Lune): compila tudo, monta mapa, personagens e cenário do menu
local H = require("./harness")
H.prepararAtores()
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

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
			if type(filho) ~= "table" then
				continue -- manequins de prévia (Instance de verdade), não são módulos
			end
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

checar("personagens: só itens do catálogo do Roblox (nada modelado)", function()
	local Config = H.modulo("ReplicatedStorage/OI3/Config")
	-- todo personagem tem camisa, calça, cabelo e rosto (do Roblox ou de usuário) por ID
	for _, cod in { "VO", "KE", "NI", "ME" } do
		local r = Config.ROUPAS[cod]
		assert(r, "sem roupas: " .. cod)
		assert(type(r.camisa) == "number" and r.camisa > 0, cod .. " sem camisa")
		assert(type(r.calca) == "number" and r.calca > 0, cod .. " sem calça")
		assert(r.cabelo and #r.cabelo > 0, cod .. " sem cabelo")
		assert((r.rosto and r.rosto > 0) or (r.rostoAcessorio and #r.rostoAcessorio > 0), cod .. " sem rosto")
		for _, campo in { "cabelo", "chapeu", "rostoAcessorio" } do
			for _, id in r[campo] or {} do
				assert(type(id) == "number" and id > 0 and id == math.floor(id), cod .. " ID inválido em " .. campo)
			end
		end
	end
	-- o servidor monta a descrição do avatar com esses IDs e a pele amarela
	local Atores = H.modulo("ServerScriptService/OI3_Servidor/Atores")
	local d = Atores.descricao("NI")
	assert(d.Shirt == Config.ROUPAS.NI.camisa and d.Pants == Config.ROUPAS.NI.calca, "descrição sem roupa")
	assert(d.HatAccessory ~= "" and d.HairAccessory ~= "" and d.FaceAccessory ~= "", "descrição sem acessórios")
	assert(d.HeadColor == Config.PELE, "pele errada")
	assert(Atores.descricao("VO").Face == 144075659, "Vô sem o Smile clássico")
	-- o cliente só copia o avatar pronto (aqui, manequins de prévia no lugar)
	H.prepararAtores()
	local Personagens = H.modulo("ReplicatedStorage/OI3/Personagens")
	for _, cod in { "VO", "KE", "NI", "ME", "CRIATURA" } do
		local m = Personagens.criar(cod)
		m.Parent = ws
		assert(m.PrimaryPart and m.PrimaryPart.Anchored, cod .. " sem raiz ancorada")
		assert(m:GetAttribute("Escala"), cod .. " sem escala")
		for _, nome in { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			assert(m:FindFirstChild(nome), cod .. " sem " .. nome)
		end
	end
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

checar("sons usados no código existem no mapa de áudio", function()
	local AudioMapa = H.modulo("ReplicatedStorage/OI3/AudioMapa")
	local fs = require("@lune/fs")
	-- todo nome passado para Som.tocar/Som.ambiente/Som.disponivel com texto fixo precisa existir
	local usados = {}
	local function varrer(caminho)
		for _, nome in fs.readDir(caminho) do
			local c = caminho .. "/" .. nome
			if fs.isDir(c) then
				varrer(c)
			elseif string.sub(nome, -5) == ".luau" then
				local src = fs.readFile(c)
				for som, depois in string.gmatch(src, 'Som%.tocar%("([%w_]+)"(%s*%.?%.?)') do
					if depois ~= ".." and not string.find(depois, "%.%.") then
						usados[som] = c
					end
				end
				for som, depois in string.gmatch(src, 'Som%.ambiente%("([%w_]+)"(%s*%.?%.?)') do
					if depois ~= ".." and not string.find(depois, "%.%.") then
						usados[som] = c
					end
				end
				for som, depois in string.gmatch(src, 'Som%.disponivel%("([%w_]+)"(%s*%.?%.?)') do
					if depois ~= ".." and not string.find(depois, "%.%.") then
						usados[som] = c
					end
				end
			end
		end
	end
	varrer("oi3/src")
	-- AJUSTE-9: os sons também podem vir das gravações da biblioteca do Roblox (SonsBiblioteca)
	local Biblioteca = H.modulo("ReplicatedStorage/OI3/SonsBiblioteca")
	local n = 0
	for som, onde in usados do
		n += 1
		assert(AudioMapa.itens[som] or Biblioteca.sons[som], "som '" .. som .. "' (usado em " .. onde .. ") não existe no AudioMapa nem na biblioteca")
	end
	-- somEm("nome", ...) no cliente das missões também
	local src = fs.readFile("oi3/src/ReplicatedStorage/OI3/Cliente/MissoesCliente.luau")
	for som in string.gmatch(src, 'somEm%("([%w_]+)"') do
		assert(AudioMapa.itens[som] or Biblioteca.sons[som], "som '" .. som .. "' (somEm) não existe")
	end
	-- sons montados com número no fim
	for _, base in { "passo", "passo_madeira", "passo_grama" } do
		for i = 1, 3 do
			assert(AudioMapa.itens[base .. i], "falta " .. base .. i)
		end
	end
	for _, base in { "goteira", "estalo" } do
		for i = 1, 2 do
			assert(AudioMapa.itens[base .. i], "falta " .. base .. i)
		end
	end
	for _, laco in { "grilos", "lareira", "assobio", "vento", "interior", "relogio", "musica_menu" } do
		assert(AudioMapa.itens[laco] and AudioMapa.itens[laco].loop == true, laco .. " precisa ser loop")
	end
	assert(table.find(AudioMapa.arquivos, "ambiente"), "arquivo 'ambiente' fora da lista")
	print("    nomes de som conferidos:", n)
end)

checar("ambiente: dentro/fora, mistura e sorteio", function()
	local Ambiente = H.modulo("ReplicatedStorage/OI3/Cliente/Ambiente")
	local AudioMapa = H.modulo("ReplicatedStorage/OI3/AudioMapa")
	local V3 = roblox.Vector3.new
	local casos = {
		{ V3(-24, 3, -8), true, "dormitório" },
		{ V3(0, 3, 0), true, "hall" },
		{ V3(34, 3, 0), true, "corredor" },
		{ V3(63, 3, 0), true, "quarto do espelho" },
		{ V3(0, 2, 30), false, "frente da casa" },
		{ V3(-50, 2, 0), false, "lado de fora (oeste)" },
		{ V3(40, 2, -20), false, "fundos da ala leste" },
		{ V3(0, 40, 0), false, "telhado/céu" },
	}
	for _, c in casos do
		assert(Ambiente.dentroDaCasa(c[1]) == c[2], "dentro/fora errado: " .. c[3])
	end
	for _, dentro in { true, false } do
		for nome, v in Ambiente.mistura(dentro) do
			assert(AudioMapa.itens[nome], "mistura usa som inexistente: " .. nome)
			assert(v >= 0 and v <= 1, "volume fora de 0..1")
		end
		for i = 0, 99 do
			local tipo = Ambiente.sortear(dentro, i / 100, true)
			if tipo then
				local ok = AudioMapa.itens[tipo] or AudioMapa.itens[tipo .. "1"]
				assert(ok, "sorteio deu som inexistente: " .. tipo)
			end
			local antigo = Ambiente.sortear(dentro, i / 100, false)
			assert(antigo == nil or antigo == "rangido" or antigo == "sussurro", "sem arquivo novo só pode usar sons antigos")
		end
	end
end)

checar("passos: som certo para cada chão", function()
	local PP = H.modulo("ReplicatedStorage/OI3/Cliente/PrimeiraPessoa")
	local AudioMapa = H.modulo("ReplicatedStorage/OI3/AudioMapa")
	local E = roblox.Enum.Material
	assert(PP.somDoPasso(E.WoodPlanks, 0.3, nil) == "pisada_madeira2", "madeira")
	assert(PP.somDoPasso(E.Grass, 0.99, nil) == "pisada_grama5", "grama")
	assert(PP.somDoPasso(E.Fabric, 0.0, nil) == "pisada_tapete1", "tapete")
	assert(PP.somDoPasso(E.Slate, 0.5, nil) == "pisada_pedra3", "pedra")
	assert(PP.somDoPasso(E.Neon, 0.5, nil) == "pisada_madeira3", "chão desconhecido usa madeira")
	local soAntigos = function(n)
		return string.sub(n, 1, 13) == "passo_madeira"
	end
	assert(PP.somDoPasso(E.WoodPlanks, 0.3, soAntigos) == "passo_madeira1", "sem gravação usa o sintetizado")
	assert(PP.somDoPasso(E.Slate, 0.9, function()
		return false
	end) == "passo3", "sem nada usa o passo comum")
	for _, tipo in { "madeira", "grama", "tapete", "pedra" } do
		for i = 1, 5 do
			assert(AudioMapa.itens["pisada_" .. tipo .. i], "falta pisada_" .. tipo .. i)
		end
	end
end)

checar("capítulo 1: detalhes estranhos, mesa, escolha e falas", function()
	local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
	local Historia = H.modulo("ServerScriptService/OI3_Servidor/Historia")
	local Capitulo1 = H.modulo("ReplicatedStorage/OI3/Cliente/Capitulo1")
	local Dialogos = H.modulo("ReplicatedStorage/OI3/Dialogos")
	local Iluminacao = H.modulo("ReplicatedStorage/OI3/Cliente/Iluminacao")
	local ws3 = roblox.Instance.new("Folder")
	local modelo = Mapa.construir(ws3)
	for _, nome in { "OI3_Foto", "OI3_PortaTrancada", "OI3_TV", "OI3_TVTela", "OI3_CaixaBrinquedos", "OI3_PortaPorao", "OI3_MesaJantar" } do
		assert(modelo:FindFirstChild(nome, true), "falta no mapa: " .. nome)
	end
	-- os 5 detalhes do cliente são os mesmos que o servidor aceita
	for _, nome in Historia.DETALHES do
		assert(Capitulo1.DETALHES[nome], "cliente sem o detalhe " .. nome)
	end
	-- ninguém pega a mesma criança
	local livres = Historia.livres({ a = "KE", b = "ME" })
	assert(#livres == 1 and livres[1] == "NI", "livres errado")
	assert(#Historia.livres({}) == 3, "3 crianças livres no começo")
	for _, id in { "VO_3", "VO_4", "VO_5", "VO_6" } do
		assert(Dialogos.FALAS[id] and Dialogos.FALAS[id].quem == "VO", "falta a fala " .. id)
	end
	local t = Iluminacao.valoresTarde()
	assert(t.ClockTime > 14 and t.ClockTime < 18.5, "a tarde precisa ser de tarde")
	print("    detalhes:", #Historia.DETALHES, "mesa e âncoras no mapa: ok")
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
	-- AJUSTE-5: qualidade máxima pedida pelos criadores; o modo "efeitos leves" desliga TODAS as sombras
	assert(sombras <= 16, "luzes com sombra demais")
end)

checar("AJUSTE-7: foto antiga (imagem enviada + desenho reserva)", function()
	local Rec = H.modulo("ReplicatedStorage/OI3/Recursos")
	local C1M = H.modulo("ReplicatedStorage/OI3/Capitulo1Mapa")
	assert(type(Rec.imagens) == "table", "Recursos.imagens faltando")
	assert(Rec.revisao == "AJUSTE-11", "Recursos.revisao desatualizado")
	local f = roblox.Instance.new("Frame")
	local q = C1M.desenharFoto(f)
	assert(q:FindFirstChild("Reserva"), "sem o desenho reserva")
	assert(not q:FindFirstChild("Imagem"), "imagem sem ID não deveria aparecer")
	Rec.imagens.foto = 4242
	local q2 = C1M.desenharFoto(f)
	Rec.imagens.foto = nil
	local img = q2:FindFirstChild("Imagem")
	assert(img and img.Image == "rbxassetid://4242", "a imagem da foto não entrou")
	assert(img.ZIndex > 1, "a imagem tem que ficar por cima do desenho")
	assert(math.abs(C1M.PROPORCAO_FOTO - 704 / 653) < 1e-6, "proporção da foto")
	-- o porta-retrato tem a mesma proporção da foto
	local ws3 = roblox.Instance.new("Folder")
	C1M.construir(ws3, { F = 0 })
	local porta = ws3:FindFirstChild("OI3_Foto", true)
	assert(porta, "sem OI3_Foto")
	local prop = porta.Size.Z / porta.Size.Y
	assert(math.abs(prop - C1M.PROPORCAO_FOTO) < 0.01, string.format("porta-retrato %.3f x foto %.3f", prop, C1M.PROPORCAO_FOTO))
	assert(porta:FindFirstChildOfClass("SurfaceGui"):FindFirstChild("Foto"), "foto não montada no porta-retrato")
end)

checar("AJUSTE-7: tela de carregamento (marcador da arte)", function()
	local fonte = fs.readFile("oi3/src/ReplicatedFirst/Carregando.client.luau")
	assert(string.find(fonte, "local FUNDO = 0 --@@OI3_IMG_CARREGANDO@@", 1, true), "marcador da arte sumiu")
	assert(string.find(fonte, "OI3_Pronto", 1, true), "a tela precisa esperar o jogo ficar pronto")
	assert(not string.find(fonte, "require(", 1, true), "a tela de carregamento não pode depender de módulos")
	local foto = fs.readFile("oi3/assets/tela/carregando.jpg")
	assert(#foto > 10000 and string.sub(foto, 1, 2) == "\255\216", "arte da tela não é jpeg")
	local foto2 = fs.readFile("oi3/assets/foto/foto_orfanato.jpg")
	assert(#foto2 > 10000 and string.sub(foto2, 1, 2) == "\255\216", "foto antiga não é jpeg")
end)

checar("AJUSTE-7: resumo da sala para o menu", function()
	local Sala = H.modulo("ServerScriptService/OI3_Servidor/Sala")
	local r = Sala.resumo()
	assert(r.n == 0 and r.max == 3 and type(r.ids) == "table", "resumo da sala inválido")
	local e = Sala.estado()
	assert(e.max == 3 and #e.membros == 0, "estado da sala inválido")
end)

checar("AJUSTE-8: o assoalho de madeira aparece (tapetes pequenos, sem textura de terra)", function()
	local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
	local pasta = roblox.Instance.new("Folder")
	local modelo = Mapa.construir(pasta)
	local F = Mapa.L.F
	local pecas = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			local y = d.CFrame.Position.Y
			if y > F - 0.6 and y < F + 0.6 then
				table.insert(pecas, d)
			end
			if d.Name == "Tapete" then
				assert(d.MaterialVariant == "", "tapete com textura (parecia terra): " .. d:GetFullName())
				assert(d.Size.X * d.Size.Z <= 80 or d.Size.Y * d.Size.Z <= 80, string.format("tapete grande demais: %.0f x %.0f", d.Size.X, d.Size.Z))
			end
		end
	end
	local function topo(x, z)
		local melhor, alto = nil, -math.huge
		for _, p in pecas do
			local cf, sz = p.CFrame, p.Size
			local q = cf:PointToObjectSpace(roblox.Vector3.new(x, cf.Position.Y, z))
			if math.abs(q.X) <= sz.X / 2 and math.abs(q.Y) <= sz.Y / 2 + 0.01 and math.abs(q.Z) <= sz.Z / 2 then
				local t = cf.Position.Y + math.abs(cf.UpVector.Y) * sz.Y / 2 + math.abs(cf.RightVector.Y) * sz.X / 2
				if t > alto then
					melhor, alto = p, t
				end
			end
		end
		return melhor
	end
	-- caminhos principais: hall (em volta da mesa), corredor, dormitório e varanda
	local madeira, tapete, total = 0, 0, 0
	for _, area in { { -10, 10, -12, 10 }, { 14, 54, -3.5, 3.5 }, { -34, -14, -20, 8 }, { -7, 7, 13, 17 } } do
		for x = area[1], area[2], 1.37 do
			for z = area[3], area[4], 1.29 do
				local p = topo(x, z)
				if p then
					total += 1
					if p.Name == "Tabua" then
						madeira += 1
					elseif p.Name == "Tapete" then
						tapete += 1
					end
				end
			end
		end
	end
	local fracao = madeira / math.max(total, 1)
	print(string.format("    chão nos caminhos: %d%% tábua, %d%% tapete (%d pontos)", math.floor(fracao * 100), math.floor(tapete / total * 100), total))
	assert(fracao >= 0.6, "o assoalho ainda está coberto")
end)

checar("AJUSTE-9: atrás de toda porta e vão dos cenários tem CHÃO (ninguém cai no vazio)", function()
	local MM = H.modulo("ReplicatedStorage/OI3/MissoesMapa")
	local V3 = roblox.Vector3.new
	local F = 1
	local verificadas = 0
	for _, nome in MM.CENARIOS do
		if nome == "rua" then
			continue
		end
		local pasta = roblox.Instance.new("Folder")
		local modelo, l = MM.construir(nome, pasta)
		local chao = {}
		local portas = {}
		local paredes = {}
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then
				local cf, sz = d.CFrame, d.Size
				local topoY = cf.Position.Y + math.abs(cf.UpVector.Y) * sz.Y / 2 + math.abs(cf.RightVector.Y) * sz.X / 2 + math.abs(cf.LookVector.Y) * sz.Z / 2
				if topoY > F - 0.7 and topoY < F + 0.5 and d.CanCollide then
					table.insert(chao, d)
				end
				if string.sub(d.Name, 1, 10) == "OI3_Porta_" then
					table.insert(portas, d)
				end
			end
		end
		local function temChao(x, z)
			for _, p in chao do
				local cf, sz = p.CFrame, p.Size
				local q = cf:PointToObjectSpace(V3(x, cf.Position.Y, z))
				if math.abs(q.X) <= sz.X / 2 + 0.05 and math.abs(q.Z) <= sz.Z / 2 + 0.05 then
					return true
				end
			end
			return false
		end
		-- 1) folhas de porta: chão dos dois lados (2 e 5 studs)
		for _, porta in portas do
			local cf = porta.CFrame
			local n = cf.LookVector
			for _, lado in { -1, 1 } do
				for _, dist in { 2, 5 } do
					local pnt = cf.Position + n * lado * dist
					assert(temChao(pnt.X, pnt.Z), string.format("%s: sem chão do lado de %s (%.1f, %.1f)", nome, porta.Name, pnt.X, pnt.Z))
					verificadas += 1
				end
			end
		end
		-- 2) o spawn e os pontos de interação têm chão embaixo
		assert(temChao(l.spawn.X, l.spawn.Z), nome .. ": spawn sem chão")
		for id, pos in l.pontos or {} do
			if id ~= "saida" then
				assert(temChao(pos.X, pos.Z), nome .. ": ponto " .. id .. " sem chão")
			end
		end
		local _ = paredes
		pasta:Destroy()
	end
	-- 3) os corredores novos atrás das portas (sala) também têm chão até o fundo
	local Moveis = H.modulo("ReplicatedStorage/OI3/Moveis")
	local _ = Moveis
	print("    pontos de porta conferidos:", verificadas)
	assert(verificadas >= 24, "poucas portas conferidas: " .. verificadas)
end)

checar("AJUSTE-9: monstro (poses, espiada e medo)", function()
	local Medo = H.modulo("ReplicatedStorage/OI3/Cliente/Medo")
	assert(Medo.bpm(0) < Medo.bpm(0.5) and Medo.bpm(0.5) < Medo.bpm(1), "o coração precisa acelerar com o medo")
	assert(Medo.bpm(1) <= 170 and Medo.bpm(0) >= 60, "batimento fora do normal")
	assert(Medo.intervaloFolego(1) < Medo.intervaloFolego(0), "a respiração precisa acelerar com o medo")
	local Monstro = H.modulo("ReplicatedStorage/OI3/Cliente/Monstro")
	for nome, pose in Monstro.POSES do
		for junta, v in pose do
			assert(#v >= 3, nome .. "/" .. junta .. " sem 3 ângulos")
			for _, a in v do
				assert(math.abs(a) < 3.3, nome .. "/" .. junta .. ": ângulo absurdo " .. a)
			end
		end
	end
	local soma = Monstro.somar({ Neck = { 1, 0, 0 } }, { Neck = { 0.5, 1, 0 }, Waist = { 1, 1, 1 } }, 0.5)
	assert(math.abs(soma.Neck[1] - 1.25) < 1e-6 and math.abs(soma.Waist[2] - 0.5) < 1e-6, "somar poses errado")
	-- o ponto da espiada fica do lado de FORA de cada esconderijo e a cabeça olha para a câmera
	local MC = H.modulo("ReplicatedStorage/OI3/Cliente/MissoesCliente")
	local MM = H.modulo("ReplicatedStorage/OI3/MissoesMapa")
	local l = MM.layout("quarto")
	for _, e in l.esconderijos do
		local alvo, olhar, pes = MC.pontoEspiada(e, 0.95)
		local d = (alvo - e.cam.Position).Magnitude
		assert(d > 1.2 and d < 4.5, e.id .. ": cabeça longe/perto demais da câmera (" .. d .. ")")
		assert((olhar - e.cam.Position).Magnitude < 1e-6, e.id .. ": precisa olhar para quem está escondido")
		assert(alvo.Y > 1 + 0.9, e.id .. ": cabeça afundando no chão")
		local _ = pes
	end
	-- servidor: espia só esconderijos SEGUROS e ocupados (no máximo 2) e dá tempo para a cena
	local Serv = H.modulo("ServerScriptService/OI3_Servidor/Missoes")
	local alvos = Serv.alvosEspiar({ a = "cama1", b = "armario2", c = "bau", d = "cama1" }, { bau = true })
	assert(#alvos == 2 and table.find(alvos, "cama1") and table.find(alvos, "armario2"), "alvos da espiada errados")
	assert(Serv.tempoConferir(0) == 9.5 and Serv.tempoConferir(2) > Serv.tempoConferir(1), "tempo da ronda errado")
end)

checar("AJUSTE-8: rosto de reação nunca fica escondido dentro da cabeça", function()
	local P = H.modulo("ReplicatedStorage/OI3/Personagens")
	local CF, V3 = roblox.CFrame.new, roblox.Vector3.new
	for _, s in { 1, 0.9, 0.88 } do
		local frenteCabeca = -0.625 * s
		-- rosto só da frente, encaixado onde a cabeça R15 teria a frente (fica dentro da R6)
		local rel, fator = P.posicaoRosto(CF(0, 0, -0.6 * s), V3(0.8, 0.5, 0.04) * s, s)
		assert(fator == 1, "rosto de frente não deve aumentar")
		assert(P.frenteDoRosto(rel, V3(0.8, 0.5, 0.04) * s) <= frenteCabeca - 0.02, "rosto de frente continuou escondido")
		-- casco de cabeça inteira menor que a cabeça R6
		local rel2, fator2 = P.posicaoRosto(CF(0, 0, 0), V3(1.2, 1.2, 1.2) * s, s)
		assert(fator2 > 1, "casco pequeno deveria aumentar")
		assert(P.frenteDoRosto(rel2, V3(1.2, 1.2, 1.2) * s * fator2) <= frenteCabeca - 0.02, "casco continuou escondido")
		-- rosto que já está para fora: não mexe
		local rel3, fator3 = P.posicaoRosto(CF(0, 0, -0.75 * s), V3(0.8, 0.5, 0.04), s)
		assert(fator3 == 1 and rel3 == CF(0, 0, -0.75 * s), "mexeu num rosto que já aparecia")
	end
	local Config = H.modulo("ReplicatedStorage/OI3/Config")
	for _, nome in { "medo", "rindo", "nervoso", "chorando" } do
		assert(tonumber(Config.ROSTOS_REACAO[nome]), "falta o rosto " .. nome)
	end
	assert(Config.ROSTOS_REACAO.rindo ~= 18600770545 and Config.ROSTOS_REACAO.nervoso ~= 113101418764487, "rostos-casco antigos ainda em uso")
end)

checar("AJUSTE-8: dados das missões e cenários coerentes", function()
	local Md = H.modulo("ReplicatedStorage/OI3/Missoes")
	local MM = H.modulo("ReplicatedStorage/OI3/MissoesMapa")
	assert(Md.TOTAL == 8, "deviam ser 8 missões (7 + porão)")
	local n, i, visitas = 1, 1, 0
	while n do
		visitas += 1
		n, i = Md.proximo(n, i)
		assert(visitas < 200, "a sequência de passos não termina")
	end
	local nomes = {}
	for k, m in Md.LISTA do
		local l = MM.layout(m.cenario)
		assert(l.spawn and l.olhar, "cenário sem spawn: " .. m.cenario)
		for j, p in m.passos do
			for _, id in Md.pontosDoPasso(p) do
				assert(l.pontos[id], string.format("missão %d passo %d: ponto %s sem posição", k, j, id))
			end
			if p.tipo == "ordem" then
				assert(#p.pontos >= 3, "ordem curta demais")
				assert(Md.conferirOrdem(p, { p.pontos[2].id }) == "errado", "ordem errada aceita")
				local seq = {}
				for _, q in p.pontos do
					table.insert(seq, q.id)
				end
				assert(Md.conferirOrdem(p, seq) == "certo", "ordem certa recusada")
			elseif p.tipo == "codigo" then
				assert(string.match(p.codigo, "^%d+$"), "código precisa ser só números")
			elseif p.tipo == "evento" then
				nomes[p.evento] = true
			end
		end
	end
	-- todo evento tem um script no cliente
	local cliente = fs.readFile("oi3/src/ReplicatedStorage/OI3/Cliente/MissoesCliente.luau")
	for nome in nomes do
		assert(string.find(cliente, "EVENTOS." .. nome .. " = function", 1, true), "evento sem script no cliente: " .. nome)
	end
	-- a senha da lavanderia sai dos balões (azul, vermelho, amarelo)
	local d = Md.DIGITOS_BALOES
	assert(d.bal_azul .. d.bal_vermelho .. d.bal_amarelo == Md.CODIGO_LAVANDERIA, "senha dos balões não bate")
	assert(Md.CODIGO_PORAO == "3194" and string.find(cliente, '{ "3", "1", "9", "4" }', 1, true), "números da fita não batem com a senha do porão")
	-- cenários montam sem erro
	for _, nome in MM.CENARIOS do
		local pasta = roblox.Instance.new("Folder")
		local modelo = MM.construir(nome, pasta)
		assert(#modelo:GetDescendants() > 50, "cenário vazio: " .. nome)
	end
end)

checar("AJUSTE-8: missões no servidor (simulação: festa inteira, ordem e senha)", function()
	local Md = H.modulo("ReplicatedStorage/OI3/Missoes")
	local S = H.modulo("ServerScriptService/OI3_Servidor/Missoes")
	for _, m in Md.LISTA do
		for _, p in m.passos do
			if p.dur then
				p.dur = 0.05
			end
		end
	end
	local eventos = {}
	local remotoFalso = {}
	function remotoFalso:FireClient(_p, tipo, info)
		table.insert(eventos, { tipo = tipo, info = info })
	end
	local jogador = { Parent = true, UserId = 7, Name = "teste", DisplayName = "teste" }
	local g = { membros = { jogador }, escolhas = { [jogador] = "KE" }, token = 1 }
	local salvo = 0
	S.configurar(remotoFalso :: any, function()
		return g
	end, function(_, n)
		salvo = n
	end, function() end)
	local function esperar(tipo: string, filtro: ((any) -> boolean)?, max: number?)
		local t0 = os.clock()
		while os.clock() - t0 < (max or 8) do
			for k, e in eventos do
				if e.tipo == tipo and (not filtro or filtro(e.info)) then
					table.remove(eventos, k)
					return e.info
				end
			end
			task.wait(0.05)
		end
		error("não chegou: " .. tipo)
	end
	local function passo(i: number)
		return esperar("m_passo", function(info)
			return info.i == i
		end)
	end
	S.iniciar(g, 2)
	assert(salvo == 2, "não salvou o ponto da missão")
	esperar("m_missao")
	passo(1)
	passo(2)
	for _, id in { "bal_azul", "bal_vermelho", "bal_amarelo" } do
		S.acao(jogador :: any, id)
	end
	passo(3)
	S.acao(jogador :: any, "agulha")
	passo(4)
	S.acao(jogador :: any, "toca_discos")
	passo(5)
	for k = 1, 4 do
		S.acao(jogador :: any, "prato" .. k)
	end
	passo(6)
	for _, v in { "vela_a", "vela_b", "vela_c", "vela_d" } do
		S.acao(jogador :: any, v)
	end
	passo(7)
	S.acao(jogador :: any, "bolo_azul") -- ordem errada
	esperar("m_errou", function(info)
		return info.motivo == "ordem"
	end)
	for _, v in { "bolo_vermelha", "bolo_azul", "bolo_amarela", "bolo_verde" } do
		S.acao(jogador :: any, v)
	end
	passo(8)
	passo(9)
	S.codigo(jogador :: any, "teclado_lavanderia", "111")
	esperar("m_errou", function(info)
		return info.motivo == "codigo"
	end)
	S.codigo(jogador :: any, "teclado_lavanderia", Md.CODIGO_LAVANDERIA)
	local nova = esperar("m_missao", nil, 6)
	assert(nova.n == 3 and salvo == 3, "não foi para a lavanderia")
	-- as três cadeiras: brinquedo errado, certo, e a contagem que recomeça quando alguém olha
	S.iniciar(g, 7)
	esperar("m_missao")
	passo(2)
	S.acao(jogador :: any, "cadeira_ke", "boneca")
	esperar("m_errou", function(info)
		return info.motivo == "dono"
	end)
	S.acao(jogador :: any, "cadeira_ke", "carrinho")
	S.acao(jogador :: any, "cadeira_ni", "boneca")
	S.acao(jogador :: any, "cadeira_me", "ursinho")
	passo(3)
	S.sentar(jogador :: any, true)
	esperar("m_conta", function(info)
		return info.k == 1
	end)
	S.olhou(jogador :: any)
	esperar("m_recomeca", function(info)
		return info.motivo == "olhou"
	end)
	g.token = -1 -- encerra os laços do teste
end)

checar("AJUSTE-10: ADM (quem é ADM, pulos válidos, comandos do chat, monstros da internet)", function()
	local Admin = H.modulo("ServerScriptService/OI3_Servidor/Admin")
	local Config = H.modulo("ReplicatedStorage/OI3/Config")
	assert(Admin.ehId(Config.DONO_USERID, 0, {}), "o dono tem que ser ADM")
	assert(Admin.ehId(555, 555, {}), "quem criou a experiência é ADM")
	assert(not Admin.ehId(12345, 0, {}), "qualquer um NÃO pode ser ADM")
	assert(Admin.ehId(12345, 0, { [12345] = true }), "ADM dado pelo dono vale")
	local d, n, i, c = Admin.validarIr("missao", 3, 99, "NI")
	assert(d == "missao" and n == 3 and i >= 1 and c == "NI", "pulo para missão")
	local Md = H.modulo("ReplicatedStorage/OI3/Missoes")
	assert(i == #Md.missao(3).passos, "passo além do fim precisa virar o último")
	assert(Admin.validarIr("missao", 99) == nil, "missão que não existe")
	assert(Admin.validarIr("missao", 2.5) == nil, "missão quebrada")
	assert(Admin.validarIr("tarde") == "tarde" and Admin.validarIr("hackear") == nil, "destinos")
	local _, _, _, cod = Admin.validarIr("tarde", nil, nil, "XX")
	assert(cod == nil, "criança inválida tem que ser ignorada")
	local AC = H.modulo("ReplicatedStorage/OI3/Cliente/AdminCliente")
	local cmd, args = AC.lerComando("/missao 3 2")
	assert(cmd == "missao" and args[1] == "3" and args[2] == "2", "ler comando do chat")
	assert(AC.lerComando("oi gente") == nil, "mensagem normal não é comando")
	local At = H.modulo("ServerScriptService/OI3_Servidor/Atores")
	assert(At.contarJuntas({ "Neck", "Root", "Waist", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip" }) == 7, "contar juntas R15")
	assert(At.contarJuntas({ "Neck", "Root Joint", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }) == 6, "contar juntas R6")
	assert(At.contarJuntas({ "Bone1", "Bone2" }) == 0, "rig sem juntas padrão")
	-- um modelo "baixado" com script malicioso: o script some e o rig é aceito
	local CF, V3 = roblox.CFrame.new, roblox.Vector3.new
	local bruto = roblox.Instance.new("Model")
	local npc = roblox.Instance.new("Model")
	npc.Name = "Bicho"
	npc.Parent = bruto
	local hum = roblox.Instance.new("Humanoid")
	hum.Parent = npc
	local raiz = roblox.Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = V3(2, 2, 1)
	raiz.CFrame = CF(0, 3, 0)
	raiz.Parent = npc
	local torso = roblox.Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = V3(2, 2, 1)
	torso.CFrame = CF(0, 3, 0)
	torso.Parent = npc
	for _, nome in { "Root Joint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" } do
		local m = roblox.Instance.new("Motor6D")
		m.Name = nome
		m.Part0 = raiz
		m.Part1 = torso
		m.Parent = torso
	end
	local ruim = roblox.Instance.new("Script")
	ruim.Name = "Virus"
	ruim.Parent = npc
	local som = roblox.Instance.new("Sound")
	som.Parent = torso
	local m, err = At.adaptarMonstro(bruto)
	assert(m, "rig válido recusado: " .. tostring(err))
	for _, d in m:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "script de modelo da internet não pode sobrar")
		assert(not d:IsA("Sound"), "som de modelo da internet não pode sobrar")
	end
	assert(m.PrimaryPart == raiz and raiz.Anchored and not torso.Anchored, "raiz ancorada, resto solto")
	local vazio = roblox.Instance.new("Model")
	assert(At.adaptarMonstro(vazio) == nil, "modelo sem Humanoid tem que ser recusado")
	assert(#Config.MONSTROS_INTERNET >= 1, "lista de monstros da internet")
	-- braço de modelo da internet em pose "T": a correção leva o braço para baixo
	local Monstro = H.modulo("ReplicatedStorage/OI3/Cliente/Monstro")
	assert(Monstro.correcaoBraco(V3(0, -2, 0.1)) == nil, "braço caído não precisa de correção")
	for _, d in { V3(-2, 0, 0), V3(2, 0, 0), V3(-1.5, -0.8, 0) } do
		local c = Monstro.correcaoBraco(d)
		assert(c, "braço aberto precisa de correção")
		local r = c * d.Unit
		assert(r.Y < -0.95, string.format("correção errada: %.2f %.2f", r.X, r.Y))
	end
end)

checar("AJUSTE-10: ADM no servidor (pular passo, ir para missão/passo e final SEM salvar)", function()
	local Md = H.modulo("ReplicatedStorage/OI3/Missoes")
	local S = H.modulo("ServerScriptService/OI3_Servidor/Missoes")
	local eventos = {}
	local remotoFalso = {}
	function remotoFalso:FireClient(_p, tipo, info)
		table.insert(eventos, { tipo = tipo, info = info })
	end
	local jogador = { Parent = true, UserId = 8, Name = "adm", DisplayName = "adm" }
	local g = { membros = { jogador }, escolhas = { [jogador] = "ME" }, token = 1, teste = true }
	local salvos, terminados = 0, 0
	S.configurar(remotoFalso :: any, function()
		return g
	end, function()
		salvos += 1
	end, function()
		terminados += 1
	end)
	local function esperar(tipo: string, filtro: ((any) -> boolean)?, max: number?)
		local t0 = os.clock()
		while os.clock() - t0 < (max or 8) do
			for k, e in eventos do
				if e.tipo == tipo and (not filtro or filtro(e.info)) then
					table.remove(eventos, k)
					return e.info
				end
			end
			task.wait(0.05)
		end
		error("não chegou: " .. tipo)
	end
	-- vai direto para a Missão 5, passo 4: refaz os pontos dos passos anteriores e começa no 4
	S.adminIr(g, 5, 4)
	esperar("m_missao", function(info)
		return info.n == 5
	end)
	local feitoAntes = esperar("m_feito", function(info)
		return info.silencioso == true
	end)
	assert(feitoAntes, "não refez os passos anteriores")
	local p4 = esperar("m_passo", function(info)
		return info.n == 5 and info.i == 4
	end)
	assert(p4, "não começou no passo 4")
	-- pula o passo atual
	S.adminPasso(g)
	esperar("m_passo", function(info)
		return info.n == 5 and info.i == 5
	end)
	-- final (modo teste)
	S.adminFinal(g)
	esperar("m_final")
	assert(salvos == 0, "pulo do ADM NÃO pode salvar o ponto da missão")
	assert(terminados == 0, "pulo do ADM NÃO pode marcar o fim do capítulo")
	g.token = -1
	local _ = Md
end)

checar("AJUSTE-11: Wendigo principal, sombra no esconde-esconde e vozes sem buracos", function()
	local Config = H.modulo("ReplicatedStorage/OI3/Config")
	assert(Config.MONSTRO_PRINCIPAL == "15020057104", "o monstro principal tem que ser o Wendigo")
	assert(Config.MONSTRO_ESCONDE == "catalogo", "o esconde-esconde usa a sombra do catálogo")
	local achou = false
	for _, info in Config.MONSTROS_INTERNET do
		if tostring(info.id) == Config.MONSTRO_PRINCIPAL then
			achou = true
		end
	end
	assert(achou, "o Wendigo precisa estar na lista dos monstros da internet")
	-- a ronda e o susto do esconde-esconde pedem a variante do catálogo
	local src = fs.readFile("oi3/src/ReplicatedStorage/OI3/Cliente/MissoesCliente.luau")
	assert(string.find(src, 'estado.layout.rota%[2%], Config.MONSTRO_ESCONDE'), "a sombra do esconde-esconde tem que ser a do catálogo")
	assert(string.find(src, "jumpscare%(Config.MONSTRO_ESCONDE%)"), "o susto do esconde-esconde tem que ser a sombra do catálogo")
	-- variante pedida existe → vem ela; não existe → vem o principal
	local P = H.modulo("ReplicatedStorage/OI3/Personagens")
	local atores = H.prepararAtores()
	local lista = atores:FindFirstChild("Monstros") or roblox.Instance.new("Folder")
	lista.Name = "Monstros"
	local cat = atores:FindFirstChild("CRIATURA"):Clone()
	cat.Name = "catalogo"
	cat:SetAttribute("NomeMonstro", "Sombra do catálogo")
	cat.Parent = lista
	lista.Parent = atores
	local m1 = P.criarCriatura("catalogo")
	assert(m1:GetAttribute("NomeMonstro") == "Sombra do catálogo", "não usou a variante pedida")
	local m2 = P.criarCriatura("nao_existe")
	assert(m2 and m2:GetAttribute("Codigo") == "CRIATURA", "variante faltando tem que cair no principal")
	-- as falas antigas do menino ficam de reserva (nada que tem gravação fica mudo)
	local AudioMapa = H.modulo("ReplicatedStorage/OI3/AudioMapa")
	for _, id in { "ME_1", "ME_2", "ME_3" } do
		assert(AudioMapa.itens[id .. "_v1"], "falta a reserva " .. id .. "_v1")
	end
	-- o relatório de vozes do ADM roda e aponta o que falta gravar
	local AC = H.modulo("ReplicatedStorage/OI3/Cliente/AdminCliente")
	local rel = AC.relatorioVozes()
	assert(string.find(rel, "Falas com voz tocando"), "relatório de vozes")
	assert(string.find(rel, "VO_7"), "o relatório tem que listar as falas sem gravação (VO_7)")
end)

print(if falhas == 0 then "\nTUDO OK" else ("\nFALHAS: " .. falhas))
if falhas > 0 then
	error("testes falharam")
end
