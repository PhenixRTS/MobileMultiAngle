/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle

import android.app.Application
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import com.phenixrts.suite.phenixmultiangle.common.LineNumberDebugTree
import com.phenixrts.suite.phenixmultiangle.injection.DaggerInjectionComponent
import com.phenixrts.suite.phenixmultiangle.injection.InjectionComponent
import com.phenixrts.suite.phenixmultiangle.injection.InjectionModule
import timber.log.Timber

class MultiAngleApp : Application(), ViewModelStoreOwner {

    private val appViewModelStore: ViewModelStore by lazy {
        ViewModelStore()
    }

    override fun onCreate() {
        super.onCreate()

        if (BuildConfig.DEBUG) {
            Timber.plant(LineNumberDebugTree("MultiAngleApp"))
        }

        component = DaggerInjectionComponent.builder().injectionModule(InjectionModule(this)).build()
    }

    override fun getViewModelStore() = appViewModelStore

    companion object {
        lateinit var component: InjectionComponent
            private set
    }
}
