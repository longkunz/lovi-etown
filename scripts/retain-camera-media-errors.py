"""Retain only the observed media error/stack lines for the selected app PID."""
import subprocess,re
from pathlib import Path
adb=r'C:/Users/longhv/AppData/Local/Android/Sdk/platform-tools/adb.exe'
raw=subprocess.check_output([adb,'-s','emulator-5554','logcat','-d','-t','1000','--pid=13560']).decode('utf-8',errors='replace')
lines=[]
for line in raw.splitlines():
    if ('ExoPlayerImplInternal' in line or 'Cleartext HTTP traffic to camera.thongtingiaothong.vn' in line or 'PlatformException(VideoError' in line):
        line=re.sub(r'(https?://[^\s?]+)\?[^\s]+',r'\1?[REDACTED]',line)
        lines.append(line)
p=Path(__file__).resolve().parents[1]/'evidence/camera/media-errors-pass4.txt'
p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'Retained {len(lines)} media lines')
