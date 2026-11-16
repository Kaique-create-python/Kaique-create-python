-- PROJETO BASTIÃO :: dados compartilhados (servidor e cliente)
-- Nomes de remotes/atributos e a versão da etapa. Os textos ficam em Textos (filho deste módulo).

local Compartilhado = {}

Compartilhado.ETAPA = "ETAPA-1"
Compartilhado.PASTA_REMOTOS = "BastiaoRemotos"
Compartilhado.REMOTO_APRESENTACAO = "Apresentacao" -- servidor -> clientes: falas, legendas, cartão final
Compartilhado.PASTA_MUNDO = "BastiaoHistoria" -- tudo o que a história cria fica aqui (o mapa Sector7World não é tocado)

-- atributos no próprio módulo (replicam para todos; quem entra depois lê o estado atual)
Compartilhado.ATR_OBJETIVO = "BastiaoObjetivo"
Compartilhado.ATR_ALARME = "BastiaoAlarme"
Compartilhado.ATR_FIM = "BastiaoFimEtapa"

-- tags para o cliente achar as peças vivas
Compartilhado.TAG_GIROFLEX = "BastiaoGiroflex"
Compartilhado.TAG_PROMPT = "BastiaoPrompt"

-- duração de uma legenda pelo tamanho do texto (leitura confortável no celular)
function Compartilhado.duracaoLeitura(texto: string): number
	return math.clamp(1.4 + #texto * 0.055, 2.2, 7.5)
end

return Compartilhado
