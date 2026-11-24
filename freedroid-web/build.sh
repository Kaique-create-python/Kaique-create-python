#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
mkdir -p work dist port
exec > >(tee "$ROOT/work/build.log") 2>&1
emcc --version
SRC="$ROOT/work/source"
ARCHIVE="$ROOT/work/freedroidRPG-1.0.tar.gz"
if [[ ! -f "$ARCHIVE" ]]; then
  if ! curl -fL --retry 2 --connect-timeout 20 --max-time 300 -o "$ARCHIVE.part" https://ftp.osuosl.org/pub/freedroid/freedroidRPG-1.0/freedroidRPG-1.0.tar.gz; then
    curl -fL --retry 2 --connect-timeout 20 --max-time 300 -o "$ARCHIVE.part" https://deb.debian.org/debian/pool/main/f/freedroidrpg/freedroidrpg_1.0.orig.tar.gz
  fi
  echo '73f124fe1aea48e25497b2ab7bbe992e  '"$ARCHIVE.part" | md5sum -c -
  mv "$ARCHIVE.part" "$ARCHIVE"
fi
echo '73f124fe1aea48e25497b2ab7bbe992e  '"$ARCHIVE" | md5sum -c -
sha256sum "$ARCHIVE"
rm -rf "$SRC"
mkdir -p "$SRC"
tar -xzf "$ARCHIVE" --strip-components=1 -C "$SRC"
test -f "$SRC/lua_modules/FDdialog.lua"
test -d "$SRC/data"
cat > port/sdl-config <<'EOF'
#!/bin/bash
for arg in "$@"; do
 case "$arg" in
 --version) echo 1.2.15;;
 --cflags|--libs|--static-libs) echo '-sUSE_SDL=1';;
 --prefix|--exec-prefix) echo "$(emcc --cflags | sed -n 's/.*--sysroot=\([^ ]*\).*/\1/p' | head -1)";;
 esac
done
EOF
cat > port/pre.js <<'EOF'
Module.preRun=Module.preRun||[];
Module.preRun.push(function(){
 ENV.HOME='/home/web_user';
 var dir='/home/web_user/.freedroid_rpg';
 FS.mkdirTree(dir);
 FS.mount(IDBFS,{autoPersist:true},dir);
 addRunDependency('restore-saves');
 FS.syncfs(true,function(err){if(err){abort('Save restore: '+err);return;}removeRunDependency('restore-saves');});
});
EOF
cat > port/cc.py <<'PY'
#!/usr/bin/env python3
import os,sys,subprocess,pathlib,shutil
args=sys.argv[1:]
legacy={'-lSDL','-lSDL_image','-lSDL_gfx','-lSDL_mixer','-rdynamic','-Wl,--as-needed'}
args=[x for x in args if x not in legacy and x not in ('-lGL','-lGLU')]
flags=['-sUSE_SDL=1','-sUSE_SDL_IMAGE=1','-sUSE_SDL_GFX=1','-sUSE_SDL_MIXER=1','-sUSE_ZLIB=1','-sUSE_LIBJPEG=1','-sUSE_LIBPNG=1','-sUSE_OGG=1','-sUSE_VORBIS=1']
output=None
if '-o' in args and not any(x in args for x in ('-c','-E','-S')):
 i=args.index('-o')+1
 if pathlib.Path(args[i]).name=='freedroidRPG':
  output=pathlib.Path(args[i])
  args[i]=str(output)+'.js'
  for folder in ('data','lua_modules'):
   args+=['--preload-file',os.path.join(os.environ['FD_WEB_ASSETS'],folder)+'@/'+folder]
  args+=['--pre-js',str(pathlib.Path(__file__).with_name('pre.js')),'-lidbfs.js','-sFORCE_FILESYSTEM=1','-sEXPORTED_RUNTIME_METHODS=["FS"]','-sASYNCIFY=1','-sASYNCIFY_STACK_SIZE=131072','-sALLOW_MEMORY_GROWTH=1','-sINITIAL_MEMORY=134217728','-sMAXIMUM_MEMORY=1073741824','-sASSERTIONS=1','-sSTACK_SIZE=524288','-sEXIT_RUNTIME=1']
