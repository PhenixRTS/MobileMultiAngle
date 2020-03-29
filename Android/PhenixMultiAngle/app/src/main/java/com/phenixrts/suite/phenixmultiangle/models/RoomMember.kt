/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import android.view.SurfaceView
import android.view.View
import com.phenixrts.express.ExpressSubscriber
import com.phenixrts.pcast.Renderer
import com.phenixrts.pcast.RendererStartStatus
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.room.Member
import com.phenixrts.suite.phenixmultiangle.common.fadeIn
import com.phenixrts.suite.phenixmultiangle.common.fadeOut
import kotlinx.coroutines.*
import timber.log.Timber
import kotlin.coroutines.suspendCoroutine

data class RoomMember(val member: Member) {

    private var surface: SurfaceView? = null
    private var mask: View? = null
    private var renderer: Renderer? = null
    private var expressSubscriber: ExpressSubscriber? = null
    private val videoRenderSurface = AndroidVideoRenderSurface()
    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    var isMainRendered: Boolean = false
    var isRendererStarted: Boolean = false

    private fun launch(block: suspend CoroutineScope.() -> Unit) = mainScope.launch(
        context = CoroutineExceptionHandler { _, e ->
            Timber.w("Coroutine failed: ${e.localizedMessage}")
            e.printStackTrace()
        },
        block = block
    )

    private suspend fun hideMask() = suspendCoroutine<Unit> { continuation ->
        mask?.fadeOut(continuation)
    }

    suspend fun showMask() = suspendCoroutine<Unit> { continuation ->
        mask?.fadeIn(continuation)
    }

    fun muteAudio() = renderer?.muteAudio()

    fun unmuteAudio() = renderer?.unmuteAudio()

    fun isSubscribed() = expressSubscriber != null

    fun setSubscriber(subscriber: ExpressSubscriber) {
        expressSubscriber = subscriber
    }

    fun setSurface(surfaceView: SurfaceView, surfaceMask: View) = launch {
        mask = surfaceMask
        surface = surfaceView
        videoRenderSurface.setSurfaceHolder(surfaceView.holder)
        hideMask()
        Timber.d("Changed member surface: ${this@RoomMember.toString()}")
    }

    fun startVideoRenderer(): RendererStartStatus {
        if (renderer == null) {
            renderer = expressSubscriber?.createRenderer()
        }
        muteAudio()
        val status = renderer?.start(videoRenderSurface) ?: RendererStartStatus.FAILED
        isRendererStarted = status == RendererStartStatus.OK
        Timber.d("Started video renderer: $status : ${this@RoomMember.toString()}")
        return status
    }

    override fun toString(): String {
        return "{\"name\":\"${member.observableScreenName.value}\"," +
                "\"hasRenderer\":\"${renderer != null}\"," +
                "\"surfaceId\":\"${surface?.id}\"," +
                "\"isSubscribed\":\"${expressSubscriber != null}\"," +
                "\"isMainRendered\":\"$isMainRendered\"}"
    }
}
