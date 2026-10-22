"""Fail packaging when the original ARM64 engine or media service is missing."""
import json, os, subprocess, sys, zipfile
apk = sys.argv[1]
with zipfile.ZipFile(apk) as z:
    native = z.read('lib/arm64-v8a/libspotifast.so')
    assert native[:4] == b'\x7fELF' and int.from_bytes(native[18:20], 'little') == 183, 'Expected AArch64 ELF'
    assert any(n.startswith('classes') and n.endswith('.dex') for n in z.namelist())
aapt = os.path.join(os.environ['ANDROID_HOME'], 'build-tools/35.0.0/aapt2')
manifest = subprocess.check_output([aapt, 'dump', 'xmltree', apk, '--file', 'AndroidManifest.xml'], text=True)
for expected in ['FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'PlaybackService', 'FreeMusicActivity', 'SpotiFastActivity', 'foregroundServiceType']:
    assert expected in manifest, expected
print(json.dumps({'apk': apk, 'bytes': os.path.getsize(apk), 'arm64_native': True, 'manifest_checked': True}))
