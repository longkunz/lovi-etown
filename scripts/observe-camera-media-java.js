// Scope to media hosts returned by the camera API; do not retain query values.
Java.perform(function(){
 const URL=Java.use('java.net.URL');
 const Thread=Java.use('java.lang.Thread');
 const open=URL.openConnection.overload();
 open.implementation=function(){
   const u=this.toString().toString();
   if(/camera\.thongtingiaothong\.vn|125\.234\.114\.126/.test(u)){
     const stack=Thread.currentThread().getStackTrace();
     const frames=[];for(let i=0;i<stack.length&&i<15;i++)frames.push(stack[i].getClassName().toString()+'.'+stack[i].getMethodName().toString());
     console.log(JSON.stringify({time:Date.now(),kind:'URL.openConnection',url:u.replace(/\/\/[^/@]+@/,'//[REDACTED]@').replace(/\?.*$/,'?[REDACTED]'),stack:frames}));
   }
   return open.call(this);
 };
 const HTTP=Java.use('com.android.okhttp.internal.huc.HttpURLConnectionImpl');
 const method=HTTP.setRequestMethod.overload('java.lang.String');
 method.implementation=function(value){
   const u=this.getURL().toString().toString();
   if(/camera\.thongtingiaothong\.vn|125\.234\.114\.126/.test(u))
     console.log(JSON.stringify({time:Date.now(),kind:'HttpURLConnection.setRequestMethod',method:value.toString(),url:u.replace(/\?.*$/,'?[REDACTED]')}));
   return method.call(this,value);
 };
 console.log(JSON.stringify({time:Date.now(),kind:'attached-java-media'}));
});
