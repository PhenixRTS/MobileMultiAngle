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
        main_stream_holder.setVisible(true)
        main_stream_list.setVisible(true)
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
            Timber.d("Channel list updated: $channels")
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
        viewModel.onReplayButtonVisible.observe(this, { visible ->
            replay_holder.setVisible(visible)
            stream_head_holder.setVisible(viewModel.onReplayButtonState.value == ReplayState.REPLAYING)
        })
        viewModel.onReplayButtonState.observe(this, { state ->
            spinner_highlights_holder.setVisible(state == ReplayState.LIVE)
            if (state == ReplayState.LIVE) {
                replay_button_icon.setImageResource(R.drawable.ic_replay_30)
                replay_button_title.setText(R.string.button_replay)
                stream_head_holder.setVisible(false)
                closed_caption_view.defaultConfiguration.isButtonVisible = true
            } else {
                replay_button_icon.setImageResource(R.drawable.ic_play)
                replay_button_title.setText(R.string.button_go_live)
                stream_head_holder.setVisible(true)
                val loopLength = viewModel.selectedHighlight.loopLength
                Timber.d("Stream head ready: $loopLength ${TimeUnit.MILLISECONDS.toSeconds(loopLength).toInt()}")
                stream_head_progress.max = TimeUnit.MILLISECONDS.toSeconds(loopLength).toInt()
                closed_caption_view.defaultConfiguration.isButtonVisible = false
            }
            closed_caption_view.refresh()
        })
        viewModel.isReplayButtonClickable.observe(this, { isClickable ->
            replay_button.setBackgroundResource(
                if (isClickable) R.drawable.bg_replay_button else R.drawable.bg_replay_button_disabled
            )
        })
        Timber.d("Initializing Main Activity: $rotation")
    }
}
