package com.example.spotify_ad_skipper

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class SpotifyNotificationListener : NotificationListenerService() {

    private lateinit var spotifyMediaController: SpotifyMediaController

    companion object {

        private const val TAG = "SpotifyAdSkipper"
        private const val SPOTIFY_PACKAGE = "com.spotify.music"
        private const val ADVERTISEMENT_TEXT = "advertisement"

        private var lastNotificationState = ""

        /**
         * Active Spotify media controller.
         *
         * MainActivity can use this to send playback commands
         * through the existing notification-listener service.
         */
        private var controllerInstance: SpotifyMediaController? = null

        fun getMediaController(): SpotifyMediaController? {
            return controllerInstance
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()

        spotifyMediaController = SpotifyMediaController(this)

        controllerInstance = spotifyMediaController

        Log.d(
            TAG,
            "✅ Spotify notification listener connected"
        )

        Log.d(
            TAG,
            "🎛️ Media session controller initialized"
        )
    }

    override fun onListenerDisconnected() {

        controllerInstance = null

        Log.d(
            TAG,
            "⚠️ Spotify notification listener disconnected"
        )

        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(
        sbn: StatusBarNotification
    ) {

        if (sbn.packageName != SPOTIFY_PACKAGE) {
            return
        }

        val notification = sbn.notification
        val extras = notification.extras

        val title =
            extras
                .getCharSequence(Notification.EXTRA_TITLE)
                ?.toString()
                ?.trim()
                ?: ""

        val text =
            extras
                .getCharSequence(Notification.EXTRA_TEXT)
                ?.toString()
                ?.trim()
                ?: ""

        val bigText =
            extras
                .getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?.toString()
                ?.trim()
                ?: ""

        /*
         * Ignore completely empty Spotify notifications.
         */
        if (
            title.isEmpty() &&
            text.isEmpty() &&
            bigText.isEmpty()
        ) {

            Log.d(
                TAG,
                "⚪ IGNORED EMPTY NOTIFICATION"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "ignored",
                    "reason" to "empty_notification"
                )
            )

            return
        }

        /*
         * Prevent duplicate events when Spotify posts
         * the exact same notification state repeatedly.
         */
        val state = "$title|$text|$bigText"

        if (state == lastNotificationState) {
            return
        }

        lastNotificationState = state

        when {

            /*
             * Advertisement detected.
             */
            isAdvertisement(
                title,
                text,
                bigText
            ) -> {

                Log.d(
                    TAG,
                    "🚨 ADVERTISEMENT DETECTED"
                )

                Log.d(
                    TAG,
                    "Title: $title"
                )

                Log.d(
                    TAG,
                    "Text: $text"
                )

                Log.d(
                    TAG,
                    "BigText: $bigText"
                )

                Log.d(
                    TAG,
                    "Notification key: ${sbn.key}"
                )

                SpotifyEventBridge.sendEvent(
                    mapOf(
                        "type" to "advertisement",
                        "title" to title,
                        "text" to text,
                        "bigText" to bigText
                    )
                )

                /*
                 * Keep the existing diagnostic behaviour.
                 *
                 * We are NOT implementing automatic skipping
                 * here yet.
                 */
                if (::spotifyMediaController.isInitialized) {

                    spotifyMediaController.inspectAndSkip()

                } else {

                    Log.d(
                        TAG,
                        "⚠️ Media controller not initialized yet"
                    )
                }
            }

            /*
             * Music notification detected.
             */
            isMusic(
                title,
                text
            ) -> {

                Log.d(
                    TAG,
                    "🎵 MUSIC DETECTED"
                )

                Log.d(
                    TAG,
                    "Title: $title"
                )

                Log.d(
                    TAG,
                    "Text: $text"
                )

                Log.d(
                    TAG,
                    "BigText: $bigText"
                )

                SpotifyEventBridge.sendEvent(
                    mapOf(
                        "type" to "music",
                        "title" to title,
                        "text" to text,
                        "bigText" to bigText
                    )
                )
            }

            /*
             * Other Spotify notification.
             */
            else -> {

                Log.d(
                    TAG,
                    "⚪ IGNORED SPOTIFY NOTIFICATION"
                )

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

    override fun onNotificationRemoved(
        sbn: StatusBarNotification
    ) {

        if (sbn.packageName != SPOTIFY_PACKAGE) {
            return
        }

        Log.d(
            TAG,
            "Spotify notification removed"
        )

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

        return title.contains(
            ADVERTISEMENT_TEXT,
            ignoreCase = true
        ) ||
            text.contains(
                ADVERTISEMENT_TEXT,
                ignoreCase = true
            ) ||
            bigText.contains(
                ADVERTISEMENT_TEXT,
                ignoreCase = true
            )
    }

    private fun isMusic(
        title: String,
        text: String
    ): Boolean {

        return title.isNotEmpty() &&
            text.isNotEmpty()
    }
}