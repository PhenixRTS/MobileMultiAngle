/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.adapters

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.lifecycle.LifecycleOwner
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixcore.repositories.models.PhenixChannel
import com.phenixrts.suite.phenixmultiangle.databinding.RowChannelItemBinding
import kotlin.properties.Delegates

class ChannelAdapter(
    private val phenixCore: PhenixCore,
    private val onChannelClicked: (channel: PhenixChannel) -> Unit
) : RecyclerView.Adapter<ChannelAdapter.ViewHolder>() {

    var data: List<PhenixChannel> by Delegates.observable(mutableListOf()) { _, old, new ->
        DiffUtil.calculateDiff(RoomMemberDiff(old, new)).dispatchUpdatesTo(this)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = ViewHolder(
        RowChannelItemBinding.inflate(LayoutInflater.from(parent.context)).apply {
            lifecycleOwner = parent.context as? LifecycleOwner
        }
    )

    override fun getItemCount() = data.size

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val channel = data[position]
        holder.binding.channel = channel
        holder.binding.channelSurfaceHolder.tag = position
        holder.binding.channelSurfaceHolder.setOnClickListener {
            data.getOrNull(it.tag as Int)?.let { roomMember ->
                updateChannelRenderer(channel, holder)
                onChannelClicked(roomMember)
            }
        }
        updateChannelRenderer(channel, holder)
    }

    private fun updateChannelRenderer(channel: PhenixChannel, holder: ViewHolder) {
        if (channel.isSelected) {
            phenixCore.renderOnImage(channel.alias, holder.binding.streamImageView)
        } else {
            phenixCore.renderOnSurface(channel.alias, holder.binding.streamSurfaceView)
        }
    }

    inner class ViewHolder(val binding: RowChannelItemBinding) : RecyclerView.ViewHolder(binding.root)

    class RoomMemberDiff(private val oldItems: List<PhenixChannel>,
                         private val newItems: List<PhenixChannel>
    ) : DiffUtil.Callback() {

        override fun getOldListSize() = oldItems.size

        override fun getNewListSize() = newItems.size

        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            return oldItems[oldItemPosition].alias == newItems[newItemPosition].alias
        }

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            return oldItems[oldItemPosition] == newItems[newItemPosition]
        }
    }
}
