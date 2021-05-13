/*
 * Copyright 2021 Phenix Real Time Solutions, Inc. Confidential and Proprietary. All rights reserved.
 */

package com.phenixrts.suite.phenixmultiangle.common.enums

@Suppress("unused")
enum class Bandwidth(val value: Long) {
    ULD(1000 * 80L),
    VLD(1000 * 350L),
    LD(1000 * 520L),
    SD(1000 * 830L),
    HD(1000 * 1600L),
    FHD(1000 * 3000L),
    XHD(1000 * 5500L),
    UHD(1000 * 8500L),
    UNLIMITED(0L)
}
