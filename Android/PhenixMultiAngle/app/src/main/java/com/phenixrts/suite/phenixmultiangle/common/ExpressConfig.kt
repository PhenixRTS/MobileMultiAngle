/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import com.phenixrts.express.JoinRoomOptions
import com.phenixrts.express.RoomExpressFactory
import com.phenixrts.express.SubscribeToMemberStreamOptions
import com.phenixrts.suite.phenixmultiangle.BuildConfig

const val SEEK_DELAY = 1000 * 5L
const val REPLAY_LOOP_DURATION = 1000 * 30L
// The delay before showing time shift button
const val TIME_SHIFT_CREATION_DELAY = 1000 * 5L

fun getRoomOptions(): JoinRoomOptions = RoomExpressFactory.createJoinRoomOptionsBuilder()
    .withRoomAlias(BuildConfig.ROOM_ALIAS)
    .buildJoinRoomOptions()

fun getMemberOptions(): SubscribeToMemberStreamOptions =
    RoomExpressFactory.createSubscribeToMemberStreamOptionsBuilder()
        .buildSubscribeToMemberStreamOptions()
