/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.viewmodels

import android.view.SurfaceView
import androidx.lifecycle.*
import androidx.lifecycle.Observer
import com.phenixrts.suite.phenixclosedcaption.PhenixClosedCaptionView
import com.phenixrts.suite.phenixmultiangle.common.DEFAULT_HIGHLIGHT
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.common.enums.ReplayState
import com.phenixrts.suite.phenixmultiangle.common.launchMain
import com.phenixrts.suite.phenixmultiangle.common.toDateString
import com.phenixrts.suite.phenixmultiangle.models.Channel
import com.phenixrts.suite.phenixmultiangle.repository.ChannelExpressRepository
import kotlinx.coroutines.delay
import timber.log.Timber
import java.util.*
import java.util.concurrent.TimeUnit

private const val REPLAY_BUTTON_CLICK_DELAY = 1000 * 2L

class ChannelViewModel(private val channelExpressRepository: ChannelExpressRepository) : ViewModel() {

    private val channelObserver = Observer<List<Channel>> { channelList ->
        launchMain {
            Timber.d("Channel list changed $channelList")
            channels.value = channelList
            channelList?.forEach { channel ->
                channel.joinChannel(channelExpressRepository.timeShiftStartTime)
            }
            onChannelsJoined.value = true
            Timber.d("Channel list joined $channelList")
        }
    }

    private val timeShiftObserver = Observer<Boolean> {
        updateRePlayState()
    }

    private val playbackHeadObserver = Observer<Date> { head ->
        headTimeStamp.value = head
    }

    val channels = MutableLiveData<List<Channel>>()
    val headTimeStamp = MutableLiveData<Date>()
    val onReplayButtonState = MutableLiveData<ReplayState>().apply { value = ReplayState.LIVE }
    val onReplayButtonVisible = MutableLiveData<Boolean>().apply { value = false }
    val isReplayButtonClickable = MutableLiveData<Boolean>().apply { value = true }
    val onChannelsJoined = MutableLiveData<Boolean>()
    var selectedHighlight = DEFAULT_HIGHLIGHT

    init {
        observeChannels()
    }

    private fun observeChannels() = launchMain {
        Timber.d("Observing channels")
        channelExpressRepository.channels.observeForever(channelObserver)
    }

    private fun updateRePlayState() = launchMain {
        channels.value?.find { it.isMainRendered.value == true }?.let { member ->
            onReplayButtonState.value = if (member.isReplaying) ReplayState.REPLAYING else ReplayState.LIVE
            onReplayButtonVisible.value = member.onTimeShiftReady.value
        }
    }

    private fun startLooping(highlight: Highlight) {
        selectedHighlight = highlight
        isReplayButtonClickable.value = false
        onReplayButtonState.value = ReplayState.REPLAYING
        channels.value?.find { it.isMainRendered.value == true }?.let { member ->
            launchMain {
                member.startVideoReplay(highlight)
                delay(REPLAY_BUTTON_CLICK_DELAY)
                isReplayButtonClickable.value = true
            }
        }
    }

    private fun endLooping() {
        isReplayButtonClickable.value = false
        onReplayButtonState.value = ReplayState.LIVE
        channels.value?.find { it.isMainRendered.value == true }?.let { member ->
            launchMain {
                member.endVideoReplay()
                delay(REPLAY_BUTTON_CLICK_DELAY)
                isReplayButtonClickable.value = true
            }
        }
    }

    fun updateActiveChannel(surfaceView: SurfaceView, closedCaptionView: PhenixClosedCaptionView, channel: Channel) = launchMain {
        val channels = channels.value?.toMutableList() ?: mutableListOf()
        channels.filter { it.isMainRendered.value == true && it.channelAlias != channel.channelAlias }.forEach { channel ->
            channel.isMainRendered.value = false
            channel.setMainSurface(null)
            channel.muteAudio()
            channel.onTimeShiftReady.removeObserver(timeShiftObserver)
            channel.onPlaybackHead.removeObserver(playbackHeadObserver)
        }
        channels.find { it.channelAlias == channel.channelAlias }?.apply {
            isMainRendered.value = true
            setMainSurface(surfaceView)
            unmuteAudio()
            if (onTimeShiftReady.value == false) {
                createTimeShift(selectedHighlight)
                onTimeShiftReady.observeForever(timeShiftObserver)
            }
            onPlaybackHead.observeForever(playbackHeadObserver)
            roomService?.let { service ->
                closedCaptionView.subscribe(service, channelExpressRepository.getMimeTypes())
            }
        }
        Timber.d("Updated active channel: $channel")
        updateRePlayState()
    }

    fun switchReplayState(highlight: Highlight) {
        if (isReplayButtonClickable.value == true) {
            if (onReplayButtonState.value == ReplayState.LIVE) {
                startLooping(highlight)
            } else {
                endLooping()
            }
        }
    }

    fun createTimeShift(highlight: Highlight) {
        Timber.d("Recreating time shift for: $highlight")
        selectedHighlight = highlight
        channelExpressRepository.timeShiftStartTime = Date(channelExpressRepository.channelJoinTime.time - selectedHighlight.minutesAgo)
        channels.value?.firstOrNull { it.isMainRendered.value == true }?.createTimeShift(channelExpressRepository.timeShiftStartTime)
    }

    fun getTimestampForProgress(progress: Long)
            = Date(channelExpressRepository.timeShiftStartTime.time + TimeUnit.SECONDS.toMillis(progress)).toDateString()

    fun getProgressFromTimestamp(timeStamp: Date): Int
            = TimeUnit.MILLISECONDS.toSeconds(timeStamp.time - channelExpressRepository.timeShiftStartTime.time).toInt()

    fun playFromHere(progress: Long) {
        channels.value?.firstOrNull {
            it.isMainRendered.value == true
        }?.playFromHere(Date(channelExpressRepository.timeShiftStartTime.time + TimeUnit.SECONDS.toMillis(progress)))
    }

    fun pausePlayback() {
        channels.value?.firstOrNull { it.isMainRendered.value == true }?.pausePlayback()
    }
}
