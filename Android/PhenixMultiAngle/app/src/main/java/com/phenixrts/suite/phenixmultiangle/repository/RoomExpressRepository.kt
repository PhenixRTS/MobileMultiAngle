/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.repository

import androidx.lifecycle.MutableLiveData
import com.phenixrts.common.RequestStatus
import com.phenixrts.express.*
import com.phenixrts.room.RoomService
import com.phenixrts.suite.phenixmultiangle.common.getRoomOptions
import com.phenixrts.suite.phenixmultiangle.models.RoomStatus
import timber.log.Timber
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class RoomExpressRepository(
    val roomExpress: RoomExpress,
    val roomStatus: MutableLiveData<RoomStatus>
) {

    suspend fun joinMultiAngleRoom() = suspendCoroutine<RoomStatus> { continuation ->
        roomExpress.pCastExpress.waitForOnline {
            roomExpress.joinRoom(getRoomOptions()) { status: RequestStatus, roomService: RoomService? ->
                var requestStatus = status
                if (roomService == null || status != RequestStatus.OK) {
                    requestStatus = RequestStatus.FAILED
                }
                Timber.d("Room join completed with status: $requestStatus")
                continuation.resume(RoomStatus(requestStatus, roomService))
            }
        }
    }
}
