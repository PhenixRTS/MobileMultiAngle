/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import android.graphics.Bitmap
import android.graphics.Paint
import android.util.Base64
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.lifecycle.MutableLiveData
import com.phenixrts.chat.RoomChatServiceFactory
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

    private var chatDisposable: Disposable? = null
    private var bandwidthLimiter: Disposable? = null
    private var timeShiftDisposables = mutableListOf<Disposable>()
    private var timeShiftSeekDisposables = mutableListOf<Disposable>()
    private var isBitmapSurfaceAvailable = false

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
    val chatMessages = MutableLiveData<String>()
    var isReplaying = false

    private suspend fun observeChatMessages(roomService: RoomService?) {
        delay(CHAT_SERVICE_DELAY)
        chatDisposable?.dispose()
        chatDisposable = null
        RoomChatServiceFactory.createRoomChatService(roomService, MESSAGE_BATCH_SIZE).observableLastChatMessage.subscribe { lastMessage ->
            launchMain {
                Timber.d("RAW message received: ${lastMessage.observableMessage.value} from: ${lastMessage.observableFrom.value.observableScreenName.value}")
                lastMessage.takeIf {
                    it.observableFrom.value.observableScreenName.value == MESSAGE_FILTER
                }?.observableMessage?.value?.let { message ->
                    chatMessages.value = Base64.decode(message, Base64.DEFAULT).toString(charset("UTF-8"))
                }
            }
        }.run { chatDisposable = this }
    }

    private fun limitBandwidth() {
        Timber.d("Limiting Bandwidth: ${toString()}")
        bandwidthLimiter =
            expressSubscriber?.videoTracks?.getOrNull(0)?.limitBandwidth(BANDWIDTH_LIMIT)
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
            renderer?.setFrameReadyCallback(videoTrack, if (isMainRendered.value == false) null else frameCallback)
        }
    }

    private fun drawFrameBitmap(bitmap: Bitmap) {
        try {
            if (isMainRendered.value == false || !isBitmapSurfaceAvailable) return
            launchIO {
                delay(THUMBNAIL_DRAW_DELAY)
                bitmapSurface?.holder?.let { holder ->
                    holder.lockCanvas()?.let { canvas ->
                        val targetWidth = bitmapSurface?.measuredWidth ?: 0
                        val targetHeight = bitmapSurface?.measuredHeight ?: 0
                        val ratioBitmap = bitmap.width.toFloat() / bitmap.height.toFloat()
                        val ratioTarget = targetWidth.toFloat() / targetHeight.toFloat()

                        var finalWidth = targetWidth
                        var finalHeight = targetHeight
                        if (ratioTarget > 1) {
                            finalWidth = (targetHeight.toFloat() * ratioBitmap).toInt()
                        } else {
                            finalHeight = (targetWidth.toFloat() / ratioBitmap).toInt()
                        }
                        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, finalWidth, finalHeight, true)
                        canvas.drawBitmap(scaledBitmap, 0f, 0f, Paint())
                        scaledBitmap.recycle()
                        bitmap.recycle()
                        holder.unlockCanvasAndPost(canvas)
                    }
                }
            }
        } catch (e: Exception) {
            Timber.d(e, "Failed to draw bitmap")
        }
    }

    private fun releaseBandwidthLimiter() {
        Timber.d("Releasing Bandwidth limiter: ${toString()}")
        bandwidthLimiter?.dispose()
        bandwidthLimiter = null
    }

    private fun releaseTimeShiftObservers() {
        isReplaying = false
        timeShiftDisposables.forEach { it.dispose() }
        timeShiftDisposables.clear()
        timeShiftSeekDisposables.forEach { it.dispose() }
        timeShiftSeekDisposables.clear()
        Timber.d("Time shift disposables released")
    }

    private fun releaseTimeShift() {
        releaseTimeShiftObservers()
        timeShift?.stop()
        timeShift?.dispose()
        timeShift = null
        Timber.d("Time shift released")
    }

    private fun renderSubscriber(subscriber: ExpressSubscriber?, expressRenderer: Renderer?, startTime: Date) {
        expressSubscriber?.stop()
        renderer?.stop()
        expressSubscriber?.dispose()
        renderer?.dispose()
        expressSubscriber = subscriber
        renderer = expressRenderer
        createTimeShift(startTime)
        setVideoFrameCallback()
        if (isMainRendered.value == true) {
            unmuteAudio()
        } else {
            muteAudio()
        }
        Timber.d("Started subscriber renderer: ${toString()}")
    }

    fun muteAudio() = renderer?.muteAudio()

    fun unmuteAudio() = renderer?.unmuteAudio()

    suspend fun joinChannel(startTime: Date) = suspendCancellableCoroutine<Unit> { continuation ->
        Timber.d("Joining channel with alias: $channelAlias")
        val options = getChannelConfiguration(channelAlias, videoRenderSurface)
        channelExpress.joinChannel(options, { requestStatus: RequestStatus?, roomService: RoomService? ->
            launchMain {
                Timber.d("Channel join status: $requestStatus")
                if (requestStatus == RequestStatus.OK) {
                    observeChatMessages(roomService)
                    onChannelJoined.value = StreamStatus.ONLINE
                } else {
                    onChannelJoined.value = StreamStatus.OFFLINE
                }
                if (continuation.isActive) continuation.resume(Unit)
            }
        }, { requestStatus: RequestStatus?, subscriber: ExpressSubscriber?, renderer: Renderer? ->
            launchMain {
                Timber.d("Stream status: $requestStatus")
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
        Timber.d("Looping time shift: ${renderer?.isSeekable}, ${toString()}")
        if (renderer?.isSeekable == false) return
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
        Timber.d("Creating time shift: ${renderer?.isSeekable}")
        if (renderer?.isSeekable == false) return
        releaseTimeShift()
        timeShift = renderer?.seek(startTime)
        Timber.d("Time shift created for: $startTime $timeShift")
        subscribeToTimeShiftReadyForPlaybackObservable()
    }

    fun playFromHere(selectedTimeStamp: Date) {
        Timber.d("Seeking timeshift: $selectedTimeStamp")
        timeShift?.seek(selectedTimeStamp)?.subscribe { status ->
            Timber.d("Time shift seek status: $status for $selectedTimeStamp")
            if (status == RequestStatus.OK) {
                timeShift?.play()
            }
        }?.run { timeShiftSeekDisposables.add(this) }
    }

    fun pausePlayback() {
        Timber.d("Playback paused")
        timeShift?.pause()
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
