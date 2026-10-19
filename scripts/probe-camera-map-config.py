import subprocess,json,re,xml.etree.ElementTree as ET
from pathlib import Path
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
raw=subprocess.check_output([adb,'-s','emulator-5554','shell','su','0','cat','/data/data/com.fts.notis/shared_prefs/FlutterSharedPreferences.xml'])
out=[]
def scan(v,path):
    if isinstance(v,dict):
        for k,x in v.items(): scan(x,path+'/'+k)
    elif isinstance(v,list):
        for i,x in enumerate(v): scan(x,path+'/'+str(i))
    elif re.search(r'geocod|search|map|location|gps|place',path,re.I):
        if re.search(r'token|secret|password|api.?key|cookie',path,re.I):
            v='[REDACTED]'
        if isinstance(v,str) and len(v)>1000: v='[omitted long value]'
        out.append({'path':path,'value':v})
for e in ET.fromstring(raw):
    if e.get('name') in ('flutter.tenantModel','flutter.ConfigSave'):
        scan(json.loads(e.text),e.get('name'))
p=Path(__file__).resolve().parents[1]/'evidence/camera/map-config-pass4.json'
p.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(out,ensure_ascii=True))
