"""Read-only audit of the original Termux tool, doubling only upload boundaries."""
import hashlib,json,re,shlex,shutil,subprocess,tempfile,unittest
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]

def ids(path):
 root=ET.parse(path).getroot()
 config=next(o.find("Properties/*[@name='Source']").text for o in root.iter('Item')
  if o.findtext("Properties/string[@name='Name']")=='Config')
 return {name:int(re.search(r'\b'+name+r' = (\d+), --@@'+marker+r'@@',config)[1])for name,marker in
  [('Id','SPRITE_ID'),('Logo','LOGO_ID'),('Icons','ICONS_ID')]}

class MediaFlowAudit(unittest.TestCase):
 def run_flow(self,body,expect_ok=True):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);case=Path(tmp.name)
  script=(ROOT/'termux/ideias.sh').read_text()
  marker='\ncase "${1:-}" in\n';assert script.count(marker)==1
  library=case/'original-functions.sh';library.write_text(script.split(marker)[0])
  remote=case/'remote';shutil.copytree(ROOT/'dist',remote/'dist')
  helper=ROOT/'tools/preparar_midias.py'
  if helper.exists():
   shutil.copy2(helper,remote/'dist/preparar_midias.py')
   sums=remote/'dist/SHA256SUMS'
   lines=[line for line in sums.read_text().splitlines()if not line.endswith('preparar_midias.py')]
   sums.write_text('\n'.join(lines)+'\n'+hashlib.sha256(helper.read_bytes()).hexdigest()+'  preparar_midias.py\n')
  (remote/'tools').symlink_to(ROOT/'tools',target_is_directory=True)
  (remote/'tests').symlink_to(ROOT/'tests',target_is_directory=True)
  code='''set -- audit
source '''+shlex.quote(str(library))+''' >/dev/null
CASE='''+shlex.quote(str(case))+'''
BASE="$CASE/downloads";PASTA="$BASE/IdeiasSemLimites";CONF_DIR="$CASE/state";CONF="$CONF_DIR/config";LEDGER="$CONF_DIR/historico.tsv"
RAW='''+shlex.quote('file://'+str(remote))+'''
mkdir -p "$BASE"
carregar_config() { USER_ID=1357078972; }
cabecalho_chave() { HDR=""; }
enviar_audio() { printf '111111\n' >"$CONF_DIR/audio_id";printf '%s\n' "$2" >"$CONF_DIR/audio_sha"; }
enviar_decal() { printf '%s\n' "$2" >>"$CASE/image-uploads";if [[ "$2" == *Icones ]];then echo 333333;else echo 222222;fi; }
enviar_legado() { printf '%s\n' "$1" >"$CASE/sent-path";cp "$1" "$CASE/sent-place"; }
curl() {
 local url="${@: -1}" out="" previous="" arg
 for arg in "$@";do if [[ "$previous" == '-o' ]];then out="$arg";fi;previous="$arg";done
 [[ "$url" == file://* && -n "$out" ]] || return 98
 cp "${url#file://}" "$out"
}
cmd_baixar >/dev/null
'''+body
  result=subprocess.run(['bash','--noprofile','--norc','-c',code],text=True,capture_output=True,timeout=20)
  if expect_ok:self.assertEqual(result.returncode,0,result.stdout+result.stderr)
  else:self.assertNotEqual(result.returncode,0,'unsafe workflow unexpectedly succeeded')
  return case

 def test_default_send_uses_current_media_ids(self):
  case=self.run_flow('cmd_sons >/dev/null\ncmd_imagens >/dev/null\ncp "$CASE/sent-place" "$CASE/final-before-default"\ncmd_enviar >/dev/null\n')
  self.assertEqual(ids(case/'final-before-default'),{'Id':111111,'Logo':222222,'Icons':333333})
  self.assertEqual(Path((case/'sent-path').read_text().strip()).name,'IdeiasSemLimites_V3_final.rbxlx')
  self.assertEqual(ids(case/'sent-place'),{'Id':111111,'Logo':222222,'Icons':333333})
  print('PASS: default send keeps all confirmed media IDs.')

 def test_fresh_download_never_sends_stale_code(self):
  case=self.run_flow('''cmd_sons >/dev/null
python3 - "$PASTA/V3/IdeiasSemLimites_V3_sons.rbxlx" <<'OLD_MARKER'
import sys
from pathlib import Path
p=Path(sys.argv[1]);s=p.read_text();p.write_text(s.replace('Config.Version = "3.0.0"','Config.Version = "OLD-UI-AND-CODE"',1))
OLD_MARKER
cmd_baixar >/dev/null
cmd_imagens >/dev/null
''')
  self.assertFalse('OLD-UI-AND-CODE'in(case/'sent-place').read_text(),'a fresh download must never reuse old code')
  print('PASS: fresh download uses fresh source even when an old sons artifact exists.')

 def test_sons_after_images_preserves_image_ids(self):
  case=self.run_flow('cmd_sons >/dev/null\ncmd_imagens >/dev/null\ncp "$CASE/sent-place" "$CASE/final-before-sons"\ncmd_sons >/dev/null\n')
  self.assertEqual(ids(case/'final-before-sons')['Icons'],333333)
  self.assertEqual(ids(case/'sent-place'),{'Id':111111,'Logo':222222,'Icons':333333})
  print('PASS: updating/reusing audio preserves image IDs.')

 def test_images_reuse_confirmed_uploads(self):
  case=self.run_flow('cmd_sons >/dev/null\ncmd_imagens >/dev/null\ncmd_imagens >/dev/null\n')
  self.assertEqual(len((case/'image-uploads').read_text().splitlines()),2)
  print('PASS: unchanged images are uploaded only once.')

 def test_distribution_hashes_and_zero_id_baseline(self):
  for line in (ROOT/'dist/SHA256SUMS').read_text().splitlines():
   digest,name=line.split(maxsplit=1);self.assertEqual(hashlib.sha256((ROOT/'dist'/name).read_bytes()).hexdigest(),digest)
  self.assertEqual(ids(ROOT/'dist/IdeiasSemLimites_V3.rbxlx'),{'Id':0,'Logo':0,'Icons':0})
  print('PASS: shipped artifact hashes match; pristine build expects ID injection.')

 def test_downloader_requires_helper_in_checksum_manifest(self):
  self.run_flow('sed -i "/preparar_midias.py/d" "${RAW#file://}/dist/SHA256SUMS"\ncmd_baixar >/dev/null\n',expect_ok=False)

 def test_downloader_rejects_malformed_helper_checksum_without_execution(self):
  case=self.run_flow('''cp "$PASTA/V3/preparar_midias.py" "$CASE/helper-before"
printf '\\n# unchecked download\\n' >>"${RAW#file://}/dist/preparar_midias.py"
sed -i 's/^[0-9a-f]*  preparar_midias.py$/invalid-checksum  preparar_midias.py/' "${RAW#file://}/dist/SHA256SUMS"
cmd_baixar >/dev/null
''',expect_ok=False)
  self.assertTrue((case/'helper-before').read_bytes()==(case/'downloads/IdeiasSemLimites/V3/preparar_midias.py').read_bytes(),'unverified helper replaced the existing one')

 def test_downloader_rejects_missing_place_checksum_without_overwrite(self):
  case=self.run_flow('''cp "$PASTA/V3/IdeiasSemLimites_V3.rbxlx" "$CASE/place-before"
sed -i '/IdeiasSemLimites_V3.rbxlx/d' "${RAW#file://}/dist/SHA256SUMS"
printf broken >>"${RAW#file://}/dist/IdeiasSemLimites_V3.rbxlx"
cmd_baixar >/dev/null
''',expect_ok=False)
  self.assertTrue((case/'place-before').read_bytes()==(case/'downloads/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxlx').read_bytes(),'previous Place was overwritten before manifest rejection')

 def test_verified_but_malformed_place_never_replaces_previous_download(self):
  case=self.run_flow('''cp "$PASTA/V3/IdeiasSemLimites_V3.rbxlx" "$CASE/place-before"
python3 - "${RAW#file://}/dist" <<'BAD_PLACE'
from pathlib import Path
import hashlib,sys
root=Path(sys.argv[1]);name='IdeiasSemLimites_V3.rbxlx';(root/name).write_text('bad xml')
p=root/'SHA256SUMS';p.write_text(''.join((hashlib.sha256((root/name).read_bytes()).hexdigest()+'  '+name+'\\n')if row.split()[-1]==name else row+'\\n'for row in p.read_text().splitlines()))
BAD_PLACE
cmd_baixar >/dev/null
''',expect_ok=False)
  self.assertTrue((case/'place-before').read_bytes()==(case/'downloads/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxlx').read_bytes(),'malformed verified XML replaced the last valid download')

 def test_audio_query_prefers_canonical_receipt_after_interrupted_legacy_mirror(self):
  case=self.run_flow('''cmd_sons >/dev/null
midias registrar audio 444444 "$(sha256sum "$PASTA/V3/IdeiasSons.ogg" | cut -d' ' -f1)"
curl() {
 local out="" previous="" arg
 for arg in "$@";do if [[ "$previous" == -o ]];then out="$arg";fi;previous="$arg";done
 printf '%s' "${@: -1}" >"$CASE/query-url"
 printf '{"moderationResult":{"moderationState":"Approved"}}' >"$out"
 printf 200
}
cmd_verificar_sons >/dev/null
''')
  self.assertTrue((case/'query-url').read_text().endswith('/444444'),'queried outdated legacy audio_id rather than confirmed JSON receipt')

 def test_failed_checksum_preserves_previous_download(self):
  case=self.run_flow('cp "$PASTA/V3/IdeiasLogo.png" "$CASE/logo-before"\nprintf broken >>"${RAW#file://}/dist/IdeiasLogo.png"\ncmd_baixar >/dev/null\n',expect_ok=False)
  self.assertEqual((case/'logo-before').read_bytes(),(case/'downloads/IdeiasSemLimites/V3/IdeiasLogo.png').read_bytes())

 def test_partial_image_failure_preserves_confirmed_receipt_without_saved(self):
  case=self.run_flow('''enviar_decal() {
 if [[ "$2" == *Icones ]];then return 1;else echo 222222;fi
}
cmd_imagens >/dev/null
''',expect_ok=False)
  self.assertFalse((case/'sent-path').exists())
  receipt=json.loads((case/'state/midia_logo.json').read_text())
  self.assertEqual(receipt['assetId'],'222222')
  self.assertFalse((case/'state/midia_icons.json').exists())

if __name__=='__main__':unittest.main(verbosity=2)
