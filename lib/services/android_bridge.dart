import 'dart:async';

import 'package:flutter/services.dart';

class AndroidBridge {
  static const MethodChannel _channel = MethodChannel(
    'spotify_ad_skipper/android',
  );

  static const EventChannel _eventChannel = EventChannel(
    'spotify_ad_skipper/events',
  );

  static Future<Map<String, dynamic>> getPlatformInfo() async {
    final result = await _channel.invokeMethod<Map>('getPlatformInfo');

    return Map<String, dynamic>.from(result ?? {});
  }

  static Future<bool> isNotificationListenerEnabled() async {
    final result = await _channel.invokeMethod<bool>(
      'isNotificationListenerEnabled',
    );

    return result ?? false;
  }

  static Future<void> openNotificationListenerSettings() async {
    await _channel.invokeMethod<void>('openNotificationListenerSettings');
  }

  static Future<bool> isSkipperRunning() async {
    final result = await _channel.invokeMethod<bool>('isSkipperRunning');

    return result ?? false;
  }

  /// Send NEXT to Spotify.
  static Future<bool> spotifyNext() async {
    final result = await _channel.invokeMethod<bool>('spotifyNext');

    return result ?? false;
  }

  /// Send PAUSE to Spotify.
  static Future<bool> spotifyPause() async {
    final result = await _channel.invokeMethod<bool>('spotifyPause');

    return result ?? false;
  }

  /// Send PLAY to Spotify.
  static Future<bool> spotifyPlay() async {
    final result = await _channel.invokeMethod<bool>('spotifyPlay');

    return result ?? false;
  }

  static Stream<Map<String, dynamic>> get spotifyEvents {
    return _eventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
  }
}
