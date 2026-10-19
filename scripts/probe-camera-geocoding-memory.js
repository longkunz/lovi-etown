// Bounded memory candidate search, not proof of a network request.
const pattern='72 6f 75 74 69 6e 67 2f 67 65 6f 63 6f 64 69 6e 67';
let budget=128*1024*1024,scanned=0,hits=0;
for(const r of Process.enumerateRanges({protection:'rw-',coalesce:true})){
 if(budget<=0)break;
 const size=Math.min(r.size,budget);budget-=size;scanned+=size;
 try{for(const m of Memory.scanSync(r.base,size,pattern)){
   hits++;
   let start=m.address.sub(180);if(start.compare(r.base)<0)start=r.base;
   const end=m.address.add(120),limit=r.base.add(size);
   const len=(end.compare(limit)<0?end:limit).sub(start).toInt32();
   const bytes=new Uint8Array(start.readByteArray(len));
   const s=Array.from(bytes).map(b=>b>=32&&b<=126?String.fromCharCode(b):' ').join('');
   const urls=s.match(/https?:\/\/[^\s]{1,250}routing\/geocoding[^\s]*/g)||[];
   for(const u of urls)console.log(JSON.stringify({kind:'runtime-memory-URL-candidate-not-network',url:u.replace(/\/\/[^/@]+@/,'//[REDACTED]@').replace(/\?.*$/,'?[REDACTED]')}));
 }}catch(e){}
}
console.log(JSON.stringify({kind:'scan-summary',scannedBytes:scanned,hits,scope:'first-128MiB-readable-writable-ranges'}));
