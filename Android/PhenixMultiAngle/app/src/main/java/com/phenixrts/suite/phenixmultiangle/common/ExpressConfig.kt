/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import com.phenixrts.express.*
import com.phenixrts.pcast.RendererOptions
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.suite.phenixmultiangle.BuildConfig
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

// The delay before starting to draw bitmaps on surface
const val THUMBNAIL_DRAW_DELAY = 100L
const val QUERY_URI = "uri"
const val QUERY_BACKEND = "backend"
const val QUERY_EDGE_AUTH = "edgeauth"
const val QUERY_CHANNEL_ALIASES = "channelAliases"
const val QUERY_MIME_TYPES = "mimetypes"
val DEFAULT_HIGHLIGHT = Highlight.FAR

@Serializable
data class ChannelExpressConfiguration(
    val uri: String = BuildConfig.PCAST_URL,
    val backend: String = BuildConfig.BACKEND_URL,
    val edgeAuth: String? = null,
    val channelAliases: List<String> = listOf(),
    val mimeTypes: List<String> = listOf()
)

fun getChannelConfiguration(channelAlias: String, surface: AndroidVideoRenderSurface): JoinChannelOptions {
    val joinRoomOptions = RoomExpressFactory.createJoinRoomOptionsBuilder()
        .withRoomAlias(channelAlias)
        .withCapabilities(arrayOf("real-time", "time-shift"))
        .buildJoinRoomOptions()
    return ChannelExpressFactory
        .createJoinChannelOptionsBuilder()
        .withJoinRoomOptions(joinRoomOptions)
        .withRenderer(surface)
        .withRendererOptions(RendererOptions())
        .buildJoinChannelOptions()
}

fun String.fromJson(): ChannelExpressConfiguration? = try {
    Json{ ignoreUnknownKeys = true }.decodeFromString(this)
} catch (e: Exception) {
    null
}

fun ChannelExpressConfiguration.toJson(): String = Json.encodeToString(this)
