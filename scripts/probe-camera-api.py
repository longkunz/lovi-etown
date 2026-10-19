"""Bounded, unauthenticated GET probes. Not a capture of app requests."""
import urllib.request, urllib.error, json, hashlib, datetime
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'evidence/camera/api-probes'
root.mkdir(exist_ok=True)
base='https://api.notis.vn/v4/'
probes={
 'snapshot':'cameras/5deb576d1dc17d7c5515ad13/snapshot',
 'nearby':'cameras?lat=10.775708&lng=106.700359&distance=5000',
 'bbox':'cameras/bybbox?lat1=10.770&lng1=106.695&lat2=10.780&lng2=106.705',
}
for name,path in probes.items():
    url=base+path
    meta={'kind':'analyst-constructed-GET-probe-not-app-traffic','timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'method':'GET','url':url,'authentication_sent':False}
    try:
        try: response=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'camera-spec-investigation/1.0'}),timeout=25)
        except urllib.error.HTTPError as e: response=e
        with response:
            body=response.read(5*1024*1024+1)
            meta.update(status=response.status,final_url=response.url,headers={k:v for k,v in response.headers.items() if k.lower() in ('content-type','content-length','cache-control','etag','last-modified','expires')},bytes=len(body),sha256=hashlib.sha256(body).hexdigest(),truncated=len(body)>5*1024*1024)
        suffix='.json' if 'json' in meta['headers'].get('Content-Type','') else '.bin'
        (root/(name+suffix)).write_bytes(body)
    except Exception as e: meta['error']=str(e)
    (root/(name+'-meta.json')).write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print(json.dumps(meta))
