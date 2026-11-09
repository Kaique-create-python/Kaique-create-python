--!strict
-- Casos de teste do interpretador. Rodam no Lune (offline) e na nuvem
-- (Luau Execution API) com o mesmo código.
-- expect.events[i]: concept, mods (todos presentes), count, requested, rain, payload, faction
-- expect.links: lista de {type, a = conceito, b = conceito}
-- expect.secrets, expect.surprise, expect.location, expect.label

local Spec = {}

Spec.cases = {
	-- básicos e variações de escrita
	{ input = "dragão", expect = { events = { { concept = "dragon", count = 1 } }, label = "Dragão" } },
	{ input = "dragao", expect = { events = { { concept = "dragon" } } } },
	{ input = "DRAGÃO!!!", expect = { events = { { concept = "dragon" } } } },
	{ input = "dargão", expect = { events = { { concept = "dragon" } } } },
	{ input = "dragon", expect = { events = { { concept = "dragon" } } } },
	{ input = "dragões", expect = { events = { { concept = "dragon", count = 3 } } } },
	{ input = "buraco negro", expect = { events = { { concept = "black_hole" } } } },
	{ input = "black hole", expect = { events = { { concept = "black_hole" } } } },
	{ input = "buracos negros", expect = { events = { { concept = "black_hole" } } } },
	{ input = "televisão", expect = { events = { { concept = "tv" } } } },
	{ input = "herói", expect = { events = { { concept = "hero" } } } },
	{ input = "demônio", expect = { events = { { concept = "demon" } } } },
	{ input = "tsunami", expect = { events = { { concept = "tsunami" } } } },
	{ input = "casa", expect = { events = { { concept = "house" } } } },
	{ input = "carro", expect = { events = { { concept = "car" } } } },
	{ input = "chuva de meteoros", expect = { events = { { concept = "meteor_shower" } } } },
	{ input = "raio", expect = { events = { { concept = "lightning" } } } },
	{ input = "relâmpago", expect = { events = { { concept = "lightning" } } } },
	{ input = "trovão", expect = { events = { { concept = "lightning" } } } },
	{ input = "cura", expect = { events = { { concept = "heal" } } } },
	{ input = "velocidade", expect = { events = { { concept = "power_speed" } } } },

	-- modificadores
	{ input = "dragão de gelo gigante", expect = { events = { { concept = "dragon", mods = { "ice", "giant" } } }, label = "Dragão de Gelo Gigante" } },
	{ input = "giant ice dragon", expect = { events = { { concept = "dragon", mods = { "ice", "giant" } } } } },
	{ input = "dragão de fogo", expect = { events = { { concept = "dragon", mods = { "fire" } } } } },
	{ input = "tornado elétrico gigante", expect = { events = { { concept = "tornado", mods = { "electric", "giant" } } } } },
	{ input = "tornado de fogo", expect = { events = { { concept = "tornado", mods = { "fire" } } } } },
	{ input = "robô voador", expect = { events = { { concept = "robot", mods = { "flying" } } } } },
	{ input = "zumbi gigante", expect = { events = { { concept = "zombie", mods = { "giant" } } } } },
	{ input = "casa de ouro", expect = { events = { { concept = "house", mods = { "gold" } } }, label = "Casa Dourada" } },
	{ input = "meteoro congelante", expect = { events = { { concept = "meteor", mods = { "ice" } } }, secrets = { "glacial_comet" } } },
	{ input = "zumbi muito grande", expect = { events = { { concept = "zombie", mods = { "colossal" } } } } },
	{ input = "gato gigante gigante", expect = { events = { { concept = "cat", mods = { "colossal" } } } } },
	{ input = "cidade futurista", expect = { events = { { concept = "city", mods = { "futuristic" } } } } },
	{ input = "superdragão", expect = { events = { { concept = "dragon", mods = { "giant" } } } } },
	{ input = "cachorrinho", expect = { events = { { concept = "dog", mods = { "small" } } } } },
	{ input = "gatão", expect = { events = { { concept = "cat", mods = { "giant" } } } } },
	{ input = "rei zumbi", expect = { events = { { concept = "zombie", mods = { "boss" } } }, secrets = { "zombie_king" } } },
	{ input = "dragão laranja", expect = { events = { { concept = "dragon", mods = { "orange" } } } } },
	{ input = "laranja", expect = { events = { { concept = "orange_fruit" } } } },

	-- palavras sozinhas que são modificadores
	{ input = "gigante", expect = { events = { { concept = "giant" } } } },
	{ input = "ficar gigante", expect = { events = { { concept = "power_giant" } } } },
	{ input = "fogo", expect = { events = { { concept = "fire" } } } },
	{ input = "gelo", expect = { events = { { concept = "ice_burst" } } } },
	{ input = "voador", expect = { events = { { concept = "power_fly" } } } },

	-- quantidades e orçamento
	{ input = "100 zumbis", expect = { events = { { concept = "zombie", count = 12, requested = 100 } } } },
	{ input = "cem zumbis", expect = { events = { { concept = "zombie", count = 12, requested = 100 } } } },
	{ input = "horda de zumbis", expect = { events = { { concept = "zombie", count = 10 } } } },
	{ input = "3 casas", expect = { events = { { concept = "house", count = 2, requested = 3 } } } },
	{ input = "um dragão", expect = { events = { { concept = "dragon", count = 1 } } } },

	-- chuva de ...
	{ input = "chuva de pizzas", expect = { events = { { concept = "pizza", rain = true } }, secrets = { "pizza_rain" } } },
	{ input = "chuva de coxinha", expect = { events = { { concept = "coxinha", rain = true } } } },
	{ input = "chuva de fogo", expect = { events = { { concept = "meteor_shower" } } } },
	{ input = "chuva de gatos", expect = { events = { { concept = "cat", rain = true } } } },

	-- combinações e interações
	{ input = "robô e dinossauro", expect = { events = { { concept = "robot" }, { concept = "dinosaur" } }, links = { { type = "rivals", a = "dinosaur", b = "robot" } } } },
	{ input = "dinossauro e robô", expect = { events = { { concept = "dinosaur" }, { concept = "robot" } }, links = { { type = "rivals" } } } },
	{ input = "herói contra demônio", expect = { events = { { concept = "hero" }, { concept = "demon" } }, links = { { type = "rivals" } }, secrets = { "light_vs_dark" } } },
	{ input = "hero vs demon", expect = { events = { { concept = "hero" }, { concept = "demon" } }, links = { { type = "rivals" } } } },
	{ input = "dragão protegendo castelo", expect = { events = { { concept = "dragon" }, { concept = "castle" } }, links = { { type = "guard", a = "dragon", b = "castle" } }, secrets = { "castle_guardian" } } },
	{ input = "dragão me protegendo", expect = { events = { { concept = "dragon", faction = "pet" } }, links = { { type = "bodyguard" } } } },
	{ input = "zumbi no carro", expect = { events = { { concept = "zombie" }, { concept = "car" } }, links = { { type = "ride", a = "zombie", b = "car" } } } },
	{ input = "cavaleiro montando dragão", expect = { links = { { type = "ride", a = "knight", b = "dragon" } }, secrets = { "dragon_rider" } } },
	{ input = "lobo e ovelha", expect = { links = { { type = "hunt", a = "wolf", b = "sheep" } } } },
	{ input = "gato contra cachorro", expect = { links = { { type = "rivals" } }, secrets = { "classic_rivalry" } } },
	{ input = "fogo e gelo", expect = { events = { { concept = "fire" }, { concept = "ice_burst" } }, secrets = { "fire_and_ice" } } },
	{ input = "robô dinossauro", expect = { events = { { concept = "dinosaur", mods = { "robotic" } } }, secrets = { "mechasaur" } } },
	{ input = "dinossauro robô", expect = { events = { { concept = "dinosaur", mods = { "robotic" } } } } },
	{ input = "tornado de tubarões", expect = { events = { { concept = "tornado", payload = "shark" } }, secrets = { "sharknado" } } },
	{ input = "dragão, robô, zumbi, fantasma", expect = { eventCount = 4 } },
	{ input = "dragão no vulcão", expect = { events = { { concept = "dragon" } }, location = "volcano" } },
	{ input = "praia", expect = { events = { { concept = "teleport" } }, location = "beach" } },
	{ input = "invasão alienígena", expect = { events = { { concept = "ufo" }, { concept = "alien" } } } },
	{ input = "vaca voadora", expect = { events = { { concept = "cow", mods = { "flying" } } }, secrets = { "flying_cow" } } },
	{ input = "cachorro de estimação", expect = { events = { { concept = "dog", mods = { "pet" } } } } },

	-- personagens pelo nome (versões originais, sem nome/visual oficial)
	{ input = "Goku", expect = { events = { { concept = "energy_warrior" } } } },
	{ input = "Naruto", expect = { events = { { concept = "shadow_ninja" } } } },
	{ input = "Saitama", expect = { events = { { concept = "bald_hero" } } } },
	{ input = "homem aranha", expect = { events = { { concept = "spider_hero" } } } },
	{ input = "skibidi toilet", expect = { events = { { concept = "singing_toilet" } }, eventCount = 1 } },
	{ input = "Tung Tung sahur", expect = { events = { { concept = "tum_tum_log" } }, eventCount = 1 } },
	{ input = "tung tung tung sahur", expect = { events = { { concept = "tum_tum_log" } }, eventCount = 1 } },
	{ input = "Tralalelo tralala", expect = { events = { { concept = "skate_shark" } }, eventCount = 1 } },
	{ input = "tralalero tralala", expect = { events = { { concept = "skate_shark" } }, eventCount = 1 } },
	{ input = "bombardiro crocodilo", expect = { events = { { concept = "croco_bomber" } }, eventCount = 1 } },
	{ input = "goku contra freeza", expect = { links = { { type = "rivals" } }, secrets = { "energy_clash" } } },

	-- sagrado: respeitoso, sem combate, sem modificadores
	{ input = "Jesus", expect = { events = { { concept = "jesus" } }, eventCount = 1 } },
	{ input = "jesus explode", expect = { events = { { concept = "jesus", chain = {} } }, eventCount = 1 } },
	{ input = "jesus de fogo gigante", expect = { events = { { concept = "jesus", modCount = 0 } } } },
	{ input = "jesus contra demônio", expect = { events = { { concept = "jesus" }, { concept = "demon" } }, noLinks = true } },
	{ input = "jesus tubarão", expect = { events = { { concept = "jesus" } } } },
	{ input = "arma que atira jesus", expect = { events = { { concept = "blaster", chain = {} } }, eventCount = 1 } },
	{ input = "deus", expect = { events = { { concept = "sacred_light" } }, eventCount = 1 } },

	-- nomes desconhecidos viram um personagem com o nome
	{ input = "verity", expect = { events = { { concept = "mystery_person", name = "Verity" } }, label = "Verity" } },
	{ input = "Verity gigante", expect = { events = { { concept = "mystery_person", name = "Verity", mods = { "giant" } } } } },
	{ input = "verity contra dragão", expect = { events = { { concept = "mystery_person" }, { concept = "dragon" } }, links = { { type = "rivals" } } } },
	{ input = "ana beatriz", expect = { events = { { concept = "mystery_person", name = "Ana Beatriz" } } } },
	{ input = "quero algo legal", expect = { surprise = true } },

	-- cadeias de ação
	{ input = "arma que atira cachorro", expect = { events = { { concept = "blaster", chain = { "shoot:dog" } } }, eventCount = 1, secrets = { "dog_launcher" } } },
	{
		input = "Arma que atira cachorro e o cachorro caga elefante que o elefante explode",
		expect = { events = { { concept = "blaster", chain = { "shoot:dog", "spawn:elephant", "explode" } } }, eventCount = 1, secrets = { "absurd_chain" } },
	},
	{ input = "cachorro explode", expect = { events = { { concept = "dog", chain = { "explode" } } }, eventCount = 1 } },
	{ input = "galinha que bota dinossauro", expect = { events = { { concept = "chicken", chain = { "spawn:dinosaur" } } }, eventCount = 1 } },
	{ input = "vaca que vira dragão", expect = { events = { { concept = "cow", chain = { "transform:dragon" } } }, eventCount = 1 } },
	{ input = "dragão que cospe gelo", expect = { events = { { concept = "dragon", element = "ice" } }, eventCount = 1 } },
	{ input = "arma que atira fogo", expect = { events = { { concept = "blaster", element = "fire" } }, eventCount = 1 } },
	{ input = "robô dança", expect = { events = { { concept = "robot", chain = { "dance" } } }, eventCount = 1 } },
	{ input = "zumbis que explodem", expect = { events = { { concept = "zombie", chain = { "explode" } } }, eventCount = 1 } },
	{ input = "explode", expect = { events = { { concept = "explosion" } } } },
	{ input = "cria um dragão", expect = { events = { { concept = "dragon" } }, eventCount = 1 } },

	-- híbridos
	{ input = "gato tubarão", expect = { events = { { concept = "cat", fusion = "shark" } }, label = "Gato-Tubarão", secrets = { "mad_lab" } } },
	{ input = "homem tubarão", expect = { events = { { concept = "villager", fusion = "shark" } }, label = "Tubarão Humanoide" } },
	{ input = "macaco pizza", expect = { events = { { concept = "monkey", fusion = "pizza" } }, eventCount = 1 } },
	{ input = "pizza macaco", expect = { events = { { concept = "monkey", fusion = "pizza" } }, eventCount = 1 } },
	{ input = "crocodilo avião", expect = { events = { { concept = "plane", fusion = "crocodile" } }, eventCount = 1 } },
	{ input = "cachorro e gato", expect = { events = { { concept = "dog" }, { concept = "cat" } } } },

	-- palavras desconhecidas: surpresa determinística
	{ input = "xyzqwe", expect = { surprise = true } },
	{ input = "banana123", expect = { events = { { concept = "banana" } } } },
	{ input = "megassauro", expect = { surprise = true } },
	{ input = "vermelho", expect = { surprise = true } },
}

