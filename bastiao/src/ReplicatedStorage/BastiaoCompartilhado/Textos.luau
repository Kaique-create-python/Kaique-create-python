-- PROJETO BASTIÃO :: todos os textos em 3 línguas (pt = português, en = English, ru = русский)
-- Chaves estáveis: a lógica nunca usa o texto. O servidor manda só chaves; cada cliente mostra
-- e toca na língua escolhida pelo jogador (menu da bodycam ou a língua da conta Roblox).
-- Placas e etiquetas pintadas no cenário ficam em russo (a base é soviética); as telas dos
-- terminais, que contam a história, aparecem na língua de cada jogador.

local Textos = {}

Textos.IDIOMAS = { "pt", "en", "ru" }
Textos.PADRAO = "pt"
Textos.NOME_IDIOMA = { pt = "PORTUGUÊS", en = "ENGLISH", ru = "РУССКИЙ" }
Textos.TITULO_MENU = "IDIOMA · LANGUAGE · ЯЗЫК"

-- quem diz cada fala (não muda com a língua)
Textos.FALANTE = {
	pavel_cafe = "PAVEL",
	pavel_conferencia = "PAVEL",
	pavel_canal = "PAVEL",
	orlov_ordem = "ORLOV_RADIO",
	pavel_arsenal = "PAVEL",
	pavel_lista1 = "PAVEL",
	pavel_lista2 = "PAVEL",
	gravacao_sokolov = "GRAVACAO",
	pavel_afasta = "PAVEL",
	sistema_isolamento = "SISTEMA",
	pavel_confirma = "PAVEL_RADIO",
	orlov_falha = "ORLOV_RADIO",
	pavel_vamos = "PAVEL",
	pavel_entra = "PAVEL",
	pavel_silencio = "PAVEL",
	elena_placa = "ELENA_RADIO",
	pavel_731 = "PAVEL",
	elena_nome = "ELENA_RADIO",
	pavel_registro = "PAVEL",
	pavel_sinal = "PAVEL",
}

-- por onde a voz chega: na pessoa (3D, sai do Pavel), rádio, gravação velha no rádio, alto-falante
Textos.CANAL = {
	PAVEL = "pessoa",
	PAVEL_RADIO = "radio",
	ORLOV_RADIO = "radio",
	ELENA_RADIO = "radio",
	GRAVACAO = "gravacao",
	SISTEMA = "pa",
}

-- orientação de interpretação para gerar as vozes (tags do ElevenLabs v4; não vão para a tela)
Textos.DIRECAO = {
	pavel_cafe = "[tired]",
	pavel_conferencia = "[casual]",
	pavel_canal = "[serious]",
	orlov_ordem = "[cold] [formal]",
	pavel_arsenal = "[firm]",
	pavel_lista1 = "[slowly] [hesitant]",
	pavel_lista2 = "[quickly] [dismissive]",
	gravacao_sokolov = "[flat] [formal]",
	pavel_afasta = "[tense] [urgent]",
	sistema_isolamento = "[formal] [calm]",
	pavel_confirma = "[tense]",
	orlov_falha = "[cold] [curt]",
	pavel_vamos = "[urgent]",
	pavel_entra = "[whispers] [urgent]",
	pavel_silencio = "[whispers]",
	elena_placa = "[calm] [tired]",
	pavel_731 = "[quietly]",
	elena_nome = "[softly] [sad]",
	pavel_registro = "[low voice] [disturbed]",
	pavel_sinal = "[whispers] [fearful]",
}

local L = {}

