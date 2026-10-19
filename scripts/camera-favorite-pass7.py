import json,subprocess,time,xml.etree.ElementTree as ET,sys
from pathlib import Path
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
def cmd(*args):return subprocess.check_output([adb,'-s','emulator-5554',*args])
def state():
    root=ET.fromstring(cmd('shell','su','0','cat','/data/data/com.fts.notis/shared_prefs/FlutterSharedPreferences.xml'))
    values=json.loads(next(x.text for x in root if x.get('name')=='flutter.CameraCare_ttgt-tphcm'))
    return [{'id':x.get('_id'),'name':x.get('name')} for x in values]
phase=sys.argv[1]
record={'phase':phase,'before_ms':round(time.time()*1000),'before':state()}
if phase=='add':cmd('shell','input','tap','65','265')
elif phase=='remove':cmd('shell','input','tap','1541','260')
else:raise SystemExit('add/remove only')
time.sleep(2)
record.update(after_ms=round(time.time()*1000),after=state())
Path(f'evidence/camera/favorite-{phase}-pass7.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=True))
