/*
 * Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.injection

import com.phenixrts.suite.phenixcore.PhenixCore
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp
import dagger.Module
import dagger.Provides
import javax.inject.Singleton

@Module
class InjectionModule(private val context: MultiAngleApp) {

    @Provides
    @Singleton
    fun providePhenixCore() = PhenixCore(context)
}
