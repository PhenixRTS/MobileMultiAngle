/*
 * Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.content.res.Configuration
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.SeekBar
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.GridLayoutManager
import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixcore.common.launchUI
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannelState
import com.phenixrts.suite.phenixcore.repositories.models.PhenixTimeShiftState
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.databinding.ActivityMainBinding
import com.phenixrts.suite.phenixmultiangle.ui.adapters.ChannelAdapter
import com.phenixrts.suite.phenixmultiangle.ui.viewmodels.ChannelViewModel
import kotlinx.coroutines.flow.distinctUntilChanged
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Inject

const val SPAN_COUNT_PORTRAIT = 2
const val SPAN_COUNT_LANDSCAPE = 1

class MainActivity : FragmentActivity() {

    @Inject lateinit var phenixCore: PhenixCore

    private lateinit var binding: ActivityMainBinding
    private val viewModel: ChannelViewModel by lazyViewModel({ application as MultiAngleApp }, {
        ChannelViewModel(phenixCore)
    })

    private val adapter: ChannelAdapter by lazy {
        ChannelAdapter(phenixCore) { channel ->
            Timber.d("Channel clicked: $channel")
            viewModel.selectChannel(channel)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MultiAngleApp.component.inject(this)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        initViews()
    }

    private fun initViews() = with (binding) {
        val rotation = resources.configuration.orientation
        val spanCount = if (rotation == Configuration.ORIENTATION_PORTRAIT) SPAN_COUNT_PORTRAIT else SPAN_COUNT_LANDSCAPE
        val isFullScreen = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        mainStreamHolder.setVisibleOr(true)
        mainStreamList.setVisibleOr(!isFullScreen)
        mainStreamList.layoutManager = GridLayoutManager(this@MainActivity, spanCount)
        mainStreamList.setHasFixedSize(true)
        mainStreamList.adapter = adapter

        spinnerHighlights.adapter = ArrayAdapter(this@MainActivity, R.layout.row_spinner_selector,
            Highlight.values().map { getString(it.title) }.toList()).apply {
                setDropDownViewResource(R.layout.row_spinner_item)
        }
        spinnerHighlights.onSelectionChanged { index ->
            Timber.d("Highlight index changed: $index")
            viewModel.createTimeShift(Highlight.values()[index])
        }

        replayButton.setOnClickListener {
            Timber.d("Replay button clicked: ${Highlight.values()[spinnerHighlights.selectedItemPosition]}")
            viewModel.switchReplayState(Highlight.values()[spinnerHighlights.selectedItemPosition])
        }

        streamHeadProgress.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            var currentProgress = 0L
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, p2: Boolean) {
                currentProgress = progress.toLong()
                streamHeadOverlay.text = viewModel.getTimestampForProgress(currentProgress)
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {
                Timber.d("Progress change started")
                viewModel.pausePlayback()
            }
            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                Timber.d("Progress set: $currentProgress")
                viewModel.playFromHere(currentProgress)
            }
        })

        launchUI {
            viewModel.channels.distinctUntilChanged().collect { channels ->
                adapter.data = channels
                viewModel.renderActiveChannel(mainStreamSurface)
                channels.find { it.isSelected && it.channelState == PhenixChannelState.STREAMING }?.let { channel ->
                    viewModel.subscribeToClosedCaptions(channel, closedCaptionView)
                }
            }
        }
        launchUI {
            viewModel.onChannelsJoined.collect { isSubscribed ->
                Timber.d("On all channels ready: $isSubscribed")
                if (isSubscribed) {
                    viewModel.renderActiveChannel(mainStreamSurface)
                }
            }
        }
        launchUI {
            viewModel.onHeadTimeChanged.collect { head ->
                streamHeadProgress.progress = viewModel.getProgressFromTimestamp(head)
            }
        }
        launchUI {
            viewModel.onReplayButtonClickable.collect { clickable ->
                updateReplayButton(clickable)
                replayButton.isEnabled = clickable
            }
        }
        launchUI {
            viewModel.onTimeShiftStateChanged.collect { state ->
                updateReplayButton(viewModel.isReplayButtonEnabled)
                when (state) {
                    PhenixTimeShiftState.IDLE -> {
                        spinnerHighlightsHolder.setVisibleOr(false)
                        replayButton.setVisibleOr(false)
                        streamHeadHolder.setVisibleOr(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = false
                    }
                    PhenixTimeShiftState.SOUGHT,
                    PhenixTimeShiftState.READY -> {
                        spinnerHighlightsHolder.setVisibleOr(true)
                        replayButtonIcon.setImageResource(R.drawable.ic_replay)
                        replayButtonTitle.setText(R.string.button_replay)
                        replayButton.isEnabled = true
                        replayButton.setVisibleOr(true)
                        streamHeadHolder.setVisibleOr(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = true
                    }
                    PhenixTimeShiftState.PAUSED,
                    PhenixTimeShiftState.REPLAYING -> {
                        spinnerHighlightsHolder.setVisibleOr(false)
                        replayButtonIcon.setImageResource(R.drawable.ic_play)
                        replayButtonTitle.setText(R.string.button_go_live)
                        replayButton.isEnabled = true
                        replayButton.setVisibleOr(true)
                        streamHeadHolder.setVisibleOr(true)
                        closedCaptionView.defaultConfiguration.isButtonVisible = false
                        // Update seek bar MAX value
                        val loopLength = viewModel.selectedHighlight.loopLength
                        streamHeadProgress.max = TimeUnit.MILLISECONDS.toSeconds(loopLength).toInt()
                    }
                    PhenixTimeShiftState.FAILED -> {
                        spinnerHighlightsHolder.setVisibleOr(true)
                        replayButtonIcon.setImageResource(R.drawable.ic_replay_warning)
                        replayButtonTitle.setText(R.string.button_replay_failed)
                        replayButton.isEnabled = true
                        replayButton.setVisibleOr(true)
                        streamHeadHolder.setVisibleOr(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = true
                    }
                    PhenixTimeShiftState.STARTING -> {
                        spinnerHighlightsHolder.setVisibleOr(false)
                        replayButtonIcon.setImageResource(R.drawable.ic_replay_starting)
                        replayButtonTitle.setText(R.string.button_replay_starting)
                        replayButton.isEnabled = false
                        replayButton.setVisibleOr(true)
                        streamHeadHolder.setVisibleOr(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = true
                    }
                }
                closedCaptionView.refresh()
            }
        }
        viewModel.onOrientationChanged(resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE)
        viewModel.joinChannels()
        Timber.d("Initializing Main Activity: $rotation")
    }

    private fun updateReplayButton(clickable: Boolean) = with(binding) {
        Timber.d("Updating replay button - isClickable: $clickable, timeShiftState: ${viewModel.lastTimeShiftState }")
        val drawable = if (clickable) {
            viewModel.lastTimeShiftState.getReplayButtonDrawable()
        } else R.drawable.bg_replay_button_disabled
        replayButton.setBackgroundResource(drawable)
    }
}
