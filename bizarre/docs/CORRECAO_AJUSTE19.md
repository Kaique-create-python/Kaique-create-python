# Correção do instalador AJUSTE-19 — 13/11/2026

Base do Claude:7a6f49f. Kaique recebeu “Destino/pacote incorreto” na AJ18 (Saved40) e AJ19 (Saved41); não houve aprovação do teste nem confirmação de publicação dessas entregas.

## Causa comprovada

Python Package/Runtime já aceitavam18/19, mas Validacao14.luau embutido no instalador só aceitava14..17. O primeiro teste estrutural era rejeitado antes do restante do teste. Reproduzido offline com o validador, configuração19,68 Sources e hashes extraídos do próprio instalador original: mesmo erro. Os testes anteriores usavam configuração16 no validador e resposta simulada de sucesso no protocolo, então não cobriam essa divergência.

## Mudança

O validador agora aceita explicitamente18/19 e conserva todas as checagens de universo, Place, pacote, revisão, hashes e catálogos. Pacotes/destinos incorretos e revisão20 não autorizada continuam bloqueados. baseline19.json registra os hashes exatos das fontes do commit original; o builder19 reconhece14..19 para atualizar também o Saved19 já preparado. Nenhuma Source foi forçada e não se apaga estado/recibo.

Só Validacao14 mudou entre as68 fontes do jogo; HUD, gráficos/VFX, animações, combate, câmera, mapa, mídia e dados são byte a byte os da AJ19 do Claude. O instalador autocontido e SHA foram regenerados; permanece AJUSTE19 e a confirmação PUBLICAR AJUSTE19. Não é uma entrega20.

## Verificação

50/50 comandos locais, incluindo85 testes Python, geral34 e todos os runners Luau, lint0 e integridade offline. Nova regressão test_installer19_native.py usa validar_pacote_nativo.luau para executar o validador extraído do instalador completo com a configuração efetiva e todas as68 Sources; aprova18/19 e bloqueia universo/Place/pacote incorreto e revisão futura. RED com o original, GREEN com o instalador corrigido. Não conecta ao Roblox.

Fixture completa AJ13→14→AJ19 original→correção:185210 instâncias preservadas,547 chunks não Source idênticos, apenas uma Source alterada, idempotente. Build repetido produz bytes idênticos. Essa fixture não é o Saved41 ao vivo. Metadados em CORRECAO_AJUSTE19.json. Nenhum teste autenticado, publicação ou medida de FPS pela IA.

## Termux

Baixar novamente para HOME evita executar a cópia antiga em Downloads:

```sh
gh api 'repos/Kaique-create-python/Kaique-create-python/contents/bizarre/dist/BIZARRE_AJUSTE19.py?ref=claude/context-capture-w0uo2t' -H 'Accept: application/vnd.github.raw+json' > ~/BIZARRE_AJUSTE19.py
python ~/BIZARRE_AJUSTE19.py testar
python ~/BIZARRE_AJUSTE19.py instalar
```

`instalar` cria Saved se necessário, testa e somente então pede PUBLICAR AJUSTE19. Nunca publica se o teste reprovar. Não repetir setup/assets-upload nem excluir ~/.bizarre_instalador. Se aparecer envio incerto/pendente, usar resume do instalador indicado; não repetir POST. Chave somente oculta no Termux.

O erro da foto é corrigido na origem. O teste autenticado ainda deve executar o restante dos casos no Roblox; qualquer novo erro precisa de análise própria, sem mascarar a falha nem liberar publicação.