subprocess.run([os.environ['FD_EMCC'],*flags,*args],check=True)
if output: shutil.copyfile(str(output)+'.js',output)
PY
chmod +x port/sdl-config port/cc.py
python3 - "$SRC" <<'PY'
import pathlib,re,sys
root=pathlib.Path(sys.argv[1]); count=0
for p in (root/'src').rglob('*.c'):
 s=p.read_text(encoding='utf-8',errors='surrogateescape')
 if 'FD_WEB_YIELD' in s: continue
 s,n=re.subn(r'(?m)^([ \t]*)our_SDL_flip_wrapper\(\);[ \t]*$',lambda m:m.group(0)+'\n#ifdef __EMSCRIPTEN__\n'+m[1]+'emscripten_sleep(0); /* FD_WEB_YIELD */\n#endif',s)
 if n:
  p.write_text('#ifdef __EMSCRIPTEN__\n#include <emscripten.h>\n#endif\n'+s,encoding='utf-8',errors='surrogateescape')
  print(p,n);count+=n
if not count: raise SystemExit('No render yield points found')
PY
export FD_WEB_ASSETS="$SRC" FD_EMCC="$(command -v emcc)" SDL_CONFIG="$ROOT/port/sdl-config"
export CC="$ROOT/port/cc.py"
cd "$SRC"
if [[ ! -x configure ]]; then ./autogen.sh; fi
./configure --help > "$ROOT/work/configure-options.log"
find data lua_modules -type f | wc -l
find externals -maxdepth 2 -type f | head -50 || true
emconfigure ./configure --host=wasm32-unknown-emscripten --disable-sdltest --disable-opengl --disable-backtrace --with-embedded-lua --enable-sound --disable-dev-tools --disable-nls CC="$CC" AR="$(command -v emar)" RANLIB="$(command -v emranlib)" CFLAGS='-O2' 2>&1 | tee "$ROOT/work/configure.log"
emmake make -j2 V=1 CC="$CC" 2>&1 | tee "$ROOT/work/make.log"
cd "$ROOT"
for ext in js wasm data; do test -s "$SRC/src/freedroidRPG.$ext"; done
cp "$SRC"/src/freedroidRPG.{js,wasm,data} dist/
cp "$SRC/COPYING" dist/COPYING
test -s dist/freedroidRPG.wasm
python3 -c 'import pathlib; assert pathlib.Path("dist/freedroidRPG.wasm").read_bytes()[:4] == b"\x00asm"'
sha256sum dist/freedroidRPG.{js,wasm,data} > dist/SHA256SUMS
cat > dist/index.html <<'HTML'
<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FreedroidRPG Web experimental</title><style>body{background:#111;color:#eee;font:16px system-ui;text-align:center}canvas{max-width:100%;max-height:85vh;touch-action:none}pre{max-height:180px;overflow:auto;text-align:left}</style><h1>FreedroidRPG</h1><button id="start">Iniciar jogo original</button><p id="status">Build experimental</p><canvas id="canvas" tabindex="0" hidden></canvas><pre id="log"></pre><script>
var canvas=document.getElementById('canvas'),statusEl=document.getElementById('status'),log=document.getElementById('log');
var Module={canvas,print:t=>log.textContent+=t+'\n',printErr:t=>log.textContent+=t+'\n',setStatus:t=>statusEl.textContent=t||'Runtime iniciado',onAbort:t=>statusEl.textContent='Erro: '+t};
document.getElementById('start').onclick=function(){this.hidden=true;canvas.hidden=false;canvas.focus();var s=document.createElement('script');s.src='freedroidRPG.js';s.onerror=()=>statusEl.textContent='Build indisponível';document.body.append(s);};
</script><small>Freedroid Team — port experimental não oficial</small></html>
HTML
echo 'WASM output exists. Gameplay and license review pending.'
