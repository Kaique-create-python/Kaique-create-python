-- PROJETO BASTIÃO :: dados compartilhados (servidor e cliente)
-- Nomes de remotos/atributos/tags e a versão da etapa. Textos ficam em Textos e a tabela
-- de áudio (trechos de cada sprite e IDs enviados pelo instalador) em Audio.

local Compartilhado = {}

Compartilhado.ETAPA = "ETAPA-2"
Compartilhado.PASTA_REMOTOS = "BastiaoRemotos"
Compartilhado.REMOTO_APRESENTACAO = "Apresentacao" -- servidor -> clientes: falas, sons, avisos, corte
Compartilhado.REMOTO_IDIOMA = "Idioma" -- cliente -> servidor: troca de língua (pt/en/ru)
Compartilhado.PASTA_MUNDO = "BastiaoHistoria" -- tudo o que a história cria fica aqui (o mapa Sector7World não é tocado)

-- atributos no próprio módulo (replicam para todos; quem entra depois lê o estado atual)
Compartilhado.ATR_OBJETIVO = "BastiaoObjetivo"
Compartilhado.ATR_ALARME = "BastiaoAlarme"
Compartilhado.ATR_FIM = "BastiaoFimEtapa"
Compartilhado.ATR_ACESSO = "BastiaoAcessoExterno" -- "aberto"/"bloqueado" (motor lá fora para quando fecha)
-- atributo no Player: língua escolhida (pt/en/ru)
Compartilhado.ATR_IDIOMA = "BastiaoIdioma"

-- tags para o cliente achar as peças vivas (com streaming elas entram e saem)
Compartilhado.TAG_GIROFLEX = "BastiaoGiroflex"
Compartilhado.TAG_PROMPT = "BastiaoPrompt"
Compartilhado.TAG_TELA = "BastiaoTela" -- telas de terminal desenhadas na língua de cada jogador
-- atributos de uma tela: qual terminal, qual estado e (na lista) os nomes do turno
Compartilhado.ATR_TELA = "BastiaoTela"
Compartilhado.ATR_TELA_ESTADO = "BastiaoTelaEstado"
Compartilhado.ATR_TELA_NOMES = "BastiaoTelaNomes"

-- duração de uma legenda pelo tamanho do texto (quando não há voz gravada)
function Compartilhado.duracaoLeitura(texto: string): number
	return math.clamp(1.4 + #texto * 0.055, 2.2, 7.5)
end

return Compartilhado
