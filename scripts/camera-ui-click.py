import argparse,subprocess,xml.etree.ElementTree as ET,re,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('serial');p.add_argument('prefix');p.add_argument('--click',action='store_true');a=p.parse_args()
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
def cmd(*args):return subprocess.check_output([adb,'-s',a.serial,*args])
result=cmd('shell','uiautomator','dump','/sdcard/camera-ui-click.xml').decode(errors='replace')
if 'ERROR' in result:raise SystemExit(result)
raw=cmd('shell','cat','/sdcard/camera-ui-click.xml')
nodes=[e for e in ET.fromstring(raw).iter('node') if (e.get('content-desc','') or e.get('text','')).startswith(a.prefix)]
if len(nodes)!=1:raise SystemExit(f'Expected one matching node, found {len(nodes)}')
n=nodes[0]; b=list(map(int,re.findall(r'\d+',n.get('bounds',''))));print(json.dumps({'serial':a.serial,'label':n.get('content-desc') or n.get('text'),'bounds':b},ensure_ascii=True))
if a.click:cmd('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2))
