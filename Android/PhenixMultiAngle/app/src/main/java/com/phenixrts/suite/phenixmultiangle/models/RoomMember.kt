/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import android.os.Handler
import android.view.SurfaceView
import android.view.View
import androidx.lifecycle.MutableLiveData
import com.phenixrts.common.Disposable
import com.phenixrts.express.ExpressSubscriber
import com.phenixrts.pcast.Renderer
import com.phenixrts.pcast.RendererStartStatus
import com.phenixrts.pcast.TimeShift
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.room.Member
import com.phenixrts.suite.phenixmultiangle.common.*
import timber.log.Timber
import java.util.*
import kotlin.coroutines.suspendCoroutine

data class RoomMember(val member: Member) {

    private var surface: SurfaceView? = null
    private var mask: View? = null
    private var renderer: Renderer? = null
    private var expressSubscriber: ExpressSubscriber? = null
    private val videoRenderSurface = AndroidVideoRenderSurface()
    private var bandwidthLimiter: Disposable? = null
    private var timeShiftDisposable: Disposable? = null
    private var timeShift: TimeShift? = null
    private var timeShiftCreationInitiated: Boolean = false

    var isMainRendered: Boolean = false
    var isRendererStarted: Boolean = false
    val onTimeShiftReady = MutableLiveData<Boolean>().apply { value = false }

    private fun limitBandwidth() {
        Timber.d("Limiting Bandwidth: ${toString()}")
        bandwidthLimiter =
            expressSubscriber?.videoTracks?.getOrNull(0)?.limitBandwidth(BANDWIDTH_LIMIT)
    }

    private fun releaseBandwidthLimiter() {
        Timber.d("Releasing Bandwidth limiter: ${toString()}")
        bandwidthLimiter?.dispose()
        bandwidthLimiter = null
    }

    private fun createTimeShift(startTime: Long) {
        if (renderer?.isSeekable == false) return
        if (!timeShiftCreationInitiated) {
            timeShiftCreationInitiated = true

            Handler().postDelayed({
                timeShift = renderer?.seek(Date(startTime + SEEK_DELAY))
                subscribeToTimeShiftReadyForPlaybackObservable()
            }, TIME_SHIFT_CREATION_DELAY)
        }
    }

    private fun subscribeToTimeShiftReadyForPlaybackObservable() {
        timeShiftDisposable?.dispose()

        timeShift?.observableReadyForPlaybackStatus?.subscribe { isReady ->
            launchMain {
                Timber.d("Playback status: $isReady, ${this@RoomMember.asString()}")
                onTimeShiftReady.value = isReady
            }
        }.run { timeShiftDisposable = this }
    }

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

    fun setSurface(surfaceView: SurfaceView, surfaceMask: View, isMainRenderer: Boolean = false) =
        launchMain {
            mask = surfaceMask
            surface = surfaceView
            videoRenderSurface.setSurfaceHolder(surfaceView.holder)
            if (isMainRenderer) {
                releaseBandwidthLimiter()
            } else {
                limitBandwidth()
            }
            hideMask()
            Timber.d("Changed member surface: ${this@RoomMember.asString()}")
        }

    fun startVideoRenderer(startTime: Long): RendererStartStatus {
        if (renderer == null) {
            renderer = expressSubscriber?.createRenderer()
        }
        muteAudio()
        val status = renderer?.start(videoRenderSurface) ?: RendererStartStatus.FAILED
        createTimeShift(startTime)
        isRendererStarted = status == RendererStartStatus.OK
        Timber.d("Started video renderer: $status : ${toString()}")
        return status
    }

    fun startVideoReplay() {
        Timber.d("Looping time shift: ${renderer?.isSeekable}, ${toString()}")
        if (renderer?.isSeekable == false) return
        timeShift?.loop(REPLAY_LOOP_DURATION)
    }

    fun endVideoReplay() {
        Timber.d("Stopping time shift: ${toString()}")
        timeShift?.stop()

        // Need to re-subscribe to observable in order to become ready again:
        subscribeToTimeShiftReadyForPlaybackObservable()
    }

    override fun toString(): String {
        return "{\"name\":\"${member.observableScreenName.value}\"," +
                "\"hasRenderer\":\"${renderer != null}\"," +
                "\"surfaceId\":\"${surface?.id}\"," +
                "\"isSubscribed\":\"${expressSubscriber != null}\"," +
                "\"isMainRendered\":\"$isMainRendered\"}"
    }

    private companion object {
        private const val BANDWIDTH_LIMIT = 1000 * 350L
    }
}
