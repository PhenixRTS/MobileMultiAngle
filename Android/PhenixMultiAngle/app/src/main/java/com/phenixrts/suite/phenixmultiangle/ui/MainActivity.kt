/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.content.res.Configuration
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.SeekBar
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.GridLayoutManager
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.Highlight
import com.phenixrts.suite.phenixmultiangle.common.enums.ReplayState
import com.phenixrts.suite.phenixmultiangle.repository.ChannelExpressRepository
import com.phenixrts.suite.phenixmultiangle.ui.adapters.ChannelAdapter
import com.phenixrts.suite.phenixmultiangle.ui.viewmodels.ChannelViewModel
import kotlinx.android.synthetic.main.activity_main.*
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Inject

const val SPAN_COUNT_PORTRAIT = 2
const val SPAN_COUNT_LANDSCAPE = 1

class MainActivity : FragmentActivity() {

    @Inject lateinit var channelExpress: ChannelExpressRepository

    private val viewModel: ChannelViewModel by lazyViewModel({ application as MultiAngleApp }, { ChannelViewModel(channelExpress) })

    private val adapter: ChannelAdapter by lazy {
        ChannelAdapter { roomMember ->
            Timber.d("Member clicked: $roomMember")
            viewModel.updateActiveChannel(main_stream_surface, closed_caption_view, roomMember)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MultiAngleApp.component.inject(this)
        setContentView(R.layout.activity_main)
        initViews()
    }

    private fun initViews() {
        val rotation = resources.configuration.orientation
        val spanCount = if (rotation == Configuration.ORIENTATION_PORTRAIT) SPAN_COUNT_PORTRAIT else SPAN_COUNT_LANDSCAPE
        val isFullScreen = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        main_stream_holder.changeVisibility(true)
        main_stream_list.changeVisibility(!isFullScreen)
        main_stream_list.layoutManager = GridLayoutManager(this, spanCount)
        main_stream_list.setHasFixedSize(true)
        main_stream_list.adapter = adapter

        spinner_highlights.adapter = ArrayAdapter(this, R.layout.row_spinner_selector,
            Highlight.values().map { getString(it.title) }.toList()).apply {
                setDropDownViewResource(R.layout.row_spinner_item)
        }
        spinner_highlights.onSelectionChanged { index ->
            Timber.d("Highlight index changed: $index")
            viewModel.createTimeShift(Highlight.values()[index])
        }

        replay_button.setOnClickListener {
            Timber.d("Replay button clicked: ${Highlight.values()[spinner_highlights.selectedItemPosition]}")
            viewModel.switchReplayState(Highlight.values()[spinner_highlights.selectedItemPosition])
        }

        stream_head_progress.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            var currentProgress = 0L
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, p2: Boolean) {
                currentProgress = progress.toLong()
                stream_head_overlay.text = viewModel.getTimestampForProgress(currentProgress)
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

        viewModel.channels.observe(this, { channels ->
            Timber.d("Channel list updated: $channels, full screen: $isFullScreen")
            channels.forEach { channel ->
                channel.isFullScreen = isFullScreen
            }
            adapter.data = channels
        })
        viewModel.onChannelsJoined.observe(this, { ready ->
            Timber.d("On all channels ready: $ready")
            if (ready) {
                viewModel.channels.value?.find { it.isMainRendered.value == true }?.let { channel ->
                    viewModel.updateActiveChannel(main_stream_surface, closed_caption_view, channel)
                }
            }
        })
        viewModel.headTimeStamp.observe(this, { head ->
            stream_head_progress.progress = viewModel.getProgressFromTimestamp(head)
        })
        viewModel.onReplayButtonClickable.observe(this, { clickable ->
            updateReplayButton(clickable)
            replay_button.isEnabled = clickable
        })
        viewModel.onReplayState.observe(this, { state ->
            updateReplayButton(viewModel.onReplayButtonClickable.isTrue())
            when (state ?: ReplayState.STARTING) {
                ReplayState.READY -> {
                    spinner_highlights_holder.changeVisibility(true)
                    replay_button_icon.setImageResource(R.drawable.ic_replay)
                    replay_button_title.setText(R.string.button_replay)
                    replay_button.isEnabled = true
                    stream_head_holder.changeVisibility(false)
                    closed_caption_view.defaultConfiguration.isButtonVisible = true
                }
                ReplayState.REPLAYING -> {
                    spinner_highlights_holder.changeVisibility(false)
                    replay_button_icon.setImageResource(R.drawable.ic_play)
                    replay_button_title.setText(R.string.button_go_live)
                    replay_button.isEnabled = true
                    stream_head_holder.changeVisibility(true)
                    closed_caption_view.defaultConfiguration.isButtonVisible = false
                    // Update seek bar MAX value
                    val loopLength = viewModel.selectedHighlight.loopLength
                    stream_head_progress.max = TimeUnit.MILLISECONDS.toSeconds(loopLength).toInt()
                }
                ReplayState.FAILED -> {
                    spinner_highlights_holder.changeVisibility(true)
                    replay_button_icon.setImageResource(R.drawable.ic_replay_warning)
                    replay_button_title.setText(R.string.button_replay_failed)
                    replay_button.isEnabled = true
                    stream_head_holder.changeVisibility(false)
                    closed_caption_view.defaultConfiguration.isButtonVisible = true
                }
                ReplayState.STARTING -> {
                    spinner_highlights_holder.changeVisibility(false)
                    replay_button_icon.setImageResource(R.drawable.ic_replay_starting)
                    replay_button_title.setText(R.string.button_replay_starting)
                    replay_button.isEnabled = false
                    stream_head_holder.changeVisibility(false)
                    closed_caption_view.defaultConfiguration.isButtonVisible = true
                }
            }
            closed_caption_view.refresh()
        })
        Timber.d("Initializing Main Activity: $rotation")
    }

    private fun updateReplayButton(clickable: Boolean) {
        val drawable = if (clickable) {
            (viewModel.onReplayState.value ?: ReplayState.STARTING).getReplayButtonDrawable()
        } else R.drawable.bg_replay_button_disabled
        replay_button.setBackgroundResource(drawable)
    }
}
