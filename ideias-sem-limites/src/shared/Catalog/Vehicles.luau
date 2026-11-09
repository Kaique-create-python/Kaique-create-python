--!strict
-- Veículos (handler "vehicle"). drive: ground | air | water | rocket
-- Veículos terrestres e aquáticos podem ser dirigidos (assento VehicleSeat);
-- aéreos fazem um voo panorâmico automático quando alguém senta.

local function veh(id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = "vehicle",
		handler = "vehicle",
		aliases = aliases,
		params = params,
		tags = tags,
		maxCount = 3,
		lifetime = 90,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

return {
	veh("car", "Carro", "m", { "carro", "car", "automovel", "fusca", "kart", "taxi", "jipe", "jeep", "suv" }, { model = "vehicle", variant = "car", drive = "ground", speed = 70 }, { "machine", "vehicle" }),
	veh("sportscar", "Carro Esportivo", "m", { "carro esportivo", "esportivo", "ferrari", "lamborghini", "supercarro", "carro de corrida", "race car", "formula 1" }, { model = "vehicle", variant = "sportscar", drive = "ground", speed = 110 }, { "machine", "vehicle" }),
	veh("police_car", "Viatura", "f", { "viatura", "carro de policia", "police car", "camburao" }, { model = "vehicle", variant = "police_car", drive = "ground", speed = 85 }, { "machine", "vehicle", "good" }),
	veh("truck", "Caminhão", "m", { "caminhao", "truck", "carreta", "jamanta", "caminhonete", "pickup" }, { model = "vehicle", variant = "truck", drive = "ground", speed = 55 }, { "machine", "vehicle" }),
	veh("firetruck", "Caminhão de Bombeiros", "m", { "caminhao de bombeiros", "carro de bombeiro", "fire truck", "firetruck" }, { model = "vehicle", variant = "firetruck", drive = "ground", speed = 60, element = "water" }, { "machine", "vehicle", "good", "water" }),
	veh("bus", "Ônibus", "m", { "onibus", "bus", "busao", "micro onibus" }, { model = "vehicle", variant = "bus", drive = "ground", speed = 50 }, { "machine", "vehicle" }),
	veh("tractor", "Trator", "m", { "trator", "tractor", "colheitadeira", "escavadeira", "retroescavadeira", "excavator" }, { model = "vehicle", variant = "tractor", drive = "ground", speed = 35 }, { "machine", "vehicle", "farm" }),
	veh("tank", "Tanque", "m", { "tanque", "tank", "tanque de guerra", "blindado de guerra" }, { model = "vehicle", variant = "tank", drive = "ground", speed = 40 }, { "machine", "vehicle" }),
	veh("motorcycle", "Moto", "f", { "moto", "motocicleta", "motorcycle", "motorbike", "lambreta", "scooter", "bicicleta", "bike", "bicycle", "bike motorizada" }, { model = "vehicle", variant = "motorcycle", drive = "ground", speed = 90 }, { "machine", "vehicle" }),
	veh("boat", "Barco", "m", { "barco", "boat", "lancha", "canoa", "jangada", "bote", "caiaque" }, { model = "vehicle", variant = "boat", drive = "water", speed = 60 }, { "machine", "vehicle", "water" }),
	veh("ship", "Navio Pirata", "m", { "navio", "ship", "navio pirata", "caravela", "galeao", "pirate ship", "embarcacao" }, { model = "vehicle", variant = "ship", drive = "water", speed = 40 }, { "machine", "vehicle", "water" }, { maxCount = 1 }),
	veh("plane", "Avião", "m", { "aviao", "plane", "airplane", "aeronave", "jato", "jet", "caca", "teco teco" }, { model = "vehicle", variant = "plane", drive = "air", speed = 90 }, { "machine", "vehicle", "flying" }),
	veh("helicopter", "Helicóptero", "m", { "helicoptero", "helicopter", "heli", "chopper" }, { model = "vehicle", variant = "helicopter", drive = "air", speed = 60 }, { "machine", "vehicle", "flying" }),
	veh("rocket", "Foguete", "m", { "foguete", "rocket", "missil", "missile", "onibus espacial", "space shuttle" }, { model = "vehicle", variant = "rocket", drive = "rocket", speed = 120 }, { "machine", "vehicle", "flying", "space" }, { lifetime = 45 }),
	veh("spaceship", "Nave Espacial", "f", { "nave espacial", "nave", "spaceship", "starship", "nave estelar", "spacecraft" }, { model = "vehicle", variant = "spaceship", drive = "air", speed = 100 }, { "machine", "vehicle", "flying", "space" }),
	veh("balloon_air", "Balão de Ar Quente", "m", { "balao de ar quente", "hot air balloon", "dirigivel", "zepelim", "zeppelin", "blimp" }, { model = "vehicle", variant = "hot_air_balloon", drive = "air", speed = 25 }, { "vehicle", "flying" }),
	veh("train", "Trem", "m", { "trem", "train", "locomotiva", "maria fumaca", "metro", "subway" }, { model = "vehicle", variant = "train", drive = "ground", speed = 50 }, { "machine", "vehicle" }, { maxCount = 1 }),
	veh("skateboard", "Skate", "m", { "skate", "skateboard", "hoverboard", "patinete" }, { model = "vehicle", variant = "skateboard", drive = "ground", speed = 75 }, { "vehicle", "sport" }),
}
