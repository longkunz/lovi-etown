Java.perform(function(){
 const app=Java.use('android.app.ActivityThread').currentApplication();
 for(const permission of ['android.permission.ACCESS_FINE_LOCATION','android.permission.ACCESS_COARSE_LOCATION'])
  console.log(JSON.stringify({permission,result:app.checkSelfPermission(permission)}));
});
