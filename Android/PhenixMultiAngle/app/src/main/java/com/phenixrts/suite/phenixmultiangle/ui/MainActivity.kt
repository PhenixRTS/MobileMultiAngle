/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.content.res.Configuration
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.SeekBar
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.GridLayoutManager
import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannelState
import com.phenixrts.suite.phenixcore.repositories.models.PhenixTimeShiftState
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.databinding.ActivityMainBinding
import com.phenixrts.suite.phenixmultiangle.ui.adapters.ChannelAdapter
import com.phenixrts.suite.phenixmultiangle.ui.viewmodels.ChannelViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collect
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Inject

const val SPAN_COUNT_PORTRAIT = 2
const val SPAN_COUNT_LANDSCAPE = 1

class MainActivity : FragmentActivity() {

    @Inject lateinit var phenixCore: PhenixCore

    private lateinit var binding: ActivityMainBinding
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
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
        observePhenixCore()
        initViews()
    }

    private fun observePhenixCore() {
        coroutineScope.launch {
            phenixCore.onError.collect { error ->
                phenixCore.consumeLastError()
                Timber.d("Main: Phenix Core error: $error")
            }
        }
        coroutineScope.launch {
            phenixCore.onEvent.collect { event ->
                phenixCore.consumeLastEvent()
                Timber.d("Main: Phenix core event: $event")
            }
        }
    }

    private fun initViews() = with (binding) {
        val rotation = resources.configuration.orientation
        val spanCount = if (rotation == Configuration.ORIENTATION_PORTRAIT) SPAN_COUNT_PORTRAIT else SPAN_COUNT_LANDSCAPE
        val isFullScreen = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        mainStreamHolder.setVisible(true)
        mainStreamList.setVisible(!isFullScreen)
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

        viewModel.channels.observe(this@MainActivity) { channels ->
            launchMain {
                channels.find { it.isSelected && it.channelState == PhenixChannelState.STREAMING }?.let { channel ->
                    mainStreamLoading.tag = channel.alias
                    mainStreamLoading.setVisible(false)
                    phenixCore.renderOnSurface(channel.alias, mainStreamSurface)
                    viewModel.subscribeToClosedCaptions(channel, closedCaptionView)
                    mainStreamLoading.setVisible(channel.timeShiftState == PhenixTimeShiftState.STARTING)
                }
            }
            adapter.data = channels
        }
        launchIO {
            viewModel.onChannelsJoined.collect {
                Timber.d("On all channels ready: ${viewModel.channels.value}")
                launchMain {
                    mainStreamLoading.setVisible(false)
                }
                viewModel.createTimeShift(Highlight.values()[spinnerHighlights.selectedItemPosition])
            }
        }
        viewModel.onHeadTimeChanged.observe(this@MainActivity) { head ->
            streamHeadProgress.progress = viewModel.getProgressFromTimestamp(head)
        }
        viewModel.onReplayButtonClickable.observe(this@MainActivity) { clickable ->
            updateReplayButton(clickable)
            replayButton.isEnabled = clickable
        }
        viewModel.onTimeShiftStateChanged.observe(this@MainActivity) { state ->
            launchMain {
                updateReplayButton(viewModel.onReplayButtonClickable.isTrue())
                when (state ?: PhenixTimeShiftState.IDLE) {
                    PhenixTimeShiftState.IDLE -> {
                        spinnerHighlightsHolder.setVisible(false)
                        replayButton.setVisible(false)
                        streamHeadHolder.setVisible(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = false
                    }
                    PhenixTimeShiftState.SOUGHT,
                    PhenixTimeShiftState.READY -> {
                        spinnerHighlightsHolder.setVisible(true)
                        replayButtonIcon.setImageResource(R.drawable.ic_replay)
                        replayButtonTitle.setText(R.string.button_replay)
                        replayButton.isEnabled = true
                        replayButton.setVisible(true)
                        streamHeadHolder.setVisible(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = true
                    }
                    PhenixTimeShiftState.PAUSED,
                    PhenixTimeShiftState.REPLAYING -> {
                        spinnerHighlightsHolder.setVisible(false)
                        replayButtonIcon.setImageResource(R.drawable.ic_play)
                        replayButtonTitle.setText(R.string.button_go_live)
                        replayButton.isEnabled = true
                        replayButton.setVisible(true)
                        streamHeadHolder.setVisible(true)
                        closedCaptionView.defaultConfiguration.isButtonVisible = false
                        // Update seek bar MAX value
                        val loopLength = viewModel.selectedHighlight.loopLength
                        streamHeadProgress.max = TimeUnit.MILLISECONDS.toSeconds(loopLength).toInt()
                    }
                    PhenixTimeShiftState.FAILED -> {
                        spinnerHighlightsHolder.setVisible(true)
                        replayButtonIcon.setImageResource(R.drawable.ic_replay_warning)
                        replayButtonTitle.setText(R.string.button_replay_failed)
                        replayButton.isEnabled = true
                        replayButton.setVisible(true)
                        streamHeadHolder.setVisible(false)
                        closedCaptionView.defaultConfiguration.isButtonVisible = true
                    }
                    PhenixTimeShiftState.STARTING -> {
                        spinnerHighlightsHolder.setVisible(false)
                        replayButtonIcon.setImageResource(R.drawable.ic_replay_starting)
                        replayButtonTitle.setText(R.string.button_replay_starting)
                        replayButton.isEnabled = false
                        replayButton.setVisible(true)
                        streamHeadHolder.setVisible(false)
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
        val drawable = if (clickable) {
            (viewModel.onTimeShiftStateChanged.value ?: PhenixTimeShiftState.STARTING).getReplayButtonDrawable()
        } else R.drawable.bg_replay_button_disabled
        replayButton.setBackgroundResource(drawable)
    }
}
