from pathlib import Path
import base64
root=Path(__file__).resolve().parents[1]
dest=root/'docs/screenshots'
dest.mkdir(parents=True,exist_ok=True)
for path in (root/'build').glob('*.b64'):
    raw=base64.b64decode(path.read_text(encoding='utf-8'),validate=False)
    extension='.png' if raw.startswith(b'\x89PNG\r\n\x1a\n') else '.jpg' if raw.startswith(b'\xff\xd8') else None
    assert extension, 'Expected original PNG or JPEG screenshot'
    (dest/(path.stem+extension)).write_bytes(raw)
    path.unlink()
    print('Saved',path.stem)
