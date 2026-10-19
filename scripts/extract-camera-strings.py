"""Static ASCII candidates only; offsets are file byte offsets, not code xrefs."""
import re, json, hashlib
from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'evidence/camera/native/libapp.so'
b = p.read_bytes()
rows = []
for m in re.finditer(rb'[\x20-\x7e]{5,}', b):
    s = m.group().decode('ascii')
    if re.search(r'camera|cctv|snapshot|https?://|bybbox|favorite|lat1=|lng1=|radius', s, re.I):
        if re.search(r'token|secret|api[_-]?key', s, re.I):
            continue
        rows.append({'offset': hex(m.start()), 'text': s})
out = root / 'evidence/camera/native-string-candidates.json'
out.write_text(json.dumps({'sha256': hashlib.sha256(b).hexdigest(), 'type': 'static-literal-candidates-no-call-proof', 'rows': rows}, indent=2), encoding='utf-8')
print(f'{len(rows)} candidates: {out}')
