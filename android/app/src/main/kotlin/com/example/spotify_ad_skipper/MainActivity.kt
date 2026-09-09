package com.example.spotify_ad_skipper

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "spotify_ad_skipper/android"

        private const val EVENT_CHANNEL =
            "spotify_ad_skipper/events"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {

        super.configureFlutterEngine(
            flutterEngine
        )

        /*
         * Flutter → Android method channel.
         */
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                /*
                 * Platform information.
                 */
                "getPlatformInfo" -> {

                    val info = mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "androidVersion" to Build.VERSION.RELEASE,
                        "sdkInt" to Build.VERSION.SDK_INT
                    )

                    result.success(info)
                }

                /*
                 * Notification listener status.
                 */
                "isNotificationListenerEnabled" -> {

                    result.success(
                        isNotificationListenerEnabled()
                    )
                }

                /*
                 * Open Android notification listener settings.
                 */
                "openNotificationListenerSettings" -> {

                    openNotificationListenerSettings()

                    result.success(true)
                }

                /*
                 * Check whether our notification listener
                 * currently has a media controller.
                 */
                "isSkipperRunning" -> {

                    val running =
                        SpotifyNotificationListener
                            .getMediaController() != null

                    result.success(running)
                }

                /*
                 * Send NEXT to Spotify.
                 */
                "spotifyNext" -> {

                    val controller =
                        SpotifyNotificationListener
                            .getMediaController()

                    if (controller == null) {

                        result.success(false)

                    } else {

                        result.success(
                            controller.next()
                        )
                    }
                }

                /*
                 * Send PAUSE to Spotify.
                 */
                "spotifyPause" -> {

                    val controller =
                        SpotifyNotificationListener
                            .getMediaController()

                    if (controller == null) {

                        result.success(false)

                    } else {

                        result.success(
                            controller.pause()
                        )
                    }
                }

                /*
                 * Send PLAY to Spotify.
                 */
                "spotifyPlay" -> {

                    val controller =
                        SpotifyNotificationListener
                            .getMediaController()

                    if (controller == null) {

                        result.success(false)

                    } else {

                        result.success(
                            controller.play()
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        /*
         * Android → Flutter event stream.
         */
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(
            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {

                    SpotifyEventBridge.setEventSink(
                        events
                    )
                }

                override fun onCancel(
                    arguments: Any?
                ) {

                    SpotifyEventBridge.setEventSink(
                        null
                    )
                }
            }
        )
    }

    private fun isNotificationListenerEnabled(): Boolean {

        val enabledListeners =
            Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners"
            ) ?: return false

        return enabledListeners
            .split(":")
            .any { componentName ->

                componentName.startsWith(
                    packageName
                )
            }
    }

    private fun openNotificationListenerSettings() {

        val intent = Intent(
            Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
        )

        startActivity(intent)
    }
}