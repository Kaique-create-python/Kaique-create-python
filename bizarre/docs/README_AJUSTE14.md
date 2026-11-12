# BIZARRE AJUSTE-14

Piloto de qualidade visual e combate para **Star Platinum / The World**, sobre a AJUSTE-13.
Destino fixo: Universe **10774214555**, Place **108061345551908**.

## O que mudou

- 23 templates dos pacotes reais, curados em catálogo com 59 ParticleEmitters e 2 Beams.
  Sem scripts de terceiros, galerias, rig, sons ou remotos importados.
- Identidade violeta/branco/azul para SP e ouro/âmbar para TW; invocação, socos, defesa,
  parry, rajadas, Star Finger, facas, parar o tempo e rolo usam receitas próprias desses assets.
- Buffer de 120 ms, cancelamento após acerto confirmado e uma extensão aérea do uppercut.
  O servidor verifica estado, alcance, parede, recarga, sequência e vítima vinculada.
- ORA/MUDA de 4,6 s com final em 4,35 s. Câmera ULT de até 0,9 s com limpeza ao interromper.
- Perfil alto de iluminação, sol quente/sombras frias e materiais selecionados em Morioh.
  Geometria, colisões, animações R6 e clipes de andar/correr permanecem.

Os quatro outros kits conservam seu combate/VFX. Mira manual, Shift Lock, câmera aprovada,
sons/IDs e dados persistentes são preservados. Não há upload novo de áudio/imagens.

## Baixar pelo Termux

Com o GitHub CLI já conectado à sua conta:

```sh
gh api 'repos/Kaique-create-python/Kaique-create-python/contents/bizarre/dist/BIZARRE_AJUSTE14.py?ref=claude/context-capture-w0uo2t' -H 'Accept: application/vnd.github.raw+json' > ~/BIZARRE_AJUSTE14.py
python ~/BIZARRE_AJUSTE14.py testar
python ~/BIZARRE_AJUSTE14.py testar-nuvem
```

Se faltar a biblioteca de compressão no Termux: `pkg install zstd`.
Não repetir setup/assets-upload de instaladores anteriores.

Se a entrega inicial mostrou apenas `Teste na nuvem nao aprovado`, o motivo ficou oculto
por um erro do instalador. A correção mostra os erros e guarda o relatório sem chave em
`~/.bizarre_instalador/state-ajuste14/ultimo-teste.json`.
Para a tarefa Saved 36 mostrada por Kaique, `dist/BIZARRE_DIAGNOSTICO14.py` consulta somente
o resultado já existente via GET, sem salvar, testar outra vez ou publicar. Ele pede a chave
oculta no Termux e imprime o relatório para análise. Não desativa a reprovação do teste.

`testar` é offline e não pede chave. `testar-nuvem` pede a chave oculta no terminal, baixa o
Place completo atual, preserva o backup e cria uma versão **Saved** se há alterações.
Então executa o preflight real nessa versão. A versão publicada não é trocada nessa etapa.
Fontes desconhecidas bloqueiam a atualização e geram um ZIP para análise.

Só depois de **TESTE APROVADO**, sem outro salvamento concorrente:

```sh
python ~/BIZARRE_AJUSTE14.py publicar
```

Confirme `PUBLICAR AJUSTE14`. Aguarde **PUBLICADO E VERIFICADO** e entre em servidor novo.
Se o envio ficar incerto:

```sh
python ~/BIZARRE_AJUSTE14.py resume
```

Não repita envio nem apague `active-write.json`. `status` mostra o estado local sem chave.
Backup, arquivo preparado e recibos ficam em `~/.bizarre_instalador/state-ajuste14/`;
o intent de envio fica na raiz `~/.bizarre_instalador/`. Preserve a pasta toda.

## Conferir dentro do jogo

Abra **ADM → PRÉVIA VFX** para ver os assets reais SP/TW em uma sequência local de 6,2 s.
Não causa dano, não envia comando de combate, não muda câmera nem congela outros jogadores.
Sem catálogo a interface avisa; não mostra uma concept art como se fosse o jogo.

Em uma luta, confira socos com/sem acerto, defesa/parry, parede entre jogadores, uppercut+
seguimento único, ORA/MUDA até o fim e troca de Stand. Teste parar o tempo com vítima dentro
e jogador fora da área: os efeitos seguem a associação de congelamento definida pelo servidor.
Confira também morte/respawn, menu e retorno da câmera.

## O que ainda depende do Roblox

A preparação e os testes nesta entrega são offline. O preflight autenticado, física real,
avatar/câmera no cliente e autorização/renderização das texturas precisam do teste no Termux
e da conferência no celular. Não houve medição de FPS nem publicação nesta implementação.
Confira o [relatório de validação](VALIDACAO_AJUSTE14.md) para distinguir cada evidência.
