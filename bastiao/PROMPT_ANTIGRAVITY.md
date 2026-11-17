# PROJETO BASTIÃO — contexto para continuar (Antigravity)

Jogo de terror no Roblox. Place 89520940302906, Universe 10776462844. O dono joga e instala só
pelo celular (Android + Termux). Responda sempre em português, simples e passo a passo.

## Regras que nunca podem ser quebradas
1. Nunca peça a chave Open Cloud no chat. O instalador pede escondido no Termux (getpass).
2. Nunca resetar o Place nem DataStores (progresso dos jogadores).
3. Não apagar/mover/editar o mapa `workspace.Sector7World`, o HUD da bodycam (`Sector7Client`)
   nem scripts `Sector7.*`. Só ACRESCENTAR coisas com nome `Bastiao*`.
4. Efeitos visuais só de pacotes da Creator Store (nada desenhado por código ou IA).
5. Publicar só depois do teste na nuvem passar e com confirmação digitada pelo dono.
6. Não pôr nome de modelo de IA em commits. E-mail do dono é privado.

## Código
GitHub: `Kaique-create-python/Kaique-create-python`, branch `claude/context-capture-w0uo2t`,
pasta `bastiao/`. Leia `bastiao/README.md`, `bastiao/LEIA_CHATGPT.md`,
`bastiao/ferramentas/etapa3/LEIA.md` e os patches em `bastiao/docs/CORRECAO*_*.patch`.

## Estado atual
- Etapa 1 e 2 publicadas: abertura (Pavel NPC, rádio, módulo, enfermaria, alarme, oficina,
  terminal), 3 línguas PT/EN/RU, som com eco/rádio.
- Etapa 3 (pacote do ChatGPT `BASTIAO_ETAPA3.py`, extraído no celular em
  `~/.bastiao_etapa3/pacote_41f942860b4357c61692`) instalada com as correções
  `bastiao/dist/CORRIGIR_ETAPA3_3.py`, `_4.py` e `_5.py` (aplicar no lugar; nunca baixar um pacote
  novo inteiro, senão perde os recibos e reenvia assets duplicados).
- Monstro 731-A: modelo GLB 46 ossos + 35 animações (rbxm) já enviados ao Roblox. Aparece quando
  a porta de contenção destrava e o alarme liga; anda pelos trilhos dos corredores (grafo em
  `src/server/Criatura.luau`), persegue quem vê, nunca entra na oficina (sala segura).
  Correção 5 (andar/perseguir + rugido mais alto e grave) entregue; falta confirmar no jogo.
- Teste na nuvem (Open Cloud Luau execution) NÃO roda física nem cria Player: o teste já usa
  jogadores falsos e confere o conteúdo das animações em vez de tocá-las.
- 36 sons novos não foram gerados (ElevenLabs gratuito bloqueado). Gerar quando o dono pagar o
  plano: `python BASTIAO_ETAPA3.py preparar-audio` (pede a chave escondida) → `assets` →
  `testar-nuvem` → `publicar`.

## O que fazer agora
1. Confirmar com o dono se o monstro anda, persegue e ruge forte após a correção 5.
2. Melhorar o encontro: primeira aparição marcante no corredor do meio (luz piscando, rugido),
   batidas na porta da oficina depois de trancar, sons de passos/respiração mais pesados.
3. Próxima etapa da história conforme o plano mestre (abaixo): objetivo "piso" depois da lista.

## Arquivos (links abertos)
- Plano mestre (PDF): https://drive.google.com/file/d/1O52ssdla6Fp0fqIGe4tnK0GN9v2XYvvK/view
- História completa: https://drive.google.com/file/d/1WjiJiwCCpoNwlGUOqgw787qGXSTDxKyg/view
- Contexto completo (zip): https://drive.google.com/file/d/1WSohe20iPa5BXgN-j5uPRwpkdsr0VeZ7/view
- Monstro 35 animações R6 (zip): https://drive.google.com/file/d/1TOVV4_t-RW0hpFs95JGWEwrKIur__uwa/view
- Monstro + áudio Etapa 3 (zip): https://drive.google.com/file/d/1lGW-BuktjsmldjTeloO2ESG19dThOjZw/view
- Prévia das animações (vídeo): https://drive.google.com/file/d/1kvCddvBmKKKE3KTEsL6CQCZvLzl2clCe/view
