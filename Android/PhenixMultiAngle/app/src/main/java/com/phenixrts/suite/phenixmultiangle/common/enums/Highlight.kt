/*
 * Copyright 2020 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common.enums

import androidx.annotation.StringRes
import com.phenixrts.suite.phenixmultiangle.R
import java.util.concurrent.TimeUnit

enum class Highlight(val minutesAgo: Long, val loopLength: Long, @StringRes val title: Int) {
    FAR(TimeUnit.SECONDS.toMillis(40), TimeUnit.SECONDS.toMillis(30), R.string.highlight_far),
    NEAR(TimeUnit.SECONDS.toMillis(30), TimeUnit.SECONDS.toMillis(20), R.string.highlight_near),
    CLOSE(TimeUnit.SECONDS.toMillis(20), TimeUnit.SECONDS.toMillis(10), R.string.highlight_close)
}
