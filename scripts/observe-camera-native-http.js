// Passive candidate SSL read/write hooks derived from SecureSocket native region.
// Artifact-bound offsets: runtime libflutter SHA256 eb115994...ab687f8, x86_64.
const m=Process.getModuleByName('libflutter.so');
let p=m.base.add(0x97cc30),end=m.base.add(0x985000),targets=new Map(),seen=new Set();
while(p.compare(end)<0){
 try{
  const ins=Instruction.parse(p);
  if(ins.mnemonic==='call'&&ins.operands[0].type==='imm'){
   const t=ptr(ins.operands[0].value),off=t.sub(m.base).toUInt32();
   if(off>=0x4a0000&&off<0x970000)targets.set(t.toString(),off);
  }
  p=ins.next;
 }catch(e){p=p.add(1);}
}
function observe(buf,n,offset,direction){
 if(n<12||n>131072)return;
 try{
  const prefix=buf.readU32();if(prefix!==0x20544547&&prefix!==0x54534f50&&prefix!==0x50545448&&prefix!==0x44414548&&prefix!==0x20545550&&prefix!==0x454c4544)return;
  const s=buf.readUtf8String(Math.min(n,8192));if(!/^(GET |POST |HEAD |PUT |DELETE |HTTP\/)/.test(s))return;
  const lines=s.split('\r\n'),host=(lines.find(x=>/^host:/i.test(x))||'').slice(5).trim();
  const first=lines[0].replace(/([?&][^=\s&]+)=([^&\s]*)/g,'$1=<redacted>');
  const key=direction+host+first;if(seen.has(key))return;seen.add(key);
  const headers=lines.slice(1,lines.indexOf('')>=0?lines.indexOf(''):undefined).filter(x=>/^[\w-]+:/.test(x)).map(x=>x.split(':')[0].toLowerCase());
  console.log(JSON.stringify({kind:'native-http-plaintext',time:Date.now(),pid:Process.id,offset:'0x'+offset.toString(16),direction,line:first,host,header_names:headers,buffer_bytes:n}));
 }catch(e){}
}
for(const [address,off] of targets){
 try{Interceptor.attach(ptr(address),{
  onEnter(args){this.buf=args[1];observe(args[1],args[2].toInt32(),off,'entry');},
  onLeave(ret){observe(this.buf,ret.toInt32(),off,'return');}
 });}catch(e){}
}
console.log(JSON.stringify({kind:'attached',pid:Process.id,candidate_offsets:Array.from(targets.values()).map(x=>'0x'+x.toString(16))}));
