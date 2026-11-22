# Capri animation atlases

The sprites come from Capri Desktop at commit `60df4a9fea49348faa5b839541a563cffbbeb582`. The Capri project credits its art and animations to an artist who prefers to stay private. The click animation is by mixmix312352. [Capri Desktop source](https://github.com/lachydotmcg/capri-desktop/tree/60df4a9fea49348faa5b839541a563cffbbeb582)

The original license contains the required notices and PolyForm Noncommercial 1.0.0 terms. The third-party notices contain the click animation credit. [License](LICENSE.md) · [Third-party notices](THIRD-PARTY-NOTICES.md)

Each body frame uses the same 142 × 200 canvas. Cell widths, playback rates, and pose placement follow the pinned desktop source. The click effect uses a centered 64 × 64 canvas. The idle, perch, laydown, and laydown sleep loops use fewer frames at a correspondingly lower rate to keep their original durations. Identical frames on a page reuse the same rectangle.

The manifest records each original strip path and SHA-256 hash, the sampled frame indices starting at zero, and the atlas rectangles for playback. Regenerate the images and manifest with Python 3.10+ and Pillow 9.1+ using the pinned checkout or supplied archive.

```sh
python tools/prepare_capri.py --source /path/to/CyberOutlaw-Capri-Assets.zip
```
