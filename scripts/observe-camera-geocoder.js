// Observe Android geocoding calls in the selected app process; preserve behavior.
Java.perform(function(){
 const G=Java.use('android.location.Geocoder');
 const T=Java.use('java.lang.Thread');
 console.log(JSON.stringify({time:Date.now(),kind:'geocoder-present',present:G.isPresent()}));
 const reverse=G.getFromLocation.overload('double','double','int');
 reverse.implementation=function(lat,lng,max){
   const stack=T.currentThread().getStackTrace(),frames=[];
   for(let i=0;i<stack.length&&i<15;i++) frames.push(stack[i].getClassName().toString()+'.'+stack[i].getMethodName().toString());
   const info={time:Date.now(),kind:'getFromLocation',approx_lat:Math.round(lat*100)/100,approx_lng:Math.round(lng*100)/100,maxResults:max,stack:frames};
   console.log(JSON.stringify({...info,kind:'getFromLocation-enter'}));
   try{const rows=reverse.call(this,lat,lng,max);info.resultCount=rows===null?null:rows.size();console.log(JSON.stringify(info));return rows;}
   catch(e){info.error=String(e).replace(/https?:\/\/\S+/g,'[URL REDACTED]');console.log(JSON.stringify(info));throw e;}
 };
 const hooked=new Set();
 try{
 const asyncReverse=G.getFromLocation.overload('double','double','int','android.location.Geocoder$GeocodeListener');
 asyncReverse.implementation=function(lat,lng,max,listener){
   const name=listener.getClass().getName().toString();
   console.log(JSON.stringify({time:Date.now(),kind:'getFromLocation-async-enter',approx_lat:Math.round(lat*100)/100,approx_lng:Math.round(lng*100)/100,maxResults:max,listenerClass:name}));
   if(!hooked.has(name)){
     hooked.add(name);const C=Java.use(name);
     const ok=C.onGeocode.overload('java.util.List');
     ok.implementation=function(rows){console.log(JSON.stringify({time:Date.now(),kind:'onGeocode',listenerClass:name,resultCount:rows===null?null:rows.size()}));return ok.call(this,rows);};
     try{const fail=C.onError.overload('java.lang.String');fail.implementation=function(error){console.log(JSON.stringify({time:Date.now(),kind:'onGeocode-error',listenerClass:name,error:String(error)}));return fail.call(this,error);};}catch(e){}
   }
   return asyncReverse.call(this,lat,lng,max,listener);
 };
 }catch(e){console.log(JSON.stringify({kind:'async-geocoder-unavailable',reason:String(e)}));}
});
