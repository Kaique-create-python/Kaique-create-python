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

	-- MAIS ANIME (versões originais) -----------------------------------------------
	npc("rubber_pirate", "Pirata Elástico", "m", { "pirata elastico", "luffy", "one piece", "monkey d luffy", "zoro", "nami", "pirata de borracha", "homem borracha" }, {
		model = "figure", variant = "rubber_pirate", faction = A, hp = 900, speed = 24, dmg = 22, attacks = { "stretch_punch", "melee", "charge" },
	}, { "good", "humanoid", "hero", "anime" }, { maxCount = 3 }),
	npc("demon_hunter", "Caçador de Demônios", "m", { "cacador de demonios", "demon slayer", "kimetsu", "kimetsu no yaiba", "tanjiro", "nezuko", "zenitsu", "inosuke", "hashira" }, {
		model = "figure", variant = "demon_hunter", faction = A, hp = 800, speed = 26, dmg = 22, element = "water", attacks = { "water_slash", "melee", "charge" },
	}, { "good", "humanoid", "warrior", "anime" }, { maxCount = 3 }),
	npc("curse_sorcerer", "Feiticeiro Amaldiçoado", "m", { "feiticeiro amaldicoado", "jujutsu kaisen", "jujutsu", "jjk", "gojo", "satoru gojo", "itadori", "yuji itadori", "sukuna", "megumi" }, {
		model = "figure", variant = "curse_sorcerer", faction = A, hp = 1000, speed = 24, dmg = 24, element = "shadow", attacks = { "energy_beam", "blink", "melee" }, aura = true,
	}, { "good", "humanoid", "magic", "anime" }, { maxCount = 2 }),
	npc("titan_giant", "Titã Colossal", "m", { "tita colossal", "tita", "titan", "titas", "ataque dos titas", "attack on titan", "shingeki", "shingeki no kyojin", "eren", "eren yeager" }, {
		model = "figure", variant = "titan_giant", faction = H, hp = 4200, speed = 12, dmg = 40, size = 4, attacks = { "stomp", "melee" },
	}, { "evil", "humanoid", "giant", "monster", "anime" }, { maxCount = 1, lifetime = 90 }),
	npc("hero_student", "Aluno Herói", "m", { "aluno heroi", "my hero academia", "boku no hero", "deku", "izuku", "all might", "bakugo", "todoroki", "escola de herois" }, {
		model = "figure", variant = "hero_student", faction = A, hp = 800, speed = 26, dmg = 22, element = "electric", attacks = { "stretch_punch", "charge", "melee" }, aura = true,
	}, { "good", "humanoid", "hero", "anime" }, { maxCount = 3 }),
	npc("soul_reaper", "Ceifador de Almas", "m", { "ceifador de almas", "bleach", "ichigo", "ichigo kurosaki", "ceifador", "shinigami", "zanpakuto" }, {
		model = "figure", variant = "soul_reaper", faction = A, hp = 1000, speed = 26, dmg = 24, element = "shadow", attacks = { "energy_beam", "water_slash", "melee" },
	}, { "good", "humanoid", "warrior", "anime" }, { maxCount = 2 }),
	npc("moon_warrior", "Guerreira da Lua", "f", { "guerreira da lua", "sailor moon", "guerreira lunar", "garota magica", "magical girl" }, {
		model = "figure", variant = "moon_warrior", faction = A, hp = 600, speed = 24, dmg = 18, element = "light", attacks = { "bolt", "heal" }, fly = true,
	}, { "good", "humanoid", "magic", "anime" }, { maxCount = 3 }),
	npc("robot_cat", "Gato Robô do Futuro", "m", { "gato robo do futuro", "gato robo", "doraemon", "gato do futuro" }, {
		model = "figure", variant = "robot_cat", faction = "pet", hp = 500, speed = 18, dmg = 10, attacks = { "gift", "bolt" }, giftKind = "food",
	}, { "good", "machine", "cute" }, { maxCount = 2 }),
	npc("chainsaw_man", "Homem Motosserra", "m", { "homem motosserra", "chainsaw man", "denji", "motosserra humana" }, {
		model = "figure", variant = "chainsaw_man", faction = A, hp = 900, speed = 24, dmg = 26, attacks = { "melee", "charge" },
	}, { "humanoid", "warrior", "anime" }, { maxCount = 2 }),
	npc("monster_trainer", "Treinador de Monstrinhos", "m", { "treinador de monstrinhos", "treinador pokemon", "treinador de pokemon", "ash", "ash ketchum", "mestre pokemon" }, {
		model = "figure", variant = "monster_trainer", faction = A, hp = 300, speed = 20, dmg = 6, attacks = { "summon", "melee" }, summon = { "electric_mouse", "dragon", "turtle", "fox" },
	}, { "good", "humanoid", "anime" }, { maxCount = 2 }),
	npc("nine_tail_fox", "Raposa de Nove Caudas", "f", { "raposa de nove caudas", "kurama", "kyuubi", "nove caudas", "raposa demonio" }, {
		model = "quadruped", variant = "fox", faction = H, hp = 2600, speed = 26, dmg = 30, size = 3, element = "fire", attacks = { "breath", "charge", "melee" },
	}, { "beast", "monster", "evil", "anime" }, { maxCount = 1, lifetime = 85 }),

	-- DESENHOS (versões originais) ----------------------------------------------------
	npc("alien_watch_hero", "Herói Alienígena", "m", { "heroi alienigena", "ben 10", "ben ten", "omnitrix", "relogio alienigena" }, {
		model = "figure", variant = "alien_watch_hero", faction = A, hp = 500, speed = 22, dmg = 16, attacks = { "summon", "melee" }, summon = { "alien", "golem", "werewolf", "dinosaur", "robot" },
	}, { "good", "humanoid", "hero" }, { maxCount = 2 }),
	npc("sea_sponge", "Esponja do Mar", "f", { "esponja do mar", "bob esponja", "spongebob", "esponja" }, {
		model = "meme", variant = "sea_sponge", faction = N, hp = 300, speed = 20, dmg = 8, element = "water", attacks = { "bolt", "sing" },
	}, { "funny", "water", "cute" }, { maxCount = 4 }),
	npc("starfish", "Estrela-do-Mar", "f", { "estrela do mar", "patrick", "patrick estrela", "starfish" }, {
		model = "meme", variant = "starfish", faction = N, hp = 260, speed = 12, dmg = 10, attacks = { "melee" },
	}, { "funny", "water", "animal" }, { maxCount = 6 }),
	npc("woodpecker", "Pica-Pau Maluco", "m", { "pica pau maluco", "pica pau", "woodpecker", "passaro maluco" }, {
		model = "bird", variant = "woodpecker", faction = N, hp = 120, speed = 26, dmg = 8, fly = true, attacks = { "melee", "charge" }, size = 0.9,
	}, { "animal", "flying", "funny" }, { maxCount = 6 }),
	npc("bunny_girl", "Menina do Coelhinho", "f", { "menina do coelhinho", "monica", "turma da monica", "sansao", "menina forte" }, {
		model = "figure", variant = "bunny_girl", faction = A, hp = 600, speed = 22, dmg = 30, attacks = { "super_punch", "melee" },
	}, { "good", "humanoid", "funny" }, { maxCount = 2 }),

	-- GAMES DE TERROR (versões originais) ------------------------------------------------
	npc("tall_shadow", "Sombra Alta", "m", { "sombra alta", "enderman", "slenderman", "slender", "siren head", "homem alto", "sombra" }, {
		model = "figure", variant = "tall_shadow", faction = H, hp = 600, speed = 18, dmg = 18, element = "shadow", attacks = { "blink", "melee" }, size = 1.4,
	}, { "evil", "monster", "humanoid" }, { maxCount = 3 }),
	npc("scary_granny", "Vovó Assustadora", "f", { "vovo assustadora", "granny", "vovo malvada", "velha assustadora" }, {
		model = "figure", variant = "scary_granny", faction = H, hp = 500, speed = 16, dmg = 20, attacks = { "melee", "charge" },
	}, { "evil", "monster", "humanoid" }, { maxCount = 2 }),

	-- VIDA REAL ---------------------------------------------------------------------------
	npc("boxer", "Lutador de Boxe", "m", { "lutador de boxe", "boxeador", "boxe", "lutador", "lutador de mma", "mma", "ufc", "boxer", "fighter" }, {
		model = "figure", variant = "boxer", faction = A, hp = 700, speed = 22, dmg = 26, attacks = { "melee", "charge" },
	}, { "good", "humanoid", "sport" }, { maxCount = 4 }),
	npc("singer", "Cantor", "m", { "cantor", "cantora", "rockstar", "estrela do rock", "rapper", "funkeiro", "mc", "pop star", "popstar", "artista" }, {
		model = "figure", variant = "singer", faction = N, hp = 250, speed = 18, dmg = 6, attacks = { "sing" },
	}, { "humanoid", "music", "funny" }, { maxCount = 3 }),
	npc("dj", "DJ", "m", { "dj", "deejay", "dj de festa" }, {
		model = "figure", variant = "dj", faction = N, hp = 250, speed = 16, dmg = 6, attacks = { "sing" }, behavior = "dance",
	}, { "humanoid", "music" }, { maxCount = 2 }),
	npc("skater", "Skatista", "m", { "skatista", "skater" }, {
		model = "figure", variant = "skater", faction = N, hp = 220, speed = 32, dmg = 8, attacks = { "charge", "melee" },
	}, { "humanoid", "sport" }, { maxCount = 5 }),
	npc("surfer", "Surfista", "m", { "surfista", "surf", "surfer", "prancha de surf" }, {
		model = "figure", variant = "surfer", faction = N, hp = 220, speed = 22, dmg = 8, element = "water", attacks = { "melee" },
	}, { "humanoid", "sport", "water" }, { maxCount = 5 }),
	npc("magician", "Mágico", "m", { "magico", "ilusionista", "magician", "magico de cartola" }, {
		model = "figure", variant = "magician", faction = A, hp = 300, speed = 18, dmg = 12, element = "light", attacks = { "summon", "bolt" }, summon = { "rabbit", "bird", "dog" },
	}, { "good", "humanoid", "magic" }, { maxCount = 3 }),
	npc("gamer", "Gamer", "m", { "gamer", "youtuber", "streamer", "influencer", "tiktoker", "jogador de videogame", "pro player" }, {
		model = "figure", variant = "gamer", faction = N, hp = 200, speed = 20, dmg = 6, attacks = { "gift", "melee" }, giftKind = "food",
	}, { "humanoid", "funny" }, { maxCount = 4 }),
	npc("builder", "Pedreiro", "m", { "pedreiro", "construtor", "engenheiro", "obreiro", "trabalhador" }, {
		model = "figure", variant = "builder", faction = N, hp = 300, speed = 16, dmg = 14, attacks = { "melee" },
	}, { "humanoid" }, { maxCount = 5 }),
	npc("ballerina", "Bailarina", "f", { "bailarina", "ballerina", "bailarino", "dancarina de bale" }, {
		model = "figure", variant = "ballerina", faction = N, hp = 220, speed = 22, dmg = 8, attacks = { "whirlwind" },
	}, { "humanoid", "music", "cute" }, { maxCount = 4 }),
	npc("basketball_player", "Jogador de Basquete", "m", { "jogador de basquete", "basquete", "basquetebol", "nba", "michael jordan", "lebron", "lebron james" }, {
		model = "figure", variant = "basketball_player", faction = N, hp = 260, speed = 26, dmg = 6, attacks = { "gift" }, giftKind = "ball",
	}, { "humanoid", "sport" }, { maxCount = 5 }),
	npc("grandma", "Vovó", "f", { "vovo", "avo", "vovozinha", "grandma", "vovo fofa", "avozinha" }, {
		model = "figure", variant = "grandma", faction = A, hp = 200, speed = 10, dmg = 2, attacks = { "gift", "heal" }, giftKind = "food",
	}, { "good", "humanoid", "cute" }, { maxCount = 2 }),
	npc("giant_baby", "Bebê Gigante", "m", { "bebe gigante", "bebezao", "nenem gigante", "giant baby" }, {
		model = "figure", variant = "giant_baby", faction = N, hp = 1500, speed = 10, dmg = 20, size = 2.6, attacks = { "stomp" },
	}, { "humanoid", "giant", "funny" }, { maxCount = 1 }),

	-- MAIS ANIMAIS -----------------------------------------------------------------------
	npc("zebra", "Zebra", "f", { "zebra", "zebras" }, { model = "quadruped", variant = "zebra", faction = N, hp = 240, speed = 26, dmg = 10, attacks = { "charge" }, size = 1.1 }, { "animal", "prey" }, { maxCount = 8 }),
	npc("hippo", "Hipopótamo", "m", { "hipopotamo", "hipo", "hippo", "hipopotamos" }, { model = "quadruped", variant = "hippo", faction = N, hp = 900, speed = 12, dmg = 22, attacks = { "charge", "melee" }, size = 1.5 }, { "animal", "giant", "water" }, { maxCount = 3 }),
	npc("koala", "Coala", "m", { "coala", "koala", "coalas" }, { model = "quadruped", variant = "koala", faction = N, hp = 120, speed = 8, dmg = 3, attacks = { "melee" }, size = 0.6 }, { "animal", "cute" }, { maxCount = 8 }),
	npc("camel", "Camelo", "m", { "camelo", "dromedario", "camel", "camelos" }, { model = "quadruped", variant = "camel", faction = N, hp = 400, speed = 18, dmg = 8, attacks = { "charge" }, size = 1.3 }, { "animal", "desert" }, { maxCount = 5 }),
	npc("llama", "Lhama", "f", { "lhama", "alpaca", "llama", "lhamas" }, { model = "quadruped", variant = "llama", faction = N, hp = 200, speed = 18, dmg = 4, attacks = { "bolt", "melee" }, size = 1 }, { "animal", "cute" }, { maxCount = 8 }),
	npc("hyena", "Hiena", "f", { "hiena", "hyena", "hienas" }, { model = "quadruped", variant = "hyena", faction = H, hp = 160, speed = 24, dmg = 11, attacks = { "melee", "charge" }, size = 0.95 }, { "animal", "beast", "predator" }, { maxCount = 8 }),
	npc("cheetah", "Guepardo", "m", { "guepardo", "chita", "cheetah", "guepardos" }, { model = "quadruped", variant = "cheetah", faction = H, hp = 200, speed = 40, dmg = 14, attacks = { "charge", "melee" }, size = 1 }, { "animal", "beast", "predator" }, { maxCount = 5 }),
	npc("anteater", "Tamanduá", "m", { "tamandua", "tamandua bandeira", "anteater" }, { model = "quadruped", variant = "anteater", faction = N, hp = 260, speed = 12, dmg = 10, attacks = { "melee" }, size = 1 }, { "animal", "brazil" }, { maxCount = 5 }),
	npc("armadillo", "Tatu", "m", { "tatu", "tatu bola", "armadillo", "tatus" }, { model = "quadruped", variant = "armadillo", faction = N, hp = 300, speed = 14, dmg = 6, attacks = { "charge" }, size = 0.7 }, { "animal", "brazil", "cute" }, { maxCount = 8 }),

	-- COMBINAÇÕES PRONTAS --------------------------------------------------------------
	{ id = "circus", label = "Circo", gender = "m", category = "disaster", handler = "composite", aliases = { "circo", "circus", "show de circo", "picadeiro" },
		params = { compose = { { id = "clown", count = 3 }, { id = "lion", count = 1 }, { id = "elephant", count = 1 }, { id = "party", count = 1 } } }, tags = { "fun" }, maxCount = 1, lifetime = 70 },
	{ id = "world_cup", label = "Copa do Mundo", gender = "f", category = "disaster", handler = "composite", aliases = { "copa do mundo", "copa", "final da copa", "partida de futebol", "jogo de futebol" },
		params = { compose = { { id = "footballer", count = 6 }, { id = "fireworks", count = 1 } } }, tags = { "sport" }, maxCount = 1, lifetime = 70 },
	{ id = "anime_battle", label = "Batalha de Anime", gender = "f", category = "disaster", handler = "composite", aliases = { "batalha de anime", "luta de anime", "anime battle", "torneio de anime" },
		params = { compose = { { id = "energy_warrior", count = 1 }, { id = "energy_tyrant", count = 1 } }, links = { { type = "rivals", a = 1, b = 2 } } }, tags = { "anime" }, maxCount = 1, lifetime = 80 },
	{ id = "birthday_party", label = "Festa de Aniversário", gender = "f", category = "disaster", handler = "composite", aliases = { "festa de aniversario", "parabens", "parabens pra voce", "happy birthday" },
		params = { compose = { { id = "cake", count = 1 }, { id = "party", count = 1 }, { id = "gift", count = 3 } } }, tags = { "fun" }, maxCount = 1, lifetime = 60 },
	{ id = "meme_apocalypse", label = "Apocalipse dos Memes", gender = "m", category = "disaster", handler = "composite", aliases = { "apocalipse dos memes", "brainrot", "italian brainrot", "memes italianos", "invasao de memes" },
		params = { compose = { { id = "tum_tum_log", count = 2 }, { id = "skate_shark", count = 1 }, { id = "croco_bomber", count = 1 } } }, tags = { "funny" }, maxCount = 1, lifetime = 70 },
	{ id = "hero_team", label = "Equipe de Heróis", gender = "f", category = "disaster", handler = "composite", aliases = { "equipe de herois", "vingadores", "avengers", "liga da justica", "justice league", "time de herois" },
		params = { compose = { { id = "caped_flyer", count = 1 }, { id = "bat_hero", count = 1 }, { id = "amazon_warrior", count = 1 }, { id = "spider_hero", count = 1 } } }, tags = { "hero" }, maxCount = 1, lifetime = 80 },

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
