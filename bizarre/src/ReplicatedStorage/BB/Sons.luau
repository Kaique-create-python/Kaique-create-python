-- BIZARRE BATTLEGROUNDS :: sons gravados da biblioteca do Roblox (ProSoundEffects, APM e Roblox)
-- Esses áudios são liberados para qualquer jogo usar: não precisam de envio nem moderação.
-- Cada som pode ter várias variações (sorteia uma) e volume/velocidade próprios.

local Sons = {}

Sons.LISTA = {
	soco = { ids = { 9117969717, 9117969687, 9117969878, 9117969892, 9117970193 }, vol = 1.05, vel = { 0.95, 1.12 } },
	soco_rapido = { ids = { 9117969584, 9117970227, 9117969990, 9113487341, 9113487470 }, vol = 0.8, vel = { 1.0, 1.25 } },
	soco_forte = { ids = { 9119061110, 9119061517, 9119061271, 9119060951 }, vol = 1.4, vel = { 0.85, 1.0 } },
	whoosh = { ids = { 9120728815, 9120728883, 9120729007, 9120729005, 9120729134 }, vol = 0.72, vel = { 0.95, 1.15 } },
	whoosh_forte = { ids = { 9120729339, 9120729412, 9120729568 }, vol = 1.05, vel = { 0.8, 0.95 } },
	chute = { ids = { 9119061631, 9119061515, 9113502506 }, vol = 0.85, vel = { 0.9, 1.08 } },
	bloqueio = { ids = { 9119072660, 9119072674 }, vol = 0.7, vel = { 0.95, 1.1 } },
	parry = { ids = { 9119747138, 9116709512 }, vol = 1, vel = { 1.05, 1.2 } },
	quebra_guarda = { ids = { 9116690684, 9116690449 }, vol = 1, vel = { 0.9, 1.0 } },
	corte = { ids = { 9119746751, 9119746759, 9119746592, 9119746598 }, vol = 0.8, vel = { 0.95, 1.1 } },
	lamina = { ids = { 9120972321, 9120972444, 9120704978 }, vol = 0.7, vel = { 1.0, 1.2 } },
	estocada = { ids = { 9126013811, 9126013644, 9126013382 }, vol = 0.6, vel = { 1.0, 1.2 } },
	fogo = { ids = { 9114446852, 9114446277, 9114444052, 9114442751 }, vol = 0.8, vel = { 0.9, 1.1 } },
	fogo_grande = { ids = { 9114428748, 9114428742 }, vol = 1, vel = { 0.85, 1.0 } },
	chama = { ids = { 9114463219, 9114463410, 9114463016 }, vol = 0.7, vel = { 0.9, 1.0 } },
	explosao = { ids = { 9117982449, 9117982785, 9117982781, 9116973611 }, vol = 1, vel = { 0.9, 1.05 } },
	explosao_grande = { ids = { 9117876706, 9117876319, 9126102254 }, vol = 1, vel = { 0.85, 1.0 } },
	terremoto = { ids = { 9114224721, 9114221862, 9114224432 }, vol = 1, vel = { 0.9, 1.05 } },
	pedra = { ids = { 9118587698, 9118587494, 9118587701, 9118588165, 9119050772 }, vol = 0.8, vel = { 0.9, 1.1 } },
	vidro = { ids = { 9114591515, 9114590297, 9114592245, 9114592102, 9114591567 }, vol = 0.75, vel = { 0.95, 1.1 } },
	madeira = { ids = { 9120801590, 9120966676, 9125993215, 9120967003 }, vol = 0.8, vel = { 0.9, 1.1 } },
	metal = { ids = { 9116546593, 9116546326, 9116546968 }, vol = 0.8, vel = { 0.9, 1.05 } },
	queda = { ids = { 9113480915, 9113469292, 9113475819 }, vol = 0.7, vel = { 0.9, 1.1 } },
	grave = { ids = { 9045206449, 9043179511, 9045200505 }, vol = 1, vel = { 1, 1 } },
	sub = { ids = { 1837830050, 1837830084, 1837830071 }, vol = 1, vel = { 0.95, 1.05 } },
	tambor = { ids = { 1837829309, 1837829565 }, vol = 1, vel = { 0.9, 1.0 } },
	tempo_para = { ids = { 9126102694, 9126102843 }, vol = 1, vel = { 0.9, 0.9 } },
	tempo_volta = { ids = { 9120059060, 9120061271 }, vol = 1, vel = { 1, 1 } },
	tempo_eco = { ids = { 9120061266, 9119707271 }, vol = 0.9, vel = { 1, 1.1 } },
	relogio = { ids = { 9113816351, 9113816524, 9113816468 }, vol = 0.9, vel = { 1, 1 } },
	teleporte = { ids = { 9116422213, 9125648149 }, vol = 0.8, vel = { 1, 1.15 } },
	magia = { ids = { 9116395089, 9116394545, 9116384485 }, vol = 0.8, vel = { 1, 1.1 } },
	cura = { ids = { 9126073001, 9119447936 }, vol = 0.7, vel = { 1, 1 } },
	cristal = { ids = { 9114592509, 9114592103, 9114592716 }, vol = 0.55, vel = { 1.2, 1.45 } },
	despertar = { ids = { 9117297453, 9119816710, 1839901345 }, vol = 1, vel = { 1, 1 } },
	gongo = { ids = { 9114630843, 9114631461 }, vol = 0.9, vel = { 0.9, 1 } },
	ui_clique = { ids = { 15675059323, 15675032796 }, vol = 0.6, vel = { 1, 1.05 } },
	ui_selecao = { ids = { 10066968815, 10128760939 }, vol = 0.6, vel = { 1, 1 } },
	notificacao = { ids = { 17208361335 }, vol = 0.5, vel = { 1, 1 } },
	abate = { ids = { 9126073318, 9126076030 }, vol = 0.8, vel = { 0.9, 1 } },
	dash = { ids = { 9126229255, 9120704709, 9119741493 }, vol = 0.9, vel = { 1, 1.2 } },
	evasiva = { ids = { 9125807267, 9113070119 }, vol = 0.8, vel = { 1, 1.1 } },
	grito = { ids = { 9125652432, 9125652466, 9125652949, 9125652443 }, vol = 0.45, vel = { 0.95, 1.1 } },
	multidao = { ids = { 9120974911, 9120974378, 9120974515 }, vol = 0.5, vel = { 1, 1 } },
	eletrico = { ids = { 9116275998, 9116276946 }, vol = 0.6, vel = { 1, 1.1 } },
	vinil = { ids = { 1846552251, 1846572294 }, vol = 0.8, vel = { 1, 1 } },
	pulo = { ids = { 9125805579 }, vol = 0.5, vel = { 1.1, 1.3 } },
	impacto_grande = { ids = { 9043338036, 9125404320 }, vol = 1, vel = { 0.9, 1 } },
	onda = { ids = { 9125934358, 9120769331 }, vol = 0.9, vel = { 1, 1.1 } },
}

