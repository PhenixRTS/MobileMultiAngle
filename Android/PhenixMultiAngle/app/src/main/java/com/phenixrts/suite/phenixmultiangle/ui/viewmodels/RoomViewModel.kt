/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.viewmodels

import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.*
import com.phenixrts.common.RequestStatus
import com.phenixrts.pcast.RendererStartStatus
import com.phenixrts.suite.phenixmultiangle.common.swap
import com.phenixrts.suite.phenixmultiangle.models.RoomMember
import com.phenixrts.suite.phenixmultiangle.models.RoomStatus
import com.phenixrts.suite.phenixmultiangle.repository.JoinedRoomRepository
import com.phenixrts.suite.phenixmultiangle.repository.RoomExpressRepository
import kotlinx.coroutines.launch
import timber.log.Timber
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class RoomViewModel(
    private val roomExpressRepository: RoomExpressRepository,
    private val context: FragmentActivity
) : ViewModel() {

    private var joinedRoomRepository: JoinedRoomRepository? = null

    val roomMembers = MutableLiveData<List<RoomMember>>()

    private fun observeRoomMembers() = viewModelScope.launch {
        joinedRoomRepository?.roomMembers?.observe(context, Observer { members ->
            Timber.d("Received room members $members")
            roomMembers.value = members
        })
    }

    suspend fun joinMultiAngleRoom() = suspendCoroutine<RoomStatus> { continuation ->
        roomExpressRepository.launch {
            val status = roomExpressRepository.joinMultiAngleRoom()
            Timber.d("Multi Angle room joined: $status")
            if (status.status == RequestStatus.OK && status.roomService != null) {
                joinedRoomRepository = JoinedRoomRepository(roomExpressRepository.roomExpress, status.roomService)
                observeRoomMembers()
            }
            continuation.resume(status)
        }
    }

    suspend fun startMemberMedia(roomMember: RoomMember) = suspendCoroutine<RendererStartStatus> { continuation ->
        viewModelScope.launch {
            if (!roomMember.isRendererStarted) {
                val status = roomMember.startVideoRenderer()
                Timber.d("Started member renderer: $status : $roomMember")
                continuation.resume(status)
            } else {
                continuation.resume(RendererStartStatus.OK)
            }
        }
    }

    fun updateActiveMember(roomMember: RoomMember) = viewModelScope.launch {
        val members = roomMembers.value?.toMutableList() ?: mutableListOf()
        val currentActiveIndex = members.indexOfFirst { it.isMainRendered }
        val currentSelectedIndex = members.indexOfFirst { it.member.sessionId == roomMember.member.sessionId }
        members.forEach { member ->
            member.isMainRendered = false
            member.muteAudio()
            if (member.member.sessionId == roomMember.member.sessionId) {
                member.isMainRendered = true
            }
        }
        members.swap(currentActiveIndex, currentSelectedIndex)
        members.getOrNull(currentActiveIndex)?.showMask()
        members.getOrNull(currentSelectedIndex)?.showMask()
        roomMembers.value = members
        Timber.d("Updated active member")
    }

    fun releaseObservers() {
        Timber.d("Releasing observers")
        joinedRoomRepository?.roomMembers?.removeObservers(context)
        joinedRoomRepository?.dispose()
        joinedRoomRepository = null
        roomMembers.removeObservers(context)
    }
}
