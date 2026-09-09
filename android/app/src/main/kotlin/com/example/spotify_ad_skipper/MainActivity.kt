package com.example.spotify_ad_skipper

import android.content.Intent
import android.os.Build
import android.provider.Settings
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
                    result.success(isNotificationListenerEnabled())
                }

                "openNotificationListenerSettings" -> {
                    openNotificationListenerSettings()
                    result.success(true)
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

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false

        return enabledListeners
            .split(":")
            .any { componentName ->
                componentName.startsWith(packageName)
            }
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(
            Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
        )

        startActivity(intent)
    }
}
