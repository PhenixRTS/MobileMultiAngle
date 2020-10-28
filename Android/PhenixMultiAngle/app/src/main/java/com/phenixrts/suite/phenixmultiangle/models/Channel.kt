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
import com.phenixrts.pcast.SeekOrigin
import com.phenixrts.pcast.TimeShift
import com.phenixrts.pcast.android.AndroidReadVideoFrameCallback
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.room.RoomService
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Bandwidth
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.common.enums.ReplayState
import com.phenixrts.suite.phenixmultiangle.common.enums.StreamStatus
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import timber.log.Timber
import java.util.*
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume

private const val TIME_SHIFT_RETRY_DELAY = 1000 * 10L

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
    private var timeShiftCreateRetryCount = 0

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

    val onTimeShiftState = MutableLiveData<ReplayState>().apply { value = ReplayState.STARTING }
    val isMainRendered= MutableLiveData<Boolean>().apply { value = false }
    val onPlaybackHead = MutableLiveData<Long>().apply { value = 0 }
    val onChannelJoined = MutableLiveData<StreamStatus>()
    var roomService: RoomService? = null
    var selectedHighlight = Highlight.FAR
    var isFullScreen = false

    private fun limitBandwidth(bandwidth: Bandwidth) {
        expressSubscriber?.videoTracks?.getOrNull(0)?.limitBandwidth(bandwidth.value)?.let { disposable ->
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

    private fun updateBandwidth() {
        val bandwidth: Bandwidth = if (isFullScreen) {
            if (isMainRendered.value == true) Bandwidth.UNLIMITED else Bandwidth.ULD
        } else {
            if (isMainRendered.value == true) Bandwidth.HD else Bandwidth.LD
        }
        if (bandwidth == Bandwidth.UNLIMITED) {
            releaseBandwidthLimiter()
        } else {
            limitBandwidth(bandwidth)
        }
    }

    private fun subscribeToTimeShiftReadyForPlaybackObservable() {
        onTimeShiftState.value = ReplayState.STARTING
        Timber.d("Subscribing to time shift observables: ${this@Channel.asString()}")
        timeShift?.observableReadyForPlaybackStatus?.subscribe { isReady ->
            if (onTimeShiftState.value == ReplayState.REPLAYING) return@subscribe
            launchMain {
                val state = if (isReady) ReplayState.READY else ReplayState.STARTING
                if (isReady) timeShiftCreateRetryCount = 0
                if (onTimeShiftState.value != state) {
                    Timber.d("Time shift ready: $isReady, ${this@Channel.asString()}")
                    onTimeShiftState.value = state
                }
            }
        }?.run { timeShiftDisposables.add(this) }
        timeShift?.observablePlaybackHead?.subscribe { head ->
            launchMain {
                val offset = head.time - (timeShift?.startTime?.time ?: 0)
                if (onPlaybackHead.value != offset) {
                    onPlaybackHead.value = offset
                }
            }
        }?.run { timeShiftDisposables.add(this) }
        timeShift?.observableFailure?.subscribe { status ->
            launchMain {
                Timber.d("Time shift failure: $status, retryCount: $timeShiftCreateRetryCount")
                releaseTimeShift()
                if (timeShiftCreateRetryCount < selectedHighlight.minutesAgo / TIME_SHIFT_RETRY_DELAY) {
                    timeShiftCreateRetryCount++
                    delay(TIME_SHIFT_RETRY_DELAY)
                    createTimeShift()
                } else {
                    timeShiftCreateRetryCount = 0
                    onTimeShiftState.value = ReplayState.FAILED
                }
            }
        }?.run { timeShiftDisposables.add(this) }
        Timber.d("Limiting time shift bandwidth to: ${Bandwidth.LD.value}")
        timeShift?.limitBandwidth(Bandwidth.LD.value)?.run { timeShiftDisposables.add(this) }
    }

    private fun updateSurfaces() {
        updateBandwidth()
        thumbnailSurface?.changeVisibility(isMainRendered.value == false)
        bitmapSurface?.changeVisibility(isMainRendered.value == true)
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

    private fun releaseTimeShift() {
        val disposed = timeShiftDisposables.isNotEmpty() || timeShiftSeekDisposables.isNotEmpty()
        timeShiftDisposables.forEach { it.dispose() }
        timeShiftDisposables.clear()
        timeShiftSeekDisposables.forEach { it.dispose() }
        timeShiftSeekDisposables.clear()
        timeShift?.dispose()
        timeShift = null
        if (disposed) {
            Timber.d("Time shift released: ${toString()}")
        }
    }

    private fun renderSubscriber(subscriber: ExpressSubscriber?, expressRenderer: Renderer?) {
        expressSubscriber?.stop()
        renderer?.stop()
        expressSubscriber?.dispose()
        renderer?.dispose()
        expressSubscriber = subscriber
        renderer = expressRenderer
        if (isMainRendered.value == false) {
            muteAudio()
        } else {
            unmuteAudio()
        }
        updateBandwidth()
        createTimeShift()
        setVideoFrameCallback()
        Timber.d("Started subscriber renderer: ${toString()}")
    }

    fun muteAudio() = renderer?.muteAudio()

    fun unmuteAudio() = renderer?.unmuteAudio()

    suspend fun joinChannel() = suspendCancellableCoroutine<Unit> { continuation ->
        Timber.d("Joining channel with alias: $channelAlias")
        val options = getChannelConfiguration(channelAlias, videoRenderSurface)
        channelExpress.joinChannel(options, { requestStatus: RequestStatus?, service: RoomService? ->
            launchMain {
                Timber.d("Channel join status: $requestStatus for: ${asString()}")
                if (requestStatus == RequestStatus.OK) {
                    roomService = service
                } else {
                    onChannelJoined.value = StreamStatus.OFFLINE
                }
                if (continuation.isActive) continuation.resume(Unit)
            }
        }, { requestStatus: RequestStatus?, subscriber: ExpressSubscriber?, renderer: Renderer? ->
            launchMain {
                Timber.d("Stream re-started: $requestStatus for: ${asString()}")
                if (requestStatus == RequestStatus.OK) {
                    renderSubscriber(subscriber, renderer)
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

    fun startVideoReplay(highlight: Highlight) = launchMain {
        if (renderer?.isSeekable == false) return@launchMain
        Timber.d("Looping time shift: ${asString()}")
        timeShift?.loop(highlight.loopLength)
        if (onTimeShiftState.value == ReplayState.READY) {
            onTimeShiftState.value = ReplayState.REPLAYING
        }
    }

    fun endVideoReplay() = launchMain {
        Timber.d("Stopping time shift: ${asString()}")
        timeShift?.stop()
        if (onTimeShiftState.value == ReplayState.REPLAYING) {
            onTimeShiftState.value = ReplayState.READY
        }
    }

    fun createTimeShift() = launchMain {
        Timber.d("Creating time shift: ${renderer?.isSeekable} for: ${asString()}")
        if (renderer == null) {
            return@launchMain
        }
        if (renderer?.isSeekable == false) {
            onTimeShiftState.value = ReplayState.FAILED
            return@launchMain
        }
        onTimeShiftState.value = ReplayState.STARTING
        releaseTimeShift()
        val utcTime = System.currentTimeMillis()
        val offset = utcTime - selectedHighlight.minutesAgo
        Timber.d("UTC time: $utcTime, offset: $offset")
        timeShift = renderer?.seek(Date(offset))
        Timber.d("Time shift created: ${timeShift?.startTime?.time} : $selectedHighlight, offset: $offset, for: ${asString()}")
        subscribeToTimeShiftReadyForPlaybackObservable()
    }

    fun playFromHere(offset: Long) {
        timeShiftSeekDisposables.forEach { it.dispose() }
        timeShiftSeekDisposables.clear()
        timeShift?.run {
            Timber.d("Seeking time shift: $offset")
            seek(offset, SeekOrigin.BEGINNING)?.subscribe { status ->
                Timber.d("Time shift seek status: $status for $offset")
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

    fun getTimestampForProgress(progress: Long) = timeShift?.startTime?.let { date ->
        Date(date.time + TimeUnit.SECONDS.toMillis(progress)).toDateString()
    } ?: ""

    override fun toString(): String {
        return "{\"name\":\"$channelAlias\"," +
                "\"hasRenderer\":\"${renderer != null}\"," +
                "\"surfaceId\":\"${thumbnailSurface?.id}\"," +
                "\"isSeekable\":\"${renderer?.isSeekable}\"," +
                "\"timeShiftState\":\"${onTimeShiftState.value}\"," +
                "\"isSubscribed\":\"${expressSubscriber != null}\"," +
                "\"isMainRendered\":\"${isMainRendered.value}\"}"
    }
}