L.pt = {
	falantes = {
		PAVEL = "PAVEL",
		PAVEL_RADIO = "PAVEL (RÁDIO)",
		ORLOV_RADIO = "ORLOV (RÁDIO)",
		ELENA_RADIO = "ELENA (RÁDIO)",
		GRAVACAO = "GRAVAÇÃO",
		SISTEMA = "SISTEMA DA BASE",
	},
	falas = {
		pavel_cafe = "Você pegou o turno em que até o café pede transferência.",
		pavel_conferencia = "KEDR, conferência de equipamento. Depois liberam a troca.",
		pavel_canal = "Canal três. Fala comigo antes de falar com o comando.",
		orlov_ordem = "KEDR, o terminal da enfermaria perdeu a reserva. Levem o módulo. Deixem no acesso externo. Não aguardem atendimento.",
		pavel_arsenal = "O módulo está no carregador do arsenal. Eu vou na frente.",
		pavel_lista1 = "Antonov. KEDR. Sokolov...",
		pavel_lista2 = "Impressão velha.",
		gravacao_sokolov = "Sokolov, Mikhail. Apresentar-se para avaliação.",
		pavel_afasta = "KEDR, afasta da porta.",
		sistema_isolamento = "Exercício Última Formação iniciado. Efetivo: permaneçam em seus setores.",
		pavel_confirma = "Comando, aqui Antonov. Que exercício? Ninguém avisou o turno.",
		orlov_falha = "Falha de protocolo. Sigam pela saída de serviço. Oficina, lado leste.",
		pavel_vamos = "Saída de serviço é pela oficina. Anda.",
		pavel_entra = "Entra. Fecha a trava atrás de você.",
		pavel_silencio = "Shh... Não se mexe.",
		elena_placa = "Tem uma placa de identificação no suporte das costas. Conseguiu ver o número?",
		pavel_731 = "731.",
		elena_nome = "Ele tinha um nome.",
		pavel_registro = "O nosso turno já está no arquivo do exercício. Preenchido antes de abrirem aquela porta.",
		pavel_sinal = "Eu conheço esse sinal.",
	},
	sons = {
		radio_chiado = "[CHIADO DE RÁDIO]",
		tres_toques = "[TRÊS TOQUES CURTOS NO METAL, AO LONGE]",
		inspiracao = "[UMA INSPIRAÇÃO LONGA ATRÁS DA PORTA]",
		pressurizacao = "[PRESSURIZAÇÃO DE UM RESERVATÓRIO · VAZAMENTO BREVE]",
		impacto_porta = "[ALGO PESADO BATE NA PORTA POR DENTRO]",
		alarme = "[ALARME DE ISOLAMENTO]",
		portas = "[PORTAS EXTERNAS FECHANDO]",
		passos_longe = "[PASSOS PESADOS EM OUTRO SETOR]",
		trava = "[TRAVA MECÂNICA FECHADA]",
		tres_toques_parede = "[TRÊS TOQUES CURTOS, DO OUTRO LADO DA PAREDE]",
	},
	objetivos = {
		radio = "Confira o rádio com Pavel",
		bateria = "Pegue o módulo de bateria no arsenal",
		terminal = "Leve o módulo ao terminal externo da enfermaria",
		oficina = "Chegue à oficina pelo corredor de serviço",
		trava = "Feche a trava da oficina",
		terminal_oficina = "Examine o terminal da oficina",
		piso = "Alcance o piso de manutenção",
	},
	prompts = {
		PegarRadio = "PEGAR RÁDIO",
		PegarModulo = "PEGAR MÓDULO",
		EncaixarModulo = "ENCAIXAR MÓDULO",
		FecharTrava = "FECHAR TRAVA",
		LerTerminal = "LER TERMINAL",
	},
	avisos = {
		modulo_no_carregador = "O módulo está no carregador do arsenal.",
		modulo_com = "O módulo está com %s.",
		modulo_voltou = "O módulo voltou ao carregador do arsenal.",
		entre_oficina = "Entre na oficina antes de fechar a trava.",
		espere_pavel = "Espere o Pavel entrar.",
	},
	terminais = {
		enfermaria_sem_energia = "SEVER-9 · ENFERMARIA\nACESSO EXTERNO\n\nRESERVA: SEM CARGA\nINSIRA O MÓDULO",
		enfermaria_ligado = "SEVER-9 · ENFERMARIA\nRESERVA: OK\n\nCIRCULAÇÃO ALA B: NOMINAL\nCONTENÇÃO: TRAVADA",
		enfermaria_autorizado = "AUTORIZAÇÃO EXTERNA RECEBIDA\n\nEXERCÍCIO AUTORIZADO\n\nCONTENÇÃO: LIBERADA",
		oficina_apagado = "SEVER-9 · OFICINA\nREDE DE MANUTENÇÃO\n\nAGUARDANDO OPERADOR",
		oficina_aguardando = "SEVER-9 · OFICINA\nREDE DE MANUTENÇÃO\n\n1 ARQUIVO NOVO:\nEXERCÍCIO ÚLTIMA FORMAÇÃO\n\n> LER",
		oficina_cabecalho = "ARQUIVO: EXERCÍCIO ÚLTIMA FORMAÇÃO\nEFETIVO AVALIADO (TURNO 02:00):",
		oficina_rodape = "REGISTRO: 02:31 · ANTES DA ABERTURA\nAUTORIZAÇÃO: [BLOQUEADO]",
		sgt = "SGT",
		presente = "PRESENTE",
		avaliacao = "AVALIAÇÃO",
		antonov = "ANTONOV, P.",
		sokolov = "SOKOLOV, M.",
	},
	fim = {
		titulo = "PROJETO BASTIÃO",
		capitulo = "CAPÍTULO 1 — A CHAMADA",
		linha = "FIM DA ABERTURA · O CAPÍTULO CONTINUA NA PRÓXIMA ATUALIZAÇÃO",
	},
	ui = { objetivo = "OBJETIVO", alerta = "● ALERTA · ISOLAMENTO", toque = "TOQUE" },
}

