-- OI3 :: falas da abertura (adaptação provisória da história dos criadores)
-- O nome do menino e o nome do pai NÃO foram definidos: o nome gritado aparece censurado.

local Dialogos = {}

Dialogos.FALANTES = {
	VO = { nome = "Vô", cor = Color3.fromRGB(226, 196, 150) },
	KE = { nome = "Keko", cor = Color3.fromRGB(214, 84, 84) },
	NI = { nome = "Nina", cor = Color3.fromRGB(196, 168, 232) },
	ME = { nome = "Menino", cor = Color3.fromRGB(120, 168, 236) },
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
}

-- Barra de censura (nome ainda não definido pelos criadores)
Dialogos.CENSURA = '<mark color="#D8D2C6" transparency="0"><font color="#D8D2C6">XXXXXXX</font></mark>!'

return Dialogos
