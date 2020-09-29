/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.repository

import androidx.lifecycle.MutableLiveData
import com.phenixrts.common.RequestStatus
import com.phenixrts.environment.android.AndroidContext
import com.phenixrts.express.*
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.common.*
import com.phenixrts.suite.phenixmultiangle.common.enums.ExpressError
import com.phenixrts.suite.phenixmultiangle.models.Channel
import kotlinx.coroutines.delay
import timber.log.Timber
import java.util.*
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

private const val REINITIALIZATION_DELAY = 1000L

class ChannelExpressRepository(private val context: MultiAngleApp) {

    private var expressConfiguration: ChannelExpressConfiguration = ChannelExpressConfiguration()
    private var roomExpress: RoomExpress? = null
    private var channelExpress: ChannelExpress? = null
    val channels = MutableLiveData<List<Channel>>()
    val channelJoinTime = Date(System.currentTimeMillis())
    var timeShiftStartTime = Date(channelJoinTime.time - DEFAULT_HIGHLIGHT.minutesAgo)

    val onChannelExpressError = MutableLiveData<ExpressError>()

    private fun hasConfigurationChanged(configuration: ChannelExpressConfiguration): Boolean = expressConfiguration != configuration

    private fun initializeChannelExpress() {
        Timber.d("Creating Channel Express with configuration: $expressConfiguration")
        AndroidContext.setContext(context)
        var pcastBuilder = PCastExpressFactory.createPCastExpressOptionsBuilder()
            .withMinimumConsoleLogLevel("info")
            .withBackendUri(expressConfiguration.backend)
            .withPCastUri(expressConfiguration.uri)
            .withUnrecoverableErrorCallback { status: RequestStatus, description: String ->
                Timber.e("Unrecoverable error in PhenixSDK. Error status: [$status]. Description: [$description]")
                onChannelExpressError.value = ExpressError.UNRECOVERABLE_ERROR
            }
        if (expressConfiguration.edgeAuth != null) {
            pcastBuilder = pcastBuilder.withAuthenticationToken(expressConfiguration.edgeAuth)
        }
        val roomExpressOptions = RoomExpressFactory.createRoomExpressOptionsBuilder()
            .withPCastExpressOptions(pcastBuilder.buildPCastExpressOptions())
            .buildRoomExpressOptions()

        val channelExpressOptions = ChannelExpressFactory.createChannelExpressOptionsBuilder()
            .withRoomExpressOptions(roomExpressOptions)
            .buildChannelExpressOptions()

        ChannelExpressFactory.createChannelExpress(channelExpressOptions)?.let { express ->
            channelExpress = express
            roomExpress = express.roomExpress
            channels.value = expressConfiguration.channelAliases.map {
                Channel(express, it)
            }.apply {
                firstOrNull()?.isMainRendered?.value = true
            }
            Timber.d("Channel express initialized")
        } ?: run {
            Timber.e("Unrecoverable error in PhenixSDK")
            onChannelExpressError.value = ExpressError.UNRECOVERABLE_ERROR
        }
    }

    suspend fun setupChannelExpress(configuration: ChannelExpressConfiguration) {
        if (hasConfigurationChanged(configuration)) {
            Timber.d("Room Express configuration has changed: $configuration")
            expressConfiguration = configuration
            roomExpress?.dispose()
            roomExpress = null
            Timber.d("Room Express disposed")
            delay(REINITIALIZATION_DELAY)
            initializeChannelExpress()
        }
    }

    suspend fun waitForPCast(): Unit = suspendCoroutine { continuation ->
        launchMain {
            Timber.d("Waiting for pCast")
            if (roomExpress == null) {
                initializeChannelExpress()
            }
            roomExpress?.pCastExpress?.waitForOnline()
            continuation.resume(Unit)
        }
    }

    fun isRoomExpressInitialized(): Boolean = roomExpress != null

    fun getMimeTypes() = expressConfiguration.mimeTypes

}