L.en = {
	falantes = {
		PAVEL = "PAVEL",
		PAVEL_RADIO = "PAVEL (RADIO)",
		ORLOV_RADIO = "ORLOV (RADIO)",
		ELENA_RADIO = "ELENA (RADIO)",
		GRAVACAO = "RECORDING",
		SISTEMA = "BASE SYSTEM",
	},
	falas = {
		pavel_cafe = "You picked the shift where even the coffee asks for a transfer.",
		pavel_conferencia = "KEDR, equipment check. Then they'll clear the shift change.",
		pavel_canal = "Channel three. Talk to me before you talk to command.",
		orlov_ordem = "KEDR, the infirmary terminal lost its backup power. Bring the module. Leave it at the external access. Do not wait for anyone.",
		pavel_arsenal = "The module is on the charger in the armory. I'll go ahead.",
		pavel_lista1 = "Antonov. KEDR. Sokolov...",
		pavel_lista2 = "Old printout.",
		gravacao_sokolov = "Sokolov, Mikhail. Report for evaluation.",
		pavel_afasta = "KEDR, get away from the door.",
		sistema_isolamento = "Exercise Last Formation has begun. All personnel: remain in your sectors.",
		pavel_confirma = "Command, this is Antonov. What exercise? Nobody told the shift.",
		orlov_falha = "Protocol fault. Use the service exit. The workshop, east side.",
		pavel_vamos = "The service exit is through the workshop. Move.",
		pavel_entra = "Get in. Lock it behind you.",
		pavel_silencio = "Shh... Don't move.",
		elena_placa = "There's an ID plate on the back brace. Could you see the number?",
		pavel_731 = "731.",
		elena_nome = "He had a name.",
		pavel_registro = "Our shift is already in the exercise file. Filled in before they opened that door.",
		pavel_sinal = "I know that signal.",
	},
	sons = {
		radio_chiado = "[RADIO STATIC]",
		tres_toques = "[THREE SHORT KNOCKS ON METAL, FAR AWAY]",
		inspiracao = "[A LONG INHALE BEHIND THE DOOR]",
		pressurizacao = "[A TANK PRESSURIZING · BRIEF LEAK]",
		impacto_porta = "[SOMETHING HEAVY SLAMS THE DOOR FROM INSIDE]",
		alarme = "[ISOLATION ALARM]",
		portas = "[EXTERNAL DOORS SLAMMING SHUT]",
		passos_longe = "[HEAVY FOOTSTEPS IN ANOTHER SECTOR]",
		trava = "[MECHANICAL LATCH LOCKED]",
		tres_toques_parede = "[THREE SHORT KNOCKS, ON THE OTHER SIDE OF THE WALL]",
	},
	objetivos = {
		radio = "Check the radio with Pavel",
		bateria = "Get the battery module from the armory",
		terminal = "Take the module to the infirmary's external terminal",
		oficina = "Reach the workshop through the service corridor",
		trava = "Lock the workshop latch",
		terminal_oficina = "Examine the workshop terminal",
		piso = "Reach the maintenance level",
	},
	prompts = {
		PegarRadio = "TAKE RADIO",
		PegarModulo = "TAKE MODULE",
		EncaixarModulo = "INSERT MODULE",
		FecharTrava = "LOCK LATCH",
		LerTerminal = "READ TERMINAL",
	},
	avisos = {
		modulo_no_carregador = "The module is on the charger in the armory.",
		modulo_com = "%s has the module.",
		modulo_voltou = "The module went back to the armory charger.",
		entre_oficina = "Get inside the workshop before locking the latch.",
		espere_pavel = "Wait for Pavel to get inside.",
	},
	terminais = {
		enfermaria_sem_energia = "SEVER-9 · INFIRMARY\nEXTERNAL ACCESS\n\nBACKUP: NO CHARGE\nINSERT MODULE",
		enfermaria_ligado = "SEVER-9 · INFIRMARY\nBACKUP: OK\n\nWARD B CIRCULATION: NOMINAL\nCONTAINMENT: LOCKED",
		enfermaria_autorizado = "EXTERNAL AUTHORIZATION:\nRECEIVED\n\nEXERCISE AUTHORIZED\n\nCONTAINMENT: RELEASED",
		oficina_apagado = "SEVER-9 · WORKSHOP\nMAINTENANCE NETWORK\n\nAWAITING OPERATOR",
		oficina_aguardando = "SEVER-9 · WORKSHOP\nMAINTENANCE NETWORK\n\n1 NEW FILE:\nEXERCISE LAST FORMATION\n\n> READ",
		oficina_cabecalho = "FILE: EXERCISE LAST FORMATION\nPERSONNEL UNDER EVALUATION (SHIFT 02:00):",
		oficina_rodape = "LOGGED: 02:31 · BEFORE THE OPENING\nAUTHORIZATION: [BLOCKED]",
		sgt = "SGT",
		presente = "PRESENT",
		avaliacao = "EVALUATION",
		antonov = "ANTONOV, P.",
		sokolov = "SOKOLOV, M.",
	},
	fim = {
		titulo = "PROJECT BASTION",
		capitulo = "CHAPTER 1 — THE CALL",
		linha = "END OF THE OPENING · THE CHAPTER CONTINUES IN THE NEXT UPDATE",
	},
	ui = { objetivo = "OBJECTIVE", alerta = "● ALERT · ISOLATION", toque = "TAP" },
}

