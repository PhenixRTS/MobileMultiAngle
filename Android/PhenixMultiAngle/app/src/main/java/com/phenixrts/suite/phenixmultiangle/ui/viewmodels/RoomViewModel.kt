/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.ui.viewmodels

import android.view.View
import android.view.animation.AnimationUtils
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.*
import com.phenixrts.common.RequestStatus
import com.phenixrts.pcast.Renderer
import com.phenixrts.pcast.RendererStartStatus
import com.phenixrts.pcast.android.AndroidVideoRenderSurface
import com.phenixrts.suite.phenixmultiangle.R
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
    private var restartingRenderers = arrayListOf<Renderer?>()

    val roomMembers = MutableLiveData<List<RoomMember>>()

    private fun observeRoomMembers() = viewModelScope.launch {
        joinedRoomRepository?.roomMembers?.observe(context, Observer { members ->
            Timber.d("Received room members $members")
            roomMembers.value = members
        })
    }

    private suspend fun restartMediaRenderer(roomMember: RoomMember): RendererStartStatus = suspendCoroutine { continuation ->
        val renderer = roomMember.renderer
        val surfaceHolder = roomMember.surface?.holder
        Timber.d("Restarting renderer for: $roomMember")
        renderer?.let { mediaRenderer ->
            var rendererStartStatus = RendererStartStatus.OK
            if (!restartingRenderers.contains(mediaRenderer)) {
                restartingRenderers.add(mediaRenderer)
                viewModelScope.launch {
                    try {
                        mediaRenderer.stop()
                        rendererStartStatus = mediaRenderer.start(AndroidVideoRenderSurface(surfaceHolder))?.let { rendererStatus ->
                            Timber.d("Renderer restarted: $rendererStatus")
                            rendererStatus
                        } ?: RendererStartStatus.FAILED
                    } catch (e: Exception) {
                        Timber.d("Failed to restart renderer")
                        rendererStartStatus = RendererStartStatus.FAILED
                    } finally {
                        restartingRenderers.remove(mediaRenderer)
                        Timber.d("Resuming renderer restart")
                        showMemberSurface(roomMember, rendererStartStatus)
                        continuation.resume(rendererStartStatus)
                    }
                }
            } else {
                Timber.d("Resuming renderer restart")
                showMemberSurface(roomMember, rendererStartStatus)
                continuation.resume(rendererStartStatus)
            }
        }
    }

    private fun showMemberSurface(roomMember: RoomMember, status: RendererStartStatus) {
        if (status == RendererStartStatus.OK) {
            roomMember.surface?.visibility = View.VISIBLE
            roomMember.surface?.startAnimation(AnimationUtils.loadAnimation(context, R.anim.fade_in))
        } else {
            roomMember.surface?.startAnimation(AnimationUtils.loadAnimation(context, R.anim.fade_out))
            roomMember.surface?.visibility = View.INVISIBLE
        }
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
            if (roomMember.renderer == null) {
                Timber.d("Creating renderer for: $roomMember")
                roomMember.renderer = roomMember.subscriber?.createRenderer()
                roomMember.renderer?.muteAudio()
            }
            continuation.resume(restartMediaRenderer(roomMember))
        }
    }

    fun updateActiveMember(roomMember: RoomMember) {
        val members = roomMembers.value?.toMutableList() ?: mutableListOf()
        members.forEach {
            it.isMainRendered = false
            it.renderer?.muteAudio()
            if (it.member.sessionId == roomMember.member.sessionId) {
                it.isMainRendered = true
            }
        }
        roomMembers.value = members
        Timber.d("Updated active member")
    }
}
