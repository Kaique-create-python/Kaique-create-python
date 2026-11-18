"""Offline, preflighted correction installer. Importing this module has no side effects.

The caller owns the explicit payload allowlist. Never execute downloaded Python to
obtain rows: read literal ARQUIVOS with ast.literal_eval instead.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
from typing import Any, Mapping, TypedDict
import uuid
import zlib


class PatchReport(TypedDict):
    schemaVersion: int
    correction: int
    status: str
    root: str
    changed: list[str]
    unchanged: list[str]
    skipped: list[str]
    backups: dict[str, str]
    report_path: str | None
    files: list[dict[str, Any]]
    errors: list[str]
    created_at: str


class PatchError(ValueError):
    """Preflight refusal or a failed commit (with rollback diagnostics)."""


AUDIO_CLIP_KEYS = frozenset({
    'inspiracao', 'monster_step_01', 'monster_step_02', 'monster_breath',
    'impacto_porta', 'lanterna_liga', 'lanterna_desliga', 'menu_abre',
    'legenda_quebra', 'jumpscare',
})
_MODES = frozenset({'trocar', 'criar', 'teste', 'criar_teste', 'plano'})
_HASH = re.compile(r'[0-9a-f]{64}\Z')
_METADATA = '.correcao10'


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _safe(path: Path) -> None:
    """Reject symlinks and non-directory ancestors, including above the root."""
    absolute = Path(os.path.abspath(path))
    parts = [*reversed(absolute.parents), absolute]
    for part in parts:
        try:
            info = part.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode):
            raise PatchError('Atalho/symlink recusado: ' + str(part))
        if part != absolute and not stat.S_ISDIR(info.st_mode):
            raise PatchError('Ancestral nao e diretorio: ' + str(part))


def _relative(name: str) -> Path:
    if (not isinstance(name, str) or not name or '\\' in name or '\x00' in name
            or ':' in name or name.startswith('/')
            or any(p in ('', '.', '..') for p in name.split('/'))):
        raise PatchError('Caminho relativo inseguro: ' + repr(name))
    pure = PurePosixPath(name)
    if pure.parts[0] == _METADATA:
        raise PatchError('Payload nao pode alterar os metadados: ' + name)
    return Path(*pure.parts)


def _payload(name: str, item: Mapping[str, Any]) -> bytes:
    if not isinstance(item, Mapping) or item.get('modo') not in _MODES:
        raise PatchError('Modo invalido: ' + name)
    expected = item.get('novo')
    previous = item.get('antes')
    if (not isinstance(expected, str) or not _HASH.fullmatch(expected)
            or not isinstance(previous, (list, tuple))
            or any(not isinstance(h, str) or not _HASH.fullmatch(h) for h in previous)):
        raise PatchError('Manifesto SHA-256 invalido: ' + name)
    try:
        encoded = item['dados']
        if not isinstance(encoded, (str, bytes)):
            raise ValueError('dados must be base85 text')
        packed = base64.b85decode(encoded)
        decoder = zlib.decompressobj()
        raw = decoder.decompress(packed) + decoder.flush()
        if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
            raise ValueError('invalid zlib stream')
    except (KeyError, ValueError, TypeError, zlib.error) as exc:
        raise PatchError('Payload corrompido: ' + name) from exc
    if sha(raw) != expected:
        raise PatchError('SHA-256 do payload nao confere: ' + name)
    return raw


def _plan(raw: bytes, label: str) -> dict[str, Any]:
    try:
        plan = json.loads(raw.decode('utf-8'))
    except (UnicodeError, ValueError) as exc:
        raise PatchError('Plano de audio invalido: ' + label) from exc
    if (not isinstance(plan, dict) or plan.get('schemaVersion') != 1
            or not isinstance(plan.get('clips'), list)):
        raise PatchError('Plano de audio/schemaVersion invalido: ' + label)
    keys = []
    for clip in plan['clips']:
        if not isinstance(clip, dict) or not isinstance(clip.get('key'), str) or not clip['key']:
            raise PatchError('Clip de audio invalido: ' + label)
        keys.append(clip['key'])
    if len(keys) != len(set(keys)):
        raise PatchError('Chaves de audio duplicadas: ' + label)
    return plan


def _merge_plan(before: bytes, payload: bytes, item: Mapping[str, Any], name: str) -> bytes:
    old = _plan(before, name)
    incoming = _plan(payload, name + ' (payload)')
    allowed = item.get('clipes', item.get('clip_keys', AUDIO_CLIP_KEYS))
    if (not isinstance(allowed, (list, tuple, set, frozenset))
            or any(not isinstance(key, str) for key in allowed)):
        raise PatchError('clip_keys invalido: ' + name)
    updates = {clip['key']: clip for clip in incoming['clips'] if clip['key'] in allowed}
    by_key = {clip['key']: index for index, clip in enumerate(old['clips'])}
    changed = False
    for key, update in updates.items():
        if key in by_key:
            index = by_key[key]
            merged = {**old['clips'][index], **update}
            if merged != old['clips'][index]:
                old['clips'][index] = merged
                changed = True
        else:
            old['clips'].append(update)
            changed = True
    # Preserve original bytes/formatting when semantic content is already correct.
    return (json.dumps(old, ensure_ascii=False, indent=2) + '\n').encode('utf-8') if changed else before


def _atomic_write(path: Path, raw: bytes, mode: int) -> None:
    """Same-directory replace: never expose a partially written target."""
    _safe(path)
    descriptor, temporary_name = tempfile.mkstemp(prefix='.' + path.name + '.', suffix='.tmp', dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        _safe(path)
        os.replace(temporary, path)
        if path.read_bytes() != raw:
            raise OSError('Verificacao apos escrita falhou: ' + str(path))
    finally:
        if temporary.exists():
            temporary.unlink()


def _mkdir(path: Path, created: list[Path]) -> None:
    if path.exists():
        _safe(path)
        if not path.is_dir():
            raise PatchError('Nao e diretorio: ' + str(path))
        return
    _mkdir(path.parent, created)
    _safe(path)
    path.mkdir(mode=0o700 if path.name == _METADATA else 0o755)
    created.append(path)


def _preflight(pasta: str | Path, rows: Mapping[str, Mapping[str, Any]]) -> tuple[Path, list[dict[str, Any]], PatchReport]:
    root = Path(os.path.abspath(Path(pasta).expanduser()))
    _safe(root)
    if not root.is_dir():
        raise PatchError('Pasta de pacote inexistente: ' + str(root))
    _safe(root / _METADATA)
    if (root / _METADATA).exists() and not (root / _METADATA).is_dir():
        raise PatchError('Diretorio de metadados invalido: ' + str(root / _METADATA))
    if not isinstance(rows, Mapping):
        raise PatchError('ARQUIVOS precisa ser um dicionario')
    decoded = []
    for name, item in rows.items():
        relative = _relative(name)
        raw = _payload(name, item)  # Validate even skipped/already current rows.
        if item['modo'] == 'plano':
            _plan(raw, name + ' (payload)')
        decoded.append((name, relative, item, raw))
    names = set(rows)
    for name in names:
        if any(str(parent) in names for parent in PurePosixPath(name).parents if str(parent) != '.'):
            raise PatchError('Payload tem caminhos sobrepostos: ' + name)
    report: PatchReport = {
        'schemaVersion': 1, 'correction': 10, 'status': 'planned', 'root': str(root),
        'changed': [], 'unchanged': [], 'skipped': [], 'backups': {},
        'report_path': None, 'files': [], 'errors': [],
        'created_at': datetime.now(timezone.utc).isoformat(),
    }
    operations = []
    for name, relative, item, raw in decoded:
        target = root / relative
        _safe(target)
        exists = target.exists()
        if exists and not target.is_file():
            raise PatchError('Alvo nao e arquivo regular: ' + name)
        info = target.stat() if exists else None
        before = target.read_bytes() if exists else None
        before_hash = sha(before) if before is not None else None
        mode = item['modo']
        action = 'write'
        if before is None:
            if mode == 'teste':
                action = 'skip'
            elif mode not in ('criar', 'criar_teste'):
                raise PatchError('Falta arquivo obrigatorio: ' + name)
        elif mode == 'plano':
            raw = _merge_plan(before, raw, item, name)
            if raw == before:
                action = 'unchanged'
        elif before_hash == item['novo']:
            action = 'unchanged'
        elif before_hash not in item['antes']:
            if mode in ('teste', 'criar_teste'):
                action = 'skip'
            else:
                raise PatchError('Versao desconhecida/alterada de ' + name + ' (SHA-256 ' + before_hash + '); nada foi alterado')
        detail = {
            'path': name, 'action': action, 'before_sha256': before_hash,
            'payload_sha256': item['novo'], 'after_sha256': sha(raw),
            'mode': stat.S_IMODE(info.st_mode) if info else 0o644,
        }
        report['files'].append(detail)
        report[{'write': 'changed', 'skip': 'skipped', 'unchanged': 'unchanged'}[action]].append(name)
        operations.append({'name': name, 'target': target, 'before': before,
                           'raw': raw, 'info': info, 'action': action, 'detail': detail})
    return root, operations, report


def apply(pasta: str | Path, rows: Mapping[str, Mapping[str, Any]], *, verify: bool = False) -> PatchReport:
    """Validate the entire package, then atomically replace allowlisted files.

    Unknown user source fails closed, including modo=criar. Optional tests may
    be skipped. Audio mode merges only clipes/clip_keys (default: the ten C9 effects).
    Validation/commit errors raise PatchError. verify=True never writes anything.
    """
    root, operations, report = _preflight(pasta, rows)
    if verify:
        report['status'] = 'verified'
        return report
    pending = [op for op in operations if op['action'] == 'write']
    if not pending:
        report['status'] = 'unchanged'
        return report
    created: list[Path] = []
    replaced = []
    transaction_owned = False
    transaction = root / _METADATA / ('aplicacao_' + uuid.uuid4().hex)
    try:
        # Detect ordinary edits between preflight and the first mutation.
        for op in operations:
            _safe(op['target'])
            actual = op['target'].read_bytes() if op['target'].exists() else None
            if actual != op['before']:
                raise PatchError('Arquivo mudou durante a verificacao: ' + op['name'])
        _mkdir(transaction.parent, created)
        _safe(transaction)
        transaction.mkdir(mode=0o700)  # Never reuse or overwrite an older backup.
        created.append(transaction)
        transaction_owned = True
        # All backups complete before replacing any payload target.
        for op in pending:
            if op['before'] is not None:
                backup = transaction / 'originais' / op['name']
                _mkdir(backup.parent, created)
                _atomic_write(backup, op['before'], op['detail']['mode'])
                os.utime(backup, ns=(op['info'].st_atime_ns, op['info'].st_mtime_ns))
                report['backups'][op['name']] = str(backup)
                op['detail']['backup'] = str(backup)
        for op in pending:
            _mkdir(op['target'].parent, created)
            _safe(op['target'])
            actual = op['target'].read_bytes() if op['target'].exists() else None
            if actual != op['before']:
                raise PatchError('Arquivo mudou antes da escrita: ' + op['name'])
            # Include this target in rollback if post-replace verification fails.
            replaced.append(op)
            _atomic_write(op['target'], op['raw'], op['detail']['mode'])
        report['status'] = 'applied'
        report['report_path'] = str(transaction / 'relatorio.json')
        report['created_at'] = datetime.now(timezone.utc).isoformat()
        _atomic_write(Path(report['report_path']), (json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode('utf-8'), 0o600)
        return report
    except BaseException as exc:
        failures = []
        for op in reversed(replaced):
            try:
                _safe(op['target'])
                if op['before'] is None:
                    op['target'].unlink(missing_ok=True)
                else:
                    _atomic_write(op['target'], op['before'], op['detail']['mode'])
                    os.utime(op['target'], ns=(op['info'].st_atime_ns, op['info'].st_mtime_ns))
            except BaseException as restore_error:
                failures.append(op['name'] + ': ' + str(restore_error))
        if not failures:
            if transaction_owned and transaction.exists():
                shutil.rmtree(transaction)
            for directory in reversed(created):
                if directory.exists():
                    try:
                        directory.rmdir()
                    except OSError:
                        pass
            raise PatchError('Falha ao aplicar; rollback concluido: ' + str(exc)) from exc
        raise PatchError('Falha ao aplicar; rollback incompleto: ' + '; '.join(failures)
                         + '. Backups preservados em ' + str(transaction) + '. Causa: ' + str(exc)) from exc


def candidatas(home: str | Path | None = None) -> list[Path]:
    """Discover phone package caches; never use cwd as an implicit target."""
    base = Path(home) if home is not None else Path.home()
    cache = base / '.bastiao_etapa3'
    if not cache.is_dir():
        return []
    return [path for path in sorted(cache.glob('pacote_*'))
            if path.is_dir() and (path / 'instalar.py').is_file()]


def main(rows: Mapping[str, Mapping[str, Any]], argv: list[str] | None = None) -> int:
    """CLI entrypoint for the standalone wrapper; no publication or API calls."""
    parser = argparse.ArgumentParser(description='Correcao 10 local/offline com backup e rollback.')
    parser.add_argument('pastas', nargs='*', help='Pastas explicitas; padrao: ~/.bastiao_etapa3/pacote_*')
    parser.add_argument('--verify', '--verificar', action='store_true', help='Verifica tudo sem escrever arquivos, backups ou relatorios')
    args = parser.parse_args(argv)
    roots = [Path(value) for value in args.pastas] if args.pastas else candidatas()
    if not roots:
        print('ERRO: nenhum pacote em ~/.bastiao_etapa3/pacote_*. Rode o status do instalador ou informe a pasta explicitamente.')
        return 1
    succeeded = 0
    for root in roots:
        try:
            report = apply(root, rows, verify=args.verify)
        except (PatchError, OSError) as exc:
            print('Pacote ' + str(root) + ': RECUSADO: ' + str(exc))
            continue
        succeeded += 1
        verb = 'verificado (sem escrita)' if args.verify else ('corrigido' if report['changed'] else 'ja estava corrigido')
        print('Pacote ' + str(root) + ': ' + verb + '; ' + str(len(report['changed'])) + ' arquivo(s), ' + str(len(report['skipped'])) + ' teste(s) opcional(is) pulado(s).')
        if report['report_path']:
            print('Relatorio e caminhos dos backups: ' + report['report_path'])
    # A shell `&& instalar` must stop if even one candidate was refused.
    return 0 if succeeded == len(roots) else 1
