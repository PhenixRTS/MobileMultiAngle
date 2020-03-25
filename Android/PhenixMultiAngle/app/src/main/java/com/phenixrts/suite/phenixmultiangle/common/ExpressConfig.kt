/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import com.phenixrts.express.JoinRoomOptions
import com.phenixrts.express.RoomExpressFactory
import com.phenixrts.express.SubscribeToMemberStreamOptions
import com.phenixrts.suite.phenixmultiangle.BuildConfig

fun getRoomOptions(): JoinRoomOptions = RoomExpressFactory.createJoinRoomOptionsBuilder()
    .withRoomAlias(BuildConfig.ROOM_ALIAS)
    .buildJoinRoomOptions()

fun getMemberOptions(): SubscribeToMemberStreamOptions =
    RoomExpressFactory.createSubscribeToMemberStreamOptionsBuilder()
        .buildSubscribeToMemberStreamOptions()
