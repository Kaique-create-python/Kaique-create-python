-- OI3 :: falas da abertura (adaptação provisória da história dos criadores)
-- O nome do menino e o nome do pai NÃO foram definidos: o nome gritado aparece censurado.

local Dialogos = {}

Dialogos.FALANTES = {
	VO = { nome = "Vô", cor = Color3.fromRGB(226, 196, 150) },
	KE = { nome = "Keko", cor = Color3.fromRGB(214, 84, 84) },
	NI = { nome = "Nina", cor = Color3.fromRGB(196, 168, 232) },
	ME = { nome = "Menino", cor = Color3.fromRGB(120, 168, 236) },
	-- AJUSTE-8: o resto do capítulo
	MU = { nome = "Mulher", cor = Color3.fromRGB(206, 200, 186) },
	CR = { nome = "???", cor = Color3.fromRGB(170, 170, 178) },
	RA = { nome = "Rádio", cor = Color3.fromRGB(150, 160, 150) },
}

-- texto = legenda (RichText permitido). censura = parte escondida.
Dialogos.FALAS = {
	VO_1 = { quem = "VO", texto = "Já está tarde, crianças... Todo mundo pra cama." },
	VO_2 = { quem = "VO", texto = "Boa noite. E nada de bagunça, hein?" },
	-- AJUSTE-6: a tarde e o jantar (voz vem no próximo ajuste; por enquanto só legenda)
	VO_3 = { quem = "VO", texto = "Vão brincar, crianças. Daqui a pouco eu chamo pro jantar." },
	VO_4 = { quem = "VO", texto = "Crianças! O jantar tá pronto!" },
	VO_5 = { quem = "VO", texto = "Aí não, criança. Essa porta fica fechada." },
	VO_6 = { quem = "VO", texto = "Comam tudo... e nada de ficar acordado até tarde, hein?" },
	KE_1 = { quem = "KE", texto = "Ei... vocês dois. Querem jogar um jogo?" },
	NI_1 = { quem = "NI", texto = "Que jogo, Keko?" },
	KE_2 = { quem = "KE", texto = "É um jogo proibido. Se chama..." },
	KE_3 = { quem = "KE", texto = "A regra é simples. Você fica na frente de um espelho... e grita três vezes o nome de alguém que já morreu." },
	ME_1 = { quem = "ME", texto = "Isso... é brincadeira, né?" },
	KE_4 = { quem = "KE", texto = "Você vai primeiro." },
	ME_2 = { quem = "ME", texto = "Eu? Tá bom... eu vou." },
	NI_2 = { quem = "NI", texto = "Que frio aqui..." },
	ME_3 = { quem = "ME", texto = "Eu vou chamar o meu pai." },
	ME_4A = { quem = "ME", texto = "", censura = true },
	ME_4B = { quem = "ME", texto = "", censura = true },
	ME_4C = { quem = "ME", texto = "", censura = true },
	ME_5 = { quem = "ME", texto = "TEM ALGUÉM NO ESPELHO!" },
	KE_5 = { quem = "KE", texto = "Que medroso! Não tem ninguém aí!" },
	NI_3 = { quem = "NI", texto = "Ele ficou com medo!" },
	-- AJUSTE-8: o resto do Capítulo 1 (poucas falas, como pede a história)
	KE_6 = { quem = "KE", texto = "Enquanto a Nina abre a porta... bora brincar de esconde-esconde?" },
	NI_4 = { quem = "NI", texto = "Eu vou achar um jeito de abrir essa porta." },
	NI_5 = { quem = "NI", texto = "Abriu! Vem, rápido!" },
	CR_1 = { quem = "CR", texto = "Não deixa ele me encontrar." },
	ME_6 = { quem = "ME", texto = "Você ainda não lembra?" },
	VO_7 = { quem = "VO", texto = "Desta vez... não pode dar errado." },
	VO_8 = { quem = "VO", texto = "Ninguém vem procurar por eles... Ninguém nunca vem." },
	ME_7 = { quem = "ME", texto = "Eu lembrei... esse é o meu rosto." },
	VO_9 = { quem = "VO", texto = "Pode deixar comigo. Eu levo os pequenos para um lugar seguro." },
	MU_1 = { quem = "MU", texto = "Muito obrigada, senhor. O senhor é muito gentil." },
	KE_8 = { quem = "RA", texto = "Oi..." },
	CONTA_3_RADIO = { quem = "RA", texto = "Três..." },
	RISADA_RADIO = { quem = "RA", texto = "(uma risadinha baixa)" },
	CONTA_1 = { quem = "CR", texto = "Um..." },
	CONTA_2 = { quem = "CR", texto = "Dois..." },
	CONTA_3 = { quem = "CR", texto = "Três..." },
	CONTA_4 = { quem = "CR", texto = "Quatro..." },
	CONTA_5 = { quem = "CR", texto = "Cinco..." },
	CONTA_6 = { quem = "CR", texto = "Seis..." },
	CONTA_7 = { quem = "CR", texto = "Sete..." },
	CONTA_8 = { quem = "CR", texto = "Oito..." },
	CONTA_9 = { quem = "CR", texto = "Nove..." },
	CONTA_10 = { quem = "CR", texto = "Dez." },
}

-- Barra de censura (nome ainda não definido pelos criadores)
Dialogos.CENSURA = '<mark color="#D8D2C6" transparency="0"><font color="#D8D2C6">XXXXXXX</font></mark>!'

return Dialogos
