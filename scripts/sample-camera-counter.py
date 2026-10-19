import subprocess,time,json,datetime,xml.etree.ElementTree as ET
from pathlib import Path
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
root=Path(__file__).resolve().parents[1]/'evidence/camera/counter-pass3'
root.mkdir(exist_ok=True)
rows=[]
for i in range(18):
    start=time.time()
    subprocess.run([adb,'-s','emulator-5554','shell','uiautomator','dump','/sdcard/camera-counter.xml'],stdout=subprocess.DEVNULL,check=True)
    raw=subprocess.check_output([adb,'-s','emulator-5554','shell','cat','/sdcard/camera-counter.xml'])
    end=time.time()
    (root/f'{i:02}.xml').write_bytes(raw)
    x=ET.fromstring(raw)
    nodes=[{'text':e.get('text'),'description':e.get('content-desc'),'bounds':e.get('bounds')} for e in x.iter('node') if (e.get('content-desc','').isdigit() or e.get('text','').isdigit())]
    rows.append({'start':start,'end':end,'numbers':nodes})
    (root/'samples.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print(json.dumps(rows))
