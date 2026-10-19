import subprocess,xml.etree.ElementTree as ET,json,re,urllib.parse
from pathlib import Path
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
raw=subprocess.check_output([adb,'-s','emulator-5554','shell','su','0','cat','/data/data/com.fts.notis/shared_prefs/FlutterSharedPreferences.xml'])
s=next((e.text for e in ET.fromstring(raw) if e.get('name')=='flutter.ErrorLog'),'[]')
rows=json.loads(s)
def scrub(s):
    s=re.sub(r'(https?://[^\s?]+)\?[^\s]*',r'\1?[REDACTED]',str(s))
    s=re.sub(r'Bearer\s+\S+','Bearer [REDACTED]',s,flags=re.I)
    return s
out=[]
for row in rows:
    if 'routing/geocoding' not in str(row.get('url','')):continue
    safe={k:scrub(row.get(k)) for k in ('code','errorMessage','dateTime')}
    url=str(row.get('url',''))
    safe['url']=url.split('?',1)[0]+('?[REDACTED]' if '?' in url else '')
    safe['query_keys']=list(urllib.parse.parse_qs(urllib.parse.urlsplit(url).query))
    response=row.get('response')
    safe['response_type']=type(response).__name__
    if isinstance(response,str):safe['response']=scrub(response)
    elif isinstance(response,dict):safe['response']={k:scrub(v) for k,v in response.items() if k.lower() in ('code','status','message','error')}
    safe['omitted_fields']=['param','metadata']
    out.append(safe)
p=Path(__file__).resolve().parents[1]/'evidence/camera/geocoding-error-log-pass5.json'
p.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(out,ensure_ascii=True,indent=2))
