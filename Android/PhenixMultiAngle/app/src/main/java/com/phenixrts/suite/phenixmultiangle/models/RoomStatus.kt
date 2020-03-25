/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import com.phenixrts.common.RequestStatus
import com.phenixrts.room.RoomService

data class RoomStatus(
    val status: RequestStatus,
    val roomService: RoomService? = null
)
