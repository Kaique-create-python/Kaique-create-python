# Horizon Turbo

Versão modificada do **Horizon Android 0.7.8** ([Vasysik/horizon-android](https://github.com/Vasysik/horizon-android), tag `v0.7.8`), o port para Android do [Horizon](https://github.com/horizon-rust/horizon): o Minecraft: Java Edition 26.3 reescrito em Rust. Sai em duas versões: **APK para Android** e **jogo para PC** (Windows e Linux).

> Não oficial. Sem relação com a Mojang ou a Microsoft. Você precisa ter o Minecraft: Java Edition: o Horizon não inclui nenhum arquivo da Mojang e baixa os arquivos do jogo direto dos servidores dela.

## Downloads

Os arquivos ficam em **[Releases](https://github.com/Kaique-create-python/Kaique-create-python/releases)** (pré-lançamento `horizon-turbo-v0.7.8-turbo.1`), gerados pelo workflow [`horizon-turbo.yml`](../.github/workflows/horizon-turbo.yml) a partir do código-fonte oficial + o patch desta pasta.

| Arquivo | Para |
| --- | --- |
| `HorizonTurbo-…-android-arm64.apk` | Android 9+ de 64 bits (arm64-v8a), GPU com Vulkan |
| `HorizonTurbo-…-windows-x64.zip` | Windows 10/11 64 bits |
| `HorizonTurbo-…-linux-x64.tar.gz` | Linux x86-64 (Vulkan ou OpenGL 3.3) |
| `SHA256SUMS.txt` | Hashes para conferir os downloads |

### Android

1. Baixe o `.apk` pelo celular e abra. Permita "instalar apps desta fonte" se o Android pedir.
2. O app se chama **Horizon Turbo** e instala **ao lado** do Horizon Android oficial (ID `io.github.kaique.horizonturbo`), sem apagar nada do outro. Os mundos de um não aparecem no outro: copie as pastas de mundo pelo app Arquivos (Horizon → Worlds) se quiser levar algum.
3. Abra, toque em **Download Minecraft 26.3** (cerca de 500 MiB, uma vez só) e depois em **Play**.

### PC

1. Extraia o `.zip` (Windows) ou o `.tar.gz` (Linux) numa pasta sua.
2. Windows: abra `Horizon Turbo.bat`. Se aparecer "O Windows protegeu o computador", clique em "Mais informações" → "Executar assim mesmo" (o programa não tem assinatura paga). Linux: `./horizon-turbo.sh`.
3. Na primeira vez uma janela de console mostra o download dos arquivos do Minecraft 26.3 (cerca de 500 MiB). Depois o jogo abre sozinho, até sem internet.
4. Seu nome offline fica em `horizon-player.txt` (troque `name:Player12345` por `name:SeuNome` com o jogo fechado). O `LEIA-ME.txt` do pacote explica o resto.

## Multiplayer de longe

O Horizon já tinha o **Play with Friends**: você abre seu mundo para amigos e recebe um **código de convite**. O problema é que ele só funcionava de longe quando o roteador abria a porta (UPnP) ou quando alguém configurava um relay. Em **dados móveis** e na maioria das operadoras brasileiras existe **CGNAT** (vários clientes atrás do mesmo IP), e aí nenhum amigo de fora conseguia entrar: na prática, só multiplayer local.

No Horizon Turbo o código de convite também passa por um **túnel público** ([bore](https://github.com/ekzhang/bore), servidor `bore.pub`):

- O jogo de quem hospeda só faz conexões **de saída** para o `bore.pub`, então funciona atrás de qualquer NAT, CGNAT e dados móveis.
- O código ganha mais um endereço (`IP do bore.pub:porta`). Quem entra testa todos os endereços ao mesmo tempo: na mesma rede ou com a porta aberta a conexão direta continua ganhando; de longe, o túnel resolve.
- Tudo que passa pelo túnel é a mesma sessão **criptografada ponta a ponta** com a chave do código (SPAKE2 + ChaCha20-Poly1305). O servidor do túnel vê só os IPs e bytes cifrados, nunca o mundo, o chat ou os nomes.

**Como usar:**

1. Entre no seu mundo (um jogador), abra o menu de pausa e toque no botão de amigos → **Start Sharing**.
2. Espere a mensagem "Friends anywhere can join with this code…" e toque em **Copy**. Mande o código para seus amigos.
3. O amigo abre o Horizon Turbo (celular ou PC), vai em **Multiplayer → Join a friend** (ou Conexão direta) e cola o código.

Quem entra precisa estar na mesma versão (Minecraft 26.3). O código muda se você parar de compartilhar ou sair do mundo.

**Ajustes** (arquivo `horizon.txt` na pasta do jogo, ou variáveis de ambiente no PC):

| Linha | Efeito |
| --- | --- |
| `friendsTunnel:none` | desliga o túnel |
| `friendsTunnel:meuservidor.com:7835` | usa o seu próprio servidor `bore server` (um VPS ou PC com a porta 7835 aberta) em vez do `bore.pub` |
| `friendsTunnelSecret:...` | senha de um servidor iniciado com `bore server --secret ...` |

Se o `bore.pub` estiver fora do ar, o código continua funcionando pelos outros caminhos e a tela diz o motivo. Alternativa sem servidor nenhum: instalar o **Tailscale** (ou ZeroTier) nos dois aparelhos: o código já inclui o endereço da VPN.

## O que foi melhorado (e o que não)

| Mudança | Por quê |
| --- | --- |
| **mimalloc no Android** | O Horizon de PC já usa o alocador mimalloc; o próprio código do Horizon mede que o alocador do sistema chegava a 16% do tempo de geração de um chunk no Windows. O Android usava o alocador do sistema (Scudo no Android 11+), que serializa as threads de geração de mundo, malhas, iluminação e tick. Agora o Android usa o mesmo mimalloc, com a mesma configuração (páginas livres devolvidas na hora). |
| **Túnel público no Play with Friends** | Multiplayer de longe sem configurar roteador (acima). |
| **Versão de PC sem Java nem launcher** | O jogo de PC instala os arquivos sozinho, do mesmo jeito que o app Android (download oficial da Mojang com hashes conferidos), em vez de exigir o Java 25 e o `horizon-prepare`. |
| **App com nome e ID próprios** | Instala junto do Horizon Android oficial. |

Nada do Minecraft foi removido: gráficos, distância de renderização, mobs, mecânicas e opções continuam iguais. As opções de desempenho do launcher ficaram como no original: as que **mudam o visual** (Super Performance, Leaf Culling) continuam desligadas, e você pode ligá-las em Settings se quiser trocar visual por FPS. As dicas ADPF também continuam opcionais: com a tela em "padrão do sistema" elas miram 60 Hz e podem segurar celulares de 90/120 Hz.

Os ganhos de FPS dependem do aparelho e não foram medidos num celular real (não tenho um aqui): o mimalloc ajuda principalmente no trabalho de CPU (carregar e gerar terreno, andar rápido, muitos mobs). Se puder, compare usando **Settings → Performance recording** no launcher do app.

## Sobre os mods (Beyond the Skybox e Verity)

Não coloquei esses dois mods dentro do app, por dois motivos:

1. **Licença.** O *beyond_the_skybox* (nimblerod, CurseForge) e o *Verity JE* são "**All Rights Reserved**": só os autores podem redistribuir. Um APK num repositório público é redistribuição, e portar o código exige descompilar e traduzir o código deles. O Beyond the Skybox ainda traz músicas de terceiros (MARK101, FRUMS, Gibbo, Barton).
2. **Técnico.** O Horizon não roda Java: mods NeoForge/Forge funcionam como "código Java que altera classes do Minecraft". O Horizon só aproveita os dados e assets de dentro do `.jar` (texturas, sons, receitas, estruturas). O Beyond the Skybox é quase todo lógica Java (22 entidades, 35 eventos, 26 dimensões, uma história) e o Verity JE é uma IA que conversa por um serviço externo (Groq) com voz. Portar isso seria reescrever os mods inteiros em Rust.

Além disso, só o `beyond_the_skybox-1.0.3-neoforge-1.21.1.jar` está no seu Drive; o do Verity não está lá.

Caminhos que funcionam:

- **Mods nativos do Horizon** (Rust, `.hnmod`/`.hmod`): minimapa, zoom, receitas e SmartF3 já vêm dentro do app; outros estão no catálogo de mods do launcher.
- **Pedir permissão aos autores** (Discord do Beyond the Skybox / do Verity JE). Com permissão, dá para portar partes específicas como mod nativo.
- **Mods com licença aberta** (MIT, Apache, CC0…): dá para portar as partes de dados/assets e reescrever a lógica em Rust.

## Como é construído

- `patches/0001-horizon-turbo.patch`: todas as mudanças, sobre o commit `68a2c4dd1b9a9e511ad3758a79ab772b6f9e5b29` (tag `v0.7.8`).
- `scripts/fetch-source.sh`: baixa o Horizon Android nesse commit exato (confere o hash) e aplica o patch.
- `pc/`: o `.bat`, o `.sh` e o `LEIA-ME.txt` que vão no pacote de PC.
- [`.github/workflows/horizon-turbo.yml`](../.github/workflows/horizon-turbo.yml):
  1. **Testes** do túnel (unitários, ponta a ponta com um servidor bore de teste e com o `bore server` real);
  2. **Tabelas do motor**: baixa o Minecraft 26.3 oficial (hashes conferidos) e gera as tabelas, como o CI do Horizon Android;
  3. **APK** arm64 no perfil `release` (opt-level 3, ThinLTO, 1 codegen unit), com a auditoria de conteúdo do próprio projeto;
  4. **PC** Windows x64 (runtime de C embutido) e Linux x86-64, perfil `release`, com suporte a mods `.hmod`;
  5. **Release**: publica tudo como pré-lançamento com `SHA256SUMS.txt`.

Para compilar na sua máquina: `bash horizon-turbo/scripts/fetch-source.sh horizon-src` e depois os comandos de [docs/android.md](https://github.com/Vasysik/horizon-android/blob/v0.7.8/docs/android.md#build-developers-only) (APK) ou `cargo build --release -p horizon-client --features mods` (PC), copiando o `engine-data.zip` gerado para o lado do executável.

### Assinatura do APK (para atualizar sem desinstalar)

Sem configuração, cada build do APK recebe uma chave de assinatura nova, e o Android só atualiza um app por cima se a chave for a mesma. Para fixar a chave, crie uma vez (no PC, com Java instalado):

```sh
keytool -genkeypair -keystore horizon-turbo.keystore -storepass android -keypass android \
  -alias androiddebugkey -keyalg RSA -keysize 4096 -validity 36500 -dname "CN=Horizon Turbo"
base64 -w0 horizon-turbo.keystore   # Windows: certutil -encodehex -f horizon-turbo.keystore out.txt 0x40000001
```

Depois cole o texto em **Settings → Secrets and variables → Actions → New repository secret**, com o nome `HORIZON_TURBO_KEYSTORE_BASE64`, e guarde o arquivo `.keystore` num lugar seguro (sem ele nenhuma build futura atualiza o app instalado). A senha precisa ser `android` porque é a que o empacotamento do Horizon Android usa.

## Créditos e licenças

- [Horizon](https://github.com/horizon-rust/horizon): Ludovic Marie e contribuidores, licença MIT.
- [Horizon Android](https://github.com/Vasysik/horizon-android): Vasysik e contribuidores (Starling), licença MIT.
- [bore](https://github.com/ekzhang/bore): Eric Zhang, MIT (o Horizon Turbo implementa o protocolo; o servidor público é o `bore.pub` do projeto).
- O patch do Horizon Turbo segue a licença MIT do Horizon. `LICENSE.txt` e `THIRD_PARTY_NOTICES.md` vão junto de cada download.
- Minecraft é marca da Mojang Synergies AB; código e assets do Minecraft pertencem à Mojang e à Microsoft ([EULA](https://www.minecraft.net/en-us/eula)).
