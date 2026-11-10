--!strict
-- Objetos comuns, comidas e natureza (handler "prop").
-- physics=true: o objeto cai e rola. edible=true: pode ser comido (cura um pouco).
-- interact: comportamento especial ao tocar/usar (explode, bounce, heal, gift...)

local function prop(category: string, id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = category,
		handler = "prop",
		aliases = aliases,
		params = params,
		tags = tags,
		maxCount = 6,
		lifetime = 70,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

local O, F, N = "object", "food", "nature"

return {
	-- OBJETOS ----------------------------------------------------------------
	prop(O, "tv", "Televisão", "f", { "televisao", "tv", "televisor", "television", "telinha", "smart tv" }, { model = "prop", variant = "tv" }, { "electronic" }),
	prop(O, "computer", "Computador", "m", { "computador", "computer", "pc", "notebook", "laptop", "monitor", "desktop" }, { model = "prop", variant = "computer" }, { "electronic" }),
	prop(O, "phone", "Celular", "m", { "celular", "telefone", "smartphone", "phone", "iphone", "tablet" }, { model = "prop", variant = "phone" }, { "electronic" }),
	prop(O, "videogame", "Videogame", "m", { "videogame", "video game", "console", "fliperama", "arcade", "controle", "joystick" }, { model = "prop", variant = "arcade" }, { "electronic", "fun" }),
	prop(O, "table", "Mesa", "f", { "mesa", "table", "escrivaninha", "bancada" }, { model = "prop", variant = "table" }, { "furniture" }),
	prop(O, "chair", "Cadeira", "f", { "cadeira", "chair", "banquinho", "trono", "throne", "poltrona" }, { model = "prop", variant = "chair" }, { "furniture" }),
	prop(O, "sofa", "Sofá", "m", { "sofa", "couch", "divan" }, { model = "prop", variant = "sofa" }, { "furniture" }),
	prop(O, "bed", "Cama", "f", { "cama", "bed", "beliche", "colchao", "rede de dormir", "rede" }, { model = "prop", variant = "bed" }, { "furniture" }),
	prop(O, "lamp", "Luminária", "f", { "luminaria", "abajur", "lampada", "lamp", "lustre", "poste", "lanterna", "lantern", "vela", "candle" }, { model = "prop", variant = "lamp" }, { "furniture", "light" }),
	prop(O, "fridge", "Geladeira", "f", { "geladeira", "refrigerador", "fridge", "freezer", "frigobar" }, { model = "prop", variant = "fridge" }, { "furniture", "ice" }),
	prop(O, "piano", "Piano", "m", { "piano", "teclado musical", "orgao" }, { model = "prop", variant = "piano" }, { "music" }),
	prop(O, "guitar", "Guitarra", "f", { "guitarra", "violao", "guitar", "baixo eletrico", "ukulele", "cavaquinho", "viola" }, { model = "prop", variant = "guitar" }, { "music" }),
	prop(O, "drum", "Bateria", "f", { "bateria", "tambor", "drum", "drums", "pandeiro", "surdo", "batuque" }, { model = "prop", variant = "drum" }, { "music" }),
	prop(O, "clock", "Relógio", "m", { "relogio", "clock", "despertador", "ampulheta", "hourglass", "cuco" }, { model = "prop", variant = "clock" }, { "time" }),
	prop(O, "book", "Livro", "m", { "livro", "book", "caderno", "grimorio", "enciclopedia", "diario" }, { model = "prop", variant = "book" }, { "magic" }),
	prop(O, "ball", "Bola", "f", { "bola", "ball", "bola de futebol", "football", "soccer ball", "basketball", "bola de praia", "beach ball" }, { model = "prop", variant = "ball", physics = true }, { "sport", "fun" }, { maxCount = 8 }),
	prop(O, "balloon", "Balão", "m", { "balao", "balloon", "bexiga", "baloes", "balao de festa" }, { model = "prop", variant = "balloon", float = true }, { "fun", "party" }, { maxCount = 10 }),
	prop(O, "gift", "Presente", "m", { "presente", "gift", "caixa surpresa", "surpresa", "present", "lootbox", "pacote" }, { model = "prop", variant = "gift", interact = "gift" }, { "fun", "holiday" }),
	prop(O, "chest", "Baú do Tesouro", "m", { "bau", "chest", "tesouro", "treasure", "arca", "bau do tesouro", "cofre", "safe" }, { model = "prop", variant = "chest", interact = "treasure" }, { "treasure" }),
	prop(O, "coin", "Moeda", "f", { "moeda", "coin", "moedas", "dinheiro", "money", "grana", "cash", "dolar", "real", "robux" }, { model = "prop", variant = "coin", physics = true }, { "treasure" }, { maxCount = 10 }),
	prop(O, "diamond", "Diamante", "m", { "diamante", "joia", "gem", "gema", "rubi", "ruby", "esmeralda", "emerald", "safira", "sapphire" }, { model = "prop", variant = "gem" }, { "treasure" }),
	prop(O, "crown", "Coroa", "f", { "coroa", "crown", "tiara", "diadema" }, { model = "prop", variant = "crown" }, { "treasure", "royal" }),
	prop(O, "trophy", "Troféu", "m", { "trofeu", "trophy", "taca", "medalha", "medal" }, { model = "prop", variant = "trophy" }, { "treasure", "sport" }),
	prop(O, "barrel", "Barril Explosivo", "m", { "barril", "barrel", "tonel", "barril explosivo" }, { model = "prop", variant = "barrel", physics = true, interact = "explode" }, { "explosive" }),
	prop(O, "crate", "Caixa", "f", { "caixa", "crate", "caixote", "box", "caixa de madeira" }, { model = "prop", variant = "crate", physics = true }, { "furniture" }, { maxCount = 8 }),
	prop(O, "tnt", "Dinamite", "f", { "dinamite", "tnt", "explosivo", "explosive", "c4", "polvora" }, { model = "prop", variant = "tnt", interact = "explode", fuse = 4 }, { "explosive" }),
	prop(O, "cannon", "Canhão", "m", { "canhao", "cannon", "catapulta", "catapult", "morteiro" }, { model = "prop", variant = "cannon", interact = "cannon" }, { "weapon" }, { maxCount = 2 }),
	prop(O, "magnet", "Ímã", "m", { "ima", "magnet", "imã", "magneto", "eletroima" }, { model = "prop", variant = "magnet", interact = "magnet" }, { "science" }, { maxCount = 2 }),
	prop(O, "disco_ball", "Globo de Luz", "m", { "globo de luz", "disco ball", "globo espelhado", "discoteca" }, { model = "prop", variant = "disco_ball", interact = "party" }, { "party", "music" }, { maxCount = 2 }),
	prop(O, "campfire", "Fogueira", "f", { "fogueira", "campfire", "lareira", "fireplace", "churrasqueira", "churrasco", "bbq", "barbecue" }, { model = "prop", variant = "campfire", interact = "heal" }, { "fire", "cozy" }),
	prop(O, "bench", "Banco", "m", { "banco", "banco de praca", "bench", "banquinho de madeira" }, { model = "prop", variant = "bench" }, { "furniture" }),
	prop(O, "flag", "Bandeira", "f", { "bandeira", "flag", "estandarte", "bandeira do brasil" }, { model = "prop", variant = "flag" }, { "decor" }),
	prop(O, "toilet", "Privada", "f", { "privada", "vaso sanitario", "toilet", "banheiro" }, { model = "prop", variant = "toilet" }, { "funny" }),
	prop(O, "umbrella", "Guarda-chuva", "m", { "guarda chuva", "umbrella", "sombrinha", "guarda sol", "parasol" }, { model = "prop", variant = "umbrella" }, { "decor" }),
	prop(O, "rubber_duck", "Pato de Borracha", "m", { "pato de borracha", "rubber duck", "patinho de borracha", "patinho de banho" }, { model = "prop", variant = "rubber_duck", physics = true }, { "funny", "cute" }),
	prop(O, "teddy", "Ursinho de Pelúcia", "m", { "ursinho de pelucia", "urso de pelucia", "teddy bear", "pelucia", "plush", "boneca", "doll", "boneco" }, { model = "prop", variant = "teddy", physics = true }, { "cute", "toy" }),
	prop(O, "snowman", "Boneco de Neve", "m", { "boneco de neve", "snowman", "frosty" }, { model = "prop", variant = "snowman" }, { "ice", "holiday" }),
	prop(O, "pumpkin", "Abóbora", "f", { "abobora", "pumpkin", "jack o lantern", "aboboras" }, { model = "prop", variant = "pumpkin" }, { "holiday", "food" }),
	prop(O, "xmas_tree", "Árvore de Natal", "f", { "arvore de natal", "christmas tree", "pinheiro de natal", "natal", "christmas" }, { model = "prop", variant = "xmas_tree" }, { "holiday" }, { maxCount = 2 }),
	prop(O, "toy_car", "Carrinho de Controle", "m", { "carrinho de controle", "rc car", "carrinho de brinquedo" }, { model = "prop", variant = "toy_car", physics = true }, { "toy" }),
	prop(O, "hat", "Chapéu", "m", { "chapeu", "hat", "bone", "cartola", "top hat", "capacete", "helmet", "sombrero" }, { model = "prop", variant = "hat", interact = "wear" }, { "clothing" }),
	prop(O, "mirror", "Espelho Mágico", "m", { "espelho", "mirror", "espelho magico" }, { model = "prop", variant = "mirror" }, { "magic" }),
	prop(O, "robot_vacuum", "Aspirador", "m", { "aspirador", "vacuum", "aspirador de po", "roomba" }, { model = "prop", variant = "vacuum", interact = "magnet" }, { "electronic", "funny" }),
	prop(O, "fan", "Ventilador", "m", { "ventilador", "fan", "ventilador gigante", "turbina" }, { model = "prop", variant = "fan", interact = "wind" }, { "electronic", "wind" }),
	prop(O, "speaker", "Caixa de Som", "f", { "caixa de som", "speaker", "som", "radio", "jukebox", "paredao" }, { model = "prop", variant = "speaker", interact = "party" }, { "music", "party" }),
	prop(O, "sign", "Placa", "f", { "placa", "sign", "letreiro", "outdoor", "billboard", "cartaz" }, { model = "prop", variant = "sign" }, { "decor" }),

	-- COMIDAS ----------------------------------------------------------------
	prop(F, "pizza", "Pizza", "f", { "pizza", "pizzas", "pizzaria", "calzone" }, { model = "food", variant = "pizza", edible = true }, { "food" }, { maxCount = 10 }),
	prop(F, "burger", "Hambúrguer", "m", { "hamburguer", "hamburger", "burger", "x burguer", "x tudo", "cheeseburger", "sanduiche", "sandwich", "lanche" }, { model = "food", variant = "burger", edible = true }, { "food" }, { maxCount = 10 }),
	prop(F, "hotdog", "Cachorro-quente", "m", { "cachorro quente", "hot dog", "hotdog", "salsicha", "sausage", "linguica" }, { model = "food", variant = "hotdog", edible = true }, { "food" }, { maxCount = 10 }),
	prop(F, "cake", "Bolo", "m", { "bolo", "cake", "bolo de aniversario", "torta", "pie", "cupcake", "aniversario", "birthday" }, { model = "food", variant = "cake", edible = true }, { "food", "party" }, { maxCount = 6 }),
	prop(F, "donut", "Rosquinha", "f", { "rosquinha", "donut", "doughnut", "sonho", "rosca" }, { model = "food", variant = "donut", edible = true }, { "food", "sweet" }, { maxCount = 10 }),
	prop(F, "icecream", "Sorvete", "m", { "sorvete", "ice cream", "picole", "gelato", "casquinha", "milkshake", "acai na tigela" }, { model = "food", variant = "icecream", edible = true }, { "food", "ice", "sweet" }, { maxCount = 10 }),
	prop(F, "apple", "Maçã", "f", { "maca", "apple", "maca do amor", "pera", "pear" }, { model = "food", variant = "apple", edible = true, physics = true }, { "food", "fruit" }, { maxCount = 12 }),
	prop(F, "banana", "Banana", "f", { "banana", "bananas", "cacho de banana" }, { model = "food", variant = "banana", edible = true, physics = true }, { "food", "fruit" }, { maxCount = 12 }),
	prop(F, "watermelon", "Melancia", "f", { "melancia", "watermelon", "melao", "melon", "abacaxi", "pineapple", "coco", "coconut" }, { model = "food", variant = "watermelon", edible = true, physics = true }, { "food", "fruit" }, { maxCount = 8 }),
	prop(F, "orange_fruit", "Laranja", "f", { "laranja", "laranjas", "fruta laranja", "tangerina", "mexerica", "limao", "lemon", "fruta", "fruit", "frutas" }, { model = "food", variant = "orange", edible = true, physics = true }, { "food", "fruit" }, { maxCount = 12 }),
	prop(F, "strawberry", "Morango", "m", { "morango", "strawberry", "cereja", "cherry", "uva", "grape", "framboesa" }, { model = "food", variant = "strawberry", edible = true, physics = true }, { "food", "fruit" }, { maxCount = 12 }),
	prop(F, "carrot", "Cenoura", "f", { "cenoura", "carrot", "legume", "vegetable", "brocolis", "broccoli", "milho", "corn" }, { model = "food", variant = "carrot", edible = true, physics = true }, { "food" }, { maxCount = 12 }),
	prop(F, "cookie", "Biscoito", "m", { "biscoito", "bolacha", "cookie", "cookies", "oreo", "waffle" }, { model = "food", variant = "cookie", edible = true, physics = true }, { "food", "sweet" }, { maxCount = 12 }),
	prop(F, "candy", "Pirulito", "m", { "pirulito", "bala", "lollipop", "bombom", "jujuba", "gummy", "algodao doce", "cotton candy", "chiclete", "gum" }, { model = "food", variant = "lollipop", edible = true }, { "food", "sweet" }, { maxCount = 10 }),
	prop(F, "chocolate", "Chocolate", "m", { "chocolate", "barra de chocolate", "chocolates", "nutella", "cacau" }, { model = "food", variant = "chocolate", edible = true }, { "food", "sweet" }, { maxCount = 10, asModifier = "chocolate_mat", preferModifier = true }),
	prop(F, "bread", "Pão", "m", { "pao", "bread", "baguete", "baguette", "pao frances", "torrada", "toast" }, { model = "food", variant = "bread", edible = true, physics = true }, { "food" }, { maxCount = 12 }),
	prop(F, "cheese", "Queijo", "m", { "queijo", "cheese", "queijos", "requeijao" }, { model = "food", variant = "cheese", edible = true }, { "food" }, { maxCount = 10 }),
	prop(F, "egg", "Ovo", "m", { "ovo", "egg", "ovos", "ovo de pascoa", "omelete", "ovo frito" }, { model = "food", variant = "egg", edible = true, physics = true }, { "food" }, { maxCount = 12 }),
	prop(F, "popcorn", "Pipoca", "f", { "pipoca", "popcorn", "pipocas" }, { model = "food", variant = "popcorn", edible = true }, { "food", "fun" }, { maxCount = 8 }),
	prop(F, "soda", "Refrigerante", "m", { "refrigerante", "refri", "soda", "coca", "guarana", "suco", "juice", "latinha", "garrafa", "bottle", "agua de coco" }, { model = "food", variant = "soda", edible = true, physics = true }, { "food", "drink" }, { maxCount = 10 }),
	prop(F, "coffee", "Café", "m", { "cafe", "coffee", "cafezinho", "xicara", "cha", "tea", "chocolate quente", "cappuccino" }, { model = "food", variant = "coffee", edible = true }, { "food", "drink" }, { maxCount = 8 }),
	prop(F, "fries", "Batata Frita", "f", { "batata frita", "fries", "french fries", "batata", "potato", "chips", "salgadinho" }, { model = "food", variant = "fries", edible = true }, { "food" }, { maxCount = 10 }),
	prop(F, "brigadeiro", "Brigadeiro", "m", { "brigadeiro", "brigadeiros", "beijinho", "docinho", "negrinho" }, { model = "food", variant = "brigadeiro", edible = true, physics = true }, { "food", "sweet", "brazil" }, { maxCount = 12 }),
	prop(F, "coxinha", "Coxinha", "f", { "coxinha", "coxinhas", "salgado", "kibe", "quibe", "esfirra", "empada", "risole" }, { model = "food", variant = "coxinha", edible = true, physics = true }, { "food", "brazil" }, { maxCount = 12 }),
	prop(F, "cheese_bread", "Pão de Queijo", "m", { "pao de queijo", "paes de queijo", "pao de queijo mineiro" }, { model = "food", variant = "cheese_bread", edible = true, physics = true }, { "food", "brazil" }, { maxCount = 12 }),
	prop(F, "acai", "Açaí", "m", { "acai", "tigela de acai", "cupuacu" }, { model = "food", variant = "acai", edible = true }, { "food", "brazil", "sweet" }, { maxCount = 8 }),
	prop(F, "pastel", "Pastel", "m", { "pastel", "pasteis", "pastel de feira", "empanada", "taco", "tacos", "burrito" }, { model = "food", variant = "pastel", edible = true, physics = true }, { "food", "brazil" }, { maxCount = 10 }),
	prop(F, "sushi", "Sushi", "m", { "sushi", "sashimi", "temaki", "onigiri", "lamen", "ramen", "macarrao", "spaghetti", "espaguete", "noodles" }, { model = "food", variant = "sushi", edible = true }, { "food" }, { maxCount = 10 }),
	prop(F, "feijoada", "Feijoada", "f", { "feijoada", "feijao", "arroz e feijao", "prato feito", "pf", "comida", "food", "almoco", "jantar", "lunch", "dinner" }, { model = "food", variant = "feijoada", edible = true }, { "food", "brazil" }, { maxCount = 6 }),

	-- NATUREZA ---------------------------------------------------------------
	prop(N, "tree", "Árvore", "f", { "arvore", "tree", "arvores", "carvalho", "oak", "ipe", "jabuticabeira", "mangueira", "baoba" }, { model = "nature", variant = "tree" }, { "nature" }, { maxCount = 8 }),
	prop(N, "pine", "Pinheiro", "m", { "pinheiro", "pine", "pine tree", "araucaria", "conifera" }, { model = "nature", variant = "pine" }, { "nature" }, { maxCount = 8 }),
	prop(N, "palm", "Coqueiro", "m", { "coqueiro", "palmeira", "palm tree", "palm", "palmeiras" }, { model = "nature", variant = "palm" }, { "nature", "beach" }, { maxCount = 8 }),
	prop(N, "forest_patch", "Floresta", "f", { "floresta", "forest", "bosque", "mata", "selva", "jungle", "matagal" }, { model = "nature", variant = "forest", cluster = 9 }, { "nature" }, { maxCount = 1 }),
	prop(N, "flower", "Flores", "f", { "flor", "flower", "flores", "rosa vermelha", "girassol", "sunflower", "tulipa", "tulip", "margarida", "orquidea", "buque" }, { model = "nature", variant = "flowers" }, { "nature", "cute" }, { maxCount = 6 }),
	prop(N, "garden", "Jardim", "m", { "jardim", "garden", "canteiro", "horta", "primavera", "spring" }, { model = "nature", variant = "garden", cluster = 1 }, { "nature" }, { maxCount = 1 }),
	prop(N, "mushroom", "Cogumelo", "m", { "cogumelo", "mushroom", "fungo", "champignon", "cogumelos" }, { model = "nature", variant = "mushroom", interact = "bounce" }, { "nature", "magic" }, { maxCount = 6 }),
	prop(N, "cactus", "Cacto", "m", { "cacto", "cactus", "mandacaru", "cactos", "suculenta" }, { model = "nature", variant = "cactus" }, { "nature", "desert" }, { maxCount = 6 }),
	prop(N, "rock", "Pedra", "f", { "pedra", "rocha", "rock", "pedregulho", "boulder", "rochedo", "seixo" }, { model = "nature", variant = "rock", physics = true }, { "nature", "stone" }, { maxCount = 6, asModifier = "stone", preferModifier = true }),
	prop(N, "crystal", "Cristal", "m", { "cristal", "cristais", "quartzo", "ametista", "geodo", "minerio", "ore" }, { model = "nature", variant = "crystal" }, { "nature", "magic" }, { maxCount = 4, asModifier = "crystal", preferModifier = true }),
	prop(N, "cloud", "Nuvem", "f", { "nuvem", "cloud", "nuvens fofas", "nuvenzinha" }, { model = "nature", variant = "cloud", float = true }, { "nature", "flying" }, { maxCount = 4 }),
	prop(N, "bush", "Arbusto", "m", { "arbusto", "bush", "moita", "planta", "samambaia", "fern", "grama", "grass" }, { model = "nature", variant = "bush" }, { "nature" }, { maxCount = 8 }),
	prop(N, "mountain", "Montanha", "f", { "montanha", "mountain", "morro", "colina", "hill", "serra", "monte" }, { model = "nature", variant = "mountain" }, { "nature", "stone" }, { maxCount = 1, lifetime = 100 }),
}
