# Arte do CyberOutlaw

O letreiro CyberOutlaw foi desenhado como uma peça única e exportado em PNG transparente. A arte de origem tem SHA-256 `6b914538a101793147075af7c2543aa49c9ca31b14efac9a5545a01b5ba53746`.

O atlas reúne três ilustrações geradas para os telões 3D da cidade Maré Baixa. Cada quadro ocupa 340 × 1020 px, na ordem Vértice, Sincronia e Porto 03. A imagem gerada antes da composição tem SHA-256 `c387e0280b093bf1d741adaac52e7b0690e8097882536d4ce9b44288f2428c75`. O script `tools/prepare_rooftop_art.py` enquadra as faces, prepara as faixas dos letreiros e gera o letreiro transparente.

O concreto e o asfalto usam cor e mapas de relevo de digitalizações Poly Haven. As cores foram dessaturadas para receber a luz de néon. O mapa de rugosidade do asfalto foi adaptado para incluir regiões úmidas. [Concrete Wall 006](https://polyhaven.com/a/concrete_wall_006) · [Asphalt 07](https://polyhaven.com/a/asphalt_07) · [Licença CC0](https://polyhaven.com/license)

A arte das fachadas contém quatro materiais gerados para a revisão local do cenário. O atlas de origem tem SHA-256 `0fe50b69238a48caa8d30e9887e04cb3f8fc9c95e26dede4fbf7dc56d270c204`. Os quatro panos são recortados em superfícies tridimensionais e acompanhados por montantes e varandas em geometria.

## Cidade jogável

As janelas dos prédios da cidade jogável (`fachada_residencial.png`, `fachada_escritorio.png` e `fachada_vidro.png`) foram desenhadas por código em `tools/draw_city_textures.py`. Cada janela é um retângulo calculado por regras fixas, sem imagem gerada por IA. A cidade jogável usa só essas janelas, o asfalto e o concreto Poly Haven. Os telões e as fachadas geradas do menu continuam apenas no cenário do menu.

## Cidade jogável v2

- **Desenhado por código, sem IA:**
  - Painéis dos megaprédios: `fachada_painel.png`.
  - Anúncios das marcas fictícias Alvor, Limiar, Kairos, Estuário Net e Nova Chuva: `anuncios.png`.
  - Os dois estão em `tools/draw_city_art.py`. O céu noturno (`ceu_*.png`) está em `tools/draw_sky.py`.
  - As fontes dos anúncios são Inter e Michroma, ambas com licença SIL Open Font License.
- **Gerado com IA, com autorização do dono do projeto:** os interiores das lojas vistos pela vitrine (`vitrines.png`).
  São oito imagens (mercadinho, bar, farmácia, eletrônicos, lanchonete, roupas, fliperama e saguão), geradas no
  Figma (gpt-image-2.5-flare). Os originais ficam no arquivo do Figma do projeto.
- **Poças:** `poca_1.png` a `poca_4.png` usam o asfalto Poly Haven já creditado acima. A água é recortada por ruído determinístico, também em `tools/draw_city_art.py`.
- **Fotos Poly Haven (CC0), com cor e relevo:**
  - [Dark Brick Wall](https://polyhaven.com/a/dark_brick_wall): `tijolo`.
  - [Corrugated Iron 02](https://polyhaven.com/a/corrugated_iron_02): `metal_ondulado`.
  - [Hexagonal Concrete Paving](https://polyhaven.com/a/hexagonal_concrete_paving): `piso_hexagonal`.
  - [Cracked Concrete](https://polyhaven.com/a/cracked_concrete): `concreto_rachado`.
  - `tools/prepare_city_textures.py` baixa, escurece e dessatura as cores para a noite.
  - SHA-256 dos arquivos de origem (cor / relevo):
    - tijolo: `1544cf036591da20cb12a593316a9ca57aa4bb32a5b1e41a8ddeb07869fd509b` / `fea4334c535ed4ca764a2b6640641dd4fa93d94917f9687f05f89fa97a837bd2`
    - metal ondulado: `77ae71a1192bd5f45cf6880f43af6a7405a70fc9ef85f1ca12b6847f5fc2a3ed` / `1a26c763d78297fe738d9ba350c03c252a6f6fb4a3c497d97f057028e61a8a11`
    - piso hexagonal: `5a7e8cb68564fc8dea8c0f399dd9b748f5d2ce15bf7f632818906e2e4bcadc7c` / `e0be8db07cbc32a2b1ff9a8bb112005586f3482ad9c5cecd73f0d93ac6ba8d5a`
    - concreto rachado: `665d98c25d740d18e65a0adb8df02f7811a9447d5396a7339c7ec16a8ed9cbcd` / `a5b3f2aefb2ac27eebc043d10d8e1d0c96385a5432eeff67791c55caf2a2e77c`
- **Correção:** até a versão anterior, o instalador não entregava as janelas desenhadas ao script da cidade, e os prédios apareciam como blocos de néon. Agora entrega todas as imagens da tabela acima. As artes geradas do menu continuam fora da cidade jogável.
