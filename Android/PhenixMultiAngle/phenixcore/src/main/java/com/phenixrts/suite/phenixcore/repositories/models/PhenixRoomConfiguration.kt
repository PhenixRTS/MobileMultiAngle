/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixcore.repositories.models

import com.phenixrts.room.MemberRole
import com.phenixrts.room.RoomType

data class PhenixRoomConfiguration(
    var roomAlias: String = "",
    var roomType: RoomType = RoomType.MULTI_PARTY_CHAT,
    var memberName: String = "",
    var memberRole: MemberRole = MemberRole.AUDIENCE,
    var messageConfigs: List<PhenixMessageConfiguration> = emptyList(),
    var joinSilently: Boolean = false,
)
