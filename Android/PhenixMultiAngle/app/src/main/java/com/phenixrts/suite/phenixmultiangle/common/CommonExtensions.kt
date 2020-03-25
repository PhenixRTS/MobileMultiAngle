/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import com.phenixrts.room.Member
import com.phenixrts.suite.phenixmultiangle.models.RoomMember

fun Member.getRoomMember(members: List<RoomMember>?): RoomMember {
    val roomMember = members.takeIf { it?.isNotEmpty() == true }
        ?.firstOrNull { it.member.sessionId == this.sessionId }
    return roomMember ?: RoomMember(this)
}
