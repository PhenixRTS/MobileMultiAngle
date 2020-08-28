/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.phenixrts.suite.phenixmultiangle.MultiAngleApp

inline fun <reified T : ViewModel> getViewModel(noinline owner: (() -> MultiAngleApp), noinline creator: (() -> T)? = null): T {
    return if (creator == null)
        ViewModelProvider(owner()).get(T::class.java)
    else
        ViewModelProvider(owner(), BaseViewModelFactory(creator)).get(T::class.java)
}

inline fun <reified T : ViewModel> lazyViewModel(noinline owner: (() -> MultiAngleApp), noinline creator: (() -> T)? = null) =
    lazy { getViewModel(owner, creator) }

class BaseViewModelFactory<T>(val creator: () -> T) : ViewModelProvider.Factory {
    override fun <T : ViewModel?> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return creator() as T
    }
}
