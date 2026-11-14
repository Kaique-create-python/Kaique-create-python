**Horizon Turbo 0.7.8-turbo.1**: Horizon Android 0.7.8 (Minecraft: Java Edition 26.3 reescrito em Rust) com melhorias, em duas versões.

| Arquivo | Para |
| --- | --- |
| `HorizonTurbo-0.7.8-turbo.1-android-arm64.apk` | Celulares Android 9+ de 64 bits (arm64-v8a) com Vulkan |
| `HorizonTurbo-0.7.8-turbo.1-windows-x64.zip` | Windows 10/11 64 bits (extraia e abra `Horizon Turbo.bat`) |
| `HorizonTurbo-0.7.8-turbo.1-linux-x64.tar.gz` | Linux x86-64 (extraia e rode `./horizon-turbo.sh`) |

O que mudou em relação ao Horizon Android 0.7.8:

- **Multiplayer de longe**: o código de convite do "Play with Friends" agora inclui um túnel público (bore.pub). Funciona em dados móveis e atrás de qualquer roteador/CGNAT, sem configurar nada, e continua criptografado ponta a ponta.
- **Desempenho**: o Android passa a usar o alocador de memória mimalloc (o mesmo do Horizon de PC) em vez do alocador do sistema, que serializava a geração de chunks, a montagem das malhas e a iluminação entre as threads.
- **Versão para PC** sem Java e sem launcher: na primeira vez o jogo baixa os arquivos do Minecraft 26.3 direto da Mojang.
- **App separado** ("Horizon Turbo", `io.github.kaique.horizonturbo`): instala ao lado do Horizon Android oficial sem conflito.

Nada do jogo foi removido. Você precisa ter o Minecraft: Java Edition; o Horizon não inclui nenhum arquivo da Mojang (o APK traz só as tabelas geradas do motor, como o APK oficial). Versão não oficial, sem relação com a Mojang ou a Microsoft. Detalhes, código-fonte e instruções: `horizon-turbo/README.md` na branch deste release.
