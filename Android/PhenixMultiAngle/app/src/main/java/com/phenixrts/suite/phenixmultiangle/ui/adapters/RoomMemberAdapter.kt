/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.adapters

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.viewModelScope
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.phenixrts.suite.phenixmultiangle.databinding.RowMemberItemBinding
import com.phenixrts.suite.phenixmultiangle.models.RoomMember
import com.phenixrts.suite.phenixmultiangle.ui.viewmodels.RoomViewModel
import kotlinx.coroutines.launch
import timber.log.Timber
import kotlin.properties.Delegates

class RoomMemberAdapter(
    private val viewModel: RoomViewModel,
    private val callback: OnMemberSelected
) : RecyclerView.Adapter<RoomMemberAdapter.ViewHolder>() {

    var data: List<RoomMember> by Delegates.observable(emptyList()) { _, old, new ->
        DiffUtil.calculateDiff(RoomMemberDiff(old, new)).dispatchUpdatesTo(this)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) = ViewHolder(
        RowMemberItemBinding.inflate(LayoutInflater.from(parent.context)).apply {
            lifecycleOwner = parent.context as? LifecycleOwner
        }
    )

    override fun getItemCount() = data.size

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val roomMember = data[position]
        roomMember.surface = holder.binding.itemStreamSurface
        renderMemberMedia(roomMember)
    }

    private fun renderMemberMedia(roomMember: RoomMember) = viewModel.viewModelScope.launch {
        val status = viewModel.startMemberMedia(roomMember)
        Timber.d("Started member renderer: $status : $roomMember")
    }

    inner class ViewHolder(val binding: RowMemberItemBinding) : RecyclerView.ViewHolder(binding.root) {
        init {
            binding.itemSurfaceHolder.setOnClickListener {
                Timber.d("Member clicked: $adapterPosition")
                data.getOrNull(adapterPosition)?.let { roomMember ->
                    callback.onMemberClicked(roomMember)
                }
            }
        }
    }

    inner class RoomMemberDiff(private val oldItems: List<RoomMember>,
                               private val newItems: List<RoomMember>
    ) : DiffUtil.Callback() {

        override fun getOldListSize() = oldItems.size

        override fun getNewListSize() = newItems.size

        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            return oldItems[oldItemPosition].member.sessionId == newItems[newItemPosition].member.sessionId
        }

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            return oldItems[oldItemPosition] == newItems[newItemPosition]
        }
    }

    interface OnMemberSelected {
        fun onMemberClicked(roomMember: RoomMember)
    }
}
