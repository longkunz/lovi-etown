"""One bounded foreground/background/resume scenario for the opened camera."""
import subprocess,time,json
from pathlib import Path
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
p=Path(__file__).resolve().parents[1]/'evidence/camera/lifecycle-pass4.json'
events=[]
def mark(name):
    events.append({'event':name,'time':time.time()})
    p.write_text(json.dumps(events,indent=2),encoding='utf-8')
def run(*args): subprocess.run([adb,'-s','emulator-5554',*args],check=True,stdout=subprocess.DEVNULL)
mark('foreground-start'); time.sleep(18)
mark('home-before'); run('shell','input','keyevent','3'); mark('background-start'); time.sleep(30)
mark('resume-before'); run('shell','monkey','-p','com.fts.notis','-c','android.intent.category.LAUNCHER','1'); mark('resumed-start'); time.sleep(18)
mark('end')
print(json.dumps(events))
