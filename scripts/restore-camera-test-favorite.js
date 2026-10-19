// Restore only the singleton favorite introduced by this investigation.
Java.perform(function () {
  const app=Java.use('android.app.ActivityThread').currentApplication();
  const prefs=app.getSharedPreferences('FlutterSharedPreferences',0);
  const key='flutter.CameraCare_ttgt-tphcm';
  const raw=prefs.getString(key,'[]').toString();
  const rows=JSON.parse(raw);
  if(rows.length===1 && rows[0]._id==='5deb576d1dc17d7c5515ad13') {
    console.log(JSON.stringify({action:'restore-initial-empty-favorites',committed:prefs.edit().putString(key,'[]').commit()}));
  } else {
    console.log(JSON.stringify({action:'no-change',reason:'current favorites differ from investigation singleton',count:rows.length}));
  }
});
