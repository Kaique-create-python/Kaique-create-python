# VEILBREAKERS v1.9.0

Varyn agora usa cenários e objetos em PNG gerados, NPCs com sprites e retratos de diálogo em pixel art anime. As seis áreas e a história de Cinzas do Oitavo continuam conectadas. O inventário abre pela **MOCHILA**, abaixo do HUD, ou pela aba **INVENTÁRIO** na tela de status.

## Inventário

- Espada de Varyn: equipar/desequipar concede ou remove +4 ATK; ataque de espada exige equipamento.
- Ataduras: o baú guarda três unidades, cada uma recupera até 45 HP.
- Tônico de Mana: o baú guarda duas unidades, cada uma recupera até 25 Mana.
- Relato de Ivo: item de missão adquirido ao completar a conversa; não é consumido.

Consumíveis não são gastos quando o recurso já está cheio. Descobertas, quantidades e equipamento persistem no Continue. Saves v1.8 migram as descobertas uma vez; voltar ao menu ou repetir uma conversa não renova provisões já gastas.

## Arte e Arcana

São seis cenários, seis poses de sobreviventes, três retratos, quatro elementos de interface, quatro ícones de itens e cinco objetos de cenário. As fontes originais, prompts e recortes ficam em `project_archive/source_sheets/v19`. A interface aplica nove recortes às molduras para preservar os cantos em telas largas e usa texto nativo legível.

Arcana usa seis poses por direção: preparação, recolhimento, carga, lançamento, continuação e repouso. O disparo ocorre em .34 s, a recuperação termina em .72 s. Uma esfera se forma junto à luva; os sprites do corpo não possuem outra esfera embutida. Lançamento, voo, cauda e impacto obedecem à direção e ao dano real. Mana, cooldown, combos e regras de pausa continuam funcionando.

## Build e recuperação

Package `com.veilbreakers.prototype`, versionCode 23, versionName 1.9.0. Branch `veilbreakers-apk-build`.

O Termux executou JDK 21 e compilação Java contra Android 35. O AAPT2 ARM disponível falhou ao ler a tabela de recursos do SDK 35; o APK usa a build GitHub Actions, que já funciona com esse SDK. Os arquivos anteriores continuam preservados no repositório. O overlay `v19_assets` entra depois de v17 e v18, e o contexto atualizado entra por último.

O manifesto atual registra 188 quadros de personagem/combate e 28 PNGs de cenário/interface. Hashes verificam os arquivos realmente presentes no APK. Verificações de lógica e compilação não substituem as capturas do Android: confira a conclusão do workflow e `qa/v19`.

## Escopo

Este é o capítulo de Varyn, não a campanha inteira. O restante da história, outras escolas de magia, novos equipamentos e áudio ainda são próximos incrementos. A instalação no celular depende da assinatura ser compatível com o save existente; não desinstalar para contornar.
