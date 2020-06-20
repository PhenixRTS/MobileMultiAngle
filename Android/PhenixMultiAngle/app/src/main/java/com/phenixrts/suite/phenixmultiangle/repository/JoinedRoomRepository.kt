/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.repository

import androidx.lifecycle.MutableLiveData
import com.phenixrts.common.Disposable
import com.phenixrts.common.RequestStatus
import com.phenixrts.express.RoomExpress
import com.phenixrts.room.RoomService
import com.phenixrts.suite.phenixmultiangle.common.getRoomMember
import com.phenixrts.suite.phenixmultiangle.common.getMemberOptions
import com.phenixrts.suite.phenixmultiangle.common.launchMain
import com.phenixrts.suite.phenixmultiangle.models.RoomMember
import timber.log.Timber

class JoinedRoomRepository(
    private val roomExpress: RoomExpress,
    private val roomService: RoomService
) {

    val roomMembers = MutableLiveData<List<RoomMember>>()
    private val disposables: MutableList<Disposable?> = mutableListOf()

    init {
        observeRoomMembers()
    }

    private fun observeRoomMembers() {
        roomService.observableActiveRoom.value.observableMembers.subscribe { members ->
            launchMain {
                Timber.d("Received RAW members count: ${members.size}")
                val memberList = ArrayList<RoomMember>()
                members.forEach { member ->
                    val roomMember = member.getRoomMember(roomMembers.value)
                    memberList.add(roomMember)
                }
                val hasMainRenderer = memberList.firstOrNull { it.isMainRendered } != null
                if (!hasMainRenderer) {
                    memberList.getOrNull(0)?.isMainRendered = true
                }
                subscribeMembers(memberList)
            }
        }.run { disposables.add(this) }
    }

    private fun subscribeMembers(memberList: List<RoomMember>) {
        val subscribedMembers = memberList.filter { it.isSubscribed() }.toMutableList()

        memberList.forEach { roomMember ->
            if (!roomMember.isSubscribed()) {
                roomMember.member.observableStreams.subscribe { streams ->
                    if (!roomMember.isSubscribed()) {
                        Timber.d("Subscribing to member media: $roomMember")
                        streams.getOrNull(0)?.let { stream ->
                            roomExpress.subscribeToMemberStream(stream, getMemberOptions()) { status, subscriber, _ ->
                                launchMain {
                                    Timber.d("Subscribed to member media: $status $roomMember")
                                    if (status == RequestStatus.OK) {
                                        roomMember.setSubscriber(subscriber)
                                        subscribedMembers.add(roomMember)
                                        updateRoomMembers(subscribedMembers)
                                    }
                                }
                            }
                        }
                    }
                }.run { disposables.add(this) }
            }
        }
        updateRoomMembers(subscribedMembers)
    }

    private fun updateRoomMembers(members: List<RoomMember>) {
        roomMembers.value = members
        Timber.d("Room member list updated: $members")
    }

    fun dispose () {
        disposables.forEach { it?.dispose() }
        disposables.clear()
    }
}
