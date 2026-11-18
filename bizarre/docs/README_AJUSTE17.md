# BIZARRE AJUSTE-17

Base: Kaique confirmou a AJUSTE-16 publicada e funcionando. A AJ17 foi preparada localmente; a IA não fez teste autenticado nem publicou no Roblox.
Universe10774214555 · Place108061345551908. Android/Termux, sem Studio.

## O que mudou

- Acerto, bloqueio, parry e quebra de guarda têm identificação local discreta e paletas distintas. O feedback vem de contatos resolvidos no servidor, deduplica hitId e não mostra dano de tempo parado ainda pendente.
- Observadores entram no ponto atual da animação/voz de ORA/MUDA. Eventos vencidos são descartados. Previsão e confirmação mantêm continuidade; duração4,6s e final4,35s preservados. O áudio não é reenviado.
- Botões mobile reorganizados em área segura, com estados PRONTO/RECARGA. HUD de habilidades duplicado é ocultado no toque. AJUSTES → EDITAR BOTÕES permite arrastar, aumentar/diminuir, salvar, cancelar e restaurar padrão. Não permite sobreposição/pulo/joystick nos layouts verificados; orientação incompatível usa padrão local sem apagar a preferência.
- Volume de efeitos, qualidade, tremor, distância/mira e layout persistem em BB_Preferencias_v1. Nenhuma estatística é migrada/resetada; BB_Jogadores_v1/Dados continuam idênticos. Falha na leitura não autoriza sobrescrever dados salvos.
- No treino, TREINO abre o laboratório. O alvo próprio pode ficar parado, defender depois de um hit, usar evasiva disponível ou contra-atacar depois de recuperar. O painel mede dano/hits e abertura entre contatos pelo estado do servidor. REPor ALVO reinicia só o alvo, com limite; não recarrega nem cura o jogador. Troca, morte, saída e criação atrasada têm limpeza. Outras pessoas não selecionam/congelam/atingem esse alvo.
- Atmosfera/bloom e núcleos contínuos dos efeitos preservam mais contraste. Materiais especiais, mapa, câmera aprovada/Shift Lock/R6, clipes de locomoção, mídias e números de Golpes/Regras preservados. Sem redução automática por FPS.

## Termux

Sem repetir setup ou assets-upload. Preserve ~/.bizarre_instalador inteira.

```sh
gh api 'repos/Kaique-create-python/Kaique-create-python/contents/bizarre/dist/BIZARRE_AJUSTE17.py?ref=claude/context-capture-w0uo2t' -H 'Accept: application/vnd.github.raw+json' > ~/BIZARRE_AJUSTE17.py
python ~/BIZARRE_AJUSTE17.py testar
python ~/BIZARRE_AJUSTE17.py testar-nuvem
```

`testar` não usa chave nem rede. `testar-nuvem` pede chave oculta no Termux, preserva o Place completo, cria Saved se necessário e testa essa versão; Published continua a mesma. Fonte desconhecida bloqueia para análise. O teste nativo17 inclui os casos16 e políticas novas, com armazenamento falso em memória para não escrever preferências de jogadores.

Somente após TESTE APROVADO e sem salvamento concorrente:

```sh
python ~/BIZARRE_AJUSTE17.py publicar
```

Digite PUBLICAR AJUSTE17; espere PUBLICADO E VERIFICADO e entre em servidor novo. Resposta incerta: `python ~/BIZARRE_AJUSTE17.py resume`. Se houver recibo anterior, use o resume do instalador indicado; nunca repetir POST ou apagar active-write.json.

## Conferir no celular

1. Segurar ataque/defesa, soltar fora do botão, abrir menu, girar tela; nenhuma entrada deve ficar presa.
2. Editar/cancelar/salvar layout, sair e entrar; volume/câmera devem voltar. Pulo e joystick continuam do Roblox.
3. Treino: quatro respostas, bloqueio/parry, dano e evasiva em recarga; reposição não altera seus cooldowns. Duas pessoas treinando não interferem nos alvos próprios.
4. ORA/MUDA local e de outro jogador, fim do áudio, final, morte/interrupção e tempo parado; seis kits, mira/Shift Lock e cidade.

Testes offline simulam serviços/relógio e usam módulos e instâncias reais de Lune; não provam renderização, áudio autorizado/seek nativo, replicação, física ou FPS do Android. O HTML preview-ajuste17.html é um esquema de controles exportados do Luau, não uma captura do Roblox. Chromium foi bloqueado pelo sandbox; não há screenshot validada dessa prévia.

Fontes em src/, build `python3 bizarre/tools/gerar_ajuste17.py`. Aceita hashes conhecidos14/15/16, acrescenta somente ModuleScripts, mantém catálogos14/15 exatos e bloqueia Sources desconhecidas. Relatórios: VALIDACAO_AJUSTE17.md, REVISAO_AJUSTE17.md, ENTREGA_AJUSTE17.json.