L.ru = {
	falantes = {
		PAVEL = "ПАВЕЛ",
		PAVEL_RADIO = "ПАВЕЛ (РАЦИЯ)",
		ORLOV_RADIO = "ОРЛОВ (РАЦИЯ)",
		ELENA_RADIO = "ЕЛЕНА (РАЦИЯ)",
		GRAVACAO = "ЗАПИСЬ",
		SISTEMA = "СИСТЕМА БАЗЫ",
	},
	falas = {
		pavel_cafe = "Тебе досталась смена, где даже кофе просится на перевод.",
		pavel_conferencia = "КЕДР, проверка снаряжения. Потом дадут смену.",
		pavel_canal = "Третий канал. Сначала говоришь со мной, потом — с командованием.",
		orlov_ordem = "КЕДР, терминал медблока потерял резерв. Доставьте модуль. Оставьте у внешнего доступа. Ответа не ждать.",
		pavel_arsenal = "Модуль на зарядке в оружейной. Я пойду первым.",
		pavel_lista1 = "Антонов. КЕДР. Соколов...",
		pavel_lista2 = "Старая распечатка.",
		gravacao_sokolov = "Соколов, Михаил. Явиться на освидетельствование.",
		pavel_afasta = "КЕДР, отойди от двери.",
		sistema_isolamento = "Учение «Последнее построение» начато. Личному составу оставаться в своих секторах.",
		pavel_confirma = "Командование, это Антонов. Какое учение? Смену никто не предупреждал.",
		orlov_falha = "Сбой протокола. Уходите через служебный выход. Мастерская, восточная сторона.",
		pavel_vamos = "Служебный выход — через мастерскую. Пошли.",
		pavel_entra = "Заходи. Закрой засов за собой.",
		pavel_silencio = "Тсс... Не двигайся.",
		elena_placa = "На спинном креплении есть табличка. Ты разглядел номер?",
		pavel_731 = "731.",
		elena_nome = "У него было имя.",
		pavel_registro = "Наша смена уже в файле учения. Заполнено ещё до того, как открыли ту дверь.",
		pavel_sinal = "Я знаю этот сигнал.",
	},
	sons = {
		radio_chiado = "[ТРЕСК РАЦИИ]",
		tres_toques = "[ТРИ КОРОТКИХ УДАРА ПО МЕТАЛЛУ, ВДАЛЕКЕ]",
		inspiracao = "[ДОЛГИЙ ВДОХ ЗА ДВЕРЬЮ]",
		pressurizacao = "[СБРОС ДАВЛЕНИЯ · КОРОТКАЯ УТЕЧКА]",
		impacto_porta = "[ЧТО-ТО ТЯЖЁЛОЕ БЬЁТ В ДВЕРЬ ИЗНУТРИ]",
		alarme = "[СИРЕНА ИЗОЛЯЦИИ]",
		portas = "[ЗАКРЫВАЮТСЯ ВНЕШНИЕ ДВЕРИ]",
		passos_longe = "[ТЯЖЁЛЫЕ ШАГИ В ДРУГОМ СЕКТОРЕ]",
		trava = "[ЗАСОВ ЗАКРЫТ]",
		tres_toques_parede = "[ТРИ КОРОТКИХ УДАРА — ПО ТУ СТОРОНУ СТЕНЫ]",
	},
	objetivos = {
		radio = "Проверь рацию у Павла",
		bateria = "Возьми аккумуляторный модуль в оружейной",
		terminal = "Отнеси модуль к внешнему терминалу медблока",
		oficina = "Доберись до мастерской по служебному коридору",
		trava = "Закрой засов мастерской",
		terminal_oficina = "Осмотри терминал мастерской",
		piso = "Доберись до технического уровня",
	},
	prompts = {
		PegarRadio = "ВЗЯТЬ РАЦИЮ",
		PegarModulo = "ВЗЯТЬ МОДУЛЬ",
		EncaixarModulo = "ВСТАВИТЬ МОДУЛЬ",
		FecharTrava = "ЗАКРЫТЬ ЗАСОВ",
		LerTerminal = "ЧИТАТЬ ТЕРМИНАЛ",
	},
	avisos = {
		modulo_no_carregador = "Модуль на зарядке в оружейной.",
		modulo_com = "Модуль у %s.",
		modulo_voltou = "Модуль вернулся на зарядку в оружейной.",
		entre_oficina = "Сначала зайди в мастерскую.",
		espere_pavel = "Подожди, пока Павел войдёт.",
	},
	terminais = {
		enfermaria_sem_energia = "СЕВЕР-9 · МЕДБЛОК\nВНЕШНИЙ ДОСТУП\n\nРЕЗЕРВ: НЕТ ЗАРЯДА\nВСТАВЬТЕ МОДУЛЬ",
		enfermaria_ligado = "СЕВЕР-9 · МЕДБЛОК\nРЕЗЕРВ: НОРМА\n\nЦИРКУЛЯЦИЯ БЛОК Б: НОРМА\nИЗОЛЯЦИЯ: ЗАКРЫТО",
		enfermaria_autorizado = "ПОЛУЧЕНА ВНЕШНЯЯ АВТОРИЗАЦИЯ\n\nУЧЕНИЕ РАЗРЕШЕНО\n\nИЗОЛЯЦИЯ: СНЯТА",
		oficina_apagado = "СЕВЕР-9 · МАСТЕРСКАЯ\nТЕХНИЧЕСКАЯ СЕТЬ\n\nОЖИДАНИЕ ОПЕРАТОРА",
		oficina_aguardando = "СЕВЕР-9 · МАСТЕРСКАЯ\nТЕХНИЧЕСКАЯ СЕТЬ\n\n1 НОВЫЙ ФАЙЛ:\nУЧЕНИЕ «ПОСЛЕДНЕЕ ПОСТРОЕНИЕ»\n\n> ЧИТАТЬ",
		oficina_cabecalho = "ФАЙЛ: УЧЕНИЕ «ПОСЛЕДНЕЕ ПОСТРОЕНИЕ»\nОЦЕНИВАЕМЫЙ СОСТАВ (СМЕНА 02:00):",
		oficina_rodape = "ЗАПИСЬ: 02:31 · ДО ОТКРЫТИЯ\nПОДПИСЬ: [ЗАБЛОКИРОВАНО]",
		sgt = "СЕРЖ.",
		presente = "НА МЕСТЕ",
		avaliacao = "НА ОЦЕНКЕ",
		antonov = "АНТОНОВ П.",
		sokolov = "СОКОЛОВ М.",
	},
	fim = {
		titulo = "ПРОЕКТ «БАСТИОН»",
		capitulo = "ГЛАВА 1 — ВЫЗОВ",
		linha = "КОНЕЦ ПРОЛОГА · ПРОДОЛЖЕНИЕ В СЛЕДУЮЩЕМ ОБНОВЛЕНИИ",
	},
	ui = { objetivo = "ЗАДАЧА", alerta = "● ТРЕВОГА · ИЗОЛЯЦИЯ", toque = "КАСАНИЕ" },
}

