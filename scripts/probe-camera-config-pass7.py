"""GET only paths observed at startup; save camera-related leaves, no secrets."""
import json,urllib.request,datetime,hashlib
from pathlib import Path
for name,path in [('tenants','tenants'),('homepage','ttgt-tphcm/configs/homepage')]:
    url='https://api-thongtingiaothong.paas.ttgt.vn/'+path
    result={'kind':'analyst-probe-not-app-response-body','url':url,'method':'GET','timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'authentication_sent':False,'camera_fields':[]}
    try:
        with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'camera-spec-investigation/1.0'}),timeout=12) as r:
            raw=r.read(2097153);result.update(status=r.status,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        data=json.loads(raw)
        result['root_type']=type(data).__name__
        def visit(v,path=''):
            if isinstance(v,dict):
                for k,x in v.items():
                    if k in ('url-api-camera','area-camera'):
                        result['camera_fields'].append({'path':path+'/'+k,'value':x})
                    if k in ('name','key') and x in ('url-api-camera','area-camera'):
                        result['camera_fields'].append({'path':path,'value':{z:y for z,y in v.items() if z in ('name','key','value')}})
                    visit(x,path+'/'+k)
            elif isinstance(v,list):
                for i,x in enumerate(v):visit(x,path+'/'+str(i))
        visit(data)
    except Exception as e:result['error']=str(e)
    Path(f'evidence/camera/config-{name}-probe-pass7.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True))
