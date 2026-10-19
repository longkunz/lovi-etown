// Passive metadata only: native call frames for app sockets on port 443.
const libc=Process.getModuleByName('libc.so');
const peer=new NativeFunction(libc.getExportByName('getpeername'),'int',['int','pointer','pointer']);
let count=0;
for(const name of ['sendto','write','writev','sendmsg']) Interceptor.attach(libc.getExportByName(name),{
 onEnter(args){
  if(count>=12)return;
  const b=Memory.alloc(128),n=Memory.alloc(4);n.writeU32(128);
  if(peer(args[0].toInt32(),b,n)!==0)return;
  const a=new Uint8Array(b.readByteArray(28));
  if(a[2]*256+a[3]!==443)return;
  const frames=Thread.backtrace(this.context,Backtracer.FUZZY).map(p=>{const m=Process.findModuleByAddress(p);return {address:p.toString(),module:m?m.name:null,offset:m?p.sub(m.base).toString():null};});
  count++;
  console.log(JSON.stringify({kind:'tls-send-stack',time:Date.now(),pid:Process.id,hook:name,bytes:name==='sendto'||name==='write'?args[2].toInt32():null,frames}));
 }
});
console.log(JSON.stringify({kind:'attached',pid:Process.id}));
