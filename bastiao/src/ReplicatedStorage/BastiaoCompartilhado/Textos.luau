-- PROJETO BASTIÃO :: textos da Etapa 1 (pt-BR). Chaves estáveis; a lógica nunca usa o texto.
-- Sem vozes gravadas ainda: cada fala vira legenda e cada som importante vira uma legenda de áudio.

local Textos = {}

Textos.falantes = {
	PAVEL = "PAVEL",
	PAVEL_RADIO = "PAVEL (RÁDIO)",
	ORLOV_RADIO = "ORLOV (RÁDIO)",
	ELENA_RADIO = "ELENA (RÁDIO)",
	GRAVACAO = "GRAVAÇÃO",
	SISTEMA = "SISTEMA DA BASE",
}

Textos.falas = {
	pavel_cafe = { "PAVEL", "Você pegou o turno em que até o café pede transferência." },
	pavel_conferencia = { "PAVEL", "KEDR, conferência de equipamento. Depois liberam a troca." },
	pavel_canal = { "PAVEL", "Canal três. Fala comigo antes de falar com o comando." },
	orlov_ordem = { "ORLOV_RADIO", "KEDR, o terminal da enfermaria perdeu a reserva. Levem o módulo. Deixem no acesso externo. Não aguardem atendimento." },
	pavel_arsenal = { "PAVEL", "O módulo está no carregador do arsenal. Eu vou na frente." },
	pavel_lista1 = { "PAVEL", "Antonov. KEDR. Sokolov..." },
	pavel_lista2 = { "PAVEL", "Impressão velha." },
	gravacao_sokolov = { "GRAVACAO", "Sokolov, Mikhail. Apresentar-se para avaliação." },
	pavel_afasta = { "PAVEL", "KEDR, afasta da porta." },
	sistema_isolamento = { "SISTEMA", "Exercício Última Formação iniciado. Efetivo: permaneçam em seus setores." },
	pavel_confirma = { "PAVEL_RADIO", "Comando, aqui Antonov. Que exercício? Ninguém avisou o turno." },
	orlov_falha = { "ORLOV_RADIO", "Falha de protocolo. Sigam pela saída de serviço. Oficina, lado leste." },
	pavel_vamos = { "PAVEL", "Saída de serviço é pela oficina. Anda." },
	pavel_entra = { "PAVEL", "Entra. Fecha a trava atrás de você." },
	elena_placa = { "ELENA_RADIO", "Tem uma placa de identificação no suporte das costas. Conseguiu ver o número?" },
	pavel_731 = { "PAVEL", "731." },
	elena_nome = { "ELENA_RADIO", "Ele tinha um nome." },
	pavel_registro = { "PAVEL", "O nosso turno já está no arquivo do exercício. Preenchido antes de abrirem aquela porta." },
	pavel_sinal = { "PAVEL", "Eu conheço esse sinal." },
}

-- sons importantes enquanto não há áudio gravado (acessibilidade também: entende sem ouvir)
Textos.sons = {
	radio_chiado = "[CHIADO DE RÁDIO]",
	tres_toques = "[TRÊS TOQUES CURTOS NO METAL, AO LONGE]",
	inspiracao = "[UMA INSPIRAÇÃO LONGA ATRÁS DA PORTA]",
	pressurizacao = "[PRESSURIZAÇÃO DE UM RESERVATÓRIO · VAZAMENTO BREVE]",
	alarme = "[ALARME DE ISOLAMENTO]",
	portas = "[PORTAS EXTERNAS FECHANDO]",
	passos_longe = "[PASSOS PESADOS EM OUTRO SETOR]",
	trava = "[TRAVA MECÂNICA FECHADA]",
	tres_toques_parede = "[TRÊS TOQUES CURTOS, DO OUTRO LADO DA PAREDE]",
}

Textos.objetivos = {
	radio = "Confira o rádio com Pavel",
	bateria = "Pegue o módulo de bateria no arsenal",
	terminal = "Leve o módulo ao terminal externo da enfermaria",
	oficina = "Chegue à oficina pelo corredor de serviço",
	trava = "Feche a trava da oficina",
	terminal_oficina = "Examine o terminal da oficina",
	piso = "Alcance o piso de manutenção",
}

Textos.prompts = {
	radio = "PEGAR RÁDIO",
	bateria = "PEGAR MÓDULO",
	encaixar = "ENCAIXAR MÓDULO",
	trava = "FECHAR TRAVA",
	terminal_oficina = "LER TERMINAL",
}

Textos.terminais = {
	enfermaria_sem = "SEVER-9 · ENFERMARIA\nACESSO EXTERNO\n\nRESERVA: SEM CARGA\nINSIRA O MÓDULO",
	enfermaria_ligado = "SEVER-9 · ENFERMARIA\nRESERVA: OK\n\nCIRCULAÇÃO ALA B: NOMINAL\nCONTENÇÃO: TRAVADA",
	enfermaria_autorizado = "AUTORIZAÇÃO EXTERNA RECEBIDA\n\nEXERCÍCIO AUTORIZADO\n\nCONTENÇÃO: LIBERADA",
	oficina_apagado = "SEVER-9 · OFICINA\nREDE DE MANUTENÇÃO\n\nAGUARDANDO OPERADOR",
	oficina_aguardando = "SEVER-9 · OFICINA\nREDE DE MANUTENÇÃO\n\n1 ARQUIVO NOVO:\nEXERCÍCIO ÚLTIMA FORMAÇÃO\n\n> LER",
	oficina_cabecalho = "ARQUIVO: EXERCÍCIO ÚLTIMA FORMAÇÃO\nEFETIVO AVALIADO (TURNO 02:00):",
	oficina_rodape = "REGISTRO: 02:31 · ANTES DA ABERTURA\nAUTORIZAÇÃO: [BLOQUEADO]",
}

-- textos impressos em objetos do cenário
Textos.objetos = {
	lista_turno = "LISTA DE TURNO\n02:00 · SEVER-9\n\nANTONOV, P.\n  SGT\nKEDR\n  EQUIPE\nSOKOLOV, M.\n  AVALIAÇÃO",
}

-- respostas curtas quando uma interação não pode acontecer agora
Textos.avisos = {
	modulo_no_carregador = "O módulo está no carregador do arsenal.",
	modulo_com = "O módulo está com %s.",
	modulo_voltou = "O módulo voltou ao carregador do arsenal.",
	entre_oficina = "Entre na oficina antes de fechar a trava.",
	espere_pavel = "Espere o Pavel entrar.",
}

Textos.fim = {
	titulo = "PROJETO BASTIÃO",
	capitulo = "CAPÍTULO 1 — A CHAMADA",
	linha = "FIM DA ETAPA 1 · A ABERTURA CONTINUA NA PRÓXIMA ATUALIZAÇÃO",
}

return Textos
