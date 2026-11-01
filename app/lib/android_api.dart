import 'dart:io';
import 'package:flutter/services.dart';

class AndroidApi {
  static const channel = MethodChannel('com.dishcovery/android');
  static Future<void> invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    if (!Platform.isAndroid) return;
    await channel.invokeMethod(method, args);
  }

  static Future<void> share(String text) => invoke('share', {'text': text});
  static Future<void> openUrl(String url) => invoke('openUrl', {'url': url});
  static Future<void> timer(int seconds, String title) =>
      invoke('timer', {'seconds': seconds, 'title': title});
  static Future<void> cancelTimer() => invoke('cancelTimer');
}
