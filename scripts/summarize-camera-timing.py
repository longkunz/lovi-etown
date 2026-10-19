import json
from pathlib import Path
r=Path(__file__).resolve().parents[1]/'evidence/camera'
samples=json.loads((r/'counter-pass3/samples.json').read_text(encoding='utf-8'))
numbers=[]
for s in samples:
    a=[int(n['description'] or n['text']) for n in s['numbers']]
    numbers.append({'start':s['start'],'end':s['end'],'counter':a[0] if len(a)==1 else None})
resets=[]
for a,b in zip(numbers,numbers[1:]):
    if a['counter'] is not None and b['counter'] is not None and b['counter']>a['counter']:
        resets.append({'earliest':a['start'],'latest':b['end'],'estimated_midpoint':(a['end']+b['start'])/2})
events=[json.loads(x) for x in (r/'socket-refresh-pass3.jsonl').read_text(encoding='utf-8-sig').splitlines() if x.startswith('{')]
writes=[e for e in events if e.get('peer',{}).get('ip')=='109.237.69.7' and e.get('bytes')==159]
out={'type':'runtime-counter-and-socket-metadata-not-decrypted-HTTP','pid':13560,'ui_samples':numbers,'ui_reset_windows':resets,'ui_estimated_cycle_seconds':[b['estimated_midpoint']-a['estimated_midpoint'] for a,b in zip(resets,resets[1:])],'same_size_socket_writes':writes,'socket_intervals_seconds':[(b['time']-a['time'])/1000 for a,b in zip(writes,writes[1:])],'limitations':['UI dump duration bounds time resolution; counter sample and socket sample came from different measurement windows.','159-byte socket writes are encrypted/outbound metadata, not authenticated HTTP request identities.','Analyst-host DNS matches socket destination; app DNS resolution was not captured.']}
(r/'timing-summary-pass3.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps({'ui_cycles':out['ui_estimated_cycle_seconds'],'socket_intervals':out['socket_intervals_seconds']}))