-- vozes dos Stands: trechos do áudio "BB_Vozes" (início em segundos, duração, volume, ordem).
-- "ordem" = posição no áudio: um áudio antigo com menos trechos só toca os que ele tem.
-- O áudio é gerado (vozes de banco, não são os dubladores do anime) e enviado pelo instalador.
Sons.VOZES = {
	BITES_THE_DUST = { 11.046, 2.562, 1.00, 6 },
	DORA = { 0.000, 1.363, 1.00, 1 },
	ORA = { 1.613, 1.420, 1.80, 2 },
	ORA_FINAL = { 3.283, 1.677, 1.80, 3 },
	SP_THE_WORLD = { 5.210, 2.411, 1.80, 4 },
	ZA_WARUDO = { 7.870, 2.925, 1.80, 5 },
} :: { [string]: { number } }

-- AJUSTE-8: sons do anime mandados pelo dono (áudio separado: se o Roblox recusar, os de cima ficam)
Sons.VOZES_ANIME = {
	MUDA_ANIME = { 0.000, 4.935, 2.60, 1 },
	ORA_ANIME = { 5.185, 5.243, 2.60, 2 },
	SP_TEMPO = { 10.678, 3.489, 2.60, 3 },
	TW_TEMPO = { 14.416, 4.017, 2.60, 4 },
} :: { [string]: { number } }

-- AJUSTE-13: sons de golpe do dono (tools/sons_sfx.py: grave forte, um pouco estourado, começo
-- cortado para o estalo sair na hora). Áudio "BB_SFX" enviado pelo instalador; ordem fixa.
Sons.SFX = {
	SOCO_A = { 0.000, 0.600, 1.60, 1 },
	SOCO_B = { 0.850, 0.740, 1.60, 2 },
	SOCO_MEGA = { 1.840, 0.880, 1.90, 3 },
	WHOOSH_SOCO = { 2.970, 0.420, 1.10, 4 },
} :: { [string]: { number } }

-- músicas (APM). O menu tem samba; a luta tem rock/percussão. AJUSTE-13: desligadas (Config.MUSICA)
Sons.MUSICAS = {
	menu = { 1846271148, 1835572198 }, -- Samba Viva, Samba Do Jazz
	luta = { 9048541013, 9038389507, 9038389225, 9044584995 }, -- Battleground, Fight Fuel, Finger on the Trigger, Underworld Fighters
	tempo = 9047875834, -- Bossa Cruse: toca baixinho durante o tempo parado
}

-- som de cada material quebrando
Sons.MATERIAL = {
	Glass = "vidro",
	Wood = "madeira",
	WoodPlanks = "madeira",
	Metal = "metal",
	DiamondPlate = "metal",
	CorrodedMetal = "metal",
}

function Sons.doMaterial(nomeMaterial: string): string
	return Sons.MATERIAL[nomeMaterial] or "pedra"
end

function Sons.todosIds(): { number }
	local lista = {}
	local vistos = {}
	for _, s in Sons.LISTA do
		for _, id in s.ids do
			if not vistos[id] then
				vistos[id] = true
				table.insert(lista, id)
			end
		end
	end
	for _, grupo in Sons.MUSICAS do
		if type(grupo) == "table" then
			for _, id in grupo do
				if not vistos[id] then
					vistos[id] = true
					table.insert(lista, id)
				end
			end
		elseif not vistos[grupo] then
			vistos[grupo] = true
			table.insert(lista, grupo)
		end
	end
	return lista
end

return Sons
