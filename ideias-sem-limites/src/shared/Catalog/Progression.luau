--!strict
-- Conquistas, missões e recompensas cosméticas (dados compartilhados:
-- o servidor valida e o cliente mostra a lista). Nada exige Robux.

local Progression = {}

-- stat: contador do perfil; goal: valor para desbloquear
Progression.Achievements = {
	{ id = "first_idea", title = "Primeira Ideia", desc = "Crie sua primeira ideia.", stat = "created", goal = 1, reward = 5 },
	{ id = "ideas_25", title = "Mente Inquieta", desc = "Crie 25 ideias.", stat = "created", goal = 25, reward = 20 },
	{ id = "ideas_100", title = "Fábrica de Ideias", desc = "Crie 100 ideias.", stat = "created", goal = 100, reward = 60 },
	{ id = "ideas_500", title = "Sem Limites", desc = "Crie 500 ideias.", stat = "created", goal = 500, reward = 200 },
	{ id = "discover_10", title = "Explorador de Palavras", desc = "Descubra 10 conceitos.", stat = "discovered", goal = 10, reward = 15 },
	{ id = "discover_50", title = "Dicionário Vivo", desc = "Descubra 50 conceitos.", stat = "discovered", goal = 50, reward = 50 },
	{ id = "discover_120", title = "Enciclopédia", desc = "Descubra 120 conceitos.", stat = "discovered", goal = 120, reward = 150 },
	{ id = "secret_1", title = "Combinação Secreta", desc = "Encontre uma combinação secreta.", stat = "secrets", goal = 1, reward = 20 },
	{ id = "secret_10", title = "Mestre dos Segredos", desc = "Encontre 10 combinações secretas.", stat = "secrets", goal = 10, reward = 120 },
	{ id = "combo_5", title = "Alquimista", desc = "Combine duas ideias 5 vezes.", stat = "combos", goal = 5, reward = 20 },
	{ id = "kills_10", title = "Defensor", desc = "Derrote 10 inimigos (você ou seus aliados).", stat = "kills", goal = 10, reward = 25 },
	{ id = "kills_100", title = "Lenda da Arena", desc = "Derrote 100 inimigos.", stat = "kills", goal = 100, reward = 120 },
	{ id = "surprise_10", title = "Caixinha de Surpresas", desc = "Gere 10 surpresas com palavras desconhecidas.", stat = "surprises", goal = 10, reward = 20 },
	{ id = "regions_all", title = "Viajante", desc = "Visite todas as regiões do mapa.", stat = "regions", goal = 9, reward = 60 },
	{ id = "eat_10", title = "Comilão", desc = "Coma 10 comidas criadas.", stat = "eat", goal = 10, reward = 15 },
	{ id = "colossal", title = "Pensando Grande", desc = "Crie algo colossal.", stat = "colossal", goal = 1, reward = 15 },
}

-- missões rotativas (3 por sessão)
Progression.Quests = {
	{ id = "q_creatures", title = "Crie 3 criaturas", stat = "q_creature", goal = 3, reward = 15 },
	{ id = "q_disaster", title = "Crie 2 desastres", stat = "q_disaster", goal = 2, reward = 15 },
	{ id = "q_ice", title = "Crie algo de gelo", stat = "q_ice", goal = 1, reward = 10 },
	{ id = "q_fire", title = "Crie algo de fogo", stat = "q_fire", goal = 1, reward = 10 },
	{ id = "q_versus", title = "Use \"contra\" para criar uma batalha", stat = "q_versus", goal = 1, reward = 15 },
	{ id = "q_kills", title = "Derrote 5 inimigos", stat = "q_kills", goal = 5, reward = 20 },
	{ id = "q_food", title = "Crie 2 comidas", stat = "q_food", goal = 2, reward = 10 },
	{ id = "q_vehicle", title = "Crie um veículo e dirija", stat = "q_vehicle", goal = 1, reward = 10 },
	{ id = "q_visit_volcano", title = "Visite a Região Vulcânica", stat = "q_visit_volcano", goal = 1, reward = 10 },
	{ id = "q_visit_glacier", title = "Visite a Região Glacial", stat = "q_visit_glacier", goal = 1, reward = 10 },
	{ id = "q_discover", title = "Descubra 3 palavras novas", stat = "q_discover", goal = 3, reward = 15 },
	{ id = "q_building", title = "Construa 2 construções", stat = "q_building", goal = 2, reward = 10 },
	{ id = "q_brazil", title = "Crie algo do folclore ou da comida brasileira", stat = "q_brazil", goal = 1, reward = 15 },
}

-- cosméticos comprados com Faíscas (ganhas jogando)
Progression.Cosmetics = {
	{ id = "trail_blue", kind = "trail", title = "Rastro Azul", price = 20, colors = { { 80, 200, 255 }, { 120, 120, 255 } } },
	{ id = "trail_fire", kind = "trail", title = "Rastro de Fogo", price = 40, colors = { { 255, 220, 80 }, { 255, 80, 30 } } },
	{ id = "trail_rainbow", kind = "trail", title = "Rastro Arco-íris", price = 80, colors = { { 255, 70, 70 }, { 255, 230, 60 }, { 80, 220, 90 }, { 70, 160, 255 }, { 150, 90, 255 } } },
	{ id = "trail_gold", kind = "trail", title = "Rastro Dourado", price = 120, colors = { { 255, 240, 160 }, { 255, 190, 40 } } },
	{ id = "title_creator", kind = "title", title = "Criador", price = 10 },
	{ id = "title_dragon", kind = "title", title = "Domador de Dragões", price = 50 },
	{ id = "title_chaos", kind = "title", title = "Mestre do Caos", price = 60 },
	{ id = "title_genius", kind = "title", title = "Gênio das Ideias", price = 100 },
	{ id = "title_legend", kind = "title", title = "Lenda Sem Limites", price = 250 },
	{ id = "aura_sparkle", kind = "aura", title = "Aura Brilhante", price = 70, colors = { { 255, 240, 150 } } },
	{ id = "aura_shadow", kind = "aura", title = "Aura Sombria", price = 90, colors = { { 120, 60, 200 } } },
}

Progression.CosmeticById = {} :: { [string]: any }
for _, c in Progression.Cosmetics do
	Progression.CosmeticById[c.id] = c
end
Progression.QuestById = {} :: { [string]: any }
for _, q in Progression.Quests do
	Progression.QuestById[q.id] = q
end

return Progression
