# Animações R6 — pesquisa e integração

Pesquisa em 13/11/2026 pelo Creator Store conectado ao Studio. Foram usados os filtros `scope=creator_store`, `assetType=Model`, `priceFilter=free` e as buscas `R6 walk animation`, `R6 run animation`, `R6 horror animation`. A sessão consultada estava sem publicação (`isPublished=false`). Na integração posterior, somente o modelo gratuito `16823872202` foi inserido para inspeção em `ServerStorage` e teste dos clipes. Ele foi removido após a falha de permissão. Não houve compra nem publicação de animação; nenhum script de terceiros acompanha a entrega.

## Base entregue sem dependência de catálogo

`Config.Animations = { Walk = "", Run = "", Idle = "" }` permanece vazio na entrega. O fallback padrão R6 foi verificado no Studio, com tracks de repouso e caminhada em execução. R6 também foi confirmado no primeiro spawn e no respawn. O registro final dos testes e de seus limites está em [VALIDATION.md](VALIDATION.md).

O Roblox fornece animações comuns para personagens padrão. A [documentação de uso de animações](https://create.roblox.com/docs/animation/using) descreve o script `Animate` e como substituir seus clipes. Conferir se ele existe no personagem escolhido; um rig criado por código exige essa verificação. Evitar duas rotinas controlando os mesmos ombros/quadris ao mesmo tempo.

## Candidatos gratuitos encontrados

**Todos os IDs abaixo são de `Model`, não de `Animation`. Não colar estes números em `Animation.AnimationId` ou `Config.Animations`.** Os nomes, descrições e autores são os metadados retornados pela loja, não uma certificação do conteúdo. Todos retornaram `isFree=true`, `priceCents=0` na data da busca.

| Uso a explorar | Modelo / link e ID | Criador informado | Evidência disponível |
| --- | --- | --- | --- |
| Caminhada | [Best Walk Animation R6 — 127964771902906](https://create.roblox.com/store/asset/127964771902906) | wifonn3 | Nome e descrição dizem R6; conteúdo não inspecionado. |
| Caminhada e repouso | [Best R6 Walk And Idle Animations — 100759077475697](https://create.roblox.com/store/asset/100759077475697) | 14cinar21 | Descrição informa Blender/Moon Animator; conteúdo não inspecionado. |
| Conjunto de movimento | [(R6) Movement Animations: Run, Walk, Etc. — 12177921457](https://create.roblox.com/store/asset/12177921457) | SoleneLament | Descrição atribui animações a Gusthavuo777 e menciona novas corridas/caminhadas; autoria e direitos ainda precisam ser conferidos. |
| Caminhada e corrida | [R6 Walk and Run Animation — 16823872202](https://create.roblox.com/store/asset/16823872202) | DeniDeveloper | Inspecionado em `ServerStorage`. Clipes Walk `16817753747` e Run `16817762547` testados: sem acesso; modelo removido. |
| Corrida | [Best Run Animations R6 — 136548520660837](https://create.roblox.com/store/asset/136548520660837) | wifonn3 | Nome e descrição dizem R6; conteúdo não inspecionado. |
| Conjunto amplo | [R6 Idle, Walk, Run, Jump, Fall, Crouch animation — 121504470265621](https://create.roblox.com/store/asset/121504470265621) | Group Fruit Hunter | Estados anunciados no nome e na descrição; conteúdo não inspecionado. |
| Terror | [R6 Anims Horror Animation Pack Rig Character Walk — 121685678461838](https://create.roblox.com/store/asset/121685678461838) | Echocog6809 | Descrição declara rig R6, 11 animações e ausência de scripts; declaração da loja ainda não verificada dentro do modelo. |
| Terror / susto | [R6 Horror Animation Pack Jumpscare RP — 134179461447668](https://create.roblox.com/store/asset/134179461447668) | le0_y2015 | Descrição declara criação em Studio; conteúdo não inspecionado. |

Somente `16823872202` teve conteúdo inspecionado e clipes testados nesta integração. Os outros sete modelos tiveram apenas metadados consultados; não foram aprovados como compatíveis, autorizados ou funcionais. Uma futura comparação visual pode explorar o conjunto `12177921457` e o rig de terror `121685678461838`, mantendo o fallback até obter um resultado autorizado e testado.

## Resultado do teste de integração

O modelo `16823872202` continha referências de caminhada `16817753747` e corrida `16817762547`. Ao tentar carregá-las com `Animator:LoadAnimation`, `AnimationTrack.Length` permaneceu em `0`; o Output informou recusa de permissão de acesso aos assets. Esses IDs não foram colocados na configuração final. O modelo de inspeção foi removido, e a entrega conserva os clipes padrão R6. Esse resultado se aplica apenas aos dois clipes testados, sem concluir nada sobre a execução ou a autorização dos demais candidatos.

## O que pode ser usado e o que falta

| Material | Situação |
| --- | --- |
| Fallback padrão R6 | Entregue e verificado em Studio, sem compra nem dependência dos modelos da tabela. Ver [VALIDATION.md](VALIDATION.md). |
| Modelos gratuitos da tabela | Candidatos da loja. Download gratuito não comprova rig, autorização de cada clipe ou permissão de execução no universo. |
| `Animation` já publicada dentro de um modelo | Extrair o verdadeiro `AnimationId`, conferir acesso do universo e testar em R6. Não usar ID do contêiner. |
| `KeyframeSequence` / `CurveAnimation` local autorizada | Pode exigir publicação como animação para obter um ID utilizável em runtime. Não publicar trabalho de terceiros sem autorização correspondente. |
| Pacotes Marketplace como Ninja, Zombie etc. | A documentação geral os lista, mas esta pesquisa não confirmou adaptação a R6 nem os escolheu. Não comprar para esta entrega. |

A [documentação do Animation Editor](https://create.roblox.com/docs/animation/editor) distingue salvar a sequência local de publicar uma animação. Para publicação em experiência de grupo, ela orienta selecionar o grupo no campo `Creator`. A [documentação de permissões](https://create.roblox.com/docs/projects/assets/privacy) também inclui animações no fluxo de conceder acesso a colaboradores e experiências; portanto, ter um ID não basta para presumir acesso. O proprietário correto pode publicar um clipe autorizado ou conceder acesso ao universo conforme as opções disponíveis. Não foi verificada licença individual nem cadeia de autoria dos candidatos.

Fluxo de seleção:

1. Inspecionar o modelo numa cópia de trabalho e verificar objetos, scripts, rig e dados de animação antes da integração.
2. Confirmar autorização para uso, edição e eventual publicação dos clipes. Registrar autor, fonte e eventual texto de licença.
3. Abrir no Animation Editor com rig R6. Comparar caminhada cautelosa, corrida sob tensão e repouso contido, com transição e loop sem salto.
4. Obter o `AnimationId` real, com permissão para o universo do jogo. Preencher apenas os campos correspondentes de `Config.Animations`.
5. Testar andar/correr/parar, esgotamento de estamina, morte/respawn e visibilidade para outro cliente numa experiência publicada de teste. Confirmar ausência de erros de carregamento no Output e manter fallback se houver falha.

## R6 obrigatório

A [API oficial de Players](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync) confirma `Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)` como fábrica de um modelo R6. A [orientação oficial de personagem personalizado](https://create.roblox.com/docs/onboarding/developers#use-a-custom-character) descreve `StarterPlayer.StarterCharacter` para substituir o personagem mantendo o spawn padrão. Criar o modelo não prova que o spawn, a câmera e o `Animate` foram integrados: verificar `Humanoid.RigType == Enum.HumanoidRigType.R6` no primeiro spawn e em cada respawn.

Alternativamente, a janela [Avatar Settings](https://create.roblox.com/docs/studio/avatar-settings) permite escolher R6 no menu superior e `Standard R6` em Animation Packs. A pesquisa não encontrou uma propriedade pública `StarterPlayer.CharacterRigType`; não depender dessa atribuição por suposição.
