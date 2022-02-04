/*
 * Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.viewmodels

import android.view.SurfaceView
import androidx.lifecycle.*
import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixclosedcaptions.PhenixClosedCaptionView
import com.phenixrts.suite.phenixcore.common.ConsumableSharedFlow
import com.phenixrts.suite.phenixcore.common.launchIO
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannel
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannelState
import com.phenixrts.suite.phenixcore.repositories.models.PhenixTimeShiftState
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Bandwidth
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import timber.log.Timber
import java.util.*
import java.util.concurrent.TimeUnit

private const val REPLAY_BUTTON_CLICK_DELAY = 1000 * 2L

class ChannelViewModel(
    private val phenixCore: PhenixCore
) : ViewModel() {

    private var rawChannels = mutableListOf<PhenixChannel>()

    private val _channels = ConsumableSharedFlow<List<PhenixChannel>>(canReplay = true)
    private val _onHeadTimeChanged = ConsumableSharedFlow<Long>(canReplay = true)
    private val _onReplayButtonClickable = ConsumableSharedFlow<Boolean>(canReplay = true)
    private val _onTimeShiftStateChanged = ConsumableSharedFlow<PhenixTimeShiftState>(canReplay = true)
    private val _onChannelsJoined = MutableStateFlow(false)

    private var channelSelected = false
    private var timeShiftStart = 0L
    private var timeShiftsCreated = false
    private val channelCopy get() = rawChannels.map { it.copy() }

    val channels = _channels.asSharedFlow()
    val onHeadTimeChanged = _onHeadTimeChanged.asSharedFlow()
    val onTimeShiftStateChanged = _onTimeShiftStateChanged.asSharedFlow()
    val onChannelsJoined = _onChannelsJoined.asStateFlow()
    val onReplayButtonClickable = _onReplayButtonClickable.asSharedFlow()
    var selectedHighlight = Highlight.SEEK_80_LOOP_60
    var isReplayButtonEnabled = true
        private set
    var lastTimeShiftState = PhenixTimeShiftState.STARTING
        private set

    init {
        launchIO {
            Timber.d("Observing channels")
            phenixCore.channels.collect { channels ->
                rawChannels.clear()
                rawChannels.addAll(channels)
                if (channels.isEmpty()) return@collect
                // Check if all channels joined
                val allChannelsJoined = channels.all { it.channelState == PhenixChannelState.STREAMING }
                _onChannelsJoined.tryEmit(allChannelsJoined)
                if (allChannelsJoined && !timeShiftsCreated) {
                    timeShiftsCreated = true
                    createTimeShift(selectedHighlight)
                }

                // Select a channel if none selected
                if (channels.none { it.isSelected } && !channelSelected) {
                    channelSelected = true
                    selectChannel(channels.first())
                }
                // Chek if all time shifts are sought to the same timestamp
                if (channels.all { it.timeShiftState == PhenixTimeShiftState.SOUGHT }) {
                    channels.forEach { channel ->
                        phenixCore.playTimeShift(channel.alias)
                    }
                }
                // Update selected channel time shift state
                val timeShiftState = channels.find { it.isSelected }?.timeShiftState ?: PhenixTimeShiftState.STARTING
                val areAllTimeShiftsReady = channels.all { it.timeShiftState == PhenixTimeShiftState.READY }
                if (lastTimeShiftState != timeShiftState) {
                    lastTimeShiftState = if (timeShiftState != PhenixTimeShiftState.READY || areAllTimeShiftsReady)
                        timeShiftState else PhenixTimeShiftState.STARTING
                    _onTimeShiftStateChanged.tryEmit(lastTimeShiftState)
                }
                // Update head time stamp for selected channel
                val head = channels.find { it.isSelected }?.timeShiftHead ?: 0L
                _onHeadTimeChanged.tryEmit(head)
                _channels.tryEmit(channels.map { it.copy() })
            }
        }
    }

    fun joinChannels() = launchIO {
        Timber.d("Joining channels: ${phenixCore.configuration?.channelAliases}")
        phenixCore.joinAllChannels()
    }

    fun selectChannel(selectedChannel: PhenixChannel) = launchIO {
        channelCopy.forEach { channel ->
            val isSelected = channel.alias == selectedChannel.alias
            phenixCore.selectChannel(channel.alias, isSelected)
            phenixCore.setAudioEnabled(channel.alias, isSelected)
        }
    }

    fun renderActiveChannel(surfaceView: SurfaceView) {
        channelCopy.find { it.isSelected }?.let { channel ->
            Timber.d("Render active channel: $channel")
            phenixCore.renderOnSurface(channel.alias, surfaceView)
        }
    }

    fun createTimeShift(highlight: Highlight) = launchIO {
        Timber.d("Creating time shift: $highlight")
        selectedHighlight = highlight
        channelCopy.forEach { channel ->
            timeShiftStart = highlight.secondsAgo
            phenixCore.createTimeShift(channel.alias, timeShiftStart)
            phenixCore.limitBandwidth(channel.alias, Bandwidth.LD.value)
        }
    }

    fun playFromHere(progress: Long) = launchIO {
        Timber.d("Seeking time shift: $progress")
        channelCopy.forEach { channel ->
            phenixCore.seekTimeShift(channel.alias, TimeUnit.SECONDS.toMillis(progress))
        }
    }

    fun pausePlayback() = launchIO {
        Timber.d("Pausing time shift")
        channelCopy.forEach { channel ->
            phenixCore.pauseTimeShift(channel.alias)
        }
    }

    fun switchReplayState(highlight: Highlight) = launchIO {
        if (isReplayButtonEnabled) {
            when (lastTimeShiftState) {
                PhenixTimeShiftState.FAILED -> createTimeShift(highlight)
                PhenixTimeShiftState.READY -> startTimeShift(highlight)
                else -> endTimeShift()
            }
        }
    }

    fun onOrientationChanged(isLandscape: Boolean) {
        channelCopy.forEach { channel ->
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

    fun subscribeToClosedCaptions(channel: PhenixChannel, closedCaptionView: PhenixClosedCaptionView) {
        closedCaptionView.subscribeToCC(phenixCore, channel.alias)
    }

    fun getTimestampForProgress(progress: Long) = channelCopy.find { it.isSelected }?.run {
        Date(timeShiftStart + TimeUnit.SECONDS.toMillis(progress)).toDateString()
    } ?: ""

    fun getProgressFromTimestamp(timeStamp: Long): Int = TimeUnit.MILLISECONDS.toSeconds(timeStamp).toInt()

    private fun startTimeShift(highlight: Highlight) = launchIO {
        Timber.d("Starting time shift: $highlight")
        selectedHighlight = highlight
        isReplayButtonEnabled = false
        _onReplayButtonClickable.tryEmit(isReplayButtonEnabled)
        channelCopy.forEach { channel ->
            phenixCore.startTimeShift(channel.alias, highlight.loopLength)
        }
        delay(REPLAY_BUTTON_CLICK_DELAY)
        isReplayButtonEnabled = true
        _onReplayButtonClickable.tryEmit(isReplayButtonEnabled)
    }

    private fun endTimeShift() = launchIO {
        Timber.d("Ending time shift")
        isReplayButtonEnabled = false
        _onReplayButtonClickable.tryEmit(isReplayButtonEnabled)
        channelCopy.forEach { channel ->
            phenixCore.stopTimeShift(channel.alias)
        }
        delay(REPLAY_BUTTON_CLICK_DELAY)
        isReplayButtonEnabled = true
        _onReplayButtonClickable.tryEmit(isReplayButtonEnabled)
    }
}
