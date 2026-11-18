#!/usr/bin/env python3
"""Atualizacao local de iluminacao do Projeto Bastiao."""
import sys
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
    update: str
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
_METADATA = '.graficos_bastiao'


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
        'schemaVersion': 1, 'update': 'graficos-bastiao', 'status': 'planned', 'root': str(root),
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
    parser = argparse.ArgumentParser(description='Iluminacao do Bastiao com backup local.')
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

ARQUIVOS = {'src/client/BastiaoIluminacao.client.luau': {'modo': 'criar', 'antes': [], 'novo': '3c4d27b72665e985fdce739e2e4c724fb0af3b46f190b51eac9ca5ba07bf9bcb', 'dados': 'c-oCv*>W4X6@4bZ0^t)m)9P>$Wr<~ZilP>)N@FRc#!1HIN`Y*UgxzfPpwYDCDf?&gkjnE^zCb^gd$ILGN=ez08o;?L?gHT8;7^&7e4&~L2W0#y&lDrESkRb6l*IX05(zTTlg~_sWK7sYDl-1`ucv>CfQXE&xD?BnJ+O>00(hDzCKHOh79vqR$?1l~d_^MwQ~1GIDPkB)q<P>V4`?!!HW$(30`Lq6Ygl>uLvk86jXF1cwFZVOa!OWo!$wz3&6wQs1#7q5TB~EhcQJirGTVo>OCCDS6T7w#U95V7Uos}IlQdT^kkv7s_^(2K&QiLc$}a-k;!~|HfUVl$4NjYZg=9>j?b+?;z<&cl3TttDnI{XyMbhpx8<MG9CR+cQ#kD&-YF~j?ZW;7oN#t~wt2ywUh*-!$xRhcuy*hI~xjP@<U;N|x-TlS%{rCo8-LTgmHZc$;Ldb|EG@=+J5#O*Rd-@M<Im83UfZ;kAHZ0;el?XCp3nk<$@JAel$m5ozEE6Pq`hzS03+{_pDtJbI%NY^mlfVd*1VTyDfTUDXl0b|Sw1P`OEQFK{ATF9Fx6|px`Rx=m{k_?sn>hzs7=VrK-bq0EhwyXK36O)E?+=b~;Rt>W4`FE~X~eXt-Tp}cT)4Ez!$ClX{eT>G0S2~bTs>-FA7`_aE%KO3J#*L(n%}Ha7w;}FrazCT*W+i^LJf}VYV}d09_m(83ly%X1(+ciHtf~Z>K*rLY9Xal>-O?`a{X?vP6L!W3`no;s^I|Dft7y$RaK|Mib_L(9D-4Ule$Vr$8}G2Q6;OBi)$Z1Z7fVUGa~PG^b8>4Z6RZ+S_6v>RqJrWlXm}*9GDTEXKnxCID~)e!1^(|x!*4%J>XaJBN_C&9WUYw!wTeNEMmGz+eYl432a*zJX9ngUy?!;c}==RtyxmueHLfTxjk^qe<(iM15m5)XLOeCcqV2tZPO7+^39ydfXs_eL*~XE_u)09U|)L<GHAyO*)IcE?w|+om_aRp5-ws!6X%xSavGZr1)GaHW$bn1a7MQ*`ip_yuq}(j_cVsQ)?Vl~8$jzAeLr>HvYNVu*Qex=poZltSFXU}y~r2qi-gW&77?06P-oOG>SvK>%%Y6N>M@1A*fJ@(4&mR4kbK1x8jpa@V?bz{#+*fN1diD<?+J)u1;OAvOk7S0%P<=O!w=U9pppgqs7Kh3lNEe>so&rqNOr`UCFX>#uj7oQQlt`efF!deF^4W&ZnjVpvkVf65~!XMoGhW3LV=7qXoaO&m)U#B?x%lm$SS8Yq8lj2@PA8V+pMXAVXTWZD76)_qIf*m2&Dx;(FL5Mxug=g(G;qFg$1gH2m);$gaRVw3z3KQu%ZzjMA~Bh2~v4PoO^x>$Y=IABE~^baHw1{<s2WUYai_$9W}VahDRl4beI^4T(J!}(t<{sm0Mfn&@yyIL(~V5{Lw9;zp=;qUHo7;eDq=s0;M(^4F`t}Y&3Rguva6X*(fQNVNSReE8DU*OP0066;TNTtGN%&%9M^zm{Brkfe$6~_nT8zOT=kpZxz$uVTC~J<oxvA!b2z3WVxAgQkN8yTJtNL;{Xsx-tDJ$e|PrI`Dm-Fgo9~@n5<&iHZvXM(K6?imUEbG3EV`K?+Wyx=mS=Ra0&&`a0;i;3wGA8iuJ2~>u1IK8MX>k&<lQpy|CLe#yLwY<>&@Ww;{EG-7!AHl4#AW7-^!urR!Q<53fb1A{6v-Vs)qR5mJ?FH@~{ihR|~H*+J}r3(K$wzfuMvyM3)hGN_js`z3(_9N}?w3Bh1eB(UkklOp4w@PHh|0NcPO1po|EFQU@rp#AQ`+%pdEsEf6P$IhU}i^ak4t<t00D{+hyCBN*=jI!U%vQJ^{@<uHeK|`E0Yvwnm5PMK<jq8-nAp6P;E}AfUW)BiL`$z3m8&xU0xKPwxINxNM8+J-SmzmaOrz9=>W4T`PB)a4>Q<F81qc$?GoQy0fQrPl;osHXCV#iu$5c+h0KG|o;ma{K+_Kbz+5_=^4si@E9UR5qF-a8iJZ)0_xTjlFXtMe=qBLgp3V+F37=L)V^XEalsiU~~tPsa)0&;=FGaj~5UoCMAFv`{IWm}H#j6^~m(4_+vJUo^tQiJS6fS!P&i^;c+k+~Y9^GUNhENofiMWlC%iu8F;b7t~$n8=7D>bKsf-Z<iC?&UWi90tE*jI#MZwdV#VanF0`!Pqm6pZ^VM4`XhYHXbk7?*LY&A8#~KQ41v9#3R!6JrEeX3xMj@9ddX^cq{oX5kcKY&w0?W<7;i|guXXd2e}~(^!JszvhSX5MB5HVaRGS3cu`6MPine~+2?yVsG<h0P2+{gM%GAssPf2f&sntX?VeeKe9rvq9SWw)PcCKw5kBlv(dbfaOdn$B~JppNr&1JL|`1^cl@294PqEI*Egm;S0wuj?IvgJ}F8z7k3%jXP~Vjx0yNiWA;O#^LNY54z0nXTbW{$(bXDq&d$yt^SjI9Lkr33E+$bkAkcSiwO(T{DT#MqV1wf}nGAqu$Zp-n6aqe)O#FhMPW0Rh-Rb+0lHD`Q8}!1Ymkh*%`0S%){RmB3e$)1Yc})U|uYj@KH8S^8(<RL^jrkRSPXdD`vl+wa&4-hp61K5nnY*M&fWED`Vt57Gm?Fk!OfNBlX9wX_^BP@UQ3#$S0Ezy7KgnOxx2>E~Sit{d-a94FFm?98$HuU0!k)M<vk}A$Z2Hx*%Vj6Z$#~4D{*Uibh3tvF{j#3$^lL*A4O6%6qAXzN~}0{Sw%m_1$3~?v38Yq7UA~DTnez8~Yw0+Iln<S}t9zF^|jMHRQ+(Aa8}rQlZf^_-jZz^{_e&Pj(}w!e^H9IQ}18y5XzZiMoE?EmdR|(=^lP=B}MtgIm>{QFKA^B#k}JOphiaNnksR_ufdMAj=4fcVsR|ZszsQlkGD%WUVtu?YW0A_K>y@{8O6crz_YHAB%?Jup}5QXq5YkeNfI8lBX&>2M0>=h{f#|&X1MXYH#xBoM#JbUacMN@nNU=Uti8Q8U'}, 'src/teste_nuvem.luau': {'modo': 'trocar', 'antes': ['2888e465aebc41e7f040b694db422059f2f71008c4fb442277064cf20f7f310a'], 'novo': 'b94d9a67ee60104a1335dabca4527e773705d65de73b3ba98490a70f3ec765ef', 'dados': 'c-p;v+io03vfwlM6^S+sbd6i3CMi)8ZF$h9D4SkM)RMG4GlI~k*p+OS)LqrC3r)$;0T%lsYs|yJ9KcWBg9YYs`C}Wmyj4|Gl703VGh%gBULqqSBO@XsB5&PN&ySD3Jvcp5UrkO<53m2{k=ol+wXSNd@<ip$rCzEuQ3rLhO4N=TK53Fh9bD;IQ)fjE1(u1r)Ma)3_d=aao_s$U!Ml8xs8w^e$Yx2JM4Pv6sUwx;Rh=x7v?x_FD|I!~d7Y>vhrU!w{nh%aE>xlxS$>hIe_0f>WT9r~bM;Wgar`f8h{dwJ7%5HAXjQ0-q`JWNQ?0NsRn5w5Rjag6t7KNxI*QeaRzEh$;>Sjp2x)c>P+k8U!h4=9E|PKt&3M2)LmUY3F*dE#R-~kBHPa=)sMUEvfM@CTzvnfStkm`Ys$939bH(jQy(;E~I!h`IebmXUF80(Cfj`mkT;BVkC>QBSee>NT#PV5@zL_OUXrISXnPSr3PNeE0Eh+{7TVDT`Hj9Ef{VD<Ia744DEcF~(08p0&)Rc;MA_WjYVbd-`x=3bPl|_ohVR(Q%UEw?;LMmNeW{3`eim_caXITU90lKm*q}{s_%vW*-NNLIhN2oLSi*2e|u~dk!{Q8$ND^#grGKZ@K`$;uZScHhouAnZU^7$fp12Y8WvPxRt#n!RW@*F`0m}iR&$VRK{f57knpE%<J5w^N2i&dHFG)Xm(Axz4ST3r8{&l`9gK0j6e_y4GaXZY{&chQLZfd3FuC{XJ~f{4MVa+&1-2a#9>pNI3ZSrrvf-VD%lS-jQwe6F(^UoMJbRYd|3&WJ`rLnve*_abQLd2*>2K=5he6;Lba6%dA40opGsog<!rU~~L!rbOlVPpy~!)Fg$v%r1*aI=LUgH0BqLpkqKpkrV@@g+(zZT7HHYOMYxJRV9ndL=}x8^*ygMz%I}`&=MgSs-I`ecyp5%<TrJ_IzbR%Mjk4lHNE$>uI0^e;C&uMQsqf8zoCZvYAYP;6~a{O^aN-)nfKP~6tdN^h%Qfv)Nkmxr<iM^hSBR%h_bJ;U%*y7{YmTmhA#c@w$gsFSimv|c6vk2P9dl+^|L&iWyLA+(1)<d;~BhvJv7Z1O%1PqM$Yt_Q3*UXmR}=yT~#`Tw{_XTPo$j+%fB0`<T9)5k1Rhg@Nsj47z;cOj*GKJaivaxu+v-6X_F2NZ+@tDMw=UpY?&dO#O?vzOI)CrME*&WW@p(Vqcs3jn5=*Y;EuqY88@A*f)$t5K;acM>s1G+fS+S4sXi~trPKjZg~g-?>fLDboq8vuKZnhTb}C}_!(}z!Q&nAN`8?X(0Mx{G{7|6Mn;Ug<w$L$b2*A{aSb#7xl1eeK!67Vq`hl%QBegYByW?>bZR$L2_ev;i_1fuy@jO!4Twf!z3k{2Lm={13(#%Mm=X+`xsas#dztJ9S9mPT?IpCZp{WVP`3~L2H7sK-$I?m2vG1u@-)fXCyZZJ-;UD#pOU{4M3uN@vV0HfMKh&D<MY&wU!eE^og#DFHUVi*|!Z4Hkh?0tK3^z0y?6{*H?^H`BBc^j<RS~me$k51LU0=<!lGC8_+a5{NDxwSJ;K!#Wb_7pC$W8O4*hC&Iw+#27zw|i%I`~ICf<}+`7@a_JCyW8Ujcg8#8?FZvsK?`GL@Q5M0%{w~K|Ez$`wJu^<d1i3lz-cf5G_KtEYxw6d#U27^pnLlK9Q$|Q8JwW=iDkyJ$Y=vt0mbMX$^z?`Mgcym4f|-}2_WwQvVODDL+l#mCk=ZSqL=8Bkot-Hq#iz0;}Eu|xWHlcNrB?5%;rgb{TpucfV1mg)MfHEyAe+<`bl4%4XdIlXO_M_I^wdIK+1P_?r#AU0AL2cVA*}bm0;LF%vfT0ss5yPcGPEPxt_hLwKNSZEQ-{p>dy9qI}dj6Z9muzNn2_VN2!N{PsjJKfbU%P0!%-%x3DP7BzwE34pDy0u@4a6Kzs!$?`LUHy^GxUKbzqs$dj=yk7o+v3a-K|Hx2NZr10zl<O-;eXA4}lT;V)hT%hC%ZQ)L_e~~THQs=-Es4A{@DiS{flEZ1F9%SXyXKB~IGMM0QHW)kbpY5O8+q7T!U*RgP#)77}AdQ)eg_uuj!ZET!++|`Bu7U72WvpfK6XC{@CA|On9gUQ61R@kj!?=wRcbyfWgVaN)2OOlnfc@h(lA|!kvsX~i%^|Ky>VwL9j1tO0Kkz5s2idS9M8ZnJk~4e}^3lO#gd4Ut+{mE8WO;V|E6AR>ztJvNgKSLov~XGm8d)rDJs$5S6gciJbO)=)p>~MifwGq5Z=(2wNSsj}xk&+54+EgpPA&36XTluVxf1Y?jNV6@L;?HLyaADa0Rqs8EY1*W0vmezgrOD8;F6>H!By>g#ZNeQ?OqvaDKfJ;^kz9&Z)aGqO(vfKD=;*M{|Jkt;k*5vdtJkha1ZL!)nwT(S)%!=C|_3qoZfq!<>}+Bta#C(B<YknAT#Nmss)_WFK6gv4@7z@2@=pOt3chl%3$Lul}yA6c1x7`0cem^VeLQ%j0%egtUgUirB1aholo#3@`XqI9u)0r$fSKky)V@L@p#-K>i}xp2A8V^?1O4Z6LdpsC{rl^O*Dwy9Ldr){0^2k$d)K429out^@7E9kq8N{ebNa@?E3@N;l)?1eS<FkpV!zvu#7T!Z+rU}NeKkU?<RQ$JCJsjdh`_6B|l<`kElR%`BekN>s9M2RAHt4B0taOB3~ot6*_M-Qkl`HMMlqYq`1D_GP6s7<xZb-OC!v<J*vT_x)WLJhf&v#zXzJ{8Fy!?idK9gO0-kLj-Eb;COSA+*T6ok0vHf%h`b~Pj^`%`hd;|*X3<AN7K|r{*Z?$><SG7L+do@EY{hKRpv_{I6dzXq(3W=$%WDJHX830Bu$rK*4t+7qg9r<`0`VhYUNC`a$nv}zxCu&m*4XS$X=Q8PDyszulzoiO^)?kt(9~G&64784&<F2UxP_hTGDADc3|3SOlM8&PL<S4$f-xnbVJh}F4WuO*J`sg^hM5VOxih6%`x|j=l!5UX<ncu_PtdrfD-hk$Hgtnb41j+Jnmld*GmUc~OApY5#oodg_ta-wcSrX>MNFQ9zBh;U!8V^n#EVkT;ooJGCh;aLQ8aIf9hDYukJ$6`hpzi~k=Go`D6<~<MA^ap*kmQ>7*sb>B$i<Hu3$22Yag@t5lF`Qal$gi)&qX|G`WJMgY(Z?-FQ>UfAsl>WbyiBrFF_*`Q^z9B%Rv5zR$0Z^<2C5cf*G0<0F`yH}o~WYhG8la8EB_J}-&|wYMW%rKvBJ!3e`issvys-ni*4HK_eCsRKrgVQ?aH6l~n}Wnj=2XqQ9^9T9Dgh$?+Cc#)xjl~s%W-JibDVt$H!XuFz)TL;z&YL2@$h5&(PiJ)+Aq;5dV%bS|rFe4IiZ9|M21ECb&0+tB#<7TlyQF|DTR4Dmw7_wSMqJ>0l$<K)+7K8Hiu|lCS&Ut(u5i1ZN`mNOu4=$?K$C%$*lV+3WWJxq-U=m|oZ*TaEDffMXMlm+9b&A@LcDqPct#a@tLy393Wy(Bl@&IxyMel5Ztg4bu33}-)sy{Y5pJhqa2FrdhMGw(l4-&j?7j+*@(Z3aWr$KsWhX*wBdR4#@ZjaJ_utjyApaG&)j^CO>Y=RGq(7OP5I&APJ^T}as-`kc-po_X{6_dA)E*43<2)(mtEtaj%@Wy<cG-=kRxR_oBCH528|B88ULHTAU8gx1oHv4OYUt4t!m#d<zfw9#nr?zROuZ*1-P+IVGXul|Rdv?4}(WYSt<}`8Ut-QpZLk&Wnfa@6eRIo~8vJaxgV_+<WBh@RnDcEN4gaf<FP(`7`L1k(YABb4wJc~fCt*?Ip)WA}wQ>s0?_g2jrG+s9u%Qb)ob@-@K&{%!_>ntm(xMPjZ@~kd~IjirU`Bs<_?TmRugUFlZ8H(vB(dA^wp-0dWF5={@!eU?WuZw1``^;5YN}S_{{tP^k^zx+|%hMO?!FYUc>%oKVyLay08N*-s@TuA&<Dl0eTJ?+PMR}Ogp+UzOj-QV~-Wp~p0Wy-a3;B@(Eug5$zgYA4?B+7pb}(5A8^qx75uYt)`6bK_yl)#0q?(M7JLF;Vv-<L(3|5K=7+gkvAVQ$C8kBI-RoC<-vepIg6qHAeAw5g&w+s*Q9(tI1L8V_>ZHfxWrYVJgh6#i}SvpdDqJm<<NHH)ZBdB+1Uu(CCb)W^=xbZQz^@(1V$<@$%ZKgwgW`-R}HPaPs-q@O1tROAm0Vaq#*S}!*t>p<T=P^j<bVv(=>7^0;VF_wrveor(xXcT+K$#0x;!w21^CDApx~iaLqF^s7qF7Dn;1cRoM!4711#Cfl`hQuxr5^`>IXpQ%pz~5g9$L_)aGB$2F`l+UdzZ!MSZ0ipF&`BRQ$UcRy|`nb1x*>=PgkVo<CD(KQ`z8?oC^;`Ff$X6Q%GDn&eG}yw)PSy%@8#$>})|wRmxU(dTbNBMRkV?u}LGPiP0Pns!4`4gUF!b5)aiyXo(LW9UeWMocNG}6ieF{150hZ;CddwQpm#0Hb#8OOpC>N#tS-12&_pZz;c6;n6rsqM}YG=g2rt-3$N`|V17J#GI@4-AXLtMkV=H4mgQtX^Xv*TX0%4#rWaH%^4cZfq4O^24)70X%(6E(&CuwJotHS4AyJ4w_Lnr^7hCdo`{n2ZKouUvJ<uuzfl4sJ9IN*eGCA%<-BROtyamI<BKGJM$J*+VXRd8tHGuF}W{YMY#71bDlU8GBj(jJ0<uGj3`PE1s$#udklyg$GmyQs)CX+y@-<UHjMxZ}$#5<`0G#=nF3_QLggENC;dAP5>^v@m_l?k-#`lV@urcNGl_GAGD$0PKQRZ7f)q`xd(7)}}pbI7v#B^|$5jG_{5tT6g5ntQ@YPz0;h?KK(nb-85>G46x}{ZDE>oVVOV)+q77o-P=V{(@pkqMpr(gN0GIAVQ{$9NaE9bUU#E7XsE=06HdhJn}bg9pgiF!7t4(piwCtzW(B&y0<+>@)b9Qz19L~cZll+XTvmaeq&1y#-U7Rd%0yhzoq;ppbjj<?YsUuTmyiP(Ks^){f}_=eS!8|q{!BX#~{+Z>H9EQo@ID!-1qIfLqxy4%91t+=B#m%%w_Mx6^m7>6^w+abO194JHKi%YyARiy=?Ch@|x#g#87O6x}eVK$@53Bz{oM8!OCT^Xyjy*+jmpNpUgx_K`ZCkH!ulX5ixrF*+IYM2s%dDOD1yU&Ev?G_LdB@OrKeLADLrX(&n@BLF6$B>UTQh)irfeo@*rJ94)nO=PuedSGsC35NEhs7U)$2E&2*re96WIE$s~3`k)z$Yr(w>%f?GxU6@nnUga=;YD(aIv}%_{QGZqBRC}<}i_46TSXe<L9D?vxW^*}<0!;o2D*RwAH0&?*IGF(p`fKvjBRwxQJ2v#g_I+=8fB+VVb5Rm6q;)V@PS678LTB@f`lN2s3OGVP0N=PWsM_InjeH_mke6lZF~)B9ZT^iiMaB98C}iFii!_2ux&>cChfhE<Jq(@pw|;((tp&R<=~qU0#ji0-utb_pboDtqX+N;*O6iwY-X)kA>!n`lx+C&#_|@bfz_lwM&|ur9(<0T2Ls;5qw8SUXRA?3;on&G#ahUe(Kh$WrBLuIk1|7b2TZKg%$v_=;Xg7u1__;M)V}nh~*SaLf2yBOc_6p9_8Gn!Sq;D3zk7SM?_#3NytTT~sHoO}6(y><mC5$y3{AX%Q-`a)2L8%!zTdz@Jgwua0ONFuQkd?mua<`AYI0}C;*x8-#9~~bb98aGfJUV*z&C%dxG=iQ7_Q1xmQ#Sg5{L`tViWO+hd9r}50oEglGEkF7<RJ2_RX*EgjGY3)hBp8@-klzQ_x0hUBa}V|$3;>OA|H|X#uwv$e@|Nvru$DOKTMw-JU*q)zRBvaFL>d1<yqXRQM+>q+JcR%TbkD3l(ggi)#;3I<i+0hOBXNb(1rcaVtT5_p-1db7uiC4FMtI@kuTKNwmHy7Qz#xnOlnvhXHBi`i7ACZ3~1%_nH!PP)_RD96`oH{PAAi+-#vSDWY0&=fVy4_h1W^-I{qoi>ft!vzU!YxB*pi#bN^R^`LFDKW~a|g#55_UmkbjFXAZFNgyB&`CyR9afc|C-Jt=6v2L@8;0w^SU;NWVuXi}X%$u70@$wsaa2pK~NiP<vAY5qpULV*FFp;6hklT3fW1O^vi@gCpWA_}cF931iR_n@ZFNVN}(uAtKm+)s`Zw$2TXHLR_yfI*Sswa*bF0QplsCL8c>2#;R@5`ll<i&Kt>SRA0y4HyBxeGWoPf>H}`y`->jj?Oa>owyzv1N`68j`!;8tSrtK`ikV$0mExl2{DNhV%o@HVWj0ucG8NCAS+&XXYr6;YIJ9>KE(B-5B<jnPmfNIPUL9Sw8a`pNFc}ZvEwcPGnXtC`*x9kfOys6$fd=bAz>J%Y{`p^zrx2<ojgB2I5~KBI@zBbMeE?!Vx79(^3|8EpfbK){aiHccXE0>o$Mc+oG@n@PzX^mXmvfA0XHv{z5+VT(Q=F7TNGKOum27AJFfMS{T_Yw?ZN5c_tJB_&!e+fnzW-%Z=i=2iwlui>A0DkQ`p1b_Xc5yY?@n)geu$dRiCRuJS{O|2!kIC$0**S&r>{bUWs?kA~k_VXP}>2j01}~S^*E;$B+w^W^DA%(X~L&8ZJX|dIM-PTQ&<*Ppk9mUn@M~vd|4EE(n7w<kLuf(=3y`fE}3%QNR+$L9slH)J3l^lN``uVFoCx0*fv+QVPzSi*mv)hG-yMX|A)V$-n~|4JtDky8U3Q7!a0J9PcpKpn~AIQV{v`6eB_$_~<*9CaXGG?qS<GnvO7P$qMfYg^Hxi0O%R9j?LluL3;fQA1nZT#Gy^Qbo`f)Uq)fi>@xgxT#$<q2Z=a;3m)@B>);*d`X_dELn@)K;(u*VAW!h+V`_9@ikxI`vB>x2bhAT^Y*ApzmTd*tImQ5GsM6Utr$sZn@P7aIMx$Ma!5jsDOgoc&b^+3$7x5ysAD0X#KM)K%<1re@<j>f`0^`$kCU3VYgO4{Ta7iJG-YN3<uc1V97k4Wkr$L*%N0XS+ZU*EuXr9d1cLkC?4ALlzH{!D4$pzT{w3JD+y%`@6uYX?tvWh1X@oJZcTQL3#R>RhcEO0-=m?VE?;)#`LuKxjYa197TPYfNz0^%Dl91y9K&o3y3lMcgVFZ)~q_ryD!UE3-}KWcsbPizPlPvUh6tAt_;eU5@5o9%$jzF5sQp_!YZtP;}w<ANMYqfPqUCVYxedxrQONP!+Y5;=Dcn<AN>%^F-J{YT1lZdeZMJ;lf5t-vTlmlt%5%15u%_GhZbqDUS2NQneX4utPo5n9;yNL@I`y^H=pFF*qTl3GY?-^qf-W9c`oH#b-hq3*ncH{erO*|I>B%@s#`jJ%MK41l21F~o%p@wkWyc3dwPF^mtCZt4$T45dNOM9O7MPw>NuP#dl8fv;q1Vm(Z|rm83}Qi!pK^2enX>_LlULXl~;htKq4<b$(m;fT-4Y{@#mRK%hAUUGVQX2KPbw!bY%lGU^g(-s@6XN5vb8j!W+`Y3CahN`__-M%eURy4NG+byvMJn6*fb&SYbX3P_QD6?8~qp<RyKxa*rECIS#7Aj=8@M6fP<`rnwv{@C{I!gpL)P5TZzs(XnZ$X}Lz~|Xm1Xf7~eFG<QEds0X{H}%}<G|LDM`U?J(FOAinNDZ;_GDbkw<<DQAjTlrP}q*kXKU}1h*-y(+4<A*W{Zw#T1;z+S_Q)LIw1{l;Mfjm1f=^73<8-;<KFILeb8Q%d2v|?O_0lpVG({LWkl{KX05)GUtM^BFkf{ydK3N&9}T<1#_9K?tO8N+P58Qly;t#fz-A8F!Glp{LS0@F)ABx#l-JlubvqatrtL8^-)JWGJkuxJEiDAbqX+abdBX|{Rl>y~jpKM<Ip$5g-1@$Ba73n6tTMA3!eeR2C}viDB>|4qS5RP$9C}<7HAz$>D<HkqK&bCVR7xkQ_XWFz0c^#0QDBiW$7oMilXBTA$fdYo=&iA$V1;#Z-3EO&!$F{5Y`wIvdxW_$btM0|28=8=;{E~|&%PlU&&FqmBAv7YYIa_sPfb2U>2J$^=o9K%nA!nkZAZ8-;V`yeI_T^K&jOA4!l(yr?3npN44FdlG5h;f&-CoI6FKeYuW;x179BaOqx_MEeW9n256G-Tcdud_J;Oz0S9tNt9R<kF{mMAnp8!kEC6&VUzZIf=ljEMGBB{`QL|APf4=?o`q%=14Qg{I{>Lm(v#LEk44CSZ_!=%JV3fW<jUjR#IF=^znV6*{5yg7kVLI-i?yaT05pSyQl2^q*z)>Jj5LCx5UF6!fC#z#M}f+P!?Put5>MtlVOy0qxM!$~qMtkR2faoKy-aWC93jvB8zr$hcU3AbWyWLcQJZH1J67!Q-ThFC1Mh>T)=zLNzF0ATlmj0_I|A^n&!gJPKAebHPMgaPlJk(5ag5h2MO&%WviC9Q*5zjm-?Js>xoNuHqnJ^ZkZ9<3SLdEb$JT#&?;GN%;X?AxB?K#XS@t4It3xwP0H+b^Z08w0{<>vhC&6#2^GD<Ox~o?(KKzdd*h)^1EQ^Z<}~$8FsO#M!D8{{Ra-Ztn{i1dHZOe6~yqb_Fhs4?P9Wkj}Bh3vYLL8J5Hzds*lTIUF?H{}Fg;|84}esM`;!=JuwWBhbGc+Er&*`=3W<0j|fpAyQ*5ob4S}E?DH~d}vj&C}0|-ln{ds_{WGetXU`8th0xs%-bsU!$mf`pwJP22Qd~<YtQ895;HpkYv{aSy#^+FQIl8C_(p)uim---5$_Q_IKIrP3|N4rXW{wAK^fN5TrVw+k4QUlB;U!&F(XB1xvImtaP7wYd9x*hNF`)w{3u+Fc{>%NZ}`MWn$&eNyFmMd1mL)~{GHucO#?#UlKzi%h&LYtvLOx>l1ztM%;M})3(9iNRhpfVNjab@q~yXw2O#Q=7NnU}))#n&OnWKFAsin`8uBgafKVXc;-|?Rc9#aWWb(ThZv`Wv?Z_Jlolq7At!_9V*WuP*9-UL(08a+CivFrJLz6~mOQgq}P%4FKbkwOwEWk->)`pLhH#4a89N$&MO(NVIOo{k$wgAFAg?$+cAAnXAOAYrSmNPYbJcd8BlK4LpGL7IJIba{o8#<h{$FqB&aF#37)G#bDke{siD`M^9Y*GB!=qy<(%IpKL#O0c5qB3B#d~+m3A3UKCG1q>FnN=8Lfh|WyF>05Olsgw{r`O;;wI{=dNwCp>T=?wyKA*x`8D<SA)P@g$$fuq`uGZ)v#Lrw0kTtvhZ3TO<O+iQ2Z7)3-B@Q57&-y=bnCAM|w4lUjOI<C|(q0rLsQpQrRB@1!&KV3qOfH!?Vp=J!Gu0ag7M7F|cBs&cP&DcUlCZQAR5+aHKtewxEa?Z5y*o1%N|r#6ky+UzZ-qo+5VJN>_PnBFf(p=6XYd!(y5)27HKSAtgfdTM&;~75MkmQI-gJSDv!+Ur;3-^mq374X)@U^|x%qni^DIkQqeSy}t4U9QlljmOY>9sLTx^m3YAt>YS{}%|8;>Wbgm<dI^FnVeHxBD=^LYaP+2LaaE^Q#@5qQj!_ska1WF^e%Hym__@XPM_4WRpx@i`)GIM_Cg8Bv<2wKZZbN{gr5*dFh&<`b$$D2We$1_rP+fs;Q=fVZy}MeR)k_jz>lOUkgA=^0&|upFgh*jP%`CN^D5_MJ}C0~lD2=ccxr6$|}H?{D!7Yn7#_5Poy7Y<p`}vX&Y}!@)LLKthLhej0g3-X2UKs-^Bbob`UqHL@D#p3$;lIpHE2pf$(R13#eHHAAw1H}_$c7kFILkFJm=X-f1Zj0;P1`|6$7c~UnLDNpMTH5<}=!e%<cKK$=)WNVyd@2Rmfwqm}K6O&3Jzc)I0){vzPjdPky23Nec(x!3FH6Q=%`7Rc(aSB-;V|jxefgjog1?bI9otQTXyHA+!<d=<<Jkw{H`RMZDv0E_q$b<0Q_5^mL4o|b3C=%U9EW*i)t{i$cPf~$>`wq;2FFJ=@4$XZ`6%Lyj&|Jmw)N2l_HcXKY&-?(GX`4yP6FqN`Oifch9Oj*`m-pJ2MbctBQE`*8*_7!({5wE4ZTTSE4t$u!Dh>OkG|sj#c0O=<L!J4o#tc~hSlY}+lEsL8Y+YO&Y+g-Ogr@EXxG|WW=#Wbc+6Hg$Lx_eODW+>6|2@;pJ^LsNh`iFvsW7ZIaT5!1)tD!KhS4B*tu<s#uj{LBIj$wiYkMnsb+#O^2<UXypexOP3Ai5&Y^(V`kVee7J?RQVM-7pAp0IX*r^JEnN<_YMT^5aMmg@SSId1yAHw-$X{-cxpaa##(45mvGN!OF*e`2>$^arN*KXHU>F#7R>v1+nT*B|WgXDb6AouSeM;sjcO2ljJE*p>I515WV1M|=iJ<-R!#l2V?q{Qe<r2Q|Y@5EwL`C!k6~Y6HbOFVKO+C6uFhyOIyQLD53B`zA6+kEr5<>8=eH`7rze&e1!}eqPoG>>3i{R{ag`4}j=OiJU!*)&uxqOrxK1&787_I{FNT&=@H;%Ts+R4vMC6UBUJ|<F#VdM}N@vT;6NBnr40$7n0?~4c|K&K@IFp$D10cubZP>y}JH|!tsH-lJQ5Jna+q{;ibu-QL{J!I`lk2>V$Qc;8dCJI0N-Y*3zLwAHizC!XK*Mgqac*B>IQAZyIf#eL{?9)*2Ok!#@(Dk}=gAir8Vxa(*I7IUTvQoHD1jnHa;^*m&!`X{%c(lw&?A3mv-+XUZmol=k0)r|C$P$w-`s+;E%|ka@M2k!VOd0b(u;Y<@qsJycomBiA_B9Y+3qpfN_Gyo<TXT4Y_m%7)zC=#4vrGt)<J(0j)Cw)GoVq)}>|_4shg!sJ&11!z<j!=j<-95r0YE)<J#4G{J-(FnW7@zi0XCOs6VFYvW{`in1QxmGf78#N}1_fd;^?nc&FvAE<p-0&01@9md5skIcPFNe6Wao3=Vk<{EnO=4&!bVPAtu=K0YGEt#_9QQ)*n<=J5^WK`O6c<$Xz?#gtb|-cH-Xu*=lX<J01x4%!CQ651((L<vxHJX)t#Ua}WSyG^$u8m_VD^%$E#T2NE^U)CYCVlJ8?<!n&MT>&P1zO8lOFCTD>055`$jSJ7(UdCF~)W<OI9GBVpijJm|U3S7|KhI`oZUF5cz42wFLSO2G*94Ef1D~aRHNUOpHr^iiS@p^L_CaW~Qhy4wkcl;2i+BY?h%>k97jp%VS)I!=;zB2ic6ttPT6qa5*9`u8RUwrECdnVJotD;L}o;fi8W!xJj<#<pgtiz<4#|!i=j`@>5=U$4F)?vuwcF?KsJqGw7xI92<rCL9NhaY~uuNz01}^aSvsBUpXZZW|0^K4Ac$9t)A4dX|%Jzx~zGvyV84fc}Kafq_mzC6ZT2%P%li0x4*lL;Pzc8#)O{&t5|DCNQ%c8-P7sN5FIUTSDcfO8L|l$Pvs|^b4ljbOx1^QSR1tx;DfGQV3fdPTxTmXharh3gD_b-v869$aj+Y@IUY2rtZAuK#TgoUVP5bo!EQ+H05I&1NkwR!@q}$VUtugHshGGxd$GQ-%^>F+-uNA;Z;Xy!Tg=nl;x;K6TXQMFT4kF!nf>!3+A}uop(LpS0r$r}$#TO<9N5cmq+Y}FmjXPS1H7Y$6fG$_h4Hfq)&jxq-GmW(y4k?YU(D)4^==V@e?g#&&$M+kGrb9>pMb#KP!D17Q25zaU>P~gy0ezL1#6h#wsd4Yth_Xe8-eV7<GBMr^pgAUItXA#lK;=A0p9)@@`Ju3fy_%98Jq`+Bxv5D)xR(fSk{|VpHpx=ZVDb!`S8|pG<V1V6=HUyg(q=E$G%>e54gzi**I!!n2x(8_#8sEF5c~v;%S3CHNeGMuDg!s`hw_N$)HJDGjAl2^#YJcD}p+kT;LU=&i7p-t|92Q5fi=}l93fX5xT?!n^%_7UeWms%Eq<<`t#1)O00uUKo>4=1>MhKr<D;vz|o^OnO<>Yo|V-ns{AlmYax=`2^6W=JPUl=S|^a`fMw5Myt5b7v%)jUFYS#g8+}<>0*VNX4v0UqU3oY81dcYgAwj1JObKD&R$NDIL#*j3@RszEB{mBw=gDUlXMAMTzP1R2)-<Cej~t`p9Mx=wFUe47_Q35sAZkj)40$R^3q$t&H2bpDOA8x{L&5VZNE+noVlqcQj;!WIodg*u_~L?Le*If}&u03`QC_D)_Cka9;4#5)(KGZtf567|s>oAI4=BllK1=l#3(CI}vXR;j1D-vbX>b}(KH&FIZ{Q_lE=go=BeOUtuYbWH8cE$4sMm)6gj>cd4ZGWvvO>iNIVXiDCmkyfKeS1sjNt;&)$QYVv>2@&=pFQ^grV-lyOHaYnpWI1^f+`&-LuC95JZuW7rBXm?<>nW56}CNbH=gt>jxtRS_taz>~}W39#gmO-zQAn+8%H9AWNWlFSewkDC!OX1morP-?53{c&_6S$e9S9B~S650tpU9F+rC2)(vCW-Hw^GZ|#izF<`QS>?$d50N)e|Mqp<=tBOUkq_d&Ei4JgGNTLHiZYL>#HMZdZMDKE`*+*<3Hy(tu9dz_Znhm`Xd@S94ASl|}UBdv(%%hag$_xtbVW0GIYJlRdrD*SDb->uY7w?+6y6eqVjrk+OiK4n@qRutwHszFx`DEsF<-y3a80<9*JnkDtewcC3=a@6F8Z=KU+7$;r5y*zQ_~3QF&;X}YvTKv4dks?V-;3`Vq-@7KK3b%m8!+Q{7de{{hB=qUI2pInabV`NqV#%MB#N{C;2d<#c;6%yn(?U3QA=4moqRn#J$N$VO`3|lFEIlapB|i?PB7OCQ*TxKi9|mnc`aWe{E&06)0u{DfJCLj6O+hx<kry0bTs-1FrOVgJvfQ@NPv*VxkNFL+R4nrcE(uTlzn3u0gE9X&nCV#%#VTZDgD)9PiZ5ESONuIx<6^URqt42I7b37L7E<YU;hJXgTg`Uf&$AcvdUclJL##tO@89^*gXk%A4VLG6EL<GY%NGS8`cV@#pEMHL(-SzGbls>T_Q#7C#zU`H`<E1V5*^vIPfus$I69H!>^c928)M0gN852fKpys?<Z4o)U}qrFyBZ?-ZJuLPwrQ$I!(N~lp@?%Vf>P4Fqo2fI_3NwY2mDAwpd<F&&Ay4iGLO`uO$x<Uw<*>J&khyKzGEF@tIjS-MRCYUKpk^J<C=$5s#72*nyaE0vd}L-d|h$K-3=dO3z@-GkZ6~C)SxdyqJWjBe+?_oB(0>VqW7t#~6lN2_NYE=b?$tBCp=vsQ>clp}9IbG5N$P@Q!7ho~xv9>%3V;?F*%?pKo6uy{Av8p52f$VS~O~-vjpc`nt&;qm$LZeC~Ja6&{0YrM9O2qPfiEHaKS~abbg~?ve$-Xm`{`zdB<r7kTHD%=9AXLSF4AGxjUQj+~UzC`QIm%TPcyxj7>?s<{;VS+z~OZm3jsWI&_*WBi2n0%rfFwVyF34`WlTe#z+fwk%Y-Sho$?R{X0vQFnIp!5rv3A1<7V-DEM>q$z=4h68%Ly?jANG8`1;qPU!*`#wfBOIR^{l}skG>S047r&-!!2!84g%aNQolx6E)kP(63%z!uOAwL7>^|DZZ;-(c??iubFf(znuu?HMw#=bL-Fh?ZFG6OD;OKg$l7qq=o_JakchQ}O1Ck-`>bA|D^R?w3CgJ_!r21=KLfEIE6Pn6jbo4kKmHh5Wp^X}%;E1L6lccBrnc)ns>3HO^%7_Kn*0|v59jIw)QyqC~Rm`vrOev;V*AD6S$+3a7GSh=qs6J%1&IpE15X26?dHIFACY2;d4TWr5b*RnPt`+!E*Md9I0KEasffp_w6P}7x4=%S;J5F-e}ZC(T|it9|273yr8eXSXJEiRkbqBpLJ*98#PjlI|_*nYuuFGLN}o1ovhfrPmc==-_`>DpQX+fQY*>)jBudlsn*#6NGNVG;=P`wS_iJun+R14^be@bJuu<<-t33_2-R$QNlb^6l(+iImxF!XEll#Ge#PvWpHoD*YYQCAP<rq<^I|F1jbMuf~|m-`%+@<>$#_#cBS;>Z)-R9(@zcPe|pYfC>QpD~j%t_=O;K!3`T%Mb{!BP?mw4blm2oWzDIdZLasY!R&DMbcq07dpO|@$E(vFR&V97SjU$A!8-`xB1ZpdPSeOI12!AK*Mi)MA$tqfqHQ9~oo?gXY;8pHqsjEi!Pf`R9!<D5R)+r%CE<S$O>EJ1_nnfS8e;7ArjLWi2ZyIeC$0mM9mPh!z6V~P@1ZMBjKRwqn-;4?Ypw1?VM~7gGrtZYJSiE~F5PLdoSNnQ&;|_4%AeugP&7Yetf7FgJ*PF{kp!jV5<mDQls?lXCBVb06F7+wX0@hVe9ue0D3Wwiy~$_ntcgy3C3*K@?t_$i(VtVy8|Hh~>Is#Hrnpjl{qN{>pS-2iKgAjAGI)LbqQI$NqJBCeevDrJ6`hg5CXp>Q3>eua2@#l;@A>59B(_)KVW!U-M77H-CC>;PFm7665TKh6{UY{uQUXp&_0{vg4;;6Xi*6{u&fbEFp?7j)1IOwW{h97p=GNg6pU+p6C(q_WA9+HtJ#+9f1AnG=!iz8HGNvr|FS+vU4pm36KPf<8p{=K~Lj68xHe3=9o4V@;s1Q}4@P|Qpc15I-rF*w;w~Bo)*B+n;4*cvyfZ!mVGZgwWSxlIdep(mgCNu0i3&hhXNr&5a|M*60miK&$1zEeoFdX0M5a6ntitDmJ5dKEP1;rlI<UiK+?Bawz#3#)R7rA#aJ*$AekC!?42--G&6yj}Z|F(|H+Kq_-QZ;A8Fh4H|8rvwmO3MzDx9qhzQ7A^_z>kMG2a&xPM+Mh55jC6alWb>2D(R%A_Kvjt3~@Q{c@C0?ObJGuBwL3~-%sd{G3WOaozG2v1PS1WeWya!Ava-qt$QK+F7uoDOl2wMn=%RC9Gl(h*Z^eFxz$F_YMpy!T7bXrwzRN)H<xtZ4;l(8lV|Q6M5=NaAmLAVeQcy|;~#Q&lbh1)J!tOIjo|vTcM|m-&`&D`F;TNO-EQ^r;hl+15kp4MR%A{9-L*?D7qB;5fVJ+Vek2^o{oN%4!T!Zu759Oiv8o1Zq4IB(`!a;+GYm><fn?--+-+)L?*D_}`V`c@Pvf2Q>T}*G|6Uk<3IU)mgOMc?uaA-6f7Amc(PkAyuzBk=TtIv;3=<}2K=W6tyY&7xDKWAYN$$_aZb$YW>#FBM7sl$8S5a4pNFycj8n6Xi{{x-k6ElVM8ssbBsR`-GOGGGsX(+qx)f<u=juiXw*Cs(I@)LDuSK)0cu>H~X83hL0VPa5S&Cu4Fut`EoRz#EKmm1tpY&LV_R{@Qz%In`K`2+0{+GaDxg{LKnRYj$)psk7{@5!wnpruSi*S|q^>;R2#7#grdwyRa$!0t{ll%-@=9R-rr$WZKm;Be5wTvFOCzL-E`!a^fD(Dec(&)-P-O)4GaNR@E^ev4hpmtj)tA<0!Pl^{=Nk2iyJSl}YYu<bK=YKziB1sqfbUKgf%U|W+Vf&#I=T4km9fL6_d-9d3`_LFj+bdmwPtfK3r04D@oCX1rH;g)Y-Y}*Tk&|&{&4(6PJvgixomQ7%8kJt8cl;V6y{j>6EWGlJfjlP5_CY|=>Z(7bpMsR~ZM>H(Tq2lAIPYhrPNDjC&wsL^QzBMQCsDx8{)Y1|tN4-(;rZF#(*M>!oGgz=^NK4jF9n;7qGcYF3Xi&Rg@)B+iE8K8%pAC8lkc_kTE}Ral3wDXV3k|3t&y`)K(c->6l{nS*qrE*G6J2;<<ea+vvRGW|Mk3lMCulckhMVNQJuYdz#(@J~6~r~lWcJ!Pw0lAca=A68a{AVC<_WS4`w8#XiO|FpxR)2kQLuQu*)N<r{&l<M{L_DrM949U*DjMxnkDo6`nRgah}Kz232j3LYd3%&n`8l8x>U<1rR46L8$IH`;1ly2*`oz}KnpNa#vYC`YajEl<%%l4z@jl_M?&3*oR`;qvVO}lN|XDyy0E!I*4i@ho-xTCYD}3yHaTjAvk_JoYg@tnbKvS)!kC>8XM2*w?a#iZF>9wFGYpCwxEiT9BSqQl_D+i<zE-SbL;6{qC4W}4_%E;##(%|s{)XDsyi6MYL?Ujg=fkUL<bJ&If4rsarj{v&H}I6jRLFtDttisKPOdzSMBr%Qi_}^S;8{w(0{iu6{*HmK2)g_6SO3S~IA_TQH9no4OHw@B3ZRz?GlF4AGHLXOcn2ovV<7O+HDOCY6J8cSy4z`k1)r(q8je~|;Da7gsdu5HEyA(M%Xc{N*H1e_@Pk)^X8@;*&!7Txz$Z;|QZ(gEqne#$xh@?$RBo<N)WhTov+Li|jBbK6IXVU|$iuX0q`HBZ?%N#YP$>Wq4;+D`*lW*DiBZb=J>I|P%TOq^q0Q_vVPPs2ll}&^=84>4{%{i+g)OOd_wPN2?@6hLjJwXl1s=aF)>b}gmLLzl8FC+dyonWJzCF(pdqUd<KF9n@r{1-Deapnk)(-^+=T<5WQPfs|rr>(M{@^XDNqf5&z}0H_4EWD}(Xh|`on6^C=@SyB{j?>KqBCIM|C@3c09!Zm|LrYVS?=mCgVJoi?ovpY&Xu0k$JyLY$NCEmeZXCl`1U4dz3%czH}U35#ei3b>^*W!3Ev&2-X(VQHb{|-x&0p8$2-liNmB7J_1v#?DT9X|uVcU2u653C$7`fsPn^NHUGJ7bZkBpm$Czi5V+yIDa%5|Xf?2Bn$r1$~BuOj_#uf8iaX=+&g42p_qI5Nrt7BNaCiei|c~#Qfj*RX|KCnq%bSq8r`9f2TV=6)?G8^;E-(t$C*}8(o=U=ml!1H}@9^OZ2yw+2`baQG9XYNWCW%;!sHT(m-_@m{6k73{ek9EmQ>EiYl?*(KMk3uIp!-iGJER|JST;*1h%T3|1-4qn^-p?RzUdSae=I4!f#02i*L8iH<Oq3YCO&59COmlnBVUgFT#n4M;yS-&IyqVlqH>RbVS=4mQ=)LIM+;BD4<&8_seMS8(7SxO><mDK*4TlZk?T8~KcU?Q}0Rsn-)Vg^PxhT`K%<V_tzUly2j~C`t@T+wJ0lo4rF;zEnE^|k#so9H=4ezE%qr~8=wo{N9JASjCi7Y&slT5r=vwc?$34(2j$|Oa@YIr~|c@<f|lA{Ml&Nwf8XUcmHIecCA=yhmkI{3YZA7<P^yyPD_{xG9`Vdn{^sP6zoz31#B94@yVBCyZ=(MC$g60%|DC2*|Z3}XF8kUMw#j3Bm|Fj0nmZOpS4T<0Q72QGppli8DYo<T@qw^@f_D~S*xp2Zd|D@UJ(E!}cx4S)Zpu2;tN_3g>gvjY(IQf&dTfqFvr&TzTL;^;94TJLz$*y08oY`X|n9x^XBy_v#8S#(D5{vczN7x+h=kWUg@O7KRGbN&&x&l@@^o<l=iizE!MU#`lGNQxJ+xWXEa>LH>Fid(-DjoZC8w#}mK{li4AUgs8%-Z4=yOgbhq=R{*~F@?pxw09rNmEXbFTL#hy(PnQx!r-)#9mJpTxCH%dtacWr)MX?&=W#hg`LufYX}o=2siC_OoL-=#xrf5ooR}C;I*M6G_Oxa)A7hrySA~PhTdtqj*<_W`o-YZ_+XIrMPZzSIL>D8sfNtGVr)25(+^F!-0Rt}*bk+q?)ExnM*9Cf47RqgfC0?f_cN0=6qA2JfS)P$Y)t*Xz_hpMo_j1KpJx5UxI;37S<pf9@ObX2AMm+yGeD?V0`03;+Ok!a?FYw0Xv@oX6#vT_(u{xsuL3*YXP##XM{~^hj@Vog+o@Lh4WKVs-*~;JfOeefmE@Y*#cV%r=JWcY(UXroVe=izEaQT;`weAQB8Zt8dnk4ep#M*Z<F|=aeo?MG?QtOpvjupUQ&mcnR$r#(VpbGcqqb49PG|ICr9PfH5ZxcC}{UVEh<ltLLy*qlxThrr%ljn!Wc=IZf{rKK=^6b&%n4a&;J>%95-yHrBTYRYe?ZD$s{Mm963x?%)1M&Qsy&g~r$@Q(hAZ%e9MX?HW40_G!gT^)iw8z*BLj{r@y>-jt#zyCEYmte#zr#w5P<#kP@9@CarouCk)26QhXX!G#j{LE4wM$N`AJ8C21-te?xKBY9_sj9QOQM}Y5WL<-HsA18s)2WHDqeT$-zPb6xIL+h)o>i$z?ch8>0)~dc1%<}J;Jj-Ae0f`V2jL0^dcCBXBuQ5a#8s@@y9oeL}H#w4tM%o&S*U@MK`PxI}0zViwEsJDG;AL29H<W-^NSnKWfoo4m*3Z*m!q({N2}wk7&tZdjq*BZ0o^v|H<Ts>63%Ur}z!KaaV&$7mR5Gk>tmti*x8<`{f^BsiyG{T&-s4GkvB#5A&83(K-V|o5s@wT?j#^pIzwmB%5OZmgzg%163#2vpPKZHGP=0<}6FJ_=N>v9T#Zxk)6m(FOhV8@vPjm6^b+<o9&RZ$vxpE?%3Uc+BtPkI8A`hiN<%G0@YrJEv{mkT|btsU@WkYH{z_f4mvLLMK~}V)OMGBZQ+Q=<^TZ|a;!_a<8PD4V#s8pP2VqW-O&08k8U(~g9UMpC9cNY#>nD{yzJp<>oC@4FLo($XqWlLxeh|!BbSEscltTNrN#F@PprU#0!@CIp|x;mFV0oTS(07Rjnmv%(!OuE%aOXw*kelpN4ApdzLTQ7i#9s~l>rd1wq%)4#8Z3aH3&>(@3hzv$<+z|d~Gm}f)iWJ@N)DK3ba<P!*F(`<$5~g{Csxf*OigQ&R%na9N5o-|C@e8=WvqWNZ;fzysoTwI)QUv9cS|vLr>p-yoUGs?0E;cxDBVBg9D;%)5(i8Hs{gqvY+7a3M6abspQvWh$*RzRf---UCK&hMMAxnllHp1d_T$v=u)B?ExqRR;!8Atqlapko#!Uc9p(=r<*q|M;<NpY?OPvWK#T%2)JHh=Fl-plD=s?x!dx!w*jNj}!B2FJyxEUudpvexr$Z!iP%+{f=4m~#T3Y~u=xy3E@ivWGxa)fK;yH1!2z6FwjhvgV-PLKqb5h0;=XJIu736D5CCGW*V(?ajnOpxfc!RxQ?LJH0r6dW<gtE_Ps|gk$f`&*3<;!v`v!XBtN$XOoOT5Vl5O%5GVw8NdRD;JwQNtQo4JhW1#8RPE#=>jN_Ltg=&tyFC776S1`3>XZ{G^q)uv;&nKSpGG=E8C#=*B~b^ED6f0$PKX!$_`2Vs_^iJT_bcDRuacHz6?BEq3Iu0{P<yP16coCL9$)!wMM#?F*H|z%s`CdoTUOUbtsC9nP8rIYg0a2knyT&UI{(UuOnWx70Gms1lUA>}xLXKC$b$bX@y(?9IL&9D+VznYAPf8ZXNg{xPqe#I-PfiP;|Sen8(H1DyxMrxklN-)yjBAV)mtk%1uUnR*ku0zCAw;R}W&DB##+fe*79oAQ{*Q8~u;iEAj(cs+xkEfIYvo1?9aM2$+WCo_I+IXikU`wW2|hy%qjrOcPIeE5m?aW{%u0=k_*<Yu>cK^XHd&SJ~_8hkfK*floTn<p6?dGFK`PYq%6;Ya2jc+NQaBJ^qRh@pgL%*!_Qsyy`M6E?E>AC1qu+rIo+2Oj>6LRS*rq|h#EG<*?Iv#Ufc==MD)#SYyyFl=}v4|QJ>k78+lLb9ZH4x>42%@<cuf=z5Lb~R*Abo5s&Guq8H%fyF|MCixd8ijNKQv5|yT~I=}^2dfV;$6};&v;0aosr`;9*QRmQg<;^$SdFONg39yzEGT>FS1<6n>`8)07)0pThw4ofG#^$)BsnZ^yCXMk+GhD)S_D`F;nQ!f~!hKTA865g#z?m=5QZMGGuI^ctn}(j#AfhvG&-5T_OI7fPE=v0>MJ}))aa^wN|?K^?u~e13E*ouDkqTT{vd6CyLR7d{6ftWz|fK8s3q7|Dji)EPpOPTh1EY>l9?CZ9LCy>7t<a1z2of%HSWeQAjvdXMCN&5vbt;NA5-T)&ew12f^lL0h3o>|1*b=x4s18fISbxA^vq|JXYlS6XCUwOM7xLBsz{TRK&<E*au6i(E6V3i*IPah|&r~Hi`>_&Z)zp5&w*9B6I$f?v%Q;dN#0v;0l7yH3-6uB%-5hNm2uE*uZoDp$aoZW1;Y2P3+e-U{?+i(b|h2@LGgH-Q+=b1mBc&H}bBwk_&8|`Ki;C0a!e6T9G52`x4sLEOUu12w1ygb4uKXCP;zVZF3}+9J$W{u&`^wzJg05`NE4Q-+etfJ~)X5a7=XTbYt@Cu~UeSx5kWa%cQNFa8~hOU=(!Y&0k2XS;c=dFa8#}3whlLQW)$`XBTFB5N^U-=S<tU$QI3<GX1ey>hcmHkkkH1!C?=2BRUJ_lVIUP=I+q@5hg1#$&2V<=SeX)o&lhY!LM&Jy#MWu=wcZ9f-ZVhGS_?uuXutyb??kGxzlxWZrJLW4UBV`w6p1N+CV^nPJ}E^G4@(O>#M}`qZo)d;y}1B)z-F^2#gkP{ljSd7NK&mJVjs1kH9N=l0`v0=4RJq(Z1E5@ZWQ@{r>|;#N{p'}, 'tooling/release_builder.py': {'modo': 'trocar', 'antes': ['81dfe25d651be2629e903ff0c8658dd35fd2105770e9c7896f2609e1803b46d5'], 'novo': '0b4467e05ffb93155da20c9370a37a318ff622cf01a2e23a68131e0c424e0ff5', 'dados': 'c-p;v*>W36mgPIYA`1N=APa<IUzp7@V=0-L>e6PSvaG9EG?+)Y2N{_F0u=#JQfg>6A2C0WHV<w6+}1Disy~@8nR9)K4FIW>WTUEL0TI4jcfZTI*RMN9qtTzY#e!SsZ_ZwwS)Ns{7VoXRDwkFzZVT~NaH}r2RVHeSt+>V3>#DpJd}`gW`sO$-xAd^C#RlawQLH!h?C9v}a$Q!NVs$O++={Bm-_y6vO;KCRl5ZEnS_wS2vU0Uy*`~H$m+7K>XO)$8zQCK+GnUpf>qTij{mv@tqwB3eCwyj|zbk6l@{<MIa-myO#BFXwQCVvuyxi8u^@d#wi!B!A+XX7spm52Gl~u?tXGf#a=tz!qKF_zCZ6)S&tB{nVwN<%co1$FRM@RZuR<7Th&ouZ&k(#eR*X7E5Ub4-N`CQhjgEgL^xM}@Wr${Btr|q`jN2+|W0__XN%WAePc)?7?9J3|n7<W-lty{JzIIHFy<?5Y!=rX&(1nZir@J8&E!-r+DYI;y>J+I2QSXE2Eq_0OuuV21=W1ULk$C$BVf%%%uDp8k<TQQ!X$4aa=^`&!l^ycjK59d_)!)RNJ>M0+cSR==dydd%-$M;54YqVVzV1QaQFQd>8-Prf(<$A#~{U%NV*G_!fv)#lFM|VdTZ_a)=N88@fv!_4&_~z-0ALg&l-u#Fsm!pdft2Ux~wP5c>MGf^HTx1n7C_Vo(0~fLK>0(O*%vd?PYMZ-w`P1ts)WxW-vd7t?z_=do)R?Ikv&EKeM@RF&oc|3qDlyB-<r<SSu11&a_}44?V;?8;t8f1C_tE5Ne(~ekPC2}1$NANV(7%&~UZ1~ucJ}1_`T2`C7c`4U7XBHUFGO`)VCiUbh(1g(Ci3y%ts-lxYCZ+qR4gk+J*d>a=#{?^|J;gIR<L3D_C>F}?)!<H5Mk={Cr-cIr7Oo$52`fJ`&5<7K{-6>m3YN&#bQ9Rd}d1B9i9LCo7ZPFsbg7Xd^vh8){7#8Z19UsSwUrV_~QxI2n<v#ZXhi5{ETGp34`>M*Q2W`6x2#grk~Z+b0`-K^I&5al77Xra#gc#a}5`?Eh(-01Udpsx}gR~(2inJKHghE&B^EV_oONq^d);zRzh~uneOhpFYn<{>pLy~PPsRniYMQf3-P|`M>Cdu_!T=j&qc8*>tQ$g@mK6fu5?wBs0{jQ-!$D#j{e2^o=i$@>6X5+Am7%{AAhq1zGKGO(pr_)D^kZNWD!VZfBbJ$;H9y^W3gdtX1P;X$f^<_|3kj_EM~<MOIRg3k@Z#G|6N*6L`7FQU;$dG<!~%;rujHVKdZ8?@qg=WN&?04@sDWm6&Z}{ZGk?}&aJDPZ-+)?ovk*-b;WLr&HJhK^A^S)_K`-hhN9bu$;^7$F@We8V?gcf<8Q|cR)32bU<=GbWtCgV37VHy*W#iE(KjN49hI=9SZ$dF(1Nlca0aFQ*QXa}-<`D@d;DleAv~H|kM=2qN0Sq+k?7weJB@-k4!M)&q3dLs&x62rVxI*(NQCWiClV}kJTFWV-wCoHLP;-kZQ%wY3E3mXONOO>2OW4Wb=;63A!3&MUda4B#os6vVHWe$&H|n>k#Wz@>?}(BAaHZXwe8#wlho%d;}}MsemOx}PY&pceV)6KohL~Y@!Za%EO4_hN*(+!iPJDoeBbunD2W9NQ8o`^W_wW@g^q0};g`|X*Wd%na?i6<H;4j{hiRTVsTX58{n(8|S7dIM<Tg(-$BiOC&$7@75|-z#5PlQ~xto3&WpBhg=#>FQ;36KUDRXS#tRV4%Sb!?WXDs%jfJb5Cf`P)s$r7IBJoW9AxuMNil8P`F@sOfD>bygfQRf39f`BI>cX<{hoO3(!BN2yQ;E34E;~)~Yo8@8X#979|khz%`<aQ9*PRJZ5P2)@xA=?Ux*P_t2(=hPk+)o9#GRTvRr>@|BnE6qbr=gu?d64_Smf+#UWkH-JHj7>RGY5o6PuRNHY!{{N42H);Hw-*XX=FzUkL}QBv7ZKRk~=KRlGqJw-xGO`MNT5$%_0_I;k_)1Q{M-3egR2h#i|{-^%+Dojbl4tA_~)p2`_XL*AYChBPS4fkOYn^JZ{^b5CIDvFJX2R2+#Er;iq3f4^-tZ>k`h^kfbcIp`@Z9O(V|0>rTo7W@o-|LhdCQXbOEdw>=284^egO*!D9o#j55W<6lCOMh`nInS=A496C(+b|kn9&B27@MXn!&t}CLPL4QD07|mB4r(hyTL`?cFv-2)XlDuQigVc^=FO2*!O=w+h+s(7kwSDMtn}H*FDj@kRhB^Wlvk2?&LG*fUB?%P2okTXzTufA)#);#IG<H(k=P{<xgO$kgj7Mn8aUnIi6S%}~B1!CK?PObNp711%{m6~t%#T4fxG#t@J4rayk;mNBVRn)Wo<+GI_`(&81tG`_xF3b0+ZGoXedw_)P6IBW&4dFMPCVPTIm9;&Gv;|L^*~<A?G)1&CyB>>4n^lO?sePBy)^V=n+f4URcDb0$rUb^JjWzL9m2x+amdoh4b#9+9XEzS@v>NCev&}azML5ds17+a$Jn_?+6A_Prz{CV0Xr5XK6hQ;vmHNmlZ-(?z&8w<$B6@|A>U0S&xv?%va-yEBJu?1QNU1|Wj2^Nk38st6pA(VBB(h5)=R<Ui6<Ne1(D^Rlek=b0k^ll-C%f529Zmd@4)8x(8ZAxL)2InL0<-5m;!cqJc@mX2Aa7pb92uQVWeD)IuY#iNqSxY)eTit5;Ktk=j6fxM}hG|9>W~PaqcA!&jmOj;;t9Qo{QJMEn?SCz=O6MyF7^eFCb^1TQs0f1U!sDl9MrJ+mJaJ5}W%_n=B$T=0Pu{Nd^NIggk)u%wxw-+>}LmMr_+>c9etiOCuiw#yn`bJmoOMi61*2OMu}r0p$X$hpw2Dg$d(4$vs#29_L@c?9aEW9gG>-Fh(3`5je&6QmCjT!p!Fhffd+&&kw+!p#vNRW0i5o$3K_}mmG7bo6o04y5s|D+{}SW5fCE|wUc6PJvRaNjfD$k0&HYQ&{hm8)yBjJ;LbdS(hOkwa|qBEFy*UCz!gzZjUi%+T!A@YEEg`+P!uHzR3pzqn1T@EN_s&AK_)O~4A{j9QjWJ!Wx1a~O?^I5ZJ=eykG2>38FUdWCKx3E%!OJNf$u{d`h@2gcrka$Rd7+r_ZUPMS`2S}H%z{OB*4!1ueYm}7-BjoJrER#G)U|`g-Rs7$imDPPHe;eB`^%Kf6P||I2?Il9)Wl$I;hqp_(Gcgs$!cvP*ZpiL6HKC!TPW`!RUc-TtCd24da}r1j&KPSi*xWwIfn>Q2GME7*H|%0xb6Ta<$7#0EV!$%uO&ENyGw}VxPH~f*jZ)%0mc!>VVNAuu~j64na09JO?gc7-rE9HQktinv2~aLDxr6L4u(zaN*Rs@Sx%>_H$rjnC%>D%}L>4Iyt7y13Usrgv~H}P{1kdIBb;1!E0exy}^Ni(FBU&&>9)sMVLyc6+ndC25^az%!4J&A=+*%M3!JsXcWpli<1zJP)}955%amt{D{FC<s|y>@SFsU1*_<K8PDK8#lT}xKuv?_6jA{bW;;Os-q)HfJkdd#A<qN9!V}M6fpS14_-q0~#uFR75A6;>oxmTqqm*Sp(oPz{SOK(gAJZ!G$o`51%3#&dUymY}CjhcByeohY7fv1U4D$o{K6VfTX2UB8;KE}m0Y<Uj+)rZ`XQc5t>tR|44mJQ7L>zG3i#$65FtoA8SXD2D$rEudV6X&mQQ{CJN^KWkGW^FCJrl@1*Gb3+$q9gjA{1a4EM9H{T-ceD=a@y$bD?E}z=<)t5vC5}3xki=g0DDjKNMA&FT}gS%rT4+X4iug652@+q(HN9L?W7i5YA?rras)K2&mQ(PLu+k101HI7bOsgJv#sMDSXO{ayj%?5?~OP13D(;4?DKYA+|o&S-?}mA^=9hh01Bs!vtW%4`D80kz&H+!i~NreI`slWIor16P`kGfcqfD07Q1cAtzuLm{i!L!0|cO6-(@fu=EZ<J_E1=_=HNdyA0!{4#W%m<~WWE@R5Sq+=Sv`oWU^ru}2XpH;zP{0zx=obT3actc4KV37oGu+&0WO9Iux`t+6=7u;EhyFhd|99q{gQI8gZO35XC_KLzxLP6TtgIcKRKXDnkq0SPm}ZoH3jJLQDSec<#s%3#772ddzZ73kIs@)pAHauUe06TvOQpfR0aQ?I<L$|b$*4;Cm5s{ykLD*;sGK=pD+ehy%qhL`~?Q<l3}uPlON2RrJ+%meZY3=|^~Uy;Dwm4FK2IfaFyB((j&PMpw=6F-41f#!*$#0kPQ2Aq!JPNsh5xltIy#zh>?XO{ImH&|Uifry20zgZ5*A0}Cn<xxxq%=h8D<>2lNY9GEY*bh(xcr?cX!aeu+*EB(I#9{|e<gl1I7TjiFc!vYz*zhR=$h{3$+_TAeh9V1Ktl|1+KtW(p4(BDxV2J#V9=L0_0mM7DVYS@KPYa5=ub7JJXRNf6Z&gSf#dtw}WfKNpwsG)!c9fTuHK#4_sWq=}m{qK-55Ff`_!VM=pB)x@lrT5+BL{j&B&iT-POyh!j1h&B$?J#v%)vgM@EzOZS?Y)6AO#HI(o24C-;FEu2))9=rXhxK2pQZUpHzDex6)5U!~|9}!DQq)#0&nHlLvyVIv@}fpY5oQzgU<aL6rfU!HVz*{O|by2@%gDFHe~8p>lI4!f1W)IM|C6ROCBQ^ftU9pFz~Vl#UMEdK4xUhZ8oi48_hwkfaW*u${%Qem*Qmm_P>L3~~VpM!5_t28<1_2q?qxAKlH0jab&>$%$n4W{c)h^5>OxYHhabg&5Z*sN>^WY{pHQ*)_gtJ|0gd6YGCiABdmtCX=J1i|_w^e)jC?*~NKhgT7)g*z@eBpdH>5Yb0vQA;}nR%xx-B&o?9_a!*}-nlH+g+9Y1%b-k^MUu7-=3f!_aZH20a*Q~BfQ~IR&zElQj(EOYdF}UdTvKG~*l)K;0UcP+QrF)caSHFmA&I*}Mz?NyVlgJjVTFO@Rr>PmB85Za%*Zpxe>dE{w9pr4)6u(6mh1`6jHg$npaZ_Xq(G*&iaOg&NM@L5)bYE@BET!|RDyuR4y{(WR^|Fpeqcdw!W^4gnv)*nfi%8`p6}0h3Nj8kXw@5EBYYi4;=|bS)La<uQC=KZ7h>P4p=ZueO#dX7*>itPGq)I?ZtYogwj0)CcnF=F|&!~s_M!egM;kB2%SY4lvwwwGoHru-U|6!?WG0$in*=lpTzyfea$vRsBWj~iB&q;xT0cV?=s(jlS{aBU*XUY!5yG+pL>B|fGa%!~&r`As^C~V%FG&v+z)S^4Jqkp@2`NCq`nz#Vk9$nvl{0;7Pi6ycAXmv)sVoNbmnPQZ;V5TsA4?8lh%5pQM8D_MLta~hSxfn$)cVAbT7@Go93w%7GWmBuAp3-;OVbjj6sOK!L%f)sh#<KiqHXG6W49d}NSbg6(pHO1cO=)p~eri#fPD@Kz5SJxe!30+AuJLT7W|_uL$s?*ijB;W<ZpYbXLv;sCb%=6P40773-_~g+z*L|dtMR?dbyodzOGFd3b^Y<Tswlgw2lipKC9cMxmarlAsKeB<N6Eu#{U&BPB}?yJ&7N#XPQ<+IU;Y^v#C>BU5nX=ma^`&_l>o(B(Z2u3|FnL3^Zju=7*B^6JCiRdn}NNGHKy`VySMDug55JevXy2|SVg9R11cTlY<fAh0FyRyRq3m=CnHsPG_n40YN<52`$qkot%@A#wR{W+R-`5I<^~!@K#>s^BL=2)$WrG|5}Rr&^I`?tr*y>B0=E~-?ef&dNA^yBgd=8a`t>L~^y_Nl9GVVGS*$i-Ps*_zj8m6O%W|RKFBR{0d)F@%1=hcwYHq;?O^PA8;JQLHtA~1OG{r36E*4A5b)-Bx=Qz2dWV)*l_S6aPMpCaBHF>Wbk+pcr$xtlzsy`$D5Z3Kt15U?`=!Olg`qiH-*ZSrgEAXsi%Q-pR70OnO3^`VkS`!6Ulkj&*68mh+wr!tsbyWLit}@zQol7g%$Xofg)}yS2Sb<2wGm}HQ7p12bCC0YXiAN{*Fd^DoD#Kb^Wm*;2Z1eHIpmJ(MDVZxu9fd-cZ8bCgi+E2-kL6n>1o*0J?57RyTa!R_(I5?J4{=X!fS@4-+TiQ8d(5|Ml{hr(bVN<e80XY}`;-^g7+jY;fIK${@1;;x>f0?!?d<TQDzZ=KpxiM!7#i0eRp?SD8P60s<GyY+w36l?0Rzl##5>jFSn3w_`J{(E4ltvJPRlJXw;f6}qe<+fxy7V-Yc4aIuz7sY%<If>NwH!e;3CC*d*<i0(sgE0>s>LtE@{C&+_hY%gpU|ccXnwyy4qnwS@!ce5uG0<ddPrfmjO}p5{+CnM5qbl^<XgjM5xg`XhhPE*O!w1tKI;{N-@g9&BSQF229`9%Jz)px{iiLC}FgciSO{(;0UO)XFBVDv;$=a)d@Nkb*-y6eO*^Tx2Qh(G=7v;9^Cu!Hw*o)VEq{NkI8(@wr~sJB^jAHFbQl0mTl=GekMYU)X497yP}QAlix!mym`Nt4i5!5u$=Pi<U#6xgup)D6zi6CyF#^>R9;`U&xtR{2zF<bDRVKJ^lSm@Y581i*<9M8q3Kjc77h?0q7z+jv?>;(of2=VZChf4FS|v)XN$Tmlhe1+VIw_;J)2q*J9KAFi`PDgut%U?eEdI40h=hfK^86vk7qDCzb(q^o?ta5a$OCq@-A^C%`HtpQRFe6T8~DLnuo+1*$r`qa>aV<jz;nBRMt4r)&GcZ|M*9z1&MGMP0<lvcFN)_9vm*b8WdjLQ??qEt?nti8I;}ZDO*;2oZU>Uf3-ZfUz(Vh@RTkwnf(d}Wij?9gGRt8ZN2PfxJc$*Gvj+#N!td^a384e(R4KXxhz)WmggzDqa>L=H48SO(s%bTs08LGLyd7z_jgpqL3V9`NW-A5b4gy*K7JjHYjjCp+tEoih4)vd{pandC5gSEn}An$3U-NoLrO{tR=uU<7wFR+*;4vN9yXe1D#dlY)KKss6fgxQ9m}R6gn88(=1wcJc=~>>EcAy~C!R=a*s+Sc%_zgEp+e7)sudL1OX%=!U2P843(BPba5w2k3O@l2NXYk>^S^Z<A1&B@tWnFeR|?DYktu~or&7z+H(<}LvcVK-&{Rs2b<Bl2$0u#Ms4CeiRhd4S>c(hvk%93GWwmx3`l%tnp4qmu^VYO0-@C!oO6<u#M4(zB2T%4Q!*OY?8;4t@o*p;DoWN;vtjCt`JB>?v*vdXDmLR5nOtsZP08S?rt_gP4dyup|siyd<JC`GR{+A*AYYNMimxi`8qCaUCy)?zHR8wXk7XpBR6GPb~f6bU48q$TLt84-`Y_p(kmep;+4tWQ?u~1(4by;CBhVT!gzn1!ZjXL3i4?jJXN0?-g7q9LfBI}82wO~8EyPu>Ue|5>bEf-rELAGZxaKAmZoPBcgS6S>Kw@7Mg&HhHV_e3W2t4k_+W#R?{(Sh?+utgKurVldy{4mtJC{}DCacDK1oPA`2kV+~x>ik3=C7p30*7TuIX^+O;$npL1PKecT0zNm>e$Pndy7g!Cu21&msNf@lrUX_S#&60fy=&YWS)=O)s@ErbnX56A*2mw-%*ZfYIS6}v7}2>Q8r_NI7<^89DC)zVwo^-$%Q=VJRWd$bFW72Ke@ui6z7(AhRdh?kwqA=BA2$}X8y`a9nSTF4nxPYAN|d*KBFkS&1tL#bwJw8s)jqj85dQDE7N%PFnLNIwyb|+Te?8bFFKXJ|c){ep%~%}|BL!*r@$v-9=x}wR4q&Od9=)o{p9OSM)5`z-pZ`mHHP8vyBmktUP(>aj9^FlL<HC9pM`m^8c|<TDt<0r5o!E7Ux<F19A>_1$KLjA4+fq|OEK5@)SMHwrF!)P#j{D&j%nk~Sg5EZvg?M<+<Q007K|8%4hu-OI??On-w;PsTh}F1*aE31bope>HkP7G>#1kgOC3h(XH0%gbo!y8f`)f~>bS(Nr!r`%sMo+pTCdnBHn1O=S;|>h$1HMBdc^Cn<%hdw8tlX~1L8BSjUDU?WQ^mCP8+$+}UMLaFST}Hr2aTa1BhnLtY*DP0v6752kq(m=&Y!$|{rdd%{Q3EJFJJula->{Cl-<u__eYt}>$RxlVMZ@dLzP(+DXRsYh+JAb{aNKYL(7mf+8`FyZ6~66KP4?49WdDr(mb5k8nPTT<UP;_u5nzu0frrO+cvH2inh2927HKQh2ki<++e!L)QZ(JsMLcI+m_lTt9}7f_Xek*-5c1`WjYb?JszMc)b8W#D9-Lgsls}fryw4ZNT&t4yOY+fqS&tEaH^NeZIQG-IGN8`MG;4EN()Bn`zEhtn9FW~E14Ql(De&s^LwwlaO1>knPa3k?p0y=<?6nj@2=rlR|PD}=Dn`2Ly6`gLDo#UGjyU|uk8>-nK}B@KEd@Zu4sGhJVs|Lxf3{=C`D9fY(blxO4#JL(bdsD>`SjqJXPsHtjT76BZ}*r&Ai@hxr~29nml`-f<IeOK2qPL47|nz=t!(6w}DoUf_ml#fTw0D2ZngCLL)`sg{1F9jra1NAq=bE7WI}bzGqpny8at``<=M1gy^)S-p_McVE&%HopW7e*wRweHyXzDpaLKg?A!`wZ!xDbb7RFvv@P;y7}@)3P?>p3g@*k#FyqAf(1izT*1Auw?gc4#WIbCgeA1CHV@DU_nq}{MMv>?`rR!B1uqwAV+8hA|T48vt)Bd$DW0kTZD?Ek_qHP%@2bi8wqDm7s?!n(qI7=r!QQKf?$lQj8(G7yE@)9)%1ulCoK*iqn_x@X2MpM}WY?I1V=xU#bVRpaf0BNhcIEGPr%2%T2kIU=p(IKSU;OfB^8wS$bNSh8ZbqlE*2&}R7K~Oyi4VY2UJq9aIS3=x<ZKO8Wm-xtBD77GZK?!Lrij~aN=rPWp&o0jAPoACq^xgSf-UQ`p_BpVlXBz65Pl9LWu|%-0w@0&K{)D+Wq7v$wg&IZm-4C_Ab*d)THj2*NT+}w++4R$iLWKCf>0X*Mld;g6R`45{ucR`mrYe62#q~8X7@5pwnp%U)fArlMVCapQueP_s+?vr!#@^hR?ot|poAicz*JID3$ue4BkfM+vc(3-*=vl^UO^|bEk(FFvji0`pKR<i%^!xLRH{E46G2DJL4GZ)i8zWuvZKh)n6hzfVRC+&zqICkE++n)Ug`#$JFt3RQuwn)0hSY<+ILJDGC$jBE5ENdsidDywBJzITh-$fgXE<gzH=-FmsN6RUvn8!_ywp@5o;>i`i+vL(og2*o&{>t>1f&!qYF)i9X4mtDCloZiyprLV7L6EdK9v)wVThJS)5Xa_hqReULe|u%IFPm>w`^C}a#vc@eJpcF_RUp4YOWgi7wdvtHo7~e?A+g`b{MWjMX6}8z)PY@hB(Ki^)rQjmL<>)vl#I;)|o*Nxu{V}Hl^EMHu)!9WD8aam8QOwNjm@BV)$0h7I-kz!5vwM>-?8bXIniDY9Si7H<NSRG`!Cv-!r==6+k0!GE{1tN88-phD|D`L0o$o(Ol{D^2Nm)IErT%7w2zwIdZQEsHz}jpJ(3fwBw=g)o9bMRvL=bv`2rFuT(Bm)a2^+I;}Q)tuzWpDT>CxekSD6aH;Plm`2+oml8nJ{crM0Ib&L`!Lw@>CB7|x74o*FI)7*4rnL#X$~)C2Co;be6NaI(?P4>Q)g^0nJCY4ub<2&`n^9Y=7d`3BO*dY$cl1BKdiL_{yYuf9H(d1QVI|(qAKZuAr|a%(ltQ0%vr#AE8nE&q1lTDw=|;Qu4sj<9W|!VQd1YF`?gTM*_vbo^JOfbsV5~xJ%B;%U5?lq26f$O`s#|KXO4MnSoVx1dnC*ej(#ba9wt=l0PLjfyNeFATQ1L{KbO<T0?s|J&l=-x`sjFR(Zj54gg$ygswrh#IGy_c@+*Q47ZNt^>ZmLNUzBJn%dMD$mX{#Ms@1fbJySm!5{dL)HcwEVlo!a&4FJ({sE=lHkLMX@6$r|ZbYovU)&K|luTRxNr(Q8lXlvATYb~f?!h746y%4U}u*~BLikH$5ZcaEx@Xg);Sy+%4kBx^p<V)qn@Zc+`Y*J!uYZmWHrE_127mc}URsiiWh!GKf6-NvAhGFYZ`f95Wp{vGy7rd$m%w*r=@gXD){Grw19>Tc2QFqYmWXu99t-`8-t;O0_TV`lY?DUyx0{sbeu5BuxjLEn=0y|L_ut*#~H(jf*)wUxn{x|fE0FuRe8POVg+fG`?e>7&bI=SnLm<suEVyxzO)dVd2&-mOZr(DB>4we<e$w=L;1S6Jp;9Q9J9WS^vL_FnCIfA4CDGq^BxC*t@~ukK9U!i<*Xhhujn&nMnj#2Y;tP}i9|BJy)CINh;@gF$reAs+WQZn9eqxSldf1=lSTkL+RCt6|OAx?GP@yHbS7yHSsNE&sAA->zhXo#T6Lj=6lRoT@)smxD-;UIuwsi;muOqdr&tw3+_k|6rEzMDx6fV2vJYc;B_9jTh08hd(HR=(67Afk=t;qbSPt@jsUoFVTlS=oU_jm`GNVhSzv>WtMH%h4Meu3CBYiOa+dNY^u|a-MEShl=PCKRD&{ZLM2RJ`%*XwD=k0%7vC;=n2AYEt^Fc1Z?eHoN|c=OfxNbdedK`)O{TJ#Ca12KDyKBL4)c&Ik#gI+#aC6=Dp;n?b@MIzK}sE%RMP~%U7qE9F0UY0hgv0GQ@nDbhj7=9$xM}0ES+hbJe2w^V`7YSY5#cY?%MWQ*Hk?DeF8&gUFADdzY|6_lhL^we7xs%GgrM!x@XdMOxn47Mn@0!OkH=;2cfyi-5@Y1x5+hlke8Sfu$Gs<qak@)IPDK8Dd89DGJD$eQSv(s+>Wp|-C~!02JMK+yp@kDQZY@z-jF9d+hBT>PiR{j9W*=r`WP^s9p}%aQI=q~)@2%{*?N*Hn4w+B$?ixbo6F#mYC>0Ue0#Y+B>DcVyJ<m1_4C2@_D&ZPo&4C_Hfm~ica!864Y{9hN~s{)4Jxq$&=dL&C%JPabIo@r4bIbQ(}vL<+Xg&x65<-gicjQ%5?6f(RkV7I<}BB>j{k&G-_q{@SmlPU#77&jgAw4QSimvft~4i%?s~_q^obYZsQYl0$&=M^RL61aJ)1h+_U7upq~01J+wS*F4iTa|OKA#K_n)|V)bCx9KSb6&V%n<8MpEp#cRE>~gXY`ix;9DGVpY?RD6l#!ic__S&>|G7#dO!F<I$8v{DgKs<&QGJ9<EfmNn?oH=z?)SNs(l~K$sQeJ<;@xcST$QS*hEfs+|@Zn&$S`^0<rQy1Tu*#9A!tK|e+`I}xVlT|1BaTin?`IO(5|J+Q}c*O`XPQ4_k9eXArpH3KS{@PR$7CZBLB_vxUr)bwfxy}$b;U+rVIPh_)ReL}kfM%4j!+S{r(^EG?lxH_5#jU`-g=_nZ|NS9P*d8}X4zSU1ppM5t6lzREvY-P;eQjkU2j}DI-*5AjZh1_8{b&c^K9J}nyh59Lzoyi!DM#Nvo^2bxuX*yYwP&YK^%zCb4y=~xG|Ncn|eMX>=SvmVfSWmx`*AX0^;7{K%dT6sqYVQA!(Pg~c6IMQGuW6v>ru&or=Az1dHLzjlHQ_&eSB9Csxd#j|U0-#r^G>ueQZsg;<8-QF^{i_(hs_NPo93#6mJRF-ghV?HKo>fA*UOr0qzKK<ACM(ke&@Geq{3`}Zbp7>itF!VC2%vn^E!6A$5W`H(ZF3gdYO_f)Tf^Yz{8V43zyAEuUgnxjZt!PSjOfs7t12kic)(dP-?32J->5vQ=5@qZ&?Ksjpe%q;d5S8ut4uu8GY(r-yq8=Jf|MF735R>TQ)kORZ!zh=5NcFZ;OpeJW*w3G=O5P<ayAK_{`{!KbBfpzSu0+qdm#7)K1&_ti=3`NAJ?nME&#*rhVCW!^?V>-9VDYO{J-2m!Um4g`uh{Jt)n=xB5xG*w#1W$+u`Hr)e3R=U{|YIqvulC}AQLoxa)$lilcv-JLNhor}&$+d*zukkMbv-q*bR<y7u$>ZQNWFf^L>`$~vk1^w6)?E_{TOBzsa=}Pcz<dM{+`H87YNXa1`Yr<4=>(waQ-yuDH$?2P_-i;uAgLS_JKG_Lpk&D{5`X~CPEzvD2dz9g+2ku2tWz?N0_g#h3OySOXYpL~na@pA6W?<Sj>@PJK&-4JeF^r%LM~4f#*7kQS*r%+{PQJt;q7Nm*v=L!-tnj`Y6f(NPiOAla<7Q7y!MffIPOaUeU#8o;`@!O%oxNk)!`EFvs24@sbJIY*4+gy`t0f(b5$*o1H2se?C?UzKzioVX>6J+WP3)Jg-qSWiUpi;a@3Ki7tdYe%FllbW+S1Kxpw7YM8fj!?vAH%8gB?}{g!)-CQ)_^l_7xh0*5sB0Z7Yv^U8^rZHsh9v`+!t8&wQV~>;PXC*S{C`wqel5ND?FVNqjhqs5^s`-neDD3$=RETfmuNgNCO%Ho0>%kzv4E2tL<DnR5e;^l37cURYq(=(YpVa^`dTQ6O-f40BmeVEE{Ym$km_pjM2g;;oNr_3MT-LGNHLR1mTA`-aq{x)Xt}i&=3?UT^>lQ&Co14)b$^YUz7vq|{hNHM7hmWe`Q{k-1Yroq?tcir^m%or0Bkt1mCpy-UzgZt2$uS9D1LRnk}gn1Ozh*gOoQ_7<zQD@tv*njbIJ&Gi<+h-2?zFSY6+F4$9(=Im5<sNy8Ub(UgCzm<5bZc3^RPd3RFN^hebbE@1vpwCgHb9K}1OPw>OcJ5^&_ux4Bq02$&S1LEfwG7~!+^jZH|66m$Ls+{5F-AfTwn4DHdD0M!CSoQh*yxQ~-Q=NDy`&V-T&m$q5ZYf4Si$TUAtStv02ygk2N~NFCp#G#y&HA(`9X7T?WlkCT?dM*VLi6=r8yEccXv2Ds7DS}(64|JcG|&3GAl%i_$jURWxGx)T&i#7+1c5aRm^P}ds}UE1zMKH6(2N@>5`7YZ3D8H;U&4v(3}Gsp3CmCm}zl%Enfe!tFz<3>z|f9zWU%y9XF;6ubRq}y$Q*bzR}WdvQK2bu3jv4L&?cb?ZY?TNS>BShO%>&#z{Z$R($-8etXe+W%yd|R!OG*7OHJ^vt1fRoR<Z8fnqZNoy`f;c_9<};62g}DRK;#&E+VxV__C?aBa$gX*cTh^mis)H<{!50;of$O?sK?dS<(aLWfD~x=8;3=>3h$Lmg&r&|tIjuhhm%`=FMoKrLGxY*$|pbkam9=IwnzGGC=x3bo~?6o$%~+`ap!ZDw@0yP&PQQPCv5BIdHFshX0>eHAtEAw^;01gdhsR-^O&cxpLaY++s;{XY>`onH'}}

def run_graphics_update():
    import fcntl

    if any(arg in ("--verificar", "--verify", "-h", "--help") for arg in sys.argv[1:]):
        return main(ARQUIVOS)
    cache = Path.home() / ".bastiao_etapa3"
    lock_path = cache / "execucao.lock"
    if not cache.is_dir():
        return main(ARQUIVOS)
    _safe(lock_path)
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise PatchError("Outro instalador do Bastiao esta aberto. Feche-o primeiro.") from None
        result = main(ARQUIVOS)
    if result == 0:
        print("Iluminacao pronta para testar. Rode o testar-nuvem do BASTIAO_ETAPA3.py.")
    else:
        print("Esta entrega usa a base da Correcao 10 do Codex. Preserve arquivos diferentes e revise o erro acima.")
    return result

if __name__ == "__main__":
    try:
        raise SystemExit(run_graphics_update())
    except (OSError, PatchError, KeyboardInterrupt) as exc:
        raise SystemExit("BLOQUEADO: " + str(exc)) from None
