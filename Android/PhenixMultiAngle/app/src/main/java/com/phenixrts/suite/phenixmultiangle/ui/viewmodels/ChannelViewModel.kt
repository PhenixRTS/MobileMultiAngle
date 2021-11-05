/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.viewmodels

import androidx.lifecycle.*
import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixcore.closedcaptions.PhenixClosedCaptionView
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannel
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannelState
import com.phenixrts.suite.phenixcore.repositories.models.PhenixTimeShiftState
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Bandwidth
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collect
import timber.log.Timber
import java.util.*
import java.util.concurrent.TimeUnit

private const val REPLAY_BUTTON_CLICK_DELAY = 1000 * 2L

class ChannelViewModel(
    private val phenixCore: PhenixCore
) : ViewModel() {

    private var selectingChannel: String? = null
    private var timeShiftStart = 0L
    val channels = MutableLiveData<List<PhenixChannel>>()
    val onHeadTimeChanged = MutableLiveData<Long>()
    val onTimeShiftStateChanged = MutableLiveData<PhenixTimeShiftState>()
    val onChannelsJoined = MutableStateFlow(false)
    val onReplayButtonClickable = MutableLiveData<Boolean>().apply { postValue(true) }
    var selectedHighlight = Highlight.SEEK_80_LOOP_60

    init {
        launchMain {
            Timber.d("Observing channels")
            phenixCore.channels.collect { channelModels ->
                channels.value = channelModels
                if (channels.value?.isEmpty() == true) return@collect
                // Check if all channels joined
                onChannelsJoined.value = channelModels.none { it.channelState == PhenixChannelState.JOINING }

                // Select a channel if none selected
                if (channelModels.all { !it.isSelected } && selectingChannel == null) {
                    selectChannel(channelModels.first())
                }
                // Chek if all time shifts are sought to the same timestamp
                if (channelModels.all { it.timeShiftState == PhenixTimeShiftState.SOUGHT }) {
                    channelModels.forEach { channel ->
                        phenixCore.playTimeShift(channel.alias)
                    }
                }
                // Update selected channel time shift state
                val timeShiftState = channelModels.find { it.isSelected }?.timeShiftState ?: PhenixTimeShiftState.STARTING
                val areAllTimeShiftsReady = channelModels.all { it.timeShiftState == PhenixTimeShiftState.READY }
                if (onTimeShiftStateChanged.value != timeShiftState) {
                    onTimeShiftStateChanged.value = if (timeShiftState != PhenixTimeShiftState.READY || areAllTimeShiftsReady)
                        timeShiftState else PhenixTimeShiftState.STARTING
                }
                // Update head time stamp for selected channel
                val head = channelModels.find { it.isSelected }?.timeShiftHead ?: 0L
                onHeadTimeChanged.value = head
                // Check if manually selected channel has been updated and release the latch
                if (channelModels.find { it.alias == selectingChannel }?.isSelected == true) {
                    selectingChannel = null
                }
            }
        }
    }

    fun joinChannels() = launchIO {
        Timber.d("Joining channels: ${phenixCore.configuration?.channels}")
        phenixCore.joinAllChannels()
    }

    fun createTimeShift(highlight: Highlight) = launchIO {
        Timber.d("Creating time shift: $highlight")
        selectedHighlight = highlight
        channels.value?.forEach { channel ->
            timeShiftStart = highlight.secondsAgo
            phenixCore.createTimeShift(channel.alias, timeShiftStart)
        }
    }

    private fun startTimeShift(highlight: Highlight) = launchIO {
        Timber.d("Starting time shift: $highlight")
        selectedHighlight = highlight
        onReplayButtonClickable.postValue(false)
        channels.value?.forEach { channel ->
            phenixCore.startTimeShift(channel.alias, highlight.loopLength)
        }
        delay(REPLAY_BUTTON_CLICK_DELAY)
        onReplayButtonClickable.postValue(true)
    }

    private fun endTimeShift() = launchIO {
        Timber.d("Ending time shift")
        onReplayButtonClickable.postValue(false)
        channels.value?.forEach { channel ->
            phenixCore.stopTimeShift(channel.alias)
        }
        delay(REPLAY_BUTTON_CLICK_DELAY)
        onReplayButtonClickable.postValue(true)
    }

    fun playFromHere(progress: Long) = launchIO {
        Timber.d("Seeking time shift: $progress")
        channels.value?.forEach { channel ->
            phenixCore.seekTimeShift(channel.alias, TimeUnit.SECONDS.toMillis(progress))
        }
    }

    fun pausePlayback() = launchIO {
        Timber.d("Pausing time shift")
        channels.value?.forEach { channel ->
            phenixCore.pauseTimeShift(channel.alias)
        }
    }

    fun switchReplayState(highlight: Highlight) = launchIO {
        if (onReplayButtonClickable.isTrue()) {
            when (onTimeShiftStateChanged.value) {
                PhenixTimeShiftState.FAILED -> createTimeShift(highlight)
                PhenixTimeShiftState.READY -> startTimeShift(highlight)
                else -> endTimeShift()
            }
        }
    }

    fun onOrientationChanged(isLandscape: Boolean) = launchIO {
        channels.value?.forEach { channel ->
            val bandwidth: Bandwidth = if (isLandscape) {
                if (channel.isSelected) Bandwidth.UNLIMITED else Bandwidth.ULD
            } else {
                if (channel.isSelected) Bandwidth.HD else Bandwidth.LD
            }
            if (bandwidth == Bandwidth.UNLIMITED) {
                phenixCore.releaseBandwidthLimiter(channel.alias)
            } else {
                phenixCore.limitBandwidth(channel.alias, bandwidth.value)
            }
        }
    }

    fun selectChannel(selectedChannel: PhenixChannel) = launchIO {
        channels.value?.forEach { channel ->
            val isSelected = channel.alias == selectedChannel.alias
            if (isSelected) {
                selectingChannel = channel.alias
            }
            phenixCore.selectChannel(channel.alias, isSelected)
            phenixCore.setAudioEnabled(channel.alias, !isSelected)
        }
    }

    fun subscribeToClosedCaptions(channel: PhenixChannel, closedCaptionView: PhenixClosedCaptionView) {
        phenixCore.subscribeToCC(channel.alias, closedCaptionView)
    }

    fun getTimestampForProgress(progress: Long) = channels.value?.find { it.isSelected }?.run {
        Date(timeShiftStart + TimeUnit.SECONDS.toMillis(progress)).toDateString()
    } ?: ""

    fun getProgressFromTimestamp(timeStamp: Long): Int = TimeUnit.MILLISECONDS.toSeconds(timeStamp).toInt()
}
