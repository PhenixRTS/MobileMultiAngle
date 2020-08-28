/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import com.phenixrts.express.*
import com.phenixrts.pcast.RendererOptions
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.suite.phenixmultiangle.BuildConfig
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import java.io.Serializable

// The delay before starting to draw bitmaps on surface
const val THUMBNAIL_DRAW_DELAY = 100L
// SDK issue - cannot reliable create chat service right after joining room
const val CHAT_SERVICE_DELAY = 2000L
const val MESSAGE_FILTER = "CC"
const val MESSAGE_BATCH_SIZE = 10
const val QUERY_URI = "uri"
const val QUERY_BACKEND = "backend"
const val QUERY_EDGE_AUTH = "edgeauth"
const val QUERY_CHANNEL_ALIASES = "channelAliases"
val DEFAULT_HIGHLIGHT = Highlight.FAR

data class ChannelExpressConfiguration(
    val uri: String = BuildConfig.PCAST_URL,
    val backend: String = BuildConfig.BACKEND_URL,
    val edgeAuth: String? = null,
    val channelAliases: List<String> = listOf()
) : Serializable

fun getChannelConfiguration(channelAlias: String, surface: AndroidVideoRenderSurface): JoinChannelOptions {
    val joinRoomOptions = RoomExpressFactory.createJoinRoomOptionsBuilder()
        .withRoomAlias(channelAlias)
        .withCapabilities(arrayOf("real-time"))
        .buildJoinRoomOptions()
    return ChannelExpressFactory
        .createJoinChannelOptionsBuilder()
        .withJoinRoomOptions(joinRoomOptions)
        .withRenderer(surface)
        .withRendererOptions(RendererOptions())
        .buildJoinChannelOptions()
}
