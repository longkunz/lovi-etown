import json
from pathlib import Path
r=Path(__file__).resolve().parents[1]/'evidence/camera'
marks=json.loads((r/'lifecycle-pass4.json').read_text(encoding='utf-8'))
t={x['event']:x['time'] for x in marks}
events=[json.loads(x) for x in (r/'socket-lifecycle-pass4.jsonl').read_text(encoding='utf-8-sig').splitlines() if x.startswith('{')]
w=[x for x in events if x.get('peer',{}).get('ip')=='109.237.69.7' and x.get('peer',{}).get('port')==443]
def window(a,b): return [x for x in w if t[a]<=x['time']/1000<t[b]]
fg=window('foreground-start','home-before'); bg=window('background-start','resume-before'); resumed=window('resumed-start','end')
o={'kind':'socket-observation-not-decrypted-HTTP','pid':13560,'foreground_seconds':t['home-before']-t['foreground-start'],'background_seconds':t['resume-before']-t['background-start'],'resumed_seconds':t['end']-t['resumed-start'],'foreground_writes':fg,'background_writes':bg,'resumed_writes':resumed,'first_resume_write_delay_seconds':resumed[0]['time']/1000-t['resumed-start'] if resumed else None,'limitations':['Bounded 30-second background window on this device/app version.','No writes in these hooks is not proof that every background task or every host stopped.','Socket metadata does not identify HTTP method/path.']}
(r/'lifecycle-summary-pass4.json').write_text(json.dumps(o,indent=2),encoding='utf-8')
print(json.dumps({'foreground_writes':len(fg),'background_writes':len(bg),'resumed_writes':len(resumed),'resume_delay':o['first_resume_write_delay_seconds']}))