local function contains(list: { any }, value: any): boolean
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

-- Verifica um caso; retorna lista de falhas (vazia = passou)
function Spec.check(plan: any, expect: any): { string }
	local fails = {}
	if expect.events then
		for i, e in expect.events do
			local ev = plan.events[i]
			if not ev then
				table.insert(fails, string.format("evento %d ausente (esperado %s)", i, tostring(e.concept)))
			else
				if e.concept and ev.concept.id ~= e.concept then
					table.insert(fails, string.format("evento %d: conceito %s, esperado %s", i, ev.concept.id, e.concept))
				end
				for _, m in e.mods or {} do
					if not contains(ev.mods, m) then
						table.insert(fails, string.format("evento %d: falta modificador %s (tem: %s)", i, m, table.concat(ev.mods, ",")))
					end
				end
				if e.count and ev.count ~= e.count then
					table.insert(fails, string.format("evento %d: count %d, esperado %d", i, ev.count, e.count))
				end
				if e.requested and ev.requested ~= e.requested then
					table.insert(fails, string.format("evento %d: requested %s, esperado %d", i, tostring(ev.requested), e.requested))
				end
				if e.rain ~= nil and ev.rain ~= e.rain then
					table.insert(fails, string.format("evento %d: rain %s", i, tostring(ev.rain)))
				end
				if e.payload and (not ev.payload or ev.payload.id ~= e.payload) then
					table.insert(fails, string.format("evento %d: payload %s, esperado %s", i, ev.payload and ev.payload.id or "nil", e.payload))
				end
				if e.faction and ev.params.faction ~= e.faction then
					table.insert(fails, string.format("evento %d: facção %s, esperado %s", i, tostring(ev.params.faction), e.faction))
				end
				if e.chain then
					local flat = {}
					local function walk(x: any, depth: number)
						for _, a in x.actions or {} do
							if a.node then
								table.insert(flat, a.verb .. ":" .. a.node.concept.id)
								if depth < 6 then
									walk(a.node, depth + 1)
								end
							else
								table.insert(flat, a.verb)
							end
						end
					end
					walk(ev, 1)
					local got, want = table.concat(flat, ","), table.concat(e.chain, ",")
					if got ~= want then
						table.insert(fails, string.format("evento %d: cadeia '%s', esperado '%s'", i, got, want))
					end
				end
				if e.fusion and (not ev.fusion or ev.fusion.id ~= e.fusion) then
					table.insert(fails, string.format("evento %d: híbrido com %s, esperado %s", i, ev.fusion and ev.fusion.id or "nada", e.fusion))
				end
				if e.name and ev.params.customName ~= e.name then
					table.insert(fails, string.format("evento %d: nome '%s', esperado '%s'", i, tostring(ev.params.customName), e.name))
				end
				if e.element and ev.params.element ~= e.element then
					table.insert(fails, string.format("evento %d: elemento %s, esperado %s", i, tostring(ev.params.element), e.element))
				end
				if e.modCount and #ev.mods ~= e.modCount then
					table.insert(fails, string.format("evento %d: %d modificadores, esperado %d", i, #ev.mods, e.modCount))
				end
			end
		end
	end
	if expect.noLinks and #plan.links > 0 then
		table.insert(fails, string.format("%d vínculos, esperado nenhum", #plan.links))
	end
	if expect.eventCount and #plan.events ~= expect.eventCount then
		table.insert(fails, string.format("%d eventos, esperado %d", #plan.events, expect.eventCount))
	end
	for _, l in expect.links or {} do
		local found = false
		for _, pl in plan.links do
			if pl.type == l.type then
				local aId = if pl.a > 0 then plan.events[pl.a].concept.id else "owner"
				local bId = if pl.b > 0 then plan.events[pl.b].concept.id else "owner"
				if (not l.a or l.a == aId) and (not l.b or l.b == bId) then
					found = true
				end
			end
		end
		if not found then
			table.insert(fails, "vínculo ausente: " .. l.type .. " " .. tostring(l.a) .. "->" .. tostring(l.b))
		end
	end
	for _, s in expect.secrets or {} do
		if not contains(plan.secrets, s) then
			table.insert(fails, "segredo ausente: " .. s)
		end
	end
	if expect.surprise ~= nil and plan.surprise ~= expect.surprise then
		table.insert(fails, "surpresa = " .. tostring(plan.surprise))
	end
	if expect.location and (not plan.location or plan.location.id ~= expect.location) then
		table.insert(fails, "local = " .. tostring(plan.location and plan.location.id))
	end
	if expect.label and plan.label ~= expect.label then
		table.insert(fails, string.format("rótulo '%s', esperado '%s'", plan.label, expect.label))
	end
	return fails
end

-- Executa todos os testes do interpretador. deps = {Planner, Catalog, Lexicon}
function Spec.run(deps: any): { passed: number, failed: number, failures: { string } }
	local Planner, Catalog, Lexicon = deps.Planner, deps.Catalog, deps.Lexicon
	local passed, failures = 0, {}

	local function record(name: string, fails: { string })
		if #fails == 0 then
			passed += 1
		else
			table.insert(failures, name .. " => " .. table.concat(fails, "; "))
		end
	end

	-- 1) catálogo íntegro
	record("catálogo válido", Catalog.validate())
	record("sem colisões de vocabulário", Lexicon.collisions())

	-- 2) casos escritos à mão
	for _, case in Spec.cases do
		local ok, planOrErr = pcall(Planner.plan, case.input)
		if not ok then
			record("'" .. case.input .. "'", { "erro: " .. tostring(planOrErr) })
		else
			record("'" .. case.input .. "'", Spec.check(planOrErr, case.expect))
		end
	end

	-- 3) ida e volta: o rótulo de cada conceito deve ser interpretado de volta
	for _, def in Catalog.Concepts do
		local ok, plan = pcall(Planner.plan, def.label)
		local fails = {}
		if not ok then
			table.insert(fails, "erro: " .. tostring(plan))
		else
			local expectedId = def.id
			if def.handler == "composite" then
				expectedId = def.params.compose[1].id
			end
			local first = plan.events[1]
			if not first or first.concept.id ~= expectedId then
				table.insert(fails, "virou " .. (first and first.concept.id or "nada") .. (if plan.surprise then " (surpresa)" else ""))
			end
		end
		record("rótulo '" .. def.label .. "'", fails)
	end

	-- 4) cada alias deve levar ao próprio conceito
	for _, def in Catalog.Concepts do
		for _, alias in def.aliases do
			local ok, plan = pcall(Planner.plan, alias)
			if not ok then
				record("alias '" .. alias .. "'", { "erro: " .. tostring(plan) })
			else
				local ids = {}
				local hit = false
				for _, ev in plan.events do
					table.insert(ids, ev.concept.id)
					if ev.concept.id == def.id then
						hit = true
					end
				end
				if def.handler == "composite" then
					hit = hit or (plan.events[1] and plan.events[1].concept.id == def.params.compose[1].id)
				end
				-- alias de chuva/rainAs e de tempo podem mapear para variações
				record("alias '" .. alias .. "' (" .. def.id .. ")", if hit then {} else { "virou " .. table.concat(ids, ",") })
			end
		end
	end

	-- 5) determinismo: mesma entrada, mesmo plano
	for _, input in { "xyzqwe", "palavra estranha", "abcdefgh" } do
		local a, b = Planner.plan(input), Planner.plan(input)
		record("determinismo '" .. input .. "'", if a.label == b.label then {} else { a.label .. " ~= " .. b.label })
	end

	-- 6) robustez: entradas estranhas não podem gerar erro
	local weird = { "", " ", ",,,", "🐉🔥", string.rep("a", 300), "de de de de", "e e e", "x", "contra", "0", "999999999999", "-1 zumbis", "\0\1\2", "dragão de de de gelo" }
	for _, input in weird do
		local ok, err = pcall(Planner.plan, input)
		record("robustez '" .. string.sub(input, 1, 20) .. "'", if ok then {} else { tostring(err) })
	end

	return { passed = passed, failed = #failures, failures = failures }
end

return Spec
