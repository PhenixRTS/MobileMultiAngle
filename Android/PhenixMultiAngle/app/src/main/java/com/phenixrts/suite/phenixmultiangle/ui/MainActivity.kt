/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.content.res.Configuration
import android.os.Bundle
import android.view.LayoutInflater
import android.widget.ArrayAdapter
import android.widget.SeekBar
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.GridLayoutManager
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.common.enums.ReplayState
import com.phenixrts.suite.phenixmultiangle.databinding.ActivityMainBinding
import com.phenixrts.suite.phenixmultiangle.repository.ChannelExpressRepository
import com.phenixrts.suite.phenixmultiangle.ui.adapters.ChannelAdapter
import com.phenixrts.suite.phenixmultiangle.ui.viewmodels.ChannelViewModel
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Inject

const val SPAN_COUNT_PORTRAIT = 2
const val SPAN_COUNT_LANDSCAPE = 1

class MainActivity : FragmentActivity() {

    @Inject lateinit var channelExpress: ChannelExpressRepository

    private lateinit var binding: ActivityMainBinding
    private val viewModel: ChannelViewModel by lazyViewModel({ application as MultiAngleApp }, { ChannelViewModel(channelExpress) })
    private val loadingBar by lazy {
        LayoutInflater.from(this).inflate(R.layout.view_loading, binding.mainStreamLoading, false)
    }

    private val adapter: ChannelAdapter by lazy {
        ChannelAdapter { roomMember ->
            Timber.d("Member clicked: $roomMember")
            viewModel.updateActiveChannel(binding.mainStreamSurface, binding.closedCaptionView, roomMember)
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

        viewModel.channels.observe(this@MainActivity, { channels ->
            Timber.d("Channel list updated: $channels, full screen: $isFullScreen")
            channels.forEach { channel ->
                channel.isFullScreen = isFullScreen
            }
            mainStreamLoading.removeAllViews()
            mainStreamLoading.addView(loadingBar)
            adapter.data = channels
        })
        viewModel.onChannelsJoined.observe(this@MainActivity, {
            Timber.d("On all channels ready")
            mainStreamLoading.removeAllViews()
            viewModel.channels.value?.find { it.isMainRendered.value == true }?.let { channel ->
                viewModel.updateActiveChannel(mainStreamSurface, closedCaptionView, channel)
            }
        })
        viewModel.headTimeStamp.observe(this@MainActivity, { head ->
            streamHeadProgress.progress = viewModel.getProgressFromTimestamp(head)
        })
        viewModel.onReplayButtonClickable.observe(this@MainActivity, { clickable ->
            updateReplayButton(clickable)
            replayButton.isEnabled = clickable
        })
        viewModel.onReplayState.observe(this@MainActivity, { state ->
            updateReplayButton(viewModel.onReplayButtonClickable.isTrue())
            when (state ?: ReplayState.STARTING) {
                ReplayState.READY -> {
                    spinnerHighlightsHolder.setVisible(true)
                    replayButtonIcon.setImageResource(R.drawable.ic_replay)
                    replayButtonTitle.setText(R.string.button_replay)
                    replayButton.isEnabled = true
                    streamHeadHolder.setVisible(false)
                    closedCaptionView.defaultConfiguration.isButtonVisible = true
                }
                ReplayState.REPLAYING -> {
                    spinnerHighlightsHolder.setVisible(false)
                    replayButtonIcon.setImageResource(R.drawable.ic_play)
                    replayButtonTitle.setText(R.string.button_go_live)
                    replayButton.isEnabled = true
                    streamHeadHolder.setVisible(true)
                    closedCaptionView.defaultConfiguration.isButtonVisible = false
                    // Update seek bar MAX value
                    val loopLength = viewModel.selectedHighlight.loopLength
                    streamHeadProgress.max = TimeUnit.MILLISECONDS.toSeconds(loopLength).toInt()
                }
                ReplayState.FAILED -> {
                    spinnerHighlightsHolder.setVisible(true)
                    replayButtonIcon.setImageResource(R.drawable.ic_replay_warning)
                    replayButtonTitle.setText(R.string.button_replay_failed)
                    replayButton.isEnabled = true
                    streamHeadHolder.setVisible(false)
                    closedCaptionView.defaultConfiguration.isButtonVisible = true
                }
                ReplayState.STARTING -> {
                    spinnerHighlightsHolder.setVisible(false)
                    replayButtonIcon.setImageResource(R.drawable.ic_replay_starting)
                    replayButtonTitle.setText(R.string.button_replay_starting)
                    replayButton.isEnabled = false
                    streamHeadHolder.setVisible(false)
                    closedCaptionView.defaultConfiguration.isButtonVisible = true
                }
            }
            closedCaptionView.refresh()
        })
        viewModel.onReplayLoadingState.observe(this@MainActivity, { isLoading ->
            Timber.d("Replay loading state changed: $isLoading")
            mainStreamLoading.removeAllViews()
            if (isLoading) {
                mainStreamLoading.addView(loadingBar)
            }
        })
        Timber.d("Initializing Main Activity: $rotation")
    }

    private fun updateReplayButton(clickable: Boolean) = with(binding) {
        val drawable = if (clickable) {
            (viewModel.onReplayState.value ?: ReplayState.STARTING).getReplayButtonDrawable()
        } else R.drawable.bg_replay_button_disabled
        replayButton.setBackgroundResource(drawable)
    }
}
