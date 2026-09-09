package com.example.spotify_ad_skipper

import android.content.ComponentName
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.util.Log

class SpotifyMediaController(
    private val service: SpotifyNotificationListener
) {

    companion object {
        private const val TAG = "SpotifyAdSkipper"
        private const val SPOTIFY_PACKAGE = "com.spotify.music"
    }

    /**
     * Find Spotify's active media session.
     */
    private fun getSpotifyController(): MediaController? {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            Log.e(
                TAG,
                "❌ Media sessions are not available"
            )

            return null
        }

        return try {

            val mediaSessionManager =
                service.getSystemService(
                    MediaSessionManager::class.java
                )

            if (mediaSessionManager == null) {

                Log.e(
                    TAG,
                    "❌ MediaSessionManager unavailable"
                )

                return null
            }

            val componentName = ComponentName(
                service,
                SpotifyNotificationListener::class.java
            )

            val controllers =
                mediaSessionManager.getActiveSessions(
                    componentName
                )

            Log.d(
                TAG,
                "🎛️ Active media sessions: ${controllers.size}"
            )

            val spotifyController =
                controllers.firstOrNull {
                    it.packageName == SPOTIFY_PACKAGE
                }

            if (spotifyController == null) {

                Log.d(
                    TAG,
                    "❌ No active Spotify media session"
                )
            }

            spotifyController

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ Failed to get Spotify controller",
                exception
            )

            null
        }
    }

    /**
     * Test Spotify's NEXT command.
     */
    fun testNext(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        val playbackState =
            controller.playbackState

        val actions =
            playbackState?.actions ?: 0L

        Log.d(
            TAG,
            "🎛️ Spotify actions: $actions"
        )

        if (
            (actions and PlaybackState.ACTION_SKIP_TO_NEXT) == 0L
        ) {

            Log.d(
                TAG,
                "❌ Spotify does not currently expose SKIP_TO_NEXT"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "next_unavailable"
                )
            )

            return false
        }

        return try {

            val beforeTitle =
                getTrackTitle(controller)

            Log.d(
                TAG,
                "⏭️ NEXT TEST"
            )

            Log.d(
                TAG,
                "Current track: $beforeTitle"
            )

            Log.d(
                TAG,
                "Sending SKIP_TO_NEXT"
            )

            controller.transportControls.skipToNext()

            Log.d(
                TAG,
                "✅ SKIP_TO_NEXT command sent"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "next_sent",
                    "trackBefore" to beforeTitle
                )
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ SKIP_TO_NEXT failed",
                exception
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "next_error",
                    "error" to (
                        exception.message
                            ?: "unknown_error"
                    )
                )
            )

            false
        }
    }

    /**
     * Test Spotify's PAUSE command.
     */
    fun testPause(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        val playbackState =
            controller.playbackState

        val actions =
            playbackState?.actions ?: 0L

        if (
            (actions and PlaybackState.ACTION_PAUSE) == 0L
        ) {

            Log.d(
                TAG,
                "❌ Spotify does not currently expose PAUSE"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "pause_unavailable"
                )
            )

            return false
        }

        return try {

            Log.d(
                TAG,
                "⏸️ PAUSE TEST"
            )

            Log.d(
                TAG,
                "Sending PAUSE"
            )

            controller.transportControls.pause()

            Log.d(
                TAG,
                "✅ PAUSE command sent"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "pause_sent"
                )
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ PAUSE failed",
                exception
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "pause_error",
                    "error" to (
                        exception.message
                            ?: "unknown_error"
                    )
                )
            )

            false
        }
    }

    /**
     * Test Spotify's PLAY command.
     */
    fun testPlay(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        val playbackState =
            controller.playbackState

        val actions =
            playbackState?.actions ?: 0L

        if (
            (actions and PlaybackState.ACTION_PLAY) == 0L
        ) {

            Log.d(
                TAG,
                "⚠️ Spotify does not currently expose PLAY"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "play_unavailable"
                )
            )

            return false
        }

        return try {

            Log.d(
                TAG,
                "▶️ PLAY TEST"
            )

            Log.d(
                TAG,
                "Sending PLAY"
            )

            controller.transportControls.play()

            Log.d(
                TAG,
                "✅ PLAY command sent"
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "play_sent"
                )
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ PLAY failed",
                exception
            )

            SpotifyEventBridge.sendEvent(
                mapOf(
                    "type" to "play_error",
                    "error" to (
                        exception.message
                            ?: "unknown_error"
                    )
                )
            )

            false
        }
    }

    /**
     * Inspect Spotify's current media session.
     *
     * This is currently diagnostic only.
     * Automatic ad skipping is NOT performed here yet.
     */
    fun inspectAndSkip(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        inspectController(controller)

        return false
    }

    private fun inspectController(
        controller: MediaController
    ) {

        val playbackState =
            controller.playbackState

        val metadata =
            controller.metadata

        val title =
            metadata?.getString(
                android.media.MediaMetadata.METADATA_KEY_TITLE
            ) ?: ""

        val artist =
            metadata?.getString(
                android.media.MediaMetadata.METADATA_KEY_ARTIST
            ) ?: ""

        val duration =
            metadata?.getLong(
                android.media.MediaMetadata.METADATA_KEY_DURATION
            ) ?: 0L

        val position =
            playbackState?.position ?: 0L

        val bufferedPosition =
            playbackState?.bufferedPosition ?: 0L

        val state =
            playbackState?.state ?: -1

        val actions =
            playbackState?.actions ?: 0L

        Log.d(
            TAG,
            "━━━━━━━━ MEDIA SESSION DIAGNOSTIC ━━━━━━━━"
        )

        Log.d(
            TAG,
            "Package: ${controller.packageName}"
        )

        Log.d(
            TAG,
            "Track: $title"
        )

        Log.d(
            TAG,
            "Artist: $artist"
        )

        Log.d(
            TAG,
            "Playback state: $state"
        )

        Log.d(
            TAG,
            "Actions: $actions"
        )

        Log.d(
            TAG,
            "Position: $position ms"
        )

        Log.d(
            TAG,
            "Buffered: $bufferedPosition ms"
        )

        Log.d(
            TAG,
            "Duration: $duration ms"
        )

        decodeActions(actions)

        Log.d(
            TAG,
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }

    private fun getTrackTitle(
        controller: MediaController
    ): String {

        return controller.metadata
            ?.getString(
                android.media.MediaMetadata.METADATA_KEY_TITLE
            )
            ?: ""
    }

    private fun decodeActions(
        actions: Long
    ) {

        checkAction(
            actions,
            PlaybackState.ACTION_STOP,
            "STOP"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_PAUSE,
            "PAUSE"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_PLAY,
            "PLAY"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_REWIND,
            "REWIND"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_SKIP_TO_PREVIOUS,
            "SKIP_TO_PREVIOUS"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_SKIP_TO_NEXT,
            "SKIP_TO_NEXT"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_FAST_FORWARD,
            "FAST_FORWARD"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_SET_RATING,
            "SET_RATING"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_SEEK_TO,
            "SEEK_TO"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_PLAY_PAUSE,
            "PLAY_PAUSE"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_PLAY_FROM_MEDIA_ID,
            "PLAY_FROM_MEDIA_ID"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_PLAY_FROM_SEARCH,
            "PLAY_FROM_SEARCH"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_SKIP_TO_QUEUE_ITEM,
            "SKIP_TO_QUEUE_ITEM"
        )

        checkAction(
            actions,
            PlaybackState.ACTION_PLAY_FROM_URI,
            "PLAY_FROM_URI"
        )

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.N
        ) {

            checkAction(
                actions,
                PlaybackState.ACTION_PREPARE,
                "PREPARE"
            )

            checkAction(
                actions,
                PlaybackState.ACTION_PREPARE_FROM_MEDIA_ID,
                "PREPARE_FROM_MEDIA_ID"
            )

            checkAction(
                actions,
                PlaybackState.ACTION_PREPARE_FROM_SEARCH,
                "PREPARE_FROM_SEARCH"
            )

            checkAction(
                actions,
                PlaybackState.ACTION_PREPARE_FROM_URI,
                "PREPARE_FROM_URI"
            )
        }
    }

    private fun checkAction(
        actions: Long,
        action: Long,
        name: String
    ) {

        if ((actions and action) != 0L) {

            Log.d(
                TAG,
                "✅ ACTION AVAILABLE: $name ($action)"
            )
        }
    }
}