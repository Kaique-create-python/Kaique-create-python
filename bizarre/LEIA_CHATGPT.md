# BIZARRE BATTLEGROUNDS — guia rápido para continuar (ChatGPT ou outro assistente)

Jogo de luta estilo JoJo no Roblox (Universe 10774214555, Place 108061345551908). O dono joga e
instala tudo **só pelo celular (Android + Termux)**. Responda em português, simples e passo a passo.

## Como o projeto funciona
- Código Luau em `bizarre/src` (ReplicatedStorage/BB = módulos; Cliente = celular; ServerScriptService/BB_Servidor = servidor).
- `python3 bizarre/tools/gerar_instalador.py AJUSTE-<N>` (na raiz do repo) monta o place (Lune) e gera
  `bizarre/dist/BIZARRE_AJUSTE<N>.py`: um instalador de um arquivo só. Antes, mude `Config.REVISAO`.
- O dono roda no Termux: `cd ~/storage/downloads` → `python BIZARRE_AJUSTE<N>.py install --substituir`.
  O instalador pede a chave da Open Cloud ESCONDIDA (getpass), envia áudios/imagens opcionais, faz um
  teste isolado na nuvem e só publica se passar E se o dono disser "s".
- Testes offline: `lune run bizarre/tools/teste_geral.luau` (tem que dar "TUDO OK") e `python3 bizarre/tools/lint.py`.

## Regras que nunca mudam
- NUNCA pedir a chave da Open Cloud no chat; nunca imprimir chave/segredo.
- NUNCA resetar o Place nem o DataStore (progresso dos jogadores).
- Teste isolado falhou → nada é publicado. Não publicar sem o dono aprovar.
- Imagens, músicas, sons e modelos são opcionais: nunca travam a instalação.
- Não mexer no mapa Morioh; preservar os 6 Stands, o áudio e os dados; só celular; usar a animação do dono.
- Efeitos: só os dos pacotes da loja que o dono pegou (nada de efeito desenhado por código/IA).

## Onde está cada coisa
- VFX: `Cliente/VFX.luau` (receitas: impacto, estouroAr, guarda, parry, invocar por Stand, ult, dash, corte...)
  + `BB/VFXMedida.luau` (medida, escala, cor) + servidor `BB_Servidor/VFXLoja.luau` (carrega os pacotes).
- Câmera/mira/Shift Lock: `Cliente/Camera.luau`, `Cliente/Jogador.luau`, botões em `Cliente/Controles.luau`.
- Sons: `BB/Sons.luau` (biblioteca do Roblox + trechos dos áudios enviados), `Cliente/Som.luau`
  (`Som.voz` gritos, `Som.golpe` socos do dono). Tratamento dos socos: `tools/sons_sfx.py`.
- Instalador: `tools/instalador_modelo.py` (modelo) + `tools/gerar_instalador.py`; teste na nuvem: `tools/teste_nuvem.luau`.
- Histórico e próximos passos: `bizarre/PLANO.md` (seção AJUSTE-13 e pendências).
