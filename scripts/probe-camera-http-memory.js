// Bounded, camera-only serialized HTTP request candidates; not a wire capture.
const pattern='47 45 54 20 2f';
let budget=256*1024*1024,scanned=0,hits=0,retained=0;
const seen=new Set();
for(const r of Process.enumerateRanges({protection:'rw-',coalesce:true})){
 if(budget<=0)break;const size=Math.min(r.size,budget);budget-=size;scanned+=size;
 try{for(const m of Memory.scanSync(r.base,size,pattern)){
   hits++;const end=r.base.add(size),len=Math.min(3000,end.sub(m.address).toInt32());
   const b=new Uint8Array(m.address.readByteArray(len));
   const s=Array.from(b).map(v=>v>=32&&v<=126||v===10||v===13?String.fromCharCode(v):'\0').join('');
   const line=s.split(/\r?\n/)[0];
   if(!/^GET \/[^\0]*cameras[^\0]* HTTP\/1\.1$/.test(line))continue;
   const host=(s.match(/\r?\nHost:\s*([^\r\n\0]+)/i)||[])[1];
   if(host!=='api.notis.vn')continue;
   let safe=line.replace(/([?&][^=& ]+=)([^& ]*)/g,(all,key,val)=>/^[-0-9.]+$/.test(val)?key+val:key+'[REDACTED]');
   if(seen.has(safe))continue;seen.add(safe);retained++;
   const headers=s.split(/\r?\n/).slice(1).map(x=>(x.match(/^([A-Za-z0-9-]+):/)||[])[1]).filter(Boolean);
   console.log(JSON.stringify({time:Date.now(),kind:'serialized-HTTP-memory-candidate-not-wire-capture',pid:Process.id,address:m.address.toString(),requestLine:safe,host,headerNames:headers}));
 }}catch(e){}
}
console.log(JSON.stringify({kind:'scan-summary',scannedBytes:scanned,hits,retained,scope:'first-256MiB-readable-writable-ranges'}));
