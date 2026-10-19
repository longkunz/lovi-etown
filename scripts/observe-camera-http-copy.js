// Read-only interception of plaintext copies. No TLS validation/proxy changes.
// Retain method/path/header NAMES only. No cookies, tokens or payload bodies.
const lib=Process.getModuleByName('libc.so');
let seen=new Set();
for(const name of ['memcpy','memmove']) Interceptor.attach(lib.getExportByName(name),{
 onEnter(args){
  const n=args[2].toInt32();if(n<16||n>131072)return;
  try{
   const prefix=args[1].readU32();
   if(prefix!==0x20544547&&prefix!==0x54534f50&&prefix!==0x50545448&&prefix!==0x44414548&&prefix!==0x20545550&&prefix!==0x454c4544)return;
   const s=args[1].readUtf8String(Math.min(n,8192));
   if(!/^(GET |POST |HEAD |PUT |DELETE |HTTP\/)/.test(s))return;
   const lines=s.split('\r\n'),first=lines[0];
   const host=(lines.find(x=>/^host:/i.test(x))||'').slice(5).trim();
   const path=first.replace(/([?&][^=\s&]+)=([^&\s]*)/g,'$1=<redacted>');
   const key=host+' '+path;if(seen.has(key))return;seen.add(key);
   const headers=lines.slice(1,lines.indexOf('')>=0?lines.indexOf(''):undefined).filter(x=>/^[\w-]+:/.test(x)).map(x=>x.split(':')[0].toLowerCase());
   const m=Process.findModuleByAddress(this.returnAddress);
   console.log(JSON.stringify({kind:'http-plaintext-copy',time:Date.now(),pid:Process.id,hook:name,line:path,host,header_names:headers,copy_size:n,caller_module:m?m.name:null,caller_offset:m?this.returnAddress.sub(m.base).toString():null}));
  }catch(e){}
 }
});
console.log(JSON.stringify({kind:'attached',pid:Process.id}));
