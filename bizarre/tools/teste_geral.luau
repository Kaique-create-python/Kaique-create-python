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
			assert(type(g.voz) == "string", gid .. ": voz")
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
			local p = Animador.andarJoJo(falso, 1 / 60, vel, false)
			for junta, v in p do
				assert(Poses.JUNTAS[junta], id .. ": junta " .. junta)
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
