-- OI3 :: o resto do Capítulo 1 (AJUSTE-8) — DADOS das missões, iguais no servidor e no cliente.
-- Segue o roteiro revisado ("A brincadeira nunca terminou"): 7 missões que parecem brincadeiras de
-- criança, a descoberta no porão e o final no carro. Nada aqui explica quem é a entidade, quem é a
-- quarta criança ou o nome do menino/pai (ainda não são oficiais).
--
-- Cada missão acontece num "cenário" montado no aparelho de cada jogador (MissoesMapa). O servidor
-- (OI3_Servidor/Missoes) decide o passo atual do GRUPO; o cliente mostra objetivo, pontos de
-- interação e os sustos.
--
-- Tipos de passo:
--   evento   — algo acontece sozinho (fala, susto, lembrança) e o jogo segue depois de "dur" segundos
--   achar    — interagir com TODOS os pontos (qualquer ordem)
--   ordem    — interagir com os pontos NA ORDEM (errou = recomeça)
--   codigo   — digitar o código no teclado do ponto
--   esconder — esconde-esconde com a sombra (Missão 1)
--   cadeiras — ficar sentado enquanto a voz conta até dez sem olhar a quarta cadeira (Missão 7)
--   fuga     — correr até a saída (o orfanato desmoronando)

local Missoes = {}

-- ponto = { id, ação (texto do botão), objeto (o que é) }
local function P(id: string, acao: string, objeto: string)
	return { id = id, acao = acao, objeto = objeto }
end

Missoes.CODIGO_LAVANDERIA = "714" -- os números dos balões: azul, vermelho, amarelo
Missoes.CODIGO_PORAO = "3194" -- os números que piscam na última fita do projetor
Missoes.DIGITOS_BALOES = { bal_azul = "7", bal_vermelho = "1", bal_amarelo = "4" }

