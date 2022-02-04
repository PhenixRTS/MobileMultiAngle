/*
 * Copyright 2022 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common.enums

import androidx.annotation.StringRes
import com.phenixrts.suite.phenixmultiangle.R
import java.util.concurrent.TimeUnit

enum class Highlight(val secondsAgo: Long, val loopLength: Long, @StringRes val title: Int) {
    SEEK_80_LOOP_60(TimeUnit.SECONDS.toMillis(80), TimeUnit.SECONDS.toMillis(60), R.string.seek_80_loop_60),
    SEEK_80_LOOP_30(TimeUnit.SECONDS.toMillis(80), TimeUnit.SECONDS.toMillis(30), R.string.seek_80_loop_30),
    SEEK_80_LOOP_10(TimeUnit.SECONDS.toMillis(80), TimeUnit.SECONDS.toMillis(10), R.string.seek_80_loop_10),
    SEEK_40_LOOP_30(TimeUnit.SECONDS.toMillis(40), TimeUnit.SECONDS.toMillis(30), R.string.seek_40_loop_30),
    SEEK_30_LOOP_20(TimeUnit.SECONDS.toMillis(30), TimeUnit.SECONDS.toMillis(20), R.string.seek_30_loop_20),
    SEEK_60_LOOP_20(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(20), R.string.seek_60_loop_20),
    SEEK_60_LOOP_25(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(25), R.string.seek_60_loop_25),
    SEEK_60_LOOP_30(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(30), R.string.seek_60_loop_30),
    SEEK_60_LOOP_35(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(35), R.string.seek_60_loop_35),
    SEEK_60_LOOP_40(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(40), R.string.seek_60_loop_40),
    SEEK_60_LOOP_45(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(45), R.string.seek_60_loop_45),
    SEEK_60_LOOP_50(TimeUnit.SECONDS.toMillis(60), TimeUnit.SECONDS.toMillis(50), R.string.seek_60_loop_50)
}
