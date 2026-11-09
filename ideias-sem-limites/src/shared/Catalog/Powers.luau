--!strict
-- Poderes aplicados ao próprio jogador (handler "power") e ferramentas que vão
-- para a mochila (handler "tool"). Ferramentas usam mira automática (bom no celular).

local function pw(handler: string, id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = if handler == "tool" then "tool" else "power",
		handler = handler,
		aliases = aliases,
		params = params,
		tags = tags,
		maxCount = 1,
		lifetime = if handler == "tool" then 90 else 20,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

return {
	-- PODERES ----------------------------------------------------------------
	pw("power", "heal", "Cura", "f", { "cura", "curar", "heal", "healing", "vida", "life", "saude", "health", "regenerar", "remedio", "pocao de vida", "medkit", "kit medico" }, { kind = "heal" }, { "good" }),
	pw("power", "power_speed", "Super Velocidade", "f", { "velocidade", "speed", "super velocidade", "correr", "run", "corrida", "flash", "sonic", "supersonico" }, { kind = "speed" }, { "good" }),
	pw("power", "super_jump", "Super Pulo", "m", { "super pulo", "pulo", "jump", "pular", "salto", "super jump", "mola nos pes", "pernas de mola" }, { kind = "jump" }, { "good" }),
	pw("power", "power_fly", "Voo", "m", { "voar", "voo", "fly", "flight", "levitar", "levitacao", "superman", "jetpack", "mochila a jato", "asas", "wings" }, { kind = "fly" }, { "good", "flying" }),
	pw("power", "power_giant", "Ficar Gigante", "m", { "crescer", "grow", "aumentar", "ficar gigante", "ficar grande", "growth" }, { kind = "giant" }, { "good" }),
	pw("power", "power_tiny", "Ficar Pequeno", "m", { "encolher", "shrink", "diminuir", "ficar pequeno", "formiga humana", "homem formiga" }, { kind = "tiny" }, { "good" }),
	pw("power", "invisible", "Invisibilidade", "f", { "invisivel", "invisibilidade", "invisible", "invisibility", "sumir de vista", "camuflagem", "camouflage", "furtividade" }, { kind = "invisible" }, { "magic" }),
	pw("power", "shield", "Escudo de Energia", "m", { "escudo", "shield", "campo de forca", "force field", "forcefield", "protecao", "protection", "imortal", "invencivel", "invincible", "armadura", "armor", "bolha" }, { kind = "shield" }, { "good" }),
	pw("power", "teleport", "Teletransporte", "m", { "teleporte", "teletransporte", "teleport", "teleportar", "warp", "viajar", "travel" }, { kind = "teleport" }, { "magic" }),
	pw("power", "clone", "Clones", "m", { "clone", "clones", "clonar", "copia", "duplicar", "sosia", "doppelganger" }, { kind = "clone" }, { "magic" }),
	pw("power", "time_stop", "Parar o Tempo", "m", { "parar o tempo", "pausar", "pause", "time stop", "congelar o tempo", "the world", "zawarudo", "tempo parado" }, { kind = "time_stop" }, { "magic", "time" }, { lifetime = 8 }),
	pw("power", "slowmo", "Câmera Lenta", "f", { "camera lenta", "slow motion", "slowmo", "tempo lento", "matrix", "bullet time" }, { kind = "slowmo" }, { "magic", "time" }, { lifetime = 12 }),
	pw("power", "pet", "Mascote", "m", { "mascote", "bichinho de estimacao", "animal de estimacao", "companheiro", "companion", "parceiro", "sidekick" }, { kind = "pet" }, { "good", "cute" }),
	pw("power", "aura", "Aura Brilhante", "f", { "aura", "brilho", "glow", "brilhar", "super saiyajin", "super sayajin", "poder maximo", "power up", "energia", "energy" }, { kind = "aura" }, { "good", "magic" }, { lifetime = 30 }),
	pw("power", "cape", "Capa de Herói", "f", { "capa", "cape", "manto", "cloak", "uniforme de heroi" }, { kind = "cape" }, { "good", "clothing" }, { lifetime = 60 }),
	pw("power", "potion", "Poção Misteriosa", "f", { "pocao", "potion", "elixir", "pocao magica", "frasco", "veneno magico" }, { kind = "potion" }, { "magic" }),

	-- FERRAMENTAS ------------------------------------------------------------
	pw("tool", "sword", "Espada", "f", { "espada", "sword", "katana", "sabre", "lamina", "blade", "adaga", "dagger", "faca", "machado", "axe" }, { kind = "sword", dmg = 30 }, { "weapon" }),
	pw("tool", "hammer", "Martelo", "m", { "martelo", "hammer", "marreta", "mjolnir", "martelo de thor", "clava", "porrete", "bastao de beisebol" }, { kind = "hammer", dmg = 40 }, { "weapon" }),
	pw("tool", "wand", "Varinha Mágica", "f", { "varinha", "varinha magica", "wand", "magic wand", "cajado", "staff", "cetro", "bastao magico" }, { kind = "wand", dmg = 22, element = "light" }, { "weapon", "magic" }),
	pw("tool", "blaster", "Blaster Laser", "m", { "blaster", "laser", "arma laser", "pistola laser", "raygun", "ray gun", "canhao de plasma", "arma", "pistola", "gun", "rifle", "metralhadora" }, { kind = "blaster", dmg = 18, element = "electric" }, { "weapon", "science" }),
	pw("tool", "bow", "Arco e Flecha", "m", { "arco e flecha", "arco", "bow", "flecha", "arrow", "besta", "crossbow", "estilingue", "slingshot" }, { kind = "bow", dmg = 24 }, { "weapon" }),
	pw("tool", "snowball", "Bolas de Neve", "f", { "bola de neve", "bolas de neve", "snowball", "guerra de neve" }, { kind = "snowball", dmg = 8, element = "ice" }, { "weapon", "ice", "fun" }),
	pw("tool", "water_gun", "Pistola de Água", "f", { "pistola de agua", "arma de agua", "water gun", "super soaker", "hose", "extintor", "extinguisher" }, { kind = "water_gun", dmg = 6, element = "water" }, { "weapon", "water", "fun" }),
	pw("tool", "flamethrower", "Lança-chamas", "m", { "lanca chamas", "flamethrower", "bafo de dragao", "maçarico", "macarico" }, { kind = "flamethrower", dmg = 10, element = "fire" }, { "weapon", "fire" }),
	pw("tool", "grapple", "Gancho", "m", { "gancho", "grappling hook", "gancho de escalada", "teia", "web", "teia de aranha", "spider web", "corda", "rope" }, { kind = "grapple" }, { "utility" }),
	pw("tool", "pickaxe", "Picareta", "f", { "picareta", "pickaxe", "pa", "shovel", "furadeira", "drill", "britadeira" }, { kind = "hammer", dmg = 26 }, { "weapon", "utility" }),
}
