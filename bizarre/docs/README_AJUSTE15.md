# BIZARRE AJUSTE-15

Silver Chariot e Magician's Red recebem combate responsivo, animações e efeitos próprios.
Base: AJUSTE-14 publicada e verificada na versão36. A15 preparada localmente; ainda precisa
ser testada no Roblox e conferida no celular. Não houve publicação pela IA.

## O que mudou

- Silver Chariot: esgrima/estocadas, defesa, Armor Off e introdução curta da ULT. Cortes
  de partículas e meshes dos modelos enviados, com fade, pausa e limpeza.
- Magician's Red: formação/voo/impacto do Crossfire, fogo na vítima capturada, lança-chamas,
  coluna e formação/queda da ULT. Silhuetas existentes preservadas.
- Buffer120ms, cancelamento válido após M1 confirmado e seguimento aéreo único também nesses
  dois Stands. Habilidades, dano, alcance, recargas e durações em Golpes.lua não mudaram.
- 14 templates adicionais,24 ParticleEmitters e10 meshes visíveis, sem código externo.
  Catálogo14 permanece idêntico; extras ficam em BB_VFXCatalogo15.
- Pausa/retomada dos projéteis acompanha posição e tempo confirmados pelo servidor,
  inclusive com duas sessões de tempo parado e reflexão.
- ADM → PRÉVIA VFX: escolha um dos quatro Stands e use reproduzir/parar. Prévia local,
  sem dano, comandos de combate, sons de ataque ou mudança de câmera.

Morioh, câmera manual/Shift Lock, andar/correr do dono, R6, mídias, dados e os números dos
kits são preservados. Crazy Diamond e Killer Queen mantêm os kits anteriores. Qualidade
alta sem redução automática por FPS. Os testes não medem aparência/FPS do cliente Roblox.

## Termux

Com gh já conectado:

```sh
gh api 'repos/Kaique-create-python/Kaique-create-python/contents/bizarre/dist/BIZARRE_AJUSTE15.py?ref=claude/context-capture-w0uo2t' -H 'Accept: application/vnd.github.raw+json' > ~/BIZARRE_AJUSTE15.py
python ~/BIZARRE_AJUSTE15.py testar
python ~/BIZARRE_AJUSTE15.py testar-nuvem
```

Não repetir setup/assets-upload. Chave só é digitada oculta no Termux e não é salva.
Se faltar zstd: `pkg install zstd`.

A15 baixa o Place completo atual, preserva backup e altera somente fontes14 reconhecidas,
acrescentando dois módulos e o catálogo15. Fonte desconhecida bloqueia e exporta ZIP para análise.
Não reconstrói Morioh nem troca IDs. Testar-nuvem cria Saved se necessário e roda o teste
nessa versão; a publicada permanece a mesma.

Após **TESTE APROVADO**, sem outro salvamento concorrente:

```sh
python ~/BIZARRE_AJUSTE15.py publicar
```

Confirme `PUBLICAR AJUSTE15`, aguarde **PUBLICADO E VERIFICADO** e entre em servidor novo.
Se houver resposta incerta:

```sh
python ~/BIZARRE_AJUSTE15.py resume
```

Não repetir publicação nem apagar `active-write.json`. Resume só consulta histórico/arquivo;
aceita o mesmo número de versão somente com flag publicada e hash completo iguais.
Preserve `~/.bizarre_instalador` inteira. A15 usa `state-ajuste15`, mantendo os recibos14.
Envio14 pendente bloqueia A15: resolver com o instalador14 original.

## Conferência

Teste M1/uppercut/seguimento, erro, parede, defesa/parry, reflexão da rapieira, Red Bind,
queimadura, Armor Off por8s e as duas ULTs. Confira morte, troca de Stand e pausa/retomada
em dois tempos parados. Compare também SP/TW e os dois kits legados.

Local: geral34, novos testes de catálogo/renderer/poses/prévia/projétil e Python, além das
regressões da V14. Patch sobre o Place14 completo reconstruído offline foi idempotente;
objetos, hierarquia, propriedades e catálogo14 originais preservados. Esse fixture não é
um backup ao vivo. Preflight real exige sources/catálogos e testa seis kits; execução
nativa, física, carregamento das texturas e avaliação visual ficam para o Termux/celular.

Fontes: src/; curadoria reproduzível: tools/normalizar_vfx15.py + ZIP original; baseline14:
installer14/baseline14.json; build: `python3 bizarre/tools/gerar_ajuste15.py` da raiz.
Módulos/transportes internos conservam nomes14 para compatibilidade; pacote/estado/confirmacão são15.
