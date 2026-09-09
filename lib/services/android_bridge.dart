import 'package:flutter/services.dart';

class AndroidBridge {
  static const MethodChannel _channel =
      MethodChannel('spotify_ad_skipper/android');

  static Future<Map<String, dynamic>> getPlatformInfo() async {
    final result = await _channel.invokeMethod<Map>('getPlatformInfo');

    return Map<String, dynamic>.from(result ?? {});
  }

  static Future<bool> isNotificationListenerEnabled() async {
    final result =
        await _channel.invokeMethod<bool>('isNotificationListenerEnabled');

    return result ?? false;
  }

  static Future<void> openNotificationListenerSettings() async {
    await _channel.invokeMethod<void>(
      'openNotificationListenerSettings',
    );
  }

  static Future<bool> isSkipperRunning() async {
    final result = await _channel.invokeMethod<bool>('isSkipperRunning');

    return result ?? false;
  }
}
