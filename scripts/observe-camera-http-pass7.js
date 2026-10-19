// Passive plaintext boundary hooks found in exact runtime libflutter x86_64.
// No certificate checks, buffers, requests or return values are modified.
// Raw bodies, credential values and geocoding query values are not retained.
let installed=false;
function install(m){
if(installed)return;installed=true;
const contexts=new Map(),pendingHeaders=new Map();
const offsets=[0x7fb4df,0x7fa9eb];
function parse(buf,n,off,direction,key){
 if(n<1||n>2097152)return;
 try{
  const a=new Uint8Array(buf.readByteArray(Math.min(n,16384)));
  let s='';for(let i=0;i<a.length;i++){s+=String.fromCharCode(a[i]);if(s.endsWith('\r\n\r\n'))break;}
  if(direction==='return'){
   const old=pendingHeaders.get(key);
   if(old)s=old+s;
   if(!s.startsWith('HTTP/'))return;
   const boundary=s.indexOf('\r\n\r\n');
   if(boundary<0){if(s.length<16384)pendingHeaders.set(key,s);else pendingHeaders.delete(key);return;}
   s=s.slice(0,boundary+4);pendingHeaders.delete(key);
  }
  if(!/^(GET |POST |HEAD |PUT |DELETE |PATCH |HTTP\/)/.test(s))return;
  const lines=s.split('\r\n'),first=lines[0],headers={};
  for(const line of lines.slice(1)){const i=line.indexOf(':');if(i>0)headers[line.slice(0,i).toLowerCase()]=line.slice(i+1).trim();}
  const redacted=first.replace(/([?&]([^=\s&]+))=([^&\s]*)/g,(all,p,k,v)=>/^(lat|lng|lat1|lng1|lat2|lng2|distance|radius|page|limit|zoom)$/.test(k)&&/^-?[0-9.]+$/.test(v)?all:p+'=<redacted>');
  const request=/^(GET |POST |HEAD |PUT |DELETE |PATCH )/.test(first);
  if(request)contexts.set(key,{line:redacted,host:headers.host||null});
  const safeHeaders={};for(const k of ['content-type','content-length','cache-control','etag','last-modified','expires','age','vary','retry-after','content-encoding','transfer-encoding'])if(headers[k])safeHeaders[k]=headers[k];
  console.log(JSON.stringify({kind:request?'app-http-request':'app-http-response',time:Date.now(),pid:Process.id,native_offset:'0x'+off.toString(16),direction,connection:key,line:redacted,host:headers.host||null,request:request?undefined:contexts.get(key)||null,header_names:Object.keys(headers),authorization_scheme:headers.authorization?(/^Bearer\s/i.test(headers.authorization)?'Bearer':'present-other'):null,safe_headers:safeHeaders,buffer_bytes:n,headers_complete:s.endsWith('\r\n\r\n')}));
 }catch(e){}
}
for(const off of offsets)Interceptor.attach(m.base.add(off),{
 onEnter(args){this.b=args[1];this.key=args[0].toString();if(off===0x7fb4df)parse(args[1],args[2].toInt32(),off,'entry',this.key);},
  onLeave(ret){if(off===0x7fa9eb){
   const n=ret.toInt32();parse(this.b,n,off,'return',this.key);
   const req=contexts.get(this.key);
   if(globalThis.CAPTURE_CAMERA_BODY===true&&n>0&&n<=2097152&&req&&(/GET \/(?:tenants |ttgt-tphcm\/configs\/homepage |ttgt-tphcm\/routing\/geocoding\?|v4\/cameras(?:\?|\/bybbox\?))/.test(req.line))){
    send({kind:'body-chunk',connection:this.key,request:req},this.b.readByteArray(n));
   }
  }}
});
console.log(JSON.stringify({kind:'attached',pid:Process.id,offsets:offsets.map(x=>'0x'+x.toString(16)),artifact_sha256:'eb1159947b57f7119a24fc6aa39ce5cee39b86ea5549d6a4848950eb8ab687f8'}));
}
Process.attachModuleObserver({onAdded(m){if(m.name==='libflutter.so')install(m);}});
