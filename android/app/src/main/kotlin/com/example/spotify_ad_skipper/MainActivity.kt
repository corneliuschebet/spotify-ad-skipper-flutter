package com.example.spotify_ad_skipper

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "spotify_ad_skipper/android"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getPlatformInfo" -> {
                    val info = mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "androidVersion" to Build.VERSION.RELEASE,
                        "sdkInt" to Build.VERSION.SDK_INT
                    )

                    result.success(info)
                }

                "isNotificationListenerEnabled" -> {
                    result.success(false)
                }

                "isSkipperRunning" -> {
                    result.success(false)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
