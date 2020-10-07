/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import android.graphics.Bitmap
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.lifecycle.MutableLiveData
import com.phenixrts.common.Disposable
import com.phenixrts.common.RequestStatus
import com.phenixrts.express.ChannelExpress
import com.phenixrts.express.ExpressSubscriber
import com.phenixrts.media.video.android.AndroidVideoFrame
import com.phenixrts.pcast.Renderer
import com.phenixrts.pcast.TimeShift
import com.phenixrts.pcast.android.AndroidReadVideoFrameCallback
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.room.RoomService
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.common.enums.StreamStatus
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import timber.log.Timber
import java.util.*
import kotlin.coroutines.resume

private const val BANDWIDTH_LIMIT = 1000 * 520L

data class Channel(
    private val channelExpress: ChannelExpress,
    val channelAlias: String
) {
    private val videoRenderSurface = AndroidVideoRenderSurface()
    private var thumbnailSurface: SurfaceView? = null
    private var bitmapSurface: SurfaceView? = null
    private var renderer: Renderer? = null
    private var expressSubscriber: ExpressSubscriber? = null
    private var timeShift: TimeShift? = null

    private var bandwidthLimiter: Disposable? = null
    private var timeShiftDisposables = mutableListOf<Disposable>()
    private var timeShiftSeekDisposables = mutableListOf<Disposable>()
    private var isBitmapSurfaceAvailable = false
    private var isFirstFrameDrawn = false

    private var bitmapCallback: SurfaceHolder.Callback? = null
    private val frameCallback = Renderer.FrameReadyForProcessingCallback { frameNotification ->
        if (isMainRendered.value == false) return@FrameReadyForProcessingCallback
        frameNotification?.read(object : AndroidReadVideoFrameCallback() {
            override fun onVideoFrameEvent(videoFrame: AndroidVideoFrame?) {
                videoFrame?.bitmap?.let { bitmap ->
                    drawFrameBitmap(bitmap)
                }
            }
        })
    }

    val onTimeShiftReady = MutableLiveData<Boolean>().apply { value = false }
    val isMainRendered= MutableLiveData<Boolean>().apply { value = false }
    val onPlaybackHead = MutableLiveData<Date>().apply { value = Date() }
    val onChannelJoined = MutableLiveData<StreamStatus>()
    var roomService: RoomService? = null
    var isReplaying = false

    private fun limitBandwidth() {
        expressSubscriber?.videoTracks?.getOrNull(0)?.limitBandwidth(BANDWIDTH_LIMIT)?.let { disposable ->
            Timber.d("Bandwidth limited: ${toString()}")
            bandwidthLimiter = disposable
        }
    }

    private fun releaseBandwidthLimiter() {
        bandwidthLimiter?.let { disposable ->
            Timber.d("Bandwidth limiter released: ${toString()}")
            disposable.dispose()
        }
        bandwidthLimiter = null
    }

    private fun subscribeToTimeShiftReadyForPlaybackObservable() = launchMain {
        onTimeShiftReady.value = false
        Timber.d("Subscribing to time shift observables")
        timeShift?.observableReadyForPlaybackStatus?.subscribe { isReady ->
            launchMain {
                if (onTimeShiftReady.value != isReady && !isReplaying) {
                    Timber.d("Time shift ready: $isReady, ${this@Channel.asString()}")
                    onTimeShiftReady.value = isReady
                }
            }
        }?.run { timeShiftDisposables.add(this) }
        timeShift?.observablePlaybackHead?.subscribe { head ->
            launchMain {
                if (onPlaybackHead.value != head) {
                    onPlaybackHead.value = head
                }
            }
        }?.run { timeShiftDisposables.add(this) }
        timeShift?.observableFailure?.subscribe { status ->
            launchMain {
                Timber.d("Time shift failure: $status")
                releaseTimeShift()
                onTimeShiftReady.value = false
            }
        }?.run { timeShiftDisposables.add(this) }
        timeShift?.limitBandwidth(BANDWIDTH_LIMIT)?.run {
            timeShiftDisposables.add(this)
        }
    }

    private fun updateSurfaces() {
        if (isMainRendered.value == false) {
            limitBandwidth()
        } else {
            releaseBandwidthLimiter()
        }
        thumbnailSurface?.setVisible(isMainRendered.value == false)
        bitmapSurface?.setVisible(isMainRendered.value == true)
    }

    private fun setVideoFrameCallback() {
        expressSubscriber?.videoTracks?.getOrNull(0)?.let { videoTrack ->
            val callback = if (isMainRendered.value == false) null else frameCallback
            if (callback == null) isFirstFrameDrawn = false
            renderer?.setFrameReadyCallback(videoTrack, callback)
            Timber.d("Frame callback ${if (callback != null) "set" else "removed"} for: ${toString()}")
        }
    }

    private fun drawFrameBitmap(bitmap: Bitmap) {
        try {
            launchIO {
                if (isMainRendered.value == false || !isBitmapSurfaceAvailable) return@launchIO
                if (isFirstFrameDrawn) delay(THUMBNAIL_DRAW_DELAY)
                bitmapSurface?.drawBitmap(bitmap)
                isFirstFrameDrawn = true
            }
        } catch (e: Exception) {
            Timber.d(e, "Failed to draw bitmap: ${toString()}")
        }
    }

    private fun releaseTimeShiftObservers() {
        isReplaying = false
        val disposed = timeShiftDisposables.isNotEmpty() || timeShiftSeekDisposables.isNotEmpty()
        timeShiftDisposables.forEach { it.dispose() }
        timeShiftDisposables.clear()
        timeShiftSeekDisposables.forEach { it.dispose() }
        timeShiftSeekDisposables.clear()
        if (disposed) {
            Timber.d("Time shift disposables released: ${toString()}")
        }
    }

    private fun releaseTimeShift() {
        releaseTimeShiftObservers()
        timeShift?.run {
            stop()
            dispose()
            Timber.d("Time shift released: ${toString()}")
        }
        timeShift = null
    }

    private fun renderSubscriber(subscriber: ExpressSubscriber?, expressRenderer: Renderer?, startTime: Date) {
        expressSubscriber?.stop()
        renderer?.stop()
        expressSubscriber?.dispose()
        renderer?.dispose()
        expressSubscriber = subscriber
        renderer = expressRenderer
        if (isMainRendered.value == false) {
            limitBandwidth()
            muteAudio()
        } else {
            releaseBandwidthLimiter()
            unmuteAudio()
        }
        createTimeShift(startTime)
        setVideoFrameCallback()
        Timber.d("Started subscriber renderer: ${toString()}")
    }

    fun muteAudio() = renderer?.muteAudio()

    fun unmuteAudio() = renderer?.unmuteAudio()

    suspend fun joinChannel(startTime: Date) = suspendCancellableCoroutine<Unit> { continuation ->
        Timber.d("Joining channel with alias: $channelAlias")
        val options = getChannelConfiguration(channelAlias, videoRenderSurface)
        channelExpress.joinChannel(options, { requestStatus: RequestStatus?, service: RoomService? ->
            launchMain {
                Timber.d("Channel join status: $requestStatus for: ${asString()}")
                if (requestStatus == RequestStatus.OK) {
                    roomService = service
                    onChannelJoined.value = StreamStatus.ONLINE
                } else {
                    onChannelJoined.value = StreamStatus.OFFLINE
                }
                if (continuation.isActive) continuation.resume(Unit)
            }
        }, { requestStatus: RequestStatus?, subscriber: ExpressSubscriber?, renderer: Renderer? ->
            launchMain {
                Timber.d("Stream status: $requestStatus for: ${asString()}")
                if (requestStatus == RequestStatus.OK) {
                    renderSubscriber(subscriber, renderer, startTime)
                    onChannelJoined.value = StreamStatus.ONLINE
                } else {
                    onChannelJoined.value = StreamStatus.OFFLINE
                }
                if (continuation.isActive) continuation.resume(Unit)
            }
        })
    }

    fun setThumbnailSurfaces(thumbnailSurfaceView: SurfaceView, bitmapSurfaceView: SurfaceView) {
        thumbnailSurface = thumbnailSurfaceView
        bitmapSurface = bitmapSurfaceView
        bitmapSurface?.holder?.removeCallback(bitmapCallback)
        bitmapCallback = bitmapSurface?.setCallback { available ->
            isBitmapSurfaceAvailable = available
        }
        if (isMainRendered.value == false) {
            videoRenderSurface.setSurfaceHolder(thumbnailSurfaceView.holder)
            updateSurfaces()
            setVideoFrameCallback()
        }
        Timber.d("Changed member thumbnail surface: ${asString()}")
    }

    fun setMainSurface(surfaceView: SurfaceView?) {
        videoRenderSurface.setSurfaceHolder(surfaceView?.holder ?: thumbnailSurface?.holder)
        updateSurfaces()
        setVideoFrameCallback()
        Timber.d("Changed member main surface: ${asString()}")
    }

    fun startVideoReplay(highlight: Highlight) {
        if (renderer?.isSeekable == false) return
        Timber.d("Looping time shift: ${toString()}")
        timeShift?.loop(highlight.loopLength)
        isReplaying = true
    }

    fun endVideoReplay() {
        Timber.d("Stopping time shift: ${toString()}")
        releaseTimeShiftObservers()
        timeShift?.stop()
        subscribeToTimeShiftReadyForPlaybackObservable()
    }

    fun createTimeShift(startTime: Date) {
        if (renderer?.isSeekable == false) return
        Timber.d("Creating time shift: ${toString()}")
        releaseTimeShift()
        timeShift = renderer?.seek(startTime)
        subscribeToTimeShiftReadyForPlaybackObservable()
    }

    fun playFromHere(selectedTimeStamp: Date) {
        timeShift?.run {
            Timber.d("Seeking time shift: $selectedTimeStamp")
            seek(selectedTimeStamp)?.subscribe { status ->
                Timber.d("Time shift seek status: $status for $selectedTimeStamp")
                if (status == RequestStatus.OK) {
                    play()
                }
            }?.run { timeShiftSeekDisposables.add(this) }
        }
    }

    fun pausePlayback() {
        timeShift?.run {
            Timber.d("Playback paused: ${toString()}")
            pause()
        }
    }

    override fun toString(): String {
        return "{\"name\":\"$channelAlias\"," +
                "\"hasRenderer\":\"${renderer != null}\"," +
                "\"surfaceId\":\"${thumbnailSurface?.id}\"," +
                "\"isSeakable\":\"${renderer?.isSeekable}\"," +
                "\"isTimeShiftReady\":\"${onTimeShiftReady.value}\"," +
                "\"isSubscribed\":\"${expressSubscriber != null}\"," +
                "\"isMainRendered\":\"${isMainRendered.value}\"}"
    }
}
