package com.example.spotify_ad_skipper

import android.content.ComponentName
import android.media.MediaMetadata
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

    data class PlaybackSnapshot(
        val available: Boolean,
        val title: String,
        val artist: String,
        val playbackState: Int,
        val actions: Long,
        val position: Long,
        val duration: Long,
        val isPlaying: Boolean,
        val isPaused: Boolean
    )

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

            controllers.firstOrNull {
                it.packageName == SPOTIFY_PACKAGE
            }?.also {
                Log.d(
                    TAG,
                    "✅ Spotify media session found"
                )
            } ?: run {
                Log.d(
                    TAG,
                    "❌ No active Spotify media session"
                )
                null
            }

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ Failed to get Spotify controller",
                exception
            )

            null
        }
    }

    fun getPlaybackSnapshot(): PlaybackSnapshot {

        val controller =
            getSpotifyController()

        if (controller == null) {
            return PlaybackSnapshot(
                available = false,
                title = "",
                artist = "",
                playbackState = -1,
                actions = 0L,
                position = 0L,
                duration = 0L,
                isPlaying = false,
                isPaused = false
            )
        }

        val state =
            controller.playbackState

        val metadata =
            controller.metadata

        val playbackState =
            state?.state
                ?: PlaybackState.STATE_NONE

        val actions =
            state?.actions
                ?: 0L

        val title =
            metadata?.getString(
                MediaMetadata.METADATA_KEY_TITLE
            ) ?: ""

        val artist =
            metadata?.getString(
                MediaMetadata.METADATA_KEY_ARTIST
            ) ?: ""

        val position =
            state?.position ?: 0L

        val duration =
            metadata?.getLong(
                MediaMetadata.METADATA_KEY_DURATION
            ) ?: 0L

        return PlaybackSnapshot(
            available = true,
            title = title,
            artist = artist,
            playbackState = playbackState,
            actions = actions,
            position = position,
            duration = duration,
            isPlaying =
                playbackState ==
                    PlaybackState.STATE_PLAYING,
            isPaused =
                playbackState ==
                    PlaybackState.STATE_PAUSED
        )
    }

    fun canPause(): Boolean {
        return hasAction(
            PlaybackState.ACTION_PAUSE
        )
    }

    fun canPlay(): Boolean {
        return hasAction(
            PlaybackState.ACTION_PLAY
        )
    }

    fun canPlayPause(): Boolean {
        return hasAction(
            PlaybackState.ACTION_PLAY_PAUSE
        )
    }

    fun canNext(): Boolean {
        return hasAction(
            PlaybackState.ACTION_SKIP_TO_NEXT
        )
    }

    fun canPrevious(): Boolean {
        return hasAction(
            PlaybackState.ACTION_SKIP_TO_PREVIOUS
        )
    }

    fun pause(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        if (
            !hasAction(
                controller,
                PlaybackState.ACTION_PAUSE
            )
        ) {
            Log.d(
                TAG,
                "❌ Spotify does not currently expose PAUSE"
            )

            return false
        }

        return try {

            Log.d(
                TAG,
                "⏸️ Sending PAUSE"
            )

            controller.transportControls.pause()

            Log.d(
                TAG,
                "✅ PAUSE command sent"
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ PAUSE failed",
                exception
            )

            false
        }
    }

    fun play(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        return try {

            val actions =
                controller.playbackState
                    ?.actions
                    ?: 0L

            if (
                (actions and PlaybackState.ACTION_PLAY) != 0L
            ) {

                Log.d(
                    TAG,
                    "▶️ Sending PLAY"
                )

                controller.transportControls.play()

                Log.d(
                    TAG,
                    "✅ PLAY command sent"
                )

                return true
            }

            if (
                (actions and
                    PlaybackState.ACTION_PLAY_PAUSE) != 0L
            ) {

                Log.d(
                    TAG,
                    "▶️ ACTION_PLAY unavailable; using PLAY_PAUSE"
                )

                controller.transportControls
                    .play()

                Log.d(
                    TAG,
                    "✅ PLAY fallback command sent"
                )

                return true
            }

            Log.d(
                TAG,
                "❌ Spotify does not currently expose PLAY"
            )

            false

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ PLAY failed",
                exception
            )

            false
        }
    }

    fun playPause(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        val actions =
            controller.playbackState
                ?.actions
                ?: 0L

        if (
            (actions and
                PlaybackState.ACTION_PLAY_PAUSE) == 0L
        ) {
            Log.d(
                TAG,
                "❌ Spotify does not expose PLAY_PAUSE"
            )

            return false
        }

        return try {

            Log.d(
                TAG,
                "⏯️ Sending PLAY_PAUSE"
            )

            controller.transportControls
                .play()

            Log.d(
                TAG,
                "✅ PLAY_PAUSE command sent"
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ PLAY_PAUSE failed",
                exception
            )

            false
        }
    }

    fun next(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        if (
            !hasAction(
                controller,
                PlaybackState.ACTION_SKIP_TO_NEXT
            )
        ) {

            Log.d(
                TAG,
                "❌ Spotify does not currently expose SKIP_TO_NEXT"
            )

            return false
        }

        return try {

            val beforeTitle =
                getTrackTitle(controller)

            Log.d(
                TAG,
                "⏭️ Sending SKIP_TO_NEXT"
            )

            Log.d(
                TAG,
                "Current track: $beforeTitle"
            )

            controller.transportControls
                .skipToNext()

            Log.d(
                TAG,
                "✅ SKIP_TO_NEXT command sent"
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ SKIP_TO_NEXT failed",
                exception
            )

            false
        }
    }

    fun previous(): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        if (
            !hasAction(
                controller,
                PlaybackState.ACTION_SKIP_TO_PREVIOUS
            )
        ) {

            Log.d(
                TAG,
                "❌ Spotify does not currently expose SKIP_TO_PREVIOUS"
            )

            return false
        }

        return try {

            Log.d(
                TAG,
                "⏮️ Sending SKIP_TO_PREVIOUS"
            )

            controller.transportControls
                .skipToPrevious()

            Log.d(
                TAG,
                "✅ SKIP_TO_PREVIOUS command sent"
            )

            true

        } catch (exception: Exception) {

            Log.e(
                TAG,
                "❌ SKIP_TO_PREVIOUS failed",
                exception
            )

            false
        }
    }

    fun inspectAndSkip(): Boolean {

        val snapshot =
            getPlaybackSnapshot()

        if (!snapshot.available) {
            return false
        }

        Log.d(
            TAG,
            "━━━━━━━━ MEDIA SESSION DIAGNOSTIC ━━━━━━━━"
        )

        Log.d(
            TAG,
            "Track: ${snapshot.title}"
        )

        Log.d(
            TAG,
            "Artist: ${snapshot.artist}"
        )

        Log.d(
            TAG,
            "Playback state: ${snapshot.playbackState}"
        )

        Log.d(
            TAG,
            "Actions: ${snapshot.actions}"
        )

        Log.d(
            TAG,
            "Position: ${snapshot.position} ms"
        )

        Log.d(
            TAG,
            "Duration: ${snapshot.duration} ms"
        )

        decodeActions(snapshot.actions)

        Log.d(
            TAG,
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        return false
    }

    private fun hasAction(
        action: Long
    ): Boolean {

        val controller =
            getSpotifyController()
                ?: return false

        return hasAction(
            controller,
            action
        )
    }

    private fun hasAction(
        controller: MediaController,
        action: Long
    ): Boolean {

        val actions =
            controller.playbackState
                ?.actions
                ?: 0L

        return (actions and action) != 0L
    }

    private fun getTrackTitle(
        controller: MediaController
    ): String {

        return controller.metadata
            ?.getString(
                MediaMetadata.METADATA_KEY_TITLE
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
