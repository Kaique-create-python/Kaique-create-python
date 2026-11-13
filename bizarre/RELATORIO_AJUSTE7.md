# BIZARRE BATTLEGROUNDS — relatório de validação do AJUSTE-7

## O que foi conferido aqui (fora do Roblox)
| Conferência | Resultado |
|---|---|
| Testes automáticos (`tools/teste_geral.luau`) | 24 de 24 passaram |
| Nomes usados sem declarar (`tools/lint.py`) | nenhum de verdade (1 alarme falso conhecido) |
| Instalador: pacote íntegro (`testar`) | ok |
| Instalador contra Roblox falso: instalação normal | publicou e conferiu |
| Versão no ar com script desconhecido | PAROU sem enviar nada (saída 3) |
| Mesmo caso com `--substituir` | publicou, com aviso |
| Teste da nuvem falhando | nada publicado |
| `testar-nuvem` e depois `publicar` | publicou só no segundo comando; segundo `publicar` recusado |

Testes novos do AJUSTE-7: toque interrompido, entrada recusada e resposta duplicada,
salvamentos ao mesmo tempo, congelamentos sobrepostos, Morioh simplificado.

## O que só o Roblox confere (roda no `install`, antes de publicar)
- Todos os golpes dos 6 Stands, bloqueio, parry, contra-ataque.
- Duas rajadas de frente se anulando (ORA x MUDA).
- Dois tempos parados ao mesmo tempo: cada um solta só os alvos dele.
- 12 lutadores com golpes, ULTs e destruição: o instalador mostra o tempo por quadro do
  SERVIDOR e a memória, antes e durante.

## O que NÃO foi conferido
- Nada foi aberto no Roblox de verdade nem num celular Android. FPS no celular: só jogando.
- Câmera, andar, interface e toque nos botões: conferidos por teste de lógica, não por olho.
- A rajada continua com a duração que já tinha (cerca de 1,5 s). Dano, recargas e durações
  dos golpes não mudaram.

## Não entrou neste ajuste
- Arte do Canva (logo e fundo do menu): precisa do envio de imagens no instalador.
- Vozes que faltam (MUDA, HORA, Crossfire, Killer Queen).
- Ajustes salvos entre uma partida e outra (hoje voltam ao padrão ao entrar).
