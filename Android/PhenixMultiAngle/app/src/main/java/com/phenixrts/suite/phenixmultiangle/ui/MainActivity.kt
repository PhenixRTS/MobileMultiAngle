/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Observer
import androidx.lifecycle.viewModelScope
import androidx.recyclerview.widget.GridLayoutManager
import com.phenixrts.common.RequestStatus
import com.phenixrts.pcast.RendererStartStatus
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.R
import com.phenixrts.suite.phenixmultiangle.common.lazyViewModel
import com.phenixrts.suite.phenixmultiangle.models.RoomMember
import com.phenixrts.suite.phenixmultiangle.repository.RoomExpressRepository
import com.phenixrts.suite.phenixmultiangle.ui.adapters.RoomMemberAdapter
import com.phenixrts.suite.phenixmultiangle.ui.viewmodels.RoomViewModel
import kotlinx.android.synthetic.main.activity_main.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import timber.log.Timber
import javax.inject.Inject

class MainActivity : FragmentActivity(), RoomMemberAdapter.OnMemberSelected {

    @Inject lateinit var roomExpress: RoomExpressRepository

    private val viewModel: RoomViewModel by lazyViewModel {
        RoomViewModel(roomExpress, this)
    }

    private val adapter: RoomMemberAdapter by lazy {
        RoomMemberAdapter(viewModel, this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MultiAngleApp.component.inject(this)
        setContentView(R.layout.activity_main)
        handleRoomExpressExceptions()
        runBlocking {
            val status = viewModel.joinMultiAngleRoom()
            if (status.status == RequestStatus.OK) {
                initViews()
            } else {
                showToast("Filed to join channel")
                finish()
            }
        }
    }

    private fun initViews() {
        main_stream_holder.visibility = View.VISIBLE
        main_stream_list.visibility = View.VISIBLE
        main_stream_list.layoutManager = GridLayoutManager(this, 2)
        main_stream_list.setHasFixedSize(true)
        main_stream_list.adapter = adapter

        main_stream_list.post {
            viewModel.roomMembers.observe(this, Observer { members ->
                Timber.d("Received members: $members")
                members.firstOrNull { it.isMainRendered }?.let { member ->
                    renderActiveMember(member)
                }
                val listMembers = members.filter { !it.isMainRendered }
                adapter.data = listMembers
            })
        }
    }

    private fun renderActiveMember(roomMember: RoomMember) = viewModel.viewModelScope.launch {
        Timber.d("Active room member changed: $roomMember")
        roomMember.surface = main_stream_surface
        val status = viewModel.startMemberMedia(roomMember)
        if (status != RendererStartStatus.OK) {
            showToast("Failed to render stream on main surface")
        } else {
            roomMember.renderer?.unmuteAudio()
        }
    }

    private fun handleRoomExpressExceptions() {
        roomExpress.roomStatus.observe(this, Observer {
            if (it.status != RequestStatus.OK) {
                showToast("Filed to init pCast")
                finish()
            }
        })
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }

    override fun onMemberClicked(roomMember: RoomMember) {
        Timber.d("Member clicked: $roomMember")
        viewModel.updateActiveMember(roomMember)
    }
}
