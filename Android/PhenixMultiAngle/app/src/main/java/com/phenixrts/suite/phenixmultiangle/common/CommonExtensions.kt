/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import android.view.View
import android.view.animation.AccelerateInterpolator
import com.phenixrts.room.Member
import com.phenixrts.suite.phenixmultiangle.models.RoomMember
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume

const val ANIMATION_DURATION_FADE_IN = 100L
const val ANIMATION_DURATION_FADE_OUT = 250L

const val ALPHA_VISIBLE = 1F
const val ALPHA_INVISIBLE = 0F

fun Member.getRoomMember(members: List<RoomMember>?): RoomMember {
    val roomMember = members.takeIf { it?.isNotEmpty() == true }
        ?.firstOrNull { it.member.sessionId == this.sessionId }
    return roomMember ?: RoomMember(this)
}

fun <T> MutableList<T>.swap(index1: Int, index2: Int) {
    if (index1 < 0 || index2 < 0 || size <= index1 || size <= index2) {
        return
    }
    val tmp = this[index1]
    this[index1] = this[index2]
    this[index2] = tmp
}

fun View.fadeIn(continuation: Continuation<Unit>) {
    animate()
        .setDuration(ANIMATION_DURATION_FADE_IN)
        .alpha(ALPHA_VISIBLE)
        .withLayer()
        .setInterpolator(AccelerateInterpolator())
        .withEndAction {
            alpha = ALPHA_VISIBLE
            continuation.resume(Unit)
        }.start()
}

fun View.fadeOut(continuation: Continuation<Unit>) {
    animate()
        .setDuration(ANIMATION_DURATION_FADE_OUT)
        .alpha(ALPHA_INVISIBLE)
        .withLayer()
        .setInterpolator(AccelerateInterpolator())
        .withEndAction {
            alpha = ALPHA_INVISIBLE
            continuation.resume(Unit)
        }.start()
}

fun RoomMember.asString() = toString()
