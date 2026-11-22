"""CyberOutlaw. O pacote portátil chama estas funções no Termux."""
from __future__ import annotations

import argparse
import getpass
from pathlib import Path

from media_tools import catalog, upload


def main(argv=None, *, root=None, storage=None):
    root = Path(root or Path(__file__).resolve().parent)
    storage = Path(storage or Path.home() / ".cyberoutlaw-menu")
    parser = argparse.ArgumentParser(description="CyberOutlaw, menu 3D para o Place 122033314086516")
    sub = parser.add_subparsers(dest="acao", required=True)
    sub.add_parser("verificar", help="Confere arquivos, origem e layout de assets localmente")
    media = sub.add_parser("midia", help="Envia apenas imagens e áudios gratuitos e consulta aprovação")
    media.add_argument("--video-id", help="ID de um Video já aprovado para este universo")
    intro = sub.add_parser("video", help="Vincula o ID de um Video que você já pode usar")
    intro.add_argument("id")
    sub.add_parser("instalar", help="Prepara backup e confirma a publicação do menu")
    sub.add_parser("resume", help="Confere um envio pendente sem repetir a publicação")
    offline = sub.add_parser("preparar-offline", help="Prepara uma cópia local para conferência")
    offline.add_argument("original")
    offline.add_argument("saida")
    recheck = sub.add_parser("rever-midia", help="Libera uma nova tentativa após uma recusa definitiva")
    recheck.add_argument("nome")
    args = parser.parse_args(argv)
    from install.cyber_installer import main as place_installer
    state = storage / "recibos-midia"
    video_file = storage / "video.json"
    try:
        if args.acao == "verificar":
            plan, capri = catalog.verify_media(root)
            print(f"{len(plan['assets'])} arquivos de mídia íntegros · {len(capri['clips'])} animações.")
            return place_installer(["verificar"], root=root)
        if args.acao == "midia":
            if args.video_id is not None:
                video_id = catalog.remember_video(video_file, args.video_id)
            else:
                video_id = catalog.saved_video(video_file)
            catalog.import_media(root, state, video=video_id)
            return 0
        if args.acao == "video":
            catalog.remember_video(video_file, args.id)
            print("ID do vídeo guardado para a próxima instalação do menu.")
            return 0
        if args.acao == "rever-midia":
            plan, _ = catalog.verify_media(root)
            row = next((row for row in plan["assets"] if row["key"] == args.nome), None)
            if not row:
                raise ValueError("Nome de mídia desconhecido.")
            upload.reset_rejected(root / "media/ASSET_PLAN.json", row["sha256"], state_dir=state)
            print("Recusa antiga arquivada. Use midia para tentar novamente com as permissões corrigidas.")
            return 0
        if args.acao == "instalar":
            catalog.make_config(root, video=catalog.saved_video(video_file))
        commands = [args.acao]
        if args.acao == "preparar-offline":
            commands.extend((args.original, args.saida))
        return place_installer(commands, root=root)
    except (ValueError, OSError, KeyError, getpass.GetPassWarning) as exc:
        print(f"Interrompido. {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
