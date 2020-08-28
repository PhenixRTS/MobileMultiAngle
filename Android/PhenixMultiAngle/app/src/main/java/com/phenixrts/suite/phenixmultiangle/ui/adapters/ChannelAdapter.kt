/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.adapters

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.lifecycle.LifecycleOwner
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.phenixrts.suite.phenixmultiangle.databinding.RowChannelItemBinding
import com.phenixrts.suite.phenixmultiangle.models.Channel
import kotlin.properties.Delegates

class ChannelAdapter(
    private val onChannelClicked: (channel: Channel) -> Unit
) : RecyclerView.Adapter<ChannelAdapter.ViewHolder>() {

    var data: List<Channel> by Delegates.observable(mutableListOf()) { _, old, new ->
        DiffUtil.calculateDiff(RoomMemberDiff(old, new)).dispatchUpdatesTo(this)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = ViewHolder(
        RowChannelItemBinding.inflate(LayoutInflater.from(parent.context)).apply {
            lifecycleOwner = parent.context as? LifecycleOwner
        }
    )

    override fun getItemCount() = data.size

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val roomMember = data[position]
        holder.binding.channel = roomMember
        roomMember.setThumbnailSurfaces(holder.binding.itemStreamSurface, holder.binding.itemBitmapSurface)
        roomMember.isMainRendered.observeForever {
            holder.binding.channel = roomMember
        }
    }

    inner class ViewHolder(val binding: RowChannelItemBinding) : RecyclerView.ViewHolder(binding.root) {
        init {
            binding.itemSurfaceHolder.setOnClickListener {
                data.getOrNull(adapterPosition)?.let { roomMember ->
                    onChannelClicked(roomMember)
                }
            }
        }
    }

    class RoomMemberDiff(private val oldItems: List<Channel>,
                         private val newItems: List<Channel>
    ) : DiffUtil.Callback() {

        override fun getOldListSize() = oldItems.size

        override fun getNewListSize() = newItems.size

        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            return oldItems[oldItemPosition].channelAlias == newItems[newItemPosition].channelAlias
        }

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            return oldItems[oldItemPosition] == newItems[newItemPosition]
        }
    }
}
