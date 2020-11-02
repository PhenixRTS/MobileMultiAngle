/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.viewmodels

import android.view.SurfaceView
import androidx.lifecycle.*
import androidx.lifecycle.Observer
import com.phenixrts.suite.phenixclosedcaption.PhenixClosedCaptionView
import com.phenixrts.suite.phenixmultiangle.common.DEFAULT_HIGHLIGHT
import com.phenixrts.suite.phenixmultiangle.common.call
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.common.enums.ReplayState
import com.phenixrts.suite.phenixmultiangle.common.isTrue
import com.phenixrts.suite.phenixmultiangle.common.launchMain
import com.phenixrts.suite.phenixmultiangle.models.Channel
import com.phenixrts.suite.phenixmultiangle.repository.ChannelExpressRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import timber.log.Timber
import java.util.concurrent.TimeUnit

private const val REPLAY_BUTTON_CLICK_DELAY = 1000 * 2L

class ChannelViewModel(private val channelExpressRepository: ChannelExpressRepository) : ViewModel() {

    private val channelObserver = Observer<List<Channel>> { channelList ->
        launchMain {
            Timber.d("Channel list changed $channelList")
            channels.value = channelList
            channelList?.forEach { channel ->
                channel.selectedHighlight = selectedHighlight
                channel.joinChannel()
                launchMain {
                    channel.onTimeShiftState.asFlow().collect {
                        updateRePlayState()
                    }
                }
                launchMain {
                    channel.onTimeShiftLoading.asFlow().collect {
                        updateLoadingState()
                    }
                }
            }
            onChannelsJoined.call()
            Timber.d("Channel list joined $channelList")
        }
    }

    private val playbackHeadObserver = Observer<Long> { head ->
        headTimeStamp.value = head
    }

    val channels = MutableLiveData<List<Channel>>()
    val headTimeStamp = MutableLiveData<Long>()
    val onReplayState = MutableLiveData<ReplayState>().apply { value = ReplayState.STARTING }
    val onReplayLoadingState = MutableLiveData<Boolean>().apply { value = false }
    val onChannelsJoined = MutableLiveData<Unit>()
    val onReplayButtonClickable = MutableLiveData<Boolean>().apply { value = true }
    var selectedHighlight = DEFAULT_HIGHLIGHT

    init {
        observeChannels()
    }

    private fun observeChannels() = launchMain {
        Timber.d("Observing channels")
        channelExpressRepository.channels.observeForever(channelObserver)
    }

    private fun updateLoadingState() = launchMain {
        val loadingState = channels.value?.find {
            it.isMainRendered.value == true
        }?.onTimeShiftLoading?.value == true
        if (onReplayLoadingState.value != loadingState) {
            onReplayLoadingState.value = loadingState
        }
    }

    private fun updateRePlayState() = launchMain {
        val rePlayState = channels.value?.find {
            it.isMainRendered.value == true
        }?.onTimeShiftState?.value ?: ReplayState.STARTING
        if (onReplayState.value != rePlayState) {
            onReplayState.value = rePlayState
        }
    }

    private fun startLooping(highlight: Highlight) = launchMain {
        selectedHighlight = highlight
        onReplayButtonClickable.value = false
        onReplayState.value = ReplayState.REPLAYING
        channels.value?.forEach { member ->
            member.startVideoReplay(highlight)
        }
        Timber.d("Video replay started")
        delay(REPLAY_BUTTON_CLICK_DELAY)
        onReplayButtonClickable.value = true
    }

    private fun endLooping() = launchMain {
        onReplayButtonClickable.value = false
        channels.value?.forEach { member ->
            member.endVideoReplay()
        }
        Timber.d("Video replay ended")
        delay(REPLAY_BUTTON_CLICK_DELAY)
        onReplayButtonClickable.value = true
    }

    fun updateActiveChannel(surfaceView: SurfaceView, closedCaptionView: PhenixClosedCaptionView, channel: Channel) = launchMain {
        val channels = channels.value?.toMutableList() ?: mutableListOf()
        channels.forEach { channel ->
            channel.onPlaybackHead.removeObserver(playbackHeadObserver)
            channel.isMainRendered.value = false
            channel.setMainSurface(null)
            channel.muteAudio()
        }
        channels.find { it.channelAlias == channel.channelAlias }?.let { channel ->
            channel.isMainRendered.value = true
            channel.setMainSurface(surfaceView)
            channel.unmuteAudio()
            launchMain {
                channel.onPlaybackHead.observeForever(playbackHeadObserver)
            }
            channel.roomService?.let { service ->
                closedCaptionView.subscribe(service, channelExpressRepository.getMimeTypes())
            }
            if (channel.onTimeShiftState.value == ReplayState.FAILED) {
                channel.selectedHighlight = selectedHighlight
                channel.createTimeShift()
            }
        }
        Timber.d("Updated active channel: $channel")
        updateRePlayState()
        updateLoadingState()
    }

    fun switchReplayState(highlight: Highlight) {
        if (onReplayButtonClickable.isTrue()) {
            when (onReplayState.value) {
                ReplayState.FAILED -> createTimeShift(highlight)
                ReplayState.READY -> startLooping(highlight)
                else -> endLooping()
            }
        }
    }

    fun createTimeShift(highlight: Highlight) = launchMain {
        Timber.d("Recreating time shift for: $highlight")
        selectedHighlight = highlight
        channels.value?.forEach { channel ->
            channel.selectedHighlight = selectedHighlight
            channel.createTimeShift()
        }
    }

    fun getTimestampForProgress(progress: Long)
            = channels.value?.find { it.isMainRendered.value == true }?.getTimestampForProgress(progress) ?: ""

    fun getProgressFromTimestamp(timeStamp: Long): Int = TimeUnit.MILLISECONDS.toSeconds(timeStamp).toInt()

    fun playFromHere(progress: Long) {
        channels.value?.forEach {channel ->
            channel.playFromHere(TimeUnit.SECONDS.toMillis(progress))
        }
    }

    fun pausePlayback() {
        channels.value?.forEach { channel ->
            channel.pausePlayback()
        }
    }
}
