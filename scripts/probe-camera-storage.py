import subprocess, json, xml.etree.ElementTree as ET, re
from pathlib import Path
ADB = r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
cmd=[ADB,'-s','emulator-5554','shell','su','0','cat','/data/data/com.fts.notis/shared_prefs/FlutterSharedPreferences.xml']
raw=subprocess.check_output(cmd)
root=ET.fromstring(raw)
result={'source':'FlutterSharedPreferences.xml','keys':[], 'camera_entries':[]}
for e in root:
    key=e.attrib.get('name','')
    result['keys'].append(key)
    if key in ('flutter.ConfigSave','flutter.tenantModel'):
        try:
            config=json.loads(e.text or '{}')
            def visit(v,path=''):
                if isinstance(v,dict):
                    for k,x in v.items():
                        if 'camera' in k.lower():
                            result.setdefault('camera_config_keys',[]).append({'source':key,'path':path+'/'+k,'value':x})
                    if any('camera' in str(x).lower() for x in v.values() if not isinstance(x,(list,dict))):
                        safe={k:x for k,x in v.items() if not re.search(r'token|secret|cookie|password|key',k,re.I)}
                        result.setdefault('camera_config',[]).append({'path':path,'value':safe})
                    for k,x in v.items(): visit(x,path+'/'+k)
                elif isinstance(v,list):
                    for i,x in enumerate(v): visit(x,path+'/'+str(i))
            visit(config)
        except ValueError: result['config_status']='not-json'
    if re.search(r'camera|area-camera',key,re.I):
        val=e.text or e.attrib.get('value','')
        if re.search(r'token|secret|cookie|password',val,re.I):
            val='[REDACTED: contains sensitive fields]'
        result['camera_entries'].append({'key':key,'type':e.tag,'value':val})
p=Path(__file__).resolve().parents[1]/'evidence/camera/storage-probe.json'
p.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=True,indent=2))
