package com.dishcovery.dishcovery

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
 override fun configureFlutterEngine(engine: FlutterEngine) {
  super.configureFlutterEngine(engine)
  MethodChannel(engine.dartExecutor.binaryMessenger,"com.dishcovery/android").setMethodCallHandler { call, result ->
   try { when(call.method) {
    "share" -> {startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {type="text/plain";putExtra(Intent.EXTRA_TEXT,call.argument<String>("text"))},"Share recipe")); result.success(null)}
    "openUrl" -> {val uri=Uri.parse(call.argument<String>("url"));if(uri.scheme!="https")throw IllegalArgumentException("Only HTTPS links are supported");startActivity(Intent(Intent.ACTION_VIEW,uri));result.success(null)}
    "timer" -> {
     if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),43);result.error("permission","Allow notifications, then start the timer again",null)} else {
      val seconds=call.argument<Int>("seconds")?:0
      require(seconds in 1..86400)
      val intent=Intent(this,KitchenTimerReceiver::class.java).putExtra("title",call.argument<String>("title"))
      val pending=PendingIntent.getBroadcast(this,17,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
      val alarm=getSystemService(ALARM_SERVICE) as AlarmManager
      // Inexact reminder avoids requesting special exact-alarm access; Android may delay it.
      alarm.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP,SystemClock.elapsedRealtime()+seconds*1000L,pending)
      result.success(null)
     }
    }
    "cancelTimer" -> {val pending=PendingIntent.getBroadcast(this,17,Intent(this,KitchenTimerReceiver::class.java),PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE);if(pending!=null){(getSystemService(ALARM_SERVICE) as AlarmManager).cancel(pending);pending.cancel()};result.success(null)}
    else -> result.notImplemented()
   }}catch(e:Exception){result.error("android_api",e.message,null)}
  }
 }
}
class KitchenTimerReceiver : BroadcastReceiver(){
 override fun onReceive(context:Context,intent:Intent){
  val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  if(Build.VERSION.SDK_INT>=26)manager.createNotificationChannel(NotificationChannel("cooking","Cooking reminders",NotificationManager.IMPORTANCE_HIGH))
  val open=PendingIntent.getActivity(context,18,Intent(context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(context,"cooking")else Notification.Builder(context)
  try{manager.notify(17,builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("Cooking timer finished").setContentText(intent.getStringExtra("title")?:"Check your dish").setContentIntent(open).setAutoCancel(true).build())}catch(_:SecurityException){}
 }
}
