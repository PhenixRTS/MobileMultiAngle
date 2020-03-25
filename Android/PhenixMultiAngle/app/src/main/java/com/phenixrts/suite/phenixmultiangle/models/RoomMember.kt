/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.models

import android.view.SurfaceView
import com.phenixrts.express.ExpressSubscriber
import com.phenixrts.pcast.Renderer
import com.phenixrts.room.Member

data class RoomMember(
    val member: Member,
    var renderer: Renderer? = null,
    var surface: SurfaceView? = null,
    var subscriber: ExpressSubscriber? = null,
    var isMainRendered: Boolean = false
) {

    override fun toString(): String {
        return "{\"name\":\"${member.observableScreenName.value}\"," +
                "\"hasRenderer\":\"${renderer != null}\"," +
                "\"surfaceId\":\"${surface?.id}\"," +
                "\"isSubscribed\":\"${subscriber != null}\"," +
                "\"isMainRendered\":\"$isMainRendered\"}"
    }
}
