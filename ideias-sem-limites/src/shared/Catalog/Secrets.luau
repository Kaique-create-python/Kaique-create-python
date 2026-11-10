--!strict
-- Combinações secretas: descobertas especiais que dão título e Faíscas.
-- match:
--   concept   id do conceito de algum acontecimento do plano
--   mods      modificadores exigidos nesse acontecimento
--   payload   conceito carregado ("tornado de tubarões")
--   rain      true se for "chuva de ..."
--   concepts  lista de conceitos presentes no mesmo plano
--   link      tipo de vínculo exigido entre os conceitos da lista
--   minRequested  quantidade mínima pedida (antes do limite de desempenho)

export type Secret = {
	id: string,
	title: string,
	hint: string,
	reward: number,
	match: { [string]: any },
}

local secrets: { Secret } = {
	{ id = "golden_dragon", title = "Tesouro Alado", hint = "Um dragão feito de riqueza.", reward = 40, match = { concept = "dragon", mods = { "gold" } } },
	{ id = "winter_lord", title = "Senhor do Inverno", hint = "O maior dragão do frio.", reward = 60, match = { concept = "dragon", mods = { "ice", "giant" } } },
	{ id = "mecha_dragon", title = "Dragão Mecânico", hint = "Escamas de aço.", reward = 40, match = { concept = "dragon", mods = { "robotic" } } },
	{ id = "sharknado", title = "Tubarnado", hint = "Um tornado com recheio perigoso.", reward = 60, match = { concept = "tornado", payload = "shark" } },
	{ id = "pizza_rain", title = "Pizzaria Celeste", hint = "Quando o céu tem fome.", reward = 30, match = { concept = "pizza", rain = true } },
	{ id = "coxinha_rain", title = "Lanche Brasileiro", hint = "Chove salgado na festa.", reward = 30, match = { concept = "coxinha", rain = true } },
	{ id = "light_vs_dark", title = "Luz contra Trevas", hint = "A batalha mais antiga.", reward = 50, match = { concepts = { "hero", "demon" }, link = "rivals" } },
	{ id = "castle_guardian", title = "Guardião do Castelo", hint = "Asas que protegem muralhas.", reward = 60, match = { concepts = { "dragon", "castle" }, link = "guard" } },
	{ id = "zombie_king", title = "Rei dos Mortos", hint = "Toda horda precisa de um líder.", reward = 40, match = { concept = "zombie", mods = { "boss" } } },
	{ id = "mechasaur", title = "Mecassauro", hint = "Pré-história com bateria.", reward = 40, match = { concept = "dinosaur", mods = { "robotic" } } },
	{ id = "glacial_comet", title = "Cometa Glacial", hint = "Um impacto que congela.", reward = 30, match = { concept = "meteor", mods = { "ice" } } },
	{ id = "apocalypse", title = "Apocalipse", hint = "Peça zumbis demais.", reward = 50, match = { concept = "zombie", minRequested = 50 } },
	{ id = "flying_cow", title = "Mu-Voadora", hint = "Uma vaca que desafia a gravidade.", reward = 30, match = { concept = "cow", mods = { "flying" } } },
	{ id = "chickenzilla", title = "Galinhazilla", hint = "Cocoricó colossal.", reward = 40, match = { concept = "chicken", mods = { "colossal" } } },
	{ id = "burning_soul", title = "Alma Ardente", hint = "Um espírito em chamas.", reward = 30, match = { concept = "ghost", mods = { "fire" } } },
	{ id = "pure_magic", title = "Magia Pura", hint = "Um unicórnio com todas as cores.", reward = 40, match = { concept = "unicorn", mods = { "rainbow" } } },
	{ id = "fire_and_ice", title = "Fogo e Gelo", hint = "Dois opostos de uma vez.", reward = 40, match = { concepts = { "fire", "ice_burst" } } },
	{ id = "sweet_hole", title = "Buraco Doce", hint = "Um buraco negro com gosto bom.", reward = 40, match = { concept = "black_hole", payload = "chocolate" } },
	{ id = "capybara_army", title = "Exército da Paz", hint = "Muitas capivaras tranquilas.", reward = 40, match = { concept = "capybara", minRequested = 8 } },
	{ id = "saci_storm", title = "Redemoinho do Saci", hint = "O saci adora vento.", reward = 40, match = { concepts = { "saci", "tornado" } } },
	{ id = "classic_rivalry", title = "Rivalidade Clássica", hint = "Gato e cachorro, de novo.", reward = 30, match = { concepts = { "cat", "dog" }, link = "rivals" } },
	{ id = "golden_throne", title = "Trono de Ouro", hint = "O banheiro mais caro do mundo.", reward = 30, match = { concept = "toilet", mods = { "gold" } } },
	{ id = "party_dino", title = "Dino Baladeiro", hint = "Até dinossauros dançam.", reward = 30, match = { concept = "dinosaur", mods = { "dancing" } } },
	{ id = "dragon_rider", title = "Cavaleiro de Dragão", hint = "Alguém montando um dragão.", reward = 50, match = { concepts = { "knight", "dragon" }, link = "ride" } },
	{ id = "pet_dragon", title = "Dragão de Estimação", hint = "O mascote mais perigoso.", reward = 50, match = { concept = "dragon", mods = { "pet" } } },
	{ id = "cheese_moon", title = "Lua de Queijo", hint = "Diziam que era feita disso.", reward = 30, match = { concepts = { "moon", "cheese" } } },
	{ id = "lava_shark", title = "Tubarão Vulcânico", hint = "Nadando no magma.", reward = 30, match = { concept = "shark", mods = { "lava" } } },
	{ id = "tiny_whale", title = "Baleia de Bolso", hint = "O maior animal, bem pequeno.", reward = 30, match = { concept = "whale", mods = { "tiny" } } },
	-- cadeias, híbridos e personagens por nome
	{ id = "absurd_chain", title = "Reação em Cadeia", hint = "Uma coisa que solta outra, que solta outra...", reward = 40, match = { chainDepth = 3 } },
	{ id = "dog_launcher", title = "Lança-Cachorro", hint = "Uma arma com munição de quatro patas.", reward = 30, match = { action = { verb = "shoot", target = "dog" } } },
	{ id = "mad_lab", title = "Laboratório Maluco", hint = "Misture dois bichos numa palavra só.", reward = 25, match = { fusion = true } },
	{ id = "energy_clash", title = "Choque de Energia", hint = "Dois guerreiros de energia frente a frente.", reward = 35, match = { concepts = { "energy_warrior", "energy_tyrant" }, link = "rivals" } },
	{ id = "one_punch", title = "Um Soco Basta", hint = "O herói careca contra um monstro gigante.", reward = 35, match = { concepts = { "bald_hero", "kaiju" }, link = "rivals" } },
	{ id = "anime_squad", title = "Esquadrão Anime", hint = "Junte dois heróis de anime.", reward = 30, match = { concepts = { "energy_warrior", "shadow_ninja" } } },
	{ id = "beach_buddies", title = "Amigos do Fundo do Mar", hint = "A esponja e a estrela.", reward = 30, match = { concepts = { "sea_sponge", "starfish" } } },
	{ id = "title_fight", title = "Luta pelo Cinturão", hint = "Um boxeador contra o herói careca.", reward = 35, match = { concepts = { "boxer", "bald_hero" }, link = "rivals" } },
	{ id = "titan_slayer", title = "Caçador de Titãs", hint = "Um caçador de demônios contra um titã.", reward = 40, match = { concepts = { "demon_hunter", "titan_giant" }, link = "rivals" } },
	{ id = "brainrot_party", title = "Festa Absurda", hint = "Junte dois memes absurdos.", reward = 30, match = { concepts = { "tum_tum_log", "skate_shark" } } },
}

return secrets
