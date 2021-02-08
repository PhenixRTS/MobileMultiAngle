/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.view.SurfaceView
import android.widget.ImageView
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
private const val TIME_SHIFT_START_WAIT_TIME = 1000 * 20L

data class Channel(
    private val channelExpress: ChannelExpress,
    val channelAlias: String
) {
    private val videoRenderSurface = AndroidVideoRenderSurface()
    private var thumbnailSurface: SurfaceView? = null
    private var thumbnailBitmap: ImageView? = null
    private var renderer: Renderer? = null
    private var expressSubscriber: ExpressSubscriber? = null
    private var timeShift: TimeShift? = null

    private var bandwidthLimiter: Disposable? = null
    private var timeShiftDisposables = mutableListOf<Disposable>()
    private var timeShiftSeekDisposables = mutableListOf<Disposable>()
    private var isFirstFrameDrawn = false
    private var timeShiftCreateRetryCount = 0

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

    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        launchMain {
            updateTimeShiftState(ReplayState.FAILED)
        }
    }

    val onTimeShiftState = MutableLiveData<ReplayState>().apply { value = ReplayState.STARTING }
    val onTimeShiftLoading = MutableLiveData<Boolean>().apply { value = false }
    val isMainRendered= MutableLiveData<Boolean>().apply { value = false }
    val onPlaybackHead = MutableLiveData<Long>().apply { value = 0 }
    val onChannelJoined = MutableLiveData<StreamStatus>()
    val onReplayReady = ConsumableLiveData<Boolean>()
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

    private fun updateTimeShiftState(state: ReplayState) {
        if (state == ReplayState.STARTING) {
            timeoutHandler.postDelayed(timeoutRunnable, TIME_SHIFT_START_WAIT_TIME)
        } else {
            timeoutHandler.removeCallbacks(timeoutRunnable)
        }
        if (onTimeShiftState.value != state) {
            Timber.d("Time shift state changed: $state for: ${this@Channel.asString()}")
            onTimeShiftState.value = state
        }
    }

    private fun subscribeToTimeShiftReadyForPlaybackObservable() {
        updateTimeShiftState(ReplayState.STARTING)
        Timber.d("Subscribing to time shift observables: ${this@Channel.asString()}")
        timeShift?.observableReadyForPlaybackStatus?.subscribe { isReady ->
            if (onTimeShiftState.value == ReplayState.REPLAYING) return@subscribe
            launchMain {
                val state = if (isReady) ReplayState.READY else ReplayState.STARTING
                if (isReady) timeShiftCreateRetryCount = 0
                updateTimeShiftState(state)
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
                if (timeShiftCreateRetryCount < selectedHighlight.secondsAgo / TIME_SHIFT_RETRY_DELAY) {
                    timeShiftCreateRetryCount++
                    updateTimeShiftState(ReplayState.STARTING)
                    delay(TIME_SHIFT_RETRY_DELAY)
                    createTimeShift()
                } else {
                    timeShiftCreateRetryCount = 0
                    updateTimeShiftState(ReplayState.FAILED)
                }
            }
        }?.run { timeShiftDisposables.add(this) }
    }

    private fun updateSurfaces() {
        updateBandwidth()
        thumbnailSurface?.setVisible(isMainRendered.value == false)
        thumbnailBitmap?.setVisible(isMainRendered.value == true)
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
            launchMain {
                if (isMainRendered.value == false || bitmap.isRecycled) return@launchMain
                if (isFirstFrameDrawn) delay(THUMBNAIL_DRAW_DELAY)
                thumbnailBitmap?.setImageBitmap(bitmap.copy(bitmap.config, bitmap.isMutable))
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

    fun setThumbnailSurfaces(thumbnailSurfaceView: SurfaceView, thumbnailImageView: ImageView) {
        thumbnailSurface = thumbnailSurfaceView
        thumbnailBitmap = thumbnailImageView
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
        onTimeShiftLoading.value = false
        if (onTimeShiftState.value == ReplayState.READY) {
            updateTimeShiftState(ReplayState.REPLAYING)
        }
    }

    fun endVideoReplay() = launchMain {
        Timber.d("Stopping time shift: ${asString()}")
        timeShift?.stop()
        onTimeShiftLoading.value = false
        if (onTimeShiftState.value == ReplayState.REPLAYING) {
            updateTimeShiftState(ReplayState.READY)
        }
    }

    fun createTimeShift() = launchMain {
        Timber.d("Creating time shift: ${renderer?.isSeekable} for: ${asString()}")
        if (renderer == null) {
            return@launchMain
        }
        if (renderer?.isSeekable == false) {
            updateTimeShiftState(ReplayState.FAILED)
            return@launchMain
        }
        updateTimeShiftState(ReplayState.STARTING)
        releaseTimeShift()
        val utcTime = System.currentTimeMillis()
        val offset = utcTime - selectedHighlight.secondsAgo
        Timber.d("UTC time: $utcTime, offset: $offset")
        timeShift = renderer?.seek(Date(offset))
        Timber.d("Time shift created: ${timeShift?.startTime?.time} : $selectedHighlight, offset: $offset, for: ${asString()}")
        subscribeToTimeShiftReadyForPlaybackObservable()
    }

    fun playFromHere(offset: Long) = launchMain {
        timeShiftSeekDisposables.forEach { it.dispose() }
        timeShiftSeekDisposables.clear()
        updateTimeShiftState(ReplayState.STARTING)
        onReplayReady.postConsumable(false)
        onTimeShiftLoading.value = true
        timeShift?.run {
            Timber.d("Seeking time shift: $offset")
            seek(offset, SeekOrigin.BEGINNING)?.subscribe { status ->
                launchMain {
                    Timber.d("Time shift seek status: $status for $offset")
                    onTimeShiftLoading.value = false
                    if (status == RequestStatus.OK) {
                        onReplayReady.postConsumable(true)
                    } else {
                        updateTimeShiftState(ReplayState.FAILED)
                    }
                }
            }?.run { timeShiftSeekDisposables.add(this) }
        }
    }

    fun startReplay() {
        timeShift?.run {
            Timber.d("Playing time shift")
            play()
            updateTimeShiftState(ReplayState.REPLAYING)
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
