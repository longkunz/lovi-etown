"""Build a sanitized, derived HAR from passive hooks for REA inspection.
Not a packet capture: response bodies omitted, timings are boundary timestamps.
"""
import json,re,datetime,collections,urllib.parse
from pathlib import Path
root=Path('evidence/camera');names=['app-http-pass7-map-favorite.jsonl','app-http-pass7-google.jsonl','app-http-pass7-search-favorite.jsonl','app-http-pass7-bodies.jsonl','app-http-pass7-fav-remove.jsonl']
entries=[];summary=[]
for name in names:
    pending={}
    for ordinal,line in enumerate((root/name).read_text(encoding='utf-8').splitlines(),1):
        if not line.startswith('{'):continue
        row=json.loads(line)
        if row.get('kind')=='app-http-request':
            method,path,version=row['line'].split(' ',2)
            if not(path.startswith('/v4/cameras') or path.startswith('/ttgt-tphcm/routing/geocoding') or path in ('/tenants','/ttgt-tphcm/configs/homepage')):continue
            headers=[{'name':k,'value':row.get('safe_headers',{}).get(k,'<value-omitted>')} for k in row['header_names']]
            path=urllib.parse.quote(path,safe='/?=&.-_:%')
            entry={'startedDateTime':datetime.datetime.fromtimestamp(row['time']/1000,datetime.timezone.utc).isoformat(),'time':0,'request':{'method':method,'url':'https://'+row['host']+path,'httpVersion':version,'cookies':[],'headers':headers,'queryString':[],'headersSize':-1,'bodySize':0},'response':{'status':0,'statusText':'not captured','httpVersion':'HTTP/1.1','cookies':[],'headers':[],'content':{'size':-1,'mimeType':'application/octet-stream'},'redirectURL':'','headersSize':-1,'bodySize':-1},'cache':{},'timings':{'send':0,'wait':0,'receive':0},'_source':{'file':name,'line':ordinal,'kind':'derived-passive-plaintext-hook','body_omitted':True,'authorization_scheme':row.get('authorization_scheme','not-recorded')}}
            entries.append(entry);pending[row['connection']]=(entry,row['time'])
        elif row.get('kind')=='app-http-response' and row['connection'] in pending:
            entry,start=pending.pop(row['connection']);parts=row['line'].split(' ',2);safe=row.get('safe_headers',{})
            entry['time']=row['time']-start;entry['timings']['wait']=entry['time']
            entry['response'].update(status=int(parts[1]),statusText=parts[2] if len(parts)>2 else '',httpVersion=parts[0],headers=[{'name':k,'value':safe.get(k,'<value-omitted>')} for k in row['header_names']],content={'size':-1,'mimeType':safe.get('content-type','application/octet-stream')})
            entry['_source']['response_headers_complete']=row.get('headers_complete')
counts=collections.Counter((e['request']['method'],re.sub(r'/[a-f0-9]{24}/snapshot','/{cameraId}/snapshot',e['request']['url'].split('?')[0]),e['response']['status']) for e in entries)
summary=[{'method':k[0],'url_pattern':k[1],'status':k[2],'count':v} for k,v in counts.items()]
har={'log':{'version':'1.2','creator':{'name':'camera-passive-hook-sanitizer','version':'1'},'pages':[],'entries':entries,'comment':'Derived from app plaintext boundary hooks, not packet/proxy HAR. Body values omitted. Query q redacted. Header credentials omitted.'}}
(root/'camera-app-pass7.har').write_text(json.dumps(har,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'camera-app-pass7-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('Derived HAR entries:',len(entries));print(json.dumps(summary,ensure_ascii=True))
