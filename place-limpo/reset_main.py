"""Fluxo do atualizador. O gerador inclui o transporte e o Baseplate revisados."""


def confirmar_destino():
    opener = build_opener(NoRedirect())

    def public(url):
        with opener.open(url, timeout=25) as response:
            return json.loads(response.read(2 * 1024 * 1024))

    link = public(f"{API}/universes/v1/places/{TARGET['place']}/universe")
    games = public(f"https://games.roblox.com/v1/games?universeIds={TARGET['universe']}")["data"]
    if link.get("universeId") != TARGET["universe"] or len(games) != 1:
        raise Failure("O Roblox não confirmou a correspondência dos IDs.")
    game = games[0]
    if game.get("id") != TARGET["universe"] or game.get("rootPlaceId") != TARGET["place"]:
        raise Failure("O Roblox não confirmou este Place como o local inicial.")
    print(f"Experiência {game['name']!r} · Universo {TARGET['universe']} · Place inicial {TARGET['place']}")
    print("Conteúdo preparado: Baseplate 512 × 512 e um ponto de nascer, sem conteúdo personalizado.")


def atual(cloud):
    latest, rows = cloud.history()
    published = [number(v["version"]) for v in rows if v.get("isPublished") is True]
    if not published:
        raise Failure("Não foi possível identificar uma versão publicada para o backup.")
    return latest, max(published)


def conferir_publicacao(cloud, receipt):
    latest, published = atual(cloud)
    if published <= receipt["publicada_anterior"]:
        raise Failure("O Roblox ainda não confirmou uma versão publicada após o envio. Use verificar.")
    if receipt.get("versao_resposta", published) != published:
        raise Failure("A versão publicada atual diverge da resposta do envio. Preserve o backup.")
    found = cloud.download(published, STATE / f"Conferencia_v{published}.rbxl")
    if found != PLACE_LIMPO:
        raise Failure("O arquivo devolvido pelo Roblox difere do preparado. Preserve o recibo e confira o histórico.")
    save(STATE / f"Publicacao_v{published}.json", {**receipt, "publicada": published, "verificada": True})
    (STATE / "envio-pendente.json").unlink()
    sync_dir(STATE)
    print(f"Place limpo publicado e conferido na versão {published}.")


def limpar(cloud):
    pending = STATE / "envio-pendente.json"
    if pending.exists():
        raise Failure("Já existe um envio pendente. Execute verificar antes de tentar novamente.")
    latest, published = atual(cloud)
    backups = {}
    for version in sorted({latest, published}):
        target = STATE / f"Backup_Place_{TARGET['place']}_v{version}.rbxl"
        raw = cloud.download(version, target)
        backups[str(version)] = {"arquivo": target.name, "sha256": sha(raw), "bytes": len(raw)}
        print(f"Backup da versão {version} guardado em {target}")
        if version == published and raw == PLACE_LIMPO and latest == published:
            print("A versão publicada já corresponde ao Baseplate preparado.")
            return
    write_once(STATE / "Baseplate.rbxl", PLACE_LIMPO)
    print(f"A limpeza troca todo o conteúdo do Place inicial. Versão publicada atual {published}.")
    confirmacao = f"LIMPAR {TARGET['place']}"
    if input(f"Para substituir o Place, digite {confirmacao}\n> ").strip() != confirmacao:
        print("Limpeza cancelada. Backups preservados.")
        return
    cloud.validate_destination()
    if atual(cloud) != (latest, published):
        raise Failure("O histórico mudou desde o backup. Rode limpar novamente para conferir a versão nova.")
    receipt = {**TARGET, "salva_anterior": latest, "publicada_anterior": published,
               "backups": backups, "sha256_baseplate": sha(PLACE_LIMPO), "data": stamp()}
    write_once(pending, json.dumps(receipt).encode())
    try:
        path = f"/universes/v1/{TARGET['universe']}/places/{TARGET['place']}/versions?versionType=Published"
        result = cloud.request(path, method="POST", raw=PLACE_LIMPO, mime="application/octet-stream")
    except Failure as exc:
        if exc.code in (400, 401, 403, 404, 413, 415, 422, 429):
            save(STATE / "envio-recusado.json", {**receipt, "http": exc.code})
            pending.unlink()
            sync_dir(STATE)
        raise
    receipt["versao_resposta"] = number(result.get("versionNumber", 0))
    save(pending, receipt)
    conferir_publicacao(cloud, receipt)


def main():
    global STATE
    parser = argparse.ArgumentParser(description="Modelo limpo para o Place inicial de Ideias.")
    parser.add_argument("acao", nargs="?", default="info", choices=("info", "limpar", "verificar"))
    args = parser.parse_args()
    confirmar_destino()
    if args.acao == "info":
        return
    STATE = private_dir(Path.home() / f"roblox-place-{TARGET['place']}")
    with guard(STATE / "execucao.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Failure("Já existe uma execução aberta para este Place.") from None
        pending = STATE / "envio-pendente.json"
        if args.acao == "limpar" and pending.exists():
            raise Failure("Já existe um envio pendente. Execute verificar.")
        receipt = read(pending) if args.acao == "verificar" else None
        if args.acao == "verificar" and receipt is None:
            print("Nenhum envio pendente. Backups e recibos ficam em", STATE)
            return
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            key = getpass.getpass("Chave Open Cloud (oculta): ").strip()
        if not key:
            raise Failure("A chave está vazia.")
        cloud = Cloud(key, TARGET)
        cloud.validate_destination()
        if args.acao == "limpar":
            limpar(cloud)
        else:
            if any(receipt.get(k) != v for k, v in TARGET.items()) or receipt.get("sha256_baseplate") != sha(PLACE_LIMPO):
                raise Failure("Recibo pertence a outro envio.")
            conferir_publicacao(cloud, receipt)


if __name__ == "__main__":
    try:
        main()
    except (Failure, OSError, ValueError, KeyError, EOFError, KeyboardInterrupt, getpass.GetPassWarning) as error:
        print("Interrompido.", str(error), file=sys.stderr)
        if STATE and (STATE / "envio-pendente.json").exists():
            print("Envio pendente. Use o comando verificar com este mesmo arquivo.", file=sys.stderr)
        raise SystemExit(1)
