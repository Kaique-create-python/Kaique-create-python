# Validação AJUSTE-14

Preparação em 11/11/2026, fechamento em 12/11/2026, sobre AJ13 remoto
`b60be0a8f49a5c0a0dc3fbd77cdbec6fa4ab1fc0`.
Somente BIZARRE: Universe 10774214555, Place 108061345551908.

## Evidência offline

- Suíte geral: 34 testes, zero falhas, `TUDO OK`; compila os módulos Luau de produção.
- Combate: política, servidor/cliente reais e regressões de sequência, buffer, ACK, morte,
  troca de Stand, paredes, projéteis e extensão aérea única.
  Fechamento: 9 cenários de geração/ACK (incluindo servidor→cliente nos quatro kits legados),
  6 de fences e 6 de sessões de projéteis. Geração e Stand chegando em ordens distintas
  não cancelam golpe novo; o fim de uma sessão não libera projéteis retidos por outra.
- Gráficos: 20 cenários de câmera/cinema/iluminação e comparação do Place AJ13 real.
  Morioh manteve 163.325 BaseParts e 184.903 objetos; 256 materiais foram ajustados
  seletivamente. Transformações, colisões, cores e texturas originais foram conferidas.
- Integração: 16 cenários, renderer/catálogo reais juntos, inicialização Main, prévia e UI ADM.
  Duas sessões congelam apenas atores com as marcas de associação do servidor.
- Validação estrutural: 8 cenários, incluindo Source alterada, catálogo/código indevido e Beam quebrado.
- Assets: reconstrução determinística do catálogo real e conferência de texturas/atributos/refs;
  zero código de terceiros executado. RBXM com 23 templates, 59 ParticleEmitters e 2 Beams.
- Python: 50 testes do patcher, transporte, filesystem, empacotamento e ferramentas.
  Incluem envio incerto sem POST repetido, proof antigo revogado, fsync antes do envio,
  redação de segredo, referências/SSTR e Source desconhecida.
- Lint sem suspeitas e `git diff --check` limpo.

Fronteiras de relógio, sinais, remotos e HTTP são controladas nos testes. Instâncias/arquivos,
políticas e módulos de produção são usados onde o Lune permite. Isso não simula um cliente
Roblox completo. As correções finais e os hashes do artefato constam no arquivo de entrega.

Comandos da raiz do repositório:

```sh
lune run bizarre/tools/teste_geral.luau
for arquivo in bizarre/tools/tests_*14*.luau; do lune run "$arquivo" || break; done
python3 bizarre/tools/lint.py
cd bizarre
python3 -m unittest discover -s tests
```

`tests_graphics14_place.luau` precisa de uma cópia completa do Place AJ13; aceite o caminho
como primeiro argumento. O fixture usado nesta preparação não é um backup do jogo ao vivo.

## Decisões registradas

- Isolamento por snapshot local e árvore remota como base: a rede do shell não permitia clone.
  O envio preserva arquivos remotos ausentes do snapshot, inclusive o Morioh original.
- Recuperação M1 de 0,30/0,45 s conta desde o início, mantendo a cadência aprovada.
- Os quatro kits legados mantêm câmera/FOV herdados. A distância real aplicada pelo menu AJ13
  é 12,5, preservada em vez de substituí-la pelo valor 11 do módulo base citado no plano.
- Catálogo sanitizado incorporado elimina LoadAsset durante ataques do piloto. A autorização
  online de cada textura continua dependente do Roblox; não há IDs novos inventados.
- Congelamento visual lê as marcas de sessão do servidor no dono ou na vítima apropriada;
  uma sessão distante não congela automaticamente todos os efeitos do mapa.
- Publicação Roblox não é parte da execução automática. Kaique testa Saved e confirma Published.

Essas decisões preservam o escopo aprovado; aparência nativa ainda precisa da conferência no celular.

## Pendente no Roblox

Kaique executar `testar-nuvem`, conferir física/combate/câmera e **ADM → PRÉVIA VFX**.
O preflight contém a verificação real de Sources/catálogo/política e os testes dos seis kits/mapa,
não uma aprovação incondicional. Aqui ele foi empacotado e compilado, sem execução autenticada.
Não houve publicação, comparação visual dentro do cliente, medição de FPS ou teste no aparelho.
