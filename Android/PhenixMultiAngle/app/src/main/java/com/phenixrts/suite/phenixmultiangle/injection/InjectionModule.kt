/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.injection

import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import com.phenixrts.suite.phenixmultiangle.cache.PreferenceProvider
import com.phenixrts.suite.phenixmultiangle.repository.ChannelExpressRepository
import dagger.Module
import dagger.Provides
import javax.inject.Singleton

@Module
class InjectionModule(private val context: MultiAngleApp) {

    @Singleton
    @Provides
    fun provideRoomExpressRepository() = ChannelExpressRepository(context)

    @Provides
    @Singleton
    fun providePreferencesProvider() = PreferenceProvider(context)
}
