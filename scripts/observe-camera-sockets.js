// App-process outbound socket metadata only. No TLS bypass or payload capture.
const libc=Process.getModuleByName('libc.so');
const peer=new NativeFunction(libc.getExportByName('getpeername'),'int',['int','pointer','pointer']);
function addr(fd){
 const b=Memory.alloc(128),n=Memory.alloc(4); n.writeU32(128);
 if(peer(fd,b,n)!==0)return null;
 const f=b.readU16();
 if(f===10){const a=new Uint8Array(b.readByteArray(28));return {family:f,ip:Array.from(a.slice(8,24)).map(v=>v.toString(16).padStart(2,'0')).join(''),port:a[2]*256+a[3]};}
 if(f!==2)return null;
 const a=new Uint8Array(b.readByteArray(8));
 return {ip:[a[4],a[5],a[6],a[7]].join('.'),port:a[2]*256+a[3]};
}
for(const name of ['sendto','write','writev','sendmsg']) Interceptor.attach(libc.getExportByName(name),{
 onEnter(args){
  const fd=args[0].toInt32(),p=addr(fd); if(!p)return;
  console.log(JSON.stringify({time:Date.now(),kind:name,fd,peer:p,bytes:name==='sendmsg'||name==='writev'?null:args[2].toInt32()}));
 }
});
console.log(JSON.stringify({time:Date.now(),kind:'attached',pid:Process.id}));
