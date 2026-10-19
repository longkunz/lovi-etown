"""Attach passive Frida hook; flush sanitized events as they arrive."""
import argparse, json, time, gzip,hashlib,datetime
from pathlib import Path
import frida
p=argparse.ArgumentParser();p.add_argument('serial');p.add_argument('pid',type=int);p.add_argument('output');p.add_argument('--duration',type=int,default=120);p.add_argument('--spawn',action='store_true');p.add_argument('--body-shapes',action='store_true');a=p.parse_args()
buffers={};done=set()
def shape(v,depth=0):
    if depth>5:return type(v).__name__
    if isinstance(v,dict):return {k:shape(x,depth+1) for k,x in v.items()}
    if isinstance(v,list):return {'type':'array','count':len(v),'first_item_shape':shape(v[0],depth+1) if v else None}
    return type(v).__name__
def consume(payload,data):
    key=payload['connection']
    if key in done:return None
    b=buffers.get(key,b'')+data
    if len(b)>2097152:done.add(key);buffers.pop(key,None);return None
    buffers[key]=b
    if b'\r\n\r\n' not in b:return None
    head,body=b.split(b'\r\n\r\n',1)
    h={line.split(b':',1)[0].lower():line.split(b':',1)[1].strip() for line in head.split(b'\r\n')[1:] if b':' in line}
    if h.get(b'transfer-encoding',b'').lower()==b'chunked':
        outbody=b'';pos=0
        while True:
            e=body.find(b'\r\n',pos)
            if e<0:return None
            size=int(body[pos:e].split(b';')[0],16);pos=e+2
            if size==0:body=outbody;break
            if len(body)<pos+size+2:return None
            outbody+=body[pos:pos+size];pos+=size+2
    elif b'content-length' in h:
        length=int(h[b'content-length'])
        if len(body)<length:return None
        body=body[:length]
    else:return None
    if h.get(b'content-encoding')==b'gzip':body=gzip.decompress(body)
    value=json.loads(body);done.add(key);buffers.pop(key,None)
    camera=[]
    def visit(v,path=''):
        if isinstance(v,dict):
            for k,x in v.items():
                if k in ('url-api-camera','area-camera'):camera.append({'path':path+'/'+k,'value':x})
                visit(x,path+'/'+k)
        elif isinstance(v,list):
            for i,x in enumerate(v):visit(x,path+'/'+str(i))
    visit(value)
    return {'kind':'app-response-body-shape','time':round(time.time()*1000),'request':payload['request'],'decoded_bytes':len(body),'decoded_sha256':hashlib.sha256(body).hexdigest(),'shape':shape(value),'camera_config_fields':camera,'raw_body_retained':False}
with Path(a.output).open('w',encoding='utf-8') as out:
    def message(msg,data):
        if msg['type']=='send' and msg.get('payload',{}).get('kind')=='body-chunk':
            try:row=consume(msg['payload'],data)
            except (ValueError,EOFError,OSError):return
            if row is None:return
        elif msg['type']=='log':
            try: row=json.loads(msg['payload'])
            except ValueError:return
        elif msg['type']=='error':row={'kind':'hook-error','description':msg.get('description')}
        else:return
        if row.get('kind')=='app-http-request':buffers.pop(row['connection'],None);done.discard(row['connection'])
        out.write(json.dumps(row,ensure_ascii=False)+'\n');out.flush()
    device=frida.get_device(a.serial)
    pid=device.spawn(['com.fts.notis']) if a.spawn else a.pid
    session=device.attach(pid)
    code=('globalThis.CAPTURE_CAMERA_BODY=true;\n' if a.body_shapes else '')+Path('scripts/observe-camera-http-pass7.js').read_text()
    script=session.create_script(code)
    script.set_log_handler(lambda level, text: message({'type':'log','payload':text},None))
    script.on('message',message);script.load()
    out.write(json.dumps({'kind':'observer-start','time':round(time.time()*1000),'pid':pid,'serial':a.serial})+'\n');out.flush()
    if a.spawn:device.resume(pid)
    print('Attached passive HTTP observer',flush=True)
    try:time.sleep(a.duration)
    finally:
        script.unload();session.detach()
        out.write(json.dumps({'kind':'observer-end','time':round(time.time()*1000),'pid':pid})+'\n');out.flush()
