# Iluminação do Bastião

A primeira melhoria trabalha com a iluminação da base. O corredor ganha sombra mais suave, tons de aço e neblina mais perceptível ao longe. Ao entrar na enfermaria, a luz fica mais fria. A oficina ganha um tom mais quente e ar mais limpo. A luz de peito tem um ponto central menos forte e ilumina um pouco mais ao redor dele.

O perfil leve reduz o halo das lâmpadas e desliga o desfoque de profundidade da lente. Ele entra com a qualidade manual do Roblox entre 1 e 4, ou no modo automático em aparelho com toque e sem mouse. Nos níveis mais altos, o desfoque da lente fica mais sutil. O desfoque de impacto tem seu próprio efeito e continua respondendo ao dano.

[Abrir a comparação de iluminação](PREVIA_ILUMINACAO.jpg). A prévia usa a geometria do arquivo original com a mesma posição de câmera nas duas versões. Ela representa a direção visual em um render 3D de referência. O motor Roblox pode exibir luz, neblina e brilho de forma diferente.

## Aplicar pelo Termux

Use `bastiao/dist/BASTIAO_GRAFICOS.py` sobre a [Correção 10 do Codex](../../dist/CORRIGIR_ETAPA3_10_CODEX.py) que já está no pacote local da Etapa 3. `--verificar` confere a compatibilidade sem gravar. A aplicação salva os originais na subpasta `.graficos_bastiao` do pacote atualizado. O fluxo de instalação usa os mesmos recibos de áudio, modelo e animações que a Etapa 3 já tem.

Depois de aplicar, rode `python ~/storage/downloads/BASTIAO_ETAPA3.py testar-nuvem`. A etapa Saved confere que o LocalScript foi incluído e que a fonte bate com a entrega. Com o teste aprovado, use `python ~/storage/downloads/BASTIAO_ETAPA3.py publicar` no fluxo já usado no Termux.

## Para integrar com outras alterações

`src/client/BastiaoIluminacao.client.luau` entra como `StarterPlayer/StarterPlayerScripts/BastiaoIluminacao`. O cliente lê a posição do jogador até oito vezes por segundo e aplica transições em `Lighting`, na atmosfera, na lente e nas duas luzes de peito existentes. Se uma propriedade passar a ser escrita por outro controlador, o script cede aquela propriedade. Quando o jogador sai da base ou durante morte e captura, o script cede a iluminação de volta. Os botões de grão, vinheta e movimento mantêm a função que já tinham.

O patch binário sobre a base de teste da C10 preservou 9.035 instâncias e 1.756 blocos de propriedades, incluindo todas as fontes existentes. Acrescentou um LocalScript. Passaram 112 testes Python e 22 verificações Luau. O aspecto final e os FPS ainda precisam de um teste no cliente Roblox.
