package com.example.spotify_ad_skipper

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class SpotifyNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "SpotifyAdSkipper"
        private const val SPOTIFY_PACKAGE = "com.spotify.music"
        private const val ADVERTISEMENT_TEXT = "advertisement"

        private var lastNotificationState = ""
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != SPOTIFY_PACKAGE) {
            return
        }

        val notification = sbn.notification
        val extras = notification.extras

        val title =
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
                ?.trim()
                ?: ""

        val text =
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
                ?.trim()
                ?: ""

        val bigText =
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
                ?.trim()
                ?: ""

        if (title.isEmpty() && text.isEmpty() && bigText.isEmpty()) {
            Log.d(TAG, "⚪ IGNORED EMPTY NOTIFICATION")

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "ignored",
                    "reason" to "empty_notification"
                )
            )

            return
        }

        val state = "$title|$text|$bigText"

        if (state == lastNotificationState) {
            return
        }

        lastNotificationState = state

        when {
            isAdvertisement(title, text, bigText) -> {
                Log.d(TAG, "🚨 ADVERTISEMENT DETECTED")
                Log.d(TAG, "Title: $title")
                Log.d(TAG, "Text: $text")
                Log.d(TAG, "BigText: $bigText")

                SpotifyEventBridge.sendEvent(
                    mapOf(
                        "type" to "advertisement",
                        "title" to title,
                        "text" to text,
                        "bigText" to bigText
                    )
                )
            }

            isMusic(title, text) -> {
                Log.d(TAG, "🎵 MUSIC DETECTED")
                Log.d(TAG, "Title: $title")
                Log.d(TAG, "Text: $text")
                Log.d(TAG, "BigText: $bigText")

                SpotifyEventBridge.sendEvent(
                    mapOf(
                        "type" to "music",
                        "title" to title,
                        "text" to text,
                        "bigText" to bigText
                    )
                )
            }

            else -> {
                Log.d(TAG, "⚪ IGNORED SPOTIFY NOTIFICATION")

                SpotifyEventBridge.sendEvent(
                    mapOf(
                        "type" to "ignored",
                        "title" to title,
                        "text" to text,
                        "bigText" to bigText
                    )
                )
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName != SPOTIFY_PACKAGE) {
            return
        }

        Log.d(TAG, "Spotify notification removed")

        SpotifyEventBridge.sendEvent(
            mapOf(
                "type" to "notification_removed"
            )
        )
    }

    private fun isAdvertisement(
        title: String,
        text: String,
        bigText: String
    ): Boolean {
        return title.contains(ADVERTISEMENT_TEXT, ignoreCase = true) ||
            text.contains(ADVERTISEMENT_TEXT, ignoreCase = true) ||
            bigText.contains(ADVERTISEMENT_TEXT, ignoreCase = true)
    }

    private fun isMusic(
        title: String,
        text: String
    ): Boolean {
        return title.isNotEmpty() && text.isNotEmpty()
    }
}
