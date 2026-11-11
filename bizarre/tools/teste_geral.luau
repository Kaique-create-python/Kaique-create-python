-- BIZARRE BATTLEGROUNDS :: testes offline (Lune). Uso: lune run bizarre/tools/teste_geral.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local H = require("./harness")

local falhas = 0
local total = 0
local function teste(nome: string, fn: () -> ())
	total += 1
	local ok, err = pcall(fn)
	if ok then
		print("  ok  " .. nome)
	else
		falhas += 1
		print("  FALHOU  " .. nome .. ": " .. tostring(err))
	end
end

print("== compilação")
teste("todos os .luau compilam", function()
	local n, erros = H.compilarTudo()
	assert(#erros == 0, table.concat(erros, "\n"))
	assert(n >= 30, "poucos arquivos: " .. n)
end)

teste("o teste da nuvem compila e cabe no limite (200 kB)", function()
	local luau = require("@lune/luau")
	local fonte = fs.readFile("bizarre/tools/teste_nuvem.luau")
	luau.compile(fonte)
	assert(#fonte < 200 * 1024)
end)

local Config = H.modulo("ReplicatedStorage/BB/Config")
local Regras = H.modulo("ReplicatedStorage/BB/Regras")
local Stands = H.modulo("ReplicatedStorage/BB/Stands")
local Golpes = H.modulo("ReplicatedStorage/BB/Golpes")
local Poses = H.modulo("ReplicatedStorage/BB/Poses")
local Sons = H.modulo("ReplicatedStorage/BB/Sons")
local Plano = H.modulo("ReplicatedStorage/BB/Mapa/Plano")
local V = roblox.Vector3.new
local Vector3 = roblox.Vector3

print("== regras do combate")
teste("combo de M1 vai de 1 a 4 e descansa", function()
	local e = Regras.novoEstado()
	local t = 10
	local seq = {}
	for _ = 1, 4 do
		local n = Regras.m1(e, t)
		table.insert(seq, n)
		t += Config.M1.intervalo + 0.01
	end
	assert(table.concat(seq, ",") == "1,2,3,4", table.concat(seq, ","))
	assert(Regras.m1(e, t) == nil, "depois do 4º tem que descansar")
	t += Config.M1.recargaFinal
	assert(Regras.m1(e, t) == 1, "volta ao 1")
	-- parou de bater: reseta
	Regras.m1(e, t + 0.4)
	assert(Regras.m1(e, t + 0.4 + Config.M1.reset + 0.1) == 1, "reset do combo")
end)

teste("bloqueio de frente segura, de costas não, parry na hora certa", function()
	local e = Regras.novoEstado()
	local olhar = V(0, 0, -1)
	assert(Regras.resolverBloqueio(e, 5, V(0, 0, -3), olhar, { dano = 3 }) == "nada", "sem bloquear")
	Regras.comecarBloqueio(e, 5)
	assert(Regras.resolverBloqueio(e, 5.1, V(0, 0, -3), olhar, { dano = 3, tipo = "melee" }) == "parry", "parry")
	assert(Regras.resolverBloqueio(e, 6, V(0, 0, -3), olhar, { dano = 3, tipo = "melee" }) == "bloqueado", "bloqueado")
	assert(Regras.resolverBloqueio(e, 6, V(0, 0, 3), olhar, { dano = 3, tipo = "melee" }) == "nada", "pelas costas")
	assert(Regras.resolverBloqueio(e, 6, V(0, 0, -3), olhar, { dano = 3, inbloqueavel = true }) == "nada", "inbloqueável")
	-- a guarda acaba e quebra
	local r = ""
	for _ = 1, 30 do
		r = Regras.resolverBloqueio(e, 7, V(0, 0, -3), olhar, { dano = 3.5, tipo = "melee" })
		if r == "quebra" then
			break
		end
	end
	assert(r == "quebra", "guarda tinha que quebrar")
	assert(Regras.resolverBloqueio(e, 7, V(0, 0, -3), olhar, { dano = 1, quebraGuarda = true, tipo = "melee" }) == "quebra")
end)

teste("atordoar interrompe; super armadura não", function()
	local e = Regras.novoEstado()
	e.acaoAte = 20
	local tok = e.token
	Regras.atordoar(e, 10, 0.5)
	assert(e.token ~= tok and e.acaoAte <= 10 and e.stunAte > 10)
	local e2 = Regras.novoEstado()
	e2.armaduraAte = 12
	e2.acaoAte = 20
	local tok2 = e2.token
	Regras.atordoar(e2, 10, 0.5)
	assert(e2.token == tok2 and e2.acaoAte == 20, "armadura ignora o atordoamento")
	assert(Regras.podeAgir(e, 10) == false)
	assert(Regras.podeAgir(e, 11) == true)
end)

teste("despertar enche, dura e deixa as recargas mais rápidas", function()
	local e = Regras.novoEstado()
	assert(not Regras.podeDespertar(e, 1))
	Regras.ganharDespertar(e, 500, 1)
	assert(e.despertar == Config.DESPERTAR.max)
	assert(Regras.podeDespertar(e, 1))
	Regras.despertar(e, 1)
	assert(Regras.desperto(e, 2) and not Regras.desperto(e, 1 + Config.DESPERTAR.duracao + 0.1))
	local fim = Regras.usarCd(e, "x", 10, 2)
	assert(math.abs(fim - (2 + 10 * Config.DESPERTAR.multRecarga)) < 1e-6)
	assert(Regras.danoFinal(10, e, Regras.novoEstado(), 2) > 10)
end)

teste("evasiva só funciona atordoado e tem recarga", function()
	local e = Regras.novoEstado()
	assert(not Regras.podeEvasiva(e, 1), "não precisa")
	Regras.atordoar(e, 1, 1)
	assert(Regras.podeEvasiva(e, 1.2))
	Regras.usarEvasiva(e, 1.2)
	assert(not Regras.atordoado(e, 1.21) and Regras.invencivel(e, 1.3))
	Regras.atordoar(e, 2, 1)
	assert(not Regras.podeEvasiva(e, 2.1), "recarga")
end)

teste("tipo do dash pela direção do movimento", function()
	assert(Regras.tipoDash(V(0, 0, -1)) == "frente")
	assert(Regras.tipoDash(V(0, 0, 1)) == "tras")
	assert(Regras.tipoDash(V(1, 0, 0)) == "lado")
	assert(Regras.tipoDash(V(0, 0, 0)) == "frente")
end)

print("== Stands e golpes")
local fonteExec = fs.readFile("bizarre/src/ServerScriptService/BB_Servidor/Executores.luau")
local fonteEfeitos = fs.readFile("bizarre/src/ReplicatedStorage/BB/Cliente/Efeitos.luau")
local EXECUTORES = { golpe = true, barragem = true, projetil = true, area = true, investida = true, agarrar = true, contra = true, teleporte = true, cura = true, buff = true, especial = true }

local function sonsDe(t: any, lista: { string })
	for k, v in t do
		if (k == "som" or k == "somLancar" or k == "somLoop") and type(v) == "string" then
			table.insert(lista, v)
		elseif type(v) == "table" and type(k) ~= "number" or (type(v) == "table" and type(k) == "number") then
			sonsDe(v, lista)
		end
	end
end

local function vfxDe(t: any, lista: { string })
	for k, v in t do
		if k == "vfx" and type(v) == "string" then
			table.insert(lista, v)
		elseif type(v) == "table" then
			vfxDe(v, lista)
		end
	end
end

teste("6 Stands da JoJo completos (4 golpes + ULT, cores, roupa e acessórios do catálogo)", function()
	assert(#Stands.ORDEM == 6)
	for _, id in Stands.ORDEM do
		local s = Stands.get(id)
		assert(s and s.id == id, id)
		assert(#s.golpes == 4, id .. " precisa de 4 golpes")
		for i, gid in s.golpes do
			local g = Golpes.get(gid)
			assert(g, id .. ": falta " .. gid)
			assert(not g.ult, gid .. " não pode ser ULT")
			local g2, id2 = Golpes.doSlot(s, i)
			assert(g2 == g and id2 == gid)
		end
		local u = Golpes.get(s.ult)
		assert(u and u.ult, id .. ": ULT")
		assert(s.cor and s.cor2 and s.aura and s.olhos, id .. ": cores")
		assert(s.usuario and s.parte and s.grito, id .. ": usuário/parte/grito")
		assert(#s.stats == 6, id .. ": status (Poder, Velocidade, Alcance, Resistência, Precisão, Potencial)")
		for _, letra in s.stats do
			assert(string.find("ABCDE", letra, 1, true), id .. ": status " .. tostring(letra))
		end
		local v = s.visual
		assert(type(v.camisa) == "number" and v.camisa > 1000, id .. ": camisa")
		assert(v.calca == nil or (type(v.calca) == "number" and v.calca > 1000), id .. ": calça")
		local itens = Stands.itens(s)
		assert(#itens >= 3, id .. ": poucos itens do catálogo")
		local vistos = {}
		for _, item in itens do
			assert(type(item) == "number" and item > 1000, id .. ": item " .. tostring(item))
			assert(not vistos[item], id .. ": item repetido " .. item)
			vistos[item] = true
		end
		for tipo in v.acessorios or {} do
			assert(({ chapeu = 1, cabelo = 1, rosto = 1, pescoco = 1, ombro = 1, frente = 1, costas = 1, cintura = 1 })[tipo], id .. ": tipo de acessório " .. tipo)
		end
		assert(v.escala and v.escala >= 1 and v.escala <= 1.3, id .. ": escala")
		assert(s.passiva and s.passiva.nome and s.passiva.desc, id .. ": passiva")
		assert(Poses.clipe("despertar_" .. id), id .. ": animação de despertar própria")
	end
end)

teste("todo golpe tem executor, animação, sons e efeitos que existem", function()
	for gid, g in Golpes.LISTA do
		assert(EXECUTORES[g.tipo], gid .. ": tipo " .. tostring(g.tipo))
		if g.tipo == "especial" then
			assert(string.find(fonteExec, "ESPECIAL." .. g.especial .. " = function", 1, true), gid .. ": especial " .. tostring(g.especial))
		end
		assert(g.nome and g.desc and g.cd and g.trava, gid .. ": nome/desc/cd/trava")
		for _, clipe in { g.animU, g.animS } do
			assert(Poses.clipe(clipe), gid .. ": clipe " .. tostring(clipe))
		end
		if g.resposta then
			assert(Poses.clipe(g.resposta.animU or "chute_alto") and Poses.clipe(g.resposta.animS or "chute"), gid .. ": clipes da resposta")
		end
		if g.agarrao then
			assert(Poses.clipe(g.agarrao.animU or "comando_cruzado") and Poses.clipe(g.agarrao.animS or "barragem"), gid .. ": clipes do agarrão")
		end
		for _, tr in g.animTroca or {} do
			assert(Poses.clipe(tr.animU) and Poses.clipe(tr.animS), gid .. ": animTroca")
		end
		local sons = {}
		sonsDe(g, sons)
		for _, nome in sons do
			assert(Sons.LISTA[nome], gid .. ": som " .. nome)
		end
		local vfx = {}
		vfxDe(g, vfx)
		for _, nome in vfx do
			assert(string.find(fonteEfeitos, nome .. " = {", 1, true) or string.find(fonteEfeitos, '"' .. nome .. '"', 1, true), gid .. ": efeito " .. nome)
		end
		if g.tipo == "projetil" then
			assert(g.proj and g.proj.vel and g.proj.alcance, gid .. ": projétil")
			if g.proj.visual then
				assert(string.find(fonteEfeitos, 'tipo == "' .. g.proj.visual .. '"', 1, true), gid .. ": visual do projétil " .. g.proj.visual)
			end
		end
		if g.tipo == "buff" then
			assert(g.buff and g.buff.dur and g.buff.dur > 0, gid .. ": buff")
		end
		if g.voz then
			assert(type(g.voz) == "string" or (type(g.voz) == "table" and #g.voz > 0), gid .. ": voz")
		end
		if g.tipo == "barragem" then
			assert(g.inicio < g.fim and g.fim <= g.trava + 0.5 and g.hit and g.final, gid .. ": barragem")
		end
		if g.hits then
			for _, h in g.hits do
				assert(h.t <= g.trava + 0.5, gid .. ": hit depois do fim da trava")
			end
		end
	end
end)

teste("sons: IDs válidos e sem repetição dentro de cada som", function()
	local n = 0
	for nome, s in Sons.LISTA do
		assert(#s.ids >= 1, nome)
		local vistos = {}
		for _, id in s.ids do
			assert(type(id) == "number" and id > 1000, nome)
			assert(not vistos[id], nome .. ": id repetido")
			vistos[id] = true
			n += 1
		end
		assert(s.vel[1] <= s.vel[2], nome)
	end
	assert(n > 100, "poucos sons: " .. n)
	assert(#Sons.todosIds() > 100)
end)

print("== animações")
teste("todo clipe amostra sem erro (início, meio e fim)", function()
	for nome, c in Poses.C do
		for _, t in { 0, 0.05, 0.2, 0.5, 1, 3 } do
			if c.proc == "barragem" then
				Poses.barragem(t, 1)
			elseif c.proc == "estocadas" then
				Poses.estocadas(t)
			else
				local p = Poses.amostrar(c, t)
				for junta, v in p do
					assert(Poses.JUNTAS[junta], nome .. ": junta " .. junta)
					assert(#v == 3 and v[1] == v[1], nome .. ": valor")
				end
			end
		end
		if c.impacto and c.dur then
			assert(c.impacto <= c.dur, nome .. ": impacto depois do fim")
		end
	end
end)

teste("andar JoJo: cada Stand tem estilo e as poses saem válidas (parado, andando, correndo)", function()
	local Animador = H.modulo("ReplicatedStorage/BB/Cliente/Animador")
	for _, id in Stands.ORDEM do
		assert(Animador.ESTILOS[id], "sem estilo de andar: " .. id)
		local falso = { fase = 0, modelo = { GetAttribute = function(_, nome)
			return if nome == "BB_Stand" then id else nil
		end } }
		for _, vel in { 0, 8, 16, 26 } do
			local p = Animador.andarJoJo(falso, 1 / 60, vel, false, Vector3.new(vel * 0.3, 0, -vel), 0.5, 0)
			assert(p.RootPos and math.abs(p.RootPos[2]) < 1, id .. ": quique do corpo")
			for junta, v in p do
				assert(Poses.JUNTAS[junta] or junta == "RootPos", id .. ": junta " .. junta)
				assert(#v == 3 and v[1] == v[1] and math.abs(v[1]) < 180, id .. ": valor ruim em " .. junta)
			end
			local r6 = Animador.paraR6(p)
			assert(r6 and r6.LS and r6.RH, id .. ": R6")
		end
	end
end)

teste("poses usam só juntas do R15 e espelhar troca os lados", function()
	for nome, p in Poses.P do
		for junta in p do
			assert(Poses.JUNTAS[junta], nome .. ": " .. junta)
		end
	end
	local e = Poses.espelhar({ LS = { 10, 20, 30 } })
	assert(e.RS and e.RS[1] == 10 and e.RS[2] == -20 and e.RS[3] == -30)
end)

print("== mapa")
local plano
teste("a cidade é gerada igual sempre e tem prédios quebráveis", function()
	plano = Plano.gerar()
	local p2 = Plano.gerar()
	assert(#plano.pecas == #p2.pecas, "determinístico")
	local q, vidros, paredes = 0, 0, 0
	local ids = {}
	for _, p in plano.pecas do
		assert(not ids[p.id], "id repetido")
		ids[p.id] = true
		assert(p.s.X > 0 and p.s.Y > 0 and p.s.Z > 0, p.n .. ": tamanho")
		if p.q then
			q += 1
		end
		if p.k == "vidro" then
			vidros += 1
		elseif p.k == "parede" then
			paredes += 1
		end
	end
	assert(plano.predios >= 12, "prédios: " .. plano.predios)
	assert(q > 1000 and paredes > 600 and vidros > 150, string.format("quebráveis %d, paredes %d, vidros %d", q, paredes, vidros))
	assert(#plano.pecas < 4500, "peças demais para celular: " .. #plano.pecas)
	assert(#plano.spawns >= 8, "spawns")
	assert(plano.treino and #plano.treino.bonecos == 3, "treino")
	print(string.format("        %d peças, %d quebráveis (%d paredes, %d vidros), %d prédios, %d spawns", #plano.pecas, q, paredes, vidros, plano.predios, #plano.spawns))
end)

teste("ninguém nasce dentro de prédio", function()
	for _, cf in plano.spawns do
		local pos = cf.Position
		for _, p in plano.pecas do
			if p.k == "parede" or p.k == "vidro" or p.k == "estatua" or p.k == "base" and p.n == "Pedestal" then
				local rel = p.cf:PointToObjectSpace(pos)
				local dentro = math.abs(rel.X) < p.s.X / 2 + 1.5 and math.abs(rel.Y) < p.s.Y / 2 + 2.5 and math.abs(rel.Z) < p.s.Z / 2 + 1.5
				assert(not dentro, string.format("spawn %s dentro de %s", tostring(pos), p.n))
			end
		end
		assert(math.abs(pos.X) < Plano.LIMITE - 5 and math.abs(pos.Z) < Plano.LIMITE - 5, "spawn fora do mapa")
	end
end)

teste("o mapa monta, quebra e reconstrói (sem física)", function()
	local Mapa = H.modulo("ServerScriptService/BB_Servidor/Mapa")
	local pasta = roblox.Instance.new("Folder")
	pasta.Name = "Teste"
	local _, pl = Mapa.construir(pasta, plano)
	local quebraveis = pasta:FindFirstChild("BB_Mapa"):FindFirstChild("Quebraveis")
	local lista = quebraveis:GetChildren()
	assert(#lista > 1000, "quebráveis montadas: " .. #lista)
	-- quebra um vidro, uma parede (força 2) e não quebra parede com força 1
	local vidro, parede, carro
	for _, p in lista do
		if p.Name == "Vidro" and not vidro then
			vidro = p
		elseif p.Name == "Parede" and not parede then
			parede = p
		elseif p.Name == "Carro" and not carro then
			carro = p
		end
	end
	assert(Mapa.quebrar(vidro, nil, 1), "vidro quebra com força 1")
	assert(vidro.Transparency == 1 and vidro.CanCollide == false, "vidro sumiu")
	assert(not Mapa.quebrar(parede, nil, 1), "parede aguenta força 1")
	assert(Mapa.quebrar(parede, nil, 2), "parede quebra com força 2")
	assert(Mapa.quebrar(carro, nil, 2), "carro quebra")
	assert(Mapa.totalQuebradas() >= 3 + 7, "o carro inteiro quebra junto: " .. Mapa.totalQuebradas())
	assert(Mapa.restaurarTudo() >= 10)
	assert(vidro.Transparency < 1 and parede.CanCollide == true, "voltou")
	assert(Mapa.totalQuebradas() == 0)
	local _ = pl
end)

teste("Morioh: dano acumula, chão e estático não quebram, máximo por impacto, volta igual", function()
	local Mapa = H.moduloNovo("ServerScriptService/BB_Servidor/Mapa")
	local Config2 = H.modulo("ReplicatedStorage/BB/Config")
	local raiz = roblox.Instance.new("Folder")
	raiz.Name = "TesteMorioh"
	local morioh = roblox.Instance.new("Model")
	morioh.Name = "Morioh"
	morioh.Parent = raiz
	local function peca(nome, pos, tam, role, vida, mat, tags)
		local p = roblox.Instance.new("Part")
		p.Name = nome
		p.Size = tam
		p.CFrame = roblox.CFrame.new(pos)
		p.Anchored = true
		p:SetAttribute("Role", role)
		p:SetAttribute("Health", vida)
		p:SetAttribute("MaterialClass", mat)
		p:SetAttribute("Destructible", vida > 0)
		for _, t in tags do
			p:AddTag(t)
		end
		p.Parent = morioh
		return p
	end
	local parede = peca("Parede", V(0, 4, 0), V(8, 8, 1), "Wall", 160, "Concrete", { "MoriohDestructible" })
	local vidro = peca("Vidro", V(6, 4, 0), V(3, 3, 0.2), "Glass", 20, "Glass", { "MoriohDestructible", "MoriohGlass" })
	local rua = peca("Asfalto", V(0, -0.25, 0), V(40, 0.5, 40), "Road", 0, "Asphalt", { "MoriohStatic" })
	local piso = peca("Piso", V(0, 0.1, 6), V(8, 0.2, 8), "Floor", 80, "WoodPlanks", { "MoriohDestructible" })
	Mapa.construir(raiz)
	assert(Mapa.modo == "morioh", "modo")
	assert(#Mapa.spawns() >= 8 and Mapa.treino() and #Mapa.treino().bonecos == 3, "spawns e treino do Morioh")
	assert(Mapa.ehQuebravel(parede) and Mapa.ehQuebravel(vidro) and not Mapa.ehQuebravel(rua), "quem quebra")
	-- força 1 (60) não derruba concreto (160) de primeira, mas acumula
	assert(not Mapa.quebrar(parede, nil, 1) and not Mapa.quebrar(parede, nil, 1), "concreto aguenta 2 golpes fracos")
	assert(Mapa.quebrar(parede, nil, 1), "o 3º golpe fraco quebra (dano acumulado)")
	assert(parede.Transparency == 1 and parede.CanCollide == false, "parede sumiu")
	assert(not Mapa.quebrar(rua, nil, 9), "rua nunca quebra")
	-- quem desliza no chão não abre buraco no piso
	Mapa.quebrarCaixa(roblox.CFrame.new(0, 1, 6), V(8, 4, 8), 9, nil, true)
	assert(piso.Transparency == 0, "piso ficou")
	assert(Mapa.quebrarVidros(V(6, 4, 0), 6) == 1 and vidro.Transparency == 1, "vidro estoura")
	-- muitas peças: um impacto só quebra no máximo maxPorImpacto
	for i = 1, 70 do
		peca("Tijolo" .. i, V(20 + (i % 7), 1 + math.floor(i / 7) * 0.5, 20), V(0.9, 0.4, 0.9), "Wall", 80, "Brick", { "MoriohDestructible" })
	end
	local n = Mapa.quebrarArea(V(23, 3, 20), 12, 9)
	assert(n == Config2.MAPA.maxPorImpacto, "máximo por impacto: " .. n)
	-- volta tudo do jeito que era
	assert(Mapa.restaurarTudo() == 2 + n, "restaurou")
	assert(parede.Transparency == 0 and parede.CanCollide == true and vidro.Transparency == 0, "voltou igual")
	assert(Mapa.totalQuebradas() == 0)
	-- a bomba da Killer Queen acha o objeto mais perto (e não o chão)
	local alvo = Mapa.maisPerto(roblox.CFrame.new(0, 3, 1), V(8, 8, 8))
	assert(alvo == parede, "mais perto: " .. tostring(alvo))
end)

print("== AJUSTE7")
local task = require("@lune/task")

teste("toque interrompido: o botão solta quando o dedo sai da tela, perde o foco ou a tela gira", function()
	local Toques = H.modulo("ReplicatedStorage/BB/Cliente/Toques")
	local apertos, solturas = 0, 0
	local t = Toques.novo(function()
		apertos += 1
	end, function()
		solturas += 1
	end)
	local dedo1, dedo2 = { "dedo1" }, { "dedo2" }
	t.comecar(dedo1, false)
	Toques.terminou(dedo2, false) -- outro dedo saiu: continua segurando
	assert(apertos == 1 and solturas == 0, "outro dedo não solta")
	Toques.terminou(dedo1, false) -- o dedo certo saiu (mesmo fora do botão)
	assert(solturas == 1, "soltou ao levantar o dedo")
	Toques.terminou(dedo1, false)
	assert(solturas == 1, "não solta duas vezes")
	t.comecar(dedo1, false)
	Toques.soltarTudo() -- perdeu o foco / abriu o menu
	assert(solturas == 2, "foco perdido solta")
	t.comecar(dedo1, false)
	t.comecar(dedo2, false) -- apertou de novo sem soltar: solta o anterior primeiro
	assert(apertos == 4 and solturas == 3, "aperto duplo")
	Toques.esquecerTodos() -- tela girou: botões refeitos
	assert(solturas == 4)
	local m = Toques.novo(function() end, function()
		solturas += 1
	end)
	m.comecar({ "clique" }, true)
	Toques.terminou({ "outro objeto" }, true) -- mouse: o objeto do evento pode ser outro
	assert(solturas == 5, "mouse solta")
end)

teste("entrada: recusas, pedido repetido e resposta duplicada", function()
	local Entrada = H.modulo("ReplicatedStorage/BB/Entrada")
	local livre = { pendente = nil, vivo = false, emCombate = false, adm = false }
	local ok, motivo, id = Entrada.validar(livre, { id = "a1", stand = "STAR_PLATINUM" }, 10, Stands.valido)
	assert(ok and id == "a1", "pedido bom")
	ok, motivo = Entrada.validar(livre, { id = "a2", stand = "NAO_EXISTE" }, 10, Stands.valido)
	assert(not ok and motivo == "Stand inválido", "Stand inválido recusado")
	ok, motivo = Entrada.validar(livre, "lixo", 10, Stands.valido)
	assert(not ok, "pedido que não é tabela")
	local carregando = { pendente = { id = "a1", t = 10 }, vivo = false, emCombate = false, adm = false }
	ok, motivo = Entrada.validar(carregando, { id = "a1", stand = "THE_WORLD" }, 12, Stands.valido)
	assert(not ok and motivo == "duplicado", "mesmo pedido de novo é ignorado")
	ok, motivo = Entrada.validar(carregando, { id = "b7", stand = "THE_WORLD" }, 12, Stands.valido)
	assert(not ok and motivo ~= "duplicado", "outro pedido durante o carregamento é recusado")
	ok = Entrada.validar(carregando, { id = "b7", stand = "THE_WORLD" }, 10 + Entrada.ESPERA_MAXIMA + 1, Stands.valido)
	assert(ok, "pedido velho expira")
	local lutando = { pendente = nil, vivo = true, emCombate = true, adm = false }
	ok, motivo = Entrada.validar(lutando, { id = "c1", stand = "THE_WORLD" }, 10, Stands.valido)
	assert(not ok and string.find(motivo, "combate"), "trocar de Stand em combate é recusado")
	lutando.adm = true
	assert(Entrada.validar(lutando, { id = "c2", stand = "THE_WORLD" }, 10, Stands.valido), "ADM pode")
	-- celular
	local c = Entrada.novoCliente()
	local p1 = c.pedir(100)
	assert(p1 and c.pedir(101) == nil, "toque repetido não cria outro pedido")
	assert(c.resposta({ id = "outro", ok = true }) == nil, "resposta de outro pedido é ignorada")
	assert(c.resposta({ id = p1, ok = false, motivo = "x" }) == "recusado")
	assert(c.resposta({ id = p1, ok = true }) == nil, "resposta duplicada é ignorada")
	local p2 = c.pedir(102)
	assert(p2 and p2 ~= p1)
	assert(not c.expirou(110) and c.expirou(102 + Entrada.ESPERA_MAXIMA + 1), "sem resposta: libera o botão")
	assert(c.resposta({ id = p2, ok = true }) == nil, "resposta atrasada depois de expirar é ignorada")
end)

teste("congelamentos sobrepostos: cada tempo parado só solta os alvos dele", function()
	local TS = H.modulo("ServerScriptService/BB_Servidor/TempoSessao")
	local function lut(nome)
		return { nome = nome, hum = { Health = 100 }, modelo = { Parent = true } }
	end
	local jotaro, dio, a, b, c = lut("jotaro"), lut("dio"), lut("a"), lut("b"), lut("c")
	local s1 = TS.nova(jotaro, 3)
	assert(#TS.congelar(s1, { a, b, dio }) == 3)
	local s2 = TS.nova(dio, 5)
	local novos = TS.congelar(s2, { a, b, c, jotaro })
	assert(#novos == 2 and novos[1] == c and novos[2] == jotaro, "a outra ULT não toma os alvos da primeira")
	assert(a.sessaoTempo == s1 and c.sessaoTempo == s2)
	local soltos = TS.encerrar(s1)
	assert(#soltos == 3 and a.sessaoTempo == nil and c.sessaoTempo == s2, "fim da 1ª: só os dela")
	assert(#TS.encerrar(s1) == 0, "encerrar duas vezes não solta ninguém")
	assert(#TS.congelar(s2, { a }) == 1, "livre de novo, pode ser pego pela 2ª")
	dio.hum.Health = 0
	assert(not TS.donoVivo(s2), "dono morto: a sessão tem que acabar")
	assert(#TS.encerrar(s2) == 3 and c.sessaoTempo == nil and jotaro.sessaoTempo == nil)
end)

teste("salvamentos ao mesmo tempo (autosave + saída + desligamento) não duplicam nem perdem", function()
	local Dados = H.moduloNovo("ServerScriptService/BB_Servidor/Dados")
	local guardado: any = nil
	local escritas, falhar = 0, 0
	local store = {}
	function store:UpdateAsync(_chave, fn)
		task.wait(0.02) -- o DataStore de verdade demora: é aqui que os salvamentos se cruzam
		local novo = fn(guardado)
		if novo ~= nil then
			guardado = novo
			escritas += 1
		end
		if falhar > 0 then
			falhar -= 1
			error("erro de rede DEPOIS de gravar")
		end
		return guardado
	end
	Dados._usarStore(store)
	local jogador = { UserId = 42 }
	local s = { base = { abates = 5, mortes = 1, melhorSequencia = 2 }, delta = { abates = 3, mortes = 2, dano = 120 }, sequencia = 0, melhorSequencia = 4, carregou = true }
	Dados._sessao(jogador, s)
	guardado = { abates = 5, mortes = 1, dano = 0, melhorSequencia = 2 }
	for _ = 1, 3 do
		task.spawn(Dados.salvar, jogador)
	end
	s.delta.abates += 1 -- um abate chega no meio do salvamento
	Dados._esperarSalvar(jogador, 5)
	task.wait(0.2)
	assert(guardado.abates == 9 and guardado.mortes == 3, string.format("somou certo: %d abates, %d mortes", guardado.abates, guardado.mortes))
	assert(guardado.melhorSequencia == 4 and s.delta.abates == 0 and s.pendente == nil)
	-- a gravação entra mas o Roblox responde erro: o MESMO lote é reenviado e não soma de novo
	s.delta.abates = 2
	falhar = 1
	Dados.salvar(jogador)
	assert(s.pendente ~= nil and guardado.abates == 11, "gravou, mas ficou pendente")
	Dados.salvar(jogador)
	assert(s.pendente == nil and guardado.abates == 11, "reenvio do lote não duplicou: " .. guardado.abates)
	assert(#guardado.lotes <= 30 and guardado.versao == 2)
	local v, aplicou = Dados._aplicarLote({ abates = 1, lotes = { "x" } }, { id = "x", abates = 9, mortes = 0, dano = 0, melhor = 0 })
	assert(not aplicou and v.abates == 1, "lote já visto é ignorado")
end)

teste("Morioh mais leve: 1 de cada 3 lâminas, sem juntas e reflexos; o que colide fica", function()
	local Mapa = H.moduloNovo("ServerScriptService/BB_Servidor/Mapa")
	local morioh = roblox.Instance.new("Model")
	morioh.Name = "Morioh"
	local function peca(nome, pai, colide, papel)
		local p = roblox.Instance.new("Part")
		p.Name = nome
		p.CanCollide = colide
		p.Anchored = true
		if papel then
			p:SetAttribute("Role", papel)
		end
		p.Parent = pai
		return p
	end
	for j = 1, 2 do
		local janela = roblox.Instance.new("Model")
		janela.Name = "Janela_Detalhada"
		janela.Parent = morioh
		for _ = 1, 10 do
			peca("Lamina_Persiana", janela, false, "Trim")
		end
	end
	for _ = 1, 4 do
		peca("Junta_Revestimento", morioh, false, "Trim")
	end
	peca("Reflexo_fino", morioh, false, "GlassHighlight")
	local parede = peca("Parede", morioh, true, "Wall")
	local enfeite = peca("Ralo", morioh, false, "Detail")
	local colide = peca("Junta_Revestimento", morioh, true, "Trim") -- com colisão: não mexe
	local removidas, semSombra = Mapa.simplificar(morioh)
	local laminas = 0
	for _, d in morioh:GetDescendants() do
		if d.Name == "Lamina_Persiana" then
			laminas += 1
		end
	end
	assert(laminas == 8, "fica 1 de cada 3 por janela (4 de 10): " .. laminas)
	assert(removidas == 12 + 4 + 1, "removidas: " .. removidas)
	assert(parede.Parent == morioh and colide.Parent == morioh, "peças com colisão ficam")
	assert(enfeite.CastShadow == false and parede.CastShadow == true and semSombra >= 1, "sombra só sai dos enfeites")
end)

print("== AJUSTE-10")
teste("andar/correr do dono: quadros completos, em ordem e tocando nas juntas do R6", function()
	local A = H.modulo("ReplicatedStorage/BB/AnimacoesDono")
	local Anim = H.modulo("ReplicatedStorage/BB/Cliente/Animador")
	for _, nome in { "andar", "correr" } do
		local c = A[nome]
		assert(c and c.dur > 0.3 and c.loop and #c.quadros >= 10, nome .. ": clipe")
		local antes = -1
		for i, q in c.quadros do
			assert(q[1] > antes, nome .. ": quadro " .. i .. " fora de ordem")
			antes = q[1]
			for _, j in { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
				local v = q[2][j]
				assert(v and #v == 6, nome .. ": quadro " .. i .. " sem " .. j)
				for _, x in v do
					assert(x == x and math.abs(x) < 10, nome .. ": número estranho em " .. j)
				end
			end
		end
		assert(math.abs(antes - c.dur) < 0.02, nome .. ": último quadro no fim do clipe")
		-- no meio de dois quadros a pose é a mistura dos dois
		local t = (c.quadros[2][1] + c.quadros[3][1]) / 2
		local pose = Anim.amostrarDono(nome, t)
		local n = 0
		for motor, cf in pose do
			n += 1
			assert(({ RootJoint = 1, Neck = 1, ["Left Shoulder"] = 1, ["Right Shoulder"] = 1, ["Left Hip"] = 1, ["Right Hip"] = 1 })[motor], "junta " .. motor)
			assert(cf.Position.Magnitude < 3, nome .. ": junta longe demais")
		end
		assert(n == 6, nome .. ": " .. n .. " juntas")
		-- volta ao começo depois do fim (loop)
		local p0, p1 = Anim.amostrarDono(nome, 0), Anim.amostrarDono(nome, c.dur * 3)
		assert((p0.RootJoint.Position - p1.RootJoint.Position).Magnitude < 0.05, nome .. ": loop")
	end
end)

teste("Stand: do lado esquerdo atrás flutuando; guarda na frente com os braços cruzados", function()
	local fonte = H.fonte("ReplicatedStorage/BB/Cliente/StandVisual")
	assert(string.find(fonte, "costas = CFrame.new(-2.35, 1.2, 1.25)", 1, true), "posição do lado")
	assert(string.find(fonte, "guarda = CFrame.new(0, 0.45, -2.3)", 1, true), "guarda na frente")
	assert(string.find(fonte, "BB_Bloqueando", 1, true) and string.find(fonte, "s_guarda", 1, true), "guarda segue o bloqueio")
	local P = H.modulo("ReplicatedStorage/BB/Poses")
	for _, nome in { "s_guarda", "s_guarda_impacto" } do
		local c = P.clipe(nome)
		assert(c, "clipe " .. nome)
		for _, k in c.keys do
			assert(P.P[k[2]], nome .. ": pose " .. k[2])
		end
	end
	-- braços cruzados: cada ombro puxa para o meio (esquerdo Z+, direito Z-) e levantados para a frente
	local g = P.P.stand_guarda
	assert(g.LS[3] > 20 and g.RS[3] < -20 and g.LS[1] > 60 and g.RS[1] > 60, "braços em X na frente")
end)

teste("VFX: todos os efeitos rodam, peças sem colisão e com teto (celular não engasga)", function()
	local roblox = require("@lune/roblox")
	local pastaVFX = roblox.Instance.new("Folder")
	local terra = roblox.Instance.new("Folder")
	local emitidas = 0
	local InstanceFalso = {
		new = function(classe: string)
			if classe == "ParticleEmitter" then
				return { Emit = function(_, n)
					emitidas += n
				end }
			end
			return roblox.Instance.new(classe)
		end,
	}
	H.servicos.Debris = { AddItem = function() end }
	H.extras.Instance = InstanceFalso
	H.extras.workspace = setmetatable({ CurrentCamera = { CFrame = roblox.CFrame.new(0, 6, 14) }, Terrain = terra }, {
		__index = function(_, k)
			if k == "FindFirstChild" then
				return function(_, nome)
					return if nome == "BB_VFX" then pastaVFX else nil
				end
			end
			return nil
		end,
	})
	local VFX = H.moduloNovo("ReplicatedStorage/BB/Cliente/VFX")
	H.extras.Instance = nil
	H.extras.workspace = nil
	local V3, cor = roblox.Vector3.new, roblox.Color3.fromRGB(170, 90, 255)
	local pos, dir = V3(0, 3, 0), V3(0, 0, -1)
	for nivel = 1, 3 do
		VFX.impacto(pos, dir, cor, nivel)
	end
	VFX.impacto(pos, nil, cor, 2)
	VFX.estouroAr(pos, dir, cor, true)
	VFX.pressao(pos, dir, cor)
	VFX.guarda(pos, dir, cor)
	VFX.parry(pos, cor)
	VFX.invocar(pos, cor)
	VFX.clash(pos, cor, roblox.Color3.fromRGB(255, 200, 60))
	VFX.tempo(pos, cor, roblox.Color3.fromRGB(255, 200, 60), 150)
	VFX.tempoVolta(pos, cor, 34)
	VFX.anel(pos, cor, 6, 0.2, V3(0, 1, 0))
	VFX.anel(pos, cor, 6, 0.2, V3(0, -1, 0))
	local pecas = 0
	for _, p in pastaVFX:GetChildren() do
		pecas += 1
		assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow, "peça de efeito encosta: " .. p.Name)
		local c = p.CFrame.Position
		assert(c.X == c.X and c.Y == c.Y and c.Z == c.Z, "posição NaN")
	end
	assert(pecas > 60 and emitidas > 0, "efeitos criados: " .. pecas .. " peças, " .. emitidas .. " partículas")
	-- teto: uma chuva de impactos não passa do limite de peças vivas
	for _ = 1, 60 do
		VFX.impacto(pos, dir, cor, 3)
	end
	assert(VFX.vivos() <= 320, "teto de peças: " .. VFX.vivos())
	-- qualidade baixa cria menos
	VFX.qualidade(false)
	local antes = VFX.vivos()
	VFX.impacto(pos, dir, cor, 1)
	assert(VFX.vivos() - antes <= 320, "baixa")
end)

teste("mapa Morioh intacto: a simplificação não roda no servidor (regra do plano)", function()
	assert(Config.SIMPLIFICAR_MAPA == false, "Config.SIMPLIFICAR_MAPA tem que ser false")
	local fonte = H.fonte("ServerScriptService/BB_Servidor/Mapa")
	assert(string.find(fonte, "if Config.SIMPLIFICAR_MAPA then", 1, true), "o servidor só simplifica se a opção estiver ligada")
end)

print("== instalador")
teste("Config tem os IDs do jogo novo", function()
	assert(Config.UNIVERSE_ID == 10774214555 and Config.PLACE_ID == 108061345551908 and Config.DONO_USERID == 1357078972)
	assert(string.match(Config.REVISAO, "^AJUSTE%-%d+$"), Config.REVISAO)
end)

print(string.format("\n%d testes, %d falhas", total, falhas))
if falhas > 0 then
	error("TESTES FALHARAM")
end
print("TUDO OK")
