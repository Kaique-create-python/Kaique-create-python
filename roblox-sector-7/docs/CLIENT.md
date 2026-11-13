# Cliente — SETOR 7

`src/client/Sector7Client.client.luau` vira o LocalScript `StarterPlayer.StarterPlayerScripts.Sector7Client`. Requer `ReplicatedStorage.Sector7.Config` e os RemoteEvents `Sector7.Remotes.Sprint`, `Flashlight` e `Feedback` descritos em `PROJECT.md`.

## Controles

| Ação | PC | Controle | Celular |
| --- | --- | --- | --- |
| Correr | Segurar Shift esquerdo | L3 alterna | CORRER alterna |
| Lanterna | F | Y | LUZ |
| Interagir | E, pelo ProximityPrompt | X, pelo ProximityPrompt | Prompt do Roblox |
| Opções / liberar cursor | M | botão View/Select, ou MENU com navegação da interface | MENU |
| Fechar nota / opções | Botão na tela, M ou Esc | B / botão na tela | Botão na tela |

MENU fica no topo direito. O cursor é liberado quando opções, documentos ou o menu Roblox abrem; a primeira pessoa volta ao fechar. O cliente não reaplica `MouseBehavior` a cada frame. O menu Roblox e a perda de foco cancelam a corrida. Corrida por toque/controle precisa ser ativada de novo depois de esgotar; Shift continua sendo uma solicitação enquanto estiver segurado, respeitando o bloqueio de exaustão do servidor.

Os botões de toque permanecem disponíveis sempre que `UserInputService.TouchEnabled` estiver ativo, inclusive em dispositivos híbridos e no simulador de celular do Studio com teclado conectado.

## Interface e acessibilidade

Dois ScreenGuis separam funções: `Sector7Effects` usa `ScreenInsets.None` e `ClipToDeviceSafeArea=false` para a sombra ambiente preencher as bordas da tela; `Sector7HUD` usa `DeviceSafeInsets` e recorta à área segura para preservar botões e textos perto de câmeras e recortes. São tamanhos proporcionais com limites, sem resolução fixa de PC. Objetivo no alto esquerdo, MENU no alto direito e fôlego centralizado no rodapé. As ações de toque ficam à direita, acima do salto padrão, sem capturar áreas do direcional ou substituir controles do Roblox. Na horizontal compacta, o texto auxiliar desaparece e as posições se ajustam. Documentos e opções rolam quando necessário.

Opções locais, mantidas durante respawns desta sessão:

- `Player.ReducedMotion`: desliga balanço, inclinação lateral, alteração de FOV, desfoque e tonalidade de ameaça. Nenhum efeito usa flashes.
- `Player.CameraBlurEnabled`: permite desativar o desfoque de câmera separadamente. O máximo é limitado a 4; não há desfoque ao ficar parado sem girar a câmera.

O indicador combina cor, número percentual e texto de recuperação. Nenhuma informação depende só da cor. A redução de movimento também suprime o desfoque mesmo que a opção de desfoque esteja ligada. As preferências são apenas locais, sem armazenamento permanente.

## Autoridade e câmera

O cliente envia somente booleanos e somente quando a intenção de corrida muda; nunca envia uma requisição por frame. `Player.Stamina`, `Sprinting`, `Exhausted`, `FlashlightOn` e `Escaped` vêm do servidor. A barra interpola o valor replicado sem alterar o fôlego real. O cliente nunca escreve velocidade, dano, fusíveis ou progresso.

A câmera usa dois passos de renderização: antes da câmera Roblox remove somente a transformação que ainda é sua; depois adiciona um deslocamento pequeno ao novo CFrame base. Isso evita acumular balanço ou inserir o efeito no cálculo seguinte da câmera. Câmeras `Scriptable` e sujeitos externos não recebem os efeitos. Morte, leitura e menus suprimem movimento. A vinculação do personagem limpa conexões antigas e as duas interfaces persistem sem duplicar no respawn.

R6 mantém o script `Animate` original. IDs opcionais passam por `Animator:LoadAnimation` sem tocar e precisam carregar uma duração válida antes de serem usados; falhas preservam o padrão. `Config.Animations.Walk` e `Idle` substituem somente os respectivos slots do `Animate`. Como o `Animate` R6 padrão não seleciona seu slot `run`, `Run` usa uma única faixa local de prioridade Movement durante corrida autoritativa no chão; a faixa para ao andar, pular, morrer ou renascer, sem tocar sobre as outras ações. Valores vazios preservam as animações padrão. O rig R6 e a velocidade continuam sendo responsabilidade do servidor/projeto.

## Feedback

`Feedback:FireClient(player, {kind, title, text})` aceita:

- `note`: documento rolável, com fechamento por toque/tecla.
- `notice`: mensagem temporária, sem prender o cursor.
- `scare`: mensagem e tonalidade muito discreta; sem movimento extra ou flashes.
- `escape`: resumo rolável com CONTINUAR. Não tenta matar/resetar o personagem no cliente.

## Verificação em Studio

1. PC: segurar/soltar Shift, esgotar, soltar durante menu/chat/perda de foco; verificar recuperação, F, E e M.
2. Abrir uma nota em primeira pessoa; clicar FECHAR, usar Esc e abrir o menu Roblox; confirmar cursor e corrida corretos.
3. Emular telefones em retrato e paisagem, inclusive recorte de tela; observar bordas, fôlego, texto, rolagem e área segura. Testar salto e direcional junto dos botões LUZ/CORRER.
4. Controle: L3, Y, X e View/Select; navegar pelas opções e fechar com B.
5. Alternar movimento reduzido e desfoque; girar lentamente e rapidamente. Confirmar limite discreto e ausência de oscilação após parar/morrer.
6. Morrer e renascer várias vezes; conferir uma única HUD, câmera sem deriva e animação R6. Verificar também com IDs de animação vazios.
7. Acompanhar tráfego de rede: segurar Shift por alguns segundos deve gerar somente a transição de início; soltar gera a de término.

Os testes visuais/dispositivos e de servidor exigem Play no Roblox Studio; uma revisão estática não os substitui.