Textos.L = L

-- como a voz deve LER algumas falas (só para gerar o áudio; a legenda fica como está acima):
-- números por extenso e o indicativo KEDR dito como palavra ("Kedr", cedro em russo)
Textos.FALADO = {
	pt = { pavel_731 = "Sete... três... um." },
	en = { pavel_731 = "Seven... three... one." },
	ru = { pavel_731 = "Семь... три... один." },
}
Textos.PRONUNCIA = {
	pt = { KEDR = "Kedr" },
	en = { KEDR = "Kedr" },
	ru = { ["КЕДР"] = "Кедр" },
}

-- placas, etiquetas e telas fixas do cenário (pintadas na base: em russo para todos)
Textos.MUNDO = {
	lista_turno = "СПИСОК СМЕНЫ\n02:00 · СЕВЕР-9\n\nАНТОНОВ П.\n  СЕРЖАНТ\nКЕДР\n  ГРУППА\nСОКОЛОВ М.\n  НА ОЦЕНКЕ",
	modulo = "РЕЗЕРВ 24В\nОПЛОМБИРОВАН",
	carregador = "ЗАРЯДКА · РЕЗЕРВ",
	contencao = "ИЗОЛЯЦИЯ · БЛОК Б\nДОСТУП ОГРАНИЧЕН\nМЕДОСМОТР",
	oficina = "МАСТЕРСКАЯ",
	trava = "ЗАСОВ",
	acesso_aberto = "ВНЕШНИЙ ДОСТУП\nОТКРЫТ",
	acesso_bloqueado = "ВНЕШНИЙ ДОСТУП\nЗАКРЫТ",
}

-- língua válida (qualquer outra coisa vira a padrão)
function Textos.normalizar(idioma: any): string
	if type(idioma) == "string" and L[idioma] then
		return idioma
	end
	return Textos.PADRAO
end

-- língua inicial a partir da língua da conta Roblox (ex.: "pt-br", "ru-ru", "en-us")
function Textos.daLocalidade(localidade: any): string
	local s = string.lower(tostring(localidade or ""))
	if string.sub(s, 1, 2) == "pt" then
		return "pt"
	elseif string.sub(s, 1, 2) == "ru" then
		return "ru"
	end
	return "en"
end

function Textos.de(idioma: any)
	return L[Textos.normalizar(idioma)]
end

-- compatibilidade com o código da Etapa 1 (servidor e testes usam o português como base)
Textos.falantes = L.pt.falantes
Textos.sons = L.pt.sons
Textos.objetivos = L.pt.objetivos
Textos.avisos = L.pt.avisos
Textos.fim = L.pt.fim
Textos.falas = {}
for chave, texto in L.pt.falas do
	Textos.falas[chave] = { Textos.FALANTE[chave], texto }
end

return Textos
