package com.example.spotify_ad_skipper

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class SpotifyNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName

        if (packageName == "com.spotify.music") {
            println("Spotify notification received: $packageName")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        val packageName = sbn.packageName

        if (packageName == "com.spotify.music") {
            println("Spotify notification removed: $packageName")
        }
    }
}
