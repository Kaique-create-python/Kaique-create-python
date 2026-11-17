-- PROJETO BASTIÃO :: Capítulo 1 — A chamada (Etapa 1: cenas 1, 3, 4, 5, 7 e 8 da abertura)
-- Conteúdo declarativo: o StoryRunner decide, os serviços executam. A perseguição (cena 6) e o
-- rifle (cena 2) entram nas próximas etapas, junto com o monstro importado do pacote real.
-- Flags com os nomes do plano: equipment_checked fica para quando o rifle existir.

local function obj(texto: string?)
	return { tipo = "objetivo", texto = texto }
end
local function ent(id: string, estado: string)
	return { tipo = "entidade", id = id, estado = estado }
end
local function seq(id: string)
	return { tipo = "sequencia", id = id }
end

return {
	id = "bastiao_cap01",
	version = 1,
	start = "rotina",
	flagSchema = {
		radio_checked = false,
		battery_collected = false,
		medical_terminal_powered = false,
		exercise_started = false,
		maintenance_reached = false,
		partial_roster_found = false,
	},
	initialFlags = {},
	nodes = {
		-- Cena 1: fim de um turno comum. Objetivo recolhido até a primeira ordem.
		rotina = {
			onEnter = {
				ent("pavel", "tunel"),
				ent("relogio", "0249"),
				ent("radio", "guardado"),
				ent("bateria", "no_carregador"),
				ent("terminal_enfermaria", "sem_energia"),
				ent("porta_contencao", "trancada"),
				ent("alarme", "desligado"),
				ent("acesso_externo", "aberto"),
				ent("porta_oficina", "aberta"),
				ent("terminal_oficina", "apagado"),
				ent("fim", "oculto"),
				obj(nil),
			},
			exits = {
				{ event = "pavel_perto", kind = "zona", to = "radio", effects = { seq("s1_pavel") } },
			},
		},
		radio = {
			onEnter = { ent("radio", "oferecido") },
			exits = {
				{ event = "s1_pavel_fim", kind = "sequencia", to = "radio_ordem", effects = { obj("radio") } },
			},
		},
		radio_ordem = {
			exits = {
				{
					event = "pegar_radio",
					kind = "interacao",
					to = "ordem",
					set = { radio_checked = true },
					effects = { ent("radio", "entregue"), obj(nil), seq("s3_ordem") },
				},
			},
		},
		-- Cena 3: a ordem plausível de Orlov e o nome na lista
		ordem = {
			exits = {
				{
					event = "s3_ordem_fim",
					kind = "sequencia",
					to = "buscar_bateria",
					effects = { ent("bateria", "disponivel"), obj("bateria") },
				},
			},
		},
		buscar_bateria = {
			exits = {
				{
					event = "pegar_bateria",
					kind = "interacao",
					to = "levar_bateria",
					set = { battery_collected = true },
					effects = { ent("bateria", "carregada"), ent("pavel", "enfermaria"), obj("terminal") },
				},
			},
		},
		-- Cena 4: uma porta grande demais. A bateria liga o terminal; a libertação é uma ordem remota separada.
		levar_bateria = {
			exits = {
				{
					event = "encaixar_bateria",
					kind = "interacao",
					to = "chamada",
					set = { medical_terminal_powered = true },
					effects = { ent("bateria", "encaixada"), ent("terminal_enfermaria", "ligado"), obj(nil), seq("s4_chamada") },
				},
			},
		},
		chamada = {
			exits = {
				{
					event = "s4_chamada_fim",
					kind = "sequencia",
					to = "isolamento",
					set = { exercise_started = true },
					effects = { seq("s5_isolamento") },
				},
			},
		},
		-- Cena 5: o isolamento. Orlov chama de falha de protocolo e manda pela saída de serviço.
		isolamento = {
			exits = {
				{
					event = "s5_isolamento_fim",
					kind = "sequencia",
					to = "ir_oficina",
					effects = { ent("pavel", "porta_oficina"), ent("porta_oficina", "trancada"), obj("oficina") },
				},
			},
		},
		-- Cena 7: Pavel abre a trava mecânica; o jogador cruza e a fecha.
		ir_oficina = {
			exits = {
				{
					event = "chegou_oficina",
					kind = "zona",
					to = "fechar_trava",
					effects = { ent("porta_oficina", "aberta"), ent("pavel", "oficina"), seq("s7_trava"), obj("trava") },
				},
			},
		},
		fechar_trava = {
			exits = {
				{
					event = "fechar_trava",
					kind = "interacao",
					to = "oficina",
					set = { maintenance_reached = true },
					effects = {
						ent("porta_oficina", "travada"),
						{ tipo = "checkpoint", id = "oficina_segura" },
						seq("s7_travada"),
						obj("terminal_oficina"),
						ent("terminal_oficina", "aguardando"),
					},
				},
			},
		},
		-- Cena 8: alguém ainda responde. A lista do turno já estava no arquivo do exercício.
		oficina = {
			exits = {
				{
					event = "ler_terminal",
					kind = "interacao",
					to = "descoberta",
					set = { partial_roster_found = true },
					effects = { ent("terminal_oficina", "lista"), obj(nil), seq("s8_lista") },
				},
			},
		},
		descoberta = {
			exits = {
				{ event = "s8_lista_fim", kind = "sequencia", to = "fim_etapa", effects = { obj("piso") } },
			},
		},
		fim_etapa = {
			final = true,
			onEnter = { ent("fim", "visivel"), { tipo = "checkpoint", id = "fim_etapa1" } },
		},
	},
	-- t em segundos desde o início da sequência. fala/som viram legenda (e voz/som na língua de
	-- cada jogador); ruido é só som, sem legenda; pos = {x, y, z} faz o som sair daquele ponto.
	-- As falas usam a duração real da voz: se uma atrasa, o que vem depois anda junto.
	sequences = {
		s1_pavel = {
			cues = {
				{ t = 0.0, fala = "pavel_cafe" },
				{ t = 5.2, fala = "pavel_conferencia" },
			},
		},
		s3_ordem = {
			cues = {
				{ t = 0.0, fala = "pavel_canal" },
				{ t = 4.0, som = "radio_chiado" },
				{ t = 4.8, fala = "orlov_ordem" },
				-- Pavel confere a lista de turno na caixa antes de sair (a pista aparece antes da explicação)
				{ t = 12.8, fala = "pavel_lista1" },
				{ t = 16.0, fala = "pavel_lista2" },
				{ t = 18.8, som = "tres_toques" },
				{ t = 21.0, fala = "pavel_arsenal" },
				{ t = 21.6, entidade = "pavel", estado = "arsenal" },
			},
		},
		s4_chamada = {
			cues = {
				{ t = 0.4, som = "radio_chiado" },
				{ t = 1.2, fala = "gravacao_sokolov" },
				{ t = 5.6, som = "inspiracao", pos = { -64.4, 4.2, -320 } },
				{ t = 9.0, som = "pressurizacao", pos = { -64.6, 0.8, -320 } },
				{ t = 9.0, entidade = "porta_contencao", estado = "vazando" },
				{ t = 13.0, entidade = "terminal_enfermaria", estado = "autorizado" },
				{ t = 14.5, entidade = "porta_contencao", estado = "destravada" },
				{ t = 15.0, fala = "pavel_afasta" },
			},
		},
		-- o peso de um ataque contra a barreira: a porta de contenção apanha por dentro e aguenta
		s5_isolamento = {
			cues = {
				{ t = 0.0, entidade = "alarme", estado = "ligado" },
				{ t = 0.0, som = "alarme" },
				{ t = 0.8, entidade = "acesso_externo", estado = "bloqueado" },
				{ t = 0.8, som = "portas" },
				{ t = 1.7, ruido = "chime_pa" },
				{ t = 2.6, fala = "sistema_isolamento" },
				{ t = 5.0, som = "impacto_porta", pos = { -64.4, 4.0, -320 } },
				{ t = 6.7, ruido = "impacto_porta", pos = { -64.4, 4.0, -320 } },
				{ t = 8.4, fala = "pavel_confirma" },
				{ t = 13.4, fala = "orlov_falha" },
				{ t = 19.0, fala = "pavel_vamos" },
			},
		},
		s7_trava = {
			cues = {
				{ t = 0.0, fala = "pavel_entra" },
			},
		},
		-- trava fechada: silêncio, e logo depois passos pesados em outro setor
		s7_travada = {
			cues = {
				{ t = 0.0, som = "trava", pos = { 66.2, 3.8, -305 } },
				{ t = 1.0, fala = "pavel_silencio" },
				{ t = 2.9, som = "passos_longe" },
			},
		},
		s8_lista = {
			cues = {
				{ t = 0.0, som = "radio_chiado" },
				{ t = 0.8, fala = "elena_placa" },
				{ t = 6.8, fala = "pavel_731" },
				{ t = 9.2, fala = "elena_nome" },
				{ t = 12.0, fala = "pavel_registro" },
				{ t = 19.0, som = "tres_toques_parede", pos = { 88, 4.2, -297.6 } },
				{ t = 21.6, fala = "pavel_sinal" },
			},
		},
	},
}
