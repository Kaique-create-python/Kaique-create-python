-- BIZARRE BATTLEGROUNDS :: configuração geral (números de combate, IDs e ajustes)
-- Tudo que é "balanceamento" fica aqui para ser fácil de mexer depois.

local Config = {}

Config.REVISAO = "AJUSTE-10"
-- AJUSTE-10: o mapa Morioh fica intacto (regra do dono): não tira enfeites nem sombras
Config.SIMPLIFICAR_MAPA = false
Config.NOME_JOGO = "BIZARRE BATTLEGROUNDS"

-- dono e ADMs (o dono sempre é ADM; quem criou a experiência também)
Config.DONO_USERID = 1357078972
Config.ADMINS = {}
Config.UNIVERSE_ID = 10774214555
Config.PLACE_ID = 108061345551908

-- personagem
Config.VIDA = 100
Config.ANDAR = 18 -- velocidade normal
Config.CORRER = 27 -- corrida automática (depois de andar um tempinho)
Config.TEMPO_PARA_CORRER = 0.5
Config.PULO = 7.6 -- altura do pulo (studs)
Config.REGEN_ATRASO = 9 -- segundos sem levar dano para começar a curar
Config.REGEN_POR_SEGUNDO = 2.5
Config.RESPAWN = 4
Config.PROTECAO_SPAWN = 3 -- segundos de proteção ao nascer
Config.FORA_DE_COMBATE = 6 -- segundos sem dano para poder trocar de Stand

-- M1 (combo básico de 4 golpes)
Config.M1 = {
	intervalo = 0.3, -- tempo entre um golpe e o próximo
	reset = 1.2, -- sem bater por esse tempo, o combo volta ao 1º golpe
	recargaFinal = 1.1, -- descanso depois do 4º golpe
	dano = { 3, 3, 3, 5 },
	danoStand = { 3.5, 3.5, 3.5, 6 }, -- com o Stand para fora bate mais forte e mais longe
	atordoar = 0.62,
	hitbox = { tam = Vector3.new(5, 5.5, 5.5), frente = 3.4 },
	hitboxStand = { tam = Vector3.new(6, 6, 7), frente = 4.6 },
	empurraoLeve = 7, -- golpes 1 a 3 empurram um pouquinho
	-- 4º golpe: arremessa (ragdoll), sobe (uppercut) se pulando, ou crava no chão se no ar
	-- AJUSTE-2: bem mais curto (antes jogava o personagem longe demais)
	final = { frente = 46, cima = 16, dur = 0.14, ragdoll = 1.1, quebra = 2 },
	finalCima = { frente = 8, cima = 62, dur = 0.13, ragdoll = 1.2, quebra = 1 },
	finalBaixo = { frente = 6, cima = -90, dur = 0.12, ragdoll = 1.1, quebra = 2 },
}

-- bloqueio (segurar F / botão BLOQ)
Config.BLOQUEIO = {
	guardaMax = 100,
	reducao = 0.88, -- quanto do dano o bloqueio segura
	gastoPorDano = 6.5, -- cada ponto de dano bloqueado gasta isso de guarda
	recuperaAtraso = 1.4,
	recuperaPorSegundo = 34,
	parryJanela = 0.22, -- apertar bloqueio logo antes do golpe = PARRY
	parryAtordoa = 1.1,
	quebraAtordoa = 1.9, -- guarda quebrada
	andar = 7,
	angulo = 0.15, -- produto escalar mínimo: só bloqueia de frente
}

-- dash (Q / botão DASH)
Config.DASH = {
	frente = { vel = 82, dur = 0.28, recarga = 2.4 },
	lado = { vel = 74, dur = 0.22, recarga = 1.6 },
	tras = { vel = 70, dur = 0.22, recarga = 1.8 },
}

-- AJUSTE-2: empurrões de golpes com ragdoll ficam mais curtos (ninguém voa longe demais)
Config.EMPURRAO = {
	multRagdoll = 0.62, -- multiplica a força dos golpes que derrubam
	durMax = 0.17, -- tempo máximo empurrando com força total
	velMax = 95, -- velocidade máxima de qualquer empurrão
	imuneDepois = 0.9, -- AJUSTE-3: depois de levantar, segundos sem cair de novo
}

-- evasiva: Q/DASH quando estiver atordoado ou no chão (barra recarrega sozinha)
Config.EVASIVA = {
	recarga = 22,
	invencivel = 0.65,
	raioEmpurrao = 11,
	empurrao = 46,
}

-- despertar (barra enche batendo e apanhando; G / botão DESPERTAR)
Config.DESPERTAR = {
	max = 100,
	porDanoCausado = 0.95,
	porDanoRecebido = 0.5,
	duracao = 45,
	multDano = 1.18,
	multRecarga = 0.55,
	invencivelAoDespertar = 1.4,
}

-- ragdoll e queda
Config.RAGDOLL_MAX = 2.4
Config.ATORDOAR_MAX = 3
Config.ALTURA_MINIMA = -60 -- caiu do mapa: volta para um spawn

-- combo e sequência
Config.COMBO_JANELA = 1.6
Config.CREDITO_ABATE = 14 -- segundos: quem bateu por último leva o abate

-- mapa quebrável (Morioh: cada peça tem Health; a força do golpe vira dano)
Config.MAPA = {
	regenerar = 30, -- segundos para uma peça quebrada voltar
	regenerarVariacao = 10,
	destrocosAlto = 6, -- pedaços por peça (efeitos altos)
	destrocosBaixo = 3,
	limiteDestrocos = 320,
	maxPorImpacto = 40, -- peças que um golpe só pode quebrar de uma vez (celular aguenta)
	danoPorForca = { 60, 130, 220, 330, 520 }, -- força 1 a 5 -> dano nas peças
}

-- bots de treino
Config.BOTS = {
	maximo = 4,
	porJogador = 2,
	dificuldade = "medio",
}

-- som e música (volumes de 0 a 1)
Config.VOLUME_MUSICA = 0.32
Config.VOLUME_EFEITOS = 0.9

return Config
