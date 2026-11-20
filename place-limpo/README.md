# Place limpo para Ideias

O Roblox confirmou que o Place inicial `122033314086516` pertence ao universo `10774214423`. O arquivo `Baseplate.rbxl` contém somente uma base de 512 × 512 studs e um ponto de nascer. Foi aberto e verificado com Lune antes de ser incluído no instalador.

Execute `python LIMPAR_PLACE_ROBLOX.py info` para ver o destino. Execute `python LIMPAR_PLACE_ROBLOX.py limpar` para preparar e confirmar a substituição. Use sua chave Open Cloud com acesso a este universo para ler o histórico, baixar o Place e publicar. Digite a chave apenas no prompt oculto do Termux.

O instalador guarda as versões salva e publicada mais recentes em `~/roblox-place-122033314086516/` antes da confirmação `LIMPAR 122033314086516`. Ele publica o Baseplate no Place indicado, baixa a versão publicada para conferir os bytes e grava um recibo. O backup pode ser aberto no Studio e o histórico da experiência permite voltar a uma versão anterior.

Se aparecer a mensagem de envio pendente, rode `python LIMPAR_PLACE_ROBLOX.py verificar`. A verificação consulta o Roblox e preserva o recibo até confirmar o resultado.

A substituição abrange o conteúdo do Place inicial. DataStores, outros Places e configuração do universo ficam fora da operação. O teste local simulou publicação, cancelamento, mudança concorrente e resposta perdida. A publicação real ocorre no Termux.
