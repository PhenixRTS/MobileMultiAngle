/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.injection

import androidx.lifecycle.MutableLiveData
import com.phenixrts.common.RequestStatus
import com.phenixrts.environment.android.AndroidContext
import com.phenixrts.express.PCastExpressFactory
import com.phenixrts.express.RoomExpressFactory
import com.phenixrts.suite.phenixmultiangle.BuildConfig
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.models.RoomStatus
import com.phenixrts.suite.phenixmultiangle.repository.RoomExpressRepository
import dagger.Module
import dagger.Provides
import timber.log.Timber
import javax.inject.Singleton

@Module
class InjectionModule(private val context: MultiAngleApp) {

    @Provides
    @Singleton
    fun provideRoomExpressRepository(): RoomExpressRepository {
        Timber.d("Create Room Express Singleton")
        val roomStatus = MutableLiveData<RoomStatus>()
        roomStatus.value = RoomStatus(RequestStatus.OK)
        AndroidContext.setContext(context)
        val pcastExpressOptions = PCastExpressFactory.createPCastExpressOptionsBuilder()
            .withBackendUri(BuildConfig.BACKEND_URL)
            .withPCastUri(BuildConfig.PCAST_URL)
            .withUnrecoverableErrorCallback { status: RequestStatus, description: String ->
                Timber.e("Unrecoverable error in PhenixSDK. Error status: [$status]. Description: [$description]")
                roomStatus.value = RoomStatus(status)
            }
            .withMinimumConsoleLogLevel("info")
            .buildPCastExpressOptions()

        val roomExpressOptions = RoomExpressFactory.createRoomExpressOptionsBuilder()
            .withPCastExpressOptions(pcastExpressOptions)
            .buildRoomExpressOptions()
        return RoomExpressRepository(RoomExpressFactory.createRoomExpress(roomExpressOptions), roomStatus)
    }
}
