/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common

import com.phenixrts.express.*
import kotlinx.coroutines.*
import timber.log.Timber
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
private val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

fun launchMain(block: suspend CoroutineScope.() -> Unit) = mainScope.launch(
    context = CoroutineExceptionHandler { _, e ->
        Timber.w(e, "Coroutine failed: ${e.localizedMessage}")
        e.printStackTrace()
    },
    block = block
)

fun launchIO(block: suspend CoroutineScope.() -> Unit) = ioScope.launch(
    context = CoroutineExceptionHandler { _, e ->
        Timber.w(e, "Coroutine failed: ${e.localizedMessage}")
        e.printStackTrace()
    },
    block = block
)

suspend fun PCastExpress.waitForOnline() = suspendCoroutine<Unit> { continuation ->
    waitForOnline {
        continuation.resume(Unit)
    }
}