Missoes.LISTA = {
	-----------------------------------------------------------------------
	{
		id = "esconde",
		titulo = "Missão 1",
		nome = "Esconde-esconde",
		cenario = "quarto",
		passos = {
			{ tipo = "evento", evento = "m1_inicio", dur = 11 },
			{ tipo = "esconder", rodadas = 3, objetivo = "Esconda-se da sombra" },
			{ tipo = "achar", objetivo = "Olhe embaixo da última cama", pontos = { P("cama_ultima", "Olhar", "Cama") } },
			{ tipo = "evento", evento = "m1_desenhos", dur = 9 },
			{ tipo = "achar", objetivo = "Saia para o corredor", pontos = { P("porta_saida", "Sair", "Porta") } },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "festa",
		titulo = "Missão 2",
		nome = "A festa de aniversário",
		cenario = "festa",
		passos = {
			{ tipo = "evento", evento = "m2_inicio", dur = 8 },
			{
				tipo = "achar",
				objetivo = "Ache os balões",
				pontos = { P("bal_azul", "Pegar", "Balão azul"), P("bal_vermelho", "Pegar", "Balão vermelho"), P("bal_amarelo", "Pegar", "Balão amarelo") },
			},
			{ tipo = "achar", objetivo = "Ache a agulha do toca-discos", pontos = { P("agulha", "Pegar", "Agulha") } },
			{ tipo = "achar", objetivo = "Conserte o toca-discos", pontos = { P("toca_discos", "Consertar", "Toca-discos") } },
			{
				tipo = "achar",
				objetivo = "Arrume os pratos e os copos",
				pontos = { P("prato1", "Arrumar", "Prato"), P("prato2", "Arrumar", "Prato"), P("prato3", "Arrumar", "Prato"), P("prato4", "Arrumar", "Prato") },
			},
			{
				tipo = "achar",
				objetivo = "Ache as velas",
				pontos = { P("vela_a", "Pegar", "Vela"), P("vela_b", "Pegar", "Vela"), P("vela_c", "Pegar", "Vela"), P("vela_d", "Pegar", "Vela") },
			},
			{
				tipo = "ordem",
				objetivo = "Acenda as velas na ordem dos desenhos",
				pontos = { P("bolo_vermelha", "Acender", "Vela vermelha"), P("bolo_azul", "Acender", "Vela azul"), P("bolo_amarela", "Acender", "Vela amarela"), P("bolo_verde", "Acender", "Vela verde") },
			},
			{ tipo = "evento", evento = "m2_esqueceram", dur = 13 },
			{ tipo = "codigo", objetivo = "Abra a lavanderia (a senha está nos balões)", ponto = P("teclado_lavanderia", "Digitar", "Porta da lavanderia"), codigo = Missoes.CODIGO_LAVANDERIA },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "lavanderia",
		titulo = "Missão 3",
		nome = "A lavanderia",
		cenario = "lavanderia",
		passos = {
			{ tipo = "evento", evento = "m3_inicio", dur = 6 },
			{ tipo = "achar", objetivo = "Ache o registro principal", pontos = { P("registro", "Fechar", "Registro") } },
			{
				tipo = "ordem",
				objetivo = "Desligue as máquinas na ordem do bilhete",
				pontos = { P("maquina3", "Desligar", "Máquina 3"), P("maquina1", "Desligar", "Máquina 1"), P("maquina4", "Desligar", "Máquina 4"), P("maquina2", "Desligar", "Máquina 2") },
			},
			{ tipo = "achar", objetivo = "Passe pelo espaço apertado até a válvula", pontos = { P("valvula", "Girar", "Válvula") } },
			{ tipo = "achar", objetivo = "Pegue a chave presa na roupinha", pontos = { P("chave", "Pegar", "Chave") } },
			{ tipo = "evento", evento = "m3_voz", dur = 6 },
			{ tipo = "achar", objetivo = "Abra o corredor de serviço", pontos = { P("porta_servico", "Abrir", "Porta") } },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "espelhos",
		titulo = "Missão 4",
		nome = "O jogo dos espelhos",
		cenario = "espelhos",
		passos = {
			{ tipo = "evento", evento = "m4_inicio", dur = 6 },
			{
				-- só uma parede é passagem de verdade: a que aparece como porta no reflexo
				tipo = "achar",
				objetivo = "Use os reflexos: ache a porta que existe de verdade",
				pontos = { P("parede_certa", "Empurrar", "Parede") },
				falsos = { "parede1", "parede2", "parede4", "parede5", "parede6" },
			},
			{ tipo = "achar", objetivo = "Chegue perto do último espelho", pontos = { P("ultimo_espelho", "Olhar", "Espelho") } },
			{ tipo = "evento", evento = "m4_ultimo", dur = 9 },
			{ tipo = "achar", objetivo = "Entre no quarto trancado", pontos = { P("porta_quarto", "Entrar", "Quarto trancado") } },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "parede",
		titulo = "Missão 5",
		nome = "A criança na parede",
		cenario = "quarto_trancado",
		passos = {
			{ tipo = "evento", evento = "m5_inicio", dur = 6 },
			{
				tipo = "achar",
				objetivo = "Bata nas paredes e escute: ache a parede oca",
				pontos = { P("parede_oca", "Bater", "Parede") },
				falsos = { "bater1", "bater2", "bater3", "bater4" },
			},
			{ tipo = "achar", objetivo = "Arraste o armário", pontos = { P("armario", "Arrastar", "Armário") } },
			{ tipo = "achar", objetivo = "Arranque o papel de parede solto", pontos = { P("papel", "Arrancar", "Papel de parede") } },
			{ tipo = "achar", objetivo = "Ache o mecanismo atrás dos desenhos", pontos = { P("mecanismo", "Apertar", "Desenhos") } },
			{ tipo = "achar", objetivo = "Entre na passagem", pontos = { P("passagem", "Entrar", "Passagem") } },
			{ tipo = "evento", evento = "m5_desenho", dur = 14 },
			{ tipo = "achar", objetivo = "Siga até o escritório", pontos = { P("saida", "Seguir", "Passagem") } },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "projetor",
		titulo = "Missão 6",
		nome = "O projetor",
		cenario = "escritorio",
		passos = {
			{ tipo = "evento", evento = "m6_inicio", dur = 5 },
			{ tipo = "achar", objetivo = "Ache uma lâmpada para o projetor", pontos = { P("gaveta", "Abrir", "Gaveta") } },
			{
				tipo = "achar",
				objetivo = "Ligue os cabos da energia",
				pontos = { P("cabo1", "Ligar", "Cabo vermelho"), P("cabo2", "Ligar", "Cabo azul"), P("cabo3", "Ligar", "Cabo amarelo") },
			},
			{ tipo = "achar", objetivo = "Ligue a chave geral", pontos = { P("chave_geral", "Ligar", "Chave geral") } },
			{
				tipo = "ordem",
				objetivo = "Coloque as fitas em ordem de data",
				pontos = { P("fita1987", "Colocar", "Fita 1987"), P("fita1991", "Colocar", "Fita 1991"), P("fita1994", "Colocar", "Fita 1994") },
			},
			{ tipo = "achar", objetivo = "Ajuste o foco do projetor", pontos = { P("lente", "Ajustar", "Projetor") } },
			{ tipo = "evento", evento = "m6_filme", dur = 26 },
			{ tipo = "achar", objetivo = "Desça para o porão", pontos = { P("escada", "Descer", "Escada") } },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "cadeiras",
		titulo = "Missão 7",
		nome = "As três cadeiras",
		cenario = "cadeiras",
		passos = {
			{ tipo = "evento", evento = "m7_inicio", dur = 6 },
			{
				-- cada brinquedo na cadeira da criança dona dele (as fotos na parede mostram quem é quem)
				tipo = "achar",
				objetivo = "Leve cada brinquedo para a cadeira do dono",
				pontos = { P("cadeira_ke", "Colocar", "Cadeira do Keko"), P("cadeira_ni", "Colocar", "Cadeira da Nina"), P("cadeira_me", "Colocar", "Cadeira sem nome") },
				escolher = { "carrinho", "boneca", "ursinho" },
				respostas = { cadeira_ke = "carrinho", cadeira_ni = "boneca", cadeira_me = "ursinho" },
			},
			{ tipo = "cadeiras", objetivo = "Sentem nas cadeiras. Não olhem para trás." },
			{ tipo = "evento", evento = "m7_maos", dur = 8 },
			{ tipo = "codigo", objetivo = "Abra a porta do porão (os números da fita)", ponto = P("porta_porao", "Digitar", "Porta do porão"), codigo = Missoes.CODIGO_PORAO },
		},
	},
	-----------------------------------------------------------------------
	{
		id = "porao",
		titulo = "Missão 8",
		nome = "O porão",
		cenario = "porao",
		passos = {
			{ tipo = "evento", evento = "m8_inicio", dur = 5 },
			{
				tipo = "achar",
				objetivo = "Ache as três peças do mecanismo",
				pontos = { P("peca_gaveta", "Procurar", "Gaveta"), P("peca_caixa", "Procurar", "Caixa"), P("peca_quadro", "Procurar", "Quadro de fotos") },
				perseguicao = true,
			},
			{
				tipo = "ordem",
				objetivo = "Aperte os símbolos na ordem das marcas da parede",
				pontos = { P("simbolo_circulo", "Apertar", "Círculo"), P("simbolo_olho", "Apertar", "Olho"), P("simbolo_espiral", "Apertar", "Espiral"), P("simbolo_tres", "Apertar", "Três riscos") },
			},
			{ tipo = "achar", objetivo = "Encaixe as peças no mecanismo", pontos = { P("mecanismo", "Encaixar", "Mecanismo") } },
			{
				tipo = "achar",
				objetivo = "Procure as provas",
				pontos = { P("documentos", "Ler", "Documentos"), P("foto_apagada", "Olhar", "Fotografia") },
			},
			{ tipo = "achar", objetivo = "Toque a fita do gravador", pontos = { P("gravador", "Tocar", "Gravador") } },
			{ tipo = "evento", evento = "m8_gravacao", dur = 9 },
			{
				tipo = "achar",
				objetivo = "Coloque os três brinquedos diante do espelho",
				pontos = { P("lugar_carrinho", "Colocar", "Carrinho"), P("lugar_boneca", "Colocar", "Boneca"), P("lugar_ursinho", "Colocar", "Ursinho") },
			},
			{ tipo = "evento", evento = "descoberta", dur = 34 },
			{ tipo = "fuga", objetivo = "FUJAM! Corram até a saída", dur = 60 },
		},
	},
}

Missoes.TOTAL = #Missoes.LISTA

-- funções puras (testáveis) ------------------------------------------------

function Missoes.missao(n: number)
	return Missoes.LISTA[n]
end

function Missoes.passo(n: number, i: number)
	local m = Missoes.LISTA[n]
	return m and m.passos[i]
end

-- todos os ids de ponto de um passo (os "falsos" também têm botão, mas não contam)
function Missoes.pontosDoPasso(passo: any): { string }
	local ids = {}
	if not passo then
		return ids
	end
	for _, p in passo.pontos or {} do
		table.insert(ids, p.id)
	end
	if passo.ponto then
		table.insert(ids, passo.ponto.id)
	end
	return ids
end

function Missoes.infoPonto(passo: any, id: string): any
	for _, p in (passo and passo.pontos) or {} do
		if p.id == id then
			return p
		end
	end
	if passo and passo.ponto and passo.ponto.id == id then
		return passo.ponto
	end
	return nil
end

-- texto do objetivo com o progresso (ex.: "Ache os balões (2/3)")
function Missoes.objetivo(passo: any, feitos: { [string]: boolean }?, extra: any?): string
	if not passo then
		return ""
	end
	local base = passo.objetivo or ""
	if passo.tipo == "achar" and passo.pontos and #passo.pontos > 1 then
		local n = 0
		for _, p in passo.pontos do
			if feitos and feitos[p.id] then
				n += 1
			end
		end
		return string.format("%s (%d/%d)", base, n, #passo.pontos)
	elseif passo.tipo == "esconder" then
		return string.format("%s (%d/%d)", base, (extra and extra.rodada or 0), passo.rodadas or 3)
	end
	return base
end

-- confere uma sequência de "ordem": devolve "certo", "continua" ou "errado"
function Missoes.conferirOrdem(passo: any, sequencia: { string }): string
	local esperado = passo.pontos
	for i, id in sequencia do
		if not esperado[i] or esperado[i].id ~= id then
			return "errado"
		end
	end
	if #sequencia == #esperado then
		return "certo"
	end
	return "continua"
end

-- a próxima missão/passo depois de (n, i); devolve nil quando o capítulo acabou
function Missoes.proximo(n: number, i: number): (number?, number?)
	local m = Missoes.LISTA[n]
	if m and i < #m.passos then
		return n, i + 1
	end
	if n < Missoes.TOTAL then
		return n + 1, 1
	end
	return nil, nil
end

return Missoes
