"""Two bounded analyst GET probes from a static route literal, not app traffic."""
import urllib.request,urllib.error,urllib.parse,time,json,hashlib
from pathlib import Path
r=Path(__file__).resolve().parents[1]/'evidence/camera/geocoding-probes-pass5';r.mkdir(exist_ok=True)
for name,q in [('query','Go Dua'),('coordinate','10.7774983,106.6964346')]:
    url='https://api.notis.vn/v4/routing/geocoding?q='+urllib.parse.quote(q)
    meta={'kind':'analyst-constructed-GET-not-app-traffic','time':time.time(),'url':url,'credentials_sent':False}
    try:
        try: res=urllib.request.urlopen(url,timeout=15)
        except urllib.error.HTTPError as e:res=e
        with res: b=res.read(1024*1024);meta.update(status=res.status,bytes=len(b),sha256=hashlib.sha256(b).hexdigest(),content_type=res.headers.get('Content-Type'))
        (r/(name+'-body.bin')).write_bytes(b)
    except Exception as e:meta['error']=str(e)
    (r/(name+'-meta.json')).write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print(json.dumps(meta))
