# CyberOutlaw · contexto para continuar o projeto

Claude, você está assumindo **CyberOutlaw**, meu projeto Roblox de mundo aberto cyberpunk. A ideia futura mistura cidade aberta, veículos e sistemas de crime. Já defini a história e os sistemas. Quando a próxima etapa precisar desses detalhes, peça meu material. Meu acesso é pelo celular, com **Termux e Roblox Open Cloud**.

## Identificação do projeto

| Dado | Valor |
| --- | --- |
| Nome do projeto | **CyberOutlaw** |
| Nome público na última consulta | **Ideias** |
| ID do universo | `10774214423` |
| ID do mapa e Place inicial | `122033314086516` |
| ID do criador Roblox | `1357078972` |
| Repositório | `Kaique-create-python/Kaique-create-python` |
| Branch | `codex/cyberoutlaw-menu-3d` |
| Pasta de trabalho | `cyberoutlaw/` |

O repositório também contém trabalhos de outros jogos. Use os IDs acima durante toda a instalação do CyberOutlaw. [Abrir o Place](https://www.roblox.com/games/122033314086516) · [Abrir o código na branch](https://github.com/Kaique-create-python/Kaique-create-python/tree/codex/cyberoutlaw-menu-3d/cyberoutlaw)

## O que já está pronto no código

- **Menu.** A câmera passeia por um terraço de Maré Baixa, uma cidade em 3D com prédios de várias alturas, fachadas detalhadas, monotrilho, concreto e asfalto PBR, poças e neon rosa e ciano. O fundo do menu precisa ser geometria 3D em movimento. Use o letreiro original aprovado em `media/art/title.png`. O cenário do menu é local e é desmontado ao tocar em **Jogar**.
- **Mapa jogável.** A entrega de Maré Baixa tem 80 quadras, estação com trilhos elevados, docas, mercado, torre de 575 studs e os materiais originais. O Place autônomo pode ser aberto para explorar. A integração da cidade com a experiência atual está descrita no guia, junto com o fluxo de mídia. [Guia de Maré Baixa](mare-baixa/README.md)
- **Abertura.** Dura seis segundos e fica muda. O pacote permite vincular o Video ID do clipe aprovado. Na ausência do ID, a abertura usa a cidade 3D e a barra de progresso.
- **Capri.** Assistente do menu, maior que nas versões iniciais. Pode ser arrastada, fica no canto, reage às interações e usa 20 clipes, incluindo teleportes e poses. Preserve os cliques do menu, as reações com áudio, as falas e os créditos. A licença da Capri é a PolyForm Noncommercial 1.0.0. [Créditos e origem da Capri](https://github.com/Kaique-create-python/Kaique-create-python/blob/codex/cyberoutlaw-menu-3d/cyberoutlaw/media/capri/PROVENANCE.md)
- **Som.** O pedido mais recente removeu o áudio de chuva. A chuva visual faz parte da cidade. A versão atual reaproveita as mídias aprovadas e tem 23 arquivos no manifesto, incluindo os atlas da Capri e sete sons.
- **HUD.** Entra depois de **Jogar**. A barra rosa mostra o rosto do avatar e a vida atual/máxima do `Humanoid`. Atualiza com dano, cura e renascimento. Fica abaixo da barra do Roblox no celular e no canto inferior esquerdo no PC.
- **Mira.** Círculo pequeno de 14 px com ponto de 2 px. A camada da mira usa `ScreenInsets.None` e âncora e posição `0.5, 0.5`, para que a barra do Roblox e os recortes de tela não desloquem o centro.
- **R6 obrigatório.** O instalador grava R6 nas propriedades nativas de avatar do Place. A alteração passou em arquivos `.rbxl` e `.rbxlx` de teste. Na consulta pública de 23 de novembro de 2026, o universo ainda respondeu `MorphToR15`. Veja qual versão está publicada e valide `Humanoid.RigType` em um servidor novo antes de dar o R6 como confirmado em jogo. [Metadados públicos do universo](https://games.roblox.com/v1/games?universeIds=10774214423)

## Arquivos atuais

- O `.py` inicia a última versão verificada. Ele reaproveita o pacote local se estiver íntegro ou baixa a versão fixa do GitHub com verificação SHA-256. [Baixar CYBEROUTLAW_HUD.py](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/codex/cyberoutlaw-menu-3d/cyberoutlaw/dist/CYBEROUTLAW_HUD.py)
- O `.pyz` é o pacote completo da versão `141e572`. [Baixar CYBEROUTLAW_TERMUX.pyz](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/141e5721f29fc280fd127e79c91391db7f4ccabd/cyberoutlaw/dist/CYBEROUTLAW_TERMUX.pyz)
- O design tem duas pranchetas editáveis para importar no Figma. O limite do plano Starter impediu gravar na versão online. A imagem da cidade nas pranchetas serve de referência para o HUD. [Figma editável](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/141e5721f29fc280fd127e79c91391db7f4ccabd/cyberoutlaw/dist/CyberOutlaw-HUD.fig) · [Prévia no celular](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/141e5721f29fc280fd127e79c91391db7f4ccabd/cyberoutlaw/dist/CyberOutlaw-HUD-Celular.png)

Leia `src/menu.client.luau` para o fluxo do menu, `src/city.luau` e `src/scene.luau` para a cidade e a câmera, e `src/hud.luau` para vida e mira. O código de montagem, migração e backup está em `install/cyber_installer.py` e `install/patcher.py`. A entrada do Termux é `launcher.py`. [Código do projeto](https://github.com/Kaique-create-python/Kaique-create-python/tree/codex/cyberoutlaw-menu-3d/cyberoutlaw)

## Fluxo no Termux

```bash
curl -fL --retry 3 -o "$HOME/CYBEROUTLAW_HUD.py" \
  'https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/codex/cyberoutlaw-menu-3d/cyberoutlaw/dist/CYBEROUTLAW_HUD.py' &&
python -u "$HOME/CYBEROUTLAW_HUD.py" verificar
```

O comando `verificar` confere o pacote sem publicar. Para aplicar no Roblox, rode `python -u "$HOME/CYBEROUTLAW_HUD.py" instalar` e confirme no Termux com `PUBLICAR CYBEROUTLAW`. A chave da Open Cloud é pedida com entrada oculta e fica no aparelho.

O instalador guarda backups em `~/.cyberoutlaw-installer`. Ele reaproveita recibos de mídia em `~/.cyberoutlaw-menu/recibos-midia` e lê IDs das versões anteriores conhecidas durante a migração. Use `midia` se faltarem aprovações. Quando o retorno da publicação ficar inconclusivo, use `resume` para conferir antes de tentar publicar de novo. [Manual do instalador](https://github.com/Kaique-create-python/Kaique-create-python/blob/codex/cyberoutlaw-menu-3d/cyberoutlaw/README.md)

## Como retomar

1. Confira o que a versão atual mostra no celular. Abra a entrada, veja se a câmera apresenta a cidade 3D e se o letreiro original carregou. O caso anterior de céu vazio e título provisório motivou a correção `0597ef5`, incluída no pacote atual. O erro Android de `os.link` no backup foi corrigido em `440a682`.
2. Toque em **Jogar** e valide o avatar R6 em um servidor novo. Confira o rosto, a vida ao receber dano e renascer, a posição da mira com as margens do celular e o fim do áudio do menu. A última entrega passou por 27 testes Python e pelos testes Luau de menu, HUD e cidade. A confirmação em partida continua pendente.
3. Depois dessa conferência, continue por uma etapa de gameplay por vez conforme eu pedir. Preserve a direção de arte, o fluxo de **Jogar**, a Capri e os créditos. Trabalhe sobre o place existente e mantenha o fluxo para atualizar com backup pelo Termux.
