--!strict
-- Personagens pedidos pelo NOME (heróis de desenho, anime, games, memes, mitologia).
--
-- Regra de direitos autorais: o jogo RECONHECE o nome digitado, mas cria uma
-- versão ORIGINAL inspirada no tipo de personagem (poderes parecidos, visual e
-- nome próprios). Ex.: "goku" -> Guerreiro de Energia (raio de energia, aura),
-- "naruto" -> Ninja das Sombras (clones), "saitama" -> Herói Careca (soco supremo).
-- Usar o nome/visual oficial poderia fazer o Roblox remover o jogo.
--
-- Nomes religiosos ("jesus", "deus"...) viram a Luz Celestial: um acontecimento
-- respeitoso (cura e paz), sem corpo, sem combate e sem modificadores.

local function npc(id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = "creature",
		handler = "npc",
		aliases = aliases,
		params = params,
		tags = tags,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

local H, A, N = "hostile", "ally", "neutral"

return {
	-- ANIME ------------------------------------------------------------------
	npc("energy_warrior", "Guerreiro de Energia", "m", {
		"guerreiro de energia", "lutador de energia", "goku", "kakaroto", "vegeta", "gohan", "goten", "trunks", "broly",
		"super saiyajin", "saiyajin", "sayajin", "super sayajin", "saiyan", "super saiyan", "dragon ball", "dragon ball z",
		"dbz", "kamehameha", "lutador de anime", "personagem de anime", "anime",
	}, {
		model = "figure", variant = "energy_warrior", faction = A, hp = 900, speed = 26, dmg = 26, fly = true, element = "electric",
		attacks = { "energy_beam", "melee", "charge" }, aura = true,
	}, { "good", "humanoid", "hero", "anime" }, { maxCount = 3, lifetime = 90 }),
	npc("energy_tyrant", "Tirano de Energia", "m", {
		"tirano de energia", "freeza", "frieza", "cell", "majin boo", "buu", "madara", "orochimaru", "vilao de anime",
	}, {
		model = "figure", variant = "energy_tyrant", faction = H, hp = 1100, speed = 22, dmg = 24, fly = true, element = "shadow",
		attacks = { "energy_beam", "bolt", "melee" }, aura = true,
	}, { "evil", "humanoid", "anime", "boss" }, { maxCount = 2, lifetime = 90 }),
	npc("shadow_ninja", "Ninja das Sombras", "m", {
		"ninja das sombras", "naruto", "naruto uzumaki", "sasuke", "sasuke uchiha", "kakashi", "itachi", "boruto", "hinata",
		"jiraiya", "minato", "hokage", "rasengan", "chidori", "jutsu", "kage bunshin", "clone das sombras", "clones das sombras",
		"ninja de anime",
	}, {
		model = "figure", variant = "shadow_ninja", faction = A, hp = 520, speed = 30, dmg = 18, element = "wind",
		attacks = { "clones", "melee", "charge", "bolt" },
	}, { "good", "humanoid", "warrior", "anime" }, { maxCount = 3, lifetime = 90 }),
	npc("bald_hero", "Herói Careca", "m", {
		"heroi careca", "saitama", "one punch", "one punch man", "onepunch", "onepunchman", "soco supremo", "heroi de um soco",
		"careca", "carequinha",
	}, {
		model = "figure", variant = "bald_hero", faction = A, hp = 6000, speed = 20, dmg = 30, attacks = { "super_punch", "melee" },
	}, { "good", "humanoid", "hero", "anime" }, { maxCount = 1, lifetime = 90 }),

	-- SUPER-HERÓIS (versões originais) ----------------------------------------
	npc("spider_hero", "Herói Aranha", "m", {
		"heroi aranha", "homem aranha", "spiderman", "spider man", "miles morales", "peter parker", "mulher aranha",
		"spider woman", "spidergirl", "aranha humana",
	}, {
		model = "figure", variant = "spider_hero", faction = A, hp = 520, speed = 28, dmg = 16, attacks = { "web", "melee", "charge" },
	}, { "good", "humanoid", "hero" }, { maxCount = 3 }),
	npc("bat_hero", "Vigilante Morcego", "m", {
		"vigilante morcego", "batman", "homem morcego", "bruce wayne", "cavaleiro das trevas", "batgirl", "mulher morcego",
	}, {
		model = "figure", variant = "bat_hero", faction = A, hp = 560, speed = 22, dmg = 20, attacks = { "melee", "bolt", "charge" },
	}, { "good", "humanoid", "hero" }, { maxCount = 3 }),
	npc("caped_flyer", "Super-Herói Voador", "m", {
		"super heroi voador", "superman", "super homem", "homem de aco", "clark kent", "supergirl", "super moca", "kal el",
	}, {
		model = "figure", variant = "caped_flyer", faction = A, hp = 1600, speed = 28, dmg = 28, fly = true,
		attacks = { "laser_eyes", "melee", "charge" },
	}, { "good", "humanoid", "hero", "flying" }, { maxCount = 2 }),
	npc("green_brute", "Brutamontes Verde", "m", {
		"brutamontes verde", "hulk", "incrivel hulk", "she hulk", "gigante verde", "monstro verde",
	}, {
		model = "figure", variant = "green_brute", faction = A, hp = 2200, speed = 20, dmg = 34, size = 1.6, attacks = { "stomp", "melee", "charge" },
	}, { "good", "humanoid", "hero", "giant" }, { maxCount = 2 }),
	npc("tech_armor", "Armadura Tecnológica", "f", {
		"armadura tecnologica", "homem de ferro", "iron man", "ironman", "tony stark", "armadura de ferro", "war machine",
		"armadura robotica",
	}, {
		model = "figure", variant = "tech_armor", faction = A, hp = 1200, speed = 26, dmg = 22, fly = true, element = "electric",
		attacks = { "laser_eyes", "bolt" },
	}, { "good", "humanoid", "hero", "machine", "flying" }, { maxCount = 2 }),
	npc("shield_hero", "Capitão Escudo", "m", {
		"capitao escudo", "capitao america", "captain america", "steve rogers", "heroi do escudo",
	}, {
		model = "figure", variant = "shield_hero", faction = A, hp = 900, speed = 22, dmg = 22, attacks = { "bolt", "melee", "charge" },
	}, { "good", "humanoid", "hero" }, { maxCount = 3 }),
	npc("amazon_warrior", "Guerreira Amazona", "f", {
		"guerreira amazona", "mulher maravilha", "wonder woman", "amazona", "diana prince",
	}, {
		model = "figure", variant = "amazon_warrior", faction = A, hp = 1100, speed = 24, dmg = 24, fly = true, element = "light",
		attacks = { "melee", "charge", "bolt" },
	}, { "good", "humanoid", "hero", "myth" }, { maxCount = 2 }),

	-- MITOLOGIA (domínio público) ---------------------------------------------
	npc("thunder_god", "Deus do Trovão", "m", {
		"deus do trovao", "thor", "zeus", "odin", "deus grego", "deus nordico", "deus viking",
	}, {
		model = "figure", variant = "thunder_god", faction = A, hp = 1800, speed = 22, dmg = 30, fly = true, element = "electric",
		attacks = { "lightning_call", "melee" }, size = 1.3,
	}, { "good", "humanoid", "myth", "flying" }, { maxCount = 1, lifetime = 90 }),
	npc("medusa", "Medusa", "f", { "medusa", "gorgona", "gorgon" }, {
		model = "figure", variant = "medusa", faction = H, hp = 520, speed = 14, dmg = 14, element = "poison", attacks = { "petrify", "bolt" },
	}, { "evil", "humanoid", "myth", "monster" }, { maxCount = 2 }),
	npc("minotaur", "Minotauro", "m", { "minotauro", "minotaur", "homem touro" }, {
		model = "figure", variant = "minotaur", faction = H, hp = 900, speed = 18, dmg = 26, size = 1.5, attacks = { "charge", "melee", "stomp" },
	}, { "evil", "humanoid", "myth", "monster", "giant" }, { maxCount = 2 }),
	npc("spartan", "Guerreiro Espartano", "m", {
		"guerreiro espartano", "espartano", "spartan", "kratos", "leonidas", "gladiador", "gladiator", "god of war",
	}, {
		model = "figure", variant = "spartan", faction = A, hp = 700, speed = 20, dmg = 24, attacks = { "melee", "charge", "bolt" },
	}, { "good", "humanoid", "warrior", "myth" }, { maxCount = 5 }),
	npc("ice_queen", "Rainha do Gelo", "f", {
		"rainha do gelo", "rainha da neve", "snow queen", "ice queen", "elsa", "frozen",
	}, {
		model = "figure", variant = "ice_queen", faction = A, hp = 700, speed = 18, dmg = 18, element = "ice", attacks = { "bolt", "breath" },
	}, { "good", "humanoid", "magic", "ice" }, { maxCount = 2 }),

	-- GAMES (versões originais) ------------------------------------------------
	npc("plumber", "Encanador Saltitante", "m", {
		"encanador saltitante", "encanador", "plumber", "mario", "super mario", "mario bros", "luigi",
	}, {
		model = "figure", variant = "plumber", faction = A, hp = 400, speed = 24, dmg = 18, attacks = { "stomp", "melee" },
	}, { "good", "humanoid", "funny" }, { maxCount = 4 }),
	npc("noob", "Noob Clássico", "m", { "noob classico", "noob", "noob do roblox", "roblox noob", "nub" }, {
		model = "figure", variant = "noob", faction = N, hp = 120, speed = 16, dmg = 4, attacks = { "melee" },
	}, { "humanoid", "funny" }, { maxCount = 10 }),
	npc("speed_hedgehog", "Ouriço Veloz", "m", {
		"ourico veloz", "ourico", "porco espinho", "hedgehog", "sonic", "sonic the hedgehog", "knuckles",
	}, {
		model = "meme", variant = "speed_hedgehog", faction = A, hp = 300, speed = 48, dmg = 14, attacks = { "charge", "melee" }, size = 0.9,
	}, { "animal", "good", "funny" }, { maxCount = 4 }),
	npc("electric_mouse", "Ratinho Elétrico", "m", {
		"ratinho eletrico", "rato eletrico", "pikachu", "pokemon", "pichu", "raichu",
	}, {
		model = "meme", variant = "electric_mouse", faction = "pet", hp = 260, speed = 24, dmg = 14, element = "electric",
		attacks = { "lightning_call", "melee" }, size = 0.7,
	}, { "animal", "good", "cute" }, { maxCount = 5 }),
	npc("boom_bush", "Arbusto-Bomba", "m", { "arbusto bomba", "arbusto explosivo", "creeper", "creepers", "moita explosiva" }, {
		model = "meme", variant = "boom_bush", faction = H, hp = 80, speed = 15, dmg = 40, attacks = { "self_destruct" },
	}, { "monster", "evil", "funny" }, { maxCount = 8 }),
	npc("animatronic_bear", "Urso Animatrônico", "m", {
		"urso animatronico", "animatronico", "animatronic", "freddy", "freddy fazbear", "fnaf", "five nights at freddys", "bonnie", "foxy",
	}, {
		model = "meme", variant = "animatronic_bear", faction = H, hp = 500, speed = 14, dmg = 18, attacks = { "melee", "charge" }, size = 1.2,
	}, { "machine", "evil", "monster" }, { maxCount = 3 }),
	npc("plush_monster", "Monstro de Pelúcia", "m", {
		"monstro de pelucia", "huggy wuggy", "huggy", "kissy missy", "poppy playtime", "pelucia assustadora",
	}, {
		model = "meme", variant = "plush_monster", faction = H, hp = 600, speed = 18, dmg = 18, attacks = { "melee", "charge" }, size = 1.5,
	}, { "monster", "evil" }, { maxCount = 2 }),
	npc("singing_toilet", "Privada Cantora", "f", { "privada cantora", "skibidi", "skibidi toilet", "vaso cantor", "privada que canta" }, {
		model = "meme", variant = "singing_toilet", faction = N, hp = 200, speed = 14, dmg = 8, attacks = { "sing", "melee" },
	}, { "funny", "monster" }, { maxCount = 6 }),

	-- MEMES "BRAINROT" (versões originais) -------------------------------------
	npc("tum_tum_log", "Tronco Tum-Tum", "m", {
		"tronco tum tum", "tung tung tung sahur", "tung tung sahur", "tung tung tung", "tung tung", "tung sahur", "sahur",
		"tum tum tum", "tum tum", "tun tun tun sahur", "tun tun sahur", "ta ta ta sahur",
	}, {
		model = "meme", variant = "tum_tum_log", faction = H, hp = 400, speed = 18, dmg = 18, attacks = { "drum", "melee" },
	}, { "funny", "monster", "brainrot" }, { maxCount = 4 }),
	npc("skate_shark", "Tubarão Patinador", "m", {
		"tubarao patinador", "tralalero tralala", "tralalelo tralala", "trallalero trallala", "tralalero", "tralalelo",
		"trallalero", "tralala", "tubarao de tenis", "tubarao com pernas", "tubarao de patins",
	}, {
		model = "meme", variant = "skate_shark", faction = N, hp = 450, speed = 34, dmg = 16, attacks = { "charge", "sing", "melee" },
	}, { "funny", "brainrot", "water" }, { maxCount = 4 }),
	npc("croco_bomber", "Crocodilo Bombardeiro", "m", {
		"crocodilo bombardeiro", "bombardiro crocodilo", "bombardino crocodilo", "bombardilo crocodilo", "bombardiro",
	}, {
		model = "meme", variant = "croco_bomber", faction = H, hp = 700, speed = 26, dmg = 22, fly = true, attacks = { "bomb_drop" },
		size = 1.2,
	}, { "funny", "brainrot", "flying", "machine" }, { maxCount = 2, lifetime = 75 }),
	npc("coffee_ballerina", "Bailarina Cappuccino", "f", {
		"bailarina cappuccino", "ballerina cappuccina", "ballerina capuccina", "bailarina cappuccina", "bailarina capuccino",
		"bailarina de cafe", "cappuccina",
	}, {
		model = "meme", variant = "coffee_ballerina", faction = N, hp = 300, speed = 22, dmg = 12, attacks = { "whirlwind", "melee" },
		behavior = "dance",
	}, { "funny", "brainrot", "food" }, { maxCount = 4 }),
	npc("banana_monkey", "Macaco Banana", "m", {
		"macaco banana", "chimpanzini bananini", "chimpanzini", "bananini", "macaco de banana",
	}, {
		model = "meme", variant = "banana_monkey", faction = N, hp = 260, speed = 22, dmg = 10, attacks = { "bolt", "melee" }, boltColor = "banana",
	}, { "funny", "brainrot", "food", "animal" }, { maxCount = 5 }),
	npc("cactus_elephant", "Elefante Cacto", "m", {
		"elefante cacto", "elefante de cacto", "lirili larila", "lirili", "larila",
	}, {
		model = "meme", variant = "cactus_elephant", faction = N, hp = 800, speed = 12, dmg = 20, attacks = { "stomp", "bolt" }, size = 1.2,
		element = "nature",
	}, { "funny", "brainrot", "animal", "nature" }, { maxCount = 3 }),

	-- JESUS: aparece como personagem, sempre com respeito. Não luta, não pode
	-- ser atacado, não aceita modificadores, híbridos nem cadeias (sacred).
	npc("jesus", "Jesus", "m", { "jesus", "jesus cristo", "cristo", "jesus de nazare", "messias", "cristo redentor" }, {
		model = "figure", variant = "jesus", faction = "ally", hp = 100000, speed = 12, dmg = 0, attacks = { "heal" },
		invulnerable = true, calmAura = 45, glow = true,
	}, { "good", "humanoid", "holy" }, { maxCount = 1, lifetime = 90, sacred = true, noFusion = true }),

	-- GIGANTE: escrever "gigante" faz aparecer um gigante
	npc("giant", "Gigante", "m", { "gigante", "giant", "o gigante", "homem gigante", "gigante da montanha" }, {
		model = "figure", variant = "giant_man", faction = N, hp = 2600, speed = 14, dmg = 32, size = 3, attacks = { "stomp", "melee" },
	}, { "humanoid", "giant" }, { maxCount = 2, lifetime = 80 }),

	-- NOME DESCONHECIDO: personagem com o nome digitado (filtrado pelo Roblox) --
	npc("mystery_person", "Personagem Misterioso", "m", { "personagem misterioso", "personagem", "pessoa misteriosa", "desconhecido" }, {
		model = "figure", variant = "custom", faction = N, hp = 260, speed = 18, dmg = 10, attacks = { "melee" },
	}, { "humanoid" }, { maxCount = 3, noFusion = true }),

	-- SAGRADO: respeitoso, sem corpo, sem combate --------------------------------
	{
		id = "sacred_light",
		label = "Luz Celestial",
		gender = "f",
		category = "magic",
		handler = "blessing",
		sacred = true,
		noFusion = true,
		aliases = {
			"luz celestial", "luz divina", "deus", "god", "senhor deus", "allah", "buda", "buddha",
			"virgem maria", "nossa senhora", "espirito santo", "abencoar", "oracao", "orar", "rezar", "amem",
			"aleluia", "paraiso", "ceu divino",
		},
		params = { radius = 70, calm = 20 },
		tags = { "good", "holy" },
		lifetime = 14,
	},
}
