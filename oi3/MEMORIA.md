# OI3: memória do projeto (pausado em 03/11/2026)

O casal pediu para pausar o OI3 e começar outro jogo. Este arquivo guarda onde paramos, para retomar sem perder nada.

## IDs e segurança

- Universe 10774214680, Place 128842336879717, dono (UserId) 1357078972.
- A chave da Open Cloud nunca é pedida no chat. O instalador pede escondida (getpass) e nunca mostra.
- Nunca resetar o Place nem o DataStore. Os dados dos jogadores ficam em `OI3_Jogadores_v1`, e a escolha do monstro em `OI3_Configuracao_v1` (chave `monstro_v2`).
- Se o teste isolado na nuvem falhar, nada é publicado.
- Imagens, músicas e modelos são opcionais e nunca travam a instalação.

## Última versão entregue

O AJUSTE-11 foi entregue (commit 722a7dc, instalador `oi3/dist/OI3_AJUSTE11.py`). Ele colocou o Wendigo como monstro principal e consertou as vozes que faltavam.

## AJUSTE-12: o que o casal pediu e ainda falta fazer

1. O Keko aparece com 2 rostos quando o jogador vira o personagem (fora da cutscene). A causa provável é `vestirJogador` em `Atores.luau` (ApplyDescription + ajustarRosto + fixarRostos).
2. Tirar a troca de rosto dos personagens: cada um fica com o próprio rosto padrão. Isso mexe em `Config.ROSTOS_REACAO`, `REACOES` e `Personagens.expressao/encaixarRosto/fixarRostos`.
3. Voz do menino (ME) "como tava antes": voltar para a voz original Açougueirão (PSkrmGGNwoOIKXqzUWs9, falas +1,5 semitom) no lugar da Mishi.
4. O botão JOGAR deve ser solo, e só o botão MULTIPLAYER junta jogadores. Hoje quem aperta JOGAR cai no mesmo mapa.
5. Tela de carregamento no lugar da tela preta do começo, enquanto os scripts carregam. Manter o loader do ReplicatedFirst até o menu estar pronto, e uma cortina nas transições.
6. Wendigo em tudo, inclusive no esconde-esconde: `Config.MONSTRO_ESCONDE` passa a ser o principal.
7. Revisar erros dos minigames e deixar todos bem mais assustadores. Sem exagerar na quantidade: o jogador tem que sentir medo e se sentir perseguido.
8. Ícones melhores nos botões (Canva ou desenho próprio).
9. Cutscene final muito mais assustadora.
10. Conferir os créditos do ElevenLabs e gravar as falas que faltam: VO_3..VO_9, NI_4, NI_5 e ME_7. A VO_3 já está em `assets/vozes_elevenlabs/VO_3_novo.mp3`.
    - Juntar tudo num único envio de áudio, porque o limite é de 10 áudios por mês sem verificação de identidade e restam uns 2 em novembro.

## Vozes (ElevenLabs)

| Personagem | Voz | ID |
|---|---|---|
| Menino (ME), original | Açougueirão (+1,5 semitom) | PSkrmGGNwoOIKXqzUWs9 |
| Menino (ME), AJUSTE-9 | Mishi | Pbk8E6dlpCANrnpOLIns |
| Keko (KE), original | Raí Ferrero | roWp29hIeiudYmlhBt9L |
| Keko (KE), desde o AJUSTE-8 | Piku | EeQEodFZVtBkjtgK3HBc |
| Nina (NI) | Lari Diniz | Yu6uoFniEUcJhbrF7K1D |
| Vô (VO) | Papai Noel _GO | mBxe7tYxRAMLpIP3fPEp |
| Mulher (MU) | Sofia | n2a9VtkZLl8j1FSXHsL7 |
| Criança (CR) | Gudiya | e3FEEanj39p8QCSMe8iV |
| Monstro | Azrak – Menacing Monster | GSg9QvjLdHGJoVVCDWGu |

O plano grátis às vezes responde "Free generations are busy". Quando isso acontece, parar de gerar naquele turno e gerar uma fala por vez.

## Pendências gerais

- 13 commits locais não foram enviados ao GitHub: o push dá 403. O dono precisa reconectar o GitHub em https://claude.ai/connect-github ou instalar o app do Claude no repositório.
- Como gerar um AJUSTE: veja o `README.md` desta pasta (testes com `lune run oi3/tools/teste_geral.luau`, depois `python3 oi3/tools/gerar_instalador.py AJUSTE-N`).
