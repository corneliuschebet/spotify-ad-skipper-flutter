package com.example.spotify_ad_skipper

import io.flutter.plugin.common.EventChannel

object SpotifyEventBridge {

    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun sendEvent(event: Map<String, Any>) {
        eventSink?.success(event)
    }
}
